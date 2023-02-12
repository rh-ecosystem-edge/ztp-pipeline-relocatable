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
	"unicode"

	"github.com/go-logr/logr"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
)

// ApplierListenerBuilder contains the data and logic needed to create an object that listens for
// applier events and writes them to the console using a human friendly format.
type ApplierListenerBuilder struct {
	logger logr.Logger
	out    io.Writer
	err    io.Writer
}

// ApplierListener knows how to write to the console human friendly representations of applier
// events.
type ApplierListener struct {
	logger logr.Logger
	out    io.Writer
	err    io.Writer
}

// NewApplierListener creates a builder that can then be used to create a listener.
func NewApplierListener() *ApplierListenerBuilder {
	return &ApplierListenerBuilder{}
}

// SetLogger sets the logger that the listener will use to write log messages. This is mandatory.
func (b *ApplierListenerBuilder) SetLogger(value logr.Logger) *ApplierListenerBuilder {
	b.logger = value
	return b
}

// SetOut sets the standard output stream. This is mandatory.
func (b *ApplierListenerBuilder) SetOut(value io.Writer) *ApplierListenerBuilder {
	b.out = value
	return b
}

// SetErr sets the standard error output stream. This is mandatory.
func (b *ApplierListenerBuilder) SetErr(value io.Writer) *ApplierListenerBuilder {
	b.err = value
	return b
}

// Build uses the data stored in the builder to create a new listener.
func (b *ApplierListenerBuilder) Build() (result *ApplierListener, err error) {
	// Check parameters:
	if b.logger.GetSink() == nil {
		err = errors.New("logger is mandatory")
		return
	}
	if b.out == nil {
		err = errors.New("output writer is mandatory")
		return
	}
	if b.err == nil {
		err = errors.New("error writer is mandatory")
		return
	}

	// Create and populate the object:
	result = &ApplierListener{
		logger: b.logger,
		out:    b.out,
		err:    b.err,
	}
	return
}

// Func is the listener function that should be passed to the SetListener or AddListener methods of
// the applier builder.
func (l *ApplierListener) Func(event *ApplierEvent) {
	// Get the friendlyKind and name to use in the messages:
	friendlyKind := l.friendlyKind(event.Object)
	friendlyName := l.friendlyName(event.Object)

	// Prepare a capitalized version of the kind, for use when it is the first part of a
	// message:
	capitalizedKind := l.capitalize(friendlyKind)

	// Print the message accroding to the event type:
	switch event.Type {
	case ApplierObjectCreated:
		fmt.Fprintf(
			l.out,
			"Created %s '%s'\n",
			friendlyKind, friendlyName,
		)
	case ApplierObjectExist:
		fmt.Fprintf(
			l.out,
			"%s '%s' already exists\n",
			capitalizedKind, friendlyName,
		)
	case ApplierObjectNotExist:
		fmt.Fprintf(
			l.out,
			"%s '%s' doesn't exist\n",
			capitalizedKind, friendlyName,
		)
	case ApplierCreateError:
		fmt.Fprintf(
			l.err,
			"Failed to create %s '%s': %v\n",
			friendlyKind, friendlyName, event.Error,
		)
	case ApplierDeleteError:
		fmt.Fprintf(
			l.err,
			"Failed to delete %s '%s': %v\n",
			friendlyKind, friendlyName, event.Error,
		)
	case ApplierStatusUpdated:
		fmt.Fprintf(
			l.out,
			"Updated status of %s '%s'\n",
			friendlyKind, friendlyName,
		)
	case ApplierStatusError:
		fmt.Fprintf(
			l.err,
			"Failed to update status of %s '%s': %v\n",
			friendlyKind, friendlyName, event.Error,
		)
	case ApplierObjectDeleted:
		fmt.Fprintf(
			l.err,
			"Deleted %s '%s'\n",
			friendlyKind, friendlyName,
		)
	case ApplierWaitingCRD:
		fmt.Fprintf(
			l.err,
			"Waiting for CRD before creating %s '%s'\n",
			friendlyKind, friendlyName,
		)
	default:
		l.logger.Info(
			"Unknown applier event",
			"type", event.Type,
			"object", friendlyName,
			"error", event.Error,
		)
	}
}

func (l *ApplierListener) friendlyKind(object *unstructured.Unstructured) string {
	kind := object.GetKind()
	result, ok := applierFriendlyKinds[kind]
	if ok {
		return result
	}
	return "object"
}

func (l *ApplierListener) friendlyName(object *unstructured.Unstructured) string {
	name := object.GetName()
	namespace := object.GetNamespace()
	if namespace != "" {
		name = fmt.Sprintf("%s/%s", namespace, name)
	}
	return name
}

func (l *ApplierListener) capitalize(s string) string {
	if s == "" {
		return s
	}
	r := []rune(s)
	r[0] = unicode.ToUpper(r[0])
	return string(r)
}

var applierFriendlyKinds = map[string]string{
	"AgentClusterInstall":      "agent cluster install",
	"BareMetalHost":            "bare metal host",
	"CatalogSource":            "catalog source",
	"ClusterDeployment":        "cluster deployment",
	"ConfigMap":                "configmap",
	"CustomResourceDefinition": "CRD",
	"InfraEnv":                 "infrastructure environment",
	"IngressController":        "ingress controller",
	"ManagedCluster":           "managed cluster",
	"MultiClusterEngine":       "multicluster engine",
	"NMStateConfig":            "nmstate configuration",
	"Namespace":                "namespace",
	"OperatorGroup":            "operator group",
	"Secret":                   "secret",
	"Subscription":             "subscription",
}
