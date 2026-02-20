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
