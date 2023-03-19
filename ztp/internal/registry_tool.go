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
	"crypto/tls"
	"encoding/pem"
	"errors"
	"fmt"
	"net"

	"github.com/go-logr/logr"
	"github.com/imdario/mergo"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/jq"
	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"
)

// RegistryToolBuilder contains the data and logic needed to create an instance of the registry
// tool.  Don't create instances of this directly, use the NewRegistryTool function instead.
type RegistryToolBuilder struct {
	logger        logr.Logger
	client        *Client
	configName    string
	configmapName string
}

// RegistryTool is a tool that knows how to perform tasks related to image registries. For example,
// it knows how to add a trusted registry to an OpenShift cluster. Don't create instances of this
// directly, use the NewRegistryTool function instead.
type RegistryTool struct {
	logger        logr.Logger
	client        *Client
	configName    string
	configmapName string
	jq            *jq.Tool
}

// NewRegistryTool creates a builder that can then be used to configure and create an instance of
// the registry tool.
func NewRegistryTool() *RegistryToolBuilder {
	return &RegistryToolBuilder{
		configName:    registryToolDefaultConfigName,
		configmapName: registryToolDefaultConfigmapName,
	}
}

// SetLogger sets the logger that the tool will use to write messages to the log. This is mandatory.
func (b *RegistryToolBuilder) SetLogger(value logr.Logger) *RegistryToolBuilder {
	b.logger = value
	return b
}

// SetClient sets the Kubernetes API client that the tool will use to interact with the cluster.
// This is mandatory.
func (b *RegistryToolBuilder) SetClient(value *Client) *RegistryToolBuilder {
	b.client = value
	return b
}

// SetConfigName sets the name of the image configuration object that will be updated. The default
// is to use `cluster` and there is usually no reason to change it, as that is the name used by
// OpenShift. This is intended for use in unit tests where it is convenient to use a different name.
func (b *RegistryToolBuilder) SetConfigName(value string) *RegistryToolBuilder {
	b.configName = value
	return b
}

// SetConfigmapName sets the name of the CA configmap object that will created if it doesn't exist.
// The default is to use the `registry-cas` and there is usually no reason to change it. This is
// intended for use in unit tests where it is convenient to use a different name.
func (b *RegistryToolBuilder) SetConfigmapName(value string) *RegistryToolBuilder {
	b.configmapName = value
	return b
}

// Build uses the data stored in the buider to create a new instance of the registry tool.
func (b *RegistryToolBuilder) Build() (result *RegistryTool, err error) {
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
	jqTool, err := jq.NewTool().
		SetLogger(b.logger).
		Build()
	if err != nil {
		err = fmt.Errorf("failed to create jq tool: %v", err)
		return
	}

	// Create and populate the object:
	result = &RegistryTool{
		logger:        b.logger,
		client:        b.client,
		configName:    b.configName,
		configmapName: b.configmapName,
		jq:            jqTool,
	}
	return
}

// AddTrustedRegistry sets the given server as an additional trusted registry.
func (t *RegistryTool) AddTrustedRegistry(ctx context.Context, server string, ca []byte) error {
	var err error

	// Fetch the CA for the sever if not explicitly passed:
	if ca == nil {
		ca, err = t.fetchCA(server)
		if err != nil {
			return err
		}
	}

	// Get the name of the configmap that is currently used for additional trusted registry
	// certificate authorities:
	configObject := &unstructured.Unstructured{}
	configObject.SetGroupVersionKind(ImageConfigGVK)
	configKey := clnt.ObjectKey{
		Name: t.configName,
	}
	err = t.client.Get(ctx, configKey, configObject)
	if err != nil {
		return err
	}
	var configmapName string
	err = t.jq.Query(`.spec.additionalTrustedCA.name`, configObject, &configmapName)
	if err != nil {
		return err
	}

	// If there are already additional trusted CAs then load them:
	var configmapData map[string]string
	configmapObject := &corev1.ConfigMap{}
	configmapKey := clnt.ObjectKey{
		Namespace: "openshift-config",
		Name:      configmapName,
	}
	if configmapName != "" {
		err = t.client.Get(ctx, configmapKey, configmapObject)
		switch {
		case err == nil:
			configmapData = configmapObject.Data
		case apierrors.IsNotFound(err):
		default:
			return err
		}
	}
	if configmapData == nil {
		configmapData = map[string]string{}
	}

	// Check if our registry is already in the list:
	serverKey, err := t.configKey(server)
	if err != nil {
		return err
	}
	serverCA, ok := configmapData[serverKey]
	if ok && bytes.Equal(ca, []byte(serverCA)) {
		t.logger.Info(
			"Trusted registry is already configured",
			"registry", server,
		)
		return nil
	}

	// Create or update the configmap containing the additional trusted registry certificates:
	if configmapObject.CreationTimestamp.IsZero() {
		configmapObject.Namespace = "openshift-config"
		configmapObject.Name = t.configmapName
		configmapObject.Data = map[string]string{
			serverKey: string(ca),
		}
		err = t.client.Create(ctx, configmapObject)
		if err != nil {
			return err
		}
		t.logger.Info(
			"Created trusted registry configmap",
			"registry", server,
			"configmap", configmapKey,
		)
	} else {
		configmapUpdate := configmapObject.DeepCopy()
		if configmapUpdate.Data == nil {
			configmapUpdate.Data = map[string]string{}
		}
		configmapUpdate.Data[serverKey] = string(ca)
		err = t.client.Patch(ctx, configmapUpdate, clnt.MergeFrom(configmapObject))
		if err != nil {
			return err
		}
		t.logger.Info(
			"Updated trusted registry configmap",
			"registry", server,
			"configmap", configmapKey,
		)
	}

	// Update the image configuration:
	if configmapName != configmapObject.GetName() {
		imageConfigUpdate := configObject.DeepCopy()
		err = mergo.MergeWithOverwrite(&imageConfigUpdate.Object, map[string]any{
			"spec": map[string]any{
				"additionalTrustedCA": map[string]any{
					"name": configmapObject.GetName(),
				},
			},
		})
		if err != nil {
			return err
		}
		err = t.client.Patch(ctx, imageConfigUpdate, clnt.MergeFrom(configObject))
		if err != nil {
			return err
		}
		t.logger.Info(
			"Updated image configuration to trust registry",
			"registry", server,
		)
	}

	return nil
}

// configKey calculates the key that is used in the configmap that contains the certificates of the
// additional trusted registries. This key is the registry host followed by two dots and the port
// number. These two dots and the port number are optional and only used when the port isn't 443.
// For example, if the server address is `my.registry.com:5000` then the key is
// `my.registry.com..5000`.
func (t *RegistryTool) configKey(address string) (result string, err error) {
	host, port, err := net.SplitHostPort(address)
	if t.isMissingPort(err) {
		result = address
		err = nil
		return
	}
	if err != nil {
		return
	}
	if port == "443" {
		result = host
	} else {
		result = fmt.Sprintf("%s..%s", host, port)
	}
	return
}

// fetchCA fetches the CA certificate from the given address.
func (t *RegistryTool) fetchCA(address string) (result []byte, err error) {
	// Set the default port:
	_, _, err = net.SplitHostPort(address)
	if t.isMissingPort(err) {
		address += ":443"
	}

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

func (t *RegistryTool) isMissingPort(err error) bool {
	addrErr, ok := err.(*net.AddrError)
	if ok {
		return addrErr.Err == "missing port in address"
	}
	return false
}

// Default values:
const (
	registryToolDefaultConfigName    = "cluster"
	registryToolDefaultConfigmapName = "registry-cas"
)
