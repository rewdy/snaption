# Working Questions / Assumptions (WIP)

Updated: 2026-02-21

## Assumptions Made

1. Face feature opt-in state is stored in `UserDefaults` per project root (keyed by a SHA-256 hash of the root path).
2. Face feature cache lives under `Application Support/Snaption/FaceFeatures/<root-hash>/`.
3. Opt-in prompt is a one-time confirmation dialog shown on first open of a project root.
4. The `...` menu in the app header is a toolbar `Menu` with an ellipsis icon shown in both Library and Viewer routes.
5. “Enable Face Features” directly enables without re-prompting if previously disabled.
6. Face Gallery (preview) shows detected face crops from cache without identity clustering or label suggestions.
7. Face label suggestions / clustering are deferred until we have an embeddings strategy (Vision featureprint vs. third-party).
8. Audio silence trimming is not yet implemented; recordings are stored as captured.

## Open Questions (for later review)

1. Do you want the opt-in prompt to appear again if a project root is moved/renamed?
2. Should the face cache be included in any future “Clear Cache” settings screen?
3. Exact wording for the opt-in prompt and disable/purge confirmation.
4. Do you want face label suggestions based on similarity (requires embeddings) before shipping F4?
5. Should silence trimming be required for the first audio release, or is it acceptable to defer?
