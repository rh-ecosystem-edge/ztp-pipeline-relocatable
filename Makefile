CI_FOLDER = images
PIPE_IMAGE ?= quay.io/ztpfw/pipeline
UI_IMAGE = quay.io/ztpfw/ui
BRANCH ?= $(shell git for-each-ref --format='%(objectname) %(refname:short)' refs/heads | awk "/^$$(git rev-parse HEAD)/ {print \$$2}" | tr '[:upper:]' '[:lower:]' | tr '\/' '-')
HASH := $(shell git rev-parse HEAD)
RELEASE ?= latest
FULL_PIPE_IMAGE_TAG=$(PIPE_IMAGE):$(BRANCH)
FULL_UI_IMAGE_TAG=$(UI_IMAGE):$(BRANCH)
EDGECLUSTERS_FILE ?= ${PWD}/hack/deploy-hub-local/edgeclusters.yaml
PULL_SECRET ?= ${HOME}/openshift_pull.json
OCP_VERSION ?= 4.10.13
ACM_VERSION ?= 2.4
ODF_VERSION ?= 4.9


# COLORS
RED    := $(shell tput -Txterm setaf 1)
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
VIOLET := $(shell tput -Txterm setaf 5)
AQUA   := $(shell tput -Txterm setaf 6)
WHITE  := $(shell tput -Txterm setaf 7)
RESET  := $(shell tput -Txterm sgr0)



## Show help
.PHONY: help
help:
	@echo ''
	@printf '\tZTPFW Makefile\n'
	@echo ''
	@echo 'For development and testing only'
	@echo ''
	@echo 'Usage:'
	@echo '  ${YELLOW}make${RESET} ${GREEN}<target>${RESET}'
	@echo ''
	@echo "Build Targets:"
	@grep -hE '^[ a-zA-Z0-9_-]+:.*?##1 .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?##1"}; {printf "${GREEN}%30s ${RESET} \t%s\n", $$1, $$2}'
	@echo ""
	@echo "Manual Targets:"
	@grep -hE '^[ a-zA-Z0-9_-]+:.*?##2 .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?##2"}; {printf "${GREEN}%30s ${RESET} \t%s\n", $$1, $$2}';
	@echo ""
	@echo "Pipeline Targets:"
	@grep -hE '^[ a-zA-Z0-9_-]+:.*?##3 .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?##3"}; {printf "${GREEN}%30s ${RESET} \t%s\n", $$1, $$2}';
	@echo ""
	@echo "Create Cluster Targets:"
	@grep -hE '^[ a-zA-Z0-9_-]+:.*?##4 .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?##4"}; {printf "${GREEN}%30s ${RESET} \t%s\n", $$1, $$2}';
	@echo ""
	@echo "Run Combine Targets:"
	@grep -hE '^[ a-zA-Z0-9_-]+:.*?##5 .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?##5"}; {printf "${GREEN}%30s ${RESET} \t%s\n", $$1, $$2}';


ifeq ($(BRANCH),)
BRANCH := $(RELEASE)
endif

.PHONY: all-images pipe-image pipe-image-ci ui-image ui-image-ci all-hub-sno all-hub-compact all-edgecluster-sno all-edgecluster-compact build-pipe-image build-ui-image push-pipe-image push-ui-image doc build-hub-sno build-hub-compact wait-for-hub-sno deploy-pipe-hub-sno deploy-pipe-hub-compact build-edgecluster-sno build-edgecluster-compact build-edgecluster-sno-2nics build-edgecluster-compact-2nics deploy-pipe-edgecluster-sno deploy-pipe-edgecluster-compact bootstrap bootstrap-ci deploy-pipe-hub-ci deploy-pipe-hub-ci deploy-pipe-edgecluster-sno-ci deploy-pipe-edgecluster-compact-ci all-hub-sno-ci all-hub-compact-ci all-edgecluster-sno-ci all-edgecluster-compact-ci all-images-ci
.EXPORT_ALL_VARIABLES:

all-images: pipe-image ui-image  				##1 Build and Publish all
	
all-images-ci: pipe-image-ci ui-image-ci

pipe-image: build-pipe-image push-pipe-image 	##1 Build and Publish Pipeline image
ui-image: build-ui-image push-ui-image 		 	##1	Build and Publish UI image

pipe-image-ci: build-pipe-image-ci push-pipe-image-ci
ui-image-ci: build-ui-image-ci push-ui-image-ci1

all-hub-sno: build-hub-sno bootstrap wait-for-hub-sno deploy-pipe-hub-sno ##5 "build-hub-sno bootstrap deploy-pipe-hub-sno"
all-hub-compact: build-hub-compact bootstrap deploy-pipe-hub-compact  ##5 "build-hub-compact bootstrap deploy-pipe-hub-compact"
all-edgecluster-sno: build-edgecluster-sno bootstrap deploy-pipe-edgecluster-sno ##5 "build-edgecluster-sno bootstrap deploy-pipe-edgecluster-sno"
all-edgecluster-compact: build-edgecluster-compact bootstrap deploy-pipe-edgecluster-compact ##5 "build-edgecluster-compact bootstrap deploy-pipe-edgecluster-compact"

all-hub-sno-ci: build-hub-sno bootstrap-ci deploy-pipe-hub-ci
all-hub-compact-ci: build-hub-compact bootstrap-ci deploy-pipe-hub-ci
all-edgecluster-sno-ci: build-edgecluster-sno bootstrap-ci deploy-pipe-edgecluster-sno-ci
all-edgecluster-compact-ci: build-edgecluster-compact bootstrap-ci deploy-pipe-edgecluster-compact-ci

### Manual builds
build-pipe-image: ##2 Containers build for Pipeline
	podman build --ignorefile $(CI_FOLDER)/.containerignore --platform linux/amd64 -t $(FULL_PIPE_IMAGE_TAG) -f $(CI_FOLDER)/Containerfile.pipeline .

build-ui-image: ##2 Containers build for UI
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

doc: ##2 Build Docs
	bash build.sh

build-hub-sno: ##4 Create OpenShift HUB SNO VM
	cd ${PWD}/hack/deploy-hub-local && \
	./build-hub.sh  $(PULL_SECRET) $(OCP_VERSION) $(ACM_VERSION) $(ODF_VERSION) sno

build-hub-compact: ##4 Create OpenShift HUB Compact VM
	cd ${PWD}/hack/deploy-hub-local && \
	./build-hub.sh  $(PULL_SECRET) $(OCP_VERSION) $(ACM_VERSION) $(ODF_VERSION) compact

build-edgecluster-sno:   ##4 Create OpenShift Edge SNO VM
	cd ${PWD}/hack/deploy-hub-local && \
	./build-edgecluster.sh  $(PULL_SECRET) $(OCP_VERSION) $(ACM_VERSION) $(ODF_VERSION) sno

build-edgecluster-compact:  ##4 Create OpenShift Edge COMPACT VM
	cd ${PWD}/hack/deploy-hub-local && \
	./build-edgecluster.sh  $(PULL_SECRET) $(OCP_VERSION) $(ACM_VERSION) $(ODF_VERSION) compact

build-edgecluster-sno-2nics:
	cd ${PWD}/hack/deploy-hub-local && \
	./build-edgecluster.sh  $(PULL_SECRET) $(OCP_VERSION) $(ACM_VERSION) $(ODF_VERSION) sno false

build-edgecluster-compact-2nics:
	cd ${PWD}/hack/deploy-hub-local && \
	./build-edgecluster.sh  $(PULL_SECRET) $(OCP_VERSION) $(ACM_VERSION) $(ODF_VERSION) compact false

wait-for-mco-compact:
	${PWD}/shared-utils/wait_for_mco_compact.sh &

wait-for-hub-sno:
	${PWD}/shared-utils/wait_for_sno_mco.sh &

deploy-pipe-hub-sno: ##3 Deploy hub on SNO
	tkn pipeline start -n edgecluster-deployer \
			-p ztp-container-image="$(PIPE_IMAGE):$(BRANCH)" \
			-p edgeclusters-config="$$(cat $(EDGECLUSTERS_FILE))" \
			-p kubeconfig=${KUBECONFIG} \
			-w name=ztp,claimName=ztp-pvc \
			--timeout 5h \
			--pod-template ./pipelines/resources/common/pod-template.yaml \
			--use-param-defaults deploy-ztp-hub  && \
	tkn pr logs -L -n edgecluster-deployer -f

deploy-pipe-hub-compact:  ##3 Deploy hub on compact
	tkn pipeline start -n edgecluster-deployer \
			-p ztp-container-image="$(PIPE_IMAGE):$(BRANCH)" \
			-p edgeclusters-config="$$(cat $(EDGECLUSTERS_FILE))" \
			-p kubeconfig=${KUBECONFIG} \
			-w name=ztp,claimName=ztp-pvc \
			--timeout 5h \
			--pod-template ./pipelines/resources/common/pod-template.yaml \
			--use-param-defaults deploy-ztp-hub  && \
	tkn pr logs -L -n edgecluster-deployer -f

deploy-pipe-edgecluster-sno: ##3 Deploy SNO edge cluster
	tkn pipeline start -n edgecluster-deployer \
    			-p ztp-container-image="$(PIPE_IMAGE):$(BRANCH)" \
    			-p edgeclusters-config="$$(cat $(EDGECLUSTERS_FILE))" \
    			-p kubeconfig=${KUBECONFIG} \
    			-w name=ztp,claimName=ztp-pvc \
    			--timeout 5h \
    			--pod-template ./pipelines/resources/common/pod-template.yaml \
    			--use-param-defaults deploy-ztp-edgeclusters-sno && \
	tkn pr logs -L -n edgecluster-deployer -f

deploy-pipe-edgecluster-compact: ##3 Deploy Compact edge cluster 
	tkn pipeline start -n edgecluster-deployer \
    			-p ztp-container-image="$(PIPE_IMAGE):$(BRANCH)" \
    			-p edgeclusters-config="$$(cat $(EDGECLUSTERS_FILE))" \
    			-p kubeconfig=${KUBECONFIG} \
    			-w name=ztp,claimName=ztp-pvc \
    			--timeout 5h \
    			--pod-template ./pipelines/resources/common/pod-template.yaml \
    			--use-param-defaults deploy-ztp-edgeclusters && \
	tkn pr logs -L -n edgecluster-deployer -f

deploy-pipe-hub-ci:
	tkn pipeline start -n edgecluster-deployer \
			-p ztp-container-image="$(PIPE_IMAGE):$(RELEASE)" \
			-p edgeclusters-config="$$(cat $(EDGECLUSTERS_FILE))" \
			-p kubeconfig=${KUBECONFIG} \
			-w name=ztp,claimName=ztp-pvc \
			--timeout 5h \
			--pod-template ./pipelines/resources/common/pod-template.yaml \
			--use-param-defaults deploy-ztp-hub  && \
	tkn pr logs -L -n edgecluster-deployer -f

deploy-pipe-edgecluster-sno-ci:
	tkn pipeline start -n edgecluster-deployer \
    			-p ztp-container-image="$(PIPE_IMAGE):$(RELEASE)" \
    			-p edgeclusters-config="$$(cat $(EDGECLUSTERS_FILE))" \
    			-p kubeconfig=${KUBECONFIG} \
    			-w name=ztp,claimName=ztp-pvc \
    			--timeout 5h \
    			--pod-template ./pipelines/resources/common/pod-template.yaml \
    			--use-param-defaults deploy-ztp-edgeclusters-sno && \
	tkn pr logs -L -n edgecluster-deployer -f

deploy-pipe-edgecluster-compact-ci:
	tkn pipeline start -n edgecluster-deployer \
    			-p ztp-container-image="$(PIPE_IMAGE):$(RELEASE)" \
    			-p edgeclusters-config="$$(cat $(EDGECLUSTERS_FILE))" \
    			-p kubeconfig=${KUBECONFIG} \
    			-w name=ztp,claimName=ztp-pvc \
    			--timeout 5h \
    			--pod-template ./pipelines/resources/common/pod-template.yaml \
    			--use-param-defaults deploy-ztp-edgeclusters && \
	tkn pr logs -L -n edgecluster-deployer -f

bootstrap: ##2 Bootstrap 
	cd ${PWD}/pipelines && \
	./bootstrap.sh $(BRANCH)

bootstrap-ci:
	cd ${PWD}/pipelines && \
	./bootstrap.sh $(RELEASE)

clean: ##2 clean edge cluster <EDGE_NAME>
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





