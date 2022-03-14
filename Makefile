CI_FOLDER = images
PIPE_IMAGE = quay.io/ztpfw/pipeline
PIPE_TAG = latest
UI_IMAGE = quay.io/ztpfw/ui
UI_TAG = latest
BRANCH := $(shell git for-each-ref --format='%(objectname) %(refname:short)' refs/heads | awk "/^$$(git rev-parse HEAD)/ {print \$$2}")
HASH := $(shell git rev-parse HEAD)

.PHONY: build push

all: build push

all-from-branch: build-from-branch push-from-branch

build-from-branch:
	podman build --platform linux/amd64 -t $(PIPE_IMAGE):$(BRANCH)-$(HASH) -f $(CI_FOLDER)/Containerfile.pipeline .
    podman build --platform linux/amd64 -t $(UI_IMAGE):$(BRANCH)-$(HASH) -f $(CI_FOLDER)/Containerfile.UI .

push-from-branch:
	podman push $(PIPE_IMAGE):$(BRANCH)-$(HASH)
    podman push $(UI_IMAGE):$(BRANCH)-$(HASH)

build:
	podman build --platform linux/amd64 -t $(PIPE_IMAGE):$(PIPE_TAG) -f $(CI_FOLDER)/Containerfile.pipeline .
	podman build --platform linux/amd64 -t $(UI_IMAGE):$(UI_TAG) -f $(CI_FOLDER)/Containerfile.UI .

push: build
	podman push $(PIPE_IMAGE):$(PIPE_TAG)
	podman push $(UI_IMAGE):$(UI_TAG)