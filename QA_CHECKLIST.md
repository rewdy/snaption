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
