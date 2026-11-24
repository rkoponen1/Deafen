# Releasing Deafen

`release.sh` builds a release that opens on any Mac without Gatekeeper warnings:

1. Raises the version, archives the app and signs it with your **Developer ID** certificate.
2. Notarizes the app with Apple and staples the ticket.
3. Builds a DMG with an Applications shortcut, signs, notarizes and staples it.
4. Zips the app as well.
5. With `--publish`, commits and pushes the new version, tags `v<version>` and creates a GitHub release with the DMG and zip attached.

The files end up in `build/release/`.

## One-time setup

### 1. Developer ID certificate

Only the team's **Account Holder** can create one. On an individual membership, that's you.

- **In Xcode:** Settings → Accounts → select your Apple ID and team → **Manage Certificates…** → **+** → **Developer ID Application**.
- **Or on the web:** in Keychain Access choose Certificate Assistant → **Request a Certificate From a Certificate Authority…** → Saved to disk. Then on [developer.apple.com](https://developer.apple.com/account/resources/certificates/list) add a **Developer ID Application** certificate with that request, download it and import it on the **same Mac** (the private key lives there).

Check that it's installed:

```bash
security find-identity -v -p codesigning
```

The list should include `Developer ID Application: … (<team ID>)`.

### 2. Notarization credentials

Create an app-specific password at [account.apple.com](https://account.apple.com) → Sign-In and Security → App-Specific Passwords. Then save it to your keychain under the profile name `deafen-notary`:

```bash
xcrun notarytool store-credentials deafen-notary --apple-id <your Apple ID> --team-id <team ID>
```

The command asks for the password; nothing is stored in the repo. Your Apple ID is the email you sign in to developer.apple.com with.

### 3. GitHub CLI (for publishing)

Install the [GitHub CLI](https://cli.github.com) and sign in:

```bash
gh auth login
```

## Making a release

Commit and push your changes, then run:

```bash
./release.sh --publish
```

The script raises the last part of the version (1.0 → 1.0.1) and the build number, builds and notarizes, and only then commits the new version, pushes it and publishes. If anything fails along the way, the project file is put back as it was.

To choose the version yourself, pass it:

```bash
./release.sh --publish 1.1
```

Without `--publish` the script only builds the files with the project's current version, which is handy for testing.

Options are set with environment variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `NOTARY_PROFILE` | `deafen-notary` | Keychain profile from step 2 |
| `TEAM_ID` | the project's `DEVELOPMENT_TEAM` | Team to sign with |

## Redoing a release

Delete the GitHub release and its tag, delete the local tag, then publish the same version again by passing it explicitly:

```bash
gh release delete v1.0 --cleanup-tag --yes
```

```bash
git tag -d v1.0
```

```bash
./release.sh --publish 1.0
```

Anyone who already downloaded the old files keeps a working app, but the old download links stop working. If the release has been shared, raise the version instead.

## Troubleshooting

| Message | Fix |
| --- | --- |
| `This operation can only be performed by the account holder` | Only the Account Holder can create Developer ID certificates. Check that Xcode is signed in with the right Apple ID and team. |
| Error `-25294` when opening the `.cer` | macOS can't find the default keychain. Import into the login keychain: `security import <file>.cer -k ~/Library/Keychains/login.keychain-db` |
| `No Developer ID Application certificate for team …` | The certificate is missing, or it's for a different team, or it was imported on a Mac without the matching private key. |
| `Notarization profile 'deafen-notary' not found` | Run the `notarytool store-credentials` command from step 2. |
| `Notarization … failed` | The script prints Apple's log with the reason. |
