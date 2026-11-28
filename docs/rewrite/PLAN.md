# Silent Shout: Swift rewrite plan

Tracking issue: https://github.com/workwithnano/silent_shout/issues/3
Branch: `swift-rewrite` (based on `origin/1.0.1`). No pull request until Nano asks for one.

## Goal

Rewrite the 2011 Objective-C app as a modern Swift app with the same functionality, so it can
later ship through Corduroying as an homage to the original (only if Nano's former business
partner agrees; nothing here assumes that he has).

## Decisions (Nano, 2026-11-26)

| Topic | Decision |
|---|---|
| Baseline | The `1.0.1` branch: its cleaned-up button art, its export sheet, its camera texture entry. |
| Stubs | Finish the two things 1.0.1 left empty: "Send in iMessage" and the Camera background. |
| Look | Original 2011 artwork in a SwiftUI layout that fills current iPhones and respects safe areas. No upscaling of art, no letterboxed 320x480 frame. |
| Resume | State file on the branch plus a scheduled check-in that continues from it. |

## Decisions made by default (change them by editing this table)

| Topic | Default | Why |
|---|---|---|
| UI framework | SwiftUI, with UIKit only where SwiftUI has no equivalent (Messages composer, camera picker, orientation control) | Matches the other Corduroying apps. |
| Deployment target | iOS 26, iPhone only | Matches the other apps; the original was iPhone only. |
| Language mode | Swift 6, strict concurrency | Matches the other apps. |
| Project | `SilentShout.xcodeproj` at the repo root, sources in `SilentShout/`, tests in `SilentShoutTests/` and `SilentShoutUITests/`, file-system-synchronized groups so nobody hand-edits pbxproj file lists | Avoids the pbxproj ID collisions Up There had. |
| Tooling | A `Makefile` with `build`, `test`, `test-ui`, `clean`, using `~/Development/devtools/sim-lane.sh` the way `~/Development/upthere/Makefile` does | Shared simulator pool; one simulator job at a time. |
| Bundle id | `com.corduroying.silentshout` (decided by Nano 2026-11-28, registered in phase 8), no development team committed | The original id belonged to Multi-Touchy-Feely. |
| Old code | `code/` is deleted on this branch in phase 1 (it stays on `master` and `1.0.1`). `assets/` stays untouched as the source archive; the app uses copies in its asset catalog. | Keeps the archive intact and the app target clean. |
| Options offered | Exactly the options 1.0.1 offers. Unreachable fonts and the unoffered "swipe" sizing are not added. | "Same functionality". |
| Original quirks | Kept where a user could see them as part of the app's character; crashes and layout bugs are not reproduced. Anything doubtful goes in `QUESTIONS.md` rather than being guessed. | |

## Rulings on SPEC.md's open points

Numbers match the "Open points" list at the end of SPEC.md.

1. Phase 1 prints the registered font names at runtime and records the real ones in SPEC.md.
2. The shout is always shown in landscape. Starting it while the phone is upright (Done key)
   requests landscape for the scene, as the original forced it; rotating back to portrait leaves.
3. Both landscape directions show the shout upright.
4. The toolbar sits at the top inside the safe area. No status-bar shift of the marquee.
5. Fit geometry is computed in the original reference canvas (480x320 for the shout, the
   original preview box for the preview) and that canvas is scaled uniformly to fit the
   available area. The texture fills the whole screen behind it (aspect fill).
6. Use the help button art the 1.0.1 project references (`assets/Help Overlay/`). Logged in
   QUESTIONS.md for Nano.
7. Draw button art at the size the original displayed it; tap targets are at least 44 pt.
8. Export renders what is on screen, texture plus text, in both sizing modes (for the marquee,
   the text at its start position). This fixes the scroll-mode oversight, and Messages needs
   the same image.
9. Text is saved explicitly on every change of screen.
10. Carousel indexes are clamped to the valid range.
11. Accidental 1 pt and 3 pt offsets are not reproduced.
12. The hidden XIB button titles are used as accessibility labels only.
13. The marquee scrolls smoothly at 90 pt/s with the 20 pt gap; the restart jump is not reproduced.
14. Marquee text is vertically centred.

Camera entry: 1.0.1 never bundled its camera icon. Phase 5 uses the art in `assets/` if it
exists (commit bfd6c15 added temporary camera icons) and logs the choice in QUESTIONS.md.

## Source of truth

`docs/rewrite/SPEC.md` describes what the original does, element by element. Implementation
agents build from SPEC.md and may read the Objective-C with `git show origin/1.0.1:<path>`.
If SPEC.md and the original code disagree, the original code wins and SPEC.md gets corrected
in the same commit.

## How the work runs

- The main session plans, briefs, reviews, and runs the state file. All implementation is done
  by Opus subagents, **one at a time**, one phase per agent.
- Each phase ends with: `make build` and `make test` passing, a commit on `swift-rewrite`,
  a push, and the phase's row in `STATE.md` updated in that same commit.
- A phase that cannot finish records what is done and what is left in its `STATE.md` notes,
  commits and pushes the working part, and leaves its status as `in progress`.
- Simulator work goes through the Makefile only (the workspace has one shared simulator slot).
  Cap every `xcodebuild` run; it can hang after tests on Xcode 27.
- Questions for Nano go in `docs/rewrite/QUESTIONS.md`; they do not block a phase unless the
  phase cannot proceed without the answer.

## Phases

### 1. Scaffold
Xcode project, Makefile, `.gitignore`, asset catalog holding every image SPEC.md lists as
used (1x/2x as they exist), bundled fonts registered through Info.plist, sound file, app icon
from the original icon art, launch screen. Delete `code/`. A `ShoutSettings` model backed by
`UserDefaults` with the original keys, plus the font/texture/sizing enums and ink colours,
with unit tests. The app launches to a placeholder screen that proves fonts and textures load.

### 2. Options screen
The main screen: background, three option carousels (texture, sizing, font) with page
dots and persistence (not tilted: the -14 degree rotation is commented out in 1.0.1), the animated sizing options, the help overlay toggle, the next button.

### 3. Editing screen
The text field bar above the keyboard, the live fit-to-box preview on the chosen texture and
font, the toggle back to options, Done starting the shout, and rotating to landscape starting
the shout.

### 4. Shout screen
Landscape presentation. Fit-to-screen rendering with the multiply blend, scroll mode with the
marquee, tap to show or hide the toolbar, back and double-back, rotating to portrait returning
to editing. The fitting algorithm lives in a pure, unit-tested type shared with the preview.

### 5. 1.0.1 additions, finished
"Export Shout" sheet with Save to Camera Roll (add-only Photos permission) and Send in
iMessage (Messages composer with the rendered shout attached; hidden when the device cannot
send). Camera entry in the texture carousel: take or choose a photo and use it as the shout
and preview background. Usage strings in Info.plist.

### 6. Parity pass and wrap-up
UI tests for the main flow, a walk through SPEC.md section by section fixing gaps, screenshots
of each screen saved under `docs/rewrite/screenshots/`, README rewritten (what it is, how to
build, credits, the original legal notice kept), `THIRD_PARTY_NOTICES.md` for the fonts and
AutoScrollLabel's origin, final `QUESTIONS.md`.

## Before any release (not part of this branch's work)

- The former business partner's agreement. "Silent Shout" is noted in the README as a
  trademark of Multi-Touchy-Feely, LLC.
- Font licences: Kristi, Later On, Journal, Scriptina and Graffiti Paint Brush are freeware
  fonts with differing terms; check each allows bundling in a paid or free app.
- ~~A real bundle id~~ (decided 2026-11-28: `com.corduroying.silentshout`, registered), team (from `.env`, never committed), icon at current sizes, and a decision on iPad.

Found during the rewrite (phases 1 to 6):

- ~~The bundle id and version are placeholders.~~ Decided 2026-11-28: bundle id
  `com.corduroying.silentshout` (registered), versions `YYYY.MM.PATCH` starting at 2026.11.0 (1).
  See `docs/release.md`.
- The app icon is the 2011 512 px art scaled up to 1024 px (QUESTIONS Q2). It needs larger
  source art or a redraw, and dark and tinted variants.
- The deployment target is iOS 26, but only the iOS 27 simulator (iPhone 17 Pro, 402 pt wide)
  has ever run the app. Run it on iOS 26 before release.
- Layout at 375 pt and 440 pt widths (and 320 pt) is covered by unit tests of the layout types
  only; no UI test or screenshot has run at those widths.
- Everything under "Needs a real phone" in QUESTIONS.md: Messages, camera capture, the Photos
  permission and save, the photo picker, marquee smoothness, the exit transition, the screen
  staying awake, the home indicator, and a VoiceOver walk.
- Font licences: the bundled Kristi says SIL OFL 1.1 inside the font file and Later On says
  "©1999, Ace Fonts"; neither has a licence file in the repository (THIRD_PARTY_NOTICES.md).

## Resuming

Read `STATE.md`. Start at the first phase that is not `done`. If it is `in progress`, read its
notes and `git log --oneline -15` first, then brief one Opus subagent with the phase text
above, SPEC.md, and the notes. Never run two phases at once.
