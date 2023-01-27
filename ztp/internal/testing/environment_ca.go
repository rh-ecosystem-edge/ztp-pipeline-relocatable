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
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"math/big"
	"net"
	"sync"
	"time"

	"github.com/go-logr/logr"
)

// environmenetCA is a certificate authority used internally by the testing environment.
type environmentCA struct {
	lock   *sync.Mutex
	logger logr.Logger
	serial *big.Int
	crt    *x509.Certificate
	key    *rsa.PrivateKey
	keyPEM []byte
	crtPEM []byte
}

func (b *EnvironmentBuilder) createCA() (result *environmentCA, err error) {
	// Initialize the serial number:
	serial := big.NewInt(0)

	// Create the CA key pair:
	key, err := rsa.GenerateKey(rand.Reader, 4096)
	if err != nil {
		return
	}

	// Create the CA certificate:
	now := time.Now()
	crt := &x509.Certificate{
		SerialNumber: serial,
		Subject: pkix.Name{
			CommonName:   "CA",
			Organization: []string{"Kubernetes"},
		},
		NotBefore: now,
		NotAfter:  now.AddDate(1, 0, 0),
		IsCA:      true,
		ExtKeyUsage: []x509.ExtKeyUsage{
			x509.ExtKeyUsageClientAuth,
			x509.ExtKeyUsageServerAuth,
		},
		KeyUsage:              x509.KeyUsageDigitalSignature | x509.KeyUsageCertSign,
		BasicConstraintsValid: true,
	}

	// Sign the certificate:
	crtBytes, err := x509.CreateCertificate(rand.Reader, crt, crt, &key.PublicKey, key)
	if err != nil {
		return
	}

	// Marshal the key:
	keyBytes := x509.MarshalPKCS1PrivateKey(key)

	// Encode the private key and the certificate:
	keyPEM := pem.EncodeToMemory(&pem.Block{
		Type:  "RSA PRIVATE KEY",
		Bytes: keyBytes,
	})
	crtPEM := pem.EncodeToMemory(&pem.Block{
		Type:  "CERTIFICATE",
		Bytes: crtBytes,
	})
	if err != nil {
		return
	}
	b.logger.V(3).Info(
		"Created CA",
		"subject", crt.Subject.String(),
		"key", string(keyPEM),
		"crt", string(keyPEM),
	)

	// Return the result:
	result = &environmentCA{
		logger: b.logger,
		lock:   &sync.Mutex{},
		serial: serial,
		key:    key,
		crt:    crt,
		keyPEM: keyPEM,
		crtPEM: crtPEM,
	}

	return
}

func (c *environmentCA) createCertificate(subject pkix.Name) (keyPEM, crtPEM []byte, err error) {
	// We need exclussive access in order to update the serial number and maybe other fields:
	c.lock.Lock()
	defer c.lock.Unlock()

	// Increase the serial number:
	serial := c.serial.Add(c.serial, big.NewInt(1))

	// Create the key pair:
	key, err := rsa.GenerateKey(rand.Reader, 4096)
	if err != nil {
		return
	}

	// Create the certificate:
	now := time.Now()
	crt := &x509.Certificate{
		SerialNumber: serial,
		Subject:      subject,
		IPAddresses: []net.IP{
			net.IPv4(127, 0, 0, 1),
			net.IPv6loopback,
		},
		NotBefore:    now,
		NotAfter:     now.AddDate(1, 0, 0),
		SubjectKeyId: serial.Bytes(),
		ExtKeyUsage: []x509.ExtKeyUsage{
			x509.ExtKeyUsageClientAuth,
			x509.ExtKeyUsageServerAuth,
		},
		KeyUsage: x509.KeyUsageDigitalSignature,
	}

	// Sign the certificate:
	crtBytes, err := x509.CreateCertificate(rand.Reader, crt, c.crt, &key.PublicKey, c.key)
	if err != nil {
		return
	}

	// Marshal the key:
	keyBytes := x509.MarshalPKCS1PrivateKey(key)

	// Encode the private key and the certificate:
	keyPEM = pem.EncodeToMemory(&pem.Block{
		Type:  "RSA PRIVATE KEY",
		Bytes: keyBytes,
	})
	crtPEM = pem.EncodeToMemory(&pem.Block{
		Type:  "CERTIFICATE",
		Bytes: crtBytes,
	})
	c.logger.V(3).Info(
		"Created admin certificate",
		"subject", crt.Subject.String(),
		"key", string(keyPEM),
		"crt", string(crtPEM),
	)

	// Update the serial number:
	c.serial = serial

	return
}
