CI_FOLDER = images
PIPE_IMAGE = quay.io/ztpfw/pipeline
UI_IMAGE = quay.io/ztpfw/ui
BRANCH := $(shell git for-each-ref --format='%(objectname) %(refname:short)' refs/heads | awk "/^$$(git rev-parse HEAD)/ {print \$$2}")
HASH := $(shell git rev-parse HEAD)
RELEASE ?= $(BRANCH)
FULL_PIPE_IMAGE_TAG=$(PIPE_IMAGE):$(RELEASE)
FULL_UI_IMAGE_TAG=$(UI_IMAGE):$(RELEASE)
UI_TAG = latest
PULL_SECRET = ${PWD}/pull_secret.json
NUM_SPOKES = 1
KUBECONFIG ?= ${PWD}/kubeconfig
GIT_BRANCH ?= main

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

create-hub:
	cd ${PWD}/hack/deploy-hub-local && \
		./build-hub.sh ${PULL_SECRET} ${NUM_SPOKES}

bootstrap-tekton:
	echo "Getting Kubeconfig: "
	kcli scp root@test-ci-installer:/root/ocp/auth/kubeconfig .
	KUBECONFIG=./kubeconfig ./pipelines/bootstrap.sh

create-spokes:
	cd ${PWD}/hack/deploy-hub-local && \
		./build-spoke.sh ${PULL_SECRET} ${NUM_SPOKES}

deploy-pipe-hub:
	tkn pipeline start -n spoke-deployer \
					   -p git-revision=${GIT_BRANCH} \
					   -p spokes-config="$(cat ./hack/deploy-hub-local/spokes.yaml)" \
					   -p kubeconfig=${KUBECONFIG} \
					   -w name=ztp,claimName=ztp-pvc \
					   --timeout 5h \
					   --use-param-defaults deploy-ztp-hub | tail -n1
	tkn pipelinerun list -n spoke-deployer --reverse | tail -n1 | cut -d' ' -f1 | xargs tkn pipelinerun logs -f -n spoke-deployer
	
