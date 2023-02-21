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

package config

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"github.com/go-logr/logr"
	"github.com/spf13/pflag"
	"golang.org/x/exp/slices"
	"gopkg.in/yaml.v3"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/jq"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/models"
)

// Loader contains the data and logic needed to load a configuration object. Don't create instances
// of this type directly, use the NewLoader function instead.
type Loader struct {
	logger logr.Logger
	source any
	jq     *jq.Tool
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

// NewLoader creates a builder that can then be used to create a new configuration object.
func NewLoader() *Loader {
	return &Loader{}
}

// SetLogger sets the logger that the loader will use to write to the log. This is mandatory.
func (l *Loader) SetLogger(value logr.Logger) *Loader {
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
func (l *Loader) SetSource(value any) *Loader {
	l.source = value
	return l
}

// SetFlags sets the command line flags that that indicate how to load the configuration. This is
// optional.
func (b *Loader) SetFlags(flags *pflag.FlagSet) *Loader {
	if flags.Changed(configFlagName) {
		value, err := flags.GetString(configFlagName)
		if err == nil {
			b.source = value
		}
	}
	return b
}

// Load uses the data stored in the loader to create and populate a configuration object.
func (l *Loader) Load() (result *models.Config, err error) {
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

	// Create the JQ tool:
	l.jq, err = jq.NewTool().
		SetLogger(l.logger).
		Build()
	if err != nil {
		err = fmt.Errorf("failed to create jq tool: %v", err)
		return
	}

	// Load the source:
	data, err := l.loadSource()
	if err != nil {
		return
	}

	// Load the properties and the clusters:
	config := &models.Config{}
	err = l.loadProperties(data, config)
	if err != nil {
		return
	}
	err = l.loadClusters(data, config)
	if err != nil {
		return
	}
	result = config
	return
}

func (l *Loader) loadSource() (result map[string]any, err error) {
	switch typed := l.source.(type) {
	case string:
		result, err = l.loadFromString(typed)
	case []byte:
		result, err = l.loadFromBytes(typed)
	case io.Reader:
		result, err = l.loadFromReader(typed, "")
	}
	return
}

func (l *Loader) loadFromString(source string) (result map[string]any, err error) {
	ext := filepath.Ext(source)
	switch strings.ToLower(ext) {
	case ".yaml", ".yml":
		result, err = l.loadFromFile(source)
	default:
		result, err = l.loadFromBytes([]byte(source))
	}
	return
}

func (l *Loader) loadFromFile(file string) (result map[string]any, err error) {
	reader, err := os.Open(file)
	if errors.Is(err, os.ErrNotExist) {
		err = fmt.Errorf("file '%s' doesn't exist", file)
		return
	}
	if errors.Is(err, os.ErrPermission) {
		err = fmt.Errorf("permission to read file '%s' denied", file)
		return
	}
	if err != nil {
		return
	}
	result, err = l.loadFromReader(reader, file)
	return
}

func (l *Loader) loadFromBytes(data []byte) (result map[string]any, err error) {
	result, err = l.loadFromReader(bytes.NewBuffer(data), "")
	return
}

func (l *Loader) loadFromReader(reader io.Reader, file string) (result map[string]any, err error) {
	decoder := yaml.NewDecoder(reader)
	err = decoder.Decode(&result)
	if err != nil {
		var prefix string
		if file != "" {
			prefix = fmt.Sprintf("failed to parse file '%s'", file)
		} else {
			prefix = "failed to parse YAML"
		}
		typeErr, ok := err.(*yaml.TypeError)
		if ok {
			err = fmt.Errorf("%s, %v", prefix, typeErr.Errors[0])
		} else {
			err = fmt.Errorf("%s: %v", prefix, err)
		}
	}
	return
}

func (l *Loader) loadProperties(content any, config *models.Config) error {
	return l.jq.Query(`.config`, content, &config.Properties)
}

func (l *Loader) loadClusters(content any, config *models.Config) error {
	var data []map[string]any
	err := l.jq.Query(`.edgeclusters`, content, &data)
	if err != nil {
		return err
	}
	for _, item := range data {
		for name, value := range item {
			cluster := &models.Cluster{
				Name: name,
			}
			err = l.loadCluster(value, cluster)
			if err != nil {
				return err
			}
			config.Clusters = append(config.Clusters, cluster)
		}
	}
	sort.Slice(config.Clusters, func(i, j int) bool {
		return strings.Compare(config.Clusters[i].Name, config.Clusters[j].Name) < 0
	})
	return nil
}

func (l *Loader) loadCluster(content any, cluster *models.Cluster) error {
	var data map[string]any
	err := l.jq.Query(`.`, content, &data)
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
			node := &models.Node{
				Name: name,
			}
			err = l.loadNode(value, node)
			if err != nil {
				return err
			}
			cluster.Nodes = append(cluster.Nodes, node)
		}
	}
	sort.Slice(cluster.Nodes, func(i, j int) bool {
		return strings.Compare(cluster.Nodes[i].Name, cluster.Nodes[j].Name) < 0
	})
	return nil
}

func (l *Loader) loadClusterConfig(content any, cluster *models.Cluster) error {
	var data configData
	err := l.jq.Query(".", content, &data)
	if err != nil {
		return err
	}

	// TPM:
	if data.TPM != nil {
		cluster.TPM = *data.TPM
	}

	return nil
}

func (l *Loader) loadNode(content any, node *models.Node) error {
	var data nodeData
	err := l.jq.Query(".", content, &data)
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
		if node.InternalNIC == nil {
			node.InternalNIC = &models.NIC{}
		}
		node.InternalNIC.Name = *data.NICIntStatic
	}
	if node.InternalNIC != nil && data.MACIntStatic != nil {
		node.InternalNIC.MAC = *data.MACIntStatic
	}

	// External NIC:
	if data.NICExtDHCP != nil {
		if node.ExternalNIC == nil {
			node.ExternalNIC = &models.NIC{}
		}
		node.ExternalNIC.Name = *data.NICExtDHCP
	}
	if node.ExternalNIC != nil && data.MACExtDHCP != nil {
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
