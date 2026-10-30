#!/usr/bin/env bash
# Personal iPhone/iPad release; uses the same signing/upload flow as NuvioMobile.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
TEAM="${APPLE_TEAM_ID:-HEGN9W2S9J}"
BUILD="${IOS_BUILD_NUMBER:-$(date +%s)}"
UPLOAD=true
case "${1:-}" in
  --no-upload) UPLOAD=false ;;
  "") ;;
  *) echo 'Usage: scripts/testflight.sh [--no-upload]' >&2; exit 2 ;;
esac
[[ "$BUILD" =~ ^[0-9]+$ ]] || { echo 'IOS_BUILD_NUMBER must be numeric' >&2; exit 2; }
if [[ "$UPLOAD" == true ]]; then
  : "${APPLE_ID:?APPLE_ID is required}"
  UPLOAD_PASSWORD="${APPLE_APP_SPECIFIC_PASSWORD:-${APPLE_PASSWORD:-}}"
  [[ -n "$UPLOAD_PASSWORD" ]] || { echo 'Apple app-specific upload password is required' >&2; exit 1; }
fi
python3 scripts/test-release-config.py
RELEASE="$ROOT/DerivedData/TestFlight"
ARCHIVE="$RELEASE/SmartTube-$BUILD.xcarchive"
EXPORT="$RELEASE/export-$BUILD"
OPTIONS="$RELEASE/export-options-$BUILD.plist"
mkdir -p "$RELEASE"
python3 - "$OPTIONS" "$TEAM" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'wb') as f:
    plistlib.dump({'method': 'app-store-connect', 'signingStyle': 'automatic', 'teamID': sys.argv[2]}, f)
PY
xcodebuild -workspace SmartTube.xcworkspace -scheme SmartTube -jobs 2 \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath "$ROOT/DerivedData/Release" \
  -clonedSourcePackagesDirPath "$ROOT/DerivedData/SourcePackages" \
  -archivePath "$ARCHIVE" -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM" CURRENT_PROJECT_VERSION="$BUILD" archive
APP="$ARCHIVE/Products/Applications/SmartTube.app"
[[ -d "$APP" ]] || { echo 'Archive did not contain SmartTube.app' >&2; exit 1; }
codesign --verify --deep --strict "$APP"
python3 - "$APP" <<'PY'
import pathlib, plistlib, sys
app = pathlib.Path(sys.argv[1])
info = plistlib.loads((app / 'Info.plist').read_bytes())
assert info['CFBundleIdentifier'] == 'com.dmarie.smarttube'
assert info['UIDeviceFamily'] == [1, 2]
assert not (app / 'GoogleService-Info.plist').exists(), 'Firebase config must not ship'
for suffix, name in [('downloadwidget', 'SmartTubeDownloadWidget'), ('shareextension', 'SmartTubeShareExtension'), ('SafariExtension', 'SafariExtension')]:
    extension = app / 'PlugIns' / (name + '.appex')
    ext_info = plistlib.loads((extension / 'Info.plist').read_bytes())
    assert ext_info['CFBundleIdentifier'] == 'com.dmarie.smarttube.' + suffix
    assert ext_info['CFBundleVersion'] == info['CFBundleVersion']
    assert ext_info['CFBundleShortVersionString'] == info['CFBundleShortVersionString']
print('Verified archive identity, iPhone/iPad support, all three extensions, and no Firebase config')
PY
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT" \
  -exportOptionsPlist "$OPTIONS" -allowProvisioningUpdates
IPA="$EXPORT/SmartTube.ipa"
[[ -f "$IPA" ]] || { echo 'No exported IPA found' >&2; exit 1; }
echo "IPA: $IPA"
if [[ "$UPLOAD" == true ]]; then
  APPLE_UPLOAD_PASSWORD="$UPLOAD_PASSWORD" xcrun altool --upload-app -f "$IPA" \
    -u "$APPLE_ID" -p '@env:APPLE_UPLOAD_PASSWORD'
else
  echo 'Upload skipped (--no-upload)'
fi
