# Questions for Nano

None of these blocks the work: each has a default already applied. Items keep the numbers they
had when they were first asked (other documents refer to them as Q1, Q2 and so on), so the
numbers are not in order below.

## Needs your decision

Things your taste decides. The default is what the app does now.

- **Q1. Help button art.** The app uses the set the 1.0.1 project referenced (`assets/Help Overlay/`); a redrawn set in `assets/Buttons/` was never referenced. Default: the referenced set. Which did you and Anthony intend?
- **Q2. App icon.** No art larger than the 2011 `Icon-512.png` exists, so the icon is that file scaled to 1024 px (soft at full size, no dark or tinted variants). Default: the upscaled icon until there is larger source art or a redraw.
- **Q3. Launch screen.** Default: the original `poster_001` (320x480 pt) centred on a dark grey sampled from it, which leaves a plain band above and below on tall screens. The alternative is a plain colour only.
- **Q4. Options background.** `bkgrnd_main` was made for one 320x460 screen and shows seams when repeated. Default: trim its edge rows and tile mirrored copies at the art's own size; the alternatives are plain repetition with seams, or one copy scaled up about 1.9x to fill.
- **Q5. Options spacing on tall screens.** Default: the three 139 pt blocks are spread evenly over the height above the buttons (about 100 pt between blocks on an iPhone 17 Pro). The alternative keeps them packed at the top as on the 320x460 original. See `screenshots/options.png`.
- **Q7. Editing preview size.** Default: the card shows the part of the texture the original showed (the lower 320x206 pt), scaled to the screen width (about 1.26x on an iPhone 17 Pro) and centred between the status bar and the text bar. Alternatives: keep it at 320 pt, push it up under the status bar, or down onto the text bar. See `screenshots/editing-short.png`.
- **Q10. Shout toolbar art.** The original drew the system black `UIToolbar` at 38 pt. Default: `toolbar_shoutoverlay`, a 480x44 black gradient that sat unused in `assets/Toolbars/`, stretched across the screen at 44 pt. The alternative is a plain black bar at 38 pt. See `screenshots/shout-toolbar.png`.
- **Q13. Exit transition.** Default: every exit rotates the app to portrait first and then dissolves the shout away, so Editing never shows laid out in landscape. The original dissolved straight from the landscape shout to portrait Editing, which needs a custom transition to match; worth judging on a phone.
- **Q15. Camera entry position and art.** In 1.0.1 the camera image sat beyond the scrollable width and could never be seen. Default: a round camera disc in the empty margin right of the cardboard, not a page and without a dot, cut from the 2011 art that was committed as "completely temporary/ugly". New camera art would be worth drawing. See `screenshots/options-camera.png`.
- **Q16. Showing the photo is in use.** Default: the carousel rests on the last texture, the textures are dimmed, no dot is lit, and the camera disc becomes a round thumbnail of the photo with a white ring; any swipe that settles on a texture, even back on the cardboard, switches back to it. See `screenshots/options-camera-photo.png`.
- **Q22. Art size.** Default: buttons, carousel art, help bubbles and bars are drawn at their original point size and never upscaled, as the plan says; the Editing preview card and the shout's 480x320 canvas scale with the screen (ruling 5), so their 2x art is upscaled a little on large phones. The alternative is to keep those two at their original size too and leave more of the background showing.

## Defaults applied, tell me if wrong

Behaviour choices where the default is probably right.

- **Q6. VoiceOver names.** The original had none. Default: Pencil, Red dry-erase marker, Keyboard; Notecard, Whiteboard, Cardboard; "Scale your note", "Scroll your note" (the words the animations show).
- **Q8. Saving the message.** Default: besides back, Done and rotating, the text is also saved when the app leaves the foreground on Editing, so it is not lost if the app is closed there. The original did not do this.
- **Q9. Screen kept awake on the shout.** Default: the screen does not dim or lock while the shout shows, and the setting is restored on leaving. The original let a held-up shout go dark.
- **Q11. Reduce Motion.** Default: the marquee keeps scrolling with Reduce Motion on, since stopping it would leave a long message unreadable. Falling back to fit mode is an option.
- **Q12. Marquee width.** Default: the marquee runs across the full screen width (about 696 reference points on an iPhone 17 Pro), entering at one edge and leaving at the other as it did on the 480 pt original; a message scrolls only when it is wider than that.
- **Q14. Save to Camera Roll feedback.** The original saved silently. Default: a "Saved to Photos" note for 2.5 s (also announced by VoiceOver), and an alert with a Settings button if photo access is refused. See `screenshots/shout-export-sheet.png`.
- **Q17. "Use Last Photo".** Default: offered when a photo is stored but not in use; only one photo is ever kept. Remove it if it adds clutter.
- **Q18. Preview on a photo.** Default: the photo fills the preview card with the text drawn plainly on top, as the preview always drew text; the shout multiplies the ink onto the photo as onto paper, so red ink on a dark photo is dim. See `editing-photo.png` and `shout-photo.png`.
- **Q19. Exported picture.** Default: PNG at the screen's full pixel size (2622x1206 on an iPhone 17 Pro), the same for Photos and Messages (attached as "Silent Shout.png"). JPEG would make smaller messages; PNG keeps the lettering sharp.
- **Q20. Turning upright under the export sheet.** Default: the shout stays while the sheet, an alert or the Messages composer is up, and leaves when it closes if the phone is upright by then. The composer is shown in landscape over the shout.
- **Q21. Carousel start.** 1.0.1 scrolled each carousel to its stored page with an animation as the screen loaded. Default: each carousel simply starts on its stored page.
- **Q23. AutoScrollLabel credit.** The 1.0.1 README credits AutoScrollLabel to Danny Baranowsky, but its source headers say "Created by Brian Stormont", "Copyright 2009 Stormy Productions", and the README's link is to blog.stormyprods.com. Default: the README keeps the original notice word for word and `THIRD_PARTY_NOTICES.md` records both.
- **Q24. Credits.** The repository supports two credits: Neil "Nano" Anderson wrote the code (file headers, commits), and Anthony Cafaro supplied the 1.0.1 button art (commits 525320d and 42c68f5). Default: the README says exactly that; tell me what else Anthony drew and it can say more.

## Needs a real phone

Gathered from every phase's notes. None of these can be seen in the simulator.

- Sending a shout in Messages: the composer, its orientation over the landscape shout, sending, cancelling, and the return to the shout (the simulator cannot send, so the choice is hidden there).
- The shout leaving when the composer is closed with the phone upright.
- Taking a photo with the camera.
- The Photos add-only permission prompt and an actual save to the library (UI tests use a fake saver).
- The system photo picker (UI tests use a drawn fixture photo).
- Marquee smoothness on a phone. Since phase 7 it is Core Animation layers moved by the render server, with no drawing in the app per frame (about 1% app CPU in the simulator, down from about 68%), but how smooth it looks on a ProMotion screen has not been seen.
- The exit transition frame by frame: rotation to portrait, then the dissolve (Q13).
- The screen staying awake while the shout shows (Q9).
- The home indicator hiding on the shout.
- A VoiceOver walk through all three screens (the labels and actions are covered by UI tests; how it feels to explore is not).
- The iOS 26 runtime: only the iOS 27 simulator has run the app.
