#!/bin/bash

podman build . -f Dockerfile -t kubeframe:test
podman run -dt -p 3001:3001/tcp kubeframe:test

