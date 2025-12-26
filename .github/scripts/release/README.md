# Release Scripts

This directory contains scripts used by the GitHub Actions release pipeline. These scripts are externalized to make them easier to test and debug locally.

All scripts are located in `.github/scripts/release/` to keep CI-related files organized together.

## Scripts

### prepare-release.sh

Updates header metadata in repository scripts for a release.

**Usage:**

```bash
.github/scripts/release/prepare-release.sh --next-version <version> [--date YYYY-MM-DD] [--dry-run] [--verbose]
```

**Example:**

```bash
.github/scripts/release/prepare-release.sh --next-version 2.0.0 --date 2026-01-01
```

**Notes:**

- Targets tracked `*.sh` files, `.githook/*`, and `COPYRIGHT`
- Excludes `.github/scripts/**` and `spec/fixtures/**`
- Requires `gsed` (GNU sed); uses dry-run wrapper output to show exact commands

---

### validate-version.sh

Validates that a version tag follows semantic versioning format.

**Usage:**

```bash
./validate-version.sh <version> <tag>
```

**Example:**

```bash
./validate-version.sh "1.2.3" "v1.2.3"
```

**Environment Variables:**

- `GITHUB_OUTPUT` - If set, writes `is_valid=true` to this file (for CI)
- `GITHUB_STEP_SUMMARY` - If set, writes error summary to this file (for CI)

---

### check-quality.sh

Runs ShellCheck on all `.sh` files in `.scripts/` and `bin/` directories.

**Usage:**

```bash
./check-quality.sh
```

**Requirements:**

- shellcheck must be installed (auto-installs in CI)

**Environment Variables:**

- `CI` - If set, auto-installs shellcheck using apt-get

---

### verify-contents.sh

Verifies that all required files and directories exist for distribution.

**Usage:**

```bash
./verify-contents.sh
```

**Checks:**

- Directories: `.scripts`, `bin`, `docs`, `demos`
- Files: `README.md`, `LICENSE`

---

### create-archive.sh

Creates a distribution ZIP archive with integrity verification.

**Usage:**

```bash
./create-archive.sh <version>
```

**Example:**

```bash
./create-archive.sh "1.2.3"
# Creates: e-bash.1.2.3.zip
# Creates: e-bash.1.2.3.zip.sha256
```

**Output:**

- `e-bash.<version>.zip` - Distribution archive
- `e-bash.<version>.zip.sha256` - Checksum file

**Environment Variables:**

- `GITHUB_OUTPUT` - If set, writes `archive_name` and `checksum` to this file (for CI)

---

### generate-release-notes.sh

Generates markdown release notes for GitHub releases.

**Usage:**

```bash
./generate-release-notes.sh <version> <tag> <commit_sha> <checksum> <archive_name>
```

**Example:**

```bash
./generate-release-notes.sh "1.2.3" "v1.2.3" "abc123def" "sha256hash" "e-bash.1.2.3.zip"
```

**Output:**

- `release_notes.md` - Generated release notes

---

### release-summary.sh

Generates a release summary for GitHub Actions or stdout.

**Usage:**

```bash
./release-summary.sh <version> <tag> <commit_sha> <checksum> <archive_name> [repository]
```

**Example:**

```bash
./release-summary.sh "1.2.3" "v1.2.3" "abc123def" "sha256hash" "e-bash.1.2.3.zip" "OleksandrKucherenko/e-bash"
```

**Environment Variables:**

- `GITHUB_STEP_SUMMARY` - If set, writes summary to this file (for CI), otherwise writes to stdout

---

## Local Testing

You can test these scripts locally before pushing to CI:

```bash
# Navigate to repository root first
cd /path/to/e-bash

# Prepare headers for a release (dry-run)
./.github/scripts/release/prepare-release.sh --next-version 2.0.0 --dry-run

# Test validation (should pass)
./.github/scripts/release/validate-version.sh "1.2.3" "v1.2.3"

# Test validation (should fail)
./.github/scripts/release/validate-version.sh "1.2" "v1.2"

# Test quality checks
./.github/scripts/release/check-quality.sh

# Test content verification
./.github/scripts/release/verify-contents.sh

# Create a test release
./.github/scripts/release/create-archive.sh "1.2.3-test"

# Generate release notes
./.github/scripts/release/generate-release-notes.sh "1.2.3" "v1.2.3" "$(git rev-parse HEAD)" \
  "$(sha256sum e-bash.1.2.3-test.zip | cut -d' ' -f1)" "e-bash.1.2.3-test.zip"

# View release summary
./.github/scripts/release/release-summary.sh "1.2.3" "v1.2.3" "$(git rev-parse HEAD)" \
  "$(sha256sum e-bash.1.2.3-test.zip | cut -d' ' -f1)" "e-bash.1.2.3-test.zip"
```

## Release Preparation (Manual)

Use these steps before tagging a release:

1. Update headers and copyright template for the release version:

   ```bash
   ./.github/scripts/release/prepare-release.sh --version 2.0.0
   ```

2. Review changes (`git diff`) and commit if needed.
3. Run local checks as desired (`check-quality.sh`, tests).
4. Create and push the tag (e.g., `git tag v2.0.0 && git push origin v2.0.0`).

## Integration with GitHub Actions

These scripts are called by `.github/workflows/release.yaml`. The workflow:

1. Extracts version from tag
2. Validates semver format → `validate-version.sh`
3. Runs quality checks → `check-quality.sh`
4. Deletes existing release (if tag reassigned)
5. Verifies distribution contents → `verify-contents.sh`
6. Creates distribution archive → `create-archive.sh`
7. Generates release notes → `generate-release-notes.sh`
8. Creates GitHub release
9. Displays release summary → `release-summary.sh`

## Benefits of Externalization

- **Local Testing**: Test scripts without pushing to GitHub
- **Debugging**: Easier to debug and iterate on scripts
- **Reusability**: Scripts can be used in other contexts
- **Maintainability**: Cleaner workflow file, focused on orchestration
- **Transparency**: Clear separation between CI logic and release logic
