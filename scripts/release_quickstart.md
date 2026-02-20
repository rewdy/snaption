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

## Notes

- Local release mode skips notarization and is expected to trigger Gatekeeper friction on other Macs.
- Use `RELEASE_CHECKLIST.md` and `RELEASE_NOTES_TEMPLATE.md` for each release.
