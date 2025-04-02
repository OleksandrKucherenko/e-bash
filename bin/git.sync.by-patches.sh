#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-04-02
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Script to apply patches from ONE source repository (e.g., repo1 OR repo2)
# into a specific subdirectory of this final monolithic repository.
#
# !!! IMPORTANT !!!
# This script MUST be executed from the ROOT directory of the final monorepo.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# --- Prerequisites ---
# 1. Ensure 'git' command-line tool is installed.
# 2. Ensure you are in the root directory of the final monorepo when running this script.
# 3. Ensure the patch directory and log file (generated from the source repo) exist
#    at the paths specified in the command-line arguments.
# 4. IMPORTANT: Configure your Git user name and email in this repository
#    or globally, as these will be used for the new commits:
#      git config user.name "Your Name"
#      git config user.email "your.email@example.com"
# 5. Make sure the script has execute permissions: chmod +x apply_patches_single.sh

# --- How to Generate Patches and changes.log in the Source Repository ---
#
# Before running this script, you need to generate the patch files and the log file
# from the *source* repository (e.g., repo1).
#
# 1. Identify the Base Commit:
#    Determine the commit hash in the *source* repository (e.g., repo1) that corresponds
#    to the *last* change from that source repo that was successfully integrated into
#    the target subdirectory (e.g., final-repo/repo1_subfolder). Let's call this
#    <last_integrated_hash>. Finding this might involve inspecting the commit history
#    of the subdirectory in the final-repo and tracing it back to the source repo.
#    Example: `git log final-repo/repo1_subfolder` and find the latest relevant commit.
#
# 2. Navigate to the Source Repository:
#    cd /path/to/your/source/repo1
#
# 3. Ensure You Are on the Correct Branch and Up-to-Date:
#    git checkout main # Or your primary development branch
#    git pull origin main
#
# 4. Create the Patches Directory (if it doesn't exist):
#    mkdir -p patches
#
# 5. Generate Patch Files (Sequential Naming):
#    Generate one patch file for each commit between <last_integrated_hash> and the
#    current HEAD. The files will be named like 0001-....patch, 0002-....patch etc.
#    Use --output-directory to place them in the 'patches' folder.
#
#    git format-patch <last_integrated_hash>..HEAD --output-directory=patches
#    # This creates files like patches/0001-Commit-subject.patch, patches/0002-....patch
#
# 6. Generate the Changes Log (`changes.log`):
#    Create a log file listing the commits in the *same range* and *same order*
#    as the generated patches. The format should be "<hash> <commit_message_subject>".
#    Use `--reverse` to ensure the log matches the patch order (oldest first).
#
#    git log --pretty="format:%H %s" --reverse <last_integrated_hash>..HEAD > changes.log
#
# 7. Transfer Files:
#    Make the `patches` directory and `changes.log` file accessible to this script,
#    either by copying them or providing the correct path when running the script.
#    Example paths used in script args: /path/to/source/repo1/patches and /path/to/source/repo1/changes.log
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# --- Function Definition ---

# Function to process patches for a single source repository
# Arguments:
#   $1: repo_name (string, for logging)
#   $2: patch_dir (string, path)
#   $3: log_file (string, path)
#   $4: target_subdir (string, path relative to current dir)
# Returns:
#   0 on success, 1 on failure
apply_patches() {
  # Assign arguments to named local variables for clarity
  local repo_name="$1"
  local patch_dir="$2"
  local log_file="$3"
  local target_subdir="$4"

  # Initialize counters and state variables
  local applied_count=0
  local skipped_count=0
  local failed_patch_info=""
  local patch_index=0 # To track patch number for sequential files (1-based index)

  echo "--- Processing patches for ${repo_name} into ${target_subdir} ---"

  # --- Input Validations ---
  if [ ! -f "${log_file}" ]; then
    echo "ERROR: Log file not found: ${log_file}"
    return 1
  fi
  if [ ! -d "${patch_dir}" ]; then
    echo "ERROR: Patch directory not found: ${patch_dir}"
    return 1
  fi
  if [ ! -d "${target_subdir}" ]; then
    echo "ERROR: Target subdirectory '${target_subdir}' not found in the current directory ($(pwd))."
    echo "Make sure you are running this script from the root of the final monorepo."
    return 1
  fi

  # --- Process Log File Line by Line ---
  # Reads the log file, expecting "<hash> <commit message subject>" per line.
  # Handles the last line even if it doesn't end with a newline.
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines
    if [ -z "$line" ]; then
      continue
    fi

    patch_index=$((patch_index + 1)) # Increment patch counter (1-based)

    # --- Parse Log Line ---
    # Extract commit hash (first word)
    local commit_hash=$(echo "$line" | awk '{print $1}')
    # Extract commit subject (everything after the first word, removing leading space)
    local commit_message_subject=$(echo "$line" | awk '{$1=""; print $0}' | sed 's/^[[:space:]]*//')

    # --- Find Corresponding Patch File ---
    # Find the Nth patch file (where N = patch_index) in the directory, sorted alphabetically.
    # This assumes `git format-patch` default sequential naming (0001-..., 0002-...).
    local patch_file=$(find "${patch_dir}" -maxdepth 1 -name "*.patch" -print | sort | sed -n "${patch_index}p")

    # Validate patch file existence
    if [ -z "${patch_file}" ]; then
      echo "  WARNING: Could not find patch file number ${patch_index} in ${patch_dir} for commit ${commit_hash}. Skipping."
      skipped_count=$((skipped_count + 1))
      continue # Skip to the next line in the log file
    fi
    if [ ! -f "${patch_file}" ]; then
      # This check is somewhat redundant due to `find` but good for robustness
      echo "  WARNING: Patch file not found: ${patch_file} (for commit ${commit_hash}). Skipping."
      skipped_count=$((skipped_count + 1))
      continue # Skip to the next line in the log file
    fi

    echo "Processing Commit ${commit_hash} (Patch ${patch_index}: $(basename "${patch_file}"))"
    echo "  Subject: ${commit_message_subject:0:70}..." # Log truncated subject

    # --- Check if Commit Already Applied ---
    # Check if a commit with this *exact* message subject already exists in the
    # history of the target subdirectory.
    # -F: Use fixed string matching (treat subject literally).
    # --grep="^${commit_message_subject}$": Match the entire subject line exactly.
    # --format=%h: Output only the abbreviated commit hash if found.
    # --: Separator indicating paths follow.
    # "${target_subdir}": Limit the log search to this specific subdirectory.
    local existing_commit_hash=$(git log --grep="^${commit_message_subject}$" -F --format=%h -- "${target_subdir}")

    if [ -z "$existing_commit_hash" ]; then
      # --- Apply Patch ---
      echo "  Commit subject not found in ${target_subdir}. Applying patch..."

      # Step 1: Check if the patch applies cleanly without modifying files.
      # --directory: Apply patch relative to this subdirectory.
      if ! git apply --check --directory="${target_subdir}" "${patch_file}"; then
        echo "  ERROR: Patch $(basename "${patch_file}") (Commit ${commit_hash}) does not apply cleanly. Aborting ${repo_name} processing."
        failed_patch_info="$(basename "${patch_file}") (Commit ${commit_hash})"
        # No cleanup needed as --check doesn't modify files
        break # Stop processing this repo's patches
      fi

      # Step 2: Apply the patch for real.
      if ! git apply --directory="${target_subdir}" "${patch_file}"; then
        echo "  ERROR: Failed to apply patch $(basename "${patch_file}") (Commit ${commit_hash}) even after check. Aborting ${repo_name} processing."
        failed_patch_info="$(basename "${patch_file}") (Commit ${commit_hash})"
        # Attempt to clean the working directory from the potentially partially applied patch
        echo "  Attempting to clean working directory..."
        git restore "${target_subdir}" # Discard changes in the working tree for the subdir
        # If the failed apply somehow staged files (less common with `git apply`), unstage them:
        git restore --staged "${target_subdir}"
        break # Stop processing this repo's patches
      fi

      # Step 3: Stage the changes within the specific subdirectory.
      if ! git add "${target_subdir}"; then
        echo "  ERROR: Failed to stage changes for patch $(basename "${patch_file}") (Commit ${commit_hash}). Aborting ${repo_name} processing."
        failed_patch_info="$(basename "${patch_file}") (Commit ${commit_hash})"
        # Attempt cleanup before breaking
        echo "  Attempting to clean working directory and index..."
        git restore --staged "${target_subdir}" # Unstage
        git restore "${target_subdir}"          # Discard working dir changes
        break                                   # Stop processing this repo's patches
      fi

      # Step 4: Commit the staged changes.
      # Use the original commit subject from the log file as the new commit message.
      # Git will use the user.name and user.email configured for this repo.
      if ! git commit -m "${commit_message_subject}"; then
        echo "  ERROR: Failed to commit changes for patch $(basename "${patch_file}") (Commit ${commit_hash}). Aborting ${repo_name} processing."
        failed_patch_info="$(basename "${patch_file}") (Commit ${commit_hash})"
        # Attempt cleanup before breaking (unstage the files)
        echo "  Attempting to clean index..."
        git restore --staged "${target_subdir}"
        break # Stop processing this repo's patches
      fi

      echo "  Successfully applied and committed patch $(basename "${patch_file}")."
      applied_count=$((applied_count + 1))
    else
      # --- Skip Patch ---
      # Found existing commit(s) with the same subject in the target subdir history
      echo "  Skipping: Commit subject already found in history for ${target_subdir} (Example commit: ${existing_commit_hash})."
      skipped_count=$((skipped_count + 1))
    fi

  done <"${log_file}" # Feed the log file into the while loop

  # --- Report Summary ---
  echo "--- Finished processing for ${repo_name} ---"
  echo "  Applied: ${applied_count}"
  echo "  Skipped: ${skipped_count}"
  if [ -n "${failed_patch_info}" ]; then
    echo "  FAILED on patch: ${failed_patch_info}"
    return 1 # Indicate failure
  fi
  return 0 # Indicate success
}

# --- Main Execution Block ---

# Check if the correct number of command-line arguments is provided
if [ "$#" -ne 4 ]; then
  # Print usage instructions if arguments are incorrect
  echo "Usage: $0 <RepoName> <PathToPatchDir> <PathToChangesLog> <TargetSubdir>"
  echo ""
  echo "Example: $0 \"Repo1\" \"/path/to/source/repo1/patches\" \"/path/to/source/repo1/changes.log\" \"repo1_subfolder\""
  echo ""
  echo "Arguments:"
  echo "  <RepoName>:         A name for logging purposes (e.g., \"Repo1\"). Enclose in quotes if it contains spaces."
  echo "  <PathToPatchDir>:   Absolute or relative path to the directory containing sequentially named .patch files."
  echo "  <PathToChangesLog>: Absolute or relative path to the changes.log file (format: '<hash> <subject>')."
  echo "  <TargetSubdir>:     The subdirectory within this repository (relative path) to apply patches to."
  echo ""
  echo "Ensure you run this script from the root directory of the final monorepo."
  exit 1 # Exit with an error code
fi

# Assign command-line arguments to descriptive variables
ARG_REPO_NAME="$1"
ARG_PATCH_DIR="$2"
ARG_LOG_FILE="$3"
ARG_TARGET_SUBDIR="$4"

# --- Pre-Execution Checks and Info ---
echo "Starting patch application process..."
echo "Repository Name: ${ARG_REPO_NAME}"
echo "Patch Directory: ${ARG_PATCH_DIR}"
echo "Log File:        ${ARG_LOG_FILE}"
echo "Target Subdir:   ${ARG_TARGET_SUBDIR}"
echo "Current Dir:     $(pwd)" # Verify script is running in the expected directory
echo "(Ensure git user.name and user.email are correctly configured)"
echo ""

# --- Execute Patch Application ---
# Call the main processing function with the provided arguments
apply_patches "${ARG_REPO_NAME}" "${ARG_PATCH_DIR}" "${ARG_LOG_FILE}" "${ARG_TARGET_SUBDIR}"
# Capture the exit status of the function
status=$?

# --- Post-Execution Reporting ---
# Check the exit status and report final outcome
if [ $status -ne 0 ]; then
  echo ""
  echo "ERROR: Patch application failed for ${ARG_REPO_NAME}."
  exit 1 # Exit script with failure code
else
  echo ""
  echo "Patch application process finished successfully for ${ARG_REPO_NAME}."
  exit 0 # Exit script with success code
fi
