# Silent Shout 1.0.1: behaviour spec for the Swift rewrite

This describes what the Objective-C app on the `1.0.1` branch does, read from the sources, the
XIBs and the Xcode project. It is the reference for the rewrite. Where the old app did something
only because of 2011 constraints (fixed 320x480 points, manual rotation transforms, 1x bitmaps),
the spec says what the behaviour was and the rewrite should reproduce the visible result, not the
mechanism.

All frames are in points in the original reference layout: portrait 320x480 with a 20 pt status
bar (content 320x460), landscape 480x320. "XIB" means the Interface Builder files under
`code/XIBs/`. Paths under `assets/` are relative to the repo root.

How the unfinished 1.0.1 features (iMessage, Camera) get finished is decided in the rewrite plan,
not here. Section 9 only records what exists.

## 1. Screen map and navigation

Three screens, in a `UINavigationController` with the navigation bar hidden. iPhone only,
deployment target iOS 4.0, product name "Silent Shout", bundle id `com.multitouchyfeely.sshout`.

| Screen | Original class / XIB | Orientation | Reached by |
|---|---|---|---|
| Options (main) | `MainViewController` / `MainView.xib` | Portrait only | App launch |
| Editing with live preview | `EditingViewController` / `PreviewView.xib` | Portrait only | Next button on Options (standard navigation push, animated) |
| Shout | `FlipsideViewController` / `FlipsideView.xib` | Landscape only (both ways) | Modal cross-dissolve over Editing |

Launch: launch image `poster_001.jpg`, status bar black opaque, then Options.

### Options to Editing

The Next button (bottom right) pushes Editing. On appearing, Editing loads the saved text into
the field, renders the preview, and makes the text field first responder, so the keyboard is
always up on this screen.

### Editing to Shout: two triggers

1. **Done key.** The return key is "Done". It resigns the text field. End-of-editing saves the
   field's text to `text` in UserDefaults, then starts the shout.
2. **Rotating the device to landscape** (either way) while on Editing. The device-orientation
   notification handler calls the same end-of-editing path directly (text saved, shout starts).
   The text field is not explicitly resigned in this path.

The shout is presented modally with a cross-dissolve. If started by Done while the phone is still
portrait, the shout is still drawn in landscape (status bar forced to landscape right); the user
is expected to turn the phone.

Guards:

- `shouting` (global BOOL in `EditingViewController`): set when the shout is presented, cleared
  when it is dismissed. While set, further Done/rotation events do not present a second shout.
- `flipScreen` (global BOOL in `TextfieldViewController`, default YES): the back button on the
  text bar sets it to NO before popping, so the end-of-editing that the pop causes saves the text
  but does **not** start a shout. It is reset to YES right after. Net rule: end of editing starts
  the shout unless it was caused by the back button.
- The shout is only started if the navigation controller still has a visible view controller.

### Editing back to Options

The back button at the left of the text bar pops to Options (animated). Text is saved on the way
out (end of editing fires as the field loses focus; see Open points 9).

### Leaving the Shout

| Action | Result |
|---|---|
| Back (one step) toolbar button | Dismiss with cross-dissolve to Editing; Editing re-runs its setup, so the field is reloaded from `text` and becomes first responder again (keyboard up). |
| Double-back toolbar button | Dismiss, then pop Editing: lands on Options. (Original: dismiss animated inside a 0.4 s animation block, pop in its completion.) |
| Rotate device to portrait | Same as Back (one step). |
| Rotate between landscape left and right | Shout stays up and rotates to match, 0.35 s ease-in-out. |

On leaving, the status bar is shown again, black opaque, portrait.

Portrait-upside-down, face up and face down do nothing on any screen.

The original's `didRotate:` on the shout left on **any** portrait notification. After the Done key
the phone is usually already upright, so that only worked because no notification arrives until
the phone moves.

**In the rewrite (phase 4): the exact leave rule** (`ShoutLeaveRule`, fed by
`AppNavigation.deviceOrientationDidChange`). The shout leaves on a device-orientation change to
portrait only after the phone has been seen in landscape (left or right) since this shout
started: either it was landscape when the shout started (the rotation trigger), or it has turned
to landscape since (the Done-key case, phone upright at the start). Face up, face down, upside
down and unknown neither leave nor reset that memory, and each shout starts the rule afresh. The
toolbar's back and double-back buttons leave at any time.

Every exit (back, double-back, rotating to portrait) sets the app back to portrait, waits for
that rotation to finish, then dissolves the shout away; double-back pops Editing once the dissolve
has finished, as the original popped in the dismissal's completion. Editing does not take the
keyboard back while the shout is on screen or while double-back is on its way to Options.

## 2. Screens in detail

### 2.1 Options (`MainView.xib`, content area 320x460 below the status bar)

Background: `bkgrnd_main.jpg` (320x461) as a repeating pattern colour.

Three stacked option blocks, each 320x139, clear background, each holding one horizontal paging
carousel and one page control:

| Block (top to bottom) | Block frame | Controller | Setting key |
|---|---|---|---|
| Writing tool (font) | (0, 0.5, 320, 139) | `FontSettingsViewController` | `font` |
| Background (texture) | (0, 139.5, 320, 139) | `TexturesSettingsViewController` | `texture` |
| Presentation (sizing) | (0, 278.5, 320, 139) | `LetteringSettingsViewController` | `lettering` |

Inside each block:

- Scroll view at (0, 9.5, 320, 100) (the lettering one is at y 9). Paging, clips, no scroll
  indicators, `canCancelContentTouches = NO`. One page is 320 wide.
- Each option is a 200x100 image centred in its page (x = (320 - 200) / 2 + page * 320, y = 0).
- Page control at (141, 98, 38, 36), standard white dots.

The carousels are **not** tilted. A -14 degree rotation helper exists but its call is commented
out ("No longer rotating!"). The slide-in entrance animation is also commented out. See section 11.

Bottom button strip `buttonsView` at (0, 415, 320, 44), clear background:

| Button | Frame in strip | Frame in content area | Images | Action |
|---|---|---|---|---|
| Help | (6, -8, 48, 48) | (6, 407, 48, 48) | normal `btns_help_UP`, highlighted `btns_help_DOWN`, selected `btns_help_ACTIVE` | `toggleHelp:` |
| Next | (266, -8, 48, 48) | (266, 407, 48, 48) | normal `btns_next_UP`, highlighted `btns_next_DOWN` | `showPreview:` (push Editing) |

The XIB also gives these buttons the titles "Help" and "Shout" (Helvetica-Bold 11 / 15). With a
48 pt image in a 48 pt button the titles are not visible; treat them as image-only buttons and use
the titles as accessibility labels.

Help overlay `helpView`: (0, 0, 320, 460), on top of everything, alpha 0, user interaction
disabled (touches pass through to the carousels and buttons). See section 8.

**In the rewrite (phase 2).** `OptionsLayout` computes these frames from the safe-area size.
All three carousels use y 9.5 (the lettering block's 9 is one of the half-point accidents of
PLAN ruling 11). The area above the buttons is split into three equal slots with a 139 pt block
centred in each, which reproduces the frames above exactly on a 320x460 area and spreads the
blocks evenly on taller screens; pages are screen-wide with the 200x100 art centred; the
buttons keep their 6 pt side and 5 pt bottom margins inside the safe area. The 320x461 background
does not tile cleanly (its top 1.5 pt and bottom 2 pt are an edge line, and its left and right
edges do not match), which never showed on a 320x460 screen; the rewrite trims those rows and
tiles mirrored copies (QUESTIONS.md).

Left over in the XIB and not part of the visible screen: a second copy of the preview view (at
y -246, off screen) and of the text bar (at y 461.5, off screen), with their own controller
objects. The text field there has an Editing-Did-End-On-Exit connection to a `showInfo:` action
that `MainViewController` does not implement. Do not port any of this.

### 2.2 Editing (`PreviewView.xib`)

Background: `bkgrnd_main.jpg` pattern, same as Options. Status bar visible.

Layout, in window coordinates (status bar included, 320x480):

| Element | Window frame | Notes |
|---|---|---|
| Preview area | (1, 0, 320, 226) | Sits under the status bar. Note the 1 pt x offset in the XIB (probably accidental). |
| Preview background image | fills the preview area (320x226) | Texture preview image for the current `texture` (section 6.4). |
| Preview label | (10, 20, 300, 206) inside the preview area | Centred, word wrap, unlimited lines, vertically centred, clips. Text and font from section 6.1. |
| Text bar | (0, 223.5, 320, 41) | Background `toolbar_Textfield` (320x41) pattern. Its bottom edge (264.5) meets the top of the 216 pt keyboard. |
| Back button | (5.5, 3.5, 33, 33) in the bar | normal `btns_back_UP`, highlighted and selected `btns_back_DOWN`. Pops to Options without shouting. |
| Field background image | (46, 6, 262, 28) in the bar | `textfield.png` (272x28 art). |
| Text field | (53, 6, 254, 31) in the bar | Helvetica 15, black text, clear button while editing, autocapitalise sentences, autocorrection on, dark ("alert") keyboard appearance, return key Done. |
| "BeginToType" button | (53, 6.5, 254, 31) in the bar | Disabled, no image, no action in this XIB. Inert. Do not port. |

Behaviour:

- On load and every time the screen is set up again (after returning from the shout): field text
  = saved `text`; preview rendered from it; field becomes first responder.
- Every edit (Editing Changed) re-renders the preview with the current field text.
- The preview **always** uses the fit-to-box rendering, whatever `lettering` is. An
  `AutoScrollLabel` exists in the preview view but its outlet is not connected, so the scrolling
  preview code never shows anything.
- The preview's texture and font are read from UserDefaults when the screen appears.
- Text is written to UserDefaults only when editing ends (Done, rotation to landscape, back).

**In the rewrite (phase 3).** `EditingView` (`Views/EditingView.swift`), laid out by
`EditingLayout` from the safe area above the keyboard:

- The text bar keeps its 41 pt height and original art at original point sizes and sits on the
  keyboard at full width. `toolbar_Textfield` tiles across it; the back button's 33 pt art is at
  (5.5, 3.5) with a 44 pt tap area; `textfield` keeps its 14 pt rounded ends and stretches between
  them from x 46 to 12 pt from the right (on the 320 pt original it was squeezed from 272 to
  262 pt); the field runs from x 53 to 13 pt from the right, 28 pt tall (ruling 11: not 31).
- The preview card shows what the original showed of the preview: the lower 320x206 pt of the
  320x226 art. The top 20 pt were under the opaque black status bar, and the art has a dark band
  there (straight on cardboard, curved on the notecard) for that reason. The label box is
  (10, 0, 300, 206) in that reference card. The card is scaled uniformly to the screen width (or
  less if the height above the bar is short) and centred between the safe-area top and the bar
  (QUESTIONS.md). The main background shows around it. The 1 pt x offset is not reproduced.
- The field is a `UITextField` (clear button while editing, Helvetica 15, black, sentence
  capitalisation, autocorrection, dark keyboard, Done). It is drawn in the light style because it
  sits on white art, so the clear button shows.
- Saving (ruling 9) is explicit: the text is written to `text` when the back button is tapped, when
  the shout starts (Done or rotation), and also when the app leaves the foreground while Editing
  shows (the original lost unsaved text if the app was killed there). Ending editing has no side
  effects, so the `flipScreen` flag is not needed: the back button saves and pops, Done and
  rotation save and call `AppNavigation.startShout()`.
- `shouting` is `AppNavigation.isShouting` plus `isShoutOnScreen` (true until the dismissal's
  dissolve has finished); no shout starts while either is set, or when Editing is not the top
  screen.
- Device orientation: `RootView` forwards `UIDevice.orientationDidChangeNotification` to
  `AppNavigation.deviceOrientation`; Editing starts the shout when it changes to either landscape
  (`ShoutOrientationRule`). The interface itself stays portrait.

### 2.3 Shout (`FlipsideView.xib`, 480x320 landscape, status bar hidden)

View background 25% white (dark grey), fully covered by the background image.

| Element | Frame | Notes |
|---|---|---|
| Background image view `bgImage` | (0, 0, 480, 320) | Scale to fill. Shows the texture, or in fit mode the composited texture + text image. |
| Fit label `outputLabel` | (9, 9, 453, 302) | Only used off screen as the source of the text bitmap (section 6.2). Never visible in the final state. |
| Marquee `textView` (`AutoScrollLabel`) | (0, -20, 480, 320) | Scroll mode only. |
| "Swipe ScrollView" | (4, -12, 462, 302) | A plain paging scroll view with no outlet connection. Unused. Do not port. |
| Toolbar | set in code to (0, 0, 480, 38) | Black bar style. Starts at alpha 0. Section 7. |

On load: status bar hidden; toolbar alpha 0; read `font`, `texture`, `lettering` and render:

| `lettering` | Mode |
|---|---|
| 0 (and any unknown value) | Fit words to screen (section 6.2) |
| 1 | Auto-scroll marquee, no touch interaction (section 6.3) |
| 2 | Same marquee with user interaction enabled ("swipe"). Not reachable: the carousel offers only 0 and 1. |

A web view outlet (`outputWebView`) is declared and never used.

**In the rewrite (phase 4).** `Views/ShoutView.swift` in a `ShoutHostingController`
(`Navigation/ShoutPresenter.swift`): landscape only (PLAN ruling 2), status bar hidden, home
indicator auto-hidden, screen kept awake while it shows (`isIdleTimerDisabled`, restored on exit;
the original did not do this, QUESTIONS.md). Started by rotating, it is presented upright for the
landscape the phone is in (device landscape left is interface landscape right and the other way
round) and the system follows the phone between the two landscapes (ruling 3); started by the
Done key with the phone upright, it is presented in interface landscape right, as the original
forced the status bar. The window's orientation mask and the shout's own supported orientations
are the same value (`OrientationLock.mask`), so they never disagree. Drawing is
`Rendering/ShoutRenderer.swift` (sections 6.2 and 6.3); geometry and marquee motion are
`Layout/ShoutLayout.swift`. The view's 25% grey is drawn under the background.

## 3. The option carousels

Common behaviour (`SettingsViewController`):

- On load, the page control gets one dot per option and the scroll view jumps (animated) to the
  page stored in UserDefaults for its key.
- While the user scrolls, the current page is recomputed on every scroll event as
  `floor((offsetX - pageWidth / 2) / pageWidth) + 1`, i.e. the selection switches when the
  carousel is 50% of the way to the next page. The page control is updated and the page index is
  written to UserDefaults immediately on every such event.
- The original does not clamp that index. The rewrite must clamp it to the valid option range.
- The page control's value-changed event is not connected in the XIB, so tapping the dots does not
  change the page. `changeSettingsPage:` exists but is unreachable.
- No sound is played (the swish call is commented out).

### Font ("writing tool"), key `font`

| Index | Name in code | Carousel image |
|---|---|---|
| 0 | Pencil | `icon-lettering_pencil` |
| 1 | Dry-Erase | `icon-lettering_reddryerase` |
| 2 | Keyboard | `icon-lettering_keyboard` |

### Texture ("background"), key `texture`

| Index | Name in code | Carousel image | Actual texture shown |
|---|---|---|---|
| 0 | Notecard | `icon-texture_notecard` | Notecard |
| 1 | "Postcard" | `icon-texture_whiteboard` | Whiteboard |
| 2 | Cardboard | `icon-texture_cardboard` | Cardboard |
| (3) | Camera | `icon-texture_camera` | 1.0.1 addition, not selectable; see section 9 |

Mismatch: option 1 is labelled "Postcard" in code but shows the whiteboard icon and produces the
whiteboard texture. The names are never shown to the user. Call it Whiteboard in the rewrite. The
real postcard texture (index 3 in the rendering switches, `bkgrd_texture-postcard`) is not offered.

### Presentation ("lettering"/sizing), key `lettering`

| Index | Name in code | Carousel image |
|---|---|---|
| 0 | Scale Message To Fit Screen | animation `scale_00000` ... `scale_00039` |
| 1 | Scroll Message Across Screen | animation `Scroll-Your-Note_00000` ... `Scroll-Your-Note_00039` |

Each is a 40-frame image sequence (frames 0 to 39, 200x100) played as a `UIImageView` animation:
5.0 s per loop (8 frames per second), repeating forever, always running. (A code comment says 150
images at 30 fps; the code loads 40.) Frame `scale_00040` is bundled but not used.

Index 2 "swipe" is handled by the shout screen but has no carousel entry; its
`Swipe-Your-Note_*` frames are bundled (1x only) and never loaded.

**The rewrite offers exactly what 1.0.1 offers:** fonts 0 to 2, textures 0 to 2, lettering 0 to 1.
(The Camera texture is covered by the plan, section 9.)

## 4. Persistence

`UserDefaults.standard`, written with `synchronize` at the time of change.

| Key | Type | Default when absent | Written when |
|---|---|---|---|
| `text` | String | absent (nil): field empty, shout shows the bare texture | Editing ends |
| `font` | Integer | 0 (Pencil) | Font carousel scrolls |
| `texture` | Integer | 0 (Notecard) | Texture carousel scrolls |
| `lettering` | Integer | 0 (Scale to fit) | Lettering carousel scrolls |

No defaults are registered; the zeros come from `integerForKey:`. Keep these key names and types
so the meaning of stored values is unchanged.

Rewrite (phase 1, `ShoutSettings`): out-of-range stored indexes are clamped to the nearest
offered option when read (PLAN ruling 10), so a stored `lettering` 2 ("swipe", the same marquee)
reads as scroll and a stored `font` 5 reads as Keyboard. This differs from the original's
fall-through cases (unknown `lettering` meant fit; unknown `font` meant the unbundled
"DJ Gross"), which no 1.0.1 UI could produce.

## 5. Fonts

`UIAppFonts` in Info.plist: `Kristi.ttf`, `GraffitiPaintBrush.ttf`, `journal.ttf`, `later_on.ttf`,
`scriptina.ttf`. All five are in the bundle; only two are reachable.

| `font` index | Constant | Font name passed to `UIFont` | File | Ink colour | Reachable |
|---|---|---|---|---|---|
| 0 | `FONT_PENCIL` | "Later On" | `assets/Fonts/Pencil/later_on.ttf` | `#000000` | Yes |
| 1 | `FONT_DRYERASE` | "Kristi" | `assets/Fonts/Dry Erase/Kristi.ttf` | `#E93232` | Yes |
| 2 | `FONT_KEYBOARD` | "Helvetica" (system) | none | `#000000` | Yes |
| 3 | `FONT_KEYBOARD` | "Helvetica" | none | `#000000` | No |
| 4 | `FONT_PENCIL` | "Later On" | | `#000000` | No |
| 5 | `FONT_MARKER` | "Journal" | `assets/Fonts/Sharpie/Journal/journal.ttf` | `#272720` | No |
| other | `FONT_PAINTBRUSH` | "DJ Gross" (not bundled) | `assets/Fonts/_archive/DJ Gross/DJGROSS.ttf` | `#A91515` | No |

Other constants: `FONT_HIGHLIGHTER` = "GraffitiPaintBrush", ink `#E7FF20`; `FONT_QUILL` =
"Scriptina", black. Neither is mapped to an index.

Name tables read from the files: Kristi, Journal, GraffitiPaintBrush and Scriptina have family =
full = PostScript name equal to the names above. `later_on.ttf` has an empty first name record
(Spotlight reports the family as "Later On").

**Registered names (confirmed at runtime, phase 1; Open points 1 resolved).** On iOS 26,
`later_on.ttf` registers family **"Later On"** with one font whose PostScript name is
**`lateron`**; `Kristi.ttf` registers family "Kristi" with PostScript name "Kristi". The rewrite
passes `lateron` and `Kristi` to `UIFont(name:size:)` (`ShoutFont.fontName`), and
`BundleResourceTests` asserts both resolve.

The rewrite bundles only `later_on.ttf` and `Kristi.ttf` (in `SilentShout/Fonts/`, listed in
`UIAppFonts`).

## 6. Rendering

### 6.1 Preview fit (Editing screen)

- Text: current field text. Font and colour: section 5 for the saved `font`.
- Start at 200 pt and step down by 2 pt (200, 198, ... 12). For each size, measure the text
  word-wrapped in a box 300 pt wide and unlimited height. Stop at the first size whose measured
  height is <= 206 pt. If none fits, the text is drawn at 12 pt: the loop
  (`for (i = 200; i > 10; i -= 2)`) sets the font at the top of each pass, so the font keeps
  the last size tried, 12, although the loop variable ends at 10. (Corrected in phase 3; this
  line used to say 10.)
- Draw in the 300x206 label: centred horizontally, vertically centred, word wrap, unlimited lines,
  clipped to the label. Text colour is the ink colour at full alpha.
- No blend mode: plain text over the preview texture.

**In the rewrite (phase 3).** `TextFitter` (`Layout/TextFitter.swift`) is this rule with its
numbers as parameters: `TextFitter.preview` (300 x 206 box, 200 down to 12 by 2) and
`TextFitter.shout` (420 x 280, 360 down to 12 by 2). It measures with
`NSString.boundingRect` (word wrap, `usesLineFragmentOrigin`, height rounded up), the modern
form of `sizeWithFont:constrainedToSize:lineBreakMode:`; a word wider than the box breaks
between characters, as UILabel draws it. Empty text returns the maximum size (nothing is drawn).
The preview draws the result in a `UILabel` (centred, word wrap, unlimited lines, clipped, as the
original), scaled with the preview card (PLAN ruling 5).

### 6.2 Shout fit (`lettering` 0)

- Text: saved `text`. Same loop with different numbers: start 360 pt, step 2, box 420 pt wide,
  fit when height <= 280 pt; text that never fits is drawn at 12 pt, the last size tried (the
  loop's `i > 10` bound; see 6.1).
- The label (453x302, centred, word wrap, unlimited lines, vertically centred, clipped, label
  alpha 0.894 in the XIB) is rendered to a bitmap of its own bounds with a transparent background.
- A 480x320 image is made: the texture drawn to fill, then the label bitmap drawn stretched to the
  full 480x320 with **multiply** blend, alpha 1.0. (So the text is scaled about 1.06x from the
  453x302 label, and darkens the texture like ink.)
- That image is shown in the full-screen background image view; the label itself is hidden.
- The original made these bitmaps at 1x scale. The rewrite should render at the device scale; the
  geometry above is in points.
- This composited image is what "Save to Camera Roll" saves (section 9).
- The label's alpha (0.894) is taken to be part of its bitmap (`renderInContext:` applying the
  layer's opacity), so black ink multiplies to about 11% of the texture rather than to black.
  This reading is not verified against a running 2011 build; the difference is slight.

**In the rewrite (phase 4).** `ShoutRenderer` draws the background aspect-filling the whole
screen, then the text with `TextFitter.shout`'s size in a real `UILabel` of 453x302 (so its line
breaks, vertical centring and clipping are UILabel's), scaled by 480/453 onto the 480x320
canvas, the canvas scaled uniformly to fit the screen and centred (PLAN ruling 5), composited
with multiply at alpha 0.894. The screen shows that image, rendered at the device scale for the
current screen size.

### 6.3 Shout scroll (`lettering` 1)

Background image view shows the plain texture. Over it, the marquee:

- One line of text, font size 180 pt, ink colour, whole marquee at alpha 0.75. Normal blending
  (no multiply).
- Marquee frame (0, -20, 480, 320); the text line is vertically centred in it.
- `AutoScrollLabel` parameters: direction left; speed 90 pt/s; gap between the two copies 20 pt;
  pause between loops 0 s; linear timing.
- If the text line is not wider than the marquee (480): no scrolling, one copy, centred
  horizontally.
- If wider: two copies of the text laid end to end with the 20 pt gap. Each loop starts with the
  content offset at -200 (the first copy's leading edge 200 pt in from the left edge of the
  screen), animates linearly to offset `textWidth + 20` over `textWidth / 90` seconds, then
  restarts immediately from -200. (Because the distance covered is `textWidth + 220` in
  `textWidth / 90` s, the real speed is slightly above 90 pt/s; and because the loop restarts at
  -200 rather than 0, there is a visible jump at each restart. Both are original behaviour.)
- Not user-scrollable (interaction disabled); taps pass through to toggle the toolbar.

**In the rewrite (phase 4)** (`MarqueeMotion`, `ShoutRenderer.drawMarquee`, `MarqueeView`):

- Numbers are reference points scaled with the canvas (`ShoutCanvas.scale`): 180 pt type,
  90 pt/s, 20 pt gap, 200 pt lead-in.
- The marquee spans the full screen width, as AutoScrollLabel spanned the full 480 pt screen,
  so its width in reference points is the screen width divided by the scale (about 696 on an
  iPhone 17 Pro). Text no wider than that does not move: one copy, centred, as AutoScrollLabel
  did (it scrolled only when the line was strictly wider than itself).
- Wider text starts with the first copy's leading edge 200 pt in from the left, as the
  original's first loop, and moves left at exactly 90 pt/s. Copies follow with a 20 pt gap, so
  after the lead-in the picture repeats every `textWidth + 20` points with no jump (PLAN ruling
  13).
- The line is vertically centred on the screen (ruling 14); the marquee does not move when the
  toolbar shows (ruling 4).
- The whole marquee is drawn at alpha 0.75 as one layer, so overlapping script glyphs do not
  darken each other.
- On screen a display link redraws the marquee at up to 60 fps. An export image (phase 5) draws
  it at time 0, the start position (PLAN ruling 8).
- Reduce Motion is not applied: the moving text is the content of this mode (QUESTIONS.md).

### 6.4 Texture images

| `texture` | Shout background (480x320) | Preview background (320x226) |
|---|---|---|
| 0 | `bkgrd_texture-notecards.jpg` | `bkgrd_texture-previewnotecard.jpg` |
| 1 | `bkgrd_texture-whiteboard.jpg` | `bkgrd_texture-previewwhiteboard.jpg` |
| 2 | `bkgrd_texture-cardboard.jpg` | `bkgrd_texture-previewcardboard.jpg` |
| 3 (unreachable) | `bkgrd_texture-postcard` (png) | `bkgrd_texture-previewpostcard` (png) |

## 7. Shout screen chrome

- The toolbar is invisible (alpha 0) when the shout appears; the status bar is hidden.
- A tap anywhere on the shout (not on a toolbar button) toggles the chrome over 0.4 s: toolbar
  alpha 0 to 1 and status bar fades in; tap again reverses it. The marquee frame moves down 20 pt
  when the chrome shows and back up when it hides.
- Toolbar: black style, 480x38 at the top. Items left to right:

| Item | Frame | Images | Action |
|---|---|---|---|
| Double back ("Back 2 Steps") | (12, 6, 33, 33) | normal `btns_doubleback_UP`, highlighted `btns_doubleback_DOWN` | `doubleBack:`: to Options |
| Back ("Back 1 Step") | (55, 6, 33, 33) | normal `btns_back2_UP`, highlighted `btns_back2_DOWN` | `back:`: to Editing |
| flexible space | | | |
| Share (1.0.1) | (435, 6, 33, 33) | normal `btns_share_UP`, highlighted `btns_share_DOWN` | `showExportOptions:` |

The 1.0.1 art for these three is 38x38 shown in 33x33 buttons (centred, unscaled).
Buttons are only tappable while the toolbar is visible in practice (alpha 0 views get no touches).

The XIB sets the toolbar's alpha to 0.627, but the code fades it between 0 and 1.0, so it shows
fully opaque.

**In the rewrite (phase 4).** A tap anywhere toggles the toolbar over 0.4 s (ease in-out); a tap
on the bar between its buttons toggles it too (UIToolbar passed such touches up the responder
chain). While hidden it is out of the view tree, so it takes no touches and VoiceOver does not
find it. It is 44 pt tall at the top of the screen (ruling 4; landscape has no top inset), its
background is `toolbar_shoutoverlay` (480x44, the black gradient 1.0.1 bundled but never used,
standing in for the 2011 black `UIToolbar`; QUESTIONS.md) stretched across the full width, and
its buttons sit inside the safe area so none is under the Dynamic Island or sensor housing:
double back then back at the leading end, 38 pt art centred in 44 pt targets (ruling 7), 6 pt
from the safe-area edge. A 44 pt slot at the trailing end is kept empty for phase 5's export
button. The status bar stays hidden when the toolbar shows (in landscape on current iPhones
there is none to show). VoiceOver reads the message as one element (label: the message; value:
"Scrolling" while the marquee moves), whose double-tap toggles the toolbar; the buttons read
"Back 2 Steps" and "Back 1 Step" with hints.

## 8. Help overlay (Options screen)

- The Help button toggles `helpView` between alpha 0 and alpha 1 with a 0.5 s fade, and sets the
  button's selected state (image `btns_help_ACTIVE`) while help is showing.
- The overlay never intercepts touches; the carousels and Next keep working under it.
- Visible content is three 103x45 bubbles, one per option block:

| Bubble image | Frame in the 320x460 content area | Points at |
|---|---|---|
| `help_bubble-writingtool` | (9, 20, 103, 45) | Font block |
| `help_bubble-background` | (8, 149, 103, 45) | Texture block |
| `help_bubble-presentation` | (8, 287, 103, 45) | Lettering block |

- Rewrite (phase 2): each bubble keeps its offset from the option art it points at (51 or
  52 pt left of the art's left edge, the original's 9 or 8 pt against art at x 60) and its y
  inside its block, so it follows the block on any screen size. VoiceOver reads the bubbles
  only while help is showing (labels "Writing Tool", "Background", "Presentation").
- The full-screen dimming image `help_overlay.png` (320x460) is in the overlay but marked hidden
  in the XIB, so it never shows.
- `help_bubble-font`, `help_bubble-sizing` and `help_bubble-next` are bundled and unused.

## 9. 1.0.1 additions, as they exist

**Export sheet.** The share toolbar button opens a `UIActionSheet`:

- Title: "Export Shout"
- "Save to Camera Roll": `UIImageWriteToSavedPhotosAlbum(bgImage.image, ...)` with no completion
  handling or feedback. In fit mode this is the composited 480x320 (1x) texture + text image. In
  scroll mode `bgImage` holds only the bare texture, so the saved picture has no text.
- "Send in iMessage": empty stub, does nothing.
- "Cancel".

**Camera texture.** `TexturesSettingsViewController` appends a fourth setting
(`"Camera"`, `icon-texture_camera`), then `addCameraButton` sets the page control back to
`count - 1` (3 dots) and shrinks the scroll content to 3 pages. The intent, per the comments, is a
camera button that sits after the last texture but is not a selectable page. As built it is
invisible: `icon-texture_camera.png` exists in `assets/Icons/Textures/` but is not in the Xcode
project's resources, and nothing handles a tap on it (the `touchesEnded` added to
`SettingsViewController` only logs "touched"). `scrollView.canCancelContentTouches = NO` was added
alongside.

**Art.** Redrawn `btns_back`, `btns_back2`, `btns_doubleback`, `btns_next`, `btns_share` (UP/DOWN,
1x and 2x); `btns_help_UP/DOWN/ACTIVE` added under `assets/Buttons/` (the project references the
copies in `assets/Help Overlay/`, see Open points 6); new launch poster and app icons; smaller
`bkgrd_texture-notecards.jpg`; `icon-texture_camera` added.

**Font.** Dry-Erase switched from GraffitiPaintBrush to Kristi.

## 10. Asset inventory

Used by the running app (each has an `@2x` sibling unless noted):

| Asset | Used where | Source path |
|---|---|---|
| `poster_001.jpg` | Launch image | `assets/App Startup/` |
| `Icon.png`, `Icon4.png`, `Icon-iPad.png`, `Icon-512.png` | App icon (57, 114, 72, 512 px) | `assets/Application Icons/` |
| `bkgrnd_main.jpg` | Options and Editing background pattern | `assets/Backgrounds/` |
| `bkgrd_texture-notecards.jpg`, `-whiteboard.jpg`, `-cardboard.jpg` | Shout background | `assets/Backgrounds/` |
| `bkgrd_texture-previewnotecard.jpg`, `-previewwhiteboard.jpg`, `-previewcardboard.jpg` | Editing preview background | `assets/Backgrounds/` |
| `icon-lettering_pencil`, `_reddryerase`, `_keyboard` (.png) | Font carousel | `assets/Icons/Fonts/` |
| `icon-texture_notecard`, `_whiteboard`, `_cardboard` (.png) | Texture carousel | `assets/Icons/Textures/` |
| `icon-texture_camera.png` | Intended camera entry (not bundled in 1.0.1) | `assets/Icons/Textures/` |
| `scale_00000` to `scale_00039` (.png) | Lettering carousel, option 0 | 1x: `assets/Icons/Sizing/Scale-Your-Note/PNG Sequence/`; 2x: `.../PNG Sequence@2x/` |
| `Scroll-Your-Note_00000` to `_00039` (.png) | Lettering carousel, option 1 | 1x: `assets/Icons/Sizing/Scroll-Your-Note/PNG Sequence/`; 2x: `.../PNG Sequence@2x/` |
| `btns_help_UP`, `_DOWN`, `_ACTIVE` | Help button | `assets/Help Overlay/` (project reference) and `assets/Buttons/` (1.0.1 redraw) |
| `btns_next_UP`, `_DOWN` | Next button | `assets/Buttons/` |
| `btns_back_UP`, `_DOWN` | Editing back button | `assets/Buttons/` |
| `btns_back2_UP`, `_DOWN` | Shout back | `assets/Buttons/` |
| `btns_doubleback_UP`, `_DOWN` | Shout double back | `assets/Buttons/` |
| `btns_share_UP`, `_DOWN` | Shout share | `assets/Buttons/` |
| `help_bubble-writingtool`, `-background`, `-presentation` | Help overlay | `assets/Help Overlay/` |
| `toolbar_Textfield.png` | Text bar background | `assets/Toolbars/` |
| `toolbar_shoutoverlay.png` | Shout toolbar background (rewrite only, phase 4; unused in 1.0.1) | `assets/Toolbars/` |
| `textfield.png` | Text field background | `assets/Toolbars/` |
| `later_on.ttf` | Pencil font | `assets/Fonts/Pencil/` |
| `Kristi.ttf` | Dry-Erase font | `assets/Fonts/Dry Erase/` |

**In the rewrite (phase 1).** Every image above is in `SilentShout/Assets.xcassets` under its
original name without the extension (for example `bkgrd_texture-notecards`, `scale_00000`,
`btns_help_UP`), with the original 1x and 2x files copied unchanged; the folders inside the
catalog are for tidiness only and do not namespace the names. The help button uses the
`assets/Help Overlay/` copies (PLAN ruling 6). `icon-texture_camera` is included for phase 5.
Two exceptions: the app icon is a single 1024 px `AppIcon` scaled up from `Icon-512.png`
(no larger art exists), and the launch screen is `UILaunchScreen` in Info.plist showing
`poster_001` on a `LaunchBackground` colour sampled from the poster. The three preview texture
@2x files are 639x451 px (319.5x225.5 pt at 2x) and `bkgrnd_main@2x.jpg` is 640x921 against a
320x461 1x; layouts should size those by their frame, not the image's intrinsic size.

Bundled in 1.0.1 but never displayed (do not import unless the plan says so):

| Asset | Why unused |
|---|---|
| `help_overlay.png` | Hidden in XIB |
| `help_bubble-font`, `-sizing`, `-next` | Not placed in any XIB |
| `toolbar_Buttons.png` | Pattern call commented out |
| `bkgrd_texture-postcard.png`, `-previewpostcard.png` | Texture 3 not offered |
| `bkgrd_texture-notecards.png`, `-previewnotecard.png` | Code uses the .jpg |
| `icon-texture_postcard`, `icon-lettering_highlighter`, `icon-lettering_marker` | Not in any carousel |
| `scale.png`, `scroll.png`, `swipe.png` (`assets/Icons/Sizing/Flat/`) | Static versions, replaced by the animations |
| `scale_00040`, `Swipe-Your-Note_*` | Extra frame; swipe option not offered |
| `GraffitiPaintBrush.ttf`, `journal.ttf`, `scriptina.ttf` | Fonts not reachable |
| `swish.caf` | Sound never played |
| `iTunesArtwork` (`code/`) | Old ad hoc distribution artwork |

Unused archives in `assets/` (not in the project at all): `Buttons/_archive/`,
`Icons/Fonts/_archive/`, `Icons/Textures/_archive/`, `Fonts/_archive/`,
`Fonts/Paint Brush/`, `Fonts/Ink and Quill/Scriptina/scriptina_alt.ttf`, `Fonts/Dry Erase/Kristi.zip`,
`Beta Applications Icons/`, `Buttons/btns_brightness_*`, `Toolbars/toolbar_shoutoverlay*` (used
by the rewrite's shout toolbar since phase 4),
`Help Overlay/help-overlay-reference.jpg`, `Sound Effects/swish.mp3`, the `.mov`/source files
beside each PNG sequence, the `.svn` folders, and the cardboard `.png` duplicates of the `.jpg`
textures. The `PNG Sequence@2x` folders hold 3 files per frame (`name_NNNNN@2x.png` plus misnamed
`name@2x_NNNNN.png` and `name@2x_NNNNN@2x.png`); only `name_NNNNN@2x.png` is the real 2x frame.

## 11. Dead code and unused things

| Thing | State | Port? |
|---|---|---|
| `Sound` class, `swish.caf` (and references to `click.aif`, `error.aif`, which do not exist) | The only call is commented out | No |
| `slideSettingsViewIn` (carousels fly in from the top right) | Call commented out | No |
| `slightlyRotateScrollViewAndPageControl` (-14 degree tilt) | Call commented out | No |
| `changeSettingsPage:` (page-control taps) | Reachable in code, not connected in the XIB | No |
| `addTextToImage:withText:withFont:withFontSize:` in the shout | Never called | No |
| `autoScrollWithText:` (shout and preview), preview `scrollWordsOnScreen:`, `beginPreviewWithSizingMethod:` | Never called, or target outlet not connected | No |
| `setPreviewBackground` in the text bar controller | All branches commented out | No |
| Lettering index 2 "swipe" branch | Reachable only with a stored value the UI cannot produce | No |
| Font indices 3 to 5 and default, texture index 3 | Same | No |
| `outputWebView`, `swipeView`, "Swipe ScrollView" in the shout XIB | Declared or placed, never used | No |
| Preview/text-bar copies inside `MainView.xib`; `SettingsView.xib` | Not loaded into the visible UI | No |
| `editingViewControllerDidFinish:` delegate method | Never called | No |
| `timerIsActivated`, `isAnimating`, the animation distance/duration constants in the text bar controller | Unused variables | No |
| CoreData and MediaPlayer frameworks | Linked, unused | No |
| `Entitlements.plist`, `iTunesArtwork` | 2011 ad hoc distribution leftovers | No |
| Manual view transforms and `setStatusBarOrientation` calls for rotation | Mechanism only | Reproduce the result with modern orientation handling |

## Open points

1. **"Later On" font name.** Resolved in phase 1: family "Later On", PostScript name `lateron`
   (section 5).
2. **Shout orientation after pressing Done in portrait.** The original forced the status bar to
   landscape right and showed the landscape layout while the phone was still upright. On current
   iOS the equivalent is a landscape-only screen that the system rotates; whether to request
   landscape right specifically in that case is a plan decision.
3. **Mapping of device landscape left/right to the drawn rotation.** The original rotated the view
   by +90 degrees for device landscape left and -90 for landscape right by hand. Modern
   auto-rotation gives the upright result in both; assume that is the intent.
4. **Toolbar and marquee geometry on tall screens.** The 20 pt marquee shift and the 38 pt toolbar
   are tied to the old status bar. How the chrome sits relative to safe areas is a layout decision.
5. **Fit-mode geometry on larger screens.** The numbers (420x280 box inside a 453x302 label
   stretched to 480x320, max 360 pt; 300x206 preview, max 200 pt) are for a 480x320 canvas. The
   plan must say whether to scale the canvas up proportionally (keeping the same line breaks and
   relative size) or recompute in real points.
6. **Two sets of help button art.** The project references `assets/Help Overlay/btns_help_*`;
   1.0.1 added redrawn `assets/Buttons/btns_help_*` that the project does not reference. The
   redrawn set looks like the intended one, but that is a guess.
7. **Back/double-back/share art is 38x38 in 33x33 buttons.** Unknown whether the overflow was
   intended; drawing them at their natural 38 pt is the safe reading.
8. **Save to Camera Roll in scroll mode** saves the texture with no text. Probably an oversight,
   not a feature; the plan should say what export does in scroll mode.
9. **Text saved on back.** Saving when leaving Editing with the back button relies on UIKit ending
   editing as the screen is popped. The rewrite should save explicitly.
10. **Carousel index while over-scrolling** is unclamped in the original and can momentarily store
    -1 or the option count. Clamp.
11. **Preview area x offset of 1 pt** and the text field being 3 pt taller than its background
    image look accidental; not worth reproducing exactly.
12. **Button titles "Help" / "Shout"** exist in the XIB under the images. Assumed not visible.
13. **Marquee restart jump and effective speed** (section 6.3) are original quirks. Reproduce or
    smooth is a plan decision; the spec records the original numbers.
14. **Marquee vertical position.** The 320-tall marquee is placed at y -20 and its text centred in
    it, so the text sits about 20 pt above screen centre until the chrome is shown. Likely a
    status-bar compensation, not a design choice.
