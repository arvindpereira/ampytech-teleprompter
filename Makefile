# Builds use the full Xcode even if xcode-select points at the Command Line Tools.
export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer

PROJECT   := Teleprompter.xcodeproj
SCHEME    := Teleprompter
SIMULATOR ?= iPhone 17 Pro
DEST      := platform=iOS Simulator,name=$(SIMULATOR)
DERIVED   := build/DerivedData
APP       := $(DERIVED)/Build/Products/Debug-iphonesimulator/Teleprompter.app
BUNDLE_ID := com.ampytech.teleprompter

.PHONY: build test run open icon clean

build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)' -derivedDataPath $(DERIVED) -quiet build

test:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DEST)' -derivedDataPath $(DERIVED) -quiet test

run: build
	xcrun simctl boot '$(SIMULATOR)' 2>/dev/null || true
	open -a Simulator
	xcrun simctl install booted $(APP)
	xcrun simctl launch booted $(BUNDLE_ID)

open:
	open $(PROJECT)

icon:
	swift scripts/make_icon.swift Teleprompter/Assets.xcassets/AppIcon.appiconset/AppIcon.png

clean:
	rm -rf build
