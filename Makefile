CI_FOLDER = images
PIPE_IMAGE = quay.io/ztpfw/pipeline
UI_IMAGE = quay.io/ztpfw/ui
BRANCH := $(shell git for-each-ref --format='%(objectname) %(refname:short)' refs/heads | awk "/^$$(git rev-parse HEAD)/ {print \$$2}" | tr '[:upper:]' '[:lower:]' | tr '\/' '-')
HASH := $(shell git rev-parse HEAD)
RELEASE ?= latest
FULL_PIPE_IMAGE_TAG=$(PIPE_IMAGE):$(BRANCH)
FULL_UI_IMAGE_TAG=$(UI_IMAGE):$(BRANCH)
SPOKES_FILE ?= "$$(cat ${PWD}/hack/deploy-hub-local/spokes.yaml)"
PULL_SECRET ?= ${HOME}/openshift_pull.json
OCP_VERSION ?= 4.10.9
ACM_VERSION ?= 2.4
OCS_VERSION ?= 4.9


.PHONY: all-images pipe-image pipe-image-ci ui-image ui-image-ci all-hub-sno all-hub-compact all-spoke-sno all-spoke-compact build-pipe-image build-ui-image push-pipe-image push-ui-image doc build-hub-sno build-hub-compact deploy-pipe-hub build-spoke-sno build-spoke-compact deploy-pipe-spoke-sno deploy-pipe-spoke-compact bootstrap
.EXPORT_ALL_VARIABLES:

all-images: pipe-image ui-image
pipe-image: build-pipe-image push-pipe-image
pipe-image-ci: build-pipe-image-ci push-pipe-image-ci
ui-image: build-ui-image push-ui-image
ui-image-ci: build-ui-image-ci push-ui-image-ci

all-hub-sno: build-hub-sno bootstrap deploy-pipe-hub
all-hub-compact: build-hub-compact bootstrap deploy-pipe-hub
all-spoke-sno: build-spoke-sno bootstrap deploy-pipe-spoke-sno
all-spoke-compact: build-spoke-compact bootstrap deploy-pipe-spoke-compact


build-pipe-image:
	podman build --ignorefile $(CI_FOLDER)/.containerignore --platform linux/amd64 -t $(FULL_PIPE_IMAGE_TAG) -f $(CI_FOLDER)/Containerfile.pipeline .

build-pipe-image-ci:
	podman build --ignorefile $(CI_FOLDER)/.containerignore --platform linux/amd64 -t $(RELEASE) -f $(CI_FOLDER)/Containerfile.pipeline .

build-ui-image:
	podman build --ignorefile $(CI_FOLDER)/.containerignore --platform linux/amd64 -t $(FULL_UI_IMAGE_TAG) -f $(CI_FOLDER)/Containerfile.UI .

build-ui-image-ci:
	podman build --ignorefile $(CI_FOLDER)/.containerignore --platform linux/amd64 -t $(RELEASE) -f $(CI_FOLDER)/Containerfile.UI .

push-pipe-image: build-pipe-image
	podman push $(FULL_PIPE_IMAGE_TAG)

push-pipe-image-ci: build-pipe-image-ci
	podman push $(RELEASE)

push-ui-image: build-ui-image
	podman push $(FULL_UI_IMAGE_TAG)

push-ui-image-ci: build-ui-image-ci
	podman push $(RELEASE)

doc:
	bash build.sh

build-hub-sno:
	cd ${PWD}/hack/deploy-hub-local && \
	./build-hub.sh  $(PULL_SECRET) $(OCP_VERSION) $(ACM_VERSION) $(OCS_VERSION) sno

build-hub-compact:
	cd ${PWD}/hack/deploy-hub-local && \
	./build-hub.sh  $(PULL_SECRET) $(OCP_VERSION) $(ACM_VERSION) $(OCS_VERSION) compact

deploy-pipe-hub:
	tkn pipeline start -n spoke-deployer \
			-p ztp-container-image="quay.io/ztpfw/pipeline:$(RELEASE)" \
			-p spokes-config=$(SPOKES_FILE) \
			-p kubeconfig=${KUBECONFIG} \
			-w name=ztp,claimName=ztp-pvc \
			--timeout 5h \
			--pod-template ./pipelines/resources/common/pod-template.yaml \
			--use-param-defaults deploy-ztp-hub  && \
	tkn pr logs -L -n spoke-deployer -f

build-spoke-sno:
	cd ${PWD}/hack/deploy-hub-local && \
	./build-spoke.sh  $(PULL_SECRET) $(OCP_VERSION) $(ACM_VERSION) $(OCS_VERSION) sno

build-spoke-compact:
	cd ${PWD}/hack/deploy-hub-local && \
	./build-spoke.sh  $(PULL_SECRET) $(OCP_VERSION) $(ACM_VERSION) $(OCS_VERSION) compact

deploy-pipe-spoke-sno:
	tkn pipeline start -n spoke-deployer \
    			-p ztp-container-image="quay.io/ztpfw/pipeline:$(RELEASE)" \
    			-p spokes-config=$(SPOKES_FILE) \
    			-p kubeconfig=${KUBECONFIG} \
    			-w name=ztp,claimName=ztp-pvc \
    			--timeout 5h \
    			--pod-template ./pipelines/resources/common/pod-template.yaml \
    			--use-param-defaults deploy-ztp-spokes-sno && \
	tkn pr logs -L -n spoke-deployer -f

deploy-pipe-spoke-compact:
	tkn pipeline start -n spoke-deployer \
    			-p ztp-container-image="quay.io/ztpfw/pipeline:$(RELEASE)" \
    			-p spokes-config=$(SPOKES_FILE) \
    			-p kubeconfig=${KUBECONFIG} \
    			-w name=ztp,claimName=ztp-pvc \
    			--timeout 5h \
    			--pod-template ./pipelines/resources/common/pod-template.yaml \
    			--use-param-defaults deploy-ztp-spokes && \
	tkn pr logs -L -n spoke-deployer -f

bootstrap:
	cd ${PWD}/pipelines && \
	./bootstrap.sh $(BRANCH)

