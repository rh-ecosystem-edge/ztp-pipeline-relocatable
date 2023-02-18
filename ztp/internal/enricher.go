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
	"bytes"
	"context"
	"crypto/rand"
	"crypto/rsa"
	"crypto/tls"
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
	"golang.org/x/exp/slices"
	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/jq"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/models"
)

// EnricherBuilder contains the data and logic needed to create an object that knows how to add
// information to the description of a cluster. Don't create instances of this type directly, use
// the NewEnricher function instead.
type EnricherBuilder struct {
	logger logr.Logger
	client clnt.Client
}

// Enricher knows how to add information to the description of a cluster. Don't create instances of
// this type directly, use the NewEnricher function instead.
type Enricher struct {
	logger logr.Logger
	client clnt.Client
	jq     *jq.Tool
}

// NewEnricher creates a builder that can then be used to create an object that knows how to add
// information to the description of a cluster.
func NewEnricher() *EnricherBuilder {
	return &EnricherBuilder{}
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
	jq, err := jq.NewTool().
		SetLogger(b.logger).
		Build()
	if err != nil {
		err = fmt.Errorf("failed to create jq tool: %v", err)
		return
	}

	// Create and populate the object:
	result = &Enricher{
		logger: b.logger,
		client: b.client,
		jq:     jq,
	}
	return
}

// Enrich completes the configuration adding the information that will be required later to create
// the clusters.
func (e *Enricher) Enrich(ctx context.Context, config *models.Config) error {
	err := e.enrichConfig(ctx, config)
	if err != nil {
		return err
	}
	for _, cluster := range config.Clusters {
		err := e.enrichCluster(ctx, config, cluster)
		if err != nil {
			return err
		}
	}
	return nil
}

func (e *Enricher) enrichConfig(ctx context.Context, config *models.Config) error {
	setters := []func(context.Context, *models.Config) error{
		e.setOCPTag,
		e.setRHCOSRelease,
		e.setConfigImageSet,
	}
	for _, setter := range setters {
		err := setter(ctx, config)
		if err != nil {
			return err
		}
	}
	return nil
}

func (e *Enricher) setOCPTag(ctx context.Context, config *models.Config) error {
	// Do nothing if already set:
	ocpTag := config.Properties[models.OCPTagProperty]
	if ocpTag != "" {
		return nil
	}

	// Check that the version has been specified:
	ocpVersion := config.Properties[models.OCPVersionProperty]
	if ocpVersion == "" {
		return fmt.Errorf(
			"failed to set OCP tag because property '%s' hasn't been specified",
			models.OCPVersionProperty,
		)
	}

	// Calculate the tag:
	ocpTag = fmt.Sprintf("%s-x86_64", ocpVersion)

	// Update the properties:
	config.Properties[models.OCPTagProperty] = ocpTag
	e.logger.V(2).Info(
		"Set OCP tag property",
		"name", models.OCPTagProperty,
		"value", ocpTag,
	)
	return nil
}

func (e *Enricher) setRHCOSRelease(ctx context.Context, config *models.Config) error {
	// Do nothing if it is already set:
	rhcosRelease := config.Properties[models.OCPRCHOSReleaseProperty]
	if rhcosRelease != "" {
		return nil
	}

	// Check that the version has been specified:
	ocpVersion := config.Properties[models.OCPVersionProperty]
	if ocpVersion == "" {
		return fmt.Errorf(
			"failed to set RHCOS release because property '%s' hasn't been specified",
			models.OCPVersionProperty,
		)
	}

	// Download the `release.txt` file:
	releaseTXT, err := e.downloadReleaseTXT(ctx, config)
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
	config.Properties[models.OCPRCHOSReleaseProperty] = rchosRelease
	e.logger.Info(
		"Set RHCOS release property",
		"name", models.OCPRCHOSReleaseProperty,
		"value", rchosRelease,
	)

	return nil
}

func (e *Enricher) downloadReleaseTXT(ctx context.Context, config *models.Config) (result string,
	err error) {
	mirror := config.Properties[models.OCPMirrorProperty]
	if mirror == "" {
		mirror = enricherDefaultMirror
	}
	version := config.Properties[models.OCPVersionProperty]
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

func (e *Enricher) setConfigImageSet(ctx context.Context, config *models.Config) error {
	// Do nothing if it is already set:
	imageSet := config.Properties[models.ClusterImageSetProperty]
	if imageSet != "" {
		return nil
	}

	// Check that the OCM version is set:
	ocpVersion := config.Properties[models.OCPVersionProperty]
	if ocpVersion == "" {
		return fmt.Errorf(
			"failed to set image set release because property '%s' hasn't been "+
				"specified",
			models.OCPVersionProperty,
		)
	}

	// Calculate the default value and save
	imageSet = fmt.Sprintf("openshift-v%s", ocpVersion)
	config.Properties[models.ClusterImageSetProperty] = imageSet
	e.logger.Info(
		"Set image set property",
		"name", models.ClusterImageSetProperty,
		"value", imageSet,
	)

	return nil
}

func (e *Enricher) enrichCluster(ctx context.Context, config *models.Config,
	cluster *models.Cluster) error {
	setters := []func(context.Context, *models.Config, *models.Cluster) error{
		e.setSNO,
		e.setPullSecret,
		e.setSSHKeys,
		e.setDNSDomain,
		e.setVIPs,
		e.setNetworks,
		e.setInternalIPs,
		e.setExternalIPs,
		e.setKubeconfig,
		e.setClusterImageSet,
		e.setClusterRegistryURL,
		e.setClusterRegistryCA,
	}
	for _, setter := range setters {
		err := setter(ctx, config, cluster)
		if err != nil {
			return err
		}
	}
	return nil
}

func (e *Enricher) setSNO(ctx context.Context, config *models.Config,
	cluster *models.Cluster) error {
	count := 0
	for _, node := range cluster.Nodes {
		if node.Kind == models.NodeKindControlPlane {
			count++
		}
	}
	cluster.SNO = count == 1
	return nil
}

func (e *Enricher) setPullSecret(ctx context.Context, config *models.Config,
	cluster *models.Cluster) error {
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

func (e *Enricher) setSSHKeys(ctx context.Context, config *models.Config,
	cluster *models.Cluster) error {
	// Do nothing if the keys are already set:
	if cluster.SSH.PublicKey != nil && cluster.SSH.PrivateKey != nil {
		return nil
	}

	// Check if the secret containing the keys has already been created:
	secret := &corev1.Secret{}
	key := clnt.ObjectKey{
		Namespace: cluster.Name,
		Name:      fmt.Sprintf("%s-keypair", cluster.Name),
	}
	err := e.client.Get(ctx, key, secret)
	switch {
	case err == nil:
		cluster.SSH.PublicKey = secret.Data["id_rsa.pub"]
		cluster.SSH.PrivateKey = secret.Data["id_rsa.key"]
		e.logger.V(1).Info(
			"Found SSH keys",
			"cluster", cluster.Name,
			"secret", fmt.Sprintf("%s/%s", secret.Namespace, secret.Name),
		)
	case apierrors.IsNotFound(err):
		cluster.SSH.PublicKey, cluster.SSH.PrivateKey, err = e.generateSSHKeys()
		e.logger.V(1).Info(
			"Generated SSH keys",
			"cluster", cluster.Name,
		)
	}
	return err
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

func (e *Enricher) setDNSDomain(ctx context.Context, config *models.Config,
	cluster *models.Cluster) error {
	if cluster.DNS.Domain != "" {
		return nil
	}
	domain, err := e.getDNSDomain(ctx)
	if err != nil {
		return fmt.Errorf("failed to get DNS domain: %v", err)
	}
	e.logger.V(1).Info(
		"Found DNS domain",
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

func (e *Enricher) setVIPs(ctx context.Context, config *models.Config,
	cluster *models.Cluster) error {
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

func (e *Enricher) setNetworks(ctx context.Context, config *models.Config,
	cluster *models.Cluster) error {
	cluster.ClusterNetworks = []*models.ClusterNetwork{{
		CIDR:       enricherClusterCIDR,
		HostPrefix: enricherHostPrefix,
	}}
	cluster.MachineNetworks = []*models.MachineNetwork{{
		CIDR: enricherMachineCIDR,
	}}
	cluster.ServiceNetworks = []*models.ServiceNetwork{{
		CIDR: enricherServiceCIDR,
	}}
	return nil
}

func (e *Enricher) setInternalIPs(ctx context.Context, config *models.Config,
	cluster *models.Cluster) error {
	for i, node := range cluster.Nodes {
		err := e.setInternalIP(ctx, i, node)
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

func (e *Enricher) setExternalIPs(ctx context.Context, config *models.Config,
	cluster *models.Cluster) error {
	// Fetch the agents for the nodes of the cluster:
	agents := &unstructured.UnstructuredList{}
	agents.SetGroupVersionKind(AgentListGVK)
	err := e.client.List(ctx, agents, clnt.InNamespace(cluster.Name))
	if err != nil {
		return err
	}

	// Index the IP addresses by MAC address:
	index := map[string]string{}
	type Pair struct {
		MAC string `json:"mac"`
		IP  string `json:"ip"`
	}
	for _, agent := range agents.Items {
		var pairs []Pair
		err = e.jq.Query(
			`
				try
				.status.inventory.interfaces[] |
				{ "mac": .macAddress, "ip": .ipV4Addresses[0] }
			`,
			agent.Object, &pairs,
		)
		if err != nil {
			return err
		}
		for _, pair := range pairs {
			if pair.MAC != "" && pair.IP != "" {
				index[strings.ToLower(pair.MAC)] = pair.IP
			}
		}
	}

	// Find the IP address for each external interface:
	for _, node := range cluster.Nodes {
		if node.ExternalNIC.IP != nil {
			continue
		}
		mac := node.ExternalNIC.MAC
		ip, ok := index[strings.ToLower(mac)]
		if ok {
			e.logger.V(1).Info(
				"Found external IP address for node",
				"cluster", cluster.Name,
				"node", node.Name,
				"mac", mac,
				"ip", ip,
			)
			node.ExternalNIC.IP, _, err = net.ParseCIDR(ip)
			if err != nil {
				return err
			}
		}
	}

	return nil
}

func (e *Enricher) setKubeconfig(ctx context.Context, config *models.Config,
	cluster *models.Cluster) error {
	if cluster.Kubeconfig != nil {
		return nil
	}
	secret := &corev1.Secret{}
	key := clnt.ObjectKey{
		Namespace: cluster.Name,
		Name:      fmt.Sprintf("%s-admin-kubeconfig", cluster.Name),
	}
	err := e.client.Get(ctx, key, secret)
	if apierrors.IsNotFound(err) {
		return nil
	}
	if err != nil {
		return err
	}
	data, ok := secret.Data["kubeconfig"]
	if ok {
		cluster.Kubeconfig = data
		e.logger.V(1).Info(
			"Found kubeconfig",
			"cluster", cluster.Name,
		)
	}
	return nil
}

func (e *Enricher) setClusterImageSet(ctx context.Context, config *models.Config,
	cluster *models.Cluster) error {
	// Do nothing if it is already set:
	if cluster.ImageSet != "" {
		return nil
	}

	// Check that the value is in the properties:
	imageSet := config.Properties[models.ClusterImageSetProperty]
	if imageSet == "" {
		return fmt.Errorf(
			"failed to set image set for cluster '%s' because image set property '%s' "+
				"hasn't been specified",
			cluster.Name, models.ClusterImageSetProperty,
		)
	}

	// Set the value:
	cluster.ImageSet = imageSet
	e.logger.Info(
		"Set cluster image set",
		"value", imageSet,
	)

	return nil
}

func (e *Enricher) setClusterRegistryURL(ctx context.Context, config *models.Config,
	cluster *models.Cluster) error {
	// Do nothing if it is already set:
	if cluster.Registry.URL != "" {
		return nil
	}

	// Do nothing if there isn't a custom registry in the configuration:
	registry := config.Properties[models.RegistryProperty]
	if registry == "" {
		return nil
	}

	// Set the value:
	cluster.Registry.URL = registry
	e.logger.Info(
		"Set cluster registry URL",
		"value", registry,
	)

	return nil
}

func (e *Enricher) setClusterRegistryCA(ctx context.Context, config *models.Config,
	cluster *models.Cluster) error {
	// Do nothing if it is already set:
	if cluster.Registry.CA != nil {
		return nil
	}

	// Do nothing if the URL isn't set:
	if cluster.Registry.URL == "" {
		return nil
	}

	// Set the value:
	ca, err := e.getCA(cluster.Registry.URL)
	if err != nil {
		return fmt.Errorf(
			"failed to get registry CA certificates for registry '%s' of "+
				"cluster '%s': %v",
			cluster.Registry.URL, cluster.Name, err,
		)
	}
	cluster.Registry.CA = ca
	e.logger.Info(
		"Set cluster registry CA",
		"value", string(ca),
	)

	return nil
}

func (e *Enricher) getCA(address string) (result []byte, err error) {
	// Connect to the server and do the TLS handshake to obtain the certificate chain:
	conn, err := tls.Dial("tcp", address, &tls.Config{
		InsecureSkipVerify: true,
	})
	if err != nil {
		return
	}
	defer conn.Close()
	certs := conn.ConnectionState().PeerCertificates

	// Serialize the certificates:
	buffer := &bytes.Buffer{}
	for _, cert := range certs {
		err = pem.Encode(buffer, &pem.Block{
			Type:  "CERTIFICATE",
			Bytes: cert.Raw,
		})
		if err != nil {
			return
		}
	}
	result = buffer.Bytes()

	return
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

// enricherDefaultMirror is the default base URL for downloading the `release.txt` files, used when
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
