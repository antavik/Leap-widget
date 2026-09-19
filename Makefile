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

.PHONY: all project release debug test report reports-prune snapshots-record install uninstall clean

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
	./scripts/check-uninstall-paths.sh
	./scripts/check-localization.sh
	./scripts/check-widget-options.sh
	./scripts/check-test-plan.sh
	swift test --package-path LeapCore

report:
	./scripts/run-tests.sh

reports-prune:
	@ls -1d reports/*/ 2>/dev/null | sort | \
		awk '{ kept[NR] = $$0 } END { for (i = 1; i <= NR - 20; i++) print kept[i] }' | \
		xargs rm -rf
	@echo "reports-prune: $$(ls -1d reports/*/ 2>/dev/null | wc -l | tr -d ' ') runs kept"

snapshots-record:
	LEAP_RECORD_SNAPSHOTS=1 swift test --package-path LeapCore --filter SnapshotTests

install: release
	rm -rf $(INSTALL_DIR)/$(APP_NAME)
	ditto $(RELEASE_APP) $(INSTALL_DIR)/$(APP_NAME)
	$(LSREGISTER) -f -R -trusted $(INSTALL_DIR)/$(APP_NAME)
	pluginkit -a $(INSTALL_DIR)/$(APP_NAME)/Contents/PlugIns/LeapWidget.appex

uninstall:
	-osascript -e 'if application "Leap" is running then tell application "Leap" to quit'
	-pkill -f '$(INSTALL_DIR)/$(APP_NAME)/Contents/PlugIns/LeapWidget.appex'
	-pluginkit -r $(INSTALL_DIR)/$(APP_NAME)/Contents/PlugIns/LeapWidget.appex
	-$(LSREGISTER) -u $(INSTALL_DIR)/$(APP_NAME)
	-rm -rf "$(HOME)/Library/Preferences/com.antavik.leap.plist" \
	       "$(HOME)/Library/Containers/com.antavik.leap" \
	       "$(HOME)/Library/Containers/com.antavik.leap.widget" \
	       "$(HOME)/Library/Application Scripts/com.antavik.leap" \
	       "$(HOME)/Library/Application Scripts/com.antavik.leap.widget" \
	       "$(HOME)/Library/Saved Application State/com.antavik.leap.savedState" \
	       "$(HOME)/Library/Caches/com.antavik.leap" \
	       "$(INSTALL_DIR)/$(APP_NAME)"

clean:
	-$(LSREGISTER) -u $(RELEASE_APP)
	-$(LSREGISTER) -u $(DEBUG_APP)
	rm -rf $(BUILD_DIR) $(PROJECT)
