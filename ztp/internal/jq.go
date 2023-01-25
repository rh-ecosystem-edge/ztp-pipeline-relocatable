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
	"encoding/json"
	"errors"
	"fmt"
	"reflect"

	"github.com/go-logr/logr"
	"github.com/itchyny/gojq"
)

// JQBuilder contains the data needed to build an object that knows how to run JQ queries. Don't
// create instances of this directly, use the NewJQ function instead.
type JQBuilder struct {
	logger logr.Logger
}

// JQ knows how to run JQ queries. Don't create instances of this directly, use the NewJQ function
// instead.
type JQ struct {
	logger logr.Logger
}

// NewJQ creates a builder that can then be used to create a JQ object.
func NewJQ() *JQBuilder {
	return &JQBuilder{}
}

// SetLogger sets the logger that the JQ object will use to write the log. This is mandatory.
func (b *JQBuilder) SetLogger(value logr.Logger) *JQBuilder {
	b.logger = value
	return b
}

// Build uses the information stored in the builder to create a new JQ object.
func (b *JQBuilder) Build() (result *JQ, err error) {
	// Check parameters:
	if b.logger.GetSink() == nil {
		err = errors.New("logger is mandatory")
		return
	}

	// Create and populate the object:
	result = &JQ{
		logger: b.logger,
	}
	return
}

// Query the given query on the given input data and stores the result into the given output
// variable.  An error will be returned if the query can't be parsed or if the data doesn't fit into
// the output variable.
func (j *JQ) Query(query string, input any, output any) error {
	// Check that the output is a pointer:
	outputValue := reflect.ValueOf(output)
	if outputValue.Kind() != reflect.Pointer {
		return fmt.Errorf("output must be a pointer, but it is of type %T", output)
	}

	// Parse the query:
	parsed, err := gojq.Parse(query)
	if err != nil {
		return fmt.Errorf("failed to parse query '%s': %v", query, err)
	}

	// Serialize the input and then deserialize it again. This will ensure that we have a type
	// that the JQ library supports.
	inputBytes, err := json.Marshal(input)
	if err != nil {
		return fmt.Errorf("failed to marshal input: %v", err)
	}
	var inputObj any
	err = json.Unmarshal(inputBytes, &inputObj)
	if err != nil {
		return fmt.Errorf("failed to unmarshal input: %v", err)
	}

	// Run the query collecting the output. Note the one of the outputs can be an error, and
	// in that case we just return it.
	var outputList []any
	outputIter := parsed.Run(inputObj)
	for {
		outputObj, ok := outputIter.Next()
		if !ok {
			break
		}
		err, ok = outputObj.(error)
		if ok {
			return err
		}
		outputList = append(outputList, outputObj)
	}

	// Marshal the output list and try to unmarshal it into the output variable. This is needed
	// to convert whatever types are returned by JQ into what the caller expects. If that fails
	// fails and there is only one result it may be that the caller passed a variable that can
	// hold only that result instead of an slice, so we try again with single result.
	outputBytes, err := json.Marshal(outputList)
	if err != nil {
		return err
	}
	err = json.Unmarshal(outputBytes, output)
	if err != nil && len(outputList) == 1 {
		outputBytes, err = json.Marshal(outputList[0])
		if err != nil {
			return err
		}
		err = json.Unmarshal(outputBytes, output)
	}
	return err
}
