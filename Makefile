CI_FOLDER = images
PIPE_IMAGE = quay.io/ztpfw/pipeline
PIPE_TAG = latest
UI_IMAGE = quay.io/ztpfw/ui
UI_TAG = latest

.PHONY: build push

all: build push

build:
	podman build --platform linux/amd64 -t $(PIPE_IMAGE):$(PIPE_TAG) -f $(CI_FOLDER)/Containerfile.pipeline .
	podman build --platform linux/amd64 -t $(UI_IMAGE):$(UI_TAG) -f $(CI_FOLDER)/Containerfile.UI .

push: build
	podman push $(PIPE_IMAGE):$(PIPE_TAG)
	podman push $(UI_IMAGE):$(UI_TAG)
