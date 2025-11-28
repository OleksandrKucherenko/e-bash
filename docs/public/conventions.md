# Conventions and Structure

## Folder Purpose
- `.scripts/_{purpose}.sh`: hidden core library, reusable functions only (not directly executable).
- `bin/{domain}.{feature}.sh`: user-facing entrypoints; domain is one short word, feature follows use-case naming rules (hyphenated words, 2–5 words, ≤25 chars).
- `demos/demo.{use-case}.sh`: runnable examples showing library/bin usage.
- `spec/`: unit tests; subfolders allowed (e.g., `spec/bin`, `spec/demos`). Files use `{subject}_{use-case}_spec.sh` (underscore separates subject and use-case).
- `spec/fixtures/`: test fixtures named `{subject}_{use_case}.*` (underscore between subject and use-case, hyphens within multi-word parts).
- `legacy/`: archived scripts/demos (non-default versions), kept for reference without crowding active commands.
- `docs/public/`: user-facing documentation; `docs/work/`: refactor notes, research, and WIP docs; test-only docs under `docs/work/tests/`.
- `docs/images/public/` and `docs/images/work/`: image assets mirroring the public/work split.

## Naming Rules
- Use dots to separate logical categories (domain.feature), hyphens within multi-word features/use-cases, and underscores only to separate distinct tokens (e.g., subject vs use-case in specs/fixtures).
- Domains are a single short word; use-cases are 2–5 words, ≤25 characters total.
- Core files stay `_prefixed` to signal library-only usage.
- Special case: keep `bin/install.e-bash.sh` unchanged to avoid breaking online installation.

## Defaults vs Legacy
- Default version script: `bin/version-up.v2.sh`; legacy v1 stored at `legacy/bin/version-up.v1.sh`.
- When introducing alternates, move superseded versions to `legacy/` and document the current default.

## Tooling
- Cleanup: `mise run clean` removes coverage/report artifacts and editor backups.
- Testing: `shellspec --quick` for fast validation; ensure specs mirror the naming of their target scripts/demos.
