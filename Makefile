IMAGE=quay.io/jparrill/ztp-pipeline
TAG=latest

all: build push

build:
	podman build -t ${IMAGE}:${TAG} .

push: build
	podman push ${IMAGE}:${TAG}
