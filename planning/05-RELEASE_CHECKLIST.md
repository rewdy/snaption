# Snaption Release Checklist

Updated: 2026-02-20

## Release Metadata

- Target version (`MARKETING_VERSION`):
- Target build (`CURRENT_PROJECT_VERSION`):
- Release tag (`v<MARKETING_VERSION>`):
- Release date:
- Release owner:
- Distribution mode: `local` or `developer-id-notarized`

## Pre-Release

1. Confirm version/build values in Xcode project settings.
2. Confirm tag plan matches version exactly (`v<MARKETING_VERSION>`).
3. Ensure `.github/workflows/release.yml` will run from that tag.
4. Run unit tests:
- `xcodebuild test -project Snaption.xcodeproj -scheme Snaption -destination 'platform=macOS,arch=arm64' -only-testing:SnaptionTests`
5. Complete manual QA from `planning/04-QUALITY.md`.
6. Confirm no blocker issues in known issues list.

## Package

1. Local mode:
- `LOCAL_RELEASE=1 ./scripts/release_preflight.sh`
- `LOCAL_RELEASE=1 ./scripts/release_build_notarize.sh`
2. Developer ID + notarized mode:
- `./scripts/release_preflight.sh <notary-keychain-profile>`
- `NOTARY_PROFILE=<notary-keychain-profile> ./scripts/release_build_notarize.sh`
3. Tag release commit and push tag:
- `git tag v<MARKETING_VERSION>`
- `git push origin v<MARKETING_VERSION>`
4. Capture SHA-256 for `build/Snaption.zip`.

## Smoke Test

1. Fresh user account / clean machine:
- unzip artifact,
- launch app,
- open folder,
- navigate photos,
- edit notes/tags/labels and confirm sidecar autosave.
2. For notarized releases, confirm Gatekeeper allows launch without override.

## Publish

1. Fill `planning/08-RELEASE_NOTES_TEMPLATE.md`.
2. Publish artifact + checksum + release notes.
3. Record known issues and follow-up tickets.
