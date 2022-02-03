#!/bin/bash

mkdir -p ./certs
openssl req -subj '/C=US' -new -newkey rsa:2048 -sha256 -days 365 -nodes -x509 -keyout certs/tls.key -out certs/tls.crt

oc delete secret kubeframe-ui-certs -n kubeframe-ui

oc create secret tls kubeframe-ui-certs -n kubeframe-ui \
  --cert=./certs/tls.crt \
  --key=./certs/tls.key
