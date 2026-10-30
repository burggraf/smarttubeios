# Personal iPhone/iPad TestFlight build

This fork's iOS scheme is **SmartTube** (not the separate **Smart Tube** Apple TV scheme).

- Apple Developer team: **Mantis Bible Company**, `HEGN9W2S9J`
- Bundle ID: `com.dmarie.smarttube`
- App Store Connect name: **SmartTube Personal**
- App Store Connect app ID: `6819357781`
- App group: `group.com.dmarie.smarttube`
- iCloud key-value store: `HEGN9W2S9J.com.dmarie.smarttube`
- Devices: iPhone and iPad, iOS/iPadOS 17 or later
- TestFlight: https://appstoreconnect.apple.com/apps/6819357781/testflight

The app, Share Extension, Safari Extension, and download Live Activity widget use
matching identifiers under the new bundle ID. Automatic signing manages their
provisioning profiles. The shared container is used by the app and Share Extension.

## Build and upload

Xcode must have this Apple Developer account signed in, and its signing identities
must be available in the macOS keychain. This uses the same automatic signing,
App Store Connect export, and `altool` upload flow as `../NuvioMobile`.

Provide `APPLE_ID` and `APPLE_APP_SPECIFIC_PASSWORD` (or the existing
`APPLE_PASSWORD`) through your local secure environment, **not** tracked files or
literal command arguments. `APPLE_TEAM_ID` defaults to `HEGN9W2S9J`.

```bash
python3 scripts/test-release-config.py
swift test --package-path SmartTubeIOS
scripts/testflight.sh
```

To archive/export without uploading:

```bash
scripts/testflight.sh --no-upload
```

`IOS_BUILD_NUMBER` can override the default Unix timestamp. Each upload must have a
new build number. Archives, export options, and IPAs are saved in the gitignored
`DerivedData/TestFlight/` directory.

## Firebase reporting is disabled

The iOS app does not configure Firebase, bundle a `GoogleService-Info.plist`, or run
the Crashlytics symbol-upload script. No Firebase project is needed for this personal
build. Firebase remains a declared upstream package dependency, but without a
configured Firebase app its Crashlytics instance is nil and reporting is inactive.
`CrashlyticsLoggerTests` exercises all diagnostic paths without configuration.
The separate Apple TV scheme is outside this iPhone/iPad release setup.

## Install

The internal **Internal Group** is configured for automatic distribution with the
same tester account as Nuvio. After Apple finishes processing an uploaded build,
accept the TestFlight invitation and install **SmartTube Personal** through Apple's
TestFlight app on both devices. Internal testing does not require external beta
review or a public App Store release. TestFlight builds expire after 90 days, so
rebuild/upload periodically to keep using the app.

## First upload

Version **4.6**, build **1791219516**, was accepted by Apple with no upload errors.
Delivery UUID: `ad8da6d7-5176-4fb7-94ef-6ae1f41697b3`.
Apple processing completed, the build was assigned to Internal Group with one
invitation, and the user confirmed installation and launch on an iPhone.

IPA: `DerivedData/TestFlight/export-1791219516/SmartTube.ipa`.
SHA-256: `d322a1de9053de7ecc55aa03f7fe70f291e0f82aa8ce4412bd512a320150c8f6`.
Raw build, export, upload, and full Swift-test logs are preserved in
`DerivedData/TestFlight/evidence-1791219516/` (gitignored).

Archive/export succeeded. IPA ZIP integrity, strict code signatures, App Store
profiles for the app and all three extensions, shared app-group entitlements,
iCloud key-value entitlement, and absence of Firebase configuration were verified.

## Same-device sign-in update

Build **4.6 (1791222212)** includes the foreground token-polling fix described below.
Its archive/export and strict IPA signatures were verified. IPA:
`DerivedData/TestFlight/export-1791222212/SmartTube.ipa`.
SHA-256: `88b6ec24b08ed14e4de65ace49b1e9ec09ad5896cdcd9f3a181b802b4a67ae2f`.
Apple accepted the upload with no errors; delivery UUID:
`38694b23-fc4c-4b28-9ecb-8d6e2b0eb9fc`. Processing completed; App Store Connect
shows this build as Ready to Submit, assigned to Internal Group with one invitation.

The new regression suite failed on the original code, then passed both tests after
the fix. `swift test --package-path SmartTubeIOS --no-parallel` ran 790 tests in 107
suites and reported the same three existing Shorts issues; both authentication
tests passed. A diagnostic run with `OS_ACTIVITY_MODE=disable` additionally failed
the existing log-capture assertion; the normal-logging rerun did not. Raw evidence
for all these runs is preserved in `DerivedData/TestFlight/evidence-1791222212/`.
The user initially reported a spinner after the Google browser approval, then
corrected that report and confirmed same-device sign-in works on the updated
TestFlight build. No additional authentication change was made. The task-retention
unit tests establish only that an active task is preserved; real-iPhone sign-in
verification comes from the user's confirmation, not simulator UI testing.

## Verification caveat

The existing full Swift suite currently has failures unrelated to the signing and
app-entry changes. A serial run (`swift test --package-path SmartTubeIOS --no-parallel`)
ran 788 tests and reported three issues: `ShortsEmbedURLTests` and
`ShortsEmbedJSTests` expect `controls=1` while the existing implementations use `0`;
`FEShortsClientRegressionTests` expects the removed TV FEshorts request while the
implementation now uses search. The default parallel run also reported timing/feed
failures (20 issues total). No assertions were weakened, and no playback/feed code
was changed to conceal these failures. These results are not a clean full-suite pass.

The iPhone/iPad UI verification attempts were interrupted after the iOS 27 simulator
launcher failed (`NSMachErrorDomain -308`, server died) and SpringBoard repeatedly
crashed. Both test jobs and an orphaned simulator diagnostic job were stopped;
the test simulators were confirmed shut down. The simulator UI suites are **not
verified**, and no further iOS 27 simulator retries are running. The user also
reported that Google approves device activation but token exchange fails in the
installed app. A subsequent check confirmed that activation succeeds when performed
on a second device while the iPhone stays in the foreground. The same-device fix
preserves the active token-polling task when returning from Safari, rather than
cancelling an exchange which may already have redeemed the device code. Regression
tests cover preserving an active poll and restarting an already-cancelled poll.
Google's “The codes don't match” text is a selectable mismatch-reporting link, not an
error message. Verify the displayed code and use Continue when it matches.
