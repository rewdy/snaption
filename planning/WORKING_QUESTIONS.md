# Working Questions / Assumptions (WIP)

Updated: 2026-02-21

## Assumptions Made

1. Face feature opt-in state is stored in `UserDefaults` per project root using a bookmark-based key so moves/renames do not re-prompt.
2. Face feature cache lives under `Application Support/Snaption/FaceFeatures/<root-key>/`.
3. Opt-in prompt is a one-time confirmation dialog shown on first open of a project root.
4. The `...` menu in the app header is a toolbar `Menu` with an ellipsis icon shown in both Library and Viewer routes.
5. “Enable Face Features” directly enables without re-prompting if previously disabled.
6. Face Gallery is a full view route, accessed from a Library toolbar button.
7. Face label suggestions are based on Vision face feature prints (distance threshold).
8. Audio recordings are trimmed for silence before processing.

## Open Questions (for later review)

1. Future clear-cache action should also purge face cache so gallery data disappears.
