ARCH := $(shell uname -m)
DIST_DIR := dist
BINARY_PATH := .build/release/seldon

.PHONY: all build-release clean-dist binary bundle app release-assets

all: release-assets

build-release:
	swift build -c release --product seldon

clean-dist:
	rm -rf $(DIST_DIR)

binary: build-release
	DIST_DIR=$(DIST_DIR) BIN_PATH=$(BINARY_PATH) ARCH=$(ARCH) \
		scripts/package-binary.sh

bundle: build-release
	DIST_DIR=$(DIST_DIR) BIN_PATH=$(BINARY_PATH) ARCH=$(ARCH) \
		scripts/package-bundle.sh

app: build-release
	DIST_DIR=$(DIST_DIR) BIN_PATH=$(BINARY_PATH) ARCH=$(ARCH) \
		scripts/package-app.sh

release-assets: binary bundle app
	@echo "Release assets created in $(DIST_DIR)"
