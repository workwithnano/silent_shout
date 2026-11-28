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

.PHONY: help build test test-ui record-marquee check-sim-lane sim-device sim-clean sim-doctor clean \
  check-team check-asc check-clean check-build-number bump-build bump-build-dry bump-version bump-version-dry archive ipa upload \
  asc-bundle-id asc-bundle-id-register asc-app

help: ## List available targets
	@grep -hE '^[a-z][a-z-]*:.*##' $(MAKEFILE_LIST) \
	  | awk -F':.*## ' '{printf "  %-22s %s\n", $$1, $$2}'

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

clean: ## Remove build products (including the archive)
	rm -rf $(DERIVED)

# --- Release: App Store Connect (see docs/release.md) ------------------------------------------
# Credentials live in .env (gitignored; copy .env.example). Recipes that read it source it
# without `set -x` and never echo a value. xcodebuild prints its own command line, which carries
# the team id and key settings, and the signing log names the team, so its output goes through
# REDACT, which replaces every .env value (and the absolute key path) with [redacted]. The team
# id is passed on the command line only; project.pbxproj stays without one.

PBXPROJ := $(PROJECT)/project.pbxproj
ARCHIVE := $(DERIVED)/SilentShout.xcarchive
EXPORT_DIR := $(DERIVED)/export
RELEASE_LOGS := $(DERIVED)/release-logs
LOAD_ENV := set -a; source ./.env; set +a; \
  ASC_KEY_ABS="$$(cd "$$(dirname "$$ASC_KEY_PATH")" && pwd)/$$(basename "$$ASC_KEY_PATH")"; export ASC_KEY_ABS
REDACT := perl -pe 'BEGIN { @s = grep { length } @ENV{qw(ASC_KEY_ABS ASC_KEY_PATH DEVELOPMENT_TEAM ASC_ISSUER_ID ASC_KEY_ID)} } for my $$v (@s) { s/\Q$$v\E/[redacted]/g }'
ASC_AUTH := -allowProvisioningUpdates -authenticationKeyPath "$$ASC_KEY_ABS" \
  -authenticationKeyID "$$ASC_KEY_ID" -authenticationKeyIssuerID "$$ASC_ISSUER_ID"

.env:
	cp .env.example .env
	chmod 600 .env
	@echo "Created .env from .env.example: fill in the blank values, then rerun."
	@false

check-team: .env ## Verify DEVELOPMENT_TEAM is set in .env
	@set -a; source ./.env; set +a; \
	test -n "$$DEVELOPMENT_TEAM" || { echo "✗ DEVELOPMENT_TEAM is empty in .env"; exit 1; }; \
	echo "✓ signing: DEVELOPMENT_TEAM is set"

check-asc: .env ## Verify the App Store Connect API key settings in .env
	@set -a; source ./.env; set +a; \
	for v in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH; do \
	  test -n "$${!v}" || { echo "✗ $$v is empty in .env"; exit 1; }; \
	done; \
	test -f "$$ASC_KEY_PATH" || { echo "✗ the file named by ASC_KEY_PATH does not exist"; exit 1; }; \
	echo "✓ App Store Connect: key, issuer and key file are set"

check-clean: ## Refuse to archive an uncommitted source tree
	@test -z "$$(git status --porcelain)" \
	  || { echo "✗ Working tree is not clean; commit changes before archiving"; git status --short; exit 1; }
	@echo "✓ working tree is clean"

# Versions are YYYY.MM.PATCH (patch from 0 within a month), as in Up There and Spud Bud.
bump-version: ## Bump MARKETING_VERSION to the next YYYY.MM.PATCH
	scripts/bump-version.sh

bump-version-dry: ## Preview the next version without writing it
	scripts/bump-version.sh --dry-run

# App Store Connect rejects a repeated (marketing version, build number) pair, so every upload
# needs a fresh build number. Commit the bump before `make archive` (it needs a clean tree).
bump-build: ## Bump CURRENT_PROJECT_VERSION to the next build number
	scripts/bump-build.sh

bump-build-dry: ## Preview the next build number without writing it
	scripts/bump-build.sh --dry-run

check-build-number: check-asc ## Verify this version and build number are not already in ASC
	@set -a; source ./.env; set +a; swift scripts/check-build-number.swift

# Release configuration, generic iOS device. -allowProvisioningUpdates with the API key lets
# xcodebuild create the distribution certificate and profile itself (cloud signing). The old
# archive is deleted first, so an archive on disk always comes from the latest run. The full
# (redacted) log is in $(RELEASE_LOGS)/archive.log.
archive: check-clean check-team check-asc ## Release archive for devices (build/SilentShout.xcarchive)
	@rm -rf $(ARCHIVE); mkdir -p $(RELEASE_LOGS)
	@set -o pipefail; $(LOAD_ENV); \
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
	  -destination 'generic/platform=iOS' -derivedDataPath $(DERIVED) -archivePath $(ARCHIVE) \
	  $(ASC_AUTH) DEVELOPMENT_TEAM="$$DEVELOPMENT_TEAM" archive 2>&1 \
	  | $(REDACT) > $(RELEASE_LOGS)/archive.log; \
	status=$$?; tail -n 5 $(RELEASE_LOGS)/archive.log; \
	if [ $$status -ne 0 ] || [ ! -d $(ARCHIVE) ]; then \
	  echo "✗ archive failed; errors:"; grep -E 'error:|❌' $(RELEASE_LOGS)/archive.log | head -20; exit 1; fi; \
	echo "✓ archive: $(ARCHIVE)"

ipa: archive ## Export an App Store-signed .ipa without uploading (build/export/)
	@rm -rf $(EXPORT_DIR)
	@set -o pipefail; $(LOAD_ENV); \
	xcodebuild -exportArchive -archivePath $(ARCHIVE) -exportPath $(EXPORT_DIR) \
	  -exportOptionsPlist scripts/export-options-ipa.plist $(ASC_AUTH) 2>&1 \
	  | $(REDACT) > $(RELEASE_LOGS)/ipa.log \
	  || { tail -n 20 $(RELEASE_LOGS)/ipa.log; exit 1; }
	@ls -l $(EXPORT_DIR)/*.ipa

# Needs the app record (created once on the website, docs/release.md). The build then appears
# in App Store Connect > TestFlight after processing.
upload: check-asc check-build-number archive ## Upload the archive to App Store Connect (TestFlight)
	@set -o pipefail; $(LOAD_ENV); \
	xcodebuild -exportArchive -archivePath $(ARCHIVE) \
	  -exportOptionsPlist scripts/export-options-upload.plist $(ASC_AUTH) 2>&1 \
	  | $(REDACT) | tee $(RELEASE_LOGS)/upload.log

asc-bundle-id: check-asc ## Show whether the bundle id is registered in the developer account
	@set -a; source ./.env; set +a; swift scripts/asc-bundle-id.swift status

asc-bundle-id-register: check-asc ## Register the bundle id com.corduroying.silentshout (if missing)
	@set -a; source ./.env; set +a; swift scripts/asc-bundle-id.swift register

asc-app: check-asc ## Show whether an App Store Connect app record uses the bundle id
	@set -a; source ./.env; set +a; swift scripts/asc-bundle-id.swift app
