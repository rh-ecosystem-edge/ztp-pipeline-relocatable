/*
Copyright 2022 Red Hat Inc.

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
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"testing"

	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/gomega"
)

func TestTemplating(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Templating")
}

// TmpFS creates a temporary directory containing the given files, and then creates a fs.FS object
// that can be used to access it.
//
// The files are specified as pairs of full path names and content. For example, to create a file
// named `mydir/myfile.yaml` containig some YAML text and a file `yourdir/yourfile.json` containing
// some JSON text:
//
//	dir, fsys = TmpFS(
//		"mydir/myfile.yaml",
//		`
//			name: Joe
//			age: 52
//		`,
//		"yourdir/yourfile.json",
//		`{
//			"name": "Mary",
//			"age": 59
//		}`
//	)
//
// Directories are created automatically when they contain at least one file or subdirectory.
//
// The caller is responsible for removing the directory once it is no longer needed.
func TmpFS(args ...string) (dir string, fsys fs.FS) {
	Expect(len(args) % 2).To(BeZero())
	dir, err := os.MkdirTemp("", "*.testfs")
	Expect(err).ToNot(HaveOccurred())
	for i := 0; i < len(args)/2; i++ {
		name := args[2*i]
		text := args[2*i+1]
		file := filepath.Join(dir, name)
		sub := filepath.Dir(file)
		_, err = os.Stat(sub)
		if errors.Is(err, os.ErrNotExist) {
			err = os.MkdirAll(sub, 0700)
			Expect(err).ToNot(HaveOccurred())
		} else {
			Expect(err).ToNot(HaveOccurred())
		}
		err = os.WriteFile(file, []byte(text), 0600)
		Expect(err).ToNot(HaveOccurred())
	}
	fsys = os.DirFS(dir)
	return
}
