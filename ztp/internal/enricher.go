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
	"encoding/base64"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/go-logr/logr"
	"github.com/spf13/pflag"
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
	logger   logr.Logger
	client   clnt.Client
	resolver string
}

// Enricher knows how to add information to the description of a cluster. Don't create instances of
// this type directly, use the NewEnricher function instead.
type Enricher struct {
	logger   logr.Logger
	client   clnt.Client
	jq       *jq.Tool
	resolver *net.Resolver
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

// SetResolver sets the IP address and port number of DNS server that the enricher will resolve
// names, for example `127.0.0.1:53`. There is usually no need to change this, it is intended for
// use in unit tests.
func (b *EnricherBuilder) SetResolver(value string) *EnricherBuilder {
	b.resolver = value
	return b
}

// SetFlags sets the command line flags that that indicate how to configure the enricher. This is
// optional.
func (b *EnricherBuilder) SetFlags(flags *pflag.FlagSet) *EnricherBuilder {
	if flags.Changed(enricherResolverFlagName) {
		value, err := flags.GetString(enricherResolverFlagName)
		if err == nil {
			b.resolver = value
		}
	}
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

	// Create the jq tool:
	jq, err := jq.NewTool().
		SetLogger(b.logger).
		Build()
	if err != nil {
		err = fmt.Errorf("failed to create jq tool: %w", err)
		return
	}

	// Set the default resolver if needed:
	var resolver *net.Resolver
	if b.resolver != "" {
		resolver, err = b.createResolver(b.resolver)
		if err != nil {
			err = fmt.Errorf("failed to create resolver: %w", err)
			return
		}
	}

	// Create and populate the object:
	result = &Enricher{
		logger:   b.logger,
		client:   b.client,
		jq:       jq,
		resolver: resolver,
	}
	return
}

func (b *EnricherBuilder) createResolver(address string) (result *net.Resolver, err error) {
	dialer := &net.Dialer{
		Timeout: 5 * time.Second,
	}
	result = &net.Resolver{
		PreferGo: true,
		Dial: func(ctx context.Context, network string,
			_ string) (conn net.Conn, err error) {
			conn, err = dialer.DialContext(ctx, network, address)
			return
		},
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
		e.setConfigRegistry,
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
	e.logger.Info(
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
	e.logger.Info(
		"Downloaded release file",
		"url", url,
	)
	e.logger.V(2).Info(
		"Release file content",
		"content", string(result),
	)
	return
}

func (e *Enricher) setConfigImageSet(ctx context.Context, config *models.Config) error {
	// Do nothing if it is already set:
	imageSet := config.Properties[models.ClusterImageSetProperty]
	if imageSet != "" {
		return nil
	}

	// Check that the OCP version is set:
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

func (e *Enricher) setConfigRegistry(ctx context.Context, config *models.Config) error {
	// Do nothing if it is already set:
	registry := config.Properties[models.RegistryProperty]
	if registry != "" {
		return nil
	}

	// Get the default registry URL from the configuration of the registry:
	registryConfig := &corev1.ConfigMap{}
	registryKey := clnt.ObjectKey{
		Namespace: "ztpfw-registry",
		Name:      "ztpfw-config",
	}
	err := e.client.Get(ctx, registryKey, registryConfig)
	if apierrors.IsNotFound(err) {
		return nil
	}
	if err != nil {
		return err
	}
	uriData, ok := registryConfig.Data["uri"]
	if !ok {
		return fmt.Errorf(
			"failed to find registry URI because configmap '%s/%s' doesn't have the "+
				"'uri' key",
			registryConfig.Namespace, registryConfig.Name,
		)
	}
	uriBytes, err := base64.StdEncoding.DecodeString(uriData)
	if err != nil {
		return fmt.Errorf(
			"failed to decode registry URI '%s': %w",
			string(uriBytes), err,
		)
	}
	uriText := strings.TrimSpace(string(uriBytes))

	// Save the value:
	config.Properties[models.RegistryProperty] = uriText
	e.logger.Info(
		"Set registry property",
		"name", models.RegistryProperty,
		"value", uriText,
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
		e.setInternalAPIIP,
		e.setInternalIngressIP,
		e.setNetworks,
		e.setInternalNodeIPs,
		e.setExternalNodeIPs,
		e.setKubeconfig,
		e.setClusterImageSet,
		e.setClusterRegistryURL,
		e.setClusterRegistryCA,
		e.setHostnames,
		e.setExternalAPIIP,
		e.setExternalIngressIP,
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
		return fmt.Errorf("failed to get pull secret: %w", err)
	}
	data, ok := secret.Data[".dockerconfigjson"]
	if !ok {
		return fmt.Errorf("pull secret doesn't contain the '.dockerconfigjson' key")
	}
	cluster.PullSecret = data
	e.logger.Info(
		"Loaded pull secret",
		"secret", fmt.Sprintf("%s/%s", secret.Namespace, secret.Name),
		"!content", string(cluster.PullSecret),
	)
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
		e.logger.Info(
			"Loaded SSH keys",
			"cluster", cluster.Name,
			"secret", fmt.Sprintf("%s/%s", secret.Namespace, secret.Name),
			"public", string(cluster.SSH.PublicKey),
			"!private", string(cluster.SSH.PrivateKey),
		)
	case apierrors.IsNotFound(err):
		cluster.SSH.PublicKey, cluster.SSH.PrivateKey, err = e.generateSSHKeys()
		e.logger.Info(
			"Generated SSH keys",
			"cluster", cluster.Name,
			"public", string(cluster.SSH.PublicKey),
			"!private", string(cluster.SSH.PrivateKey),
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
		return fmt.Errorf("failed to get DNS domain: %w", err)
	}
	e.logger.Info(
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
	if err != nil {
		return
	}

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

func (e *Enricher) setInternalAPIIP(ctx context.Context, config *models.Config,
	cluster *models.Cluster) error {
	if cluster.API.InternalIP != nil {
		return nil
	}
	cluster.API.InternalIP = enricherInternalAPIIP
	e.logger.Info(
		"Found internal API IP",
		"value", cluster.API.InternalIP,
	)
	return nil
}

func (e *Enricher) setInternalIngressIP(ctx context.Context, config *models.Config,
	cluster *models.Cluster) error {
	if cluster.Ingress.InternalIP != nil {
		return nil
	}
	cluster.Ingress.InternalIP = enricherInternalIngressIP
	e.logger.Info(
		"Found internal ingress IP",
		"value", cluster.Ingress.InternalIP,
	)
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

func (e *Enricher) setInternalNodeIPs(ctx context.Context, config *models.Config,
	cluster *models.Cluster) error {
	for i, node := range cluster.Nodes {
		err := e.setInternalNodeIP(ctx, i, node)
		if err != nil {
			return err
		}
	}
	return nil
}

func (e *Enricher) setInternalNodeIP(ctx context.Context, index int, node *models.Node) error {
	// Do nothing if the IP is already set:
	if node.InternalIP != nil {
		return nil
	}

	// For nodes of the cluster we want to assign IP addresses within the machine network
	// 192.168.7.0/24, starting with 192.168.7.10 for the first master node, 192.168.7.11 for
	// the second one, and so on.
	address := slices.Clone(enricherMachineCIDR.IP)
	address[len(address)-1] = byte(10 + index)
	prefix, _ := enricherMachineCIDR.Mask.Size()
	node.InternalIP = &models.IP{
		Address: address,
		Prefix:  prefix,
	}

	return nil
}

func (e *Enricher) setExternalNodeIPs(ctx context.Context, config *models.Config,
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
				.status.inventory.interfaces[]? |
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

	// Find the external IP addresses of the nodes:
	for _, node := range cluster.Nodes {
		if node.ExternalNIC == nil {
			continue
		}
		if node.ExternalIP != nil {
			continue
		}
		mac := node.ExternalNIC.MAC
		ip, ok := index[strings.ToLower(mac)]
		if ok {
			e.logger.Info(
				"Found external IP address for node",
				"cluster", cluster.Name,
				"node", node.Name,
				"mac", mac,
				"ip", ip,
			)
			node.ExternalIP, err = models.ParseIP(ip)
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
		e.logger.Info(
			"Loaded kubeconfig",
			"cluster", cluster.Name,
			"secret", fmt.Sprintf("%s/%s", secret.Namespace, secret.Name),
			"!content", string(cluster.Kubeconfig),
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

	// The registry URL may not contain a port number, but it is required to connect with TLS
	// and obtain the CA certificates, so we need to add a default:
	uri := cluster.Registry.URL
	colon := strings.LastIndex(uri, ":")
	if colon == -1 {
		uri = fmt.Sprintf("%s:443", uri)
	}

	// Set the value:
	ca, err := e.getCA(uri)
	if err != nil {
		return fmt.Errorf(
			"failed to get registry CA certificates for registry '%s' of "+
				"cluster '%s': %w",
			uri, cluster.Name, err,
		)
	}
	cluster.Registry.CA = ca
	e.logger.Info("Found cluster registry CA")
	e.logger.V(2).Info(
		"Cluster registry CA content",
		"content", string(cluster.Registry.CA),
	)
	return nil
}

func (e *Enricher) setExternalAPIIP(ctx context.Context, config *models.Config,
	cluster *models.Cluster) error {
	// Do nothing if the IP is already set:
	if cluster.API.ExternalIP != nil {
		return nil
	}

	// Check that the DNS domain is set:
	if cluster.DNS.Domain == "" {
		return fmt.Errorf("failed to set external API IP because DNS domain isn't set")
	}

	// Try to find the IP address for the domain:
	domain := fmt.Sprintf("api.%s.%s", cluster.Name, cluster.DNS.Domain)
	address, err := e.resolveDomain(ctx, domain)
	if err != nil {
		return err
	}
	cluster.API.ExternalIP = net.ParseIP(address)
	e.logger.Info(
		"Found external API IP",
		"value", cluster.API.ExternalIP,
	)

	return nil
}

func (e *Enricher) setExternalIngressIP(ctx context.Context, config *models.Config,
	cluster *models.Cluster) error {
	// Do nothing if the IP is already set:
	if cluster.Ingress.ExternalIP != nil {
		return nil
	}

	// Check that the DNS domain is set:
	if cluster.DNS.Domain == "" {
		return fmt.Errorf("failed to set external ingress IP because DNS domain isn't set")
	}

	// Try to find the IP address for the domain:
	domain := fmt.Sprintf("apps.%s.%s", cluster.Name, cluster.DNS.Domain)
	address, err := e.resolveDomain(ctx, domain)
	if err != nil {
		return err
	}
	cluster.Ingress.ExternalIP = net.ParseIP(address)
	e.logger.Info(
		"Found external ingress IP",
		"value", cluster.Ingress.ExternalIP,
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

func (e *Enricher) setHostnames(ctx context.Context, config *models.Config,
	cluster *models.Cluster) error {
	for _, node := range cluster.Nodes {
		err := e.setHostname(ctx, config, cluster, node)
		if err != nil {
			return err
		}
	}
	return nil
}

func (e *Enricher) setHostname(ctx context.Context, config *models.Config,
	cluster *models.Cluster, node *models.Node) error {
	if node.Hostname != "" {
		return nil
	}
	var kind string
	switch node.Kind {
	case models.NodeKindControlPlane:
		kind = "master"
	case models.NodeKindWorker:
		kind = "worker"
	default:
		return fmt.Errorf(
			"failed to set hostname for node '%s' of cluster '%s' because node "+
				"kind '%s' is unknown",
			node.Name, cluster.Name, node.Kind,
		)
	}
	node.Hostname = fmt.Sprintf("ztpfw-%s-%s-%s", cluster.Name, kind, node.Index())
	return nil
}

func (e *Enricher) resolveDomain(ctx context.Context, domain string) (result string, err error) {
	// First try to use the default resolver:
	resolver := e.resolver
	if resolver == nil {
		resolver = net.DefaultResolver
	}
	addresses, err := resolver.LookupHost(ctx, domain)
	if err == nil {
		result = addresses[0]
		e.logger.V(1).Info(
			"Default resolver succeeded",
			"domain", domain,
			"address", result,
		)
		return
	}
	e.logger.V(1).Info(
		"Default resolver failed",
		"domain", domain,
		"error", err,
	)

	// Find the IP addresses of the nodes of the hub:
	nodes := &corev1.NodeList{}
	err = e.client.List(ctx, nodes)
	if err != nil {
		return
	}
	var servers []string
	err = e.jq.Query(
		`.items[].status.addresses[] | select(.type == "InternalIP") | .address`,
		nodes, &servers,
	)
	if err != nil {
		return
	}

	// Try with each of the IP addresses of the nodes of the hub:
	dialer := &net.Dialer{}
	for _, server := range servers {
		resolver := &net.Resolver{
			PreferGo: true,
			Dial: func(ctx context.Context, network string,
				address string) (conn net.Conn, err error) {
				conn, err = dialer.DialContext(
					ctx,
					network,
					net.JoinHostPort(server, "53"),
				)
				return
			},
		}
		var addresses []string
		addresses, err = resolver.LookupHost(ctx, domain)
		if err == nil {
			result = addresses[0]
			e.logger.V(1).Info(
				"Node resolver succeeded",
				"server", server,
				"domain", domain,
				"address", result,
			)
			return
		}
		e.logger.V(1).Info(
			"Node resolver failed",
			"server", server,
			"domain", domain,
			"error", err,
		)
	}

	// If we are here we failed to resolve:
	err = fmt.Errorf("failed to resolve domain '%s'", domain)
	return
}

// Hardcoded blocks of addresses used by the cluster, the machines and the services (assigned in the
// init function below).
var (
	enricherClusterCIDR *net.IPNet
	enricherMachineCIDR *net.IPNet
	enricherServiceCIDR *net.IPNet
)

// Hardcoded internal API and ingress IP addresses (assigned in the init function below).
var (
	enricherInternalAPIIP     net.IP
	enricherInternalIngressIP net.IP
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

	// Assign the internal IP addresses, 192.168.7.242 for the ingress and 192.168.7.243 for the
	// API.
	enricherInternalIngressIP = slices.Clone(enricherMachineCIDR.IP)
	enricherInternalIngressIP[len(enricherInternalIngressIP)-1] = 242
	enricherInternalAPIIP = slices.Clone(enricherMachineCIDR.IP)
	enricherInternalAPIIP[len(enricherInternalAPIIP)-1] = 243
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
