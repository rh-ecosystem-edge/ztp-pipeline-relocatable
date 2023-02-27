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
	"sort"
	"strings"
	"unicode"

	. "github.com/onsi/gomega"
)

// Dedent removes from the given string all the whitespace that is common to all the lines.
func Dedent(text string) string {
	// Normalize blank lines replacing them with empty strings:
	lines := strings.Split(text, "\n")
	for i, line := range lines {
		if strings.TrimSpace(line) == "" {
			lines[i] = ""
		}
	}

	// Calculate the set of white space prefixes for all the non blank lines:
	set := map[string]bool{}
	for _, line := range lines {
		length := strings.IndexFunc(line, func(r rune) bool {
			return !unicode.IsSpace(r)
		})
		if length == -1 {
			continue
		}
		set[line[0:length]] = true
	}

	// Sort the prefixes by length, from longest to shortest:
	list := make([]string, len(set))
	i := 0
	for prefix := range set {
		list[i] = prefix
		i++
	}
	sort.Slice(list, func(i, j int) bool {
		return len(list[i]) > len(list[j])
	})

	// Find the length prefix that is a prefix of all the lines:
	var length int
	for _, prefix := range list {
		i := 0
		for _, line := range lines {
			if line != "" && !strings.HasPrefix(line, prefix) {
				break
			}
			i++
		}
		if i == len(lines) {
			length = len(prefix)
			break
		}
	}

	// Remove the prefix from all the lines:
	for i, line := range lines {
		if line == "" {
			continue
		}
		lines[i] = line[length:]
	}

	// Join the lines, but taking into account that if the original text had an ending line
	// break we want to preserve it:
	size := len(lines)
	for _, line := range lines {
		size += len(line)
	}
	builder := &strings.Builder{}
	builder.Grow(size)
	for i, line := range lines {
		if i > 0 {
			builder.WriteString("\n")
		}
		builder.WriteString(line)
	}
	if strings.HasSuffix(text, "\n") {
		builder.WriteString("\n")
	}
	return builder.String()
}

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
