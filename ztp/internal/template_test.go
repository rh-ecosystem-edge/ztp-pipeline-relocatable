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
	"errors"
	"io/fs"
	"math"
	"os"
	"path/filepath"

	"github.com/go-logr/logr"
	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/ginkgo/v2/dsl/table"
	. "github.com/onsi/gomega"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/logging"
)

var _ = Describe("Template", func() {
	var logger logr.Logger

	BeforeEach(func() {
		var err error
		logger, err = logging.NewLogger().
			SetWriter(GinkgoWriter).
			SetV(math.MaxInt).
			Build()
		Expect(err).ToNot(HaveOccurred())
	})

	It("Can't be created without a logger", func() {
		// Create the filesystem:
		tmp, fsys := TmpFS()
		defer os.RemoveAll(tmp)

		// Create the template:
		template, err := NewTemplate().
			SetFS(fsys).
			Build()
		Expect(err).To(HaveOccurred())
		msg := err.Error()
		Expect(msg).To(ContainSubstring("logger"))
		Expect(msg).To(ContainSubstring("mandatory"))
		Expect(template).To(BeNil())
	})

	It("Can't be created without a filesystem", func() {
		template, err := NewTemplate().
			SetLogger(logger).
			Build()
		Expect(err).To(HaveOccurred())
		msg := err.Error()
		Expect(msg).To(ContainSubstring("filesystem"))
		Expect(msg).To(ContainSubstring("mandatory"))
		Expect(template).To(BeNil())
	})

	It("Loads single template file", func() {
		// Create the file system:
		tmp, fsys := TmpFS(
			"a.txt", "a",
		)
		defer os.RemoveAll(tmp)

		// Create the template:
		template, err := NewTemplate().
			SetLogger(logger).
			SetFS(fsys).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Verify that it has loaded the file:
		names := template.Names()
		Expect(names).To(ConsistOf("a.txt"))
	})

	It("Loads multiple template files", func() {
		// Create the file system:
		tmp, fsys := TmpFS(
			"a.txt", "a",
			"b.txt", "b",
			"c.txt", "c",
		)
		defer os.RemoveAll(tmp)

		// Create the template:
		template, err := NewTemplate().
			SetLogger(logger).
			SetFS(fsys).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Verify that it has loaded the file:
		names := template.Names()
		Expect(names).To(ConsistOf("a.txt", "b.txt", "c.txt"))
	})

	It("Executes simple template", func() {
		// Create the file system:
		tmp, fsys := TmpFS(
			"a.txt", "a",
		)
		defer os.RemoveAll(tmp)

		// Create the template:
		template, err := NewTemplate().
			SetLogger(logger).
			SetFS(fsys).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Execute the template:
		buffer := &bytes.Buffer{}
		err = template.Execute(buffer, "a.txt", nil)
		Expect(err).ToNot(HaveOccurred())
		text := buffer.String()
		Expect(text).To(Equal("a"))
	})

	It("Executes multiple templates", func() {
		// Create the file system:
		tmp, fsys := TmpFS(
			"a.txt", "a",
			"b.txt", "b",
			"c.txt", "c",
		)
		defer os.RemoveAll(tmp)

		// Create the template:
		template, err := NewTemplate().
			SetLogger(logger).
			SetFS(fsys).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Execute the first template:
		buffer := &bytes.Buffer{}
		err = template.Execute(buffer, "a.txt", nil)
		Expect(err).ToNot(HaveOccurred())
		Expect(buffer.String()).To(Equal("a"))

		// Executes the second template:
		buffer.Reset()
		err = template.Execute(buffer, "b.txt", nil)
		Expect(err).ToNot(HaveOccurred())
		Expect(buffer.String()).To(Equal("b"))

		// Executes the third template:
		buffer.Reset()
		err = template.Execute(buffer, "c.txt", nil)
		Expect(err).ToNot(HaveOccurred())
		Expect(buffer.String()).To(Equal("c"))
	})

	It("Executes template inside directory", func() {
		// Create the file system:
		tmp, fsys := TmpFS(
			"first/second/myfile.txt", "mytext",
		)
		defer os.RemoveAll(tmp)

		// Create the template:
		template, err := NewTemplate().
			SetLogger(logger).
			SetFS(fsys).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Execute the template:
		buffer := &bytes.Buffer{}
		err = template.Execute(buffer, "first/second/myfile.txt", nil)
		Expect(err).ToNot(HaveOccurred())
		Expect(buffer.String()).To(Equal("mytext"))
	})

	It("Reports template that doesn't exist", func() {
		// Create the file system:
		tmp, fsys := TmpFS(
			"good.txt", "mycontent",
		)
		defer os.RemoveAll(tmp)

		// Create the template:
		template, err := NewTemplate().
			SetLogger(logger).
			SetFS(fsys).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Execute the template:
		buffer := &bytes.Buffer{}
		err = template.Execute(buffer, "bad.txt", nil)
		Expect(err).To(HaveOccurred())
		msg := err.Error()
		Expect(msg).To(ContainSubstring("no template"))
		Expect(msg).To(ContainSubstring("bad.txt"))
	})

	It("Passes data to the template", func() {
		// Create the file system:
		tmp, fsys := TmpFS(
			"f.txt", "x={{ .X }} y={{ .Y }}",
		)
		defer os.RemoveAll(tmp)

		// Create the template:
		template, err := NewTemplate().
			SetLogger(logger).
			SetFS(fsys).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Execute the template:
		buffer := &bytes.Buffer{}
		err = template.Execute(buffer, "f.txt", map[string]any{
			"X": 42,
			"Y": 24,
		})
		Expect(err).ToNot(HaveOccurred())
		Expect(buffer.String()).To(Equal("x=42 y=24"))
	})

	It("Honours the optional directory", func() {
		// Create the file system:
		tmp, fsys := TmpFS(
			"mydir/myfile.txt", "mytext",
		)
		defer os.RemoveAll(tmp)

		// Create the template:
		template, err := NewTemplate().
			SetLogger(logger).
			SetFS(fsys).
			SetDir("mydir").
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Execute the template:
		buffer := &bytes.Buffer{}
		err = template.Execute(buffer, "myfile.txt", nil)
		Expect(err).ToNot(HaveOccurred())
		Expect(buffer.String()).To(Equal("mytext"))
	})

	Context("Template function 'execute'", func() {
		It("Executes the target template", func() {
			// Create the file system:
			tmp, fsys := TmpFS(
				"caller.txt", `{{ execute "called.txt" . }}`,
				"called.txt", `mytext`,
			)
			defer os.RemoveAll(tmp)

			// Create the template:
			template, err := NewTemplate().
				SetLogger(logger).
				SetFS(fsys).
				Build()
			Expect(err).ToNot(HaveOccurred())

			// Execute the template:
			buffer := &bytes.Buffer{}
			err = template.Execute(buffer, "caller.txt", nil)
			Expect(err).ToNot(HaveOccurred())
			Expect(buffer.String()).To(Equal("mytext"))
		})

		It("Executes multiple chained templates", func() {
			// Create the file system:
			tmp, fsys := TmpFS(
				"first.txt", `{{ execute "second.txt" . }}`,
				"second.txt", `{{ execute "third.txt" . }}`,
				"third.txt", `mytext`,
			)
			defer os.RemoveAll(tmp)

			// Create the template:
			template, err := NewTemplate().
				SetLogger(logger).
				SetFS(fsys).
				Build()
			Expect(err).ToNot(HaveOccurred())

			// Execute the template:
			buffer := &bytes.Buffer{}
			err = template.Execute(buffer, "first.txt", nil)
			Expect(err).ToNot(HaveOccurred())
			Expect(buffer.String()).To(Equal("mytext"))
		})

		It("Accepts input", func() {
			// Create the file system:
			tmp, fsys := TmpFS(
				"caller.txt", `{{ execute "called.txt" 42 }}`,
				"called.txt", `{{ . }}`,
			)
			defer os.RemoveAll(tmp)

			// Create the template:
			template, err := NewTemplate().
				SetLogger(logger).
				SetFS(fsys).
				Build()
			Expect(err).ToNot(HaveOccurred())

			// Execute the template:
			buffer := &bytes.Buffer{}
			err = template.Execute(buffer, "caller.txt", nil)
			Expect(err).ToNot(HaveOccurred())
			Expect(buffer.String()).To(Equal("42"))
		})
	})

	Context("Template function 'base64'", func() {
		It("Encodes text", func() {
			// Create the file system:
			tmp, fsys := TmpFS(
				"myfile.txt", `{{ "mytext" | base64 }}`,
			)
			defer os.RemoveAll(tmp)

			// Create the template:
			template, err := NewTemplate().
				SetLogger(logger).
				SetFS(fsys).
				Build()
			Expect(err).ToNot(HaveOccurred())

			// Execute the template:
			buffer := &bytes.Buffer{}
			err = template.Execute(buffer, "myfile.txt", nil)
			Expect(err).ToNot(HaveOccurred())
			Expect(buffer.String()).To(Equal("bXl0ZXh0"))
		})
	})

	DescribeTable(
		"Template function 'json'",
		func(input any, expected string) {
			// Create the file system:
			tmp, fsys := TmpFS(
				"myfile.txt", `{{ . | json }}`,
			)
			defer os.RemoveAll(tmp)

			// Create the template:
			template, err := NewTemplate().
				SetLogger(logger).
				SetFS(fsys).
				Build()
			Expect(err).ToNot(HaveOccurred())

			// Execute the template:
			buffer := &bytes.Buffer{}
			err = template.Execute(buffer, "myfile.txt", input)
			Expect(err).ToNot(HaveOccurred())
			Expect(buffer.String()).To(Equal(expected))
		},
		Entry(
			"String that doesn't need quotes",
			`mytext`,
			`"mytext"`,
		),
		Entry(
			"String that needs quotes",
			`my"text"`,
			`"my\"text\""`,
		),
		Entry(
			"Integer",
			42,
			`42`,
		),
		Entry(
			"Boolean",
			true,
			`true`,
		),
		Entry(
			"Struct without tags",
			struct {
				X int
				Y int
			}{
				X: 42,
				Y: 24,
			},
			`{"X":42,"Y":24}`,
		),
		Entry(
			"Struct with tags",
			struct {
				X int `json:"my_x"`
				Y int `json:"my_y"`
			}{
				X: 42,
				Y: 24,
			},
			`{"my_x":42,"my_y":24}`,
		),
		Entry(
			"Slice",
			[]int{42, 24},
			`[42,24]`,
		),
		Entry(
			"Map",
			map[string]int{"x": 42, "y": 24},
			`{"x":42,"y":24}`,
		),
	)
})

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
