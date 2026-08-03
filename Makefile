PRODUCT_NAME := HangulInputFixer
APP_NAME := dhxk
BUILD_DIR := .build/release
APP_DIR := dist/$(APP_NAME).app
# The repository lives in an iCloud Drive folder, which re-attaches FinderInfo and
# resource-fork metadata to bundles while they are assembled. codesign rejects that
# ("resource fork, Finder information, or similar detritus not allowed"), so the
# bundle is assembled and signed on local disk and only then copied into dist/.
STAGE_DIR := /private/tmp/dhxk-app-stage/$(APP_NAME).app
INSTALL_DIR := /Applications/$(APP_NAME).app
BUNDLE_ID ?= com.jinsu1011.dhxk
VERSION ?= 0.3.2
BUILD_NUMBER ?= 6
REGISTRATION_ENDPOINT ?=
SKALA_REGISTRATION_REQUIRED ?= false

.PHONY: test benchmark build app install universal clean run

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
	@test "$(APP_DIR)" = "dist/dhxk.app" || { echo "Unexpected APP_DIR: $(APP_DIR)"; exit 1; }
	@test "$(STAGE_DIR)" = "/private/tmp/dhxk-app-stage/dhxk.app" || { echo "Unexpected STAGE_DIR: $(STAGE_DIR)"; exit 1; }
	rm -rf "$(STAGE_DIR)"
	mkdir -p "$(STAGE_DIR)/Contents/MacOS" "$(STAGE_DIR)/Contents/Resources"
	cp "$(BUILD_DIR)/$(PRODUCT_NAME)" "$(STAGE_DIR)/Contents/MacOS/$(PRODUCT_NAME)"
	cp Resources/Info.plist "$(STAGE_DIR)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $(BUNDLE_ID)" "$(STAGE_DIR)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" "$(STAGE_DIR)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(BUILD_NUMBER)" "$(STAGE_DIR)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :SKALARegistrationRequired $(SKALA_REGISTRATION_REQUIRED)" "$(STAGE_DIR)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Set :SKALARegistrationEndpoint $(REGISTRATION_ENDPOINT)" "$(STAGE_DIR)/Contents/Info.plist"
	cp Resources/AppIcon.icns "$(STAGE_DIR)/Contents/Resources/AppIcon.icns"
	chmod +x "$(STAGE_DIR)/Contents/MacOS/$(PRODUCT_NAME)"
	xattr -cr "$(STAGE_DIR)"
	codesign --force --deep --sign - "$(STAGE_DIR)"
	codesign --verify --deep --strict "$(STAGE_DIR)"
	rm -rf "$(APP_DIR)"
	mkdir -p dist
	COPYFILE_DISABLE=1 ditto --norsrc --noextattr --noacl --noqtn "$(STAGE_DIR)" "$(APP_DIR)"
	xattr -cr "$(APP_DIR)"
	@echo "Signed bundle: $(STAGE_DIR) (verified)"
	@echo "Convenience copy: $(APP_DIR) (iCloud may re-stamp FinderInfo; verify the staged or installed copy)"

# Installs the staged, verified bundle. Copies from local disk rather than dist/
# so no iCloud metadata can ride along into /Applications.
install: app
	@test "$(INSTALL_DIR)" = "/Applications/dhxk.app" || { echo "Unexpected INSTALL_DIR: $(INSTALL_DIR)"; exit 1; }
	- pkill -f "$(INSTALL_DIR)/Contents/MacOS/$(PRODUCT_NAME)"
	rm -rf "$(INSTALL_DIR)"
	COPYFILE_DISABLE=1 ditto --norsrc --noextattr --noacl --noqtn "$(STAGE_DIR)" "$(INSTALL_DIR)"
	xattr -cr "$(INSTALL_DIR)"
	codesign --verify --deep --strict --verbose=2 "$(INSTALL_DIR)"
	@echo "Installed $(INSTALL_DIR)"

run: app
	open "$(APP_DIR)"

universal:
	Scripts/build-universal.sh

clean:
	swift package clean
	rm -rf dist
