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

package quay

import (
	"bytes"
	"context"
	"io"
	"math"
	"net/http"

	"github.com/go-logr/logr"
	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/gomega"
	. "github.com/onsi/gomega/ghttp"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/logging"
)

var _ = Describe("Client", func() {
	var (
		ctx    context.Context
		server *Server
		buffer *bytes.Buffer
		logger logr.Logger
		client *Client
	)

	BeforeEach(func() {
		var err error

		// Create the context:
		ctx = context.Background()

		// Create the server:
		server = NewServer()

		// Create a logger that writes to the Ginkgo writer and also a buffer in
		// memory, so that we can analyze the result:
		buffer = &bytes.Buffer{}
		logger, err = logging.NewLogger().
			SetWriter(io.MultiWriter(buffer, GinkgoWriter)).
			SetLevel(math.MaxInt).
			Build()
		Expect(err).ToNot(HaveOccurred())

		// Create the client:
		client, err = NewClient().
			SetLogger(logger).
			SetURL(server.URL()).
			Build()
		Expect(err).ToNot(HaveOccurred())
	})

	AfterEach(func() {
		// Stop the server:
		server.Close()
	})

	It("Initializes user", func() {
		// Prepare the server:
		server.AppendHandlers(
			CombineHandlers(
				VerifyContentType("application/json"),
				VerifyRequest(http.MethodPost, "/api/v1/user/initialize"),
				VerifyJSON(`{
					"username": "my-user",
					"password": "my-password",
					"email": "my-email",
					"access_token": true
				}`),
				RespondWith(
					http.StatusOK,
					`{
						"access_token": "my-token"
					}`,
					http.Header{
						"Content-Type": []string{"application/json"},
					},
				),
			),
		)

		// Send the request:
		response, err := client.UserInitialize(ctx, &UserInitializeRequest{
			Username:    "my-user",
			Password:    "my-password",
			Email:       "my-email",
			AccessToken: true,
		})
		Expect(err).ToNot(HaveOccurred())
		Expect(response).ToNot(BeNil())
		Expect(response.AccessToken).To(Equal("my-token"))
		Expect(client.Token()).To(Equal("my-token"))
	})

	It("Fails if user initialization has already been done", func() {
		// Prepare the server:
		server.AppendHandlers(
			CombineHandlers(
				RespondWith(
					http.StatusBadRequest,
					`{
						"message": "Cannot initialize user in a non-empty database"
					}`,
					http.Header{
						"Content-Type": []string{"application/json"},
					},
				),
			),
		)

		// Send the request:
		response, err := client.UserInitialize(ctx, &UserInitializeRequest{
			Username:    "my-user",
			Password:    "my-password",
			Email:       "my-email",
			AccessToken: true,
		})
		Expect(err).To(HaveOccurred())
		Expect(response).To(BeNil())
		var responseErr *Error
		Expect(err).To(BeAssignableToTypeOf(responseErr))
		responseErr = err.(*Error)
		Expect(responseErr.Status).To(Equal(http.StatusBadRequest))
		Expect(responseErr.ErrorMessage).To(Equal("Cannot initialize user in a non-empty database"))
	})

	It("Creates organization", func() {
		// Prepare the server:
		server.AppendHandlers(
			CombineHandlers(
				VerifyContentType("application/json"),
				VerifyRequest(http.MethodPost, "/api/v1/organization/"),
				VerifyJSON(`{
					"name": "my-organization",
					"email": "my-email"
				}`),
				RespondWith(
					http.StatusCreated,
					`Created`,
					http.Header{
						"Content-Type": []string{"text/plain"},
					},
				),
			),
		)

		// Send the request:
		err := client.OrganizationCreate(ctx, &OrganizationCreateRequest{
			Name:  "my-organization",
			Email: "my-email",
		})
		Expect(err).ToNot(HaveOccurred())
	})

	It("Fails to create organization if not authenticated", func() {
		// Prepare the server:
		server.AppendHandlers(
			CombineHandlers(
				RespondWith(
					http.StatusForbidden,
					`{
						"error": "CSRF token was invalid or missing."
					}`,
					http.Header{
						"Content-Type": []string{"text/html"},
					},
				),
			),
		)

		// Send the request:
		err := client.OrganizationCreate(ctx, &OrganizationCreateRequest{
			Name:  "my-organization",
			Email: "my-email",
		})
		Expect(err).To(HaveOccurred())
		var responseErr *Error
		Expect(err).To(BeAssignableToTypeOf(responseErr))
		responseErr = err.(*Error)
		Expect(responseErr.Status).To(Equal(http.StatusForbidden))
		Expect(responseErr.ErrorMessage).To(Equal("CSRF token was invalid or missing."))
	})
})
