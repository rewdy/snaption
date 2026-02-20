# Snaption Versioning

Updated: 2026-02-20

## macOS Conventions

1. `MARKETING_VERSION` (`CFBundleShortVersionString`):
- user-facing app version (for example `1.3.0`)
- use semantic versioning (`MAJOR.MINOR.PATCH`)
2. `CURRENT_PROJECT_VERSION` (`CFBundleVersion`):
- internal build number
- must be numeric and monotonically increasing

## Recommended Process (Best Practice)

Use an explicit release process, not auto-bump on every merge.

1. Merge normal feature/fix PRs without touching version numbers.
2. Create a dedicated release PR that:
- bumps `MARKETING_VERSION` to the intended release version,
- increments `CURRENT_PROJECT_VERSION`.
3. Merge the release PR.
4. Tag that exact commit as `v<MARKETING_VERSION>` (example: `v1.3.0`).
5. Push the tag; `.github/workflows/release.yml` builds and publishes `Snaption.zip`.

## Why Explicit Beats Auto-Bump Here

1. Versioning stays intentional and reviewable.
2. Changelogs/release notes map cleanly to tagged commits.
3. Avoids accidental public versions from routine merges.
4. Easier rollback/hotfix control for a small team workflow.
