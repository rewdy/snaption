# PhotoInfo App Execution Plan (MVP)

This plan converts requirements and technical design into implementable milestones and agent-ready task units.

## 1) Delivery Strategy

- Build vertical slices early:
  - Open folder -> index -> grid -> viewer
  - Then annotation -> autosave -> search
- Keep sidecar format stable from first implementation.
- Prioritize responsiveness and data safety before UI polish.

## 2) Milestones

## Milestone 0: Project Bootstrap

Goal: runnable macOS app skeleton with app state wiring.

Outputs:
- Xcode project scaffold (SwiftUI macOS app).
- Basic app navigation: Start screen -> empty Library screen -> empty Viewer screen.
- Module folders and initial protocols/interfaces.
- CI/lint/test baseline (if desired in repo stage).

Exit criteria:
- App launches locally and navigates between placeholder views.

## Milestone 1: Project Open + Index + Grid

Goal: user can open a root folder and browse thumbnails from recursive scan.

Scope:
- Folder picker integration.
- Recursive image discovery (`jpg/jpeg/png`).
- Progressive index publishing.
- Filename sort + asc/desc toggle.
- `LazyVGrid` thumbnail display with in-memory thumbnail cache.

Exit criteria:
- On realistic folder trees, first thumbnails appear quickly and scrolling remains smooth.

## Milestone 2: Viewer + Navigation

Goal: user can open any photo and navigate sequentially.

Scope:
- Open photo from grid.
- Viewer rendering for selected image.
- Previous/Next controls using filename order.
- Disable controls at bounds.

Exit criteria:
- Viewer navigation is deterministic and consistent with library sort direction.

## Milestone 3: Sidecar Read/Write + Notes

Goal: notes persist to `.md` sidecar in canonical format.

Scope:
- Sidecar path mapping.
- Front matter/body parser.
- Fallback behavior for missing/malformed front matter.
- Notes editor and autosave pipeline.
- Atomic write strategy.

Exit criteria:
- Notes survive app restart and sidecar is non-destructively maintained.

## Milestone 4: Labels + Tags

Goal: user can annotate point labels and tags, with persistence.

Scope:
- Click-to-place normalized point label + text.
- Label list edit/remove.
- Tags add/remove with normalization/dedupe.
- Persist labels/tags into front matter.

Exit criteria:
- Labels and tags reload accurately and render in viewer.

## Milestone 5: Search

Goal: library search across notes, labels, and tags.

Scope:
- In-memory searchable index.
- Case-insensitive substring query.
- Incremental updates after sidecar save.

Exit criteria:
- Search results reflect edits without full app restart.

## Milestone 6: Hardening + Performance

Goal: reliability and responsiveness on 4k-6k photos.

Scope:
- Performance tuning for indexing and thumbnail lifecycle.
- Error states (read/write failures, malformed sidecars).
- Unit/integration test coverage for core workflows.
- Manual QA checklist pass.

Exit criteria:
- No critical data-loss bugs, acceptable responsiveness on target dataset.

## 3) Workstreams and Dependencies

## Workstream A: App Shell and State

- Build app scaffolding and shared state containers.
- Dependency order: none (starts first).

## Workstream B: Indexing and Grid

- File scan, sorting, grid virtualization, thumbnail cache.
- Dependency order: after A.

## Workstream C: Viewer and Navigation

- Viewer screen and selection model.
- Dependency order: after B basic index list exists.

## Workstream D: Sidecar Engine

- Parser/serializer, merge/preserve logic, atomic writer.
- Dependency order: after A (can run parallel with B/C).

## Workstream E: Annotation UX

- Notes, labels, tags editors and overlay rendering.
- Dependency order: after C + D.

## Workstream F: Search

- In-memory indexing and query integration.
- Dependency order: after D + partial E.

## Workstream G: QA/Perf

- Tests, fixtures, profiling, bug fixing.
- Dependency order: ongoing, final pass after all streams.

## 4) Agent-Ready Task Breakdown

Each task is intentionally small enough for focused implementation and review.

## Agent 1: Foundation

Tasks:
1. Create app module layout and core protocols.
2. Implement `AppState`, `ProjectService`, and route skeleton.
3. Add start screen with folder picker and recent-project placeholder.

Deliverables:
- Compiling app shell with empty states wired.

## Agent 2: Media Indexing + Grid

Tasks:
1. Implement recursive scanner for supported extensions.
2. Emit progressive `PhotoItem` batches to UI.
3. Implement filename sort and asc/desc toggle.
4. Build `LazyVGrid` thumbnail list and selection action.

Deliverables:
- Working library grid with responsive progressive load.

## Agent 3: Thumbnail Pipeline

Tasks:
1. Implement thumbnail decoding using ImageIO.
2. Add `NSCache`-based in-memory cache with eviction limits.
3. Add cancellation for off-screen requests.
4. Add lightweight prefetch around visible range.

Deliverables:
- Smooth thumbnail experience with bounded memory growth.

## Agent 4: Viewer + Navigation

Tasks:
1. Build photo viewer screen.
2. Implement next/previous navigation with boundary disable.
3. Ensure navigation follows library sort direction.

Deliverables:
- Deterministic single-photo browsing workflow.

## Agent 5: Sidecar Parser/Writer

Tasks:
1. Implement sidecar path resolver.
2. Implement Markdown + YAML front matter parser.
3. Preserve unknown front matter keys where parseable.
4. Implement atomic write and error propagation.

Deliverables:
- Robust sidecar I/O engine with non-destructive behavior.

## Agent 6: Notes + Autosave

Tasks:
1. Add notes editor bound to sidecar body.
2. Implement dirty/saving/error states.
3. Implement 600ms debounce autosave.
4. Force flush on navigation-away and app lifecycle events.

Deliverables:
- Reliable autosave for notes without explicit save button.

## Agent 7: Labels + Tags

Tasks:
1. Implement click-to-place normalized point labels.
2. Add label text entry/edit/remove flows.
3. Implement tag chip input + remove + dedupe.
4. Persist labels/tags through sidecar service.

Deliverables:
- Complete annotation MVP.

## Agent 8: Search

Tasks:
1. Build in-memory searchable projection (notes/labels/tags).
2. Implement case-insensitive substring query.
3. Wire library search box to filtered results.
4. Reindex changed photo on successful save.

Deliverables:
- Fast, predictable MVP search behavior.

## Agent 9: Tests + Hardening

Tasks:
1. Build fixture dataset generator (nested folders + sidecar variants).
2. Add parser/writer roundtrip unit tests.
3. Add navigation/order/search integration tests.
4. Add malformed sidecar resilience tests.

Deliverables:
- Safety net for regression control and data integrity.

## 5) Suggested Implementation Sequence

1. Agent 1
2. Agent 2 + Agent 5 (parallel)
3. Agent 3 + Agent 4 (parallel)
4. Agent 6 + Agent 7 (parallel)
5. Agent 8
6. Agent 9
7. Final integration and QA pass

## 6) Definition of Done (MVP)

All of the following must be true:

- Open-folder flow works for nested directories.
- Grid/viewer navigation works in filename order.
- Notes, labels, and tags autosave to sidecars and reload correctly.
- Search works across notes/labels/tags.
- App is responsive on 4k-6k image collections.
- Malformed sidecars do not crash app.
- Core workflows covered by automated tests.

## 7) Risk Register (Execution)

- Parser complexity risk:
  - Mitigate with strict canonical writer + tolerant reader tests.
- UI/perf risk with large libraries:
  - Mitigate with early profiling and explicit cache constraints.
- Concurrency race risk in autosave/navigation:
  - Mitigate with actor-isolated write pipeline and state machine tests.

## 8) Immediate Next Actions

1. Initialize SwiftUI macOS project structure in repo.
2. Implement Milestone 0 and Milestone 1 skeleton in one branch.
3. Add fixture directories and first parser tests before full annotation UI.

## 9) Agent Team Operating Model

This section defines how parallel agents should work without stepping on each other.

## 9.1 Branch Strategy

- Main branch: `main` (protected by review policy if available).
- Agent branches:
  - `agent/<area>/<short-task>`
  - Examples:
    - `agent/foundation/app-shell`
    - `agent/sidecar/parser-writer`
- Rebase/merge policy:
  - Keep branches short-lived.
  - Merge to `main` only after checks pass.

## 9.2 Ownership Map

- Agent 1 owns: app shell, routing, global state wiring.
- Agent 2/3 own: indexing, grid, thumbnail pipeline.
- Agent 4 owns: viewer + navigation.
- Agent 5/6/7 own: sidecar engine + annotations + autosave.
- Agent 8 owns: search.
- Agent 9 owns: tests/perf harness and release quality gates.

## 9.3 Interface Contracts (Required)

Each agent must treat these as stable contracts unless a coordinated change is approved:

- `PhotoItem` fields and sorting semantics.
- Sidecar canonical keys:
  - `photo`
  - `labels` (`id`, `x`, `y`, `text`)
  - `tags`
  - `updated_at`
- Autosave state machine states:
  - `clean`, `dirty`, `saving`, `error`
- Navigation semantics:
  - filename-based, no wraparound.

Contract changes require:
1. Updating `TECHNICAL_DESIGN.md`.
2. Updating impacted tests in same PR.
3. Calling out migration impact in PR notes.

## 9.4 PR and Handoff Template

Every agent PR should include:

1. Scope: what was implemented.
2. Files touched: explicit list.
3. Contract changes: yes/no.
4. Tests added/updated.
5. Risks/open issues.
6. Screenshots or short clip for UI changes.

## 9.5 Merge Gates

- Required before merge:
  - Build succeeds.
  - Relevant unit/integration tests pass.
  - No unresolved TODOs for data-loss/error paths in changed files.
- For sidecar write-path changes:
  - Roundtrip tests are mandatory.
- For viewer/index/search changes:
  - At least one integration test or manual QA evidence.

## 9.6 Integration Cadence

- Integrate to `main` at least once per day during active build.
- Prefer smaller PRs (<500 LOC net when practical).
- Resolve conflicts by contract owner for affected module.
