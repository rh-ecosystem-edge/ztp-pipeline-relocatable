CI_FOLDER = images
PIPE_IMAGE ?= quay.io/ztpfw/pipeline
UI_IMAGE ?= quay.io/ztpfw/ui
BRANCH ?= $(shell git branch --show-current | tr '[:upper:]' '[:lower:]' | tr '\/' '-')
HASH := $(shell git rev-parse HEAD)
RELEASE ?= latest
CLUSTER_NAME ?= edgecluster
EDGECLUSTERS_FILE ?= ${PWD}/hack/deploy-hub-local/${CLUSTER_NAME}.yaml
PULL_SECRET ?= ${HOME}/openshift_pull.json
OCP_VERSION ?= 4.11.28
ACM_VERSION ?= 2.6
ODF_VERSION ?= 4.11

ifneq ($(TAG),)
BRANCH := $(TAG)
endif

FULL_PIPE_IMAGE_TAG=$(PIPE_IMAGE):$(BRANCH)
FULL_UI_IMAGE_TAG=$(UI_IMAGE):$(BRANCH)

.PHONY: all-images pipe-image pipe-image-ci ui-image ui-image-ci all-hub-sno all-hub-compact all-edgecluster-sno all-edgecluster-compact build-pipe-image build-ui-image push-pipe-image push-ui-image doc build-hub-sno build-hub-compact wait-for-hub-sno deploy-pipe-hub-sno deploy-pipe-hub-compact build-edgecluster-sno build-edgecluster-compact build-edgecluster-sno-2nics build-edgecluster-compact-2nics deploy-pipe-edgecluster-sno deploy-pipe-edgecluster-compact bootstrap bootstrap-ci deploy-pipe-hub-ci deploy-pipe-hub-ci deploy-pipe-edgecluster-sno-ci deploy-pipe-edgecluster-compact-ci all-hub-sno-ci all-hub-compact-ci all-edgecluster-sno-ci all-edgecluster-compact-ci all-images-ci run-pipeline-task run-hub-lvmo-task build-hub-sno-custom build-edgecluster-sno-2nics-custom build-edgecluster-compact-2nics-custom
.EXPORT_ALL_VARIABLES:

all-images: pipe-image ui-image
all-images-ci: pipe-image-ci ui-image-ci

pipe-image: build-pipe-image push-pipe-image
ui-image: build-ui-image push-ui-image

pipe-image-ci: build-pipe-image-ci push-pipe-image-ci
ui-image-ci: build-ui-image-ci push-ui-image-ci

all-hub-sno: build-hub-sno bootstrap wait-for-hub-sno deploy-pipe-hub-sno
all-hub-compact: build-hub-compact bootstrap deploy-pipe-hub-compact
all-edgecluster-sno: build-edgecluster-sno bootstrap deploy-pipe-edgecluster-sno
all-edgecluster-compact: build-edgecluster-compact bootstrap deploy-pipe-edgecluster-compact

all-hub-sno-ci: build-hub-sno bootstrap-ci deploy-pipe-hub-ci
all-hub-compact-ci: build-hub-compact bootstrap-ci deploy-pipe-hub-ci
all-edgecluster-sno-ci: build-edgecluster-sno bootstrap-ci deploy-pipe-edgecluster-sno-ci
all-edgecluster-compact-ci: build-edgecluster-compact bootstrap-ci deploy-pipe-edgecluster-compact-ci

### Manual builds
.PHONY: build
build:
	cd ztp && go build -o oc-ztp

build-pipe-image:
	podman build --ignorefile $(CI_FOLDER)/.containerignore --platform linux/amd64 -t $(FULL_PIPE_IMAGE_TAG) -f $(CI_FOLDER)/Containerfile.pipeline .

build-ui-image:
	podman build --ignorefile $(CI_FOLDER)/.containerignore --platform linux/amd64 -t $(FULL_UI_IMAGE_TAG) -f $(CI_FOLDER)/Containerfile.UI .

push-pipe-image: build-pipe-image
	podman push $(FULL_PIPE_IMAGE_TAG)

push-ui-image: build-ui-image
	podman push $(FULL_UI_IMAGE_TAG)

### CI
build-pipe-image-ci:
	podman build --ignorefile $(CI_FOLDER)/.containerignore --platform linux/amd64 -t $(PIPE_IMAGE):$(RELEASE) -f $(CI_FOLDER)/Containerfile.pipeline .

build-ui-image-ci:
	podman build --ignorefile $(CI_FOLDER)/.containerignore --platform linux/amd64 -t $(UI_IMAGE):$(RELEASE) -f $(CI_FOLDER)/Containerfile.UI .

push-pipe-image-ci: build-pipe-image-ci
	podman push $(PIPE_IMAGE):$(RELEASE)

push-ui-image-ci: build-ui-image-ci
	podman push $(UI_IMAGE):$(RELEASE)

doc:
	bash build.sh

build-hub-sno:
	cd ${PWD}/hack/deploy-hub-local && \
	./build-hub.sh  $(PULL_SECRET) $(OCP_VERSION) $(ACM_VERSION) $(ODF_VERSION) sno

build-hub-sno-custom:
	cd ${PWD}/hack/deploy-hub-local && \
	./build-hub.sh  $(PULL_SECRET) $(OCP_VERSION) $(ACM_VERSION) $(ODF_VERSION) sno $(REGISTRY)

build-hub-compact:
	cd ${PWD}/hack/deploy-hub-local && \
	./build-hub.sh  $(PULL_SECRET) $(OCP_VERSION) $(ACM_VERSION) $(ODF_VERSION) compact

build-edgecluster-sno:
	cd ${PWD}/hack/deploy-hub-local && \
	./build-edgecluster.sh  $(PULL_SECRET) $(OCP_VERSION) $(ACM_VERSION) $(ODF_VERSION) sno

build-edgecluster-compact:
	cd ${PWD}/hack/deploy-hub-local && \
	./build-edgecluster.sh  $(PULL_SECRET) $(OCP_VERSION) $(ACM_VERSION) $(ODF_VERSION) compact

build-edgecluster-sno-2nics:
	cd ${PWD}/hack/deploy-hub-local && \
	./build-edgecluster.sh  $(PULL_SECRET) $(OCP_VERSION) $(ACM_VERSION) $(ODF_VERSION) sno false

build-edgecluster-compact-2nics:
	cd ${PWD}/hack/deploy-hub-local && \
	./build-edgecluster.sh  $(PULL_SECRET) $(OCP_VERSION) $(ACM_VERSION) $(ODF_VERSION) compact false

build-edgecluster-sno-2nics-custom:
	cd ${PWD}/hack/deploy-hub-local && \
	./build-edgecluster.sh  $(PULL_SECRET) $(OCP_VERSION) $(ACM_VERSION) $(ODF_VERSION) sno false $(REGISTRY)

build-edgecluster-compact-2nics-custom:
	cd ${PWD}/hack/deploy-hub-local && \
	./build-edgecluster.sh  $(PULL_SECRET) $(OCP_VERSION) $(ACM_VERSION) $(ODF_VERSION) compact false $(REGISTRY)

wait-for-hub-sno:
	${PWD}/shared-utils/wait_for_sno_mco.sh &


run-pipeline-task:
	tkn task start -n edgecluster-deployer \
    			-p ztp-container-image="$(PIPE_IMAGE):$(BRANCH)" \
    			-p edgeclusters-config="$$(cat $(EDGECLUSTERS_FILE))" \
    			-p kubeconfig=${KUBECONFIG} \
			    -w name=ztp,emptyDir="" \
    			--timeout 5h \
    			--pod-template ./pipelines/resources/common/pod-template.yaml \
    			--use-param-defaults $(TASK) \
    			--showlog

run-hub-lvmo-task:
	tkn task start -n edgecluster-deployer \
    			-p ztp-container-image="$(PIPE_IMAGE):$(BRANCH)" \
    			-p edgeclusters-config="$$(cat $(EDGECLUSTERS_FILE))" \
    			-p kubeconfig=${KUBECONFIG} \
			    -w name=ztp,emptyDir="" \
    			--timeout 5h \
    			--pod-template ./pipelines/resources/common/pod-template.yaml \
    			--use-param-defaults hub-deploy-lvmo \
    			--showlog


deploy-pipe-hub-sno: run-hub-lvmo-task
	tkn pipeline start -n edgecluster-deployer \
			-p ztp-container-image="$(PIPE_IMAGE):$(BRANCH)" \
			-p edgeclusters-config="$$(cat $(EDGECLUSTERS_FILE))" \
			-p kubeconfig=${KUBECONFIG} \
			-w name=ztp,claimName=ztp-pvc \
			--timeout 5h \
			--pod-template ./pipelines/resources/common/pod-template.yaml \
			--use-param-defaults deploy-ztp-hub \
			--showlog

deploy-pipe-hub-compact: run-hub-lvmo-task
	tkn pipeline start -n edgecluster-deployer \
			-p ztp-container-image="$(PIPE_IMAGE):$(BRANCH)" \
			-p edgeclusters-config="$$(cat $(EDGECLUSTERS_FILE))" \
			-p kubeconfig=${KUBECONFIG} \
			-w name=ztp,claimName=ztp-pvc \
			--timeout 5h \
			--pod-template ./pipelines/resources/common/pod-template.yaml \
			--use-param-defaults deploy-ztp-hub \
			--showlog

deploy-pipe-edgecluster-sno:
	tkn pipeline start -n edgecluster-deployer \
    			-p ztp-container-image="$(PIPE_IMAGE):$(BRANCH)" \
    			-p edgeclusters-config="$$(cat $(EDGECLUSTERS_FILE))" \
    			-p kubeconfig=${KUBECONFIG} \
    			-w name=ztp,claimName=ztp-pvc \
    			--timeout 5h \
    			--pod-template ./pipelines/resources/common/pod-template.yaml \
    			--use-param-defaults deploy-ztp-edgeclusters-sno \
    			--showlog

deploy-pipe-edgecluster-compact:
	tkn pipeline start -n edgecluster-deployer \
    			-p ztp-container-image="$(PIPE_IMAGE):$(BRANCH)" \
    			-p edgeclusters-config="$$(cat $(EDGECLUSTERS_FILE))" \
    			-p kubeconfig=${KUBECONFIG} \
    			-w name=ztp,claimName=ztp-pvc \
    			--timeout 5h \
    			--pod-template ./pipelines/resources/common/pod-template.yaml \
    			--use-param-defaults deploy-ztp-edgeclusters \
    			--showlog

deploy-pipe-hub-ci:
	tkn pipeline start -n edgecluster-deployer \
			-p ztp-container-image="$(PIPE_IMAGE):$(RELEASE)" \
			-p edgeclusters-config="$$(cat $(EDGECLUSTERS_FILE))" \
			-p kubeconfig=${KUBECONFIG} \
			-w name=ztp,claimName=ztp-pvc \
			--timeout 5h \
			--pod-template ./pipelines/resources/common/pod-template.yaml \
			--use-param-defaults deploy-ztp-hub \
			--showlog

deploy-pipe-edgecluster-sno-ci:
	tkn pipeline start -n edgecluster-deployer \
    			-p ztp-container-image="$(PIPE_IMAGE):$(RELEASE)" \
    			-p edgeclusters-config="$$(cat $(EDGECLUSTERS_FILE))" \
    			-p kubeconfig=${KUBECONFIG} \
    			-w name=ztp,claimName=ztp-pvc \
    			--timeout 5h \
    			--pod-template ./pipelines/resources/common/pod-template.yaml \
    			--use-param-defaults deploy-ztp-edgeclusters-sno \
    			--showlog

deploy-pipe-edgecluster-compact-ci:
	tkn pipeline start -n edgecluster-deployer \
    			-p ztp-container-image="$(PIPE_IMAGE):$(RELEASE)" \
    			-p edgeclusters-config="$$(cat $(EDGECLUSTERS_FILE))" \
    			-p kubeconfig=${KUBECONFIG} \
    			-w name=ztp,claimName=ztp-pvc \
    			--timeout 5h \
    			--pod-template ./pipelines/resources/common/pod-template.yaml \
    			--use-param-defaults deploy-ztp-edgeclusters \
    			--showlog

bootstrap:
	cd ${PWD}/pipelines && \
	./bootstrap.sh $(BRANCH)

bootstrap-ci:
	cd ${PWD}/pipelines && \
	./bootstrap.sh $(RELEASE)

clean:
	oc delete managedcluster $(EDGE_NAME); \
	oc delete ns $(EDGE_NAME); \
	oc rollout restart -n openshift-machine-api deployment/metal3; \
	kcli delete vm -y $(EDGE_NAME)-m0 $(EDGE_NAME)-m1 $(EDGE_NAME)-m2 $(EDGE_NAME)-w0

clean-ci:
	# From: https://github.com/stolostron/deploy/blob/master/hack/cleanup-managed-cluster.sh
	list=$$(tkn pr ls -n edgecluster-deployer |grep -i running | cut -d' ' -f1); \
	for i in ${list}; do tkn pr cancel $${i} -n edgecluster-deployer; done; \
	list=$$($ oc get bmh -n $(EDGE_NAME) --no-headers|awk '{print $$1}'); \
	for i in $${list}; do oc patch -n $(EDGE_NAME) bmh $${i} --type json -p '[ { "op": "remove", "path": "/metadata/finalizers" } ]'; done; \
	list=$$(oc get secret -n $(EDGE_NAME) --no-headers |grep bmc|awk '{print $$1}'); \
	for i in $${list}; do oc patch -n $(EDGE_NAME) secret $${i} --type json -p '[ { "op": "remove", "path": "/metadata/finalizers" } ]'; done; \
	oc delete --ignore-not-found=true managedcluster $(EDGE_NAME); \
	oc delete --ignore-not-found=true ns $(EDGE_NAME); \
	oc rollout restart -n openshift-machine-api deployment/metal3; \
	kcli delete vm -y $(EDGE_NAME)-m0 $(EDGE_NAME)-m1 $(EDGE_NAME)-m2 $(EDGE_NAME)-w0
