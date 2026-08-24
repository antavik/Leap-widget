PROJECT      := Leap.xcodeproj
SCHEME       := Leap
BUILD_DIR    := build
APP_NAME     := Leap.app
INSTALL_DIR  := /Applications

RELEASE_APP  := $(BUILD_DIR)/Build/Products/Release/$(APP_NAME)
DEBUG_APP    := $(BUILD_DIR)/Build/Products/Debug/$(APP_NAME)

.PHONY: all release debug test install clean

all: test release

release:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
		-configuration Release -derivedDataPath $(BUILD_DIR) build

debug:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
		-configuration Debug -derivedDataPath $(BUILD_DIR) build

test:
	swift test --package-path LeapCore

install: release
	ditto $(RELEASE_APP) $(INSTALL_DIR)/$(APP_NAME)
	pluginkit -a $(INSTALL_DIR)/$(APP_NAME)/Contents/PlugIns/LeapWidget.appex
	-killall chronod 2>/dev/null

clean:
	rm -rf $(BUILD_DIR)
