# PhotoInfo App Technical Design (MVP)

This document turns product requirements into an implementable design for a native macOS app.

## 1) Technology Choices

- Language: Swift 5.10+
- UI: SwiftUI (macOS native)
- Min macOS target: 14+ (recommended for modern SwiftUI behavior/perf)
- Concurrency: Swift Concurrency (`async/await`, `Task`, actors)
- Persistence model:
  - Source of truth: Markdown sidecar files on disk
  - Optional internal caches/index files: ephemeral/rebuildable

Rationale:
- Native performance for large local image sets.
- Good integration with filesystem APIs and image decoding.
- Lower complexity than mixing web runtime layers.

## 2) High-Level Architecture

## 2.1 Modules

- `AppShell`
  - App lifecycle, window setup, global dependency wiring.
- `ProjectService`
  - Open/change root folder, recent projects, folder-level state.
- `MediaIndexer`
  - Recursive discovery of image files, filename sorting, background indexing.
- `ThumbnailService`
  - Thumbnail generation/cache for grid.
- `SidecarService`
  - Read/parse/write `.md` files, preserve unknown fields where possible.
- `SearchService`
  - In-memory index/query across notes, labels, tags.
- `ViewerService`
  - Current photo selection, next/previous navigation.
- `UI Layer`
  - SwiftUI views + view models for start screen, grid, viewer, editors.

## 2.2 Data Flow

1. User opens root folder -> `ProjectService`.
2. `MediaIndexer` streams discovered image entries to UI state.
3. Grid requests thumbnails from `ThumbnailService`.
4. Viewer requests sidecar via `SidecarService`.
5. User edits notes/tags/labels -> view model updates local draft.
6. Autosave pipeline debounces and writes via `SidecarService`.
7. On successful write, `SearchService` updates document index.

## 3) Core Data Models

## 3.1 Media Models

```swift
struct PhotoItem: Identifiable, Hashable {
    let id: UUID
    let imageURL: URL
    let sidecarURL: URL
    let filename: String
    let relativePath: String
}
```

## 3.2 Sidecar Models (Canonical)

```swift
struct SidecarDocument {
    var frontMatter: FrontMatter
    var notesMarkdown: String
    var unknownFrontMatter: [String: YAMLValue]
}

struct FrontMatter {
    var photo: String?
    var labels: [PointLabel]
    var tags: [String]
    var updatedAt: Date?
}

struct PointLabel: Identifiable, Hashable {
    var id: String
    var x: Double   // normalized 0...1
    var y: Double   // normalized 0...1
    var text: String
}
```

Notes:
- Keep `unknownFrontMatter` so roundtrip write can preserve non-MVP keys.
- Normalize and dedupe tags (case strategy defined below).

## 4) Filesystem and Indexing Design

## 4.1 Recursive Discovery

- Use `FileManager.enumerator(at:includingPropertiesForKeys:options:)`.
- Skip hidden files/folders by default in MVP.
- Filter extensions case-insensitively: `jpg`, `jpeg`, `png`.

## 4.2 Streaming Index

- Indexing runs in background task.
- Emit `PhotoItem` batches to UI (e.g., every N items or time slice).
- Sort behavior:
  - Maintain filename-based ordering for stable navigation.
  - Apply ascending/descending toggle at view-model layer.

## 4.3 Incremental Reindex Strategy

MVP approach:
- Full reindex on project open.
- Manual `Refresh` action to rescan filesystem.
- No live file watcher in MVP (can add later with `DispatchSourceFileSystemObject`/FSEvents).

## 5) Thumbnail and Image Loading

## 5.1 Thumbnail Generation

- Use `CGImageSourceCreateThumbnailAtIndex` for efficient decode/resize.
- Cache key: file URL + file modification date + requested thumbnail size.
- Cache tiers:
  - In-memory LRU (`NSCache`)
  - Optional disk cache (post-MVP if needed)

## 5.2 Grid Virtualization

- SwiftUI `LazyVGrid` for viewport-based cell creation.
- Thumbnail request cancellation when cell disappears.
- Prefetch near-visible cells (small lookahead window).

## 5.3 Viewer Loading

- Load full-size image lazily on open.
- Avoid decoding multiple full-size images concurrently.
- Keep small adjacent prefetch (`prev`/`next`) optional behind feature flag.

## 6) Sidecar Parsing/Writing

## 6.1 File Format

- File contains optional YAML front matter bounded by `---` and markdown body.
- If file missing: create on first save.

## 6.2 Parser Behavior

Parsing tiers:
1. Valid front matter + body -> parse canonical fields + unknown map.
2. No front matter -> body only; front matter defaults.
3. Malformed front matter:
  - Keep raw file content.
  - Expose safe fallback in UI.
  - Do not overwrite file until user performs an explicit edit that requires write.

## 6.3 Merge/Preserve Strategy

On write:
- Start from original parsed document.
- Replace canonical keys (`photo`, `labels`, `tags`, `updated_at`) with normalized values.
- Preserve unknown keys/values unchanged when parseable.
- Keep notes body exactly as current editor text.

## 6.4 Atomic Write

- Write to temp file in same directory.
- `FileManager.replaceItemAt`/rename swap to destination.
- On failure:
  - Retain dirty state
  - Surface non-blocking UI warning
  - Retry on next edit/autosave tick

## 7) Autosave and Edit Pipeline

## 7.1 Debounce Policy

Recommended default:
- Debounce interval: 600 ms after last edit event.
- Immediate write when:
  - User navigates away from current photo.
  - App moves to background/terminates.

## 7.2 Dirty State Model

Per-photo editor state:
- `clean`: matches sidecar on disk.
- `dirty`: pending changes.
- `saving`: write in progress.
- `error`: last write failed, changes still in memory.

## 7.3 Concurrency Controls

- Use `actor SidecarStore` to serialize read/write for a given file path.
- Coalesce multiple pending writes to latest snapshot.
- Ensure navigation does not race with stale writes.

## 8) Search Design

## 8.1 Index Shape

For each `PhotoItem`, maintain searchable lowercase fields:
- `notesText`
- `labelTexts` (joined)
- `tags` (joined)

## 8.2 Query Behavior

- Case-insensitive substring matching in MVP.
- Query applies over in-memory index.
- Results update incrementally as sidecars are parsed/indexed.

## 8.3 Update Triggers

- Initial sidecar parse for each discovered photo.
- Any successful sidecar save for active photo.
- Project refresh/reindex.

## 9) UI/State Management

## 9.1 App State Containers

- `AppState` (observable): project path, index progress, global errors.
- `LibraryViewModel`: visible list, sort direction, query text, search results.
- `ViewerViewModel`: current photo, editor draft, autosave status.

## 9.2 Navigation Rules

- Source order always derived from filename sort + direction.
- Next/previous disabled at collection bounds.
- No wraparound in MVP.

## 10) Error Handling Strategy

- Read errors (image or sidecar):
  - Log structured error with file path.
  - Keep app navigable and show local warning affordance.
- Write errors:
  - Never drop in-memory edits.
  - Show unsaved indicator until successful save.
- Malformed sidecar:
  - Do not crash.
  - Use fallback display and safe write policy.

## 11) Security and Privacy

- No network dependency for MVP.
- File access only within user-selected folder scope.
- If sandboxing is enabled later:
  - Persist security-scoped bookmarks for project roots.

## 12) Testing Strategy

## 12.1 Unit Tests

- Sidecar parse/write roundtrip:
  - Valid front matter.
  - Unknown key preservation.
  - Missing front matter.
  - Malformed front matter fallback.
- Coordinate conversion:
  - View click -> normalized point -> render back.
- Tag normalization and dedupe behavior.
- Filename sorting asc/desc.

## 12.2 Integration Tests

- Open fixture library with nested folders.
- Background indexing emits progressive batches.
- Autosave writes on debounce and on navigate-away.
- Search updates after edits.

## 12.3 Performance Checks

- Measure time-to-first-grid-item.
- Scroll smoothness with 4k-6k fixture set.
- Sidecar save latency under rapid edits.

## 13) Implementation Notes and Decisions

- Tag normalization rule (MVP):
  - Trim whitespace.
  - Collapse internal repeated spaces.
  - Case-preserving display, case-insensitive match.
- Label IDs:
  - Generate UUID-based `lbl-<uuid-fragment>`.
- `updated_at`:
  - Written in ISO-8601 UTC string.

## 14) Risks and Mitigations

- Risk: malformed YAML diversity in real files.
  - Mitigation: tolerant parser + non-destructive write path.
- Risk: memory pressure from thumbnails.
  - Mitigation: aggressive `NSCache` limits + cancellation/prefetch bounds.
- Risk: UI hitching during scan.
  - Mitigation: batched index publish and background queue/actors.

## 15) Open Technical Decisions

- YAML/Markdown parsing library selection:
  - Option A: lightweight dependency for YAML front matter.
  - Option B: custom minimal parser for constrained schema.
- Disk thumbnail cache needed for MVP or not.
- Exact `NSCache` sizing defaults and prefetch window sizes.
- Minimum macOS target confirmation (13 vs 14).
