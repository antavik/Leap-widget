PROJECT      := Leap.xcodeproj
SCHEME       := Leap
BUILD_DIR    := build
APP_NAME     := Leap.app
INSTALL_DIR  := /Applications
BUILD_COMMIT := $(shell git rev-parse --short=8 HEAD 2>/dev/null || echo unknown)
BUILD_VERSION ?= $(shell date +%s)
LSREGISTER   := /System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister

RELEASE_APP  := $(BUILD_DIR)/Build/Products/Release/$(APP_NAME)
DEBUG_APP    := $(BUILD_DIR)/Build/Products/Debug/$(APP_NAME)

.PHONY: all project release debug test install clean

all: test release

project:
	xcodegen generate --spec project.yml

release: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
		-configuration Release -derivedDataPath $(BUILD_DIR) \
		LEAP_BUILD_COMMIT=$(BUILD_COMMIT) \
		CURRENT_PROJECT_VERSION=$(BUILD_VERSION) build
	-$(LSREGISTER) -u $(RELEASE_APP)

debug: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
		-configuration Debug -derivedDataPath $(BUILD_DIR) \
		LEAP_BUILD_COMMIT=$(BUILD_COMMIT) \
		CURRENT_PROJECT_VERSION=$(BUILD_VERSION) build
	-$(LSREGISTER) -u $(DEBUG_APP)

test:
	swift test --package-path LeapCore

install: release
	rm -rf $(INSTALL_DIR)/$(APP_NAME)
	ditto $(RELEASE_APP) $(INSTALL_DIR)/$(APP_NAME)
	$(LSREGISTER) -f -R -trusted $(INSTALL_DIR)/$(APP_NAME)
	pluginkit -a $(INSTALL_DIR)/$(APP_NAME)/Contents/PlugIns/LeapWidget.appex

clean:
	-$(LSREGISTER) -u $(RELEASE_APP)
	-$(LSREGISTER) -u $(DEBUG_APP)
	rm -rf $(BUILD_DIR) $(PROJECT)
