## 
# Makefile to build deploy base image for OpenNMS production container images
##
.PHONY: help test build install uninstall clean clean-all

.DEFAULT_GOAL := build

VERSION                 := localbuild
SHELL                   := /bin/bash -o nounset -o pipefail -o errexit
BUILD_DATE              := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
BASE_IMAGE              := ubuntu:focal-20201106
DOCKER_CLI_EXPERIMENTAL := enabled
DOCKERX_INSTANCE	      := env-deploy-base-oci
DOCKER_REGISTRY         := docker.io
DOCKER_ORG              := opennms
DOCKER_PROJECT          := deploy-base
DOCKER_TAG              := $(DOCKER_REGISTRY)/$(DOCKER_ORG)/$(DOCKER_PROJECT):$(VERSION)
DOCKER_ARCH             := linux/amd64
DOCKER_FLAGS            := --output=type=docker,dest=artifacts/deploy-base.oci
SOURCE                  := $(shell git remote get-url origin)
REVISION                := $(shell git describe --always)
BUILD_NUMBER            := "unset"
BUILD_URL               := "unset"
BUILD_BRANCH            := $(shell git describe --always)
JAVA_MAJOR_VERSION      := 11
JAVA_PKG_VERSION        := 11.0.9.1+1-0ubuntu1~20.04
JAVA_PKG                := openjdk-$(JAVA_MAJOR_VERSION)-jre-headless=$(JAVA_PKG_VERSION)
JICMP_VERSION           := "jicmp-2.0.5-1"
JICMP6_VERSION          := "jicmp6-2.0.4-1"

help:
	@echo ""
	@echo "Makefile to build multi-architecture deploy base image and push to a registry."
	@echo ""
	@echo "Requirements to build images:"
	@echo "  * Docker 18+"
	@echo "  * Buildx CLI tools from https://github.com/docker/buildx/releases in search path as docker-buildx"
	@echo ""
	@echo "Targets:"
	@echo "  help:      Show this help"
	@echo "  build:     Create an OCI image file in artifacts/deploy-base.oci"
	@echo "  test:      Test requirements to build the deploy-base OCI"
	@echo "  install:   Load the OCI file in your Docker instance"
	@echo "  uninstall: Remove the container image from your Docker instance"
	@echo "  clean:     Remove the Dockerx build instance keep the files in the directory artifacts/"
	@echo "  clean-all: Remove the Dockerx build instance and delete *everything* in the directory artifacts/"
	@echo ""
	@echo "Arguments to modify the build:"
	@echo "  VERSION:            Version number for this release of the deploy-base artefact, default: $(VERSION)"
	@echo "  BASE_IMAGE:         The base image we install our Java app as a tarball, default: $(BASE_IMAGE)"
	@echo "  DOCKERX_INSTANCE:   Name of the docker buildx instance, default: $(DOCKERX_INSTANCE)"
	@echo "  DOCKER_REGISTRY:    Registry to push the image to, default is set to $(DOCKER_REGISTRY)"
	@echo "  DOCKER_ORG:         Organisation where the image should pushed in the registry, default is set to $(DOCKER_ORG)"
	@echo "  DOCKER_PROJECT:     Name of the project in the registry, the default is set to $(DOCKER_PROJECT)"
	@echo "  DOCKER_TAG:         Docker tag is generated from registry, org, project, version and build number, set to $(DOCKER_TAG)"
	@echo "  DOCKER_ARCH:        Architecture for OCI image, default: $(DOCKER_ARCH)"
	@echo "  DOCKER_FLAGS:       Additional docker buildx flags, by default write a single architecture to a file, default: $(DOCKER_FLAGS)"
	@echo "  BUILD_NUMBER:       In case we run in CI/CD this is the build number which produced the artifact, default: $(BUILD_NUMBER)"
	@echo "  BUILD_URL:          In case we run in CI/CD this is the URL which for the build, default: $(BUILD_URL)"
	@echo "  BUILD_BRANCH:       In case we run in CI/CD this is the branch of the build, default: $(BUILD_BRANCH)"
	@echo "  JAVA_MAJOR_VERSION: Major version number from Java package, default: $(JAVA_MAJOR_VERSION)"
	@echo "  JAVA_PKG_VERSION:   Java package version, default: $(JAVA_PKG_VERSION)"
	@echo "  JAVA_PKG:           Java package to install, default: $(JAVA_PKG)"
	@echo ""
	@echo "Example:"
	@echo "  make build DOCKER_REGISTRY=myregistry.com DOCKER_ORG=myorg DOCKER_FLAGS=--push"
	@echo ""

test:
	@echo "Test Docker and Buildx installation ..."
	@command -v docker;
	@command -v docker-buildx;

build: test
  # If we don't have a builder instance create it, otherwise use the existing one
	@echo "Initialize builder instance ..."
	@if ! docker-buildx inspect $(DOCKERX_INSTANCE); then docker-buildx create --name $(DOCKERX_INSTANCE); fi;
	@docker-buildx use $(DOCKERX_INSTANCE);
	@echo "Build container image for architecture: $(DOCKER_ARCH) ..."
	docker-buildx build --platform=$(DOCKER_ARCH) \
    --build-arg BASE_IMAGE=$(BASE_IMAGE) \
    --build-arg VERSION=$(VERSION) \
    --build-arg BUILD_DATE=$(BUILD_DATE) \
    --build-arg SOURCE=$(SOURCE) \
    --build-arg REVISION=$(REVISION) \
    --build-arg BUILD_NUMBER=$(BUILD_NUMBER) \
    --build-arg BUILD_URL=$(BUILD_URL) \
    --build-arg BUILD_BRANCH=$(BUILD_BRANCH) \
    --build-arg JAVA_MAJOR_VERSION=$(JAVA_MAJOR_VERSION) \
    --build-arg JAVA_PKG_VERSION=$(JAVA_PKG_VERSION) \
    --build-arg JICMP_VERSION=$(JICMP_VERSION) \
    --build-arg JICMP6_VERSION=$(JICMP6_VERSION) \
    --tag=$(DOCKER_TAG) \
    $(DOCKER_FLAGS) \
    . ;

install: artifacts/deploy-base.oci
	@echo "Load image ..."
	@docker image load -i artifacts/deploy-base.oci;

uninstall:
	@echo "Remove image ..."
	@docker rmi $(DOCKER_TAG)

clean:
	@echo "Destroy builder environment: $(DOCKERX_INSTANCE) ..."
	@docker-buildx rm $(DOCKERX_INSTANCE);

clean-all:
	@echo "Destroy builder environment: $(DOCKERX_INSTANCE) ..."	
	@docker-buildx rm $(DOCKERX_INSTANCE);
	@echo "Delete artifacts ..."
	@rm -rf artifacts/*.*
