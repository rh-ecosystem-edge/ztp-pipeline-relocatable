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

package delete

import (
	"github.com/spf13/cobra"

	deleteclustercmd "github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/cmd/delete/cluster"
	deletemetallbcmd "github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/cmd/delete/metallb"
	deleteuicmd "github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/cmd/delete/ui"
)

// Cobra creates and returns the `delete` command.
func Cobra() *cobra.Command {
	result := &cobra.Command{
		Use:   "delete",
		Short: "Deletes objects",
		Args:  cobra.NoArgs,
	}
	result.AddCommand(deleteclustercmd.Cobra())
	result.AddCommand(deletemetallbcmd.Cobra())
	result.AddCommand(deleteuicmd.Cobra())
	return result
}
