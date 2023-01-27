/*
Copyright 2022 Red Hat Inc.

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
	"context"
	"os"
	"path/filepath"
	"testing"

	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/gomega"

	. "github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/ztp/internal/testing"
)

func TestInternal(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Internal")
}

// environment is the Kubernetes API testing environment that will be created before starting the
// test suite.
var environment *Environment

// kubeconfig is an array of bytes containing a `kubeconfig` file that can be used to access the
// Kubernetes API testing environment with administrator privileges.
var kubeconfig []byte

var _ = BeforeSuite(func() {
	// Create a context:
	ctx := context.Background()

	// Create the logger:
	logger, err := NewLogger().
		SetWriter(GinkgoWriter).
		SetV(2).
		Build()
	Expect(err).ToNot(HaveOccurred())

	// Create the Kubernetes API testing environment:
	environment, err = NewEnvironment().
		SetLogger(logger).
		SetName("ztp").
		Build()
	Expect(err).ToNot(HaveOccurred())

	// Start the environment:
	err = environment.Start(ctx)
	Expect(err).ToNot(HaveOccurred())

	// Get the kubeconfig:
	kubeconfig, err = environment.Kubeconfig()
	Expect(err).ToNot(HaveOccurred())

	// Write the kubeconfig to the `tests.kubeconfig` file. This is intended to simplify access
	// to the testing cluster when debugging tests.
	work, err := os.Getwd()
	Expect(err).ToNot(HaveOccurred())
	file := filepath.Join(work, "..", "tests.kubeconfig")
	err = os.WriteFile(file, kubeconfig, 0600)
	Expect(err).ToNot(HaveOccurred())
})

var _ = AfterSuite(func() {
	// Create a context:
	ctx := context.Background()

	// Stop the environment:
	if environment != nil {
		err := environment.Stop(ctx)
		Expect(err).ToNot(HaveOccurred())
	}
})
