# Build and test tasks for Silent Shout. Run from the repo root.
#
# Simulator work goes through the workspace's shared pool, $(DEVTOOLS)/sim-lane.sh, the same
# way Up There, Byways and Spud Bud use it: one machine-wide slot, one warm device, one run at
# a time. Never point xcodebuild at a simulator by name here.

SHELL := /bin/bash
PROJECT := SilentShout.xcodeproj
SCHEME := SilentShout
DERIVED := build

# Lazily expanded (`=`): resolving the destination creates the pool device if it is missing,
# and `make help` should not do that. Targets that use it depend on `sim-device` first.
DEVTOOLS ?= $(HOME)/Development/devtools
SIM_LANE := $(DEVTOOLS)/sim-lane.sh
SIM_LANE_ERROR := sim-lane.sh not found at $(SIM_LANE). Clone https://github.com/workwithnano/devtools into ~/Development, or set DEVTOOLS=<path>
SIM_LANE_CHECK = $(if $(wildcard $(SIM_LANE)),true,$(error $(SIM_LANE_ERROR)))
SIM_DEST = $(if $(wildcard $(SIM_LANE)),$(shell $(SIM_LANE) dest),$(error $(SIM_LANE_ERROR)))

.DEFAULT_GOAL := help

.PHONY: help build test test-ui record-marquee check-sim-lane sim-device sim-clean sim-doctor clean

help: ## List available targets
	@grep -hE '^[a-z][a-z-]*:.*##' $(MAKEFILE_LIST) \
	  | awk -F':.*## ' '{printf "  %-12s %s\n", $$1, $$2}'

build: sim-device ## Debug build for the simulator
	$(SIM_LANE) run -- xcodebuild -project $(PROJECT) -scheme $(SCHEME) -sdk iphonesimulator \
	  -destination '$(SIM_DEST)' -derivedDataPath $(DERIVED) build

# The unit target uses Swift Testing, so xcodebuild also prints a legacy "Executed 0 tests"
# line from the empty XCTest suite. The Swift Testing summary ("Test run with N tests ...")
# is the one that counts. Result bundles land in $(DERIVED)/Logs/Test/.
test: sim-device ## Run the Swift Testing unit tests
	$(SIM_LANE) run -- xcodebuild -project $(PROJECT) -scheme $(SCHEME) -only-testing:SilentShoutTests \
	  -destination '$(SIM_DEST)' -derivedDataPath $(DERIVED) test

# Parallel testing stays off: it clones simulators, which the shared pool exists to avoid.
# UI_ONLY narrows the run, e.g. `make test-ui UI_ONLY=SilentShoutUITests/ShoutScreenTests`.
UI_ONLY ?= SilentShoutUITests
test-ui: sim-device ## Run the XCUITest UI tests (slower; UI_ONLY=<target/class[/method]> narrows)
	$(SIM_LANE) run -- xcodebuild -project $(PROJECT) -scheme $(SCHEME) -only-testing:$(UI_ONLY) \
	  -destination '$(SIM_DEST)' -derivedDataPath $(DERIVED) \
	  -parallel-testing-enabled NO test

# Films the scrolling marquee (Kristi on the notecard, a long message, device landscape left)
# with `simctl io recordVideo` on the pool device, inside the lane's `run`, and samples the
# app's CPU meanwhile. Writes OUT (upright H.264), OUT's -raw.mov, -frame-N.png and -cpu.txt.
# Runs only SilentShoutUITests/MarqueeRecordingTests, which the normal suite skips.
OUT ?= build/recordings/marquee.mp4
record-marquee: sim-device ## Record the marquee on the simulator (OUT=<file.mp4>)
	$(SIM_LANE) run -- scripts/record-marquee.sh '$(OUT)' '$(SIM_DEST)'

check-sim-lane:
	@$(SIM_LANE_CHECK)

sim-device: check-sim-lane ## Create the pool simulator if it does not exist yet
	@$(SIM_LANE) udid >/dev/null

sim-clean: check-sim-lane ## Reset the pool simulator (safe; only this slot's device)
	@$(SIM_LANE) clean

sim-doctor: check-sim-lane ## Report the slot pool and what else is running
	@$(SIM_LANE) doctor

clean: ## Remove build products
	rm -rf $(DERIVED)
