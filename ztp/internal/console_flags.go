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

// AddConsoleFlags adds the console flags to the given flag set.
func AddConsoleFlags(set *pflag.FlagSet) {
	_ = set.Bool(
		consoleColorFlag,
		true,
		"Enables or disables use of color in the console. By default color is used when "+
			"the console is a terminal and disabled otherwise.",
	)
}

// Names of the flags:
const (
	consoleColorFlag = "color"
)
