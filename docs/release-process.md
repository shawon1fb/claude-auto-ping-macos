# Release Process

This project ships an **unsigned** build by default. Signing and notarization are
left to the maintainer and are optional for local use.

## 1. Version bump

- Update `MARKETING_VERSION` in `project.yml` (and re-run `xcodegen generate`).
- Add a new section to `CHANGELOG.md` and move items out of `[Unreleased]`.

## 2. Build

```bash
./Scripts/build-release.sh
# Output: build/ClaudeAutoPingMacos.app
```

## 3. (Optional) Sign with Developer ID

Requires an Apple Developer account and a "Developer ID Application" certificate.

```bash
codesign --force --options runtime --timestamp \
  --entitlements App/ClaudeAutoPingMacos.entitlements \
  --sign "Developer ID Application: YOUR NAME (TEAMID)" \
  build/ClaudeAutoPingMacos.app

codesign --verify --deep --strict --verbose=2 build/ClaudeAutoPingMacos.app
```

## 4. (Optional) Notarize

```bash
# Zip the app
ditto -c -k --keepParent build/ClaudeAutoPingMacos.app build/ClaudeAutoPingMacos.zip

# Submit for notarization (store credentials once with `notarytool store-credentials`)
xcrun notarytool submit build/ClaudeAutoPingMacos.zip \
  --keychain-profile "AC_NOTARY" --wait

# Staple the ticket
xcrun stapler staple build/ClaudeAutoPingMacos.app
```

## 5. Tag and release

```bash
git tag v0.1.0
git push origin v0.1.0
```

The `.github/workflows/release.yml` template builds on tag push. To attach signed,
notarized assets:

1. Add repository secrets for the certificate (`.p12` base64), its password, and
   notarization credentials.
2. Import the certificate in the workflow, sign and notarize, then upload the
   `.app` (zipped) or a `.dmg` as a release asset.

> The initial workflow intentionally does **not** require signing secrets so it
> runs on forks and pull requests.

## 6. GitHub release assets

- Attach `ClaudeAutoPingMacos.zip` (and optionally a `.dmg`).
- Paste the relevant `CHANGELOG.md` section into the release notes.
- Note clearly whether the build is signed/notarized so users know what Gatekeeper
  prompt to expect.
