# _self-update.sh

**Self-Update System for e-bash Scripts**

This module provides automatic update detection and file-by-file library updates
for projects using e-bash scripts library.

## References

- demo: demo.selfupdate.sh
- bin: install.e-bash.sh (uses self-update for upgrades)
- documentation: docs/public/version-up.md

## Module Globals

- E_BASH - Path to .scripts directory
- __E_BASH - Home directory name (".e-bash")
- __E_ROOT - Full path to ~/.e-bash
- __REPO_URL - Repository URL (https://github.com/OleksandrKucherenko/e-bash.git)
- __REMO_REMOTE - Remote name ("e-bash")
- __REPO_MASTER - Master branch ("master")
- __REPO_V1 - First version tag ("v1.0.0")
- __WORKTREES - Worktrees directory (".versions")
- __VERSION_PATTERN - Version tag pattern ("v?${SEMVER}")
- __REPO_MAPPING - Associative array: version -> tag mapping
- __REPO_VERSIONS - Array of sorted versions

---

## Functions

<!-- TOC -->

- [_self-update.sh](#_self-updatesh)
    - [`array:qsort`](#arrayqsort)
    - [`compare:versions`](#compareversions)
    - [`path:resolve`](#pathresolve)
    - [`self-update`](#self-update)
    - [`self-update:dependencies`](#self-updatedependencies)
    - [`self-update:file:hash`](#self-updatefilehash)
    - [`self-update:initialize`](#self-updateinitialize)
    - [`self-update:rollback:backup`](#self-updaterollbackbackup)
    - [`self-update:rollback:version`](#self-updaterollbackversion)
    - [`self-update:self:version`](#self-updateselfversion)
    - [`self-update:unlink`](#self-updateunlink)
    - [`self-update:version:bind`](#self-updateversionbind)
    - [`self-update:version:find`](#self-updateversionfind)
    - [`self-update:version:find:highest_tag`](#self-updateversionfindhighest_tag)
    - [`self-update:version:find:latest_stable`](#self-updateversionfindlatest_stable)
    - [`self-update:version:get`](#self-updateversionget)
    - [`self-update:version:get:first`](#self-updateversiongetfirst)
    - [`self-update:version:get:latest`](#self-updateversiongetlatest)
    - [`self-update:version:has`](#self-updateversionhas)
    - [`self-update:version:hash`](#self-updateversionhash)
    - [`self-update:version:remove`](#self-updateversionremove)
    - [`self-update:version:resolve`](#self-updateversionresolve)
    - [`self-update:version:tags`](#self-updateversiontags)

<!-- /TOC -->

---

### array:qsort

QuickSort implementation for array sorting

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `compare` | string | required | Comparison function name |
| `array` | variadic | required | Array elements to sort |

#### Globals

- reads/listen: none
- mutate/publish: none

#### Returns

- Echoes sorted array elements

#### Usage

```bash
array:qsort compare_func "item3" "item1" "item2"
```

---

### compare:versions

Compare two version strings using semver constraints

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `$1` | string | required | First version string (for < comparison) |
| `$2` | string | required | Second version string (for > comparison) |

#### Globals

- reads/listen: semver:constraints:simple
- mutate/publish: none

#### Returns

- 0 if $1 < $2
- 1 otherwise

#### Usage

```bash
compare:versions "1.0.0" "2.0.0"
```

---

### path:resolve

Resolve file path relative to caller script location

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `file` | string | required | File path to resolve |
| `working_dir` | string | default: $PWD | Base directory for relative paths |

#### Globals

- reads/listen: BASH_SOURCE
- mutate/publish: none

#### Returns

- Echoes absolute path to file

#### Usage

```bash
path:resolve "../config.json" "$PWD"
```

---

### self-update

Main entry point for self-update functionality
Checks for updates and binds script to newer version if available.
Compares current version with target version using hash verification.

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `version_expression` | string | required | Version constraint (e.g., "^1.0.0") |
| `file` | string | optional | Path to script file (default: ${BASH_SOURCE[0]}) |

#### Globals

- reads/listen: BASH_SOURCE
- mutate/publish: none (creates symlink, backup, .sha1 files)

#### Side Effects

- Initializes git repo
- Fetches latest version
- Creates worktree for target version
- Updates symlink and hash files if out of date

#### Usage

```bash
self-update "^1.0.0"
self-update "latest" "./script.sh"
```

#### Returns

- 0 on success or if up-to-date
Recommended pattern:
  trap "self-update '^1.0.0'" EXIT

---

### self-update:dependencies

Check and declare script dependencies for self-update functionality

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- reads/listen: none
- mutate/publish: none

#### Side Effects

- Declares required dependencies (bash, git, coreutils tools)

#### Usage

```bash
self-update:dependencies
```

#### Returns

- 0 on success (via dependency function calls)

---

### self-update:file:hash

Calculate SHA1 hash of script file content
Creates or updates .sha1 file for caching. Uses numbered backups for hash changes.

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `filepath` | string | optional | Path to script file (default: ${BASH_SOURCE[0]}) |

#### Globals

- reads/listen: BASH_SOURCE
- mutate/publish: none (creates/updates .sha1 file)

#### Side Effects

- Creates or updates {file}.sha1
- Creates numbered backup when hash changes

#### Returns

- Echoes SHA1 hash

#### Usage

```bash
hash=$(self-update:file:hash)
hash=$(self-update:file:hash "./script.sh")
```

---

### self-update:initialize

Initialize git repo and extract first version
Sets up ~/.e-bash as git repo with remote and extracts v1.0.0.

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- reads/listen: __E_ROOT, __REPO_URL, __REMO_REMOTE, __REPO_MASTER, __WORKTREES
- mutate/publish: none (creates git repo and worktree)

#### Side Effects

- Creates ~/.e-bash directory
- Initializes git repo if not exists
- Adds remote and fetches
- Creates .versions/ worktree for v1.0.0

#### Usage

```bash
self-update:initialize
```

#### Returns

- 0 on success

---

### self-update:rollback:backup

Restore script file from backup
Finds the most recent backup file (.~N~) and restores it.

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `file` | string | optional | Path to script file (default: ${BASH_SOURCE[0]}) |

#### Globals

- reads/listen: BASH_SOURCE
- mutate/publish: none (replaces file with backup)

#### Side Effects

- Replaces original file with latest backup

#### Usage

```bash
self-update:rollback:backup
self-update:rollback:backup "./script.sh"
```

#### Returns

- 0 on success

---

### self-update:rollback:version

Rollback script to specified version
Extracts version if needed and creates symlink binding.

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `version` | string | optional | Version tag to rollback to (default: v1.0.0) |
| `file` | string | optional | Path to script file (default: ${BASH_SOURCE[0]}) |

#### Globals

- reads/listen: __REPO_V1, BASH_SOURCE
- mutate/publish: none (creates symlink)

#### Side Effects

- Creates worktree if version not present
- Creates symlink binding

#### Usage

```bash
self-update:rollback:version "v1.0.0"
self-update:rollback:version "v1.2.3" "./script.sh"
```

#### Returns

- 0 on success

---

### self-update:self:version

Extract version of current script
Determines script version from symlink binding or copyright comments.

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `file` | string | optional | Path to script file (default: ${BASH_SOURCE[0]}) |

#### Globals

- reads/listen: __VERSION_PATTERN, __REPO_V1, BASH_SOURCE
- mutate/publish: none

#### Returns

- Echoes version tag (e.g., "v1.0.0")

#### Usage

```bash
version=$(self-update:self:version)
version=$(self-update:self:version "./script.sh")
```

---

### self-update:unlink

Convert symlink to regular file copy
Replaces symbolic link with actual file content by copying target.

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `filepath` | string | optional | Path to symlink (default: ${BASH_SOURCE[0]}) |

#### Globals

- reads/listen: BASH_SOURCE
- mutate/publish: none (replaces symlink with file)

#### Side Effects

- Removes symlink and copies target file

#### Usage

```bash
self-update:unlink
self-update:unlink "./script.sh"
```

#### Returns

- 0 on success, 1 if not a symlink or on copy failure

---

### self-update:version:bind

Bind script file to specified version
Creates symlink from script to version-specific file in ~/.e-bash/.versions/

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `version` | string | required | Version tag to bind to |
| `filepath` | string | optional | Path to script file (default: ${BASH_SOURCE[0]}) |

#### Globals

- reads/listen: __E_ROOT, __WORKTREES, __REPO_V1, BASH_SOURCE
- mutate/publish: none (creates symlink)

#### Side Effects

- Creates numbered backup of original file
- Creates symlink to versioned file

#### Usage

```bash
self-update:version:bind "v1.0.0"
self-update:version:bind "v1.2.3" "./my-script.sh"
shellcheck disable=SC2088
```

---

### self-update:version:find

Find highest version tag matching semver constraints

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `constraints` | string | required | Semver constraint expression |

#### Globals

- reads/listen: __REPO_VERSIONS, __REPO_MAPPING
- mutate/publish: none

#### Returns

- Echoes tag name (e.g., "v1.2.3") or empty if not found

#### Usage

```bash
tag=$(self-update:version:find "^1.0.0")
tag=$(self-update:version:find "~2.1.0")
```

---

### self-update:version:find:highest_tag

Find highest version tag in git repo

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- reads/listen: __REPO_VERSIONS, __REPO_MAPPING
- mutate/publish: none

#### Returns

- Echoes highest version tag name

#### Usage

```bash
latest=$(self-update:version:find:highest_tag)
```

---

### self-update:version:find:latest_stable

Find latest stable version tag (no pre-release like alpha, beta, rc)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- reads/listen: __REPO_VERSIONS, __REPO_MAPPING
- mutate/publish: none

#### Returns

- Echoes highest stable version tag name
- Returns empty if no stable version found

#### Usage

```bash
stable=$(self-update:version:find:latest_stable)
```

---

### self-update:version:get

Extract specified version from git repo to local disk
Creates git worktree for the specified version in ~/.e-bash/.versions/

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `tag_or_branch` | string | required | Git tag or branch name |

#### Globals

- reads/listen: __E_ROOT, __WORKTREES
- mutate/publish: none (creates worktree directory)

#### Side Effects

- Creates .versions/{tag_or_branch} directory
- Runs git worktree add command

#### Usage

```bash
self-update:version:get "v1.0.0"
```

#### Returns

- 0 on success, exit code from git on failure
shellcheck disable=SC2088

---

### self-update:version:get:first

Extract first version (v1.0.0) to local disk

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- reads/listen: __REPO_V1
- mutate/publish: none

#### Side Effects

- Creates worktree for first version if not exists

#### Usage

```bash
self-update:version:get:first
```

#### Returns

- 0 on success

---

### self-update:version:get:latest

Extract latest version to local disk

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- reads/listen: none
- mutate/publish: none

#### Side Effects

- Creates worktree for latest version if not exists

#### Usage

```bash
self-update:version:get:latest
```

#### Returns

- 0 on success

---

### self-update:version:has

Check if version is already extracted to local disk

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `tag_or_branch` | string | required | Git tag or branch name |

#### Globals

- reads/listen: __E_ROOT, __WORKTREES
- mutate/publish: none

#### Returns

- 0 if version exists locally, 1 otherwise

#### Usage

```bash
if self-update:version:has "v1.0.0"; then echo "exists"; fi
```

---

### self-update:version:hash

Calculate SHA1 hash of versioned script file
Like self-update:file:hash but reads file from version folder.

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `filepath` | string | optional | Path to script file (default: ${BASH_SOURCE[0]}) |
| `version` | string | required | Version tag to read from |

#### Globals

- reads/listen: __E_ROOT, __WORKTREES, BASH_SOURCE
- mutate/publish: none

#### Returns

- Echoes SHA1 hash of versioned file

#### Usage

```bash
hash=$(self-update:version:hash "./script.sh" "v1.0.0")
shellcheck disable=SC2088
```

---

### self-update:version:remove

Remove version from local disk
Deletes the git worktree and directory for specified version.

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `version` | string | required | Version tag to remove |

#### Globals

- reads/listen: __E_ROOT, __WORKTREES
- mutate/publish: none (removes worktree directory)

#### Side Effects

- Removes .versions/{version} directory
- Runs git worktree remove command

#### Usage

```bash
self-update:version:remove "v1.0.0"
```

#### Returns

- 0 on success

---

### self-update:version:resolve

Resolve version expression to actual tag/branch
Converts various version notations to concrete git references.

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `version_expression` | string | required | Version constraint or notation |

#### Globals

- reads/listen: none
- mutate/publish: none
Supported expressions:
- "latest" - latest stable (no prerelease)
- "*" or "next" - highest version including prereleases
- "branch:{name}" - specific branch
- "tag:{name}" - specific tag
- "^1.0.0", "~1.0.0" - semver constraints

#### Returns

- Echoes resolved tag/branch name

#### Usage

```bash
version=$(self-update:version:resolve "latest")
version=$(self-update:version:resolve "branch:master")
```

---

### self-update:version:tags

Extract all version tags from git repo into global arrays

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- reads/listen: __VERSION_PATTERN, __REPO_URL
- mutate/publish: __REPO_VERSIONS, __REPO_MAPPING

#### Side Effects

- Populates global __REPO_VERSIONS array with sorted versions
- Populates global __REPO_MAPPING associative array (version -> tag)

#### Usage

```bash
self-update:version:tags
```

#### Returns

- 0 on success

