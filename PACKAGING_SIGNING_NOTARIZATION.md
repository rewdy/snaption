# Snaption Packaging, Signing, and Notarization Plan

Updated: 2026-02-20

## Goal

Produce a direct-download macOS build that:
- launches without Gatekeeper warnings after notarization,
- is reproducible for each release,
- has a documented checklist for release day.

## Prerequisites

1. Apple Developer Program membership (Organization or Individual).
2. Developer ID certificates installed in login keychain:
- `Developer ID Application`
- `Developer ID Installer` (optional if shipping `.pkg`)
3. App bundle identifier locked (current: `com.rewdy.Snaption`).
4. Release version and build number updated in Xcode.

## Distribution Format (MVP Recommendation)

1. Primary: signed + notarized `.zip` containing `Snaption.app`.
2. Optional later: signed + notarized `.dmg` with drag-to-Applications UX.

## Local-Only Release Mode (No Apple Developer Account)

Use this to package builds for personal/internal testing before Developer ID setup.

1. Run preflight in local mode:
- `LOCAL_RELEASE=1 ./scripts/release_preflight.sh`
2. Build a local self-signed zip:
- `LOCAL_RELEASE=1 ./scripts/release_build_notarize.sh`
3. Optional explicit self-sign identity:
- `LOCAL_RELEASE=1 SELF_SIGN_IDENTITY="-" ./scripts/release_build_notarize.sh`

Notes:
- Local mode skips Developer ID and notarization checks.
- Gatekeeper warnings/blocking on other Macs are expected until Developer ID notarization is enabled.

## Automated Scripts

1. Preflight (checks signing identity, build settings, optional notary profile, runs tests):
- `./scripts/release_preflight.sh`
- `./scripts/release_preflight.sh <notary-keychain-profile>`
2. Build + package (+ optional notarize/staple):
- `NOTARY_PROFILE=<notary-keychain-profile> ./scripts/release_build_notarize.sh`
- Without notarization: `./scripts/release_build_notarize.sh`
3. Optional output overrides:
- `ARCHIVE_PATH=/path/to/Snaption.xcarchive EXPORT_DIR=/path/to/export ZIP_PATH=/path/to/Snaption.zip ./scripts/release_build_notarize.sh`
4. Optional Xcode path override:
- `DEVELOPER_DIR_PATH=/Applications/Xcode.app/Contents/Developer ./scripts/release_preflight.sh`

See also:
- `scripts/release_quickstart.md`
- `RELEASE_CHECKLIST.md`
- `RELEASE_NOTES_TEMPLATE.md`

## Build and Archive

1. Use Xcode `Archive` for `Snaption` scheme in `Release`.
2. Export `.app` using `Developer ID` signing.
3. Verify local signature:
- `codesign --verify --deep --strict --verbose=2 Snaption.app`
- `spctl --assess --type execute --verbose Snaption.app`

## Notarization Flow

1. Zip app for notarization upload:
- `ditto -c -k --keepParent Snaption.app Snaption.zip`
2. Submit:
- `xcrun notarytool submit Snaption.zip --keychain-profile <profile> --wait`
3. Staple ticket:
- `xcrun stapler staple Snaption.app`
4. Re-check Gatekeeper:
- `spctl --assess --type execute --verbose Snaption.app`

## Release Checklist

1. Run full `SnaptionTests` and pass.
2. Run manual QA checklist (`QA_CHECKLIST.md`) on medium + large datasets.
3. Build Release archive and export signed app.
4. Verify signature and hardened runtime.
5. Notarize, staple, and re-verify.
6. Smoke-test downloaded artifact on a clean macOS user account.
7. Publish release notes with:
- version/build
- checksum (SHA-256)
- known issues

## CI Automation (Post-MVP)

1. Add release workflow to:
- build Release
- run tests
- submit notarization
- attach notarized artifact to GitHub release
2. Store notarization credentials in CI secrets.
