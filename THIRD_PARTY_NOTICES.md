# Third-party notices

What the Swift rewrite on this branch bundles or replaces that was not written for Silent
Shout. Nothing here has been checked by a lawyer; confirm each item before any release.

## Bundled fonts

The app bundles two font files, copied unchanged from `assets/Fonts/` into
`SilentShout/Fonts/` and listed in `UIAppFonts`.

### Kristi

- File: `SilentShout/Fonts/Kristi.ttf`, from `assets/Fonts/Dry Erase/Kristi.ttf` (the same file
  is in `assets/Fonts/Dry Erase/Kristi.zip`). Used for the Dry-Erase writing tool.
- Licence file: no licence file in the repository; confirm before release.
- The font's own name table says:

  > Copyright (c) 2010, Birgit Pulk (birgitpulk@gmail.com). All rights reserved. Licenced under SIL OFL v1.1

  and gives the licence URL `http://scripts.sil.org/OFL`. If that holds, the SIL Open Font
  Licence 1.1 text has to ship with the app.

### Later On

- File: `SilentShout/Fonts/later_on.ttf`, from `assets/Fonts/Pencil/later_on.ttf`. Used for the
  Pencil writing tool.
- Licence file: no licence file in the repository; confirm before release.
- The font's own name table says:

  > ©1999, Ace Fonts -- www.acefonts.com

## AutoScrollLabel

The 2011 app scrolled the message with `AutoScrollLabel` (`code/Classes/AutoScrollLabel.h` and
`.m` on the `1.0.1` branch). The rewrite's marquee (`MarqueeMotion` in
`SilentShout/Layout/ShoutLayout.swift`, drawn by `ShoutRenderer` and `MarqueeView`) replaces it
and was written from the behaviour described in `docs/rewrite/SPEC.md` section 6.3. No code from
AutoScrollLabel remains in this branch; the name appears only in comments that explain which
original behaviour a number reproduces.

Its origin, as the 1.0.1 sources record it:

- The original README credits it to Danny Baranowsky ("AutoScrollLabel" copyright 2009-2010
  Danny Baranowsky, offered license-free) and links to
  http://blog.stormyprods.com/2009/10/simple-scrolling-uilabel-for-iphone.html.
- The source file headers say "Created by Brian Stormont on 10/21/09", "Copyright 2009 Stormy
  Productions", and "Permission is granted to use this code free of charge for any project."

## Fonts in `assets/` that are not bundled

These sit in the source archive and are not in the app. Licence files are listed where the
repository has one.

| File | Licence file in the repository |
|---|---|
| `assets/Fonts/Highlighter/GraffitiPaintBrush.ttf` | none |
| `assets/Fonts/Ink and Quill/Scriptina/scriptina.ttf` | `Apostrophic Labs License.txt` (same folder) |
| `assets/Fonts/Ink and Quill/Scriptina/scriptina_alt.ttf` | `Apostrophic Labs License.txt` (same folder) |
| `assets/Fonts/Sharpie/Journal/journal.ttf` | `Freeware License.txt` (same folder) |
| `assets/Fonts/Paint Brush/Brushstroke-Plain/BRUSHSTP.ttf` | none |
| `assets/Fonts/_archive/DJ Gross/DJGROSS.ttf` | `SDFonts Font License.txt` (same folder) |
