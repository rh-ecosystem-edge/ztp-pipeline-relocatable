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

	"github.com/go-logr/logr"
	"golang.org/x/exp/slices"
	"gopkg.in/yaml.v3"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	clnt "sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/templating"
)

// RendererBuilder contains the data and logic needed to create an object that knows how render
// Kubernetes API objects from templates. Don't create instances of this type directly, use the
// NewRenderer function instead.
type RendererBuilder struct {
	logger     logr.Logger
	tmplEngine *templating.Engine
	tmplNames  []string
}

// Renderer knows how to create Kubernetes API objects from templates. Don't create instances of
// this type directly, use the NewRenderer function instead.
type Renderer struct {
	logger     logr.Logger
	tmplEngine *templating.Engine
	tmplNames  []string
}

// NewRenderer creates a builder that can then be used to create an object that knows how create
// Kubernetes API objects from templates.
func NewRenderer() *RendererBuilder {
	return &RendererBuilder{}
}

// SetLogger sets the logger that the renderer will use to write log messages. This is mandatory.
func (b *RendererBuilder) SetLogger(value logr.Logger) *RendererBuilder {
	b.logger = value
	return b
}

// SetTemplates sets the templates that will be used to generate the objects. This is mandatory.
func (b *RendererBuilder) SetTemplates(engine *templating.Engine,
	names ...string) *RendererBuilder {
	b.tmplEngine = engine
	b.tmplNames = names
	return b
}

// Build uses the data stored in the builder to create a new renderer.
func (b *RendererBuilder) Build() (result *Renderer, err error) {
	// Check parameters:
	if b.logger.GetSink() == nil {
		err = errors.New("logger is mandatory")
		return
	}
	if b.tmplEngine == nil {
		err = errors.New("template engine is mandatory")
		return
	}
	if len(b.tmplNames) == 0 {
		err = errors.New("template names are mandatory")
		return
	}

	// Create and populate the object:
	result = &Renderer{
		logger:     b.logger,
		tmplEngine: b.tmplEngine,
		tmplNames:  slices.Clone(b.tmplNames),
	}
	return
}

// Render completes the description of the given cluster adding the information that will be later
// required to create it.
func (r *Renderer) Render(ctx context.Context, data any) (results []clnt.Object, err error) {
	for _, tmplName := range r.tmplNames {
		var objects []clnt.Object
		objects, err = r.render(ctx, data, tmplName)
		if err != nil {
			return
		}
		results = append(results, objects...)
	}
	return
}

func (r *Renderer) render(ctx context.Context, data any, name string) (results []clnt.Object,
	err error) {
	// Execute the template:
	buffer := &bytes.Buffer{}
	err = r.tmplEngine.Execute(buffer, name, data)
	if err != nil {
		err = fmt.Errorf(
			"failed to execute template '%s': %v",
			name, err,
		)
		return
	}

	// Parse the objects:
	var objects []map[string]any
	decoder := yaml.NewDecoder(buffer)
	for {
		var object map[string]any
		err = decoder.Decode(&object)
		if errors.Is(err, io.EOF) {
			err = nil
			break
		}
		if err != nil {
			err = fmt.Errorf(
				"failed to parse YAML from template '%s': %v",
				name, err,
			)
			return
		}
		objects = append(objects, object)
	}

	// Create the objects:
	results = make([]clnt.Object, len(objects))
	for i, object := range objects {
		results[i] = &unstructured.Unstructured{
			Object: object,
		}
	}
	return
}
