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
	"errors"
	"fmt"
	"io"
	"io/fs"

	"github.com/go-logr/logr"
	"golang.org/x/exp/maps"
	"golang.org/x/exp/slices"
	"gopkg.in/yaml.v3"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/client-go/util/retry"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/templating"
)

// ApplierBuilder contains the data and logic needed to create an object that knows how create
// Kubernetes API objects from templates. Don't create instances of this type directly, use the
// NewApplier function instead.
type ApplierBuilder struct {
	logger    logr.Logger
	client    clnt.WithWatch
	labels    map[string]string
	fsys      fs.FS
	root      string
	dirs      []string
	listeners []func(*ApplierEvent)
}

// Applier knows how to create Kubernetes API objects from templates. Don't create instances of
// this type directly, use the NewApplier function instead.
type Applier struct {
	logger    logr.Logger
	client    clnt.WithWatch
	labels    map[string]string
	jq        *JQ
	engine    *templating.Engine
	templates []string
	listeners []func(*ApplierEvent)
}

// ApplierEventType defines the possible types of events.
type ApplierEventType string

const (
	// ApplierObjectCreated indicates that an object didn't exist and has been created.
	ApplierObjectCreated ApplierEventType = "ObjectCreated"

	// ApplierObjectExists indicates that an object already existed and therefore it hasn't been
	// created.
	ApplierObjectExists ApplierEventType = "ObjectExists"

	// ApplierObjectError indicates that an error occurred while trying to create an object.
	ApplierObjectError ApplierEventType = "ObjectError"

	// ApplierStatusUpdated indicates that the status of an object has been updated.
	ApplierStatusUpdated ApplierEventType = "StatusUpdated"

	// ApplierStatusError indicates that an error occurred while trying to update the status of
	// an object.
	ApplierStatusError ApplierEventType = "StatusError"
)

// ApplierEvents represents an event generated by the applier to inform of the progress of its work.
type ApplierEvent struct {
	Type   ApplierEventType
	Object *unstructured.Unstructured
	Error  error
}

// NewApplier creates a builder that can then be used to create an object that knows how create
// Kubernetes API objects from templates.
func NewApplier() *ApplierBuilder {
	return &ApplierBuilder{}
}

// SetLogger sets the logger that the renderer will use to write log messages. This is mandatory.
func (b *ApplierBuilder) SetLogger(value logr.Logger) *ApplierBuilder {
	b.logger = value
	return b
}

// SetFS sets the file system containing the templates. This is mandatory.
func (b *ApplierBuilder) SetFS(value fs.FS) *ApplierBuilder {
	b.fsys = value
	return b
}

// SetRoot sets the root directory of the templates file system. Directories specified with the
// AddDir method are relative to this. This is optional.
func (b *ApplierBuilder) SetRoot(value string) *ApplierBuilder {
	b.root = value
	return b
}

// SetDir sets a directory within the templates filesystem root that contains templates for the
// Kubernetes API objects. This is optional. If no directory is specified then all the templates in
// the filesystem will be used. Note that this removes all previously configured directories, use
// AddDir if you want to preserve them.
func (b *ApplierBuilder) SetDir(value string) *ApplierBuilder {
	b.dirs = []string{value}
	return b
}

// AddDir adds a directory within the templates filesystem root that contains templates for the
// Kubernetes API objects. This is optional. If no directory is specified then all the templates in
// the filesystem will be used.
func (b *ApplierBuilder) AddDir(value string) *ApplierBuilder {
	b.dirs = append(b.dirs, value)
	return b
}

// SetDirs sets a set of directories within the templates filesystem root that contain templates for
// the Kubernetes API objects. This is optional. If no directory is specified then all the templates
// in the filesystem will be used. Note that this removes all previously configured directories, use
// AddDirs if you want to preserve them.
func (b *ApplierBuilder) SetDirs(values ...string) *ApplierBuilder {
	b.dirs = slices.Clone(values)
	return b
}

// AddDirs adds a set of directories within the templates filesystem root that contain templates for
// the Kubernetes API objects. This is optional. If no directory is specified then all the templates
// in the filesystem will be used.
func (b *ApplierBuilder) AddDirs(values ...string) *ApplierBuilder {
	b.dirs = append(b.dirs, values...)
	return b
}

// SetClient sets the Kubernetes API client that the applier will use to create the objects.
func (b *ApplierBuilder) SetClient(value clnt.WithWatch) *ApplierBuilder {
	b.client = value
	return b
}

// AddLabel adds a label that will be added to all the objects created. This is optional.
func (b *ApplierBuilder) AddLabel(name, value string) *ApplierBuilder {
	if b.labels == nil {
		b.labels = map[string]string{}
	}
	b.labels[name] = value
	return b
}

// AddLabels adds a the collection of labels that will be added to all the objects created. This is
// ooptional.
func (b *ApplierBuilder) AddLabels(values map[string]string) *ApplierBuilder {
	if b.labels == nil {
		b.labels = map[string]string{}
	}
	maps.Copy(b.labels, values)
	return b
}

// SetListener sets a function that will be called when an event is generated. This is optional.
// Note that this removes any previously added listener. If you want to preserve them use the
// AddListener function.
func (b *ApplierBuilder) SetListener(value func(*ApplierEvent)) *ApplierBuilder {
	b.listeners = []func(*ApplierEvent){value}
	return b
}

// AddListener adds a function that will be called when an event is generated. This is optional.
func (b *ApplierBuilder) AddListener(value func(*ApplierEvent)) *ApplierBuilder {
	b.listeners = append(b.listeners, value)
	return b
}

// Build uses the data stored in the builder to create a new applier.
func (b *ApplierBuilder) Build() (result *Applier, err error) {
	// Check parameters:
	if b.logger.GetSink() == nil {
		err = errors.New("logger is mandatory")
		return
	}
	if b.client == nil {
		err = errors.New("client is mandatory")
		return
	}
	if b.fsys == nil {
		err = errors.New("template filesystem is mandatory")
		return
	}

	// Create the JQ object:
	jq, err := NewJQ().
		SetLogger(b.logger).
		Build()
	if err != nil {
		err = fmt.Errorf("failed to create JQ object: %v", err)
		return
	}

	// Create the filesystem:
	fsys := b.fsys
	if b.root != "" {
		fsys, err = fs.Sub(b.fsys, b.root)
		if err != nil {
			return
		}
	}

	// Create the templating engine:
	engine, err := b.createEngine(fsys)
	if err != nil {
		err = fmt.Errorf("failed to create templating engine: %v", err)
		return
	}
	templates, err := b.findTemplates(fsys)
	if err != nil {
		err = fmt.Errorf("failed to find templates: %v", err)
		return
	}

	// Create and populate the object:
	result = &Applier{
		logger:    b.logger,
		client:    b.client,
		labels:    maps.Clone(b.labels),
		jq:        jq,
		engine:    engine,
		templates: templates,
		listeners: slices.Clone(b.listeners),
	}
	return
}

func (b *ApplierBuilder) createEngine(fsys fs.FS) (result *templating.Engine, err error) {
	result, err = templating.NewEngine().
		SetLogger(b.logger).
		SetFS(fsys).
		Build()
	return
}

func (b *ApplierBuilder) findTemplates(fsys fs.FS) (results []string, err error) {
	var templates []string
	dirs := b.dirs
	if len(dirs) == 0 {
		dirs = []string{"."}
	}
	for _, dir := range dirs {
		err = fs.WalkDir(fsys, dir, func(path string, d fs.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if !d.Type().IsRegular() {
				return nil
			}
			templates = append(templates, path)
			return nil
		})
		if err != nil {
			return
		}
	}
	results = templates
	return
}

// Apply generates the objects passing the given data to the templates and then creates them.
func (r *Applier) Apply(ctx context.Context, data any) error {
	// Render the objects:
	objects, err := r.Render(ctx, data)
	if err != nil {
		return err
	}

	// Namespaces and custom resource definitions need to be created first as other objects will
	// depend on them, so first we need to classify the rendered objects.
	var namespaces, crds, others []*unstructured.Unstructured
	for _, object := range objects {
		switch {
		case r.isNamespace(object):
			namespaces = append(namespaces, object)
		case r.isCRD(object):
			crds = append(crds, object)
		default:
			others = append(others, object)
		}
	}

	// Create the namespaces:
	err = r.applyNamespaces(ctx, namespaces)
	if err != nil {
		return err
	}

	// Create the custom resource definitions:
	err = r.applyCRDs(ctx, crds)
	if err != nil {
		return err
	}

	// Create the rest of the objects:
	err = r.applyObjects(ctx, others)
	if err != nil {
		return err
	}

	return nil
}

// Render generates the objects passing the given data to the templates, but doesn't actually create
// them.
func (a *Applier) Render(ctx context.Context, data any) (results []*unstructured.Unstructured,
	err error) {
	for _, template := range a.templates {
		var objects []*unstructured.Unstructured
		objects, err = a.renderObjects(ctx, data, template)
		if err != nil {
			return
		}
		results = append(results, objects...)
	}
	return
}

func (a *Applier) isNamespace(object clnt.Object) bool {
	gvk := object.GetObjectKind().GroupVersionKind()
	matchesGroup := gvk.Group == NamespaceGVK.Group
	matchesKind := gvk.Kind == NamespaceGVK.Kind
	return matchesGroup && matchesKind
}

func (a *Applier) isCRD(object clnt.Object) bool {
	gvk := object.GetObjectKind().GroupVersionKind()
	matchesGroup := gvk.Group == CustomResourceDefinitionGVK.Group
	matchesKind := gvk.Kind == CustomResourceDefinitionGVK.Kind
	return matchesGroup && matchesKind
}

func (a *Applier) applyNamespaces(ctx context.Context, objects []*unstructured.Unstructured) error {
	return a.applyObjects(ctx, objects)
}

func (a *Applier) applyCRDs(ctx context.Context, objects []*unstructured.Unstructured) error {
	// Some CRD templates may have status, but we don't want to apply that:
	for _, object := range objects {
		delete(object.Object, "status")
	}

	// Create the objects:
	err := a.applyObjects(ctx, objects)
	if err != nil {
		return err
	}

	// Wait till all the CRDs have been established, as otherwise creating objects of the
	// corresponding kind will fail:
	if len(objects) > 0 {
		err = a.waitCRDs(ctx, objects)
		if err != nil {
			return err
		}
	}

	return nil
}

func (a *Applier) waitCRDs(ctx context.Context, objects []*unstructured.Unstructured) error {
	pending := map[string]bool{}
	for _, object := range objects {
		pending[object.GetName()] = true
	}
	list := &unstructured.UnstructuredList{}
	list.SetGroupVersionKind(CustomResourceDefinitionGVK)
	watch, err := a.client.Watch(ctx, list)
	if err != nil {
		return err
	}
	defer watch.Stop()
	for event := range watch.ResultChan() {
		update, ok := event.Object.(*unstructured.Unstructured)
		if !ok {
			continue
		}
		name := update.GetName()
		_, ok = pending[name]
		if !ok {
			continue
		}
		var status string
		err = a.jq.Query(
			`try .status.conditions[] | select(.type == "Established") | .status`,
			update.Object, &status,
		)
		if err != nil {
			return err
		}
		if status != "True" {
			continue
		}
		delete(pending, name)
		if len(pending) == 0 {
			break
		}
	}
	return nil
}

func (a *Applier) applyObjects(ctx context.Context, objects []*unstructured.Unstructured) error {
	for _, object := range objects {
		err := a.applyObject(ctx, object)
		if err != nil {
			return err
		}
	}
	return nil
}

func (a *Applier) applyObject(ctx context.Context, object *unstructured.Unstructured) error {
	// Create a copy of the object so that we don't alter the original:
	copy, err := a.copyObject(object)
	if err != nil {
		return a.fireError(ApplierObjectError, object, err)
	}

	// Add the labels:
	labels := copy.GetLabels()
	if labels == nil {
		labels = map[string]string{}
	}
	maps.Copy(labels, a.labels)
	copy.SetLabels(labels)

	// The object may have a status, but the create API ignores it, so we need to extract it and
	// apply it separately after the object has been created.
	status, ok := copy.Object["status"]
	if ok {
		delete(copy.Object, "status")
	}

	// Create the object:
	err = a.client.Create(ctx, copy)
	if err == nil {
		a.fireInfo(ApplierObjectCreated, object)
	}
	if apierrors.IsAlreadyExists(err) {
		a.fireInfo(ApplierObjectExists, object)
		err = nil
	}
	if err != nil {
		return a.fireError(ApplierStatusError, object, err)
	}

	// Update the status:
	if status != nil {
		key := clnt.ObjectKeyFromObject(copy)
		err = retry.RetryOnConflict(retry.DefaultBackoff, func() error {
			err := a.client.Get(ctx, key, copy)
			if err != nil {
				return a.fireError(ApplierStatusError, object, err)
			}
			copy.Object["status"] = status
			return a.client.Status().Update(ctx, copy)
		})
		if err != nil {
			return a.fireError(ApplierStatusError, object, err)
		}
		a.fireInfo(ApplierStatusUpdated, object)
	}

	return nil
}

func (a *Applier) renderObjects(ctx context.Context, data any,
	template string) (results []*unstructured.Unstructured, err error) {
	buffer := &bytes.Buffer{}
	err = a.engine.Execute(buffer, template, data)
	if err != nil {
		return
	}
	results, err = a.decodeObjects(buffer)
	if err != nil {
		err = fmt.Errorf(
			"failed to decode YAML generated from template '%s': %v",
			template, err,
		)
		return
	}
	return
}

func (a *Applier) decodeObjects(reader io.Reader) (results []*unstructured.Unstructured, err error) {
	var objects []map[string]any
	decoder := yaml.NewDecoder(reader)
	for {
		var object map[string]any
		err = decoder.Decode(&object)
		if errors.Is(err, io.EOF) {
			err = nil
			break
		}
		if err != nil {
			return
		}
		objects = append(objects, object)
	}
	results = make([]*unstructured.Unstructured, len(objects))
	for i, object := range objects {
		results[i] = &unstructured.Unstructured{
			Object: object,
		}
	}
	return
}

func (a *Applier) copyObject(object *unstructured.Unstructured) (result *unstructured.Unstructured,
	err error) {
	if object == nil {
		return
	}
	data, err := yaml.Marshal(object.Object)
	if err != nil {
		return
	}
	result = &unstructured.Unstructured{}
	err = yaml.Unmarshal(data, &result.Object)
	return
}

func (a *Applier) fireInfo(typ ApplierEventType, object *unstructured.Unstructured) {
	a.fireEvent(&ApplierEvent{
		Type:   typ,
		Object: object,
	})
}

func (a *Applier) fireError(typ ApplierEventType, object *unstructured.Unstructured,
	err error) error {
	a.fireEvent(&ApplierEvent{
		Type:   typ,
		Object: object,
		Error:  err,
	})
	return err
}

func (a *Applier) fireEvent(event *ApplierEvent) {
	logger := a.logger.V(2)
	if logger.Enabled() {
		gvk := event.Object.GroupVersionKind()
		fields := []any{
			"group", gvk.Group,
			"version", gvk.Version,
			"kind", gvk.Kind,
			"namespace", event.Object.GetNamespace(),
			"name", event.Object.GetName(),
		}
		switch event.Type {
		case ApplierObjectCreated:
			logger.Info("Object created", fields...)
		case ApplierObjectExists:
			logger.Info("Object exists", fields...)
		case ApplierObjectError:
			logger.Error(event.Error, "Object error", fields...)
		case ApplierStatusUpdated:
			logger.Info("Status updated", fields...)
		case ApplierStatusError:
			logger.Info("Status error", fields...)
		default:
			logger.Info("Event", fields...)
		}
	}
	for _, listener := range a.listeners {
		listener(event)
	}
}
