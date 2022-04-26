CI_FOLDER = images
PIPE_IMAGE = quay.io/ztpfw/pipeline
UI_IMAGE = quay.io/ztpfw/ui
BRANCH := $(shell git for-each-ref --format='%(objectname) %(refname:short)' refs/heads | awk "/^$$(git rev-parse HEAD)/ {print \$$2}")
HASH := $(shell git rev-parse HEAD)
RELEASE ?= $(BRANCH)
FULL_PIPE_IMAGE_TAG=$(PIPE_IMAGE):$(RELEASE)
FULL_UI_IMAGE_TAG=$(UI_IMAGE):$(RELEASE)
OCP_VERSION ?= 4.10.9
ACM_VERSION ?= 2.4
OCS_VERSION ?= 4.9
TYPE ?= sno



.PHONY: build-image-pipe build-image-ui push-image-pipe push-image-ui doc build-hub deploy-pipe-hub build-spoke deploye-pipe-spoke boostrap
.EXPORT_ALL_VARIABLES:

image-all: image-pipe image-ui

image-pipe: build-image-pipe push-image-pipe

image-ui: build-image-ui push-image-ui

build-image-pipe:
	podman build --ignorefile $(CI_FOLDER)/.containerignore --platform linux/amd64 -t $(FULL_PIPE_IMAGE_TAG) -f $(CI_FOLDER)/Containerfile.pipeline .

build-image-ui:
	podman build --ignorefile $(CI_FOLDER)/.containerignore --platform linux/amd64 -t $(FULL_UI_IMAGE_TAG) -f $(CI_FOLDER)/Containerfile.UI .

push-image-pipe: build-pipe
	podman push $(FULL_PIPE_IMAGE_TAG)

push-image-ui: build-ui
	podman push $(FULL_UI_IMAGE_TAG)

doc:
	bash build.sh

build-hub-sno:
	./build-hub.sh  ${HOME}/openshift_pull.json $(OCP_VERSION) $(ACM_VERSION) $(OCS_VERSION) sno

build-hub-compact:
	./build-hub.sh  ${HOME}/openshift_pull.json $(OCP_VERSION) $(ACM_VERSION) $(OCS_VERSION) compact

deploy-pipe-hub:
	tkn pipeline start -n spoke-deployer \
			-p ztp-container-image="quay.io/ztpfw/pipeline:$(BRANCH)" \
			-p spokes-config="$(cat $(SPOKES_FILE))" \
			-p kubeconfig=${KUBECONFIG} \
			-w name=ztp,claimName=ztp-pvc \
			--timeout 5h \
			--pod-template ./pipelines/resources/common/pod-template.yaml \
			--use-param-defaults deploy-ztp-hub

build-spoke-sno:
	./build-spoke.sh  ${HOME}/openshift_pull.json $(OCP_VERSION) $(ACM_VERSION) $(OCS_VERSION) sno

build-spoke-compact:
	./build-spoke.sh  ${HOME}/openshift_pull.json $(OCP_VERSION) $(ACM_VERSION) $(OCS_VERSION) compact

deploy-pipe-spoke-sno:
	tkn pipeline start -n spoke-deployer \
    			-p ztp-container-image="quay.io/ztpfw/pipeline:$(BRANCH)" \
    			-p spokes-config="$(cat $(SPOKES_FILE))" \
    			-p kubeconfig=${KUBECONFIG} \
    			-w name=ztp,claimName=ztp-pvc \
    			--timeout 5h \
    			--pod-template ./pipelines/resources/common/pod-template.yaml \
    			--use-param-defaults deploy-ztp-spokes-sno

deploy-pipe-spoke-compact:
	tkn pipeline start -n spoke-deployer \
    			-p ztp-container-image="quay.io/ztpfw/pipeline:$(BRANCH)" \
    			-p spokes-config="$(cat $(SPOKES_FILE))" \
    			-p kubeconfig=${KUBECONFIG} \
    			-w name=ztp,claimName=ztp-pvc \
    			--timeout 5h \
    			--pod-template ./pipelines/resources/common/pod-template.yaml \
    			--use-param-defaults deploy-ztp-spokes

boostrap:
	./bootstrap.sh $(BRANCH)

