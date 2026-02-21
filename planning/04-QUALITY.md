# Snaption Quality Guide

Updated: 2026-02-21

# Snaption Manual QA Checklist

Updated: 2026-02-20

## Scope

Run this before milestone merges that touch indexing, viewer navigation, sidecars, search, or presentation mode.

## Datasets

- Medium dataset: ~200-500 images across nested folders.
- Large dataset: ~4,000-6,000 images across nested folders.

## Core Regression Pass

1. Open project folder.
- Expected: app transitions to library quickly.
- Expected: thumbnails begin appearing before full indexing completes.

2. Verify indexing status.
- Expected: indexing counter rises progressively.
- Expected: final indexed count matches expected photo total.

3. Open a photo from library.
- Expected: viewer opens selected photo.
- Expected: filename/relative path match clicked item.

4. Viewer navigation buttons.
- Expected: `Previous` and `Next` follow filename order.
- Expected: no wraparound at first/last item.

5. Keyboard navigation.
- Expected: left arrow goes to previous.
- Expected: right arrow goes to next.
- Expected: no wraparound at boundaries.

6. Notes autosave.
- Edit notes and pause >1s.
- Navigate away and back.
- Restart app and reopen photo.
- Expected: notes persist exactly.

7. Tags add/remove.
- Add tags with mixed spacing/case.
- Remove one tag.
- Expected: tags dedupe case-insensitively and persist.

8. Point labels add/remove.
- Add label point + text.
- Remove label.
- Expected: overlay and labels list update immediately and persist.

9. Search.
- Search by notes text, tag text, label text.
- Expected: results update and match case-insensitive substring behavior.

10. Malformed sidecar safety check.
- Use a photo with malformed/partial front matter.
- Expected: app does not crash; photo remains navigable; warning/fallback behavior is safe.

## Presentation Mode Pass

1. Connect second display and open viewer.
- Enable `Presentation Mode`.
- Expected: second display shows photo only (fullscreen borderless).

2. Navigate photos while presentation mode is on.
- Expected: second display follows selected photo.

3. Leave viewer (back to library/start) while presentation mode remains on.
- Expected: second display stays black until viewer is active again.

4. Disconnect external display while presentation mode is on.
- Expected: mode auto-disables and app stays stable.

## Performance Spot Checks (Large Dataset)

1. Time-to-first-visible-thumbnails.
- Record: seconds from folder select to first visible thumbnail.
- Use: Library `Performance` panel `First paint` value.

2. Scroll smoothness during active indexing.
- Record: smooth/minor hitching/major hitching.

3. Memory trend during prolonged scrolling.
- Record: stable growth/slow leak/large spikes.
- Use: Library `Performance` panel `Memory` value while scrolling.

## Test Log Template

- Date:
- Build/commit:
- Dataset:
- Pass/Fail summary:
- Defects found:
- Notes:

# Snaption Performance Profiling Runbook

Updated: 2026-02-20

## Goal

Validate indexing and thumbnail behavior on medium and large datasets before release.

## Setup

1. Build a Debug app from current branch.
2. Prepare:
- Medium dataset: ~200-500 photos.
- Large dataset: ~4,000-6,000 photos.
3. Close unrelated high-memory apps to reduce noise.

## What To Measure

Use the Library `Performance` panel during each run:

- `First paint`: time to first visible thumbnails.
- `Full index`: time until indexing completes.
- `Memory`: resident memory during indexing and scroll.
- `Thumb hit rate`: cache effectiveness while scrolling.
- `Thumb entries`: approximate cache working set.

## Procedure

1. Open dataset folder and wait for indexing completion.
2. Record `First paint` and `Full index`.
3. Scroll continuously for 60-90 seconds.
4. Record memory min/max while scrolling.
5. Scroll back to earlier content and record hit-rate trend.
6. Repeat twice and average values.

## Pass/Fail Guidance

- First paint should remain quick enough for immediate browsing.
- Full indexing should complete without UI stalls.
- Memory should stabilize after active scrolling (no unbounded growth).
- Hit rate should improve on repeated passes through recently viewed content.

## Results Template

| Date | Commit | Dataset | First paint | Full index | Memory range | Hit rate end | Notes |
|------|--------|---------|-------------|------------|--------------|--------------|-------|
|      |        | Medium  |             |            |              |              |       |
|      |        | Large   |             |            |              |              |       |
