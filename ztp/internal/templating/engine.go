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

package templating

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	tmpl "text/template"

	"github.com/go-logr/logr"
	"github.com/google/uuid"
	"golang.org/x/exp/slices"
)

// EngineBuilder contains the data and logic needed to create templates. Don't create objects of
// this type directly, use the NewTemplate function instead.
type EngineBuilder struct {
	logger logr.Logger
	fsys   fs.FS
	dir    string
}

// Engine is a template engine based on template.Template with some additional functions. Don't
// create objects of this type directly, use the NewTemplate function instead.
type Engine struct {
	logger   logr.Logger
	names    []string
	template *tmpl.Template
}

// NewEngine creates a builder that can the be used to create a template engine.
func NewEngine() *EngineBuilder {
	return &EngineBuilder{}
}

// SetLogger sets the logger that the engine will use to write messages to the log. This is
// mandatory.
func (b *EngineBuilder) SetLogger(value logr.Logger) *EngineBuilder {
	b.logger = value
	return b
}

// SetFS sets the filesystem that will be used to read the templates. This is mandatory.
func (b *EngineBuilder) SetFS(value fs.FS) *EngineBuilder {
	b.fsys = value
	return b
}

// SetDir instructs the engine to load load the templates only from the given directory of the
// filesystem. This is optional and the default is to load all the templates.
func (b *EngineBuilder) SetDir(value string) *EngineBuilder {
	b.dir = value
	return b
}

// Build uses the configuration stored in the builder to create a new engine.
func (b *EngineBuilder) Build() (result *Engine, err error) {
	// Check parameters:
	if b.logger.GetSink() == nil {
		err = errors.New("logger is mandatory")
		return
	}
	if b.fsys == nil {
		err = errors.New("filesystem is mandatory")
		return
	}

	// Calculate the root directory:
	fsys := b.fsys
	if b.dir != "" {
		fsys, err = fs.Sub(b.fsys, b.dir)
		if err != nil {
			return
		}
	}

	// We need to create the engine early because the some of the functions need the pointer:
	e := &Engine{
		logger:   b.logger,
		template: tmpl.New(""),
	}

	// Register the functions:
	e.template.Funcs(tmpl.FuncMap{
		"base64":  e.base64Func,
		"execute": e.executeFunc,
		"json":    e.jsonFunc,
		"uuid":    e.uuidFunc,
	})

	// Find and parse the template files:
	err = e.findTemplates(fsys)
	if err != nil {
		return
	}
	err = e.parseTemplates(fsys)
	if err != nil {
		return
	}

	// Return the object:
	result = e
	return
}

func (e *Engine) findTemplates(fsys fs.FS) error {
	return fs.WalkDir(fsys, ".", func(name string, entry fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if entry.IsDir() {
			return nil
		}
		e.names = append(e.names, name)
		return nil
	})
}

func (e *Engine) parseTemplates(fsys fs.FS) error {
	for _, name := range e.names {
		err := e.parseTemplate(fsys, name)
		if err != nil {
			return err
		}
	}
	return nil
}

func (e *Engine) parseTemplate(fsys fs.FS, name string) error {
	data, err := fs.ReadFile(fsys, name)
	if err != nil {
		return err
	}
	text := string(data)
	_, err = e.template.New(name).Parse(text)
	if err != nil {
		return err
	}
	detail := e.logger.V(2)
	if detail.Enabled() {
		detail.Info(
			"Parsed template",
			"name", name,
			"text", text,
		)
	}
	return nil
}

// Execute executes the template with the given name and passing the given input data. It writes the
// result to the given writer.
func (e *Engine) Execute(writer io.Writer, name string, data any) error {
	buffer := &bytes.Buffer{}
	err := e.template.ExecuteTemplate(buffer, name, data)
	if err != nil {
		return err
	}
	_, err = buffer.WriteTo(writer)
	if err != nil {
		return err
	}
	detail := e.logger.V(2)
	if detail.Enabled() {
		detail.Info(
			"Executed template",
			"name", name,
			"data", data,
			"text", buffer.String(),
		)
	}
	return nil
}

// Names returns the names of the templates.
func (e *Engine) Names() []string {
	return slices.Clone(e.names)
}

// base64Func is a template function that encodes the given data using Base64 and returns the result
// as a string. If the data is an array of bytes it will be encoded directly. If the data is a
// string it will be converted to an array of bytes using the UTF-8 encoding. If the data implements
// the fmt.Stringer interface it will be converted to a string using the String method, and then to
// an array of bytes using the UTF-8 encoding. Any other kind of data will result in an error.
func (e *Engine) base64Func(value any) (result string, err error) {
	var data []byte
	switch typed := value.(type) {
	case []byte:
		data = typed
	case string:
		data = []byte(typed)
	case fmt.Stringer:
		data = []byte(typed.String())
	default:
		err = fmt.Errorf(
			"don't know how to encode value of type %T",
			value,
		)
		if err != nil {
			return
		}
	}
	result = base64.StdEncoding.EncodeToString(data)
	return
}

// executeFunc is a template function similar to template.ExecuteTemplate but it returns the result
// instead of writing it to the output. That is useful when some processing is needed after that,
// for example, to encode the result using Base64:
//
//	{{ execute "my.tmpl" . | base64 }}
func (e *Engine) executeFunc(name string, data any) (result string, err error) {
	buffer := &bytes.Buffer{}
	executed := e.template.Lookup(name)
	if executed == nil {
		err = fmt.Errorf("failed to find template '%s'", name)
		return
	}
	err = executed.Execute(buffer, data)
	if err != nil {
		return
	}
	result = buffer.String()
	return
}

// jsonFunc is a template function that encodes the given data as JSON. This can be used, for
// example, to encode as a JSON string the result of executing other function. For example, to
// create a JSON document with a 'content' field that contains the text of the 'my.tmpl' template:
//
//	"content": {{ execute "my.tmpl" . | json }}
//
// Note how that the value of that 'content' field doesn't need to sorrounded by quotes, because the
// 'json' function will generate a valid JSON string, including those quotes.
func (e *Engine) jsonFunc(data any) (result string, err error) {
	text, err := json.Marshal(data)
	if err != nil {
		return
	}
	result = string(text)
	return
}

// uuidFunc is a template function that generates a random UUID.
func (e *Engine) uuidFunc() string {
	return uuid.NewString()
}
