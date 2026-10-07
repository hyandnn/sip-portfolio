XCODE_DIR ?= /Applications/Xcode.app/Contents/Developer
export DEVELOPER_DIR := $(XCODE_DIR)
export CLANG_MODULE_CACHE_PATH := $(CURDIR)/.build/clang-cache
export SWIFTPM_MODULECACHE_OVERRIDE := $(CURDIR)/.build/module-cache
SPM_FLAGS = --disable-sandbox --cache-path .build/spm-cache --config-path .build/spm-config --security-path .build/spm-security
TEST_FLAGS ?=

.PHONY: build run test release icon
build:
	swift build $(SPM_FLAGS)
	./scripts/bundle.sh debug
run: build
	open build/Sipfolio.app
test:
	swift test $(SPM_FLAGS) $(TEST_FLAGS)
release:
	swift build -c release $(SPM_FLAGS)
	./scripts/bundle.sh release
icon:
	xcrun swift -module-cache-path .build/module-cache scripts/generate-icon.swift build/AppIcon.iconset
	iconutil -c icns build/AppIcon.iconset -o packaging/AppIcon.icns
