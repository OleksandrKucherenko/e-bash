# Lefthook Hooks

This directory contains git hooks managed by [lefthook](https://github.com/evilmartians/lefthook).

## Installation

```bash
# Install lefthook (macOS)
brew install lefthook

# Install lefthook (Linux)
# See: https://github.com/evilmartians/lefthook/blob/master/docs/install.md

# Install the hooks
lefthook install
```

## Available Hooks

### Pre-commit Hooks

1. **copyright-verify** - Verifies and adds copyright notices to `.sh` files
   - Checks for copyright headers
   - Validates copyright format (5 lines required)
   - Auto-detects project version via `bin/git.semantic-version.sh`
   - Creates numbered backups (`.~1~`, `.~2~`, etc.)

2. **last-revisit-update** - Updates "Last revisit" dates in modified files
   - Updates only modified files
   - Creates numbered backups

3. **docs-update** - Auto-generates documentation for modified `.scripts/*.sh` files
   - Uses `bin/e-docs.sh` for generation
   - Stages generated documentation files

## Manual Testing

```bash
# Run all pre-commit hooks
lefthook run pre-commit

# Run a specific hook
lefthook run pre-commit --commands copyright-verification

# Run hooks from a specific commit (for testing)
lefthook run pre-commit --ref HEAD~1

# Skip specific hooks for testing
LEFTHOOK_EXCLUDE=last-revisit-update lefthook run pre-commit
```

## Local Configuration

Create a `lefthook-local.yml` file to override settings locally (this file should be gitignored):

```yaml
# Example: Skip specific hooks locally
pre-commit:
  skip:
    - docs-update
```

## Migration Notes

This is the new hook system replacing the legacy `.githook/` directory. See the [migration plan](../../docs/plans/2025-01-25-lefthook-migration.md) for details.

## Exit Codes

For copyright verification:
- `0` - Success
- `1` - General failure
- `2` - Wrong line count in copyright
- `3` - Format mismatch in copyright
