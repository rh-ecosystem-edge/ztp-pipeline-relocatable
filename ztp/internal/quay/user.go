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

// UserInitializeRequest contains the input parameters for the request to initialize the
// administrator user.
type UserInitializeRequest struct {
	Username    string `json:"username,omitempty"`
	Password    string `json:"password,omitempty"`
	Email       string `json:"email,omitempty"`
	AccessToken bool   `json:"access_token,omitempty"`
}

// UserInitializeResponse contains the output parameters for the request to initialize the
// administrator user.
type UserInitializeResponse struct {
	AccessToken string `json:"access_token,omitempty"`
}

// UserInitialize sends the request to initialize the administrator user of the registry. It returns
// the response and also saves the returned token if no token has been set when the client was
// created.
func (c *Client) UserInitialize(ctx context.Context,
	request *UserInitializeRequest) (response *UserInitializeResponse, err error) {
	result, err := c.post(ctx, "user/initialize", request, func() any {
		return &UserInitializeResponse{}
	})
	if err != nil {
		return
	}
	if result != nil {
		response = result.(*UserInitializeResponse)
		if response.AccessToken != "" {
			c.token = response.AccessToken
		}
	}
	return
}
