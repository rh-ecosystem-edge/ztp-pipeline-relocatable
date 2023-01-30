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
	"sort"
	"strings"
	"unicode"
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

	// Join the lines:
	buffer := &bytes.Buffer{}
	for _, line := range lines {
		buffer.WriteString(line)
		buffer.WriteString("\n")
	}

	return buffer.String()
}
