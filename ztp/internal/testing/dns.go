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
	"fmt"
	"net"
	"strings"
	"sync/atomic"

	"github.com/miekg/dns"
	. "github.com/onsi/ginkgo/v2/dsl/core"
	. "github.com/onsi/gomega"
)

// DNSServer is a simple DNS server intendef for use in tests.
type DNSServer struct {
	server  *dns.Server
	address string
	zones   []*dnsZone
}

type dnsZone struct {
	name    string
	suffix  string
	records []dns.RR
}

func NewDNSServer() *DNSServer {
	// Create the server:
	s := &DNSServer{}

	// Add the default zones:
	s.addReverseZone()

	// Create the listener:
	listener, err := net.ListenPacket("udp", "127.0.0.1:0")
	Expect(err).ToNot(HaveOccurred())
	s.address = listener.LocalAddr().String()

	// Create the server with a notification function that will tell us when the server is
	// actually started:
	started := &atomic.Bool{}
	s.server = &dns.Server{
		Net:        "udp",
		PacketConn: listener,
		Handler:    dns.HandlerFunc(s.serve),
		NotifyStartedFunc: func() {
			started.Store(true)
		},
	}

	// Start the server in a separate goroutine and wait till it is started, otherwise trying to
	// stop it may fail because it isn't started yet.
	go func() {
		defer GinkgoRecover()
		err := s.server.ActivateAndServe()
		Expect(err).ToNot(HaveOccurred())
	}()
	Eventually(started.Load).Should(BeTrue())

	return s
}

// AddZone adds a zone to the server. This must be done before adding any record for that zone.
func (s *DNSServer) AddZone(name string) {
	s.addDirectZone(name)
}

// AddHost adds an A record and the corresponding PTR record to the server.
func (s *DNSServer) AddHost(name, address string) {
	// We only support IPv4:
	a := net.ParseIP(address).To4()
	Expect(a).ToNot(BeNil())

	// Add the A record:
	if !strings.HasSuffix(name, ".") {
		name += "."
	}
	directZone := s.findZone(name)
	Expect(directZone).ToNot(BeNil())
	directZone.records = append(directZone.records, &dns.A{
		Hdr: dns.RR_Header{
			Name:   name,
			Class:  dns.ClassINET,
			Rrtype: dns.TypeA,
			Ttl:    60,
		},
		A: a,
	})

	// Add the PTR record:
	reverseA := make(net.IP, len(a))
	for i, j := 0, len(a)-1; j >= 0; i, j = i+1, j-1 {
		reverseA[i] = a[j]
	}
	reverseName := fmt.Sprintf("%s.in-addr.arpa.", reverseA)
	reverseZone := s.findZone(reverseName)
	Expect(reverseZone).ToNot(BeNil())
	reverseZone.records = append(reverseZone.records, &dns.PTR{
		Hdr: dns.RR_Header{
			Name:   reverseName,
			Class:  dns.ClassINET,
			Rrtype: dns.TypePTR,
			Ttl:    60,
		},
		Ptr: name,
	})
}

// Address returns the host and port number of the server.
func (s *DNSServer) Address() string {
	return s.address
}

// Close stops the server.
func (s *DNSServer) Close() {
	err := s.server.Shutdown()
	Expect(err).ToNot(HaveOccurred())
}

func (s *DNSServer) findZone(name string) *dnsZone {
	suffix := "." + name
	for _, zone := range s.zones {
		if strings.HasSuffix(suffix, zone.suffix) {
			return zone
		}
	}
	return nil
}

func (s *DNSServer) findRecords(zone *dnsZone, rtype uint16, name string) []dns.RR {
	if zone == nil {
		return nil
	}
	var records []dns.RR
	for _, record := range zone.records {
		header := record.Header()
		if header.Name == name && header.Rrtype == rtype {
			records = append(records, record)
		}
	}
	return records
}

func (s *DNSServer) addReverseZone() {
	s.zones = append(s.zones, &dnsZone{
		name:   "in-addr.arpa.",
		suffix: ".in-addr.arpa.",
		records: []dns.RR{
			&dns.SOA{
				Hdr: dns.RR_Header{
					Name:   "in-addr.arpa.",
					Class:  dns.ClassINET,
					Rrtype: dns.TypeSOA,
					Ttl:    60,
				},
				Ns:      "ns.internal.",
				Mbox:    "info.internal.",
				Serial:  0,
				Refresh: 3600,
				Retry:   3600,
				Expire:  3600,
				Minttl:  3600,
			},
			&dns.NS{
				Hdr: dns.RR_Header{
					Name:   "in-addr.arpa.",
					Class:  dns.ClassINET,
					Rrtype: dns.TypeNS,
					Ttl:    60,
				},
				Ns: "ns.internal.",
			},
		},
	})
}

func (s *DNSServer) addDirectZone(name string) {
	if !strings.HasSuffix(name, ".") {
		name += "."
	}
	s.zones = append(s.zones, &dnsZone{
		name:   name,
		suffix: "." + name,
		records: []dns.RR{
			&dns.SOA{
				Hdr: dns.RR_Header{
					Name:   name,
					Class:  dns.ClassINET,
					Rrtype: dns.TypeSOA,
					Ttl:    60,
				},
				Ns:      "ns.internal.",
				Mbox:    "info.internal.",
				Serial:  0,
				Refresh: 3600,
				Retry:   3600,
				Expire:  3600,
				Minttl:  3600,
			},
			&dns.NS{
				Hdr: dns.RR_Header{
					Name:   name,
					Class:  dns.ClassINET,
					Rrtype: dns.TypeNS,
					Ttl:    60,
				},
				Ns: "ns.internal.",
			},
		},
	})
}

func (s *DNSServer) serve(w dns.ResponseWriter, r *dns.Msg) {
	defer GinkgoRecover()
	if len(r.Question) != 1 {
		s.sendError(w, r, nil)
		return
	}
	q := r.Question[0]
	if q.Qclass != dns.ClassINET {
		s.sendError(w, r, nil)
		return
	}
	zone := s.findZone(q.Name)
	if zone == nil {
		s.sendError(w, r, nil)
		return
	}
	records := s.findRecords(zone, q.Qtype, q.Name)
	if len(records) > 0 {
		s.sendAnswer(w, r, zone, records)
		return
	}
	s.sendError(w, r, zone)
}

func (s *DNSServer) sendError(w dns.ResponseWriter, r *dns.Msg, zone *dnsZone) {
	m := &dns.Msg{}
	m.Authoritative = true
	if zone != nil {
		m.Ns = s.findRecords(zone, dns.TypeNS, zone.name)
	}
	m.SetRcode(r, dns.RcodeNameError)
	err := w.WriteMsg(m)
	Expect(err).ToNot(HaveOccurred())
}

func (s *DNSServer) sendAnswer(w dns.ResponseWriter, r *dns.Msg, zone *dnsZone, records []dns.RR) {
	m := &dns.Msg{}
	m.SetReply(r)
	m.Authoritative = true
	m.Answer = records
	err := w.WriteMsg(m)
	Expect(err).ToNot(HaveOccurred())
}
