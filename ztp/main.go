/*
Copyright 2022 Red Hat Inc.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in
compliance with the License.  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is
distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied. See the License for the specific language governing permissions and limitations under the
License.
*/

package main

import (
	"context"
	"fmt"
	"os"

	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/cmd"
	"github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/exit"
)

func main() {
	// Create a context:
	ctx := context.Background()

	// Create the tool:
	tool, err := internal.NewTool().
		AddArgs(os.Args...).
		SetIn(os.Stdin).
		SetOut(os.Stdout).
		SetErr(os.Stderr).
		AddCommand(cmd.Create).
		AddCommand(cmd.Delete).
		AddCommand(cmd.Dev).
		AddCommand(cmd.Version).
		Build()
	if err != nil {
		fmt.Fprintf(os.Stderr, "%s\n", err.Error())
		os.Exit(1)
	}

	// Run the tool:
	err = tool.Run(ctx)
	if err != nil {
		exitErr, ok := err.(exit.Error)
		if ok {
			os.Exit(exitErr.Code())
		} else {
			fmt.Fprintf(os.Stderr, "%s\n", err.Error())
			os.Exit(1)
		}
	}
}
