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
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/go-logr/logr"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/models"
	"golang.org/x/exp/slices"
	"gopkg.in/yaml.v3"
)

// ConfigLoader contains the data and logic needed to load a configuration object. Don't create
// instances of this type directly, use the NewConfigLoader function instead.
type ConfigLoader struct {
	logger logr.Logger
	source any
	jq     *JQ
}

// configData is used internally to parse the data of a cluster.
type configData struct {
	TPM *bool `json:"tpm"`
}

// nodeData is used internally to parse the data of a node.
type nodeData struct {
	BMCPass      *string  `json:"bmc_pass"`
	BMCURL       *string  `json:"bmc_url"`
	BMCUser      *string  `json:"bmc_user"`
	IgnoreIfaces *string  `json:"ignore_ifaces"`
	MACExtDHCP   *string  `json:"mac_ext_dhcp"`
	MACIntStatic *string  `json:"mac_int_static"`
	NICExtDHCP   *string  `json:"nic_ext_dhcp"`
	NICIntStatic *string  `json:"nic_int_static"`
	RootDisk     *string  `json:"root_disk"`
	StorageDisk  []string `json:"storage_disk"`
}

// NewConfigLoader creates a builder that can then be used to create a new configuration object.
func NewConfigLoader() *ConfigLoader {
	return &ConfigLoader{}
}

// SetLogger sets the logger that the loader will use to write to the log. This is mandatory.
func (l *ConfigLoader) SetLogger(value logr.Logger) *ConfigLoader {
	l.logger = value
	return l
}

// SetSource sets the source for the configuration. It can be one of the following things:
//
// - A string ending in `.yaml` or .`yml`. In this case it will be interpreted as the name of a YAML
// file containing the configuration.
//
// - A string not ending in `.yaml`, `.yml`. In this case it will be interpredted as the content
// of the configuration itself.
//
// - An array of bytes containing the configuration as an UTF-8 string.
//
// - A io.Reader providing the configuration text.
//
// This is mandatory.
func (l *ConfigLoader) SetSource(value any) *ConfigLoader {
	l.source = value
	return l
}

// Load uses the data stored in the loader to create and populate a configuration object.
func (l *ConfigLoader) Load() (result models.Config, err error) {
	// Check the parameters:
	if l.logger.GetSink() == nil {
		err = errors.New("logger is mandatory")
		return
	}
	if l.source == nil {
		err = fmt.Errorf("source is mandatory")
		return
	}
	switch l.source.(type) {
	case string:
	case []byte:
	case io.Reader:
	default:
		err = fmt.Errorf(
			"source isn't valid, should be a string, an array of bytes "+
				"or a reader, but it is of type %T",
			l.source,
		)
		return
	}

	// Create the JQ object:
	l.jq, err = NewJQ().
		SetLogger(l.logger).
		Build()
	if err != nil {
		err = fmt.Errorf("failed to create JQ object: %v", err)
		return
	}

	// Load and the source:
	data, err := l.loadSource()
	if err != nil {
		return
	}

	// Load the properties and the clusters:
	err = l.loadProperties(data, &result)
	if err != nil {
		return
	}
	err = l.loadClusters(data, &result)
	if err != nil {
		return
	}

	return
}

func (l *ConfigLoader) loadSource() (result map[string]any, err error) {
	switch typed := l.source.(type) {
	case string:
		result, err = l.loadFromString(typed)
	case []byte:
		result, err = l.loadFromBytes(typed)
	case io.Reader:
		result, err = l.loadFromReader(typed)
	}
	return
}

func (l *ConfigLoader) loadFromString(source string) (result map[string]any, err error) {
	ext := filepath.Ext(source)
	switch strings.ToLower(ext) {
	case ".yaml", ".yml":
		result, err = l.loadFromFile(source)
	default:
		result, err = l.loadFromBytes([]byte(source))
	}
	return
}

func (l *ConfigLoader) loadFromFile(file string) (result map[string]any, err error) {
	reader, err := os.Open(file)
	if err != nil {
		return
	}
	result, err = l.loadFromReader(reader)
	return
}

func (l *ConfigLoader) loadFromBytes(data []byte) (result map[string]any, err error) {
	err = yaml.Unmarshal(data, &result)
	return
}

func (l *ConfigLoader) loadFromReader(reader io.Reader) (result map[string]any, err error) {
	decoder := yaml.NewDecoder(reader)
	err = decoder.Decode(&result)
	return
}

func (l *ConfigLoader) loadProperties(content any, config *models.Config) error {
	return l.jq.Run(`.config`, content, &config.Properties)
}

func (l *ConfigLoader) loadClusters(content any, config *models.Config) error {
	var data []map[string]any
	err := l.jq.Run(`.edgeclusters`, content, &data)
	if err != nil {
		return err
	}
	for _, item := range data {
		for name, value := range item {
			cluster := models.Cluster{
				Name: name,
			}
			err = l.loadCluster(value, &cluster)
			if err != nil {
				return err
			}
			config.Clusters = append(config.Clusters, cluster)
		}
	}
	return nil
}

func (l *ConfigLoader) loadCluster(content any, cluster *models.Cluster) error {
	var data map[string]any
	err := l.jq.Run(`.`, content, &data)
	if err != nil {
		return err
	}
	for name, value := range data {
		switch {
		case name == "contrib":
		case name == "config":
			err = l.loadClusterConfig(value, cluster)
			if err != nil {
				return err
			}
		default:
			node := models.Node{
				Name: name,
			}
			err = l.loadNode(value, &node)
			if err != nil {
				return err
			}
			cluster.Nodes = append(cluster.Nodes, node)
		}
	}
	return nil
}

func (l *ConfigLoader) loadClusterConfig(content any, cluster *models.Cluster) error {
	var data configData
	err := l.jq.Run(".", content, &data)
	if err != nil {
		return err
	}

	// TPM:
	if data.TPM != nil {
		cluster.TPM = *data.TPM
	}

	return nil
}

func (l *ConfigLoader) loadNode(content any, node *models.Node) error {
	var data nodeData
	err := l.jq.Run(".", content, &data)
	if err != nil {
		return err
	}

	// Kind:
	switch {
	case controlNodeRE.MatchString(node.Name):
		node.Kind = models.NodeKindControlPlane
	case workerNodeRE.MatchString(node.Name):
		node.Kind = models.NodeKindWorker
	}

	// BMC:
	if data.BMCURL != nil {
		node.BMC.URL = *data.BMCURL
	}
	if data.BMCUser != nil {
		node.BMC.User = *data.BMCUser
	}
	if data.BMCPass != nil {
		node.BMC.Pass = *data.BMCPass
	}
	if data.RootDisk != nil {
		node.RootDisk = *data.RootDisk
	}
	node.StorageDisks = slices.Clone(data.StorageDisk)

	// Internal NIC:
	if data.NICIntStatic != nil {
		node.InternalNIC.Name = *data.NICIntStatic
	}
	if data.MACIntStatic != nil {
		node.InternalNIC.MAC = *data.MACIntStatic
	}

	// External NIC:
	if data.NICExtDHCP != nil {
		node.ExternalNIC.Name = *data.NICExtDHCP
	}
	if data.MACExtDHCP != nil {
		node.ExternalNIC.MAC = *data.MACExtDHCP
	}

	// Ignored NICs:
	if data.IgnoreIfaces != nil {
		values := strings.Split(*data.IgnoreIfaces, " ")
		for _, value := range values {
			if value != "" {
				node.IgnoredNICs = append(node.IgnoredNICs, value)
			}
		}
	}

	return nil
}

var (
	controlNodeRE = regexp.MustCompile(`^master\d+$`)
	workerNodeRE  = regexp.MustCompile(`^worker\d+$`)
)
