# Personal iPhone/iPad TestFlight build

This fork's iOS scheme is **SmartTube** (not the separate **Smart Tube** Apple TV scheme).

## Repository and safe updates

Public fork: https://github.com/burggraf/smarttubeios.

- `origin`: `burggraf/smarttubeios`, where personal work is pushed.
- `upstream`: `milika/SmartTubeIOS`, the actively maintained parent project.
- `original`: `ikeval/smarttubeios`, the original clone source (itself a fork).
- `personal/testflight`: personal release branch and the fork's default branch.
- `testflight-pre-upstream`: immutable pre-update recovery tag at `020b3e7`.
- `update/upstream-master`: separate integration of upstream `6bd85d3` (184 new commits).

Commit local work before any future update, then fetch and merge on a new branch:

```bash
git switch personal/testflight
git fetch upstream
git switch -c update/upstream-YYYYMMDD
git merge upstream/master
```

Resolve conflicts and verify the personal configuration, full test suite, and iOS
archive before promoting an update to `personal/testflight`. Do not use GitHub's
Sync fork action as a substitute for merging and checking the personal changes.
The upstream `master` branch on the fork is not the personal release branch.

To return to the personal release branch with a clean working tree:

```bash
git switch personal/testflight
```

The recovery tag also remains available if that branch advances later:

```bash
git switch -c recovery/testflight testflight-pre-upstream
```

Existing signed archives, IPAs, credentials, and raw logs remain local and ignored;
they are not part of the public backup. Deployment and test records below describe
the original 4.6 builds unless explicitly labeled as upstream-integration checks.

## Personal release identity

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

## Upstream integration release — 2026-10-30

Uploaded build: **5.6 (1793375185)**, based on upstream `6bd85d3` with the personal
signing identity, shared container, foreground sign-in fix, and disabled Firebase
reporting preserved. The new Home Screen widget shares the same personal app group.

- Fixed the upstream native-macOS window-ready callback and PNG snapshot compile errors.
- Fixed a disk-cache read-after-write race by reading on the existing serial write
  queue. The new regression failed before the fix, then all 10 disk-cache tests passed.
- Replaced timing guesses in the failing subscription/feed tests with readiness
  checks, serialized only the integration suites sharing the playback queue, and
  serialized the RSS fixture whose static routes were being overwritten concurrently.
- Corrected stale Shorts assertions to the existing native-controls/search contracts;
  added URL-builder parity and anonymous WEB request/TV OAuth separation checks.
  The legacy authenticated TV continuation assertions remain and were strengthened.
- Two complete `just test-unit` parallel runs each passed **991 tests in 145 suites**.
  Full raw output is retained in `DerivedData/UpstreamUpdate/release-parallel-{1,2}-raw.log`,
  before the upstream recipe's output truncation.
- Release configuration (2 tests), shell syntax, `just format-check`, `just secrets-check`,
  and `just doc-links` pass. `just` and SwiftLint were installed with operator approval.
- **CI is not fully green:** `just ci` stops at SwiftLint with **183 violations**;
  pristine upstream reports **175** with the same tool. The remaining differences
  include moved legacy fixture lines and changed size metrics, not a reset baseline.
  The operator explicitly approved documenting the existing lint debt without a
  repository-wide lint refactor. No rules, baseline, or security assertions were weakened.
- Signed archive/export succeeded. The exported IPA passed ZIP integrity, strict
  signatures, all four App Store identities/profiles/versions, iPhone/iPad support,
  app-group and iCloud entitlements, and absence of Firebase configuration.
- Simulator UI suites and real-device playback/sign-in for this new build are not
  verified; use TestFlight for device acceptance testing.

IPA: `DerivedData/TestFlight/export-1793375185/SmartTube.ipa`.
SHA-256: `b555e59ce59adebdeb13efad653f6645251e63ef24bfc85862d147103d471401`.
Raw initial failures, crash report, regression runs, CI output, and signed-build
logs are preserved locally in `DerivedData/UpstreamUpdate/` (gitignored).

Source: merge commit `4e4573c`, tagged `testflight-5.6-1793375185`.

Apple accepted the upload with **no errors** on 2026-10-30.
Delivery UUID: `4e4728d6-999b-4eb5-b9ae-ede2e92371df`.
The follow-up App Store Connect query confirms `is-on-app-store-connect: true`,
`build-status: VALID_BINARY`, iPhone/iPad support, and no non-exempt encryption.
Its import state is still `PROCESSING`; tester availability is not yet confirmed.
Upload and processing responses are retained locally alongside the build evidence.

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
