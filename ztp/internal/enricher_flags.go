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
	"github.com/spf13/pflag"
)

// AddEnricherFlags adds the enricher flags to the given flag set.
func AddEnricherFlags(set *pflag.FlagSet) {
	_ = set.String(
		enricherResolverFlagName,
		"",
		"IP address and port number of the DNS server, for example 127.0.0.1:53. "+
			"The default is to use the DNS server globally configured in the "+
			"machine and there is usually no reason to change it; it is "+
			"intended for use in tests.",
	)
	_ = set.MarkHidden(enricherResolverFlagName)
}

// Names of the flags:
const (
	enricherResolverFlagName = "resolver"
)
