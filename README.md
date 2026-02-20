# Snaption

<p align="center">
  <img src="https://github.com/rewdy/snaption/blob/main/snaption-sm.png?raw=true" alt="Snaption app icon"/>
</p>

Snaption is a macOS desktop app for browsing family photo archives and saving annotations in human-readable Markdown sidecar files.

## What It Does

- Opens a root folder and recursively indexes photos (`.jpg`, `.jpeg`, `.png`)
- Shows a progressive thumbnail grid for large libraries
- Sorts by filename (`asc` / `desc`)
- Opens a photo viewer with previous/next navigation
- Supports keyboard navigation in viewer (`Left` = previous, `Right` = next)
- Saves notes, tags, and point labels per photo
- Autosaves edits to adjacent `.md` sidecar files (no manual save button)
- Searches across notes, tags, and label text
- Handles malformed sidecar data defensively and preserves unknown front matter keys when possible

## Data Model (Sidecar)

For a photo like `IMG_0001.jpg`, Snaption writes `IMG_0001.md` in the same folder.

- YAML front matter: structured fields (`labels`, `tags`, metadata)
- Markdown body: free-form notes

## Tech Stack

- Swift + SwiftUI (macOS app)
- Xcode project: `Snaption.xcodeproj`
- Unit tests: `SnaptionTests`

## Local Development

- Open in Xcode: `Snaption.xcodeproj`
- Run unit tests:
  - `xcodebuild test -project Snaption.xcodeproj -scheme Snaption -destination 'platform=macOS,arch=arm64' -only-testing:SnaptionTests`
- Release preflight:
  - `./scripts/release_preflight.sh`
  - No Apple Developer account yet: `LOCAL_RELEASE=1 ./scripts/release_preflight.sh`

## ROADMAP

- [x] Milestone 0: Project bootstrap and app shell
- [x] Milestone 1: Open folder + recursive index + thumbnail grid
- [x] Milestone 2: Viewer + previous/next navigation
- [x] Milestone 3: Sidecar read/write + notes autosave
- [x] Milestone 4: Point labels + tags persistence
- [x] Milestone 5: Search across notes/tags/labels
- [ ] Milestone 6: Hardening and performance pass on 4k-6k libraries
- [ ] Expand regression/integration coverage (keyboard nav, UI update propagation, edge sidecars)
- [ ] Packaging/signing/notarization plan for direct-download release

## Project Docs

- `REQUIREMENTS.md`
- `FUNCTIONAL_SPEC.md`
- `TECHNICAL_DESIGN.md`
- `EXECUTION_PLAN.md`
- `NEXT_STEPS.md`
- `QA_CHECKLIST.md`
- `PERFORMANCE_PROFILING.md`
- `PACKAGING_SIGNING_NOTARIZATION.md`
- `RELEASE_CHECKLIST.md`
- `RELEASE_NOTES_TEMPLATE.md`
- `scripts/release_quickstart.md`
