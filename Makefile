# Copyright 2018 The OPA Authors. All rights reserved.
# Use of this source code is governed by an Apache2
# license that can be found in the LICENSE file.

VERSION_OPA := $(shell ./build/get-opa-version.sh)
VERSION := $(VERSION_OPA)-envoy$(shell ./build/get-plugin-rev.sh)
VERSION_ISTIO := $(VERSION_OPA)-istio$(shell ./build/get-plugin-rev.sh)

PACKAGES := $(shell go list ./.../ | grep -v 'vendor')

GO := go
GOVERSION := $(shell cat ./.go-version)
GOARCH ?= $(shell go env GOARCH)
GOOS ?= $(shell go env GOOS)
DISABLE_CGO := CGO_ENABLED=0

BIN := opa_envoy_$(GOOS)_$(GOARCH)

REPOSITORY := openpolicyagent
IMAGE := $(REPOSITORY)/opa

ifeq ($(shell tty > /dev/null && echo 1 || echo 0), 1)
DOCKER_FLAGS := --rm -it
else
DOCKER_FLAGS := --rm
endif

RELEASE_BUILD_IMAGE := golang:$(GOVERSION)

RELEASE_DIR ?= _release/$(VERSION)

BUILD_COMMIT := $(shell ./build/get-build-commit.sh)
BUILD_TIMESTAMP := $(shell ./build/get-build-timestamp.sh)
BUILD_HOSTNAME := $(shell ./build/get-build-hostname.sh)

LDFLAGS := "-X github.com/open-policy-agent/opa/version.Version=$(VERSION) \
	-X github.com/open-policy-agent/opa/version.Vcs=$(BUILD_COMMIT) \
	-X github.com/open-policy-agent/opa/version.Timestamp=$(BUILD_TIMESTAMP) \
	-X github.com/open-policy-agent/opa/version.Hostname=$(BUILD_HOSTNAME)"

GO15VENDOREXPERIMENT := 1
export GO15VENDOREXPERIMENT

LINUX_PLATFORMS := linux/arm64 linux/amd64
PLATFORMS := $(LINUX_PLATFORMS) windows/amd64

temp = $(subst /, ,$@)
os = $(word 1, $(temp))
arch = $(word 2, $(temp))


.PHONY: all build build-darwin build-linux build-windows clean check check-fmt check-vet check-lint \
    deploy-ci docker-login generate image image-quick push push-latest tag-latest \
    test test-cluster test-e2e update-opa update-istio-quickstart-version version

######################################################
#
# Development targets
#
######################################################

all: build test check

version:
	@echo $(VERSION)

generate:
	$(GO) generate ./...

build: generate
	$(GO) build -o $(BIN) -ldflags $(LDFLAGS) ./cmd/opa-envoy-plugin/...

image:
	@$(MAKE) build-linux
	@$(MAKE) image-quick

image-quick:
	docker build --build-arg GOARCH=$(GOARCH) --build-arg GOOS=$(GOOS) -t $(IMAGE):$(VERSION) -f Dockerfile .
	docker tag $(IMAGE):$(VERSION) $(IMAGE):$(VERSION_ISTIO)

push:
	docker push $(IMAGE):$(VERSION)
	docker push $(IMAGE):$(VERSION_ISTIO)

tag-latest:
	docker tag $(IMAGE):$(VERSION) $(IMAGE):latest-envoy
	docker tag $(IMAGE):$(VERSION) $(IMAGE):latest-istio

push-latest:
	docker push $(IMAGE):latest-envoy
	docker push $(IMAGE):latest-istio

docker-login:
	@echo "Docker Login..."
	@echo ${DOCKER_PASSWORD} | docker login -u ${DOCKER_USER} --password-stdin

deploy-ci: docker-login image push tag-latest push-latest

update-opa:
	@./build/update-opa-version.sh $(TAG)

update-istio-quickstart-version:
	sed -i "/opa_container/{N;s/openpolicyagent\/opa:.*/openpolicyagent\/opa:latest-istio\"\,/;}" examples/istio/quick_start.yaml

test: generate
	$(DISABLE_CGO) $(GO) test -v -bench=. $(PACKAGES)

test-e2e:
	bats -t test/bats/test.bats

test-cluster:
	@./build/install-istio-with-kind.sh

clean:
	rm -f Dockerfile_*
	rm -f opa_*_*
	rm -f *.so

check: check-fmt check-vet check-lint

check-fmt:
	./build/check-fmt.sh

check-vet:
	./build/check-vet.sh

check-lint:
	./build/check-lint.sh

generatepb:
	protoc --proto_path=test/files \
	  --descriptor_set_out=test/files/combined.pb \
	  --include_imports \
	  test/files/example/Example.proto \
	  test/files/book/Book.proto

.PHONY: release
release:
	docker run $(DOCKER_FLAGS) \
		-v $(PWD)/$(RELEASE_DIR):/$(RELEASE_DIR) \
		-v $(PWD):/_src \
		$(RELEASE_BUILD_IMAGE) \
		/_src/build/build-release.sh --version=$(VERSION) --output-dir=/$(RELEASE_DIR) --source-url=/_src

release-dir:
	@echo $(RELEASE_DIR)

comma:= ,
empty:=
space:= $(empty) $(empty)

linux-platforms:
	@echo $(subst $(space),$(comma),$(LINUX_PLATFORMS))

.PHONY: ensure-release-dir
ensure-release-dir:
	mkdir -p $(RELEASE_DIR)

.PHONY: build-all-platforms $(PLATFORMS)
build-all-platforms: $(PLATFORMS)

$(PLATFORMS): ensure-release-dir
	@$(MAKE) build GOOS=$(os) GOARCH=$(arch)
	mv opa_envoy_$(os)_$(arch) $(RELEASE_DIR)/opa_envoy_$(os)_$(arch)$(if $(filter $(os),windows),.exe,)