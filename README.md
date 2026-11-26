# Silent Shout

Silent Shout is an iPhone app from 2011 for holding up a message. You type a few words and turn
the phone on its side, and the words fill the screen in the lettering and paper you chose, as a
sign someone across a room can read. A long message can run across the screen
as a marquee instead.

This branch, `swift-rewrite`, is a rewrite of the 2011 Objective-C app (the `1.0.1` branch) in
Swift and SwiftUI for current iPhones. It keeps the original artwork and behaviour, and finishes
the two things 1.0.1 left as stubs: sending the shout in Messages and using a photo as the
background. The original code stays on `master` and `1.0.1`.

## Building and testing

You need Xcode with the iOS 26 SDK or later and a clone of the workspace's `devtools`
repository beside this one (`~/Development/devtools`), because every simulator command goes
through its `sim-lane.sh`, which hands out the machine's one shared simulator. Set
`DEVTOOLS=<path>` if it lives elsewhere.

```
make build     # debug build for the simulator
make test      # unit tests (Swift Testing)
make test-ui   # UI tests (XCUITest); UI_ONLY=SilentShoutUITests/<Class> runs one class
make help      # every target
```

Results go to `build/`; test result bundles land in `build/Logs/Test/`.

To run on a phone, open `SilentShout.xcodeproj`, choose your own team under Signing &
Capabilities for the SilentShout target, and run. Keep that change local: no development team
is committed, and the bundle id `com.corduroying.silentshout` is a placeholder.

## Project layout

- `SilentShout/`: the app. `Views/` holds the three screens (Options, Editing, Shout) and their
  parts; `Layout/` the geometry and the text-fitting rule, as plain types the unit tests cover;
  `Rendering/` draws the shout for the screen and for export; `Model/` the stored settings and
  the photo background; `Navigation/` moves between screens and handles orientation; `Export/`
  saves to Photos and sends in Messages; `Debug/` holds the launch-argument hooks the UI tests
  use, compiled into debug builds only.
- `SilentShoutTests/`: unit tests, hosted in the app.
- `SilentShoutUITests/`: UI tests.
- `assets/`: the original 2011 artwork, fonts and sounds, kept as the source archive. The app
  uses copies in `SilentShout/Assets.xcassets` and `SilentShout/Fonts/`.
- `docs/rewrite/`: how the rewrite was done.

## The rewrite documents

- `docs/rewrite/PLAN.md`: the plan, Nano's decisions, rulings on the spec's open points, and
  what is still needed before any release.
- `docs/rewrite/SPEC.md`: what the 1.0.1 app does, element by element, with notes on where the
  rewrite differs.
- `docs/rewrite/PARITY.md`: the spec checked against the Swift code, behaviour by behaviour.
- `docs/rewrite/QUESTIONS.md`: open questions, each with the default applied, and what still
  needs a real phone.
- `docs/rewrite/STATE.md`: phase by phase progress and notes.
- `docs/rewrite/screenshots/`: one picture per screen and state.
- `THIRD_PARTY_NOTICES.md`: the bundled fonts and the origin of the original marquee.

## Credits

The original app was written by Neil "Nano" Anderson (the source file headers name Neil
Anderson; the commits are by Nano). The redrawn button art in 1.0.1 came from Anthony Cafaro,
as the commits that added it record. The source headers carry the copyrights of Nano LLC (2010)
and Multi-Touchy-Feely (2011).

## LEGAL STUFF

"Silent Shout" is a registered trademark of Multi-Touchy-Feely, LLC. "Silent Shout" copyright Multi-Touchy-Feely, LLC. "AutoScrollLabel" copyright 2009-2010 Danny Baranowsky. All trademarks and copyrights reserved.

We'll be open-sourcing this code in the near future. Until then, we offer absolutely no rights to the use of this code for commercial or non-commercial use. One exception is "AutoScrollLabel", [offered license-free from Danny Baranowsky](http://blog.stormyprods.com/2009/10/simple-scrolling-uilabel-for-iphone.html).

The Swift rewrite on this branch is unreleased, and nothing in it grants any rights to the Silent Shout name, its artwork or its code.
