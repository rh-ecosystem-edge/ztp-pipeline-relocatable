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
BRANCH := $(shell git for-each-ref --format='%(objectname) %(refname:short)' refs/heads | awk "/^$$(git rev-parse HEAD)/ {print \$$2}" | tr '[:upper:]' '[:lower:]' | tr '\/' '-')
HASH := $(shell git rev-parse HEAD)
RELEASE ?= latest
FULL_PIPE_IMAGE_TAG=$(PIPE_IMAGE):$(BRANCH)
FULL_UI_IMAGE_TAG=$(UI_IMAGE):$(BRANCH)
SPOKES_FILE ?= ${PWD}/hack/deploy-hub-local/spokes.yaml
PULL_SECRET ?= ${HOME}/openshift_pull.json
OCP_VERSION ?= 4.10.13
ACM_VERSION ?= 2.4
ODF_VERSION ?= 4.9

.PHONY: all-images pipe-image pipe-image-ci ui-image ui-image-ci cloud-image cloud-image-ci all-hub-sno all-hub-compact all-spoke-sno all-spoke-compact build-pipe-image build-ui-image build-cloud-image push-pipe-image push-ui-image push-cloud-image doc build-hub-sno build-hub-compact wait-for-hub-sno deploy-pipe-hub-sno deploy-pipe-hub-compact build-spoke-sno build-spoke-compact deploy-pipe-spoke-sno deploy-pipe-spoke-compact bootstrap bootstrap-ci deploy-pipe-hub-ci deploy-pipe-hub-ci deploy-pipe-spoke-sno-ci deploy-pipe-spoke-compact-ci all-hub-sno-ci all-hub-compact-ci all-spoke-sno-ci all-spoke-compact-ci all-images-ci
.EXPORT_ALL_VARIABLES:

all-images: pipe-image ui-image cloud-image
all-images-ci: pipe-image-ci ui-image-ci cloud-image-ci

pipe-image: build-pipe-image push-pipe-image
ui-image: build-ui-image push-ui-image
cloud-image: build-cloud-image push-cloud-image

pipe-image-ci: build-pipe-image-ci push-pipe-image-ci
ui-image-ci: build-ui-image-ci push-ui-image-ci
cloud-image-ci: build-cloud-image-ci push-cloud-image-ci

all-hub-sno: build-hub-sno bootstrap wait-for-hub-sno deploy-pipe-hub-sno
all-hub-compact: build-hub-compact bootstrap deploy-pipe-hub-compact
all-spoke-sno: build-spoke-sno bootstrap deploy-pipe-spoke-sno
all-spoke-compact: build-spoke-compact bootstrap deploy-pipe-spoke-compact

all-hub-sno-ci: build-hub-sno bootstrap-ci deploy-pipe-hub-ci
all-hub-compact-ci: build-hub-compact bootstrap-ci deploy-pipe-hub-ci
all-spoke-sno-ci: build-spoke-sno bootstrap-ci deploy-pipe-spoke-sno-ci
all-spoke-compact-ci: build-spoke-compact bootstrap-ci deploy-pipe-spoke-compact-ci

### Manual builds
build-pipe-image:
	podman build --ignorefile $(CI_FOLDER)/.containerignore --platform linux/amd64 -t $(FULL_PIPE_IMAGE_TAG) -f $(CI_FOLDER)/Containerfile.pipeline .

build-ui-image:
	podman build --ignorefile $(CI_FOLDER)/.containerignore --platform linux/amd64 -t $(FULL_UI_IMAGE_TAG) -f $(CI_FOLDER)/Containerfile.UI .

build-cloud-image:
	podman build --ignorefile $(CI_FOLDER)/.containerignore --platform linux/amd64 -t $(FULL_CLOUD_IMAGE_TAG) -f $(CI_FOLDER)/Containerfile.cloud .

push-pipe-image: build-pipe-image
	podman push $(FULL_PIPE_IMAGE_TAG)

push-cloud-image: build-cloud-image
	podman push $(FULL_CLOUD_IMAGE_TAG)

push-ui-image: build-ui-image
	podman push $(FULL_UI_IMAGE_TAG)



### CI
build-pipe-image-ci:
	podman build --ignorefile $(CI_FOLDER)/.containerignore --platform linux/amd64 -t $(PIPE_IMAGE):$(RELEASE) -f $(CI_FOLDER)/Containerfile.pipeline .

build-ui-image-ci:
	podman build --ignorefile $(CI_FOLDER)/.containerignore --platform linux/amd64 -t $(UI_IMAGE):$(RELEASE) -f $(CI_FOLDER)/Containerfile.UI .

build-cloud-image-ci:
	podman build --ignorefile $(CI_FOLDER)/.containerignore --platform linux/amd64 -t $(PIPE_IMAGE):$(RELEASE) -f $(CI_FOLDER)/Containerfile.cloud .

push-pipe-image-ci: build-pipe-image-ci
	podman push $(PIPE_IMAGE):$(RELEASE)

push-ui-image-ci: build-ui-image-ci
	podman push $(UI_IMAGE):$(RELEASE)

push-cloud-image-ci: build-cloud-image-ci
	podman push $(PIPE_IMAGE):$(RELEASE)

doc:
	bash build.sh

build-hub-sno:
	cd ${PWD}/hack/deploy-hub-local && \
	./build-hub.sh  $(PULL_SECRET) $(OCP_VERSION) $(ACM_VERSION) $(ODF_VERSION) sno

build-hub-compact:
	cd ${PWD}/hack/deploy-hub-local && \
	./build-hub.sh  $(PULL_SECRET) $(OCP_VERSION) $(ACM_VERSION) $(ODF_VERSION) compact

build-spoke-sno:
	cd ${PWD}/hack/deploy-hub-local && \
	./build-spoke.sh  $(PULL_SECRET) $(OCP_VERSION) $(ACM_VERSION) $(ODF_VERSION) sno

build-spoke-compact:
	cd ${PWD}/hack/deploy-hub-local && \
	./build-spoke.sh  $(PULL_SECRET) $(OCP_VERSION) $(ACM_VERSION) $(ODF_VERSION) compact

wait-for-hub-sno:
	${PWD}/shared-utils/wait_for_sno_mco.sh &

deploy-pipe-hub-sno:
	tkn pipeline start -n spoke-deployer \
			-p ztp-container-image="quay.io/ztpfw/pipeline:$(BRANCH)" \
			-p spokes-config="$$(cat $(SPOKES_FILE))" \
			-p kubeconfig=${KUBECONFIG} \
			-w name=ztp,claimName=ztp-pvc \
			--timeout 5h \
			--pod-template ./pipelines/resources/common/pod-template.yaml \
			--use-param-defaults deploy-ztp-hub  && \
	tkn pr logs -L -n spoke-deployer -f

deploy-pipe-hub-compact:
	tkn pipeline start -n spoke-deployer \
			-p ztp-container-image="quay.io/ztpfw/pipeline:$(BRANCH)" \
			-p spokes-config="$$(cat $(SPOKES_FILE))" \
			-p kubeconfig=${KUBECONFIG} \
			-w name=ztp,claimName=ztp-pvc \
			--timeout 5h \
			--pod-template ./pipelines/resources/common/pod-template.yaml \
			--use-param-defaults deploy-ztp-hub  && \
	tkn pr logs -L -n spoke-deployer -f

deploy-pipe-spoke-sno:
	tkn pipeline start -n spoke-deployer \
    			-p ztp-container-image="quay.io/ztpfw/pipeline:$(BRANCH)" \
    			-p spokes-config="$$(cat $(SPOKES_FILE))" \
    			-p kubeconfig=${KUBECONFIG} \
    			-w name=ztp,claimName=ztp-pvc \
    			--timeout 5h \
    			--pod-template ./pipelines/resources/common/pod-template.yaml \
    			--use-param-defaults deploy-ztp-spokes-sno && \
	tkn pr logs -L -n spoke-deployer -f

deploy-pipe-spoke-compact:
	tkn pipeline start -n spoke-deployer \
    			-p ztp-container-image="quay.io/ztpfw/pipeline:$(BRANCH)" \
    			-p spokes-config="$$(cat $(SPOKES_FILE))" \
    			-p kubeconfig=${KUBECONFIG} \
    			-w name=ztp,claimName=ztp-pvc \
    			--timeout 5h \
    			--pod-template ./pipelines/resources/common/pod-template.yaml \
    			--use-param-defaults deploy-ztp-spokes && \
	tkn pr logs -L -n spoke-deployer -f

deploy-pipe-hub-ci:
	tkn pipeline start -n spoke-deployer \
			-p ztp-container-image="quay.io/ztpfw/pipeline:$(RELEASE)" \
			-p spokes-config="$$(cat $(SPOKES_FILE))" \
			-p kubeconfig=${KUBECONFIG} \
			-w name=ztp,claimName=ztp-pvc \
			--timeout 5h \
			--pod-template ./pipelines/resources/common/pod-template.yaml \
			--use-param-defaults deploy-ztp-hub  && \
	tkn pr logs -L -n spoke-deployer -f

deploy-pipe-spoke-sno-ci:
	tkn pipeline start -n spoke-deployer \
    			-p ztp-container-image="quay.io/ztpfw/pipeline:$(RELEASE)" \
    			-p spokes-config="$$(cat $(SPOKES_FILE))" \
    			-p kubeconfig=${KUBECONFIG} \
    			-w name=ztp,claimName=ztp-pvc \
    			--timeout 5h \
    			--pod-template ./pipelines/resources/common/pod-template.yaml \
    			--use-param-defaults deploy-ztp-spokes-sno && \
	tkn pr logs -L -n spoke-deployer -f

deploy-pipe-spoke-compact-ci:
	tkn pipeline start -n spoke-deployer \
    			-p ztp-container-image="quay.io/ztpfw/pipeline:$(RELEASE)" \
    			-p spokes-config="$$(cat $(SPOKES_FILE))" \
    			-p kubeconfig=${KUBECONFIG} \
    			-w name=ztp,claimName=ztp-pvc \
    			--timeout 5h \
    			--pod-template ./pipelines/resources/common/pod-template.yaml \
    			--use-param-defaults deploy-ztp-spokes && \
	tkn pr logs -L -n spoke-deployer -f

bootstrap:
	cd ${PWD}/pipelines && \
	./bootstrap.sh $(BRANCH)

bootstrap-ci:
	cd ${PWD}/pipelines && \
	./bootstrap.sh $(RELEASE)

clean:
	oc delete managedcluster $(SPOKE_NAME); \
	oc delete ns $(SPOKE_NAME); \
	oc rollout restart -n openshift-machine-api deployment/metal3; \
	kcli delete vm $(SPOKE_NAME)-m0 $(SPOKE_NAME)-m1 $(SPOKE_NAME)-m2 $(SPOKE_NAME)-w0
