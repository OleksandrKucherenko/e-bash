# Legacy Git Hooks (Archived)

**Archived:** 2026-01-25
**Reason:** Migrated to lefthook

This directory contains the legacy git hooks that were used before migrating to lefthook.

## Migration Details

See the full migration plan: [../../plans/2026-01-25-lefthook-migration.md](../../plans/2026-01-25-lefthook-migration.md)

## Files

- `pre-commit` - Main orchestrator
- `pre-commit-copyright` - Copyright verification and addition
- `pre-commit-copyright-last-revisit` - Last revisit date updates
- `pre-commit.d/` - Additional hook scripts
- `README.md` - Original documentation

## Current System

The project now uses [lefthook](https://github.com/evilmartians/lefthook) for git hooks management.

See: [../../.lefthook/README.md](../../.lefthook/README.md)
