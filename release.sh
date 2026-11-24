#!/bin/bash
#
# Builds, signs with Developer ID, notarizes and zips Deafen.
#
#   ./release.sh            build notarized Deafen-<version>.dmg and .zip in build/release
#   ./release.sh --publish  also tag v<version> and create a GitHub release with both
#
# One-time setup:
#   1. Create a "Developer ID Application" certificate (only the team's Account
#      Holder can): Xcode → Settings → Accounts → your team → Manage
#      Certificates, or developer.apple.com → Certificates with a signing
#      request from Keychain Access → Certificate Assistant.
#   2. Store notarization credentials in your keychain (asks for an
#      app-specific password from appleid.apple.com; nothing is saved in the repo):
#        xcrun notarytool store-credentials deafen-notary --apple-id <your Apple ID> --team-id <team ID>
#   3. For --publish: install the GitHub CLI and run `gh auth login`.
#
# Settings (environment variables):
#   NOTARY_PROFILE  keychain profile name from step 2 (default: deafen-notary)
#   TEAM_ID         developer team (default: DEVELOPMENT_TEAM from the project)

set -euo pipefail

PROJECT="Deafen.xcodeproj"
SCHEME="Deafen"
APP_NAME="Deafen"
NOTARY_PROFILE="${NOTARY_PROFILE:-deafen-notary}"

ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/build/release"
ARCHIVE="$OUT/$APP_NAME.xcarchive"
EXPORT_DIR="$OUT/export"
APP="$EXPORT_DIR/$APP_NAME.app"

PUBLISH=false
for arg in "$@"; do
    case "$arg" in
        --publish) PUBLISH=true ;;
        -h|--help) sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $arg (see --help)" >&2; exit 2 ;;
    esac
done

step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
fail() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

cd "$ROOT"

# --- Checks ----------------------------------------------------------------

step "Checking setup"
command -v xcodebuild >/dev/null || fail "xcodebuild not found. Install Xcode."
xcodebuild -version >/dev/null 2>&1 || fail "Xcode isn't selected. Run: sudo xcode-select -s /Applications/Xcode.app"

SETTINGS="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release -showBuildSettings 2>/dev/null)"
setting() { awk -F' = ' -v key="$1" '$1 ~ "^ *"key"$" { print $2; exit }' <<<"$SETTINGS"; }
VERSION="$(setting MARKETING_VERSION)"
TEAM_ID="${TEAM_ID:-$(setting DEVELOPMENT_TEAM)}"
[[ -n "$VERSION" ]] || fail "Couldn't read MARKETING_VERSION from the project."
[[ -n "$TEAM_ID" ]] || fail "No team set. Choose a Team under Signing & Capabilities, or set TEAM_ID."

IDENTITIES="$(security find-identity -v -p codesigning)"
SIGNING_IDENTITY="$(awk -v team="($TEAM_ID)" '/Developer ID Application/ && index($0, team) { print $2; exit }' <<<"$IDENTITIES")"
[[ -n "$SIGNING_IDENTITY" ]] \
    || fail "No Developer ID Application certificate for team $TEAM_ID in your keychain. Create one in Xcode → Settings → Accounts → Manage Certificates."
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
    || fail "Notarization profile '$NOTARY_PROFILE' not found or not working. Run: xcrun notarytool store-credentials $NOTARY_PROFILE --apple-id <Apple ID> --team-id $TEAM_ID"

TAG="v$VERSION"
if $PUBLISH; then
    command -v gh >/dev/null || fail "GitHub CLI (gh) not found. Install it, or run without --publish."
    gh auth status >/dev/null 2>&1 || fail "gh isn't signed in. Run: gh auth login"
    [[ -z "$(git status --porcelain)" ]] || fail "Uncommitted changes. Commit or stash them before publishing."
    git fetch --quiet --tags origin
    [[ "$(git rev-parse HEAD)" == "$(git rev-parse '@{u}' 2>/dev/null)" ]] \
        || fail "This branch isn't in sync with GitHub. Pull or push first."
    if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
        fail "Tag $TAG already exists. Raise MARKETING_VERSION in the project first."
    fi
fi

echo "Version $VERSION, team $TEAM_ID, notary profile $NOTARY_PROFILE"

# --- Build and sign --------------------------------------------------------

rm -rf "$OUT"
mkdir -p "$OUT"

step "Archiving"
xcodebuild archive \
    -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -archivePath "$ARCHIVE" \
    -destination "generic/platform=macOS" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    -allowProvisioningUpdates -quiet

step "Exporting with Developer ID"
cat >"$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
PLIST
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$OUT/ExportOptions.plist" \
    -allowProvisioningUpdates -quiet
[[ -d "$APP" ]] || fail "Export didn't produce $APP"

codesign --verify --deep --strict "$APP" || fail "Code signature check failed."
# Capture first: piping into `grep -q` can kill codesign with SIGPIPE, which pipefail reports as a failure.
SIGNATURE="$(codesign -dvv "$APP" 2>&1)"
if [[ "$SIGNATURE" != *"Authority=Developer ID Application"* ]]; then
    grep -E "Authority|TeamIdentifier|Signature" <<<"$SIGNATURE" >&2 || true
    fail "The app isn't signed with a Developer ID certificate (signing details above)."
fi

# --- Notarize --------------------------------------------------------------

# Uploads a .zip or .dmg for notarization and waits; prints Apple's log on failure.
notarize() {
    local file="$1" result="$OUT/notary-result.json" status submission
    xcrun notarytool submit "$file" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json >"$result" \
        || true
    status="$(plutil -extract status raw -o - "$result" 2>/dev/null || echo unknown)"
    if [[ "$status" != "Accepted" ]]; then
        submission="$(plutil -extract id raw -o - "$result" 2>/dev/null || true)"
        echo "Notarization status: $status" >&2
        if [[ -n "$submission" ]]; then
            xcrun notarytool log "$submission" --keychain-profile "$NOTARY_PROFILE" >&2 || true
        else
            cat "$result" >&2
        fi
        fail "Notarization of $(basename "$file") failed."
    fi
}

step "Notarizing the app (usually takes a few minutes)"
UPLOAD_ZIP="$OUT/upload.zip"
ditto -c -k --keepParent "$APP" "$UPLOAD_ZIP"
notarize "$UPLOAD_ZIP"
rm -f "$UPLOAD_ZIP"
xcrun stapler staple "$APP"
spctl --assess --type execute "$APP" || fail "Gatekeeper rejected the notarized app."

ZIP="$OUT/$APP_NAME-$VERSION.zip"
ditto -c -k --keepParent "$APP" "$ZIP"

# --- Disk image ------------------------------------------------------------

step "Building the disk image"
DMG="$OUT/$APP_NAME-$VERSION.dmg"
STAGING="$OUT/dmg"
mkdir -p "$STAGING"
ditto "$APP" "$STAGING/$APP_NAME.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov -quiet "$DMG"
rm -rf "$STAGING"
codesign --sign "$SIGNING_IDENTITY" --timestamp "$DMG"

step "Notarizing the disk image"
notarize "$DMG"
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature "$DMG" \
    || fail "Gatekeeper rejected the notarized disk image."

echo "Ready:"
echo "  $DMG"
echo "  $ZIP"

# --- Publish ---------------------------------------------------------------

if $PUBLISH; then
    step "Creating GitHub release $TAG"
    git tag "$TAG"
    git push --quiet origin "$TAG"
    gh release create "$TAG" "$DMG" "$ZIP" --title "$APP_NAME $VERSION" --generate-notes --verify-tag
    echo "Published: $(gh release view "$TAG" --json url --jq .url)"
else
    echo "Run again with --publish to create a GitHub release."
fi
