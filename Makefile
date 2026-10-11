XCODE_DIR ?= $(shell ./scripts/find-xcode.sh)
export DEVELOPER_DIR := $(XCODE_DIR)
export CLANG_MODULE_CACHE_PATH := $(CURDIR)/.build/clang-cache
export SWIFTPM_MODULECACHE_OVERRIDE := $(CURDIR)/.build/module-cache
SPM_FLAGS = --disable-sandbox --cache-path .build/spm-cache --config-path .build/spm-config --security-path .build/spm-security
TEST_FLAGS ?=

.PHONY: check-tools build run test test-ci release icon audit
check-tools:
	@test -n "$(XCODE_DIR)" || { echo "Install full Xcode, or set XCODE_DIR to its Contents/Developer directory." >&2; exit 1; }
	@XCODE_DIR="$(DEVELOPER_DIR)" ./scripts/find-xcode.sh >/dev/null
	@xcrun --find swift >/dev/null
	@xcrun --sdk macosx --show-sdk-path >/dev/null
build: check-tools
	swift build $(SPM_FLAGS)
	./scripts/bundle.sh debug "$$(swift build $(SPM_FLAGS) --show-bin-path)"
run: build
	open build/Sipfolio.app
test: check-tools
	swift test $(SPM_FLAGS) $(TEST_FLAGS)
test-ci: check-tools
	swift test $(SPM_FLAGS) --skip realBottleBecomesTransparentSticker $(TEST_FLAGS)
release: check-tools
	swift build -c release $(SPM_FLAGS)
	./scripts/bundle.sh release "$$(swift build -c release $(SPM_FLAGS) --show-bin-path)"
icon: check-tools
	xcrun swift -module-cache-path .build/module-cache scripts/generate-icon.swift build/AppIcon.iconset
	iconutil -c icns build/AppIcon.iconset -o packaging/AppIcon.icns
audit:
	python3 scripts/check-repository.py
