# Snaption Agent Instructions (Repo Memory)

Use this file at the start of each new coding session in this repo.

## Planning Docs Location (Read First)

- All planning/design/release/QA docs live in `planning/`.
- At the start of each session, thoroughly review all docs in `planning/`.
- Store any new planning/design/release/QA docs in `planning/` (not the repo root).

## 1) Product Snapshot

- App name: `Snaption`
- Platform: macOS SwiftUI desktop app
- Primary purpose: browse local photo folders and store annotations in sidecar Markdown files.
- Users: small family use, offline-first, filesystem-based sync only.

## 2) Implemented MVP Capabilities (Current)

- Open root project folder via picker.
- Recursive image discovery (`jpg`, `jpeg`, `png`).
- Progressive indexing + thumbnail grid rendering.
- Filename sort with asc/desc toggle.
- Viewer with previous/next navigation.
- Notes editor (Markdown text body).
- Tags add/remove.
- Point labels add/remove.
- Debounced autosave to sidecar `.md` files.
- Search over notes + tags + labels.
- Unit tests for sidecar + library/navigation/search workflows.

## 3) Important Architecture Notes

- Entry app state lives in `Snaption/AppState.swift` (`@MainActor`).
- Library indexing/search state lives in `Snaption/LibraryViewModel.swift`.
- Sidecar read/write logic lives in `Snaption/SidecarService.swift`.
- Viewer UI is in `Snaption/ViewerView.swift`.
- Root navigation is in `Snaption/RootView.swift`.

### Critical UI Update Lesson

- `LibraryView` observes `AppState`, not `LibraryViewModel` directly.
- To ensure library updates repaint immediately, `AppState` forwards `libraryViewModel.objectWillChange`.
- If thumbnails only appear after clicking UI controls, verify this forwarding still exists.

## 4) Key Product Decisions to Preserve

- Sidecar Markdown is the source of truth.
- Sidecar path rule: same folder + basename, `.md` extension.
- Filename ordering is canonical; no date sort in MVP.
- No multi-user conflict handling in MVP.
- Autosave only; no explicit Save button.
- Point labels (single normalized x/y), not boxes.

## 5) Dev Workflow

- Preferred run/test path:
  - `xcodebuild test -project Snaption.xcodeproj -scheme Snaption -destination 'platform=macOS,arch=arm64' -only-testing:SnaptionTests`
- Before pushing code: run UI tests locally (do not skip):
  - `xcodebuild test -project Snaption.xcodeproj -scheme Snaption -destination 'platform=macOS,arch=arm64' -only-testing:SnaptionUITests`
- Keep `.vscode` in repo and do not remove it (user preference).
- When modifying nested observable objects, verify parent view update propagation.
- Avoid destructive git operations; repository may include user changes.

## 6) Current Status Summary

- Milestones 0-5 are functionally implemented.
- Face features (opt-in, indexing, gallery, suggestions) are implemented.
- Audio recording/transcription/summaries are implemented.
- Milestone 6 (hardening/performance/QA) is partially done and is the active focus area.
- Most immediate work is product polish + performance validation + packaging prep.

## 7) Next Session Priorities

1. Add/expand manual QA checklist and run through regression pass.
2. Add integration or UI tests for keyboard navigation and first-paint behavior.
3. Profile with larger (4k-6k) dataset and tune thumbnail cache/prefetch limits.
4. Review warnings and clean non-critical Xcode warnings.
5. Prepare packaging/signing/notarization plan (post-MVP delivery readiness).
