#!/bin/bash

set -ex

mkdir -p ./certs
#if [ x${TLS_CERT_FILE} = x ]; then
export TLS_CERT_FILE=./certs/tls.crt
export TLS_KEY_FILE=./certs/tls.key

echo Autogenerating TLS certificates, set TLS_CERT_FILE and TLS_KEY_FILE environment variables if you want otherwise
openssl req -subj '/C=US' -new -newkey rsa:2048 -sha256 -days 365 -nodes -x509 -keyout certs/tls.key -out certs/tls.crt
#fi

#oc delete secret ztpfw-ui-certs -n ztpfw-ui || true
#oc create secret tls ztpfw-ui-certs -n ztpfw-ui \
#    --cert=${TLS_CERT_FILE} \
#    --key=${TLS_KEY_FILE}

