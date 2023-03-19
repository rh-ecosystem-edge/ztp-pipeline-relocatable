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

import "context"

// OrganizationCreateRequest contains the input parameters for the request to create an
// oraganization.
type OrganizationCreateRequest struct {
	Name  string `json:"name,omitempty"`
	Email string `json:"email,omitempty"`
}

// OrganizationCreate sends a request o create an organization and waits for the response.
func (c *Client) OrganizationCreate(ctx context.Context, request *OrganizationCreateRequest) error {
	_, err := c.post(ctx, "organization/", request, nil)
	return err
}
