#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo 'This build requires macOS with Xcode. On Windows, run the GitHub Actions workflow.' >&2
  exit 1
fi
if ! command -v xcodegen >/dev/null 2>&1; then
  echo 'Install XcodeGen first: brew install xcodegen' >&2
  exit 1
fi
xcodegen generate
xcodebuild -project DoseFlow.xcodeproj -scheme DoseFlow -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
APP='build/DerivedData/Build/Products/Release-iphoneos/DoseFlow.app'
test -f "$APP/DoseFlow"
test -d "$APP/PlugIns/DoseFlowWidgets.appex"
python3 scripts/verify-bundles.py "$APP"
mkdir -p build/ipa/Payload
# Preserve app resources and symlinks when packaging.
ditto "$APP" build/ipa/Payload/DoseFlow.app
rm -f build/DoseFlow-unsigned.ipa
(cd build/ipa && /usr/bin/zip -qry ../DoseFlow-unsigned.ipa Payload)
echo 'Created build/DoseFlow-unsigned.ipa — sign with your installation tool before installing.'
