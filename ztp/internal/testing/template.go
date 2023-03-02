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

package testing

import (
	"bytes"
	"html/template"

	. "github.com/onsi/gomega"
)

// Templates generates a string from the given templlate source and name value pairs.
func Template(source string, args ...any) string {
	// Check that there is an even number of args, and that the first of each pair is a string:
	count := len(args)
	Expect(count%2).To(
		Equal(0),
		"Template '%s' should have an even number of arguments, but it has %d",
		source, count,
	)
	for i := 0; i < count; i = i + 2 {
		name := args[i]
		_, ok := name.(string)
		Expect(ok).To(
			BeTrue(),
			"Argument %d of template '%s' is a key, so it should be a string, "+
				"but its type is %T",
			i, source, name,
		)
	}

	// Put the variables in the map that will be passed as the data object for the execution of
	// the template:
	data := make(map[string]interface{})
	for i := 0; i < count; i = i + 2 {
		name := args[i].(string)
		value := args[i+1]
		data[name] = value
	}

	// Parse the template:
	tmpl, err := template.New("").Parse(source)
	Expect(err).ToNot(
		HaveOccurred(),
		"Can't parse template '%s': %v",
		source, err,
	)

	// Execute the template:
	buffer := new(bytes.Buffer)
	err = tmpl.Execute(buffer, data)
	Expect(err).ToNot(
		HaveOccurred(),
		"Can't execute template '%s': %v",
		source, err,
	)
	return buffer.String()
}
