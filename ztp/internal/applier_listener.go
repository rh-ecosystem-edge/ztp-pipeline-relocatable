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
	"strings"
	"unicode"

	"github.com/go-logr/logr"
	"github.com/iancoleman/strcase"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
)

// ApplierListenerBuilder contains the data and logic needed to create an object that listens for
// applier events and writes them to the console using a human friendly format.
type ApplierListenerBuilder struct {
	logger  logr.Logger
	console *Console
}

// ApplierListener knows how to write to the console human friendly representations of applier
// events.
type ApplierListener struct {
	logger  logr.Logger
	console *Console
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

// SetConsole sets the console. This is mandatory.
func (b *ApplierListenerBuilder) SetConsole(value *Console) *ApplierListenerBuilder {
	b.console = value
	return b
}

// Build uses the data stored in the builder to create a new listener.
func (b *ApplierListenerBuilder) Build() (result *ApplierListener, err error) {
	// Check parameters:
	if b.logger.GetSink() == nil {
		err = errors.New("logger is mandatory")
		return
	}
	if b.console == nil {
		err = errors.New("console is mandatory")
		return
	}

	// Create and populate the object:
	result = &ApplierListener{
		logger:  b.logger,
		console: b.console,
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
		l.console.Info(
			"Created %s '%s'",
			friendlyKind, friendlyName,
		)
	case ApplierObjectExist:
		l.console.Warn(
			"%s '%s' already exists",
			capitalizedKind, friendlyName,
		)
	case ApplierObjectNotExist:
		l.console.Warn(
			"%s '%s' doesn't exist",
			capitalizedKind, friendlyName,
		)
	case ApplierCreateError:
		l.console.Error(
			"Failed to create %s '%s': %v",
			friendlyKind, friendlyName, event.Error,
		)
	case ApplierDeleteError:
		l.console.Error(
			"Failed to delete %s '%s': %v",
			friendlyKind, friendlyName, event.Error,
		)
	case ApplierStatusUpdated:
		l.console.Info(
			"Updated status of %s '%s'",
			friendlyKind, friendlyName,
		)
	case ApplierStatusError:
		l.console.Error(
			"Failed to update status of %s '%s': %v",
			friendlyKind, friendlyName, event.Error,
		)
	case ApplierObjectDeleted:
		l.console.Info(
			"Deleted %s '%s'",
			friendlyKind, friendlyName,
		)
	case ApplierWaitingCRD:
		l.console.Info(
			"Waiting for CRD before creating %s '%s'",
			friendlyKind, friendlyName,
		)
	case ApplierWaitingDisappear:
		l.console.Info(
			"Waiting for %s '%s' to disappear before deleting namespace",
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
	result = strcase.ToDelimited(kind, ' ')
	words := strings.Split(result, " ")
	for i, word := range words {
		if !l.isAcronym(word) {
			words[i] = strings.ToLower(word)
		}
	}
	result = strings.Join(words, " ")
	return result
}

func (l *ApplierListener) isAcronym(word string) bool {
	for _, r := range word {
		if unicode.IsLower(r) {
			return false
		}
	}
	return true
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
	"ConfigMap":                "configmap",
	"CustomResourceDefinition": "CRD",
	"IPAddressPool":            "IP address pool",
	"InfraEnv":                 "infrastructure environment",
	"L2Advertisement":          "L2 advertisement",
	"MetalLB":                  "metal load balancer",
	"MultiClusterEngine":       "multicluster engine",
	"NMState":                  "nmstate",
	"NMStateConfig":            "nmstate configuration",
	"OAuthClient":              "OAuth client",
}
