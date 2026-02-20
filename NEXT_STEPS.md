# Snaption Next Steps

Updated: 2026-02-19

## 1) Where We Are

- MVP feature implementation is effectively complete (Milestones 0-5).
- Active phase is Milestone 6: hardening, performance validation, and release prep.

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
  - nested observable update propagation behavior
  - keyboard navigation behavior
  - malformed/partial sidecar edge cases
- Resolve remaining Xcode warnings that are not noise (in progress: destination warning removed, one toolchain noise message remains).

4. Packaging readiness (after QA confidence)
- Define signing/notarization path for direct-download distribution.
- Add a lightweight release checklist (versioning, archive, smoke test).
- Use automation scripts:
  - `scripts/release_preflight.sh`
  - `scripts/release_build_notarize.sh`

## 3) Suggested First Task Next Session

- Start with a structured manual QA run using a medium and large folder tree.
- Log findings in a short checklist file so fixes can be tracked and batched.
