# Questions for Nano

None of these block the work; each has a default already applied.

1. Help button art: the app uses the set the 1.0.1 project references (`assets/Help Overlay/`). There is a redrawn set in `assets/Buttons/` that the project never referenced. Which did you and Anthony intend?
2. App icon: no art larger than the 2011 512 px `Icon-512.png` exists, so the app icon is that file scaled to 1024 px with `sips` (soft at full size, and no dark or tinted variants). Is there larger source art, or should the icon be redrawn before any release?
3. Launch screen: the default shows the original `poster_001` (320x480 pt) centred on a dark grey sampled from it, so tall screens show a plain band above and below. Keep, or use a plain colour only?
4. Options background on large screens: `bkgrnd_main` (320x461) was sized for one 320x460 screen and shows hard seams when repeated (an edge line along its top and bottom, unmatched left/right edges). The default trims the edge rows and tiles mirrored copies, keeping the art at its own size. Alternatives: plain repetition with seams, or one copy scaled to fill (soft, since it would be upscaled about 1.9x).
5. Options vertical spacing on tall screens: the three option blocks keep their original 139 pt size and are spread evenly over the height above the buttons (on an iPhone 17 Pro about 100 pt of extra space between blocks). The alternative is to keep them packed at the top as in the 320x460 original and leave the space above the buttons empty. See `docs/rewrite/screenshots/options.png`.
6. VoiceOver names for the options (the original had none): Pencil, Red dry-erase marker, Keyboard; Notecard, Whiteboard, Cardboard; "Scale your note", "Scroll your note" (the words the animations show). Change freely.
