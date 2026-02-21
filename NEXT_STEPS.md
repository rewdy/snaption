# Snaption Next Steps

Updated: 2026-02-21

## 1) Where We Are

- MVP feature implementation is effectively complete (Milestones 0-5).
- Active phase is Milestone 6: hardening, performance validation, release prep, and final UX polish.

## 2) Immediate Priorities (Recommended Order)

1. QA and regression pass
- Validate all core flows:
  - open folder -> progressive grid load
  - viewer previous/next via buttons and keyboard arrows
  - notes/tags/labels autosave and reload
  - search across notes/tags/labels
- Record any UX or data-integrity defects.

2. Performance profiling on realistic data
- Test with 4k-6k image library.
- Measure:
  - time-to-first-visible-thumbnails
  - scroll smoothness during active indexing
- memory behavior for thumbnail cache
- Tune cache limits/prefetch behavior if needed.

3. Hardening and tests
- Add tests for:
  - viewer toolbar interactions (back, add-label mode, prev/next)
  - route-aware title/subtitle behavior
  - malformed/partial sidecar edge cases not yet covered

4. Packaging readiness (after QA confidence)
- Complete final release checklist run:
  - `scripts/release_preflight.sh`
  - `scripts/release_build_notarize.sh`
  - smoke test signed build on a clean machine

## 3) Suggested First Task Next Session

- Run a full manual QA pass against the current UI and toolbar flow changes with medium and large folder trees.
- Log findings for final polish before cutting the first release.
