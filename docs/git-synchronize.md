# Git Repository Synchronization

This document explains how to use the `git.sync.by-patches.sh` script to synchronize code between repositories. The script applies patches from one source repository to a subdirectory in a target monorepo, preserving commit history.

## Overview

The synchronization process occurs in two main phases:

1. **Preparation Phase**: Generate patches and a commit log from the source repository
2. **Application Phase**: Apply these patches to a subdirectory in the target monorepo

## Prerequisites

- Git command-line tool (version 2.x.x or later)
- GNU grep (ggrep, version 3.x or later)
- GNU sed (gsed, version 4.x or later)
- GNU awk (gawk, version 5.x.x or later)
- Configure Git user identity in the target repository:
  ```bash
  git config user.name "Your Name"
  git config user.email "your.email@example.com"
  ```

## Methods for Generating Patches

There are two primary ways to generate patches:

1. **Using the integrated `--patches` flag (recommended)** - Automatically generates patches and changes.log
2. **Manual preparation** - Generate patches and changes.log yourself

### 1. Using the Integrated `--patches` Flag (Recommended)

The `git.sync.by-patches.sh` script now includes a `--patches N` flag that automates patch generation and synchronization in one step:

```bash
# From the monorepo root directory
./bin/git.sync.by-patches.sh \
  --patches 5 \
  "/path/to/source/repo" \
  "patches" \
  "changes.log" \
  "subfolder/in/monorepo"
```

In this case, the script will:
1. Navigate to the source repository (`/path/to/source/repo`)
2. Generate patch files for the last 5 commits in the `patches` directory
3. Create a `changes.log` file with the commit history
4. Apply these patches to the specified subdirectory in the monorepo

This approach is faster and less error-prone than manually generating patches.

### 2. Manual Patch Generation

If you prefer to generate patches manually, follow these instructions from within the source repository after switching to the correct branch and pulling the latest changes:

```bash
git checkout main  # Or your primary development branch
git pull origin main
```

#### 2.1 Patches for the Last N Commits

This method is useful when you know exactly how many recent commits you need to transfer.

##### Generate Patches

Replace `N` with the number of commits:

```bash
# Example: Get patches for the last 5 commits
N=5
git format-patch -${N} --output-directory=patches
```

This creates files like `patches/0001-....patch` through `patches/000N-....patch`.

##### Generate changes.log

Use the same `N`. The `--reverse` flag ensures the commits in the changes.log are in the same order as the patches (oldest first), which is required by the `git.sync.by-patches.sh` script:

```bash
# Example: Get log for the last 5 commits (oldest first)
N=5
git log --pretty="format:%H %s" --reverse -${N} > changes.log
```

### 2. Patches Since a Specific Date

This method is helpful for periodic synchronization (daily, weekly, etc.) when you want all commits since the last sync date.

#### Generate Patches

Replace `YYYY-MM-DD` with the date (and optional time). Git understands various date formats (e.g., "2024-10-28", "2 weeks ago", "yesterday"):

```bash
# Example: Get patches for commits since midnight on October 28th, 2024
DATE="2024-10-28"
git format-patch --since="${DATE}" --output-directory=patches
```

#### Generate changes.log

Use the same `--since` flag with `--reverse` to match patch order:

```bash
# Example: Get log for commits since midnight on October 28th, 2024 (oldest first)
DATE="2024-10-28"
git log --pretty="format:%H %s" --reverse --since="${DATE}" > changes.log
```

### 3. Patches Since a Specific Commit Hash (Recommended Method)

This is the most precise method, ensuring you only get commits after a known point in history and preventing duplicates if used correctly.

#### Find the Base Commit

To identify the correct base commit (`<last_integrated_hash>`):

1. In your target monorepo, navigate to the subdirectory where the source repository's content is located
2. Use `git log` to view the commit history of this subdirectory
3. Identify the last commit that represents a merge or integration from the source repository
4. Copy the full commit hash of this commit - this is your `<last_integrated_hash>`

#### Step-by-Step Guide to Generate Patches and Changes Log

Follow these steps in the source repository:

1. **Identify the Base Commit:**
   Determine the commit hash in the source repository that corresponds to the last change from that source repo that was successfully integrated into the target subdirectory. Let's call this `<last_integrated_hash>`. Finding this might involve inspecting the commit history of the subdirectory in the final-repo and tracing it back to the source repo.
   Example: `git log final-repo/repo1_subfolder` and find the latest relevant commit.

2. **Navigate to the Source Repository:**
   ```bash
   cd /path/to/your/source/repo1
   ```

3. **Ensure You Are on the Correct Branch and Up-to-Date:**
   ```bash
   git checkout main # Or your primary development branch
   git pull origin main
   ```

4. **Create the Patches Directory (if it doesn't exist):**
   ```bash
   mkdir -p patches
   ```

5. **Generate Patch Files (Sequential Naming):**
   Generate one patch file for each commit between `<last_integrated_hash>` and the current HEAD. The files will be named like 0001-....patch, 0002-....patch etc. Use --output-directory to place them in the 'patches' folder.

   ```bash
   git format-patch <last_integrated_hash>..HEAD --output-directory=patches
   # This creates files like patches/0001-Commit-subject.patch, patches/0002-....patch
   ```

6. **Generate the Changes Log (`changes.log`):**
   Create a log file listing the commits in the same range and same order as the generated patches. The format should be "<hash> <commit_message_subject>". Use `--reverse` to ensure the log matches the patch order (oldest first).

   ```bash
   git log --pretty="format:%H %s" --reverse <last_integrated_hash>..HEAD > changes.log
   ```

7. **Transfer Files:**
   Make the `patches` directory and `changes.log` file accessible to the synchronization script, either by copying them or providing the correct path when running the script.
   Example paths used in script args: `/path/to/source/repo1/patches` and `/path/to/source/repo1/changes.log`

#### Generate Patches (Simplified)

```bash
# Example: Get patches for commits after abc1234
HASH="abc1234"
git format-patch ${HASH}..HEAD --output-directory=patches
```

#### Generate changes.log (Simplified)

Use the same commit range with `--reverse`:

```bash
# Example: Get log for commits after abc1234 (oldest first)
HASH="abc1234"
git log --pretty="format:%H %s" --reverse ${HASH}..HEAD > changes.log
```

## Using the Synchronization Script

### Standard Usage (With Pre-Generated Patches)

If you've generated patches manually, you can use the `git.sync.by-patches.sh` script to apply them to your target monorepo:

```bash
# Run from the ROOT directory of your target monorepo
./bin/git.sync.by-patches.sh \
  "source-repo-name" \
  "/path/to/source/repo/patches" \
  "/path/to/source/repo/changes.log" \
  "subfolder/in/monorepo"
```

### Automated Patch Generation and Application

To generate patches and apply them in a single command, use the `--patches` flag:

```bash
# Run from the ROOT directory of your target monorepo
./bin/git.sync.by-patches.sh \
  --patches 5 \
  "/path/to/source/repo" \
  "patches" \
  "changes.log" \
  "subfolder/in/monorepo"
```

With this method, the first parameter is the path to the source repository on disk instead of just a name for logging.

### Important Notes

- Always run the script from the **root directory** of your target monorepo
- Ensure the paths to the patches directory and changes.log file are correct and accessible
- Use relative paths when possible for better portability
- Use the `--dry-run` flag to preview changes without applying them
- Use the `--silent-git` flag to minimize Git command output

## Process Flow

1. The script validates inputs and dependencies
2. Each commit from the changes.log is processed sequentially
3. The script checks if each commit has already been applied to avoid duplicates
4. Patches are applied with proper directory prefixing
5. Changes are staged and committed with the original commit message
6. A summary is provided upon completion

By following this process, you maintain a clean and traceable history between repositories while keeping the target monorepo's structure intact.