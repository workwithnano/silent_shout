# Rewrite state

Checkout: `~/Development/silent_shout`, branch `swift-rewrite`.
Read `PLAN.md` first. Resume at the first row that is not `done`.
Statuses: `todo`, `in progress`, `done`.

| # | Phase | Status | Commit | Notes |
|---|---|---|---|---|
| 0 | Plan and behaviour spec | done | | PLAN.md, SPEC.md, rulings on the spec's open points |
| 1 | Scaffold | done | 818ec4a | Project, Makefile, asset catalog (113 image sets), fonts, `ShoutSettings` + option enums, placeholder screen. `make build`, `make test` (29 tests / 55 runs) and `make test-ui` (1 test) pass. See Notes. |
| 2 | Options screen | done | 4d33108 | `OptionsView` as the root in a `NavigationStack`, three paged carousels (font, texture, lettering, top to bottom as in `MainView.xib`), page dots, persistence at 50% with clamping, 40-frame sizing loops, help button and 0.5 s overlay, Next to a stub Editing screen. `make build`, `make test` (42 tests / 7 suites) and `make test-ui` (5 tests) pass. Screenshots in `docs/rewrite/screenshots/`. See Notes. |
| 3 | Editing screen | todo | | |
| 4 | Shout screen | todo | | |
| 5 | 1.0.1 additions, finished | todo | | |
| 6 | Parity pass and wrap-up | todo | | |

## Log

- 2026-11-26: branch created from `origin/1.0.1`, issue #3 opened, plan written.
- 2026-11-26: SPEC.md written; open points ruled on in PLAN.md. Phase 1 next.
- 2026-11-26: Phase 1 done. `code/` deleted. Later On registers as PostScript `lateron` (SPEC open point 1 closed). Phase 2 next.
- 2026-11-26: Phase 2 done. Placeholder screen removed; background tiles mirrored and trimmed (QUESTIONS 4); questions 4 to 6 added. Phase 3 next.

## Notes for the next phases

- **Layout.** `SilentShout/` (app), `SilentShoutTests/` (Swift Testing, hosted in the app), `SilentShoutUITests/` (XCUITest) are file-system-synchronized groups: add files on disk, never edit pbxproj file lists. `SilentShout/Info.plist` is excluded from resources by an exception set; it holds only `UIAppFonts` and `UILaunchScreen`, the rest is generated from build settings (`INFOPLIST_KEY_*`).
- **Orientations.** The app target allows portrait and both landscapes (`INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone`); phases 2 to 4 restrict per screen.
- **Model.** `ShoutSettings` (`Model/ShoutSettings.swift`) writes to UserDefaults on every assignment. Phase 3 should keep the field's text in local state and assign `settings.text` on each screen change (ruling 9), not on every keystroke. The lettering setting is the `sizing` property (key `lettering`). Out-of-range stored values clamp to the nearest option (a stored lettering 2 reads as scroll); SPEC section 4 records this.
- **Names.** `ShoutFont.fontName` (`lateron`, `Kristi`, `Helvetica`), `.ink` (`InkColor`, `.color` / `.uiColor`), `.carouselImageName`; `ShoutTexture.shoutImageName` / `.previewImageName` / `.carouselImageName`, `ShoutTexture.cameraCarouselImageName`; `ShoutSizing.frameImageNames` (40 names) and `animationDuration` (5 s); `ChromeImage` holds every button, help bubble and toolbar asset name. Asset names are the original file names without extension.
- **Art sizes.** The preview textures' @2x files are 639x451 px (half a point short) and `bkgrnd_main@2x` is 640x921; size those by frame. Back/back2/doubleback/share are 38x38 pt art (ruling 7).
- **Placeholder.** Removed in phase 2. Font and image loading is still asserted by `BundleResourceTests`.
- **Navigation (phase 2).** `Navigation/AppNavigation.swift`: `RootView` owns a `NavigationStack(path:)` driven by the `@Observable` `AppNavigation` in the environment (`showEditing()`, `pop()`, `popToOptions()` for phase 4's double-back). `AppRoute.editing` currently maps to `EditingPlaceholderView` (`Views/EditingPlaceholderView.swift`, ids `editing.placeholder` and `editing.back`); phase 3 replaces that view and the `navigationDestination` case, then deletes the placeholder and updates `testNextOpensEditingAndBackReturns`. Screens hide the system nav bar (`.toolbar(.hidden, for: .navigationBar)`), so the swipe-back gesture is off; the screen's own back button pops.
- **Orientation (phase 2).** `OrientationLock.set(_:)` (same file) plus `AppDelegate.supportedInterfaceOrientationsFor` returns `OrientationLock.mask`, default `.portrait`; Options and the stub call `.set(.portrait)` on appear. Phase 4 sets `.landscape` for the shout and back to `.portrait` on leaving.
- **Options views (phase 2).** `Views/OptionsView.swift` (screen, `HelpBubble`, `MainBackground` with the mirrored tile, `OptionsAccessibilityID`), `Views/OptionCarousel.swift` (generic paged carousel + `PageDots`; its `trailing:` slot is laid out after the last page and is never a page: phase 5 puts the camera entry there), `Views/SizingAnimationView.swift`, `Views/ImageButtonStyle.swift` (UP/DOWN/selected art buttons; reuse for Editing and Shout buttons). Pure geometry and logic in `Layout/OptionsLayout.swift`: `OptionsLayout`, `CarouselPaging.page(forOffset:pageWidth:count:)`, `SizingAnimation.frameIndex(elapsed:)`, unit-tested in `OptionsLayoutTests.swift` at 320, 375, 390, 402 and 440 pt widths. `MainBackground` is the Editing background too.
- **Carousel persistence.** Writes only while the user drives the scroll (scroll phase interacting/decelerating, then a final write at idle), so the initial positioning never overwrites the stored value. VoiceOver adjusts with swipe up/down (`accessibilityAdjustableAction`); XCUITest on iOS has no increment/decrement, so that path has no UI test.
- **UI test helpers.** `SilentShoutUITests/OptionsScreen.swift`: `XCUIApplication.optionsApp(reset:)` adds `-UITestResetSettings` (handled in `SilentShoutApp.init`, DEBUG only, via `ShoutSettings.resetStoredOptions`), and `OptionsScreen` holds the queries (`carousel("font"|"texture"|"lettering")`, `value(of:)`, `bubble(_:)`, `helpButton`, `nextButton`, `waitForValue`). Accessibility ids: `options.carousel.<key>`, `options.help`, `options.next`, `options.help.bubble.<key>`. `testScreenshots` attaches `options` and `options-help`; export with `xcrun xcresulttool export attachments --path <xcresult> --output-path <dir>`.
- **Unit tests also build the UI test target** (the scheme builds all targets for `make test`), so UI test compile errors and warnings break `make test`.
- **Simulator.** The pool device is an iPhone 17 Pro on iOS 27.0 (deployment target is 26.0). A cold `make test-ui` took under a minute here. Result bundles land in `build/Logs/Test/`.
- **Sound.** PLAN phase 1 lists the sound file, but SPEC marks `swish.caf` as never played and the phase 1 brief said not to bundle it; it is not bundled (a unit test checks).
- **Version.** `MARKETING_VERSION` 2.0, build 1: a placeholder, like the bundle id.
