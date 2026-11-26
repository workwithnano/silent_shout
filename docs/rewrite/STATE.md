# Rewrite state

Checkout: `~/Development/silent_shout`, branch `swift-rewrite`.
Read `PLAN.md` first. Resume at the first row that is not `done`.
Statuses: `todo`, `in progress`, `done`.

| # | Phase | Status | Commit | Notes |
|---|---|---|---|---|
| 0 | Plan and behaviour spec | done | | PLAN.md, SPEC.md, rulings on the spec's open points |
| 1 | Scaffold | done | | Project, Makefile, asset catalog (113 image sets), fonts, `ShoutSettings` + option enums, placeholder screen. `make build`, `make test` (29 tests / 55 runs) and `make test-ui` (1 test) pass. See Notes. |
| 2 | Options screen | todo | | |
| 3 | Editing screen | todo | | |
| 4 | Shout screen | todo | | |
| 5 | 1.0.1 additions, finished | todo | | |
| 6 | Parity pass and wrap-up | todo | | |

## Log

- 2026-11-26: branch created from `origin/1.0.1`, issue #3 opened, plan written.
- 2026-11-26: SPEC.md written; open points ruled on in PLAN.md. Phase 1 next.
- 2026-11-26: Phase 1 done. `code/` deleted. Later On registers as PostScript `lateron` (SPEC open point 1 closed). Phase 2 next.

## Notes for the next phases

- **Layout.** `SilentShout/` (app), `SilentShoutTests/` (Swift Testing, hosted in the app), `SilentShoutUITests/` (XCUITest) are file-system-synchronized groups: add files on disk, never edit pbxproj file lists. `SilentShout/Info.plist` is excluded from resources by an exception set; it holds only `UIAppFonts` and `UILaunchScreen`, the rest is generated from build settings (`INFOPLIST_KEY_*`).
- **Orientations.** The app target allows portrait and both landscapes (`INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone`); phases 2 to 4 restrict per screen.
- **Model.** `ShoutSettings` (`Model/ShoutSettings.swift`) writes to UserDefaults on every assignment. Phase 3 should keep the field's text in local state and assign `settings.text` on each screen change (ruling 9), not on every keystroke. The lettering setting is the `sizing` property (key `lettering`). Out-of-range stored values clamp to the nearest option (a stored lettering 2 reads as scroll); SPEC section 4 records this.
- **Names.** `ShoutFont.fontName` (`lateron`, `Kristi`, `Helvetica`), `.ink` (`InkColor`, `.color` / `.uiColor`), `.carouselImageName`; `ShoutTexture.shoutImageName` / `.previewImageName` / `.carouselImageName`, `ShoutTexture.cameraCarouselImageName`; `ShoutSizing.frameImageNames` (40 names) and `animationDuration` (5 s); `ChromeImage` holds every button, help bubble and toolbar asset name. Asset names are the original file names without extension.
- **Art sizes.** The preview textures' @2x files are 639x451 px (half a point short) and `bkgrnd_main@2x` is 640x921; size those by frame. Back/back2/doubleback/share are 38x38 pt art (ruling 7).
- **Placeholder.** `Views/PlaceholderView.swift` is phase 1 only; replace it in phase 2 (the UI smoke test looks for `placeholder.title` and `placeholder.font.N`, so update `LaunchSmokeTests` with it).
- **Simulator.** The pool device is an iPhone 17 Pro on iOS 27.0 (deployment target is 26.0). A cold `make test-ui` took under a minute here. Result bundles land in `build/Logs/Test/`.
- **Sound.** PLAN phase 1 lists the sound file, but SPEC marks `swish.caf` as never played and the phase 1 brief said not to bundle it; it is not bundled (a unit test checks).
- **Version.** `MARKETING_VERSION` 2.0, build 1: a placeholder, like the bundle id.
