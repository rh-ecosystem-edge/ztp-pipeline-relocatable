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

package odf

import (
	"context"
	"fmt"
	"sort"
	"strings"

	"github.com/go-logr/logr"
	"github.com/imdario/mergo"
	"github.com/spf13/cobra"
	"github.com/spf13/pflag"
	corev1 "k8s.io/api/core/v1"
	storagev1 "k8s.io/api/storage/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/config"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/exit"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/jq"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/models"
)

// Create creates and returns the `create odf` command.
func Create() *cobra.Command {
	c := NewCreateCommand()
	result := &cobra.Command{
		Use:     "odf",
		Aliases: []string{"odf"},
		Short:   "Deploys OpenShift data foundation",
		Args:    cobra.NoArgs,
		RunE:    c.run,
	}
	flags := result.Flags()
	config.AddFlags(flags)
	internal.AddEnricherFlags(flags)
	return result
}

// CreateCommand contains the data and logic needed to run the `create odf` command.
type CreateCommand struct {
	logger  logr.Logger
	flags   *pflag.FlagSet
	jq      *jq.Tool
	console *internal.Console
	config  *models.Config
	client  *internal.Client
}

// CreateTask contains the information necessary to complete each of the tasks that this command
// runs, in particular it contains the reference to the cluster it works with, so that it isn't
// necessary to pass this reference around all the time.
type CreateTask struct {
	parent  *CreateCommand
	logger  logr.Logger
	flags   *pflag.FlagSet
	jq      *jq.Tool
	console *internal.Console
	version string
	cluster *models.Cluster
	client  *internal.Client
}

// NewCreateCommand creates a new runner that knows how to execute the `create odf` command.
func NewCreateCommand() *CreateCommand {
	return &CreateCommand{}
}

// run runs the `create odf` command.
func (c *CreateCommand) run(cmd *cobra.Command, argv []string) error {
	var err error

	// Get the context:
	ctx := cmd.Context()

	// Get the dependencies from the context:
	c.logger = internal.LoggerFromContext(ctx)
	c.console = internal.ConsoleFromContext(ctx)

	// Save the flags:
	c.flags = cmd.Flags()

	// Create the jq tool:
	c.jq, err = jq.NewTool().
		SetLogger(c.logger).
		Build()
	if err != nil {
		c.console.Error(
			"Failed to create jq tool: %v",
			err,
		)
		return exit.Error(1)
	}

	// Load the configuration:
	c.config, err = config.NewLoader().
		SetLogger(c.logger).
		SetFlags(c.flags).
		Load()
	if err != nil {
		c.console.Error(
			"Failed to load configuration: %v",
			err,
		)
		return exit.Error(1)
	}

	// Check that the ODF version is set:
	version, ok := c.config.Properties[models.ODFVersionProperty]
	if !ok {
		return fmt.Errorf(
			"ODF version property '%s' isn't set",
			models.ODFVersionProperty,
		)
	}

	// Create the client for the API:
	c.client, err = internal.NewClient().
		SetLogger(c.logger).
		SetFlags(c.flags).
		Build()
	if err != nil {
		c.console.Error(
			"Failed to create API client: %v",
			err,
		)
		return exit.Error(1)
	}

	// Enrich the configuration:
	enricher, err := internal.NewEnricher().
		SetLogger(c.logger).
		SetClient(c.client).
		SetFlags(c.flags).
		Build()
	if err != nil {
		c.console.Error(
			"Failed to create enricher: %v",
			err,
		)
		return exit.Error(1)
	}
	err = enricher.Enrich(ctx, c.config)
	if err != nil {
		c.console.Error(
			"Failed to enrich configuration: %v",
			err,
		)
		return exit.Error(1)
	}

	// Create a task for each cluster, and run them:
	for _, cluster := range c.config.Clusters {
		task := &CreateTask{
			parent:  c,
			logger:  c.logger.WithValues("cluster", cluster.Name),
			flags:   c.flags,
			jq:      c.jq,
			console: c.console,
			version: version,
			cluster: cluster,
		}
		err = task.run(ctx)
		if err != nil {
			c.console.Error(
				"Failed to create OpenShift data foundation for cluster '%s': %v",
				cluster.Name, err,
			)
		}
	}

	return nil
}

func (t *CreateTask) run(ctx context.Context) error {
	var err error

	// Check that the Kubeconfig is available:
	if t.cluster.Kubeconfig == nil {
		return fmt.Errorf(
			"kubeconfig for cluster '%s' isn't available",
			t.cluster.Name,
		)
	}

	// Check that there is at least one control plane node:
	nodes := t.cluster.Nodes
	if len(nodes) == 0 {
		return fmt.Errorf(
			"there are no nodes in cluster '%s'",
			t.cluster.Name,
		)
	}

	// Currently we assume that all the nodes nodes have the same number of storage disks, so we
	// need to verify it:
	disks0 := len(nodes[0].StorageDisks)
	for i := 1; i < len(nodes); i++ {
		disksI := len(nodes[i].StorageDisks)
		if disks0 != disksI {
			return fmt.Errorf(
				"all nodes of cluster '%s' should have the number of storage "+
					"disks, but node '%s' has %d and node '%s' has %d",
				t.cluster.Name,
				nodes[0].Name, disks0,
				nodes[i].Name, disksI,
			)
		}
	}

	// Create the client to connect to the cluster:
	t.client, err = internal.NewClient().
		SetLogger(t.logger).
		SetFlags(t.flags).
		SetKubeconfig(t.cluster.Kubeconfig).
		Build()
	if err != nil {
		return err
	}

	// Deploy the operator:
	err = t.deployODF(ctx)
	if err != nil {
		return err
	}

	return nil
}

func (t *CreateTask) deployODF(ctx context.Context) error {
	// Create the applier:
	listener, err := internal.NewApplierListener().
		SetLogger(t.logger).
		SetConsole(t.console).
		Build()
	if err != nil {
		return err
	}
	applier, err := internal.NewApplier().
		SetLogger(t.logger).
		SetListener(listener.Func).
		SetClient(t.client).
		SetFS(templatesFS).
		SetRoot("templates").
		SetDir("objects").
		Build()
	if err != nil {
		return err
	}

	// Label the nodes:
	err = t.labelNodes(ctx)
	if err != nil {
		return err
	}

	// Calculate the variables:
	disks := t.getDisks()
	t.logger.Info(
		"Calculated ODF details",
		"disks", disks,
	)

	// Create the objects:
	objects, err := applier.Render(ctx, map[string]any{
		"Version": t.version,
		"Cluster": t.cluster,
		"Disks":   disks,
	})
	if err != nil {
		return err
	}
	err = applier.ApplyObjects(ctx, objects)
	if err != nil {
		return err
	}

	// Find the storage cluster:
	var storageCluster *unstructured.Unstructured
	for _, object := range objects {
		if object.GroupVersionKind() == internal.StorageClusterGVK {
			storageCluster = object
			break
		}
	}
	if storageCluster == nil {
		return fmt.Errorf(
			"failed to find storage cluster for cluster '%s'",
			t.cluster.Name,
		)
	}

	// Wait till the storage cluster is ready:
	t.console.Info(
		"Waiting for storage cluster '%s' for cluster '%s' to be ready",
		storageCluster, t.cluster.Name,
	)
	err = t.waitStorageCluster(ctx, storageCluster)
	if err != nil {
		return err
	}

	// For SNO clusters we need to wait till the NooBaa backing store is ready and then we need
	// to increase the resources because the default is 50 GiB and that isn't enough for the
	// registry mirror:
	if t.cluster.SNO {
		backingStoreKey := clnt.ObjectKey{
			Namespace: storageCluster.GetNamespace(),
			Name:      "noobaa-default-backing-store",
		}
		t.console.Info(
			"Waiting for backing store '%s' for cluster '%s' to be ready",
			backingStoreKey, t.cluster.Name,
		)
		err = t.waitBackingStore(ctx, backingStoreKey)
		if err != nil {
			return err
		}
		err = t.resizeBackingStore(ctx, backingStoreKey)
		if err != nil {
			return err
		}
		t.console.Info(
			"Resized backing store '%s' of cluster '%s'",
			backingStoreKey, t.cluster.Name,
		)
	}

	// For non SNO clusters we need to wait till the Ceph storage class is created and then make
	// it the default:
	if !t.cluster.SNO {
		storageClass := &storagev1.StorageClass{
			ObjectMeta: metav1.ObjectMeta{
				Name: fmt.Sprintf("%s-ceph-rbd", storageCluster.GetName()),
			},
		}
		t.console.Info(
			"Waiting for storage class '%s' of cluster '%s'",
			storageClass, t.cluster.Name,
		)
		err = t.waitStorageClass(ctx, storageClass)
		if err != nil {
			return err
		}
		err = t.client.AddAnnotation(ctx, storageClass,
			"storageclass.kubernetes.io/is-default-class", "true",
		)
		if err != nil {
			return err
		}
		t.console.Info(
			"Marked storage class '%s' of cluster '%s' as default",
			storageClass, t.cluster.Name,
		)
	}

	return nil
}

func (t *CreateTask) labelNodes(ctx context.Context) error {
	// Get the list of control plane nodes:
	list := &corev1.NodeList{}
	err := t.client.List(ctx, list, clnt.MatchingLabels{
		"node-role.kubernetes.io/control-plane": "",
	})
	if err != nil {
		return err
	}
	nodes := make([]*corev1.Node, len(list.Items))
	for i, item := range list.Items {
		nodes[i] = item.DeepCopy()
	}

	// The rack label is calculated from the index of the node, so we sort them by name to make
	// sure that the result is predictable:
	sort.Slice(nodes, func(i, j int) bool {
		return strings.Compare(nodes[i].Name, nodes[j].Name) < 0
	})

	// Add the labels:
	for i, node := range nodes {
		err = t.client.AddLabels(ctx, node, map[string]string{
			"cluster.ocs.openshift.io/openshift-storage": "",
			"topology.rook.io/rack":                      fmt.Sprintf("rack%d", i),
		})
		if err != nil {
			return err
		}
		t.console.Info(
			"Labeled node '%s' of cluster '%s'",
			node, t.cluster.Name,
		)
	}
	return nil
}

func (t *CreateTask) getDisks() int {
	// Note that currently the configuration assumes that all the nodes have the same number
	// storage disks, and that is validated before this point, so we can just get the number of
	// storage disks of the first control plane node.
	return len(t.cluster.Nodes[0].StorageDisks)
}

func (t *CreateTask) waitStorageCluster(ctx context.Context,
	storageCluster *unstructured.Unstructured) error {
	list := &unstructured.UnstructuredList{}
	list.SetGroupVersionKind(internal.StorageClusterListGVK)
	namespace := storageCluster.GetNamespace()
	name := storageCluster.GetName()
	watch, err := t.client.Watch(
		ctx, list,
		clnt.InNamespace(namespace),
		clnt.MatchingFields{
			"metadata.name": name,
		},
	)
	if err != nil {
		return err
	}
	defer watch.Stop()
	previous := ""
	for event := range watch.ResultChan() {
		object, ok := event.Object.(*unstructured.Unstructured)
		if !ok {
			continue
		}
		var current string
		err = t.jq.Query(`.status.phase`, object.Object, &current)
		if err != nil {
			return err
		}
		if current == "Error" {
			return fmt.Errorf(
				"storage cluster '%s/%s' of cluster '%s' moved to error phase",
				namespace, name, t.cluster.Name,
			)
		}
		if current == "Ready" {
			t.console.Info(
				"Storage cluster '%s/%s' of cluster '%s' is now ready",
				namespace, name, t.cluster.Name,
			)
			return nil
		}
		if current != previous {
			t.console.Info(
				"Storage cluster '%s/%s' of cluster '%s' moved to phase '%s'",
				namespace, name, t.cluster.Name, current,
			)
		}
		previous = current
	}
	return fmt.Errorf(
		"timed out while waiting for storage cluster '%s/%s' of cluster '%s' to be ready",
		namespace, name, t.cluster.Name,
	)
}

func (t *CreateTask) waitBackingStore(ctx context.Context, key clnt.ObjectKey) error {
	list := &unstructured.UnstructuredList{}
	list.SetGroupVersionKind(internal.BackingStoreListGVK)
	watch, err := t.client.Watch(
		ctx,
		list,
		clnt.InNamespace(key.Namespace),
		clnt.MatchingFields{
			"metadata.name": key.Name,
		},
	)
	if err != nil {
		return err
	}
	defer watch.Stop()
	previous := ""
	for event := range watch.ResultChan() {
		object, ok := event.Object.(*unstructured.Unstructured)
		if !ok {
			continue
		}
		var current string
		err = t.jq.Query(`.status.phase`, object.Object, &current)
		if err != nil {
			return err
		}
		if current == "Error" {
			return fmt.Errorf(
				"backing store '%s/%s' of cluster '%s' moved to error phase",
				key.Namespace, key.Name, t.cluster.Name,
			)
		}
		if current == "Ready" {
			t.console.Info(
				"Backing store '%s/%s' of cluster '%s' is now ready",
				key.Namespace, key.Name, t.cluster.Name,
			)
			return nil
		}
		if current != previous {
			t.console.Info(
				"Backing store '%s/%s' of cluster '%s' moved to phase '%s'",
				key.Namespace, key.Name, t.cluster.Name, current,
			)
		}
		previous = current
	}
	return fmt.Errorf(
		"timed out while waiting for backing store '%s/%s' of cluster '%s' to be ready",
		key.Namespace, key.Name, t.cluster.Name,
	)
}

func (t *CreateTask) resizeBackingStore(ctx context.Context, key clnt.ObjectKey) error {
	object := &unstructured.Unstructured{}
	object.SetGroupVersionKind(internal.BackingStoreGVK)
	err := t.client.Get(ctx, key, object)
	if err != nil {
		return err
	}
	update := object.DeepCopy()
	err = mergo.Map(&update.Object, map[string]any{
		"spec": map[string]any{
			"pvPool": map[string]any{
				"numVolumes": 8,
				"resources": map[string]any{
					"limits": map[string]any{
						"cpu":    "4",
						"memory": "8Gi",
					},
				},
			},
		},
	})
	if err != nil {
		return err
	}
	return t.client.Patch(ctx, update, clnt.MergeFrom(update))
}

func (t *CreateTask) waitStorageClass(ctx context.Context, object *storagev1.StorageClass) error {
	list := &storagev1.StorageClassList{}
	watch, err := t.client.Watch(
		ctx,
		list,
		clnt.MatchingFields{
			"metadata.name": object.Name,
		},
	)
	if err != nil {
		return err
	}
	defer watch.Stop()
	for range watch.ResultChan() {
		t.console.Info(
			"Storage class '%s' of cluster '%s' is now available",
			object, t.cluster.Name,
		)
		return nil
	}
	return fmt.Errorf(
		"timed out while waiting for storage class '%s' of cluster '%s'",
		object.Name, t.cluster.Name,
	)
}
