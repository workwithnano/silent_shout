# Releasing Silent Shout

Silent Shout goes to internal TestFlight only. Nothing is submitted to App Review.

- Bundle id: `com.corduroying.silentshout`, registered in the developer account on 2026-11-28
  (resource id `9S2PP29NWY`, name "Silent Shout"; the API lists it as platform UNIVERSAL).
- Versions follow the Corduroying scheme, `YYYY.MM.PATCH` (patch from 0 within a month), as in
  Up There and Spud Bud. The first build is 2026.11.0 (1).
- Credentials live in `.env` at the repo root (gitignored, mode 600; `.env.example` lists the
  four variables). The team id is passed to xcodebuild on the command line and never written
  into `project.pbxproj`. The release targets redact every `.env` value from xcodebuild's
  output; full logs go to `build/release-logs/`.

## One time: create the app record (Nano, on the website)

The App Store Connect API cannot create an app record. In App Store Connect, Apps, "+",
New App:

| Field | Value |
|---|---|
| Platforms | iOS |
| Name | Silent Shout |
| Primary Language | English (U.S.) |
| Bundle ID | Silent Shout - com.corduroying.silentshout |
| SKU | `silentshout` |
| User Access | Full Access |

Then `make asc-app` should print the record's name, id and SKU.

## Each build

```
make bump-version   # only for a new release: next YYYY.MM.PATCH (skip for the first build)
make bump-build     # next build number; skip for the first upload (build 1)
git commit -am "Bump build to N"   # archive refuses an uncommitted tree
make upload         # check-asc, check-build-number, archive, then export and upload
```

`make upload` stops before archiving if the version and build number are already in App Store
Connect, and `make archive` refuses a dirty working tree. Signing is automatic: the API key lets
xcodebuild create the distribution certificate and profiles itself (`-allowProvisioningUpdates`).
`make archive` alone builds `build/SilentShout.xcarchive`; `make ipa` exports a store-signed
`build/export/SilentShout.ipa` without uploading.

After the upload, the build takes several minutes to process. Check it in App Store Connect,
Apps, Silent Shout, TestFlight (iOS builds), or with the API (`GET /v1/builds?filter[app]=<app id>`,
attribute `processingState`, which goes from `PROCESSING` to `VALID`). Because the app declares
`ITSAppUsesNonExemptEncryption = NO`, no export compliance question is asked. Then add the build
to an internal testing group in TestFlight (once, create the group and add testers).

Other targets: `make asc-bundle-id` (is the bundle id registered), `make asc-bundle-id-register`
(register it if missing), `make check-build-number`, `make bump-build-dry`, `make bump-version-dry`.

## Not automated, on purpose

- Store metadata: description, keywords, screenshots, privacy answers, age rating. TestFlight
  internal testing does not need them.
- App Review submission, external TestFlight (which needs Beta App Review), and release.
- Tags. No `tag-build` target yet.
