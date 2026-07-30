#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
APP_PATH="$PROJECT_DIR/release/dhxk.app"
NOTARY_PROFILE=${NOTARY_PROFILE:-}

if [[ -z "$NOTARY_PROFILE" ]]; then
    print -u2 "Set NOTARY_PROFILE to the Keychain profile created by notarytool."
    exit 1
fi
if [[ ! -d "$APP_PATH" ]]; then
    print -u2 "Missing $APP_PATH. Run Scripts/build-universal.sh with a Developer ID identity first."
    exit 1
fi
SIGNATURE_INFO=$(codesign -dv --verbose=4 "$APP_PATH" 2>&1)
if [[ "$SIGNATURE_INFO" == *"Signature=adhoc"* ]]; then
    print -u2 "Refusing to notarize an ad-hoc signed app. Set SIGNING_IDENTITY to Developer ID Application."
    exit 1
fi
if [[ "$SIGNATURE_INFO" != *"Authority=Developer ID Application:"* ]]; then
    print -u2 "The app is not signed with a Developer ID Application certificate."
    exit 1
fi
if [[ "$SIGNATURE_INFO" != *"(runtime)"* ]]; then
    print -u2 "The app signature does not include Hardened Runtime."
    exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")
SUBMISSION_ZIP="$PROJECT_DIR/release/dhxk-$VERSION-notarize.zip"
FINAL_ZIP="$PROJECT_DIR/release/dhxk-$VERSION-universal.zip"

rm -f "$SUBMISSION_ZIP" "$FINAL_ZIP" "$FINAL_ZIP.sha256"
ditto -c -k --keepParent "$APP_PATH" "$SUBMISSION_ZIP"
xcrun notarytool submit "$SUBMISSION_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
spctl --assess --type execute --verbose=4 "$APP_PATH"

ditto -c -k --keepParent "$APP_PATH" "$FINAL_ZIP"
shasum -a 256 "$FINAL_ZIP" > "$FINAL_ZIP.sha256"
print "Created $FINAL_ZIP"
print "Created $FINAL_ZIP.sha256"
