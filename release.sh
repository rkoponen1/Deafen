#!/bin/bash
#
# Builds, signs with Developer ID, notarizes and zips Deafen.
#
#   ./release.sh            build a notarized build/release/Deafen-<version>.zip
#   ./release.sh --publish  also tag v<version> and create a GitHub release
#
# One-time setup:
#   1. Sign in to Xcode with the Apple ID of your developer team, and create a
#      "Developer ID Application" certificate (Xcode → Settings → Accounts →
#      Manage Certificates).
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
        -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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

security find-identity -v -p codesigning | grep -q "Developer ID Application" \
    || fail "No Developer ID Application certificate in your keychain. Create one in Xcode → Settings → Accounts → Manage Certificates."
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
codesign -dvv "$APP" 2>&1 | grep -q "Authority=Developer ID Application" \
    || fail "The app isn't signed with a Developer ID certificate."

# --- Notarize --------------------------------------------------------------

step "Notarizing (usually takes a few minutes)"
UPLOAD_ZIP="$OUT/upload.zip"
ditto -c -k --keepParent "$APP" "$UPLOAD_ZIP"
RESULT="$OUT/notary-result.json"
xcrun notarytool submit "$UPLOAD_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json >"$RESULT" \
    || true
STATUS="$(plutil -extract status raw -o - "$RESULT" 2>/dev/null || echo unknown)"
if [[ "$STATUS" != "Accepted" ]]; then
    SUBMISSION_ID="$(plutil -extract id raw -o - "$RESULT" 2>/dev/null || true)"
    echo "Notarization status: $STATUS" >&2
    if [[ -n "$SUBMISSION_ID" ]]; then
        xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "$NOTARY_PROFILE" >&2 || true
    else
        cat "$RESULT" >&2
    fi
    fail "Notarization failed."
fi
rm -f "$UPLOAD_ZIP"

step "Stapling the notarization ticket"
xcrun stapler staple "$APP"
spctl --assess --type execute "$APP" || fail "Gatekeeper rejected the notarized app."

ZIP="$OUT/$APP_NAME-$VERSION.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "Ready: $ZIP"

# --- Publish ---------------------------------------------------------------

if $PUBLISH; then
    step "Creating GitHub release $TAG"
    git tag "$TAG"
    git push --quiet origin "$TAG"
    gh release create "$TAG" "$ZIP" --title "$APP_NAME $VERSION" --generate-notes --verify-tag
    echo "Published: $(gh release view "$TAG" --json url --jq .url)"
else
    echo "Run again with --publish to create a GitHub release."
fi
