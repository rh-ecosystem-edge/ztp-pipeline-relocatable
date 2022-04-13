CI_FOLDER = images
###
## prod image name 
## quay.io/ztpfw/pipeline
###
PIPE_IMAGE = quay.io/takinosh/ztpfw-pipeline
###
## prod image name 
## quay.io/ztpfw/ui
###
UI_IMAGE = quay.io/takinosh/ztpfw-ui
###
## prod image name 
## quay.io/ztpfw/cloud-openshift-ztp
CLOUD_IMAGE = quay.io/takinosh/cloud-openshift-ztp
BRANCH := $(shell git for-each-ref --format='%(objectname) %(refname:short)' refs/heads | awk "/^$$(git rev-parse HEAD)/ {print \$$2}")
HASH := $(shell git rev-parse HEAD)
RELEASE ?= $(BRANCH)
FULL_PIPE_IMAGE_TAG=$(PIPE_IMAGE):$(RELEASE)
FULL_UI_IMAGE_TAG=$(UI_IMAGE):$(RELEASE)
FULL_CLOUD_IMAGE_TAG=$(CLOUD_IMAGE):$(RELEASE)
.PHONY: build-pipe build-ui push-pipe push-ui doc
.EXPORT_ALL_VARIABLES:
all: pipe ui
pipe: build-pipe push-pipe
ui: build-ui push-ui
cloud: build-cloud

build-pipe:
	podman build --ignorefile $(CI_FOLDER)/.containerignore --platform linux/amd64 -t $(FULL_PIPE_IMAGE_TAG) -f $(CI_FOLDER)/Containerfile.pipeline .

build-ui:
	podman build --ignorefile $(CI_FOLDER)/.containerignore --platform linux/amd64 -t $(FULL_UI_IMAGE_TAG) -f $(CI_FOLDER)/Containerfile.UI .

build-cloud:
	podman build --ignorefile $(CI_FOLDER)/.containerignore --platform linux/amd64 -t $(FULL_CLOUD_IMAGE_TAG) -f $(CI_FOLDER)/Containerfile.cloud .

push-pipe: build-pipe
	podman push $(FULL_PIPE_IMAGE_TAG)

push-ui: build-ui
	podman push $(FULL_UI_IMAGE_TAG)

doc:
	bash build.sh
