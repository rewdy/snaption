# Release Quickstart

Updated: 2026-02-20

## Local Release (No Apple Developer Account)

1. Run preflight:
- `LOCAL_RELEASE=1 ./scripts/release_preflight.sh`
2. Build self-signed zip:
- `LOCAL_RELEASE=1 ./scripts/release_build_notarize.sh`
3. Artifact:
- `build/Snaption.zip`

## Developer ID + Notarized Release (Later)

1. Validate signing + notary profile:
- `./scripts/release_preflight.sh <notary-keychain-profile>`
2. Build + notarize + staple:
- `NOTARY_PROFILE=<notary-keychain-profile> ./scripts/release_build_notarize.sh`
3. Artifact:
- `build/Snaption.zip` (plus stapled app in `build/export/Snaption.app`)

## GitHub Automation

1. PRs run tests via `.github/workflows/ci.yml`.
2. Pushes to `main` run tests and upload a local-signed build artifact.
3. Tagged releases (`v*`) run `.github/workflows/release.yml`:
- validates `MARKETING_VERSION` matches the tag,
- runs tests,
- publishes `Snaption.zip` + `SHA256.txt` to GitHub Releases.

## Notes

- Local release mode skips notarization and is expected to trigger Gatekeeper friction on other Macs.
- Use `planning/05-RELEASE_CHECKLIST.md` and `planning/08-RELEASE_NOTES_TEMPLATE.md` for each release.
