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

package models

import (
	"fmt"
	"net"
	"strconv"
	"strings"
)

// IP represents an IP addess together with the prefix length that indicates the network part.
type IP struct {
	Address net.IP
	Prefix  int
}

// String generates a string representing the given IP address and prefix. For example, for IP address
// 192.168.122.123 with mask 255.255.255.0 the result will be 192.168.122.123/24.
func (i *IP) String() string {
	return fmt.Sprintf("%s/%d", i.Address.String(), i.Prefix)
}

// ParseIP parses the given text as an IP address and mask. The expected input is a string like
// 192.168.122.123/24.
func ParseIP(s string) (ip *IP, err error) {
	slash := strings.LastIndex(s, "/")
	if slash == -1 {
		err = fmt.Errorf(
			"failed to parse IP address '%s' because it doesn't contain the slash "+
				"that separates the address from the prefix",
			s,
		)
		return
	}
	prefix, err := strconv.Atoi(s[slash+1:])
	if err != nil {
		err = fmt.Errorf(
			"failed to parse IP address '%s' because prefix '%s' isn't a valid "+
				"integer",
			s, s[slash+1:],
		)
		return
	}
	address := net.ParseIP(s[0:slash])
	ip = &IP{
		Address: address,
		Prefix:  prefix,
	}
	return
}
