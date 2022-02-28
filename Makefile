PIPE_IMAGE = quay.io/ztpfw/pipeline
PIPE_TAG = latest
CI_FOLDER = images

.PHONY: build push

all: build push

build:
	podman build -t $(PIPE_IMAGE):$(PIPE_TAG) -f $(CI_FOLDER)/Containerfile.pipeline . 

push: build
	podman push $(PIPE_IMAGE):$(PIPE_TAG)