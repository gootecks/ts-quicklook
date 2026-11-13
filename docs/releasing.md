# Releasing

Merging a pull request into `main` starts `.github/workflows/release.yml`. When a `feat`, `fix` or breaking commit has landed since the last `v*` tag, the workflow:

1. Computes the next version with `cz bump --get-next`.
2. Moves the entries under `## [Unreleased]` in `CHANGELOG.md` into a new `## [X.Y.Z] - date` section (`scripts/release-notes.sh`) and keeps them as the release notes.
3. Runs `cz bump`, which sets `CFBundleShortVersionString` in both `Info.plist` files, commits `chore(release): vX.Y.Z` and tags `vX.Y.Z`.
4. Builds the app, signs it with the Developer ID certificate and the hardened runtime, notarizes and staples it (`scripts/notarize.sh`), and zips it.
5. Pushes the commit and tag together, then creates the GitHub Release with `TSQuickLook-X.Y.Z.zip` attached.

The build runs before the push, so a failed build or notarization leaves no tag behind. Without the signing secrets the release fails instead of publishing an unsigned build.

Preview the next version locally with `mise run release:preview`.

## Changelog

`CHANGELOG.md` is written by hand. Every commit adds its entry under `## [Unreleased]`; commitizen does not write the file.

## Signing secrets

The workflow reads five repository secrets (Settings, Secrets and variables, Actions):

| Secret                | Value                                                                     |
| --------------------- | ------------------------------------------------------------------------- |
| `MACOS_CERT_P12`      | Developer ID Application certificate with its private key, `.p12`, base64 |
| `MACOS_CERT_PASSWORD` | Password of that `.p12`                                                   |
| `APPLE_API_KEY_P8`    | App Store Connect API key, `.p8`, base64                                  |
| `APPLE_API_KEY_ID`    | Key ID of that API key                                                    |
| `APPLE_API_ISSUER`    | Issuer ID shown on the App Store Connect keys page                        |

To create them:

1. Developer ID certificate: only the account holder can create one. In Xcode, Settings, Accounts, select the team, Manage Certificates, **+**, Developer ID Application. Then in Keychain Access, export the certificate with its private key as a `.p12` with a password.
2. API key: App Store Connect, Users and Access, Integrations, Team Keys, **+**, access Developer. Download the `.p8` (it can be downloaded once) and note the key ID and issuer ID.
3. Upload:

   ```sh
   base64 -i DeveloperID.p12 | gh secret set MACOS_CERT_P12
   gh secret set MACOS_CERT_PASSWORD
   base64 -i AuthKey_XXXXXXXXXX.p8 | gh secret set APPLE_API_KEY_P8
   gh secret set APPLE_API_KEY_ID --body XXXXXXXXXX
   gh secret set APPLE_API_ISSUER --body 00000000-0000-0000-0000-000000000000
   ```

Keep the `.p12`, its password and the `.p8` in 1Password.

## Signing locally

```sh
SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" sh scripts/build.sh
NOTARY_PROFILE=tsquicklook scripts/notarize.sh build/TSQuickLook.app
```

Save the notary profile once with `xcrun notarytool store-credentials tsquicklook`. Without `SIGN_IDENTITY`, `scripts/build.sh` signs ad hoc.

## Requirements on `main`

- A tag matching `v*` must exist; `v0.1.0` marks the first version.
- `main` must accept pushes from `github-actions[bot]`. If branch protection requires pull requests or status checks, the push of the bump commit is rejected.
