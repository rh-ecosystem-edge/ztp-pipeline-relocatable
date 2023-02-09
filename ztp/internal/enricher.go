/*
Copyright 2023 Red Hat Inc.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in
compliance with the License. You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is
distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied. See the License for the specific language governing permissions and limitations under the
License.
*/

package internal

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"regexp"
	"strings"

	"github.com/go-logr/logr"
	"golang.org/x/crypto/ssh"
	"golang.org/x/exp/maps"
	"golang.org/x/exp/slices"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/models"
)

// EnricherBuilder contains the data and logic needed to create an object that knows how to add
// information to the description of a cluster. Don't create instances of this type directly, use
// the NewEnricher function instead.
type EnricherBuilder struct {
	logger logr.Logger
	client clnt.Client
	env    map[string]string
}

// Enricher knows how to add information to the description of a cluster. Don't create instances of
// this type directly, use the NewEnricher function instead.
type Enricher struct {
	logger logr.Logger
	client clnt.Client
	env    map[string]string
	jq     *JQ
}

// NewEnricher creates a builder that can then be used to create an object that knows how to add
// information to the description of a cluster.
func NewEnricher() *EnricherBuilder {
	return &EnricherBuilder{
		env: map[string]string{},
	}
}

// SetLogger sets the logger that the enricher will use to write log messages. This is mandatory.
func (b *EnricherBuilder) SetLogger(value logr.Logger) *EnricherBuilder {
	b.logger = value
	return b
}

// SetClient sets the Kubernetes API client that the enricher will use to talk to the hub cluster in
// order to extract the additional information.
func (b *EnricherBuilder) SetClient(value clnt.Client) *EnricherBuilder {
	b.client = value
	return b
}

// SetEnv sets the environment variables that will be used by the enricher.
func (b *EnricherBuilder) SetEnv(value map[string]string) *EnricherBuilder {
	b.env = value
	return b
}

// Build uses the data stored in the builder to create a new object that knows how to add
// information to the description of a cluster.
func (b *EnricherBuilder) Build() (result *Enricher, err error) {
	// Check parameters:
	if b.logger.GetSink() == nil {
		err = errors.New("logger is mandatory")
		return
	}
	if b.client == nil {
		err = errors.New("client is mandatory")
		return
	}

	// Create the JQ object:
	jq, err := NewJQ().
		SetLogger(b.logger).
		Build()
	if err != nil {
		err = fmt.Errorf("failed to create jq object: %v", err)
		return
	}

	// Create and populate the object:
	result = &Enricher{
		logger: b.logger,
		client: b.client,
		env:    maps.Clone(b.env),
		jq:     jq,
	}
	return
}

// Enrich completes the configuration adding the information that will be required later to create
// the clusters.
func (e *Enricher) Enrich(ctx context.Context, config *models.Config) error {
	err := e.enrichProperties(ctx, config.Properties)
	if err != nil {
		return err
	}
	for i := range config.Clusters {
		err := e.enrichCluster(ctx, &config.Clusters[i])
		if err != nil {
			return err
		}
	}
	return nil
}

func (e *Enricher) enrichProperties(ctx context.Context, properties map[string]string) error {
	setters := []func(context.Context, map[string]string) error{
		e.setOCPTag,
		e.setRHCOSRelease,
	}
	for _, setter := range setters {
		err := setter(ctx, properties)
		if err != nil {
			return err
		}
	}
	return nil
}

func (e *Enricher) setOCPTag(ctx context.Context, properties map[string]string) error {
	// Do nothing if already set:
	ocpTag := properties[models.OCPTagProperty]
	if ocpTag != "" {
		return nil
	}

	// Check that the version has been specified:
	ocpVersion := properties[models.OCPVersionProperty]
	if ocpVersion == "" {
		return fmt.Errorf(
			"failed to set OCP tag because property '%s' hasn't been specified",
			models.OCPVersionProperty,
		)
	}

	// Calculate the tag:
	ocpTag = fmt.Sprintf("%s-x86_64", ocpVersion)

	// Update the properties:
	properties[models.OCPTagProperty] = ocpTag
	e.logger.V(2).Info(
		"Set OCP tag property",
		"name", models.OCPTagProperty,
		"value", ocpTag,
	)
	return nil
}

func (e *Enricher) setRHCOSRelease(ctx context.Context, properties map[string]string) error {
	// Do nothing if it is already set:
	rhcosRelease := properties[models.OCPRCHOSReleaseProperty]
	if rhcosRelease != "" {
		return nil
	}

	// Check that the version has been specified:
	ocpVersion := properties[models.OCPVersionProperty]
	if ocpVersion == "" {
		return fmt.Errorf(
			"failed to set RHCOS release because property '%s' hasn't been specified",
			models.OCPVersionProperty,
		)
	}

	// Download the `release.txt` file:
	releaseTXT, err := e.downloadReleaseTXT(ctx, properties)
	if err != nil {
		return err
	}

	// Extract the RHCOS release:
	rhcosReleaseMatches := enricherRHCOSReleaseRE.FindStringSubmatch(string(releaseTXT))
	if len(rhcosReleaseMatches) < 2 {
		return fmt.Errorf("failed to find RHCOS release inside 'release.txt' file")
	}
	rchosRelease := rhcosReleaseMatches[1]

	// Update the properties:
	properties[models.OCPRCHOSReleaseProperty] = rchosRelease
	e.logger.Info(
		"Set RHCOS release property",
		"name", models.OCPRCHOSReleaseProperty,
		"value", rchosRelease,
	)

	return nil
}

func (e *Enricher) downloadReleaseTXT(ctx context.Context, properties map[string]string) (result string,
	err error) {
	mirror := properties[models.OCPMirrorProperty]
	if mirror == "" {
		mirror = enricherDefaultMirror
	}
	version := properties[models.OCPVersionProperty]
	url := fmt.Sprintf(
		"%s/%s/release.txt",
		mirror, version,
	)
	response, err := http.Get(url)
	if err != nil {
		return
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		err = fmt.Errorf(
			"failed to download 'release.txt' file from URL '%s' because server "+
				"responded with status code %d",
			url, response.StatusCode,
		)
		return
	}
	data, err := io.ReadAll(response.Body)
	if err != nil {
		return
	}
	result = string(data)
	e.logger.V(2).Info(
		"Downloaded 'release.txt' file",
		"url", url,
		"text", result,
	)
	return
}

func (e *Enricher) enrichCluster(ctx context.Context, cluster *models.Cluster) error {
	setters := []func(context.Context, *models.Cluster) error{
		e.setSNO,
		e.setPullSecret,
		e.setSSHKeys,
		e.setDNSDomain,
		e.setImageSet,
		e.setVIPs,
		e.setNetworks,
		e.setInternalIPs,
	}
	for _, setter := range setters {
		err := setter(ctx, cluster)
		if err != nil {
			return err
		}
	}
	return nil
}

func (e *Enricher) setSNO(ctx context.Context, cluster *models.Cluster) error {
	count := 0
	for _, node := range cluster.Nodes {
		if node.Kind == models.NodeKindControlPlane {
			count++
		}
	}
	cluster.SNO = count == 1
	return nil
}

func (e *Enricher) setPullSecret(ctx context.Context, cluster *models.Cluster) error {
	if cluster.PullSecret != nil {
		return nil
	}
	secret := &corev1.Secret{}
	key := clnt.ObjectKey{
		Namespace: "openshift-config",
		Name:      "pull-secret",
	}
	err := e.client.Get(ctx, key, secret)
	if err != nil {
		return fmt.Errorf("failed to get pull secret: %v", err)
	}
	data, ok := secret.Data[".dockerconfigjson"]
	if !ok {
		return fmt.Errorf("pull secret doesn't contain the '.dockerconfigjson' key")
	}
	e.logger.V(1).Info(
		"Loaded pull secret",
		"secret", string(data),
	)
	cluster.PullSecret = data
	return nil
}

func (e *Enricher) setSSHKeys(ctx context.Context, cluster *models.Cluster) error {
	publicKey, privateKey, err := e.generateSSHKeys()
	if err != nil {
		return fmt.Errorf("failed to generate RSA key pair: %v", err)
	}
	e.logger.V(1).Info(
		"Generated SSH keys",
		"public", string(publicKey),
		"private", string(privateKey),
	)
	cluster.SSH.PublicKey = publicKey
	cluster.SSH.PrivateKey = privateKey
	return nil
}

func (e *Enricher) generateSSHKeys() (publicKey, privateKey []byte, err error) {
	rsaKey, err := rsa.GenerateKey(rand.Reader, 4096)
	if err != nil {
		return
	}
	sshKey, err := ssh.NewPublicKey(&rsaKey.PublicKey)
	if err != nil {
		return
	}
	publicKey = ssh.MarshalAuthorizedKey(sshKey)
	privateKey = pem.EncodeToMemory(&pem.Block{
		Type:  "RSA PRIVATE KEY",
		Bytes: x509.MarshalPKCS1PrivateKey(rsaKey),
	})
	return
}

func (e *Enricher) setDNSDomain(ctx context.Context, cluster *models.Cluster) error {
	if cluster.DNS.Domain != "" {
		return nil
	}
	domain, err := e.getDNSDomain(ctx)
	if err != nil {
		return fmt.Errorf("failed to get DNS domain: %v", err)
	}
	e.logger.V(1).Info(
		"DNS domain name",
		"domain", domain,
	)
	cluster.DNS.Domain = domain
	return nil
}

func (e *Enricher) getDNSDomain(ctx context.Context) (result string, err error) {
	// Get the domain name used by the default ingress controller:
	object := &unstructured.Unstructured{}
	object.SetGroupVersionKind(IngressControllerGVK)
	key := clnt.ObjectKey{
		Namespace: "openshift-ingress-operator",
		Name:      "default",
	}
	err = e.client.Get(ctx, key, object)
	if err != nil {
		return
	}
	var domain string
	err = e.jq.Query(`.status.domain`, object, &domain)

	// The domain name used by the ingress controller will be something like
	// `apps.my-cluster.my-domain.com` and we want to use only `my-domain.com` as the base
	// domain for the clusters that we create, so we need to remove the first two labels:
	labels := strings.Split(domain, ".")
	if len(labels) < 3 {
		err = fmt.Errorf(
			"failed to extract base DNS domain from ingress controller domain '%s' "+
				"because it only contains %d labels and at least 3 are required",
			domain, len(labels),
		)
		return
	}
	result = strings.Join(labels[2:], ".")

	return
}

func (e *Enricher) setImageSet(ctx context.Context, cluster *models.Cluster) error {
	if cluster.ImageSet != "" {
		return nil
	}
	value, ok := e.env["CLUSTERIMAGESET"]
	if !ok {
		return fmt.Errorf("environment variable 'CLUSTERIMAGESET' isn't set")
	}
	e.logger.V(1).Info(
		"Loaded cluster image set",
		"value", value,
	)
	cluster.ImageSet = value
	return nil
}

func (e *Enricher) setVIPs(ctx context.Context, cluster *models.Cluster) error {
	if cluster.SNO {
		return nil
	}
	if cluster.API.VIP == "" {
		cluster.API.VIP = enricherAPIVIP.String()
	}
	if cluster.Ingress.VIP == "" {
		cluster.Ingress.VIP = enricherIngressVIP.String()
	}
	return nil
}

func (e *Enricher) setNetworks(ctx context.Context, cluster *models.Cluster) error {
	cluster.ClusterNetworks = []models.ClusterNetwork{{
		CIDR:       enricherClusterCIDR,
		HostPrefix: enricherHostPrefix,
	}}
	cluster.MachineNetworks = []models.MachineNetwork{{
		CIDR: enricherMachineCIDR,
	}}
	cluster.ServiceNetworks = []models.ServiceNetwork{{
		CIDR: enricherServiceCIDR,
	}}
	return nil
}

func (e *Enricher) setInternalIPs(ctx context.Context, cluster *models.Cluster) error {
	for i := range cluster.Nodes {
		err := e.setInternalIP(ctx, i, &cluster.Nodes[i])
		if err != nil {
			return err
		}
	}
	return nil
}

func (e *Enricher) setInternalIP(ctx context.Context, index int, node *models.Node) error {
	// Do nothing if the IP is already set:
	if node.InternalNIC.IP != nil {
		return nil
	}

	// For nodes of the cluster we want to assign IP addresses within the machine network
	// 192.168.7.0/24, starting with 192.168.7.10 for the first master node, 192.168.7.11 for
	// the second one, and so on.
	ip := slices.Clone(enricherMachineCIDR.IP)
	ip[len(ip)-1] = byte(10 + index)
	node.InternalNIC.IP = ip
	node.InternalNIC.Prefix, _ = enricherMachineCIDR.Mask.Size()

	return nil
}

// Hardcoded blocks of addresses used by the cluster, the machines and the services (assigned in the
// init function below).
var (
	enricherClusterCIDR *net.IPNet
	enricherMachineCIDR *net.IPNet
	enricherServiceCIDR *net.IPNet
)

// Hardcoded virtual IP addresses (assigned in the init function below).
var (
	enricherAPIVIP     net.IP
	enricherIngressVIP net.IP
)

// Harccoded prefix for the block of addressed assigned to the hosts of the cluster.
const enricherHostPrefix = 23

func init() {
	var err error

	// Parse the hardcoded CIDRs:
	_, enricherClusterCIDR, err = net.ParseCIDR("10.128.0.0/14")
	if err != nil {
		panic(err)
	}
	_, enricherMachineCIDR, err = net.ParseCIDR("192.168.7.0/24")
	if err != nil {
		panic(err)
	}
	_, enricherServiceCIDR, err = net.ParseCIDR("172.30.0.0/16")
	if err != nil {
		panic(err)
	}

	// Assign the virtual IP addresses, 192.168.7.242 for the API and 192.168.7.243 for the
	// ingress.
	enricherAPIVIP = slices.Clone(enricherMachineCIDR.IP)
	enricherAPIVIP[len(enricherAPIVIP)-1] = 242
	enricherIngressVIP = slices.Clone(enricherMachineCIDR.IP)
	enricherIngressVIP[len(enricherIngressVIP)-1] = 243
}

// enricherDefaultMirror is the debault base URL for downloading the `release.txt` files, used when
// the `OC_OCP_MIRROR` property isn't set.
const enricherDefaultMirror = "https://mirror.openshift.com/pub/openshift-v4/clients/ocp"

// enricherRHCOSReleaseRE is the regular expressions used by the enricher to extract the RHCOS
// release number for the OpenShift `release.txt` file. For example, if the file contains a line
// line this:
//
//	Component Versions:
//
//	  kubernetes 1.23.12
//	  machine-os 410.84.202210130022-0 Red Hat Enterprise Linux CoreOS
//
// It will extract the value `410.84.202210130022-0`.
var enricherRHCOSReleaseRE = regexp.MustCompile(
	`(?m:^\s*machine-os\s+(.*)\s+Red\s+Hat\s+Enterprise\s+Linux\s+CoreOS\s*$)`,
)
