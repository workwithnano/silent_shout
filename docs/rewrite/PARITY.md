# Parity with Silent Shout 1.0.1

Phase 6 walked `SPEC.md` section by section against the Swift code and, where the spec left
room for doubt, the Objective-C on `origin/1.0.1`. One row per behaviour.

Statuses:

- **same**: the rewrite does what 1.0.1 did (the mechanism may differ).
- **deliberate change**: the rewrite differs on purpose; the last column says where that was decided.
- **missing**: 1.0.1 did it and the rewrite does not.
- **not verifiable in simulator**: the code is there, but whether it matches can only be seen on a phone.

"Ruling n" is a numbered ruling in `PLAN.md` ("Rulings on SPEC.md's open points"); "Q n" is an
item in `QUESTIONS.md`; "PLAN defaults" is the table of decisions made by default in `PLAN.md`.

## 1. Screen map and navigation

| Behaviour | Status | Recorded in |
|---|---|---|
| Three screens (Options, Editing, Shout) in a navigation stack with the bar hidden, iPhone only | same | PLAN defaults (iOS 26, iPhone only) |
| Product name "Silent Shout"; bundle id `com.multitouchyfeely.sshout` | deliberate change | PLAN defaults (placeholder `com.corduroying.silentshout`) |
| Launch shows `poster_001`, then Options | deliberate change | Q3 (poster centred on a sampled colour) |
| Black opaque status bar on Options and Editing | deliberate change | PLAN decisions, "Look" (screens run under the status bar on current iPhones) |
| Next pushes Editing, animated | same | |
| Editing loads the saved text, renders the preview and raises the keyboard on arrival | same | |
| Done saves the text and starts the shout | same | |
| Turning the phone to either landscape on Editing saves the text and starts the shout | same | |
| A shout started by Done with the phone upright is still drawn in landscape (landscape right) | same | Ruling 2 |
| No second shout while one is up; the back button never starts one; nothing starts unless Editing is the visible screen | same | SPEC 2.2 rewrite note (no `flipScreen` flag needed) |
| Editing's back button saves the text and pops to Options | same | Ruling 9 (saved explicitly) |
| Shout back: dissolve to Editing, field reloaded from `text`, keyboard up | same | |
| Shout double-back: dismiss, then pop Editing, landing on Options | same | |
| Turning the phone upright leaves the shout | deliberate change | Ruling 2 and SPEC 1, "the exact leave rule" (leaves only after the phone has been in landscape since the shout started, so a Done-key shout is not dropped) |
| Turning between the two landscapes keeps the shout and turns it upright | same | Ruling 3 (system rotation instead of the hand-made 0.35 s transform) |
| Status bar back, portrait, after leaving the shout | same | |
| Upside down, face up and face down do nothing on any screen | same | |
| Every exit rotates to portrait first, then dissolves | deliberate change | Q13 (how it feels needs a phone) |
| Turning upright under the export sheet, an alert or the composer waits until it closes | deliberate change | SPEC 1 "While something is presented over the shout", Q20 |

## 2. Screens in detail

### 2.1 Options

| Behaviour | Status | Recorded in |
|---|---|---|
| `bkgrnd_main` as a repeating background | deliberate change | Q4 (edge rows trimmed, copies mirrored) |
| Three 139 pt option blocks, font, texture, lettering, top to bottom | same | |
| Spacing of the blocks on screens taller than 460 pt | deliberate change | Q5 (spread evenly; identical on 320x460) |
| Paging carousel per block, 200x100 art centred in a screen-wide page | same | PLAN decisions, "Look" (pages are as wide as the screen, as they were on 320 pt) |
| Lettering carousel at y 9 rather than 9.5 | deliberate change | Ruling 11 |
| Page dots, one per option, white, not tappable | same | |
| Carousels not tilted, no slide-in entrance | same | |
| Help button bottom left, Next bottom right, 48 pt art, 6 pt side and 5 pt bottom margins | same | Inside the safe area |
| Hidden XIB titles "Help" and "Shout" | same | Ruling 12 (accessibility labels only) |
| Help overlay never blocks touches | same | |
| Off-screen preview and text bar copies in `MainView.xib`, `showInfo:` | same | Not ported (never visible) |

### 2.2 Editing

| Behaviour | Status | Recorded in |
|---|---|---|
| Main background pattern behind the screen | same | Q4 (the same mirrored tile as Options) |
| Preview area: texture preview art with the text fitted in a 300x206 box | same | |
| Preview size and position on current screens | deliberate change | Q7, ruling 5 (lower 320x206 of the art, scaled to the width, centred above the bar) |
| 1 pt x offset of the preview | deliberate change | Ruling 11 |
| Text bar: `toolbar_Textfield` art, 41 pt, directly on the keyboard | same | |
| Back button: 33 pt art at (5.5, 3.5) | same | Ruling 7 (44 pt tap area) |
| Field background `textfield` | deliberate change | SPEC 2.2 rewrite note (end caps kept, middle stretched to the screen width; it was squeezed to 262 pt on 320) |
| Text field: Helvetica 15, black, clear button while editing, sentence capitals, autocorrection, dark keyboard, Done key | same | |
| Text field 31 pt tall | deliberate change | Ruling 11 (28 pt, the height of its background) |
| Disabled "BeginToType" button | same | Not ported (inert) |
| Every edit re-renders the preview | same | |
| Preview always fits the text to the box, whatever the presentation setting | same | |
| Texture and font of the preview are the saved ones | same | |
| Text saved when editing ends (Done, rotation, back) | same | Ruling 9 |
| Text also saved when the app leaves the foreground on Editing | deliberate change | Q8 |

### 2.3 Shout

| Behaviour | Status | Recorded in |
|---|---|---|
| 25% grey view background under the picture | same | |
| Background image fills the screen | deliberate change | Ruling 5 (aspect fill on the whole screen; the 480x320 canvas is scaled to fit) |
| Fit text drawn off screen in a 453x302 label and composited into one picture | same | |
| Marquee frame at y -20 | deliberate change | Ruling 14 (vertically centred) |
| Status bar hidden | same | |
| `lettering` 0 fits, 1 scrolls | same | |
| `lettering` 2 ("swipe") and unknown values | deliberate change | Ruling 10, SPEC 4 (clamped: 2 reads as scroll) |
| Unused "Swipe ScrollView" and web view | same | Not ported |
| Landscape only, both directions | same | Rulings 2 and 3 |
| Screen kept awake while the shout shows | deliberate change | Q9 (effect needs a phone) |
| Home indicator auto-hidden on the shout | deliberate change | SPEC 2.3 rewrite note (current iPhones only; effect needs a phone) |

## 3. The option carousels

| Behaviour | Status | Recorded in |
|---|---|---|
| Starts on the stored page | deliberate change | Q21 (starts there directly; 1.0.1 scrolled to it with an animation as the view loaded) |
| Selection switches at 50% of the way to the next page and is stored as the user scrolls | same | |
| Index clamped while over-scrolling | deliberate change | Ruling 10 |
| Page dots are not tappable | same | |
| No sound | same | |
| Fonts: Pencil, Dry-Erase, Keyboard, with their carousel art | same | |
| Textures: Notecard, Whiteboard (called "Postcard" in code), Cardboard | same | |
| Lettering: scale and scroll animations, 40 frames, 5 s a loop, forever | same | |
| Swipe option and postcard texture not offered | same | PLAN defaults, "Options offered" |
| VoiceOver: each carousel is one adjustable element with option names | deliberate change | Q6 (1.0.1 had no names) |

## 4. Persistence

| Behaviour | Status | Recorded in |
|---|---|---|
| `text` (String), `font`, `texture`, `lettering` (Integer) in standard UserDefaults, absent keys meaning 0 or no text | same | |
| Written at the time of change | same | Ruling 9 for `text` |
| Out-of-range stored indexes | deliberate change | Ruling 10, SPEC 4 (clamped to the nearest option) |
| `photoBackground` key and the stored photo file | deliberate change | PLAN decisions, "Stubs"; SPEC 4 |

## 5. Fonts

| Behaviour | Status | Recorded in |
|---|---|---|
| Pencil: Later On (`lateron`), black | same | |
| Dry-Erase: Kristi, `#E93232` | same | |
| Keyboard: Helvetica, black | same | |
| GraffitiPaintBrush, Journal and Scriptina bundled but unreachable | deliberate change | PLAN defaults, "Options offered" (not bundled) |

## 6. Rendering

| Behaviour | Status | Recorded in |
|---|---|---|
| 6.1 Preview fit: 200 pt down by 2 in a 300 pt wide box, fits at 206 pt or less, 12 pt if nothing fits | same | SPEC 6.1 (12, not 10, corrected in phase 3) |
| 6.1 Preview text plain over the texture, centred, wrapped, clipped | same | |
| 6.1 Preview drawn at the card's scale | deliberate change | Ruling 5 |
| 6.2 Shout fit: 360 pt down by 2 in a 420 pt box, fits at 280 pt, label 453x302 stretched to 480x320, multiplied | same | |
| 6.2 Label alpha 0.894 carried into the bitmap | same | As read from the source; SPEC 6.2 notes it was never compared with a running 2011 build |
| 6.2 Rendered at the device scale, canvas scaled to fit the screen | deliberate change | Ruling 5 (SPEC 6.2 asks for device scale) |
| 6.3 Marquee: one line, 180 pt, ink colour, alpha 0.75, normal blending | same | |
| 6.3 Text no wider than the marquee does not move and is centred | same | |
| 6.3 Marquee width on wide screens | deliberate change | Q12 (full screen width) |
| 6.3 90 pt/s, 20 pt gap, 200 pt lead-in | same | |
| 6.3 Jump back to the start at the end of each loop | deliberate change | Ruling 13 (seamless) |
| 6.3 Line vertically centred | deliberate change | Ruling 14 |
| 6.3 Not user-scrollable; taps pass through | same | |
| 6.3 Keeps moving with Reduce Motion on | deliberate change | Q11 (1.0.1 predates the setting) |
| 6.3 Smoothness and CPU cost of the marquee | not verifiable in simulator | |
| 6.4 Texture images for shout and preview | same | |

## 7. Shout screen chrome

| Behaviour | Status | Recorded in |
|---|---|---|
| Toolbar hidden when the shout appears | same | |
| A tap anywhere toggles the toolbar over 0.4 s | same | |
| Status bar fading in with the toolbar; marquee moving down 20 pt | deliberate change | Ruling 4 |
| Black 38 pt `UIToolbar` | deliberate change | Q10, ruling 4 (`toolbar_shoutoverlay`, 44 pt) |
| Double back, back, flexible space, share, in that order | same | |
| 38 pt button art in 33 pt buttons | deliberate change | Ruling 7 (art at 38 pt in 44 pt targets) |
| Buttons work only while the toolbar shows | same | |
| A tap on the bar between buttons toggles the toolbar | same | |
| XIB alpha 0.627 ignored; toolbar fully opaque | same | |

## 8. Help overlay

| Behaviour | Status | Recorded in |
|---|---|---|
| Help toggles the overlay with a 0.5 s fade and shows `btns_help_ACTIVE` while on | same | |
| Overlay never intercepts touches | same | |
| Three bubbles beside the art they point at | same | Q5 (they follow their blocks on tall screens) |
| `help_overlay.png` and the extra bubbles never shown | same | |
| Help button art set | deliberate change | Ruling 6, Q1 (the set the 1.0.1 project referenced) |

## 9. 1.0.1 additions

| Behaviour | Status | Recorded in |
|---|---|---|
| Share button opens "Export Shout" with Save to Camera Roll, Send in iMessage, Cancel | same | |
| Save to Camera Roll saves the shout | deliberate change | Ruling 8, Q14, Q19 (on-screen picture with text in both modes, PNG, add-only permission, feedback) |
| Real permission prompt and save to the photo library | not verifiable in simulator | UI tests use the fake saver |
| Send in iMessage (empty stub in 1.0.1) | deliberate change | PLAN decisions, "Stubs"; Q19, Q20 |
| Messages composer, sending, and dismissal back to the shout | not verifiable in simulator | The simulator cannot send, so the choice is hidden there |
| Camera entry after the last texture (unreachable in 1.0.1) | deliberate change | PLAN decisions, "Stubs", and its camera entry note; Q15 to Q18 |
| Camera capture and the system photo picker | not verifiable in simulator | UI tests use a drawn fixture photo |
| Redrawn 1.0.1 button art, new poster and icon art | same | |
| Dry-Erase uses Kristi | same | |

## 10. Asset inventory

| Behaviour | Status | Recorded in |
|---|---|---|
| Every image 1.0.1 displays, 1x and 2x files unchanged, under its original name | same | `BundleResourceTests` |
| App icon | deliberate change | Q2 (one 1024 px icon scaled up from the 512 px art) |
| Launch image | deliberate change | Q3 |
| `toolbar_shoutoverlay` used for the shout toolbar | deliberate change | Q10 |
| `icon-texture_camera` bundled | deliberate change | PLAN camera entry note, Q15 |
| `swish.caf` and the other unused assets not bundled | same | |

## 11. Dead code

| Behaviour | Status | Recorded in |
|---|---|---|
| Sound, slide-in, tilt, page-control taps, unused rendering helpers, swipe mode, unused XIB objects, CoreData and MediaPlayer, ad hoc leftovers | same | Not ported, as SPEC 11 lists |

## Totals

120 behaviours: 74 same, 42 deliberate changes, 0 missing, 4 not verifiable in simulator.

Nothing in scope was found missing. The walk led to two SPEC.md corrections (section 3, how the carousels start; section 9, the camera choices have no Cancel row) and one new default (Q21).
