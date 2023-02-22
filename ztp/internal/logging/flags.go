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

import "github.com/spf13/pflag"

// AddFlags adds the flags related to logging to the given flag set.
func AddFlags(set *pflag.FlagSet) {
	_ = set.Int(
		levelFlagName,
		0,
		"Log level. The default is zero, which includes information messages, level "+
			"one includes basic debug messages, and levels two and above include "+
			"detailed and verbose debug messages.",
	)
	_ = set.String(
		fileFlagName,
		"",
		"Log file. The default is to write to a 'ztp.log' file inside the user cache "+
			"directory. The value can also be 'stdout' or 'stderr' and then the "+
			"log will be written to the standard output or error streams of the "+
			"process.",
	)
}

// Names of the flags:
const (
	levelFlagName = "log-level"
	fileFlagName  = "log-file"
)
