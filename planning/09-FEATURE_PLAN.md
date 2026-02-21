# Snaption Feature Plan (Faces + Audio)

Updated: 2026-02-21

This plan breaks the new features into agent‑sized tasks with clear ownership, review gates, and reporting expectations.

---

## 0) Coordination Rules

- Each implementation task must have a paired review task by a different agent.
- Implementation agents report progress + risks in a short status note.
- Review agents focus on correctness, data safety, and UI regressions.
- Main agent consolidates updates and reports to you after each task pair completes.

---

## 1) Face Features (Opt‑In, Cached)

### Task F1 — Opt‑In + Toggle + Cache Scaffold (Implement)
**Owner:** Agent A  
**Scope:**
- Add per‑project opt‑in prompt when opening a folder.
- Add `...` menu toggle: “Enable Face Features” / “Disable Face Features”.
- On disable: prompt to **keep** or **purge** cache.
- Create local cache directory + metadata file (empty schema for now).
**Touchpoints:**
- `AppState`, `RootView`, `ProjectService`, new cache helper.
**Acceptance:**
- Opt‑in prompted once per project root.
- Toggle works + prompts on disable.
- Cache directory created and purged correctly.

### Task F1R — Review (Code + UX)
**Owner:** Agent B  
**Checklist:**
- No prompts in unexpected flows.
- Toggle state persists per root.
- Purge deletes only face cache, not sidecars.

---

### Task F2 — Viewer Face Detection Overlay (Implement)
**Owner:** Agent A  
**Scope:**
- Use Vision face detection on current photo.
- Overlay face boxes/points in viewer when enabled + labels visible.
**Touchpoints:**
- `ViewerView` + new Vision helper.
**Acceptance:**
- Face boxes appear within 1–2s after image load.
- Hidden when labels are hidden or face feature disabled.

### Task F2R — Review
**Owner:** Agent B  
**Checklist:**
- No blocking UI.
- Overlay respects zoom/scale correctly.

---

### Task F3 — Background Face Indexing (Implement)
**Owner:** Agent A  
**Scope:**
- Background job for face detection + faceprint extraction.
- Store results in local cache.
- Pause/cancel on project change.
**Touchpoints:**
- `LibraryViewModel` / new indexing worker.
**Acceptance:**
- Doesn’t block UI.
- Cache populated with detected faces.

### Task F3R — Review
**Owner:** Agent B  
**Checklist:**
- CPU usage bounded (throttled or batched).
- Reindex handles modified files.

---

### Task F4 — Label Suggestions + Face Gallery (Implement)
**Owner:** Agent A  
**Scope:**
- Suggest known label when placing label on a detected face.
- Create Faces view (gallery), cluster display, batch assign.
**Acceptance:**
- Suggestion accuracy + confirm flow.
- Faces view shows counts and supports batch assign.

### Task F4R — Review
**Owner:** Agent B  
**Checklist:**
- False positives minimized.
- UI consistent with library/viewer.

---

## 2) Audio Recording + Processing

### Task A1 — Recording UI + Session State (Implement)
**Owner:** Agent C  
**Scope:**
- Record button in viewer toolbar `.secondaryAction` next to Presentation.
- Button red while recording.
- Blink 3× on photo change when recording active.
- Start/stop per photo, save `.m4a` with timestamp.
**Touchpoints:**
- `ViewerView`, new `AudioRecordingService`.
**Acceptance:**
- Button states correct.
- Files saved with proper names.

### Task A1R — Review
**Owner:** Agent D  
**Checklist:**
- No UI regressions.
- Recording stops on navigate away.

---

### Task A2 — Transcription + Notes Append (Implement)
**Owner:** Agent C  
**Scope:**
- Gate “Update notes with recording text” based on Speech availability.
- Append `## Audio - DATE` section to sidecar notes.
- If audio retention disabled, move file to Trash.
**Touchpoints:**
- `SidecarService`, new `AudioTranscriptionService`.
**Acceptance:**
- Notes append correctly.
- Audio file handled per settings.

### Task A2R — Review
**Owner:** Agent D  
**Checklist:**
- No data loss in notes.
- Trash behavior verified.

---

### Task A3 — Summaries (Implement)
**Owner:** Agent C  
**Scope:**
- Gate summaries behind Apple Intelligence availability.
- Append `## Audio Summary - DATE`.
**Touchpoints:**
- `AudioSummaryService` (stub if unavailable).
**Acceptance:**
- Summaries appended only when available.

### Task A3R — Review
**Owner:** Agent D  
**Checklist:**
- Summaries do not overwrite or misplace notes.

---

## 3) Reporting & Checkpoints

- After each task pair (Implement + Review), main agent posts a summary:
  - Scope completed
  - Files touched
  - Risks/issues
  - Next task ready

