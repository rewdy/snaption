# Snaption Requirements (Draft v0.1)

## 1) Vision and Goals

Build a macOS desktop app for family photo collections that makes it fast and simple to:

- Browse photos from a filesystem folder tree.
- Add structured labels and free-form notes to each photo.
- Store all annotation data in human-readable Markdown sidecar files.

Primary users are the author and parents, with an emphasis on ease of use, offline operation, and data portability.

## 2) Product Scope

### MVP Scope

- Open a root folder as a project/library.
- Recursively discover supported image files under that root.
- Show thumbnail grid with responsive scrolling for large collections.
- Open single-photo viewer.
- Navigate next/previous in filename order (ascending/descending toggle only).
- Add/edit free-form notes (Markdown body).
- Add/remove point-based labels on photo (click point + text label).
- Add/edit simple tags (text tags).
- Autosave changes to sidecar Markdown file (debounced, no Save button).
- Search/filter by:
  - Notes text
  - Label text (person names or any label text)
  - Tags

### Out of Scope for MVP (Post-MVP)

- Multi-user conflict handling/locking/history.
- EXIF/XMP embedding and write-back.
- Face detection/recognition.
- Review workflows (reviewed/unreviewed flags).
- Backup/version files (`.bak`) and in-app history.
- Advanced sorting modes (date, custom sort).
- Additional formats beyond JPG/PNG.
- Presentation-mode display picker when multiple external displays are connected.
- App Store distribution requirements.

## 3) Users and Usage Model

- Users: 2-3 family members, primarily non-technical.
- Typical collection size: ~4,000-6,000 photos.
- Usage mode: offline-first, local filesystem only.
- Sync/sharing model: external filesystem sync tools (iCloud, Dropbox, etc.).

## 4) Functional Requirements

### 4.1 Library/Folder Handling

- User selects a root folder.
- App recursively indexes subfolders for supported image formats.
- Supported formats (MVP): `.jpg`, `.jpeg`, `.png` (case-insensitive).
- Folder is treated as one project/library.

### 4.2 Grid and Viewer

- Thumbnail grid supports virtualization/windowing to keep scrolling smooth.
- Initial UI must render quickly with partial index; background indexing continues.
- Photo viewer supports next/previous navigation using filename sort:
  - Primary sort key: filename.
  - Toggle: ascending or descending.

### 4.3 Annotation

- Notes: free-form Markdown text.
- Point labels:
  - User clicks image to place point.
  - User enters label text (e.g., person name or any tag text).
  - User can remove/edit labels.
- Tags:
  - Free-form text tags managed per photo.
  - Reusable autocomplete list is optional post-MVP.

### 4.4 Search

- Search must support:
  - Notes body text.
  - Point-label text.
  - Tags.

### 4.5 Saving and Recovery

- Autosave on changes with short debounce.
- No explicit save action in MVP.
- Sidecar is source of truth.
- Corrupt or unknown front matter handling:
  - Preserve unknown fields where possible.
  - If known fields are invalid, ignore invalid values and keep file readable.
  - App should avoid destructive rewrites that drop unrelated user data.
  - Optional user-facing warning can be post-MVP.

## 5) Data Format Requirements

## 5.1 Sidecar Rule

- Sidecar path: same directory as image, same basename, `.md` extension.
- Example:
  - `IMG_1234.jpg`
  - `IMG_1234.md`

## 5.2 Canonical Structure (Proposed)

Use YAML front matter for structured fields and Markdown body for notes.

```md
---
photo: IMG_1234.jpg
labels:
  - id: lbl-1
    x: 0.412
    y: 0.338
    text: "Grandpa Joe"
tags:
  - "christmas"
  - "1978"
updated_at: 2026-02-19T10:15:00Z
---

General notes in markdown...
```

### Data Model Notes

- `x`, `y` are normalized coordinates in `[0,1]`.
- `text` is generic by design; can represent a person name or any label.
- Preserve unknown front matter fields during read/write when practical.
- `updated_at` can be managed by app for debugging/sync transparency.

## 6) Non-Functional Requirements

- Platform: macOS desktop app.
- Performance:
  - Fast first paint for grid on large libraries.
  - Background indexing and thumbnail generation.
  - Smooth scrolling via virtualization.
- Reliability:
  - Never require internet.
  - Graceful handling of malformed sidecars.
- Portability:
  - Plain files; no mandatory database for user data.

## 7) Technical Direction (Initial)

- Recommended stack: Swift + SwiftUI for native macOS UX.
- Store user annotations in sidecar Markdown files only for MVP.
- Internal app cache/index (if used) should be rebuildable from filesystem.

## 8) Distribution (Current Assumption)

- Initial release as open-source direct download outside Mac App Store.
- Packaging/signing/notarization details deferred.

## 9) Acceptance Criteria for MVP

- User can open root folder and see recursive thumbnails.
- User can open any photo and navigate next/previous by filename.
- User can add/edit/remove note text and point labels.
- User can add/edit/remove tags.
- App autosaves to matching `.md` sidecar.
- After restart, annotations reload accurately from sidecar.
- Search returns matches across notes, labels, and tags.
- App remains responsive on a 4k-6k image collection.

## 10) Open Questions to Resolve Next

- Exact debounce interval and write batching strategy.
- Detailed malformed YAML behavior (strict merge/preserve policy).
- UI specifics for point label editing/removal affordance.
- Whether to include `.jpeg` explicitly (recommended yes).
- Minimum macOS target version.
- Project structure and implementation phases.
