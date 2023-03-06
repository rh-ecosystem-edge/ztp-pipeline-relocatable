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
	"net/http"
)

// RequestTransformer returns a transport wrapper that creates transports that transform the request
// using the given function.
func RequestTransformer(
	fn func(*http.Request) *http.Request) func(http.RoundTripper) http.RoundTripper {
	return func(rt http.RoundTripper) http.RoundTripper {
		return &requestTransformer{
			fn: fn,
			rt: rt,
		}
	}
}

type requestTransformer struct {
	fn func(*http.Request) *http.Request
	rt http.RoundTripper
}

func (t *requestTransformer) RoundTrip(request *http.Request) (*http.Response, error) {
	return t.rt.RoundTrip(t.fn(request))
}

// ResponseTransformer returns a transport wrapper that creates transports that transform the
// response using the given function.
func ResponseTransformer(
	fn func(*http.Response, error) (*http.Response, error)) func(http.RoundTripper) http.RoundTripper {
	return func(rt http.RoundTripper) http.RoundTripper {
		return &responseTransformer{
			fn: fn,
			rt: rt,
		}
	}
}

type responseTransformer struct {
	fn func(*http.Response, error) (*http.Response, error)
	rt http.RoundTripper
}

func (t *responseTransformer) RoundTrip(request *http.Request) (*http.Response, error) {
	return t.fn(t.rt.RoundTrip(request))
}
