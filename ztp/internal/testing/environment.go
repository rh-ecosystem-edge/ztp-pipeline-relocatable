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
	"bufio"
	"bytes"
	"context"
	"crypto/x509/pkix"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"

	dockertypes "github.com/docker/docker/api/types"
	dockercontainer "github.com/docker/docker/api/types/container"
	dockerfilters "github.com/docker/docker/api/types/filters"
	docker "github.com/docker/docker/client"
	dockerstdcopy "github.com/docker/docker/pkg/stdcopy"
	dockernat "github.com/docker/go-connections/nat"
	"github.com/go-logr/logr"
	"k8s.io/client-go/tools/clientcmd"
	clientcmdapi "k8s.io/client-go/tools/clientcmd/api"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"
)

// EnvironmentBuilder contains the data and logic to create a Kubernetes API testing environment.
// Don't create instances of this type directly, use the NewEnvironment function instead.
type EnvironmentBuilder struct {
	logger logr.Logger
	name   string
}

// Environment is a Kubernetes API testing environment. Don't create instances of this type
// directly, use the NewEnvironment function instead.
type Environment struct {
	logger       logr.Logger
	name         string
	ca           *environmentCA
	apiKeyPEM    []byte
	apiCrtPEM    []byte
	adminKeyPEM  []byte
	adminCrtPEM  []byte
	sasKeyPEM    []byte
	sasCrtPEM    []byte
	dockerClient *docker.Client
	etcdCont     *environmentContainer
	apiCont      *environmentContainer
	tmpDirs      []string
}

// environmentContainer contains information about the containers created by the testing
// environment.
type environmentContainer struct {
	id   string
	name string
	ip   string
	addr string
}

// NewEnvironment creates a builder that can then be used to configure and create a Kubernetes API
// testing environment. This runs a minimal setup of etcd and a Kubernetes API server in containers
// without the rest of the components of the cluster.
func NewEnvironment() *EnvironmentBuilder {
	return &EnvironmentBuilder{}
}

// SetLogger sets the logger that will be used to write to the log. This is mandatory.
func (b *EnvironmentBuilder) SetLogger(value logr.Logger) *EnvironmentBuilder {
	b.logger = value
	return b
}

// SetName sets the name of the environment. It will be used as a prefix for the names of the
// containers and other objects created. For example, if the values is `my` then the name of the API
// server container will be `my-api`. This is mandatory.
func (b *EnvironmentBuilder) SetName(value string) *EnvironmentBuilder {
	b.name = value
	return b
}

// Build uses the data stored in the builder to create and configure a new Kubernetes API testing
// environment. Note that this creates the environment but doesn't start it. To start it use the
// Start method of the returned object, and remember to call the Stop method when the environment is
// no longer needed.
func (b *EnvironmentBuilder) Build() (result *Environment, err error) {
	// Check parameters:
	if b.logger.GetSink() == nil {
		err = errors.New("logger is mandatory")
		return
	}
	if b.name == "" {
		err = errors.New("name is mandatory")
		return
	}

	// Create the CA:
	ca, err := b.createCA()
	if err != nil {
		err = fmt.Errorf("failed to create CA: %v", err)
		return
	}

	// Create the admin certificate:
	adminKeyPEM, adminCrtPEM, err := ca.createCertificate(pkix.Name{
		CommonName:   "admin",
		Organization: []string{"system:masters"},
	})
	if err != nil {
		err = fmt.Errorf("failed to create admin certificate: %v", err)
		return
	}

	// Create the API certificate:
	apiKeyPEM, apiCrtPEM, err := ca.createCertificate(pkix.Name{
		CommonName:   "api",
		Organization: []string{"Kubernetes"},
	})
	if err != nil {
		err = fmt.Errorf("failed to create API server certificate: %v", err)
		return
	}

	// Create the service account signer certificate:
	sasKeyPEM, sasCrtPEM, err := ca.createCertificate(pkix.Name{
		CommonName:   "service-account-signer",
		Organization: []string{"Kubernetes"},
	})
	if err != nil {
		err = fmt.Errorf("failed to create service account signer certificate: %v", err)
		return
	}

	// Create the docker dockerClient:
	dockerClient, err := docker.NewClientWithOpts(docker.FromEnv)
	if err != nil {
		err = fmt.Errorf("failed to create docker client: %v", err)
		return
	}

	// Create and populate the object:
	result = &Environment{
		logger:       b.logger,
		name:         b.name,
		ca:           ca,
		apiKeyPEM:    apiKeyPEM,
		apiCrtPEM:    apiCrtPEM,
		adminKeyPEM:  adminKeyPEM,
		adminCrtPEM:  adminCrtPEM,
		sasKeyPEM:    sasKeyPEM,
		sasCrtPEM:    sasCrtPEM,
		dockerClient: dockerClient,
	}
	return
}

// Start starts the Kubernetes API testing environment. Remember to call the Stop method when the
// environment is no longer needed.
func (e *Environment) Start(ctx context.Context) error {
	// Kill containers that may be left around in other executions:
	err := e.collectGarbage(ctx)
	if err != nil {
		return err
	}

	// Start the etcd server:
	err = e.startEtcd(ctx)
	if err != nil {
		return err
	}

	// Start the API server:
	err = e.startAPI(ctx)
	if err != nil {
		return err
	}

	return nil
}

// Stop stops the Kubernetes API testing environment and releases all the resources it was using.
func (e *Environment) Stop(ctx context.Context) error {
	// Collect the logs of the containers:
	if e.logger.V(3).Enabled() {
		err := e.collectLogs(ctx)
		if err != nil {
			e.logger.Error(err, "Failed to collect logs")
		}
	}

	// Remove the containers:
	err := e.collectGarbage(ctx)
	if err != nil {
		e.logger.Error(err, "Failed to remove containers")
	}

	// Remove temporary directories:
	err = e.removeTmpDirs()
	if err != nil {
		e.logger.Error(err, "Failed to remove temporary directories")
	}

	return nil
}

// Kubeconfig returns the bytes of a Kubernetes API config file that can be used to connect to the
// testing environment with admnistrator privileges.
func (e *Environment) Kubeconfig() (result []byte, err error) {
	cfgObj := clientcmdapi.Config{
		Clusters: map[string]*clientcmdapi.Cluster{
			e.name: {
				Server:                   fmt.Sprintf("https://%s", e.apiCont.addr),
				CertificateAuthorityData: e.ca.crtPEM,
			},
		},
		AuthInfos: map[string]*clientcmdapi.AuthInfo{
			e.name: {
				ClientKeyData:         e.adminKeyPEM,
				ClientCertificateData: e.adminCrtPEM,
			},
		},
		Contexts: map[string]*clientcmdapi.Context{
			e.name: {
				Cluster:  e.name,
				AuthInfo: e.name,
			},
		},
		CurrentContext: e.name,
	}
	result, err = clientcmd.Write(cfgObj)
	return
}

// Client returns a controller-runtime client that can be used to connect to the testing environment
// with admnistrator provileges. Note that this creates a new client every time it is called.
func (e *Environment) Client() (result clnt.WithWatch, err error) {
	cfgData, err := e.Kubeconfig()
	if err != nil {
		return
	}
	clientCfg, err := clientcmd.NewClientConfigFromBytes(cfgData)
	if err != nil {
		return
	}
	restCfg, err := clientCfg.ClientConfig()
	if err != nil {
		return
	}
	result, err = clnt.NewWithWatch(restCfg, clnt.Options{})
	return
}

func (e *Environment) startEtcd(ctx context.Context) error {
	var err error

	// Start the container:
	e.etcdCont, err = e.startContainer(
		ctx,
		fmt.Sprintf("%s-etcd", e.name),
		&dockercontainer.Config{
			ExposedPorts: dockernat.PortSet{
				"2379/tcp": {},
			},
			Image: environmentEtcdImage,
			Cmd: []string{
				"etcd",
				"--advertise-client-urls=http://127.0.0.1:2379",
				"--initial-advertise-peer-urls=http://127.0.0.1:2380",
				"--initial-cluster-state=new",
				"--initial-cluster=default=http://127.0.0.1:2380",
				"--listen-client-urls=http://0.0.0.0:2379",
				"--listen-peer-urls=http://127.0.0.1:2380",
			},
		},
		&dockercontainer.HostConfig{
			PortBindings: dockernat.PortMap{
				"2379/tcp": []dockernat.PortBinding{{
					HostPort: "",
				}},
			},
		},
	)
	if err != nil {
		return err
	}

	// Find the address:
	e.etcdCont.addr, err = e.findAddr(ctx, e.etcdCont.id, "2379/tcp")
	if err != nil {
		return err
	}

	return err
}

func (e *Environment) startAPI(ctx context.Context) error {
	// Create a temporary directory containing the keys and certificates needed by the API server:
	configDir, err := e.writeConfig(map[string][]byte{
		"ca.crt":  e.ca.crtPEM,
		"api.key": e.apiKeyPEM,
		"api.crt": e.apiCrtPEM,
		"sas.key": e.sasKeyPEM,
		"sas.crt": e.sasCrtPEM,
	})
	if err != nil {
		return err
	}

	// Start the API server:
	e.apiCont, err = e.startContainer(
		ctx,
		fmt.Sprintf("%s-api", e.name),
		&dockercontainer.Config{
			Image: environmentAPIImage,
			ExposedPorts: dockernat.PortSet{
				"6443/tcp": struct{}{},
			},
			Cmd: []string{
				"kube-apiserver",
				fmt.Sprintf("--etcd-servers=http://%s:2379", e.etcdCont.ip),
				"--client-ca-file=/config/ca.crt",
				"--tls-private-key-file=/config/api.key",
				"--tls-cert-file=/config/api.crt",
				"--advertise-address=127.0.0.1",
				"--authorization-mode=Node,RBAC",
				"--bind-address=0.0.0.0",
				"--service-account-issuer=https://127.0.0.1:6443",
				"--service-account-key-file=/config/sas.crt",
				"--service-account-signing-key-file=/config/sas.key",
				"--service-cluster-ip-range=10.128.0.0/14",
			},
		},
		&dockercontainer.HostConfig{
			Binds: []string{
				fmt.Sprintf("%s:/config:z", configDir),
			},
			PortBindings: dockernat.PortMap{
				"6443/tcp": []dockernat.PortBinding{{
					HostPort: "",
				}},
			},
		},
	)
	if err != nil {
		return err
	}

	// Find the address:
	e.apiCont.addr, err = e.findAddr(ctx, e.apiCont.id, "6443/tcp")
	if err != nil {
		return err
	}

	return nil
}

func (e *Environment) startContainer(ctx context.Context, name string,
	config *dockercontainer.Config,
	host *dockercontainer.HostConfig) (result *environmentContainer, err error) {
	// Make sure that the image is available:
	err = e.pullImage(ctx, config.Image)
	if err != nil {
		return
	}

	// Add the label that helps us identify this as a container that we created, so that we can
	// later collect the garbage properly:
	if config.Labels == nil {
		config.Labels = map[string]string{}
	}
	config.Labels[environmentLabel] = e.name

	// Create a custom logger so that the name (and later the identifier) will be automatically
	// added to log messages:
	logger := e.logger.WithValues(
		"name", name,
	)

	// Create the container:
	logger.Info(
		"Creating container",
		"labels", config.Labels,
		"image", config.Image,
		"cmd", config.Cmd,
	)
	response, err := e.dockerClient.ContainerCreate(ctx, config, host, nil, nil, name)
	if err != nil {
		return
	}
	id := response.ID
	logger = logger.WithValues("id", id)

	// Start the container:
	logger.Info("Starting container")
	err = e.dockerClient.ContainerStart(ctx, id, dockertypes.ContainerStartOptions{})
	if err != nil {
		return
	}

	// Find the IP address:
	details, err := e.dockerClient.ContainerInspect(ctx, id)
	if err != nil {
		return
	}
	ip := details.NetworkSettings.DefaultNetworkSettings.IPAddress

	// Return the result:
	result = &environmentContainer{
		id:   response.ID,
		name: name,
		ip:   ip,
	}

	return
}

func (e *Environment) pullImage(ctx context.Context, ref string) error {
	// Check if the image is already available:
	filters := dockerfilters.NewArgs()
	filters.Add("reference", ref)
	images, err := e.dockerClient.ImageList(ctx, dockertypes.ImageListOptions{
		Filters: filters,
	})
	if err != nil {
		return err
	}
	if len(images) > 0 {
		e.logger.Info(
			"Image is already available",
			"ref", ref,
		)
		return nil
	}

	// Pull the image:
	e.logger.Info(
		"Pulling image",
		"ref", ref,
	)
	reader, err := e.dockerClient.ImagePull(ctx, ref, dockertypes.ImagePullOptions{})
	if err != nil {
		return err
	}
	defer reader.Close()
	_, err = io.Copy(io.Discard, reader)
	return err
}

func (e *Environment) findAddr(ctx context.Context, id string, port dockernat.Port) (addr string, err error) {
	detail, err := e.dockerClient.ContainerInspect(ctx, id)
	if err != nil {
		return
	}
	for key, bindings := range detail.NetworkSettings.Ports {
		if key == port {
			for _, binding := range bindings {
				if binding.HostIP == "" || binding.HostPort == "" {
					continue
				}
				host := binding.HostIP
				if host == "0.0.0.0" {
					host = "127.0.0.1"
				}
				addr = net.JoinHostPort(host, binding.HostPort)
				return
			}
		}
	}
	return
}

func (e *Environment) collectLogs(ctx context.Context) error {
	// Collect the etcd logs:
	err := e.collectContainerLogs(ctx, e.etcdCont)
	if err != nil {
		e.logger.Error(
			err,
			"Failed to collect etcd logs",
			"id", e.etcdCont.id,
		)
	}

	// Collect the API server logs:
	err = e.collectContainerLogs(ctx, e.apiCont)
	if err != nil {
		e.logger.Error(
			err,
			"Failed to collect API server logs",
			"id", e.apiCont.id,
		)
	}

	return nil
}

func (e *Environment) collectContainerLogs(ctx context.Context, container *environmentContainer) error {
	logReader, err := e.dockerClient.ContainerLogs(
		ctx,
		container.id,
		dockertypes.ContainerLogsOptions{
			ShowStdout: true,
			ShowStderr: true,
		})
	if err != nil {
		return err
	}
	outBuf := &bytes.Buffer{}
	errBuf := &bytes.Buffer{}
	_, err = dockerstdcopy.StdCopy(outBuf, errBuf, logReader)
	if err != nil {
		return err
	}
	outScanner := bufio.NewScanner(outBuf)
	var outLines []string
	for outScanner.Scan() {
		outLines = append(outLines, outScanner.Text())
	}
	logger := e.logger.WithValues(
		"id", container.id,
		"name", container.name,
	)
	logger.V(3).Info(
		"Container stdout",
		"lines", outLines,
	)
	errScanner := bufio.NewScanner(errBuf)
	var errLines []string
	for errScanner.Scan() {
		errLines = append(errLines, errScanner.Text())
	}
	logger.V(3).Info(
		"Container stderr",
		"lines", errLines,
	)
	return nil
}

func (e *Environment) collectGarbage(ctx context.Context) error {
	// Get the all the containers that we have created before:
	filters := dockerfilters.NewArgs()
	filters.Add("label", fmt.Sprintf("%s=%s", environmentLabel, e.name))
	containers, err := e.dockerClient.ContainerList(ctx, dockertypes.ContainerListOptions{
		All:     true,
		Filters: filters,
	})
	if err != nil {
		return err
	}

	// Remove the garbage containers:
	for _, container := range containers {
		info := environmentContainer{
			id: container.ID,
		}
		if len(container.Names) > 0 {
			info.name = container.Names[0]
		}
		err = e.removeContainer(ctx, info)
		if err != nil {
			e.logger.Error(
				err,
				"Failed to remove container",
				"id", info.id,
				"name", info.name,
			)
		}
	}

	return nil
}

func (e *Environment) removeContainer(ctx context.Context, container environmentContainer) error {
	logger := e.logger.WithValues(
		"id", container.id,
		"name", container.name,
	)
	logger.Info("Removing container")
	return e.dockerClient.ContainerRemove(ctx, container.id, dockertypes.ContainerRemoveOptions{
		Force: true,
	})
}

func (e *Environment) removeTmpDirs() error {
	for _, tmpDir := range e.tmpDirs {
		err := os.RemoveAll(tmpDir)
		if err != nil {
			e.logger.Error(
				err,
				"Failed to remove temporary directory",
				"dir", tmpDir,
			)
		}
	}
	return nil
}

func (e *Environment) writeConfig(files map[string][]byte) (result string, err error) {
	tmpDir, err := os.MkdirTemp("", "*.test")
	if err != nil {
		return
	}
	e.tmpDirs = append(e.tmpDirs, tmpDir)
	for name, data := range files {
		path := filepath.Join(tmpDir, name)
		sub := filepath.Dir(path)
		err = os.MkdirAll(sub, 0600)
		if errors.Is(err, os.ErrExist) {
			err = nil
		}
		if err != nil {
			return
		}
		err = os.WriteFile(path, data, 0400)
		if err != nil {
			return
		}
	}
	result = tmpDir
	return
}

// environmentLabel is the name of the label used to mark containers.
const environmentLabel = "env"

// Container images:
const (
	environmentEtcdImage = "quay.io/coreos/etcd:v3.5.7"
	environmentAPIImage  = "registry.k8s.io/kube-apiserver:v1.26.0"
)
