# Copyright 2019 The Caicloud Authors.
#
# The old school Makefile, following are required targets. The Makefile is written
# to allow building multiple binaries. You are free to add more targets or change
# existing implementations, as long as the semantics are preserved.
#
#   make              - default to 'build' target
#   make lint         - code analysis
#   make test         - run unit test (or plus integration test)
#   make build        - alias to build-local target
#   make build-local  - build local binary targets
#   make build-linux  - build linux binary targets
#   make container    - build containers
#   $ docker login registry -u username -p xxxxx
#   make push         - push containers
#   make clean        - clean up targets
#
# Not included but recommended targets:
#   make e2e-test
#
# The makefile is also responsible to populate project version information.
#

#
# Tweak the variables based on your project.
#

# This repo's root import path (under GOPATH).
ROOT := github.com/caicloud/multus-cni

# Target binaries. You can build multiple binaries for a single project.
TARGETS := multus

# Container image prefix and suffix added to targets.
# The final built images are:
#   $[REGISTRY]/$[IMAGE_PREFIX]$[TARGET]$[IMAGE_SUFFIX]:$[VERSION]
# $[REGISTRY] is an item from $[REGISTRIES], $[TARGET] is an item from $[TARGETS].
IMAGE_PREFIX ?= $(strip )
IMAGE_SUFFIX ?= $(strip -cni)

# Container registry for base images.
BASE_REGISTRY ?= cargo.caicloud.xyz/library

# Go build GOARCH, you can choose to build amd64 or arm64
ARCH ?= amd64

# Change Dockerfile name and registry project name for arm64
ifeq ($(ARCH),arm64)
DOCKERFILE := Dockerfile.arm64
REGISTRY ?= cargo.dev.caicloud.xyz/arm64v8
else
DOCKERFILE := Dockerfile
REGISTRY ?= cargo.dev.caicloud.xyz/release
endif

#
# These variables should not need tweaking.
#

# It's necessary to set this because some environments don't link sh -> bash.
export SHELL := /bin/bash

# It's necessary to set the errexit flags for the bash shell.
export SHELLOPTS := errexit

# Project main package location (can be multiple ones).
CMD_DIR := .

# Project output directory.
OUTPUT_DIR := ./bin

# Build direcotory.
BUILD_DIR := ./build

# Current version of the project.
VERSION ?= $(shell git describe --tags --always --dirty)
GITCOMMIT ?= $(shell git rev-parse HEAD)
BUILDDATE ?= $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

# Available cpus for compiling, please refer to https://github.com/caicloud/engineering/issues/8186#issuecomment-518656946 for more information.
CPUS ?= $(shell /bin/bash hack/read_cpus_available.sh)

# Track code version with Docker Label.
DOCKER_LABELS ?= git-describe="$(shell date -u +v%Y%m%d)-$(shell git describe --tags --always --dirty)"

# Golang standard bin directory.
GOPATH ?= $(shell go env GOPATH)
BIN_DIR := $(GOPATH)/bin
GOLANGCI_LINT := $(BIN_DIR)/golangci-lint

#
# Define all targets. At least the following commands are required:
#

# All targets.
.PHONY: lint test build container push

build: build-local

# more info about `GOGC` env: https://github.com/golangci/golangci-lint#memory-usage-of-golangci-lint
lint: $(GOLANGCI_LINT)
	@$(GOLANGCI_LINT) run

$(GOLANGCI_LINT):
	curl -sfL https://install.goreleaser.com/github.com/golangci/golangci-lint.sh | sh -s -- -b $(BIN_DIR) v1.23.6

test:
e2e-test:
	@export GOPATH=$(PWD)/gopath; umask 0; cd $${GOPATH}/src/$(ROOT);                  \
		go test -v -covermode=count -coverprofile=coverage.out ./...

build-local:
	go build -v -o $(OUTPUT_DIR)/multus -mod=vendor -p $(CPUS)                   \
	  -ldflags "-s -w -X main.version=$(VERSION)                        \
	  -X main.commit=$(GITCOMMIT) -X main.date=$(BUILDDATE)"                       \
	  ./cmd;                                                   \

build-linux:
	@docker run --rm -t --net=none                                                     \
	  -v $(PWD):/go/src/$(ROOT)                                                        \
	  -w /go/src/$(ROOT)                                                               \
	  -e GOOS=linux                                                                    \
	  -e GOARCH=$(ARCH)                                                                \
	  -e GOPATH=/go                                                                    \
	  -e SHELLOPTS=$(SHELLOPTS)                                                        \
	  $(BASE_REGISTRY)/golang:1.13-security                                            \
	    go build -i -v -o $(OUTPUT_DIR)/multus -p $(CPUS) -mod=vendor                  \
	        -ldflags "-s -w -X main.version=$(VERSION)                                 \
	        -X main.commit=$(GITCOMMIT) -X main.date=$(BUILDDATE)"                     \
	        ./cmd;

container: build-linux
	@for target in $(TARGETS); do                                                      \
	  image=$(IMAGE_PREFIX)$${target}$(IMAGE_SUFFIX);                                  \
	  docker build -t $(REGISTRY)/$${image}:$(VERSION)                                 \
	    --label $(DOCKER_LABELS)                                                       \
	    -f ./$(DOCKERFILE) .;                                                          \
	done

push: container
	@for target in $(TARGETS); do                                                      \
	  image=$(IMAGE_PREFIX)$${target}$(IMAGE_SUFFIX);                                  \
	  docker push $(REGISTRY)/$${image}:$(VERSION);                                    \
	done

lint:
	@echo "skip lint"

.PHONY: clean
clean:
	@-rm -vrf ${OUTPUT_DIR}
