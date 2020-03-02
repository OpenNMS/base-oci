VERSION            := 1.0.0
SHELL              := /bin/bash -o pipefail
BUILD_DATE          = $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
DOCKERX_INSTANCE	= multiarch-env
DOCKER_REGISTRY    := docker.io
DOCKER_ORG         := opennms
DOCKER_PROJECT      = deploy-base
DOCKER_TAG          = $(DOCKER_REGISTRY)/$(DOCKER_ORG)/$(DOCKER_PROJECT):$(VERSION)
DOCKER_ARCH         = linux/amd64,linux/arm64,linux/arm/v7
VCS_URL            := $(shell git remote get-url origin)
VCS_REF            := $(shell git describe --always)

help:
	@echo ""
	@echo "Makefile to build Docker container images, tag them and push them to a registry. The following targets can be used:"
	@echo ""
	@echo "  help:  Show this help and is the default goal"
	@echo "  all:   Run tasks to build the oci, save it as OCI file to disk and push it to a registry."
	@echo "  build: Create an OCI image file in artifact/image.oci"
	@echo ""
	@echo "Arguments to modify the build:"
	@echo ""
	@echo "  VERSION:            Version number for this release of the deploy-base artefact, default: $(VERSION)"
	@echo "  DOCKER_ARCH:        Architecture for OCI image, default: $(DOCKER_ARCH)"
	@echo "  DOCKER_REGISTRY:    Registry to push the image to, default is set to $(DOCKER_REGISTRY)"
	@echo "  DOCKER_ORG:         Organisation where the image should pushed in the registry, default is set to $(DOCKER_ORG)."
	@echo "  DOCKER_PROJECT:     Name of the project in the registry, the default is set to $(DOCKER_PROJECT)."
	@echo "  DOCKER_TAG:         Docker tag is generated from registry, org, project, version and build number, set to $(DOCKER_TAG)."

	@echo ""
	@echo "Example:"
	@echo ""
	@echo "  make build DOCKER_REGISTRY=myregistry.com DOCKER_ORG=myorg"
	@echo ""

.DEFAULT_GOAL := help

.PHONY: all build tag help

all: build

build:
	if [[ -n "${CIRCLE_BUILD_NUM}" ]]; then \
		DOCKER_TAG=$(DOCKER_TAG)-b$(CIRCLE_BUILD_NUM); \
	fi;
	docker buildx create --name $(DOCKERX_INSTANCE); \
	docker buildx use $(DOCKERX_INSTANCE); \
	docker buildx build --platform=$(DOCKER_ARCH) \
	    --build-arg VERSION=$(VERSION) \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg VCS_URL=$(VCS_URL) \
		--build-arg VCS_REF=$(VCS_REF) \
		--build-arg BUILD_NUMBER=$(CIRCLE_BUILD_NUM) \
		--build-arg BUILD_URL=$(CIRCLE_BUILD_URL) \
		--build-arg BUILD_BRANCH=$(CIRCLE_BRANCH) \
		. \
		--output=type=oci,dest=artifacts/image.oci;

clean:
	docker buildx rm $(DOCKERX_INSTANCE)
	rm artifacts/*.oci