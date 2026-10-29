PROJECT      := Leap.xcodeproj
SCHEME       := Leap
BUILD_DIR    := build
APP_NAME     := Leap Widget.app
INSTALL_DIR  := /Applications
BUILD_COMMIT := $(shell git rev-parse --short=8 HEAD 2>/dev/null || echo unknown)
BUILD_VERSION ?= $(shell date +%s)
# The latest vX.Y.Z tag: builds past it keep its version and differ by commit.
APP_VERSION  := $(or $(shell git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null | sed 's/^v//'),0.0.0)
LSREGISTER   := /System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister

RELEASE_APP  := $(BUILD_DIR)/Build/Products/Release/$(APP_NAME)
DEBUG_APP    := $(BUILD_DIR)/Build/Products/Debug/$(APP_NAME)

TEST_PLAN    := Leap
UI_RESULTS   := $(BUILD_DIR)/LeapUITests.xcresult
UI_SIGNING   := CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual
ONLY         ?=

.PHONY: all help project help-book release dist debug test ui-test lint report reports-prune snapshots-record uninstall clean

all: lint test release ## lints, tests, then a Release build (default)

help: ## list targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN { FS = ":.*?## " } { printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2 }'

help-book: ## render docs/manual into build/help/Leap.help
	LEAP_VERSION=$(APP_VERSION) ./scripts/build-help.sh

project: help-book ## generate Leap.xcodeproj from project.yml
	xcodegen generate --spec project.yml

release: help-book project ## Release build into build/
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
		-configuration Release -derivedDataPath $(BUILD_DIR) \
		-destination 'generic/platform=macOS' \
		CLANG_COVERAGE_MAPPING=NO \
		MARKETING_VERSION=$(APP_VERSION) \
		LEAP_BUILD_COMMIT=$(BUILD_COMMIT) \
		CURRENT_PROJECT_VERSION=$(BUILD_VERSION) build
	-$(LSREGISTER) -u "$(RELEASE_APP)"

dist: ## signed + notarized DMG – make dist VERSION=x.y.z [PUBLISH=1]
	@test -n "$(VERSION)" || { echo "usage: make dist VERSION=x.y.z [PUBLISH=1]" >&2; exit 1; }
	./scripts/release.sh $(VERSION) $(if $(PUBLISH),--publish,)

debug: project ## Debug build into build/
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
		-configuration Debug -derivedDataPath $(BUILD_DIR) \
		MARKETING_VERSION=$(APP_VERSION) \
		LEAP_BUILD_COMMIT=$(BUILD_COMMIT) \
		CURRENT_PROJECT_VERSION=$(BUILD_VERSION) build
	-$(LSREGISTER) -u "$(DEBUG_APP)"

test: ## L0 consistency checks + LeapCore tests (L1-L3)
	./scripts/check-uninstall-paths.sh
	./scripts/check-help.sh
	./scripts/check-localization.sh
	./scripts/check-widget-options.sh
	./scripts/check-test-plan.sh
	swift test --package-path LeapCore

ui-test: project ## L4 UI tests, takes over the screen; ONLY=<test> narrows
	rm -rf $(UI_RESULTS)
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-derivedDataPath $(BUILD_DIR) build-for-testing $(UI_SIGNING) && \
	xcodebuild test-without-building \
		-project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-derivedDataPath $(BUILD_DIR) -testPlan $(TEST_PLAN) \
		-resultBundlePath $(UI_RESULTS) \
		$(if $(ONLY),-only-testing:$(ONLY)) $(UI_SIGNING); \
	status=$$?; $(LSREGISTER) -u "$(DEBUG_APP)"; exit $$status

lint: ## SwiftLint, strict
	swiftlint lint --strict --quiet

report: ## tests plus a report in reports/<stamp>-<hash>/
	./scripts/run-tests.sh

reports-prune: ## keep only the 20 newest reports
	@ls -1d reports/*/ 2>/dev/null | sort | \
		awk '{ kept[NR] = $$0 } END { for (i = 1; i <= NR - 20; i++) print kept[i] }' | \
		xargs rm -rf
	@echo "reports-prune: $$(ls -1d reports/*/ 2>/dev/null | wc -l | tr -d ' ') runs kept"

snapshots-record: ## re-record golden snapshots
	LEAP_RECORD_SNAPSHOTS=1 swift test --package-path LeapCore --filter SnapshotTests

uninstall: ## remove the /Applications copy and its settings
	-osascript -e 'if application id "com.antavik.leapwidget" is running then tell application id "com.antavik.leapwidget" to quit'
	-pkill -f '$(INSTALL_DIR)/$(APP_NAME)/Contents/PlugIns/LeapWidget.appex'
	-pluginkit -r "$(INSTALL_DIR)/$(APP_NAME)/Contents/PlugIns/LeapWidget.appex"
	-$(LSREGISTER) -u "$(INSTALL_DIR)/$(APP_NAME)"
	-rm -rf "$(HOME)/Library/Preferences/com.antavik.leapwidget.plist" \
	       "$(HOME)/Library/Containers/com.antavik.leapwidget" \
	       "$(HOME)/Library/Containers/com.antavik.leapwidget.widget" \
	       "$(HOME)/Library/Application Scripts/com.antavik.leapwidget" \
	       "$(HOME)/Library/Application Scripts/com.antavik.leapwidget.widget" \
	       "$(HOME)/Library/Saved Application State/com.antavik.leapwidget.savedState" \
	       "$(HOME)/Library/Caches/com.antavik.leapwidget" \
	       "$(INSTALL_DIR)/$(APP_NAME)"

clean: ## delete build/ and the generated project
	-$(LSREGISTER) -u "$(RELEASE_APP)"
	-$(LSREGISTER) -u "$(DEBUG_APP)"
	rm -rf $(BUILD_DIR) $(PROJECT)
