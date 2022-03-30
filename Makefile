CI_FOLDER = images
PIPE_IMAGE = quay.io/ztpfw/pipeline
UI_IMAGE = quay.io/ztpfw/ui
BRANCH := $(shell git for-each-ref --format='%(objectname) %(refname:short)' refs/heads | awk "/^$$(git rev-parse HEAD)/ {print \$$2}")
HASH := $(shell git rev-parse HEAD)
RELEASE ?= $(BRANCH)
FULL_PIPE_IMAGE_TAG=$(PIPE_IMAGE):$(RELEASE)
FULL_UI_IMAGE_TAG=$(UI_IMAGE):$(RELEASE)

.PHONY: build-pipe build-ui push-pipe push-ui doc
.EXPORT_ALL_VARIABLES:
all: pipe ui
pipe: build-pipe push-pipe
ui: build-ui push-ui

build-pipe:
	podman build --platform linux/amd64 -t $(FULL_PIPE_IMAGE_TAG) -f $(CI_FOLDER)/Containerfile.pipeline .

build-ui:
	podman build --platform linux/amd64 -t $(FULL_UI_IMAGE_TAG) -f $(CI_FOLDER)/Containerfile.UI .

push-pipe: build-pipe
	podman push $(FULL_PIPE_IMAGE_TAG)

push-ui: build-ui
	podman push $(FULL_UI_IMAGE_TAG)

doc:
	bash build.sh
