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

package setup

import (
	"context"
	"fmt"
	"io/fs"

	"github.com/go-logr/logr"
	"github.com/spf13/cobra"
	"gopkg.in/yaml.v3"
	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal"
)

// Cobra creates and returns the `dev setup` command.
func Cobra() *cobra.Command {
	c := NewCommand()
	return &cobra.Command{
		Use:   "setup",
		Short: "Prepares the development environment",
		Args:  cobra.NoArgs,
		RunE:  c.run,
	}
}

// Command contains the data and logic needed to run the `dev setup` command.
type Command struct {
	logger logr.Logger
	tool   *internal.Tool
	env    map[string]string
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

	// Create the client for the API:
	fmt.Fprintf(c.tool.Out(), "Creating API client\n")
	c.client, err = internal.NewClient().
		SetLogger(c.logger).
		SetEnv(c.env).
		Build()
	if err != nil {
		err = fmt.Errorf(
			"failed to create API client: %v",
			err,
		)
		return
	}

	// Install the custom resource definitions and the objects:
	fmt.Fprintf(c.tool.Out(), "Installing CRDs\n")
	err = c.installCRDs(ctx)
	if err != nil {
		return err
	}
	fmt.Fprintf(c.tool.Out(), "Installing objects\n")
	err = c.installObjects(ctx)
	if err != nil {
		return err
	}

	return nil
}

func (c *Command) installCRDs(ctx context.Context) error {
	return fs.WalkDir(
		internal.DataFS,
		"data/dev/crds",
		func(path string, d fs.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if !d.Type().IsRegular() {
				return nil
			}
			return c.installCRD(ctx, path)
		},
	)
}

func (c *Command) installCRD(ctx context.Context, path string) error {
	// Read the CRD from the file:
	crdBytes, err := internal.DataFS.ReadFile(path)
	if err != nil {
		return err
	}
	crdData := &unstructured.Unstructured{}
	err = yaml.Unmarshal(crdBytes, &crdData.Object)
	if err != nil {
		return err
	}

	// Add the label that identifies the CRD as created by us:
	crdLabels := crdData.GetLabels()
	if crdLabels == nil {
		crdLabels = map[string]string{}
	}
	crdLabels["ztp"] = "true"
	crdData.SetLabels(crdLabels)

	// Calculate the display name:
	displayName := crdData.GetName()

	// Create the CRD:
	err = c.client.Create(ctx, crdData)
	if errors.IsAlreadyExists(err) {
		fmt.Fprintf(
			c.tool.Out(),
			"CRD '%s' already exists\n",
			displayName,
		)
		return nil
	}
	if err != nil {
		return err
	}
	fmt.Fprintf(
		c.tool.Out(),
		"Created CRD '%s'\n",
		displayName,
	)

	return nil
}

func (c *Command) installObjects(ctx context.Context) error {
	return fs.WalkDir(
		internal.DataFS,
		"data/dev/objects",
		func(path string, d fs.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if !d.Type().IsRegular() {
				return nil
			}
			return c.installObject(ctx, path)
		},
	)
}

func (c *Command) installObject(ctx context.Context, path string) error {
	// Read the object from the file:
	objectBytes, err := internal.DataFS.ReadFile(path)
	if err != nil {
		return err
	}
	var objectMap map[string]any
	err = yaml.Unmarshal(objectBytes, &objectMap)
	if err != nil {
		return err
	}
	objectData := &unstructured.Unstructured{
		Object: objectMap,
	}

	// Add the label that identifies the CRD as created by us:
	objectLabels := objectData.GetLabels()
	if objectLabels == nil {
		objectLabels = map[string]string{}
	}
	objectLabels["ztp"] = "true"
	objectData.SetLabels(objectLabels)

	// Calculate namespace and name that we will display to the user:
	displayNS := objectData.GetNamespace()
	displayName := objectData.GetName()
	if displayNS != "" {
		displayName = fmt.Sprintf("%s/%s", displayNS, displayName)
	}

	// The object may have a status, but the API client will ignore it, so we need to extract it
	// and save it separately after the object has been created.
	statusAny, ok := objectMap["status"]
	if ok {
		delete(objectMap, "status")
	}

	// Create the object:
	err = c.client.Create(ctx, objectData)
	if errors.IsAlreadyExists(err) {
		fmt.Fprintf(
			c.tool.Out(),
			"Object '%s' already exists\n",
			displayName,
		)
		return nil
	}
	if err != nil {
		return err
	}
	fmt.Fprintf(
		c.tool.Out(),
		"Created object '%s'\n",
		displayName,
	)

	// Update the status:
	if statusAny != nil {
		objectData.Object["status"] = statusAny
		err = c.client.Status().Update(ctx, objectData)
		if err != nil {
			return err
		}
		fmt.Fprintf(
			c.tool.Out(),
			"Updated status of object '%s'\n",
			displayName,
		)
	}
	return nil
}
