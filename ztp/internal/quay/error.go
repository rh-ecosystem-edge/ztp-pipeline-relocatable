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

import "encoding/json"

// Error represents errors returned by the API.
type Error struct {
	Status       int    `json:"status,omitempty"`
	Type         string `json:"type,omitempty"`
	Detail       string `json:"detail,omitempty"`
	Title        string `json:"title,omitempty"`
	ErrorMessage string `json:"error_message,omitempty"`
	ErrorType    string `json:"error_type,omitempty"`
}

func (e *Error) UnmarshalJSON(data []byte) error {
	// Unmarshal the data into a variable of an alias of the type so that the UnmarshalJSON
	// method will not be called in a loop:
	type Alias Error
	var alias Alias
	err := json.Unmarshal(data, &alias)
	if err != nil {
		return err
	}
	*e = Error(alias)

	// The errors returned by the API server should conform to the error data type, but some
	// times they contain only fields like `error` or `message`, so we need to copy those:
	if e.ErrorMessage == "" {
		var extra map[string]any
		err = json.Unmarshal(data, &extra)
		if err != nil {
			return err
		}
		field, ok := extra["error"]
		if ok {
			text, ok := field.(string)
			if ok {
				e.ErrorMessage = text
			}
		}
		field, ok = extra["message"]
		if ok {
			text, ok := field.(string)
			if ok {
				e.ErrorMessage = text
			}
		}
	}
	return nil
}

// Error returns a string representing the error.
func (e *Error) Error() string {
	return e.ErrorMessage
}
