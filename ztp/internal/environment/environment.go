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

package environment

import (
	"fmt"
	"sort"
	"strconv"
	"strings"

	"golang.org/x/exp/maps"
)

// Builder contains the data and logic needed to build a set of environment variables. Don't create
// instances of this type directly, use the New function instead.
type Builder struct {
	vars map[string]any
}

// New creates a new builder that can then be used to create a set of environment variables.
func New() *Builder {
	return &Builder{
		vars: map[string]any{},
	}
}

// SetEnv sets the environment variables given in the name value pairs.
func (b *Builder) SetEnv(values ...string) *Builder {
	for _, pair := range values {
		var name, value string
		equal := strings.Index(pair, "=")
		if equal != -1 {
			name = pair[0:equal]
			value = pair[equal+1:]
		} else {
			name = pair
			value = ""
		}
		b.vars[name] = value
	}
	return b
}

// SetVar sets an environment variable to in the given environment. If the variable already exists
// then the value will be replaced.
func (b *Builder) SetVar(name string, value any) *Builder {
	b.vars[name] = value
	return b
}

// AddVars adds a collection of environment variables. Variables that already exist will be replaced.
func (b *Builder) SetVars(values map[string]any) *Builder {
	maps.Copy(b.vars, values)
	return b
}

// Build returns the resulting set of environment variables. Each item in the returned array is a
// name value pair.
func (b *Builder) Build() (result []string, err error) {
	names := maps.Keys(b.vars)
	pairs := make([]string, len(names))
	sort.Strings(names)
	for i, name := range names {
		var text string
		switch value := b.vars[name].(type) {
		case nil:
			text = ""
		case string:
			text = value
		case fmt.Stringer:
			text = value.String()
		case bool:
			text = strconv.FormatBool(value)
		case int, int8, int16, int32, int64, uint, uint8, uint16, uint32, uint64:
			text = fmt.Sprintf("%v", value)
		case float32, float64:
			text = fmt.Sprintf("%v", value)
		default:
			err = fmt.Errorf(
				"failed to convert value of environment variable '%s' of type '%T' to string",
				name, value,
			)
			return
		}
		pairs[i] = fmt.Sprintf("%s=%s", name, text)
	}
	result = pairs
	return
}
