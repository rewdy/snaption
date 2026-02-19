# Snaption Functional Specification (MVP)

This document defines concrete MVP behavior from user actions to file writes.

## 1) Information Architecture

- App level:
  - `Project` = one selected root folder.
  - `Media Index` = recursive list of supported image files under root.
  - `Current Selection` = active image in grid/viewer.
- Per-photo data source:
  - Sidecar Markdown at same basename/path as image.

## 2) Primary Screens

## 2.1 Project Start Screen

Purpose: choose project root and reopen recent roots.

Required behavior:
- `Open Folder` action launches macOS folder picker.
- On selection, app starts indexing and transitions to Library screen.
- If folder has no supported images, show empty-state message with folder path.

## 2.2 Library Screen (Thumbnail Grid)

Purpose: browse many photos quickly.

Required behavior:
- Grid displays thumbnails for indexed images.
- Recursive indexing starts immediately:
  - First visible thumbnails load as soon as possible.
  - Remaining files continue indexing in background.
- Virtualized rendering/windowing is required to avoid full in-memory view creation.
- Clicking a thumbnail opens Viewer at that photo.
- Sort control:
  - Field fixed to filename.
  - Direction toggle: `A->Z` or `Z->A`.
- Search input filters items by sidecar content:
  - Notes text
  - Label text
  - Tags

## 2.3 Photo Viewer

Purpose: annotate one image with quick sequential navigation.

Required behavior:
- Main image display with pan/zoom optional for MVP (if omitted, keep fit-to-view).
- Navigation controls:
  - `Previous` and `Next` follow current filename order and direction.
  - At bounds, controls disable (no wraparound in MVP).
- Metadata/annotation panel includes:
  - Notes editor (Markdown text)
  - Tag editor (add/remove tag chips)
  - Label list (existing point labels)
- Image click in label mode:
  - Places one point at click location.
  - Prompts for text.
  - Saves as normalized `x`, `y`.

## 3) User Flows

## 3.1 Open Project

1. User clicks `Open Folder`.
2. User selects root folder.
3. App scans recursively for supported image extensions.
4. App displays grid as soon as first batch is available.
5. Background indexing continues until complete.

Success criteria:
- User can begin browsing before full scan finishes.

## 3.2 Annotate Notes

1. User opens photo in Viewer.
2. User edits notes body.
3. Autosave debouncer starts/reset on each change.
4. On debounce expiry, sidecar writes to disk.

Success criteria:
- Closing and reopening photo/app retains latest text written before close.

## 3.3 Add Point Label

1. User enters label mode (or clicks `Add Label`).
2. User clicks point on photo.
3. App records normalized coordinates.
4. User enters label text and confirms.
5. Label appears on overlay and in label list.
6. Autosave writes updated front matter.

## 3.4 Manage Tags

1. User adds tag text in tags input.
2. App normalizes whitespace and stores distinct tags.
3. User can remove tag from list.
4. Autosave writes updated front matter.

## 3.5 Search

1. User types search query in Library screen.
2. App filters current project using indexed sidecar fields.
3. Grid updates incrementally as search/index data becomes available.

Search matching:
- Case-insensitive substring for MVP.

## 4) File and Data Behavior

## 4.1 Supported Inputs

- Image file extensions (case-insensitive):
  - `.jpg`
  - `.jpeg`
  - `.png`

## 4.2 Sidecar Path Mapping

- For image `/path/to/IMG_0001.jpg`, sidecar is `/path/to/IMG_0001.md`.
- Sidecar is created on first edit if missing.

## 4.3 Front Matter Schema (MVP Canonical)

```yaml
photo: IMG_0001.jpg
labels:
  - id: lbl-1
    x: 0.412
    y: 0.338
    text: Grandpa Joe
tags:
  - christmas
updated_at: 2026-02-19T10:15:00Z
```

Markdown body stores notes.

## 4.4 Parsing and Recovery Rules

- No front matter:
  - Treat whole file as notes body.
  - On save, write canonical front matter + existing body.
- Unknown front matter keys:
  - Preserve keys and values when rewriting if parseable.
- Invalid known fields:
  - Ignore invalid values at runtime.
  - Replace with valid canonical values on next write for edited entities.
- Unparseable front matter block:
  - Preserve original file contents in memory as raw fallback notes view.
  - On write, avoid destructive overwrite unless user edits fields in app.

## 5) Autosave Contract

- Autosave is required for:
  - Notes edits
  - Label add/edit/remove
  - Tag add/remove
- Debounced writes (exact interval to be defined in technical design).
- Write strategy:
  - Atomic write to temp + rename to reduce corruption risk.
- Failure behavior:
  - Keep in-memory dirty state.
  - Show non-blocking error indicator with retry on next change.

## 6) Performance Requirements (Functional)

- App remains interactive while indexing 4k-6k images.
- First visible grid content appears quickly from partial index.
- Viewer navigation should feel immediate after initial thumbnail/index warmup.
- Search should stream/update results progressively, not block UI thread.

## 7) Error and Empty States

- No images found:
  - Show clear empty state with supported extensions.
- Image unreadable:
  - Show placeholder and allow navigation onward.
- Sidecar parse issue:
  - Continue displaying photo.
  - Show safe fallback for notes/metadata where possible.
- Sidecar write failure:
  - Show transient warning; continue allowing edits in memory.

## 8) Non-Goals (MVP Explicit)

- Multi-user coordination or conflict resolution.
- Backup/history/version browsing.
- Face boxes or segmentation; point labels only.
- AI recognition or name suggestions.
- EXIF/XMP synchronization.

## 9) Acceptance Tests (Functional)

1. Open root folder with nested subfolders; grid eventually shows all JPG/JPEG/PNG files.
2. Click any thumbnail; viewer opens selected photo.
3. Navigate next/previous and verify filename order adherence.
4. Edit notes; restart app; notes persist in `.md` sidecar body.
5. Add point label; reopen photo; marker and text persist from front matter.
6. Add/remove tags; verify persistence and searchability.
7. Search by notes text, label text, and tag; matching photos are returned.
8. Introduce unknown YAML key; app preserves key after normal edit/save.
9. Simulate malformed front matter; app does not crash and keeps photo navigable.
