#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
PRODUCT_NAME=HangulInputFixer
APP_NAME=dhxk
ARM_BUILD_PATH="$PROJECT_DIR/.build-arm64"
INTEL_BUILD_PATH="$PROJECT_DIR/.build-x86_64"
RELEASE_APP_PATH="$PROJECT_DIR/release/$APP_NAME.app"
# The project lives in iCloud Drive, which re-attaches FinderInfo/resource-fork
# metadata to bundles at unpredictable times. codesign rejects those attributes
# ("resource fork, Finder information, or similar detritus not allowed"), and it
# can happen after signing too, so the authoritative bundle is assembled, signed,
# verified and archived on local disk. release/ only receives copies.
STAGE_ROOT="/private/tmp/dhxk-universal-stage"
APP_PATH="$STAGE_ROOT/$APP_NAME.app"
SIGNING_IDENTITY=${SIGNING_IDENTITY:--}
BUNDLE_ID=${BUNDLE_ID:-local.hangul-input-fixer}
VERSION=${VERSION:-0.1.0}
BUILD_NUMBER=${BUILD_NUMBER:-1}
REGISTRATION_ENDPOINT=${REGISTRATION_ENDPOINT:-}
SKALA_REGISTRATION_REQUIRED=${SKALA_REGISTRATION_REQUIRED:-false}

if [[ ! "$VERSION" =~ ^[0-9]+([.][0-9]+){2}([.-][0-9A-Za-z.-]+)?$ ]]; then
    print -u2 "VERSION must be a semantic version such as 0.3.0."
    exit 1
fi
if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
    print -u2 "BUILD_NUMBER must contain digits only."
    exit 1
fi
if [[ ! "$BUNDLE_ID" =~ ^[A-Za-z0-9]+([.-][A-Za-z0-9]+)+$ ]]; then
    print -u2 "BUNDLE_ID must be a reverse-DNS identifier."
    exit 1
fi
if [[ "$SKALA_REGISTRATION_REQUIRED" == "true" && "$REGISTRATION_ENDPOINT" != https://* ]]; then
    print -u2 "SKALA build requires an HTTPS REGISTRATION_ENDPOINT."
    exit 1
fi

if [[ "$APP_PATH" != "/private/tmp/dhxk-universal-stage/dhxk.app" ]]; then
    print -u2 "Unexpected staging path: $APP_PATH"
    exit 1
fi
if [[ "$RELEASE_APP_PATH" != "$PROJECT_DIR/release/dhxk.app" ]]; then
    print -u2 "Unexpected release path: $RELEASE_APP_PATH"
    exit 1
fi

cd "$PROJECT_DIR"
mkdir -p .build/cache/clang .build/cache/swiftpm release "$STAGE_ROOT"

export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.build/cache/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_DIR/.build/cache/swiftpm"

swift build --disable-sandbox -c release --product "$PRODUCT_NAME" \
    --arch arm64 --build-path "$ARM_BUILD_PATH"
swift build --disable-sandbox -c release --product "$PRODUCT_NAME" \
    --arch x86_64 --build-path "$INTEL_BUILD_PATH"

rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp Resources/Info.plist "$APP_PATH/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP_PATH/Contents/Resources/AppIcon.icns"

/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :SKALARegistrationRequired $SKALA_REGISTRATION_REQUIRED" "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :SKALARegistrationEndpoint $REGISTRATION_ENDPOINT" "$APP_PATH/Contents/Info.plist"

lipo -create \
    "$ARM_BUILD_PATH/arm64-apple-macosx/release/$PRODUCT_NAME" \
    "$INTEL_BUILD_PATH/x86_64-apple-macosx/release/$PRODUCT_NAME" \
    -output "$APP_PATH/Contents/MacOS/$PRODUCT_NAME"
chmod +x "$APP_PATH/Contents/MacOS/$PRODUCT_NAME"

# iCloud/Finder may attach FinderInfo or resource-fork metadata while the bundle is
# assembled. Those attributes invalidate an otherwise correct Developer ID signature.
xattr -cr "$APP_PATH"

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    codesign --force --deep --sign - "$APP_PATH"
else
    codesign --force --deep --options runtime --timestamp \
        --sign "$SIGNING_IDENTITY" "$APP_PATH"
fi

plutil -lint "$APP_PATH/Contents/Info.plist"
lipo -info "$APP_PATH/Contents/MacOS/$PRODUCT_NAME"
lipo "$APP_PATH/Contents/MacOS/$PRODUCT_NAME" -verify_arch arm64 x86_64
codesign --verify --deep --strict --all-architectures --verbose=2 "$APP_PATH"
codesign -dv --verbose=4 "$APP_PATH" 2>&1 | grep -E 'Identifier=|Format=|flags=|Signature=|TeamIdentifier='
print "Created $APP_PATH"

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    if [[ "$SKALA_REGISTRATION_REQUIRED" == "true" ]]; then
        ARCHIVE_NAME="dhxk-$VERSION-skala-universal-adhoc.zip"
    else
        ARCHIVE_NAME="dhxk-$VERSION-universal-adhoc.zip"
    fi
    STAGED_ARCHIVE_PATH="$STAGE_ROOT/$ARCHIVE_NAME"
    ADHOC_ARCHIVE_PATH="$PROJECT_DIR/release/$ARCHIVE_NAME"

    # Archive from the clean staged bundle so no iCloud metadata is captured.
    rm -f "$STAGED_ARCHIVE_PATH" "$ADHOC_ARCHIVE_PATH" "$ADHOC_ARCHIVE_PATH.sha256"
    COPYFILE_DISABLE=1 ditto -c -k --keepParent --norsrc --noextattr "$APP_PATH" "$STAGED_ARCHIVE_PATH"
    cp "$STAGED_ARCHIVE_PATH" "$ADHOC_ARCHIVE_PATH"

    STAGED_SHA=$(shasum -a 256 "$STAGED_ARCHIVE_PATH" | cut -d' ' -f1)
    RELEASE_SHA=$(shasum -a 256 "$ADHOC_ARCHIVE_PATH" | cut -d' ' -f1)
    if [[ "$STAGED_SHA" != "$RELEASE_SHA" ]]; then
        print -u2 "Archive copy mismatch between staging and release."
        exit 1
    fi
    cd "$PROJECT_DIR/release"
    print "$RELEASE_SHA  $ARCHIVE_NAME" > "$ARCHIVE_NAME.sha256"

    # Convenience copy of the bundle; the staged copy stays authoritative.
    rm -rf "$RELEASE_APP_PATH"
    COPYFILE_DISABLE=1 ditto --norsrc --noextattr --noacl --noqtn "$APP_PATH" "$RELEASE_APP_PATH"

    print "Created $ADHOC_ARCHIVE_PATH (ad-hoc; Gatekeeper override required)"
    print "Created $ADHOC_ARCHIVE_PATH.sha256"
    print "Signed staging bundle: $APP_PATH"
fi
