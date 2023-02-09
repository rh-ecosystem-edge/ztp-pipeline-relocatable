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

package logging

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"math"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"time"

	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/ginkgo/v2/dsl/table"
	. "github.com/onsi/gomega"
)

var _ = Describe("Logger", func() {
	It("Rejects negative level", func() {
		buffer := &bytes.Buffer{}
		logger, err := NewLogger().
			SetWriter(buffer).
			SetLevel(-1).
			Build()
		Expect(err).To(HaveOccurred())
		msg := err.Error()
		Expect(msg).To(ContainSubstring("-1"))
		Expect(msg).To(ContainSubstring("greater than or equal to zero"))
		Expect(logger.GetSink()).To(BeNil())
	})

	It("Writes time in UTC", func() {
		// Create a logger that writes to a memory buffer:
		buffer := &bytes.Buffer{}
		logger, err := NewLogger().
			SetWriter(buffer).
			SetLevel(math.MaxInt).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Write a message:
		logger.Info("")

		// Verify the fields:
		var msg struct {
			TS string `json:"ts"`
		}
		err = json.Unmarshal(buffer.Bytes(), &msg)
		Expect(err).ToNot(HaveOccurred())
		ts, err := time.Parse(time.RFC3339, msg.TS)
		Expect(err).ToNot(HaveOccurred())
		zone, offset := ts.Zone()
		Expect(zone).To(Equal("UTC"))
		Expect(offset).To(BeZero())
	})

	It("Writes time in RFC3339 format", func() {
		// Create a logger that writes to a memory buffer:
		buffer := &bytes.Buffer{}
		logger, err := NewLogger().
			SetWriter(buffer).
			SetLevel(math.MaxInt).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Write a message:
		logger.Info("")

		// Verify the fields:
		var msg struct {
			TS string `json:"ts"`
		}
		err = json.Unmarshal(buffer.Bytes(), &msg)
		Expect(err).ToNot(HaveOccurred())
		_, err = time.Parse(time.RFC3339, msg.TS)
		Expect(err).ToNot(HaveOccurred())
	})

	It("Writes `error` for error messages", func() {
		// Create a logger that writes to a memory buffer:
		buffer := &bytes.Buffer{}
		logger, err := NewLogger().
			SetWriter(buffer).
			SetLevel(math.MaxInt).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Write a message:
		logger.Error(errors.New(""), "")

		// Verify the fields:
		var msg struct {
			Level string `json:"level"`
		}
		err = json.Unmarshal(buffer.Bytes(), &msg)
		Expect(err).ToNot(HaveOccurred())
		Expect(msg.Level).To(Equal("error"))
	})

	DescribeTable(
		"Writes `error` for error messages regardless of the level",
		func(v int) {
			// Create a logger that writes to a memory buffer:
			buffer := &bytes.Buffer{}
			logger, err := NewLogger().
				SetWriter(buffer).
				SetLevel(math.MaxInt).
				Build()
			Expect(err).ToNot(HaveOccurred())

			// Write a message:
			logger.V(v).Error(errors.New(""), "")

			// Verify the fields:
			var msg struct {
				Level string `json:"level"`
			}
			err = json.Unmarshal(buffer.Bytes(), &msg)
			Expect(err).ToNot(HaveOccurred())
			Expect(msg.Level).To(Equal("error"))
		},
		Entry("Zero", 0),
		Entry("One", 1),
		Entry("Two", 2),
		Entry("Three", 3),
		Entry("Four", 4),
		Entry("Five", 5),
		Entry("Six", 6),
		Entry("Seven", 7),
		Entry("Eight", 8),
		Entry("Nine", 9),
	)

	DescribeTable(
		"Doesn't write level for error messages",
		func(v int) {
			// Create a logger that writes to a memory buffer:
			buffer := &bytes.Buffer{}
			logger, err := NewLogger().
				SetWriter(buffer).
				SetLevel(math.MaxInt).
				Build()
			Expect(err).ToNot(HaveOccurred())

			// Write a message:
			logger.V(v).Error(errors.New(""), "")

			// Verify the fields:
			var msg struct {
				V *int `json:"v"`
			}
			err = json.Unmarshal(buffer.Bytes(), &msg)
			Expect(err).ToNot(HaveOccurred())
			Expect(msg.V).To(BeNil())
		},
		Entry("Zero", 0),
		Entry("One", 1),
		Entry("Two", 2),
		Entry("Three", 3),
		Entry("Four", 4),
		Entry("Five", 5),
		Entry("Six", 6),
		Entry("Seven", 7),
		Entry("Eight", 8),
		Entry("Nine", 9),
	)

	It("Writes `info` for info messages", func() {
		// Create a logger that writes to a memory buffer:
		buffer := &bytes.Buffer{}
		logger, err := NewLogger().
			SetWriter(buffer).
			SetLevel(math.MaxInt).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Write a message:
		logger.Info("")

		// Verify the fields:
		var msg struct {
			Level string `json:"level"`
		}
		err = json.Unmarshal(buffer.Bytes(), &msg)
		Expect(err).ToNot(HaveOccurred())
		Expect(msg.Level).To(Equal("info"))
	})

	It("Writes `info` for level zero", func() {
		// Create a logger that writes to a memory buffer:
		buffer := &bytes.Buffer{}
		logger, err := NewLogger().
			SetWriter(buffer).
			SetLevel(math.MaxInt).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Write a message:
		logger.V(0).Info("")

		// Verify the fields:
		var msg struct {
			Level string `json:"level"`
		}
		err = json.Unmarshal(buffer.Bytes(), &msg)
		Expect(err).ToNot(HaveOccurred())
	})

	DescribeTable(
		"Writes `debug` for level greater than zero",
		func(v int) {
			// Create a logger that writes to a memory buffer:
			buffer := &bytes.Buffer{}
			logger, err := NewLogger().
				SetWriter(buffer).
				SetLevel(math.MaxInt).
				Build()
			Expect(err).ToNot(HaveOccurred())

			// Write a message:
			logger.V(v).Info("")

			// Verify the fields:
			var msg struct {
				Level string `json:"level"`
			}
			err = json.Unmarshal(buffer.Bytes(), &msg)
			Expect(err).ToNot(HaveOccurred())
			Expect(msg.Level).To(Equal("debug"))
		},
		Entry("One", 1),
		Entry("Two", 2),
		Entry("Three", 3),
		Entry("Four", 4),
		Entry("Five", 5),
		Entry("Six", 6),
		Entry("Seven", 7),
		Entry("Eight", 8),
		Entry("Nine", 9),
	)

	DescribeTable(
		"Writes for level",
		func(v int) {
			// Create a logger that writes to a memory buffer:
			buffer := &bytes.Buffer{}
			logger, err := NewLogger().
				SetWriter(buffer).
				SetLevel(math.MaxInt).
				Build()
			Expect(err).ToNot(HaveOccurred())

			// Write a message:
			logger.V(v).Info("")

			// Verify the fields:
			var msg struct {
				V int `json:"v"`
			}
			err = json.Unmarshal(buffer.Bytes(), &msg)
			Expect(err).ToNot(HaveOccurred())
			Expect(msg.V).To(Equal(v))
		},
		Entry("Zero", 1),
		Entry("One", 1),
		Entry("Two", 2),
		Entry("Three", 3),
		Entry("Four", 4),
		Entry("Five", 5),
		Entry("Six", 6),
		Entry("Seven", 7),
		Entry("Eight", 8),
		Entry("Nine", 9),
	)

	It("Doesn't write debug messages by default (level is zero)", func() {
		// Create a logger that writes to a memory buffer:
		buffer := &bytes.Buffer{}
		logger, err := NewLogger().
			SetWriter(buffer).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Write a message:
		logger.V(1).Info("")

		// Verify that no message was written:
		Expect(buffer.Len()).To(BeZero())
	})

	It("Doesn't write debug messages when level is explicitly set to zero", func() {
		// Create a logger that writes to a memory buffer:
		buffer := &bytes.Buffer{}
		logger, err := NewLogger().
			SetWriter(buffer).
			SetLevel(0).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Write a message:
		logger.V(1).Info("")

		// Verify that no message was written:
		Expect(buffer.Len()).To(BeZero())
	})

	DescribeTable(
		"Writes debug messages with level less than or equal to the maximum",
		func(v int) {
			// Create a logger that writes to a memory buffer:
			buffer := &bytes.Buffer{}
			logger, err := NewLogger().
				SetWriter(buffer).
				SetLevel(v).
				Build()
			Expect(err).ToNot(HaveOccurred())

			// Write a message:
			logger.V(v).Info("")

			// Verify that something was written:
			Expect(buffer.Len()).ToNot(BeZero())
		},
		Entry("Zero", 1),
		Entry("One", 1),
		Entry("Two", 2),
		Entry("Three", 3),
		Entry("Four", 4),
		Entry("Five", 5),
		Entry("Six", 6),
		Entry("Seven", 7),
		Entry("Eight", 8),
		Entry("Nine", 9),
	)

	DescribeTable(
		"Doesn't write debug messages with level greater than the maximum",
		func(v int) {
			// Create a logger that writes to a memory buffer:
			buffer := &bytes.Buffer{}
			logger, err := NewLogger().
				SetWriter(buffer).
				SetLevel(v).
				Build()
			Expect(err).ToNot(HaveOccurred())

			// Write some messages with levels greater than the configured one:
			for i := 1; i <= 10; i++ {
				logger.V(v + i).Info("")
			}

			// Verify that nothing was written:
			Expect(buffer.Len()).To(BeZero())
		},
		Entry("Zero", 1),
		Entry("One", 1),
		Entry("Two", 2),
		Entry("Three", 3),
		Entry("Four", 4),
		Entry("Five", 5),
		Entry("Six", 6),
		Entry("Seven", 7),
		Entry("Eight", 8),
		Entry("Nine", 9),
	)

	It("Doesn't write to the default file if a writer is provided", func() {
		// We skip this test in non Linux operating systems because there we can't use a
		// temporary directory via the `XDG_CACHE_HOME` environment variable.
		if runtime.GOOS != "linux" {
			Skip("Don't know how to use temporary directory.")
		}

		// Create a temporary cache directory:
		tmpCache, err := os.MkdirTemp("", "*.test")
		Expect(err).ToNot(HaveOccurred())
		defer func() {
			err := os.RemoveAll(tmpCache)
			Expect(err).ToNot(HaveOccurred())
		}()
		oldCache := os.Getenv("XDG_CACHE_HOME")
		defer os.Setenv("XDG_CACHE_HOME", oldCache)
		os.Setenv("XDG_CACHE_HOME", tmpCache)

		// Create the logger witho a writer:
		logger, err := NewLogger().
			SetWriter(io.Discard).
			SetLevel(math.MaxInt).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Write a message:
		logger.Info("my message")

		// Check that the log file hasn't been created:
		file := filepath.Join(tmpCache, "ztp", "ztp.log")
		Expect(file).ToNot(BeAnExistingFile())
	})

	It("Writes to the default file if no writer is provided", func() {
		// We skip this test in non Linux operating systems because there we can't use a
		// temporary directory via the `XDG_CACHE_HOME` environment variable.
		if runtime.GOOS != "linux" {
			Skip("Don't know how to use temporary directory.")
		}

		// Create a temporary cache directory:
		tmpCache, err := os.MkdirTemp("", "*.test")
		Expect(err).ToNot(HaveOccurred())
		defer func() {
			err := os.RemoveAll(tmpCache)
			Expect(err).ToNot(HaveOccurred())
		}()
		oldCache := os.Getenv("XDG_CACHE_HOME")
		defer os.Setenv("XDG_CACHE_HOME", oldCache)
		os.Setenv("XDG_CACHE_HOME", tmpCache)

		// Create the logger without a writer:
		logger, err := NewLogger().
			SetLevel(math.MaxInt).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Write a message:
		logger.Info("my message")

		// Check that the log file was created:
		file := filepath.Join(tmpCache, "ztp", "ztp.log")
		Expect(file).To(BeARegularFile())
		data, err := os.ReadFile(file)
		Expect(err).ToNot(HaveOccurred())
		var msg struct {
			Msg string `json:"msg"`
		}
		err = json.Unmarshal(data, &msg)
		Expect(err).ToNot(HaveOccurred())
		Expect(msg.Msg).To(Equal("my message"))
	})

	It("Appends to the default file if already exists", func() {
		// We skip this test in non Linux operating systems because there we can't use a
		// temporary directory via the `XDG_CACHE_HOME` environment variable.
		if runtime.GOOS != "linux" {
			Skip("Don't know how to use temporary directory.")
		}

		// Create a temporary cache directory:
		tmpCache, err := os.MkdirTemp("", "*.test")
		Expect(err).ToNot(HaveOccurred())
		defer func() {
			err := os.RemoveAll(tmpCache)
			Expect(err).ToNot(HaveOccurred())
		}()
		oldCache := os.Getenv("XDG_CACHE_HOME")
		defer os.Setenv("XDG_CACHE_HOME", oldCache)
		os.Setenv("XDG_CACHE_HOME", tmpCache)

		// Write something to the file:
		dir := filepath.Join(tmpCache, "ztp")
		err = os.MkdirAll(dir, 0700)
		Expect(err).ToNot(HaveOccurred())
		file := filepath.Join(tmpCache, "ztp", "ztp.log")
		err = os.WriteFile(file, []byte("{}\n"), 0600)
		Expect(err).ToNot(HaveOccurred())

		// Create the logger without a writer:
		logger, err := NewLogger().
			SetLevel(math.MaxInt).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Write a message:
		logger.Info("my message")

		// Check that the message has been appended:
		data, err := os.ReadFile(file)
		Expect(err).ToNot(HaveOccurred())
		lines := strings.Split(string(data), "\n")
		Expect(lines).To(HaveLen(3))
		Expect(lines[0]).To(Equal("{}"))
		var msg struct {
			Msg string `json:"msg"`
		}
		err = json.Unmarshal([]byte(lines[1]), &msg)
		Expect(err).ToNot(HaveOccurred())
		Expect(msg.Msg).To(Equal("my message"))
		Expect(lines[2]).To(BeEmpty())
	})

	It("Writes to the explicitly provided file", func() {
		// Create a temporary directory for the log file:
		tmp, err := os.MkdirTemp("", "*.test")
		Expect(err).ToNot(HaveOccurred())
		defer func() {
			err := os.RemoveAll(tmp)
			Expect(err).ToNot(HaveOccurred())
		}()
		file := filepath.Join(tmp, "my.log")

		// Create the logger:
		logger, err := NewLogger().
			SetLevel(math.MaxInt).
			SetFile(file).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Write a message:
		logger.Info("my message")

		// Check that the file has been created:
		info, err := os.Stat(file)
		Expect(err).ToNot(HaveOccurred())
		Expect(info.Size()).To(BeNumerically(">=", 0))

		// Check that the file has read and write permissions for the owner:
		Expect(info.Mode() & 0400).ToNot(BeZero())
		Expect(info.Mode() & 0200).ToNot(BeZero())

		// Check that the file doesn't have execution permissions:
		Expect(info.Mode() & 0111).To(BeZero())
	})
})
