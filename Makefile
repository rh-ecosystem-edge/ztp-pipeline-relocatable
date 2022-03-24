CI_FOLDER = images
PIPE_IMAGE = quay.io/ztpfw/pipeline
PIPE_TAG = latest
UI_IMAGE = quay.io/ztpfw/ui
UI_TAG = latest

.PHONY: build build-ui build-pipe push push-ui push-pipe doc

all: build push
build: build-pipe build-ui
push: push-pipe push-ui

build-ui:
	podman build --platform linux/amd64 -t $(UI_IMAGE):$(UI_TAG) -f $(CI_FOLDER)/Containerfile.UI .

build-pipe:
	podman build --platform linux/amd64 -t $(PIPE_IMAGE):$(PIPE_TAG) -f $(CI_FOLDER)/Containerfile.pipeline .

push-ui: build-ui
	podman push $(UI_IMAGE):$(UI_TAG)

push-pipe: build-pipe
	podman push $(PIPE_IMAGE):$(PIPE_TAG)

doc:
	bash build.sh
