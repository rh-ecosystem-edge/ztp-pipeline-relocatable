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


.PHONY: all-images pipe-image ui-image all-hub-sno all-hub-compact all-spoke-sno all-spoke-compact build-pipe-image build-ui-image push-pipe-image push-ui-image doc build-hub-sno build-hub-compact deploy-pipe-hub build-spoke-sno build-spoke-compact deploy-pipe-spoke-sno deploy-pipe-spoke-compact boostrap
.EXPORT_ALL_VARIABLES:

all-images: pipe-image ui-image
pipe-image: build-pipe-image push-pipe-image
ui-image: build-ui-image push-ui-image

all-hub-sno: build-hub-sno boostrap deploy-pipe-hub
all-hub-compact: build-hub-compact boostrap deploy-pipe-hub
all-spoke-sno: build-spoke-sno boostrap deploy-pipe-spoke-sno
all-spoke-compact: build-spoke-compact boostrap deploy-pipe-spoke-compact


build-pipe-image:
	podman build --ignorefile $(CI_FOLDER)/.containerignore --platform linux/amd64 -t $(FULL_PIPE_IMAGE_TAG) -f $(CI_FOLDER)/Containerfile.pipeline .

build-ui-image:
	podman build --ignorefile $(CI_FOLDER)/.containerignore --platform linux/amd64 -t $(FULL_UI_IMAGE_TAG) -f $(CI_FOLDER)/Containerfile.UI .

push-pipe-image: build-pipe
	podman push $(FULL_PIPE_IMAGE_TAG)

push-ui-image: build-ui
	podman push $(FULL_UI_IMAGE_TAG)

doc:
	bash build.sh

build-hub-sno:
	cd ${PWD}/hack/deploy-hub-local && \
	./build-hub.sh  ${HOME}/openshift_pull.json $(OCP_VERSION) $(ACM_VERSION) $(OCS_VERSION) sno

build-hub-compact:
	cd ${PWD}/hack/deploy-hub-local && \
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
	cd ${PWD}/hack/deploy-hub-local && \
	./build-spoke.sh  ${HOME}/openshift_pull.json $(OCP_VERSION) $(ACM_VERSION) $(OCS_VERSION) sno

build-spoke-compact:
	cd ${PWD}/hack/deploy-hub-local && \
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
	cd ${PWD}/pipelines && \
	./bootstrap.sh $(BRANCH)

