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

package cleanup

import (
	"context"
	"fmt"
	"sort"
	"strings"

	"github.com/go-logr/logr"
	"github.com/spf13/cobra"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime/schema"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/exit"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/labels"
)

// Cobra creates and returns the `dev setup` command.
func Cobra() *cobra.Command {
	c := NewCommand()
	return &cobra.Command{
		Use:   "cleanup",
		Short: "Cleans the development environment",
		Args:  cobra.NoArgs,
		RunE:  c.run,
	}
}

// Command contains the data and logic needed to run the `dev setup` command.
type Command struct {
	logger logr.Logger
	tool   *internal.Tool
	env    map[string]string
	jq     *internal.JQ
	client clnt.WithWatch
}

// NewCommand creates a new runner that knows how to execute the `dev setup` command.
func NewCommand() *Command {
	return &Command{}
}

// run executes the `dev setup` command.
func (c *Command) run(cmd *cobra.Command, argv []string) (err error) {
	// Get the context:
	ctx := cmd.Context()

	// Get the dependencies from the context:
	c.logger = internal.LoggerFromContext(ctx)
	c.tool = internal.ToolFromContext(ctx)

	// Get the environment:
	c.env = c.tool.Env()

	// Create the JQ object:
	c.jq, err = internal.NewJQ().
		SetLogger(c.logger).
		Build()
	if err != nil {
		fmt.Fprintf(
			c.tool.Err(),
			"Failed to create JQ object: %v\n",
			err,
		)
		return exit.Error(1)
	}

	// Create the client for the API:
	c.client, err = internal.NewClient().
		SetLogger(c.logger).
		SetEnv(c.env).
		Build()
	if err != nil {
		fmt.Fprintf(
			c.tool.Err(),
			"Failed to create client: %v\n",
			err,
		)
		return exit.Error(1)
	}

	// Delete the namespaces:
	fmt.Fprintf(c.tool.Out(), "Deleting namespaces\n")
	err = c.deleteNamespaces(ctx)
	if err != nil {
		return err
	}

	// Delete the remaining objects and the custom resource definitions:
	fmt.Fprintf(c.tool.Out(), "Deleting CRDs\n")
	err = c.deleteCRDs(ctx)
	if err != nil {
		return err
	}

	return nil
}

func (c *Command) deleteCRDs(ctx context.Context) error {
	// Find all the CRDs that we installed, so that we can then delete all the objects of those
	// types:
	list := &unstructured.UnstructuredList{}
	list.SetGroupVersionKind(internal.CustomResourceDefinitionListGVK)
	err := c.client.List(ctx, list, clnt.HasLabels{labels.ZTPFW})
	if err != nil {
		return err
	}

	// For each CRD uninstall the objects of that type:
	for _, crd := range list.Items {
		err = c.deleteObjects(ctx, &crd)
		if err != nil {
			return err
		}
	}

	// Delete the CRDs:
	for _, crd := range list.Items {
		err = c.deleteCRD(ctx, &crd)
		if err != nil {
			return err
		}
	}

	return nil
}

func (c *Command) deleteCRD(ctx context.Context, crd *unstructured.Unstructured) error {
	err := c.client.Delete(ctx, crd)
	if errors.IsNotFound(err) {
		fmt.Fprintf(
			c.tool.Out(),
			"CRD '%s' doesn't exist\n",
			crd.GetName(),
		)
		return nil
	}
	if err != nil {
		return err
	}
	fmt.Fprintf(c.tool.Out(), "Deleted CRD '%s'\n", crd.GetName())
	return nil
}

func (c *Command) deleteObjects(ctx context.Context, crd *unstructured.Unstructured) error {
	// Extract the group, version and kind of the list of objects from the CRD definition:
	var objectListGVK schema.GroupVersionKind
	err := c.jq.Query(`.spec.group`, crd.Object, &objectListGVK.Group)
	if err != nil {
		return err
	}
	err = c.jq.Query(`.spec.versions[0].name`, crd.Object, &objectListGVK.Version)
	if err != nil {
		return err
	}
	err = c.jq.Query(`.spec.names.listKind`, crd.Object, &objectListGVK.Kind)
	if err != nil {
		return err
	}

	// Find and delete all the objects of the given type that we created:
	objectList := &unstructured.UnstructuredList{}
	objectList.SetGroupVersionKind(objectListGVK)
	err = c.client.List(ctx, objectList, clnt.MatchingLabels{
		labels.ZTPFW: "true",
	})
	if err != nil {
		return err
	}

	// Sort the objects by type so that the process will be predictable:
	sort.Slice(objectList.Items, func(i, j int) bool {
		return strings.Compare(
			objectList.Items[i].GetName(),
			objectList.Items[j].GetName(),
		) < 0
	})

	// Delete the CRDs:
	for _, objectItem := range objectList.Items {
		err = c.deleteObject(ctx, &objectItem)
		if err != nil {
			return err
		}
	}

	return nil
}

func (c *Command) deleteObject(ctx context.Context, object *unstructured.Unstructured) error {
	// Calculate the display name:
	displayNS := object.GetNamespace()
	displayName := object.GetName()
	if displayNS != "" {
		displayName = fmt.Sprintf("%s/%s", displayNS, displayName)
	}

	// Delete the object:
	err := c.client.Delete(ctx, object)
	if errors.IsNotFound(err) {
		fmt.Fprintf(
			c.tool.Out(),
			"Object '%s' doesn't exist\n",
			displayName,
		)
		err = nil
	}
	if err != nil {
		return err
	}
	fmt.Fprintf(
		c.tool.Out(),
		"Deleted object '%s'\n",
		displayName,
	)
	return nil
}

func (c *Command) deleteNamespaces(ctx context.Context) error {
	// Find and all the namespaces that we created:
	nsList := &corev1.NamespaceList{}
	err := c.client.List(ctx, nsList, clnt.HasLabels{labels.ZTPFW})
	if err != nil {
		return err
	}

	// Delete the namespaces:
	for _, nsItem := range nsList.Items {
		err = c.deleteNamespace(ctx, &nsItem)
		if err != nil {
			return err
		}
	}

	return nil
}

func (c *Command) deleteNamespace(ctx context.Context, ns *corev1.Namespace) error {
	err := c.client.Delete(ctx, ns)
	if errors.IsNotFound(err) {
		fmt.Fprintf(
			c.tool.Out(),
			"Namespace '%s' doesn't exist\n",
			ns.Name,
		)
		err = nil
	}
	if err != nil {
		return err
	}
	fmt.Fprintf(
		c.tool.Out(),
		"Deleted namespace '%s'\n",
		ns.Name,
	)
	return nil
}
