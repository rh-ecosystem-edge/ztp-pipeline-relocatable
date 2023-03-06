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

package logging

import (
	"bytes"
	"fmt"
	"io"
	"math"
	"net/http"
	"strings"

	"github.com/go-logr/logr"
	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/ginkgo/v2/dsl/table"
	. "github.com/onsi/gomega"
	. "github.com/onsi/gomega/ghttp"
	"github.com/spf13/pflag"
)

var _ = Describe("Transport wrapper", func() {
	It("Can't be created without a logger", func() {
		wrapper, err := NewTransportWrapper().Build()
		Expect(err).To(HaveOccurred())
		msg := err.Error()
		Expect(msg).To(ContainSubstring("logger"))
		Expect(msg).To(ContainSubstring("mandatory"))
		Expect(wrapper).To(BeNil())
	})

	Context("With server", func() {
		var (
			server *Server
			buffer *bytes.Buffer
			logger logr.Logger
		)

		BeforeEach(func() {
			var err error

			// Create the server:
			server = NewServer()

			// Create a logger that writes to the Ginkgo writer and also a buffer in
			// memory, so that we can analyze the result:
			buffer = &bytes.Buffer{}
			logger, err = NewLogger().
				SetWriter(io.MultiWriter(buffer, GinkgoWriter)).
				SetLevel(math.MaxInt).
				Build()
			Expect(err).ToNot(HaveOccurred())
		})

		AfterEach(func() {
			// Stop the server:
			server.Close()
		})

		It("Writes the details of the request line", func() {
			// Prepare the server:
			server.AppendHandlers(RespondWith(http.StatusOK, nil))

			// Create the client:
			wrapper, err := NewTransportWrapper().
				SetLogger(logger).
				Build()
			Expect(err).ToNot(HaveOccurred())
			client := &http.Client{
				Transport: wrapper(http.DefaultTransport),
			}

			// Send the request:
			url := fmt.Sprintf("%s/my-path", server.URL())
			response, err := client.Get(url)
			Expect(err).ToNot(HaveOccurred())
			defer response.Body.Close()
			_, err = io.Copy(io.Discard, response.Body)
			Expect(err).ToNot(HaveOccurred())

			// Verify the request line details:
			messages := Parse(buffer)
			details := Find(messages, "Sending request")
			Expect(details).To(HaveLen(1))
			detail := details[0]
			Expect(detail).To(HaveKeyWithValue("method", http.MethodGet))
			Expect(detail).To(HaveKeyWithValue("url", url))
		})

		It("Writes the details of the response line", func() {
			// Prepare the server:
			server.AppendHandlers(RespondWith(http.StatusOK, nil))

			// Create the client:
			wrapper, err := NewTransportWrapper().
				SetLogger(logger).
				Build()
			Expect(err).ToNot(HaveOccurred())
			client := &http.Client{
				Transport: wrapper(http.DefaultTransport),
			}

			// Send the request:
			url := fmt.Sprintf("%s/my-path", server.URL())
			response, err := client.Get(url)
			Expect(err).ToNot(HaveOccurred())
			defer response.Body.Close()
			_, err = io.Copy(io.Discard, response.Body)
			Expect(err).ToNot(HaveOccurred())

			// Verify the response line details:
			messages := Parse(buffer)
			details := Find(messages, "Received response")
			Expect(details).ToNot(BeEmpty())
			detail := details[0]
			Expect(detail).To(HaveKeyWithValue("code", BeNumerically("==", http.StatusOK)))
		})

		It("Writes request headers if explicitly enabled", func() {
			// Prepare the server:
			server.AppendHandlers(RespondWith(http.StatusOK, nil))

			// Create the client:
			wrapper, err := NewTransportWrapper().
				SetLogger(logger).
				SetHeaders(true).
				Build()
			Expect(err).ToNot(HaveOccurred())
			client := &http.Client{
				Transport: wrapper(http.DefaultTransport),
			}

			// Send the request:
			url := fmt.Sprintf("%s/my-path", server.URL())
			request, err := http.NewRequest(http.MethodGet, url, nil)
			Expect(err).ToNot(HaveOccurred())
			request.Header.Set("My-Header", "my-value")
			response, err := client.Do(request)
			Expect(err).ToNot(HaveOccurred())
			defer response.Body.Close()
			_, err = io.Copy(io.Discard, response.Body)
			Expect(err).ToNot(HaveOccurred())

			// Verify the response line details:
			messages := Parse(buffer)
			details := Find(messages, "Sending request")
			Expect(details).ToNot(BeEmpty())
			detail := details[0]
			Expect(detail).To(HaveKeyWithValue(
				"headers", HaveKeyWithValue(
					"My-Header", ConsistOf("my-value"),
				),
			))
		})

		It("Doesn't write request headers if explicitly disabled", func() {
			// Prepare the server:
			server.AppendHandlers(RespondWith(http.StatusOK, nil))

			// Create the client:
			wrapper, err := NewTransportWrapper().
				SetLogger(logger).
				SetHeaders(false).
				Build()
			Expect(err).ToNot(HaveOccurred())
			client := &http.Client{
				Transport: wrapper(http.DefaultTransport),
			}

			// Send the request:
			url := fmt.Sprintf("%s/my-path", server.URL())
			response, err := client.Get(url)
			Expect(err).ToNot(HaveOccurred())
			defer response.Body.Close()
			_, err = io.Copy(io.Discard, response.Body)
			Expect(err).ToNot(HaveOccurred())

			// Verify the response line details:
			messages := Parse(buffer)
			details := Find(messages, "Sending request")
			Expect(details).ToNot(BeEmpty())
			detail := details[0]
			Expect(detail).ToNot(HaveKey("headers"))
		})

		It("Doesn't write request headers by default", func() {
			// Prepare the server:
			server.AppendHandlers(RespondWith(http.StatusOK, nil))

			// Create the client:
			wrapper, err := NewTransportWrapper().
				SetLogger(logger).
				Build()
			Expect(err).ToNot(HaveOccurred())
			client := &http.Client{
				Transport: wrapper(http.DefaultTransport),
			}

			// Send the request:
			url := fmt.Sprintf("%s/my-path", server.URL())
			response, err := client.Get(url)
			Expect(err).ToNot(HaveOccurred())
			defer response.Body.Close()
			_, err = io.Copy(io.Discard, response.Body)
			Expect(err).ToNot(HaveOccurred())

			// Verify the response line details:
			messages := Parse(buffer)
			details := Find(messages, "Sending request")
			Expect(details).ToNot(BeEmpty())
			detail := details[0]
			Expect(detail).ToNot(HaveKey("headers"))
		})

		It("Writes the details of the request body if explicitly enabled", func() {
			// Prepare the server:
			server.AppendHandlers(RespondWith(http.StatusOK, nil))

			// Create the client:
			wrapper, err := NewTransportWrapper().
				SetLogger(logger).
				SetBodies(true).
				Build()
			Expect(err).ToNot(HaveOccurred())
			client := &http.Client{
				Transport: wrapper(http.DefaultTransport),
			}

			// Send the request:
			url := fmt.Sprintf("%s/my-path", server.URL())
			body := make([]byte, 42)
			response, err := client.Post(url, "application/octet-stream", bytes.NewBuffer(body))
			Expect(err).ToNot(HaveOccurred())
			defer response.Body.Close()
			_, err = io.Copy(io.Discard, response.Body)
			Expect(err).ToNot(HaveOccurred())

			// Verify the number of bytes. Note that there may be multiple lines like
			// this if the response body was split into multiple network packages, so we
			// will sum the values of the `n` fields and count the total.
			messages := Parse(buffer)
			details := Find(messages, "Sending body")
			Expect(details).ToNot(BeEmpty())
			total := 0
			for _, detail := range details {
				Expect(detail).To(HaveKeyWithValue("n", BeNumerically(">=", 0)))
				total += int(detail["n"].(float64))
			}
			Expect(total).To(Equal(len(body)))
		})

		It("Doesn't write the details of the request body if explicitly disabled", func() {
			// Prepare the server:
			server.AppendHandlers(RespondWith(http.StatusOK, nil))

			// Create the client:
			wrapper, err := NewTransportWrapper().
				SetLogger(logger).
				SetBodies(false).
				Build()
			Expect(err).ToNot(HaveOccurred())
			client := &http.Client{
				Transport: wrapper(http.DefaultTransport),
			}

			// Send the request:
			url := fmt.Sprintf("%s/my-path", server.URL())
			body := make([]byte, 42)
			response, err := client.Post(url, "application/octet-stream", bytes.NewBuffer(body))
			Expect(err).ToNot(HaveOccurred())
			defer response.Body.Close()
			_, err = io.Copy(io.Discard, response.Body)
			Expect(err).ToNot(HaveOccurred())

			// Verify that the details aren't written:
			messages := Parse(buffer)
			details := Find(messages, "Sending body")
			Expect(details).To(BeEmpty())
		})

		It("Doesn't write the details of the request body by default", func() {
			// Prepare the server:
			server.AppendHandlers(RespondWith(http.StatusOK, nil))

			// Create the client:
			wrapper, err := NewTransportWrapper().
				SetLogger(logger).
				Build()
			Expect(err).ToNot(HaveOccurred())
			client := &http.Client{
				Transport: wrapper(http.DefaultTransport),
			}

			// Send the request:
			url := fmt.Sprintf("%s/my-path", server.URL())
			body := make([]byte, 42)
			response, err := client.Post(url, "application/octet-stream", bytes.NewBuffer(body))
			Expect(err).ToNot(HaveOccurred())
			defer response.Body.Close()
			_, err = io.Copy(io.Discard, response.Body)
			Expect(err).ToNot(HaveOccurred())

			// Verify that the details aren't written:
			messages := Parse(buffer)
			details := Find(messages, "Sending body")
			Expect(details).To(BeEmpty())
		})

		It("Writes the details of the response body if explicitly enabled", func() {
			// Prepare the server:
			body := make([]byte, 42)
			server.AppendHandlers(RespondWith(http.StatusOK, body))

			// Create the client:
			wrapper, err := NewTransportWrapper().
				SetLogger(logger).
				SetBodies(true).
				Build()
			Expect(err).ToNot(HaveOccurred())
			client := &http.Client{
				Transport: wrapper(http.DefaultTransport),
			}

			// Send the request:
			url := fmt.Sprintf("%s/my-path", server.URL())
			response, err := client.Post(url, "application/octet-stream", bytes.NewBuffer(body))
			Expect(err).ToNot(HaveOccurred())
			defer response.Body.Close()
			_, err = io.Copy(io.Discard, response.Body)
			Expect(err).ToNot(HaveOccurred())

			// Verify the number of bytes. Note that there may be multiple lines like
			// this if the response body was split into multiple network packages, so we
			// will sum the values of the `n` fields and count the total.
			messages := Parse(buffer)
			details := Find(messages, "Received body")
			Expect(details).ToNot(BeEmpty())
			total := 0
			for _, detail := range details {
				Expect(detail).To(HaveKeyWithValue("n", BeNumerically(">=", 0)))
				total += int(detail["n"].(float64))
			}
			Expect(total).To(Equal(len(body)))
		})

		It("Doesn't write the details of the response body if explicitly disabled", func() {
			// Prepare the server:
			body := make([]byte, 42)
			server.AppendHandlers(RespondWith(http.StatusOK, body))

			// Create the client:
			wrapper, err := NewTransportWrapper().
				SetLogger(logger).
				SetBodies(false).
				Build()
			Expect(err).ToNot(HaveOccurred())
			client := &http.Client{
				Transport: wrapper(http.DefaultTransport),
			}

			// Send the request:
			url := fmt.Sprintf("%s/my-path", server.URL())
			response, err := client.Post(url, "application/octet-stream", bytes.NewBuffer(body))
			Expect(err).ToNot(HaveOccurred())
			defer response.Body.Close()
			_, err = io.Copy(io.Discard, response.Body)
			Expect(err).ToNot(HaveOccurred())

			// Verify that details aren't written:
			messages := Parse(buffer)
			details := Find(messages, "Received response body")
			Expect(details).To(BeEmpty())
		})

		It("Doesn't write the details of the response body by default", func() {
			// Prepare the server:
			body := make([]byte, 42)
			server.AppendHandlers(RespondWith(http.StatusOK, body))

			// Create the client:
			wrapper, err := NewTransportWrapper().
				SetLogger(logger).
				Build()
			Expect(err).ToNot(HaveOccurred())
			client := &http.Client{
				Transport: wrapper(http.DefaultTransport),
			}

			// Send the request:
			url := fmt.Sprintf("%s/my-path", server.URL())
			response, err := client.Post(url, "application/octet-stream", bytes.NewBuffer(body))
			Expect(err).ToNot(HaveOccurred())
			defer response.Body.Close()
			_, err = io.Copy(io.Discard, response.Body)
			Expect(err).ToNot(HaveOccurred())

			// Verify that details aren't written:
			messages := Parse(buffer)
			details := Find(messages, "Received response body")
			Expect(details).To(BeEmpty())
		})

		DescribeTable(
			"Honors the --log-headers flag",
			func(expected bool, args ...string) {
				// Prepare the server:
				server.AppendHandlers(RespondWith(http.StatusOK, nil))

				// Prepare the flags:
				flags := pflag.NewFlagSet("", pflag.ContinueOnError)
				AddFlags(flags)
				err := flags.Parse(args)
				Expect(err).ToNot(HaveOccurred())

				// Create the client:
				wrapper, err := NewTransportWrapper().
					SetLogger(logger).
					SetFlags(flags).
					Build()
				Expect(err).ToNot(HaveOccurred())
				client := &http.Client{
					Transport: wrapper(http.DefaultTransport),
				}

				// Send the request:
				url := fmt.Sprintf("%s/my-path", server.URL())
				response, err := client.Get(url)
				Expect(err).ToNot(HaveOccurred())
				defer response.Body.Close()
				_, err = io.Copy(io.Discard, response.Body)
				Expect(err).ToNot(HaveOccurred())

				// Verify the response line details:
				messages := Parse(buffer)
				details := Find(messages, "Sending request")
				Expect(details).ToNot(BeEmpty())
				detail := details[0]
				if expected {
					Expect(detail).To(HaveKey("headers"))
				} else {
					Expect(detail).ToNot(HaveKey("headers"))
				}
			},
			Entry("Disabled by default", false),
			Entry("Explicitly enabled without value", true, "--log-headers"),
			Entry("Explicitly enabled with value", true, "--log-headers=true"),
			Entry("Explicitly disabled with value", false, "--log-headers=false"),
		)

		DescribeTable(
			"Honors the --log-bodies flag",
			func(expected bool, args ...string) {
				// Prepare the server:
				body := make([]byte, 42)
				server.AppendHandlers(RespondWith(http.StatusOK, body))

				// Prepare the flags:
				flags := pflag.NewFlagSet("", pflag.ContinueOnError)
				AddFlags(flags)
				err := flags.Parse(args)
				Expect(err).ToNot(HaveOccurred())

				// Create the client:
				wrapper, err := NewTransportWrapper().
					SetLogger(logger).
					SetFlags(flags).
					Build()
				Expect(err).ToNot(HaveOccurred())
				client := &http.Client{
					Transport: wrapper(http.DefaultTransport),
				}

				// Send the request:
				url := fmt.Sprintf("%s/my-path", server.URL())
				response, err := client.Post(url, "application/octet-stream", bytes.NewBuffer(body))
				Expect(err).ToNot(HaveOccurred())
				defer response.Body.Close()
				_, err = io.Copy(io.Discard, response.Body)
				Expect(err).ToNot(HaveOccurred())

				// Verify that details aren't written:
				messages := Parse(buffer)
				requestDetails := Find(messages, "Received body")
				responseDetails := Find(messages, "Received body")
				if expected {
					Expect(requestDetails).ToNot(BeEmpty())
					Expect(responseDetails).ToNot(BeEmpty())
				} else {
					Expect(requestDetails).To(BeEmpty())
					Expect(responseDetails).To(BeEmpty())
				}
			},
			Entry("Disabled by default", false),
			Entry("Explicitly enabled without value", true, "--log-bodies"),
			Entry("Explicitly enabled with value", true, "--log-bodies=true"),
			Entry("Explicitly disabled with value", false, "--log-bodies=false"),
		)

		It("Honors exclude function", func() {
			// Prepare the server:
			server.AppendHandlers(
				RespondWith(http.StatusOK, nil),
				RespondWith(http.StatusOK, nil),
				RespondWith(http.StatusOK, nil),
				RespondWith(http.StatusOK, nil),
			)

			// Create the client:
			wrapper, err := NewTransportWrapper().
				SetLogger(logger).
				SetExcludeFunc(func(request *http.Request) bool {
					return strings.Contains(request.URL.Path, "excluded")
				}).
				Build()
			Expect(err).ToNot(HaveOccurred())
			client := &http.Client{
				Transport: wrapper(http.DefaultTransport),
			}

			// Send the request:
			get := func(path string) {
				url := fmt.Sprintf("%s/%s", server.URL(), path)
				response, err := client.Get(url)
				Expect(err).ToNot(HaveOccurred())
				defer response.Body.Close()
				_, err = io.Copy(io.Discard, response.Body)
				Expect(err).ToNot(HaveOccurred())
			}
			get("excluded")
			get("excluded/my-path")
			get("included")
			get("included/my-path")

			// Verify that details aren't written:
			messages := Find(Parse(buffer), "Sending request")
			Expect(messages).To(HaveLen(2))
			Expect(messages[0]).To(HaveKeyWithValue(
				"url", fmt.Sprintf("%s/included", server.URL()),
			))
			Expect(messages[1]).To(HaveKeyWithValue(
				"url", fmt.Sprintf("%s/included/my-path", server.URL()),
			))

			// Verify that details aren't written:
			Expect(buffer.String()).To(BeEmpty())
		})

		It("Honors exclude pattern", func() {
			// Prepare the server:
			server.AppendHandlers(
				RespondWith(http.StatusOK, nil),
				RespondWith(http.StatusOK, nil),
				RespondWith(http.StatusOK, nil),
				RespondWith(http.StatusOK, nil),
			)

			// Create the client:
			wrapper, err := NewTransportWrapper().
				SetLogger(logger).
				SetExclude("^/excluded(/.*)?$").
				Build()
			Expect(err).ToNot(HaveOccurred())
			client := &http.Client{
				Transport: wrapper(http.DefaultTransport),
			}

			// Send the requests:
			get := func(path string) {
				url := fmt.Sprintf("%s/%s", server.URL(), path)
				response, err := client.Get(url)
				Expect(err).ToNot(HaveOccurred())
				defer response.Body.Close()
				_, err = io.Copy(io.Discard, response.Body)
				Expect(err).ToNot(HaveOccurred())
			}
			get("excluded")
			get("excluded/my-path")
			get("included")
			get("included/my-path")

			// Verify that details aren't written:
			messages := Find(Parse(buffer), "Sending request")
			Expect(messages).To(HaveLen(2))
			Expect(messages[0]).To(HaveKeyWithValue(
				"url", fmt.Sprintf("%s/included", server.URL()),
			))
			Expect(messages[1]).To(HaveKeyWithValue(
				"url", fmt.Sprintf("%s/included/my-path", server.URL()),
			))
		})

		It("Honors multiple patterns", func() {
			// Prepare the server:
			server.AppendHandlers(
				RespondWith(http.StatusOK, nil),
				RespondWith(http.StatusOK, nil),
				RespondWith(http.StatusOK, nil),
				RespondWith(http.StatusOK, nil),
			)

			// Create the client:
			wrapper, err := NewTransportWrapper().
				SetLogger(logger).
				AddExclude("^/excluded1$").
				AddExclude("^/excluded2$").
				Build()
			Expect(err).ToNot(HaveOccurred())
			client := &http.Client{
				Transport: wrapper(http.DefaultTransport),
			}

			// Send the requests:
			get := func(path string) {
				url := fmt.Sprintf("%s/%s", server.URL(), path)
				response, err := client.Get(url)
				Expect(err).ToNot(HaveOccurred())
				defer response.Body.Close()
				_, err = io.Copy(io.Discard, response.Body)
				Expect(err).ToNot(HaveOccurred())
			}
			get("excluded1")
			get("excluded2")

			// Verify that details aren't written:
			messages := Find(Parse(buffer), "Sending request")
			Expect(messages).To(BeEmpty())
		})
	})
})
