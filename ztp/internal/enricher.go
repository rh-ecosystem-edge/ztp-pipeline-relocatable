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
	"os"
	"regexp"

	"github.com/go-logr/logr"
	"golang.org/x/crypto/ssh"
	"golang.org/x/exp/maps"
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
	file, ok := e.env["PULL_SECRET"]
	if !ok {
		return fmt.Errorf("environment variable 'PULL_SECRET' isn't set")
	}
	data, err := os.ReadFile(file)
	if err != nil {
		return fmt.Errorf(
			"failed to load pull secret from file '%s': %v",
			file, err,
		)
	}
	e.logger.V(1).Info(
		"Loaded pull secret",
		"file", file,
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
	err = e.jq.Query(`.status.domain`, object, &result)
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
	if !cluster.SNO {
		return nil
	}
	cluster.API.VIP = hardcodedAPIVIP
	cluster.Ingress.VIP = hardcodedIngressVIP
	return nil
}

func (e *Enricher) setNetworks(ctx context.Context, cluster *models.Cluster) error {
	_, clusterNetworkCIDR, err := net.ParseCIDR(hardcodedClusterNetworkCIDR)
	if err != nil {
		return fmt.Errorf("failed to parse cluster network CIDR: %v", err)
	}
	cluster.ClusterNetworks = []models.ClusterNetwork{{
		CIDR:       clusterNetworkCIDR,
		HostPrefix: hardcodedClusterNetworkHostPrefix,
	}}

	_, machineNetworkCIDR, err := net.ParseCIDR(hardcodedClusterNetworkCIDR)
	if err != nil {
		return fmt.Errorf("failed to parse machine network CIDR: %v", err)
	}
	cluster.MachineNetworks = []models.MachineNetwork{{
		CIDR: machineNetworkCIDR,
	}}

	_, serviceNetworkCIDR, err := net.ParseCIDR(hardcodedServiceNetworkCIDR)
	if err != nil {
		return fmt.Errorf("failed to parse service network CIDR: %v", err)
	}
	cluster.ServiceNetworks = []models.ServiceNetwork{{
		CIDR: serviceNetworkCIDR,
	}}

	return nil
}

const (
	hardcodedAPIVIP                   = "192.168.7.243"
	hardcodedIngressVIP               = "192.168.7.242"
	hardcodedClusterNetworkHostPrefix = 23
	hardcodedClusterNetworkCIDR       = "10.128.0.0/14"
	hardcodedMachineNetworkCIDR       = "192.168.7.0/24"
	hardcodedServiceNetworkCIDR       = "172.30.0.0/16"
)

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
