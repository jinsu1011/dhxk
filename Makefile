PRODUCT_NAME := HangulInputFixer
APP_NAME := dhxk
BUILD_DIR := .build/release
APP_DIR := dist/$(APP_NAME).app
REGISTRATION_ENDPOINT ?=
SKALA_REGISTRATION_REQUIRED ?= false

.PHONY: test benchmark build app universal clean run

test:
	mkdir -p .build/cache/clang .build/cache/swiftpm
	CLANG_MODULE_CACHE_PATH="$(CURDIR)/.build/cache/clang" SWIFTPM_MODULECACHE_OVERRIDE="$(CURDIR)/.build/cache/swiftpm" swift run --disable-sandbox CoreTests
	node Tests/BackendRegistrationTests.js

benchmark:
	mkdir -p .build/cache/clang .build/cache/swiftpm
	CLANG_MODULE_CACHE_PATH="$(CURDIR)/.build/cache/clang" SWIFTPM_MODULECACHE_OVERRIDE="$(CURDIR)/.build/cache/swiftpm" swift run --disable-sandbox -c release CoreBenchmark

build:
	mkdir -p .build/cache/clang .build/cache/swiftpm
	CLANG_MODULE_CACHE_PATH="$(CURDIR)/.build/cache/clang" SWIFTPM_MODULECACHE_OVERRIDE="$(CURDIR)/.build/cache/swiftpm" swift build --disable-sandbox -c release

app: build
	mkdir -p "$(APP_DIR)/Contents/MacOS" "$(APP_DIR)/Contents/Resources"
	cp "$(BUILD_DIR)/$(PRODUCT_NAME)" "$(APP_DIR)/Contents/MacOS/$(PRODUCT_NAME)"
	cp Resources/Info.plist "$(APP_DIR)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :SKALARegistrationRequired $(SKALA_REGISTRATION_REQUIRED)" "$(APP_DIR)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :SKALARegistrationEndpoint $(REGISTRATION_ENDPOINT)" "$(APP_DIR)/Contents/Info.plist"
	cp Resources/AppIcon.icns "$(APP_DIR)/Contents/Resources/AppIcon.icns"
	chmod +x "$(APP_DIR)/Contents/MacOS/$(PRODUCT_NAME)"
	codesign --force --deep --sign - "$(APP_DIR)"
	@echo "Created $(APP_DIR)"

run: app
	open "$(APP_DIR)"

universal:
	Scripts/build-universal.sh

clean:
	swift package clean
	rm -rf dist
