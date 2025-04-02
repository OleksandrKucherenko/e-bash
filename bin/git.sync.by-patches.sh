#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-04-02
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# shellcheck disable=SC2155
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.scripts" && pwd)"

# Load e-bash dependencies management
# shellcheck disable=SC1090 source=../.scripts/_colors.sh
source /dev/null
# shellcheck disable=SC1090 source=../.scripts/_dependencies.sh
source "${E_BASH}/_dependencies.sh"
# shellcheck disable=SC1090 source=../.scripts/_logger.sh
source "${E_BASH}/_logger.sh"

# Initialize logger for this script
logger "sync" "$@" && logger:prefix "sync" "[${cl_blue}sync${cl_reset}] " && logger:redirect "sync" ">&2"
logger "error" "$@" && logger:prefix "error" "[${cl_red}error${cl_reset}] " && logger:redirect "error" ">&2"
logger "info" "$@" && logger:prefix "info" "[${cl_cyan}info${cl_reset}] " && logger:redirect "info" ">&2"
logger "success" "$@" && logger:prefix "success" "[${cl_green}success${cl_reset}] " && logger:redirect "success" ">&2"
logger "warning" "$@" && logger:prefix "warning" "[${cl_yellow}warning${cl_reset}] " && logger:redirect "warning" ">&2"

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

readonly VERSION="1.0.0"

## Error codes
readonly WRONG_PARAMS_NUMBER=1 # Error code for wrong number of parameters

## DRY_RUN flag - when true, commands will be printed but not executed
DRY_RUN=false

## Flag for controlling git command output verbosity
SILENT_GIT=false

# --- Function Definitions ---

# Function to verify dependencies
# Returns:
#   none
function verify_dependencies() {
  echo:Sync "Verifying dependencies..."

  # Git is required for all operations
  dependency git "2.*.*" "brew install git"
  dependency ggrep "3.*" "brew install grep"
  dependency gsed "4.*" "brew install gnu-sed"
  dependency gawk "5.*.*" "brew install gawk"
}

# Function to show progress percentage
# Arguments:
#   $1: current (number)
#   $2: total (number)
function show_progress() {
  local current=$1
  local total=$2
  local width=50
  local percent=$((current * 100 / total))
  local completed=$((width * current / total))

  # Build progress bar
  local progress=""
  for ((i = 0; i < completed; i++)); do
    progress+="#"
  done
  for ((i = completed; i < width; i++)); do
    progress+=" "
  done

  # Print progress bar with percentage
  printf "\r[%s] %d%% (%d/%d)" "$progress" "$percent" "$current" "$total"
}

# Function to validate input parameters for patch processing
# Arguments:
#   $1: log_file (string, path to log file)
#   $2: patch_dir (string, path to patch directory)
#   $3: target_subdir (string, path to target subdirectory)
# Returns:
#   0 on success, 1 on failure
function validate_patch_inputs() {
  local log_file="$1"
  local patch_dir="$2"
  local target_subdir="$3"

  if [ ! -f "${log_file}" ]; then
    echo:Error "Log file not found: ${log_file}"
    return 1
  fi
  if [ ! -d "${patch_dir}" ]; then
    echo:Error "Patch directory not found: ${patch_dir}"
    return 1
  fi
  if [ ! -d "${target_subdir}" ]; then
    echo:Error "Target subdirectory '${target_subdir}' not found in the current directory ($(pwd))."
    echo:Sync "Make sure you are running this script from the root of the final monorepo."
    return 1
  fi

  return 0
}

# Function to find patch file by index
# Arguments:
#   $1: patch_dir (string, path to patch directory)
#   $2: patch_index (integer, 1-based index of patch to find)
# Returns:
#   Prints path to patch file, returns 0 on success, 1 if not found
function find_patch_file() {
  local patch_dir="$1"
  local patch_index="$2"

  # Find the Nth patch file (where N = patch_index) in the directory, sorted alphabetically
  local patch_file
  patch_file=$(find "${patch_dir}" -maxdepth 1 -name "*.patch" -print | sort | sed -n "${patch_index}p")

  if [ -z "${patch_file}" ] || [ ! -f "${patch_file}" ]; then
    return 1
  fi

  echo "${patch_file}"
  return 0
}

# Function to parse commit line from log
# Arguments:
#   $1: line (string, a line from the log file)
# Returns:
#   Prints hash and subject, separated by a tab character
function parse_commit_line() {
  local line="$1"
  local commit_hash
  local commit_message_subject

  # Extract commit hash (first word)
  commit_hash=$(echo "$line" | awk '{print $1}')

  # Extract commit subject (everything after the first word, removing leading space)
  commit_message_subject=$(echo "$line" | awk '{$1=""; print $0}' | sed 's/^[[:space:]]*//')

  # Output the result with a tab delimiter - will be captured by the caller
  echo "${commit_hash}"$'\t'"${commit_message_subject}"
}

# Function to check if commit is already applied
# Arguments:
#   $1: commit_message_subject (string, full commit message)
#   $2: target_subdir (string, path to target subdirectory)
# Returns:
#   Prints hash of existing commit if found, empty if not found
function is_commit_applied() {
  local commit_message_subject="$1"
  local target_subdir="$2"
  local result=""

  if [ "$DRY_RUN" = true ]; then
    echo -e "${cl_cyan}dry run: git log --grep="^${commit_message_subject}$" -F --format=%h -- "${target_subdir}"${cl_reset}" >&2
    # In dry-run mode, we simulate that no commits match
    return 0
  fi

  # Check if a commit with this exact message subject already exists
  # -F: Use fixed string matching (treat subject literally)
  # --grep="^${commit_message_subject}$": Match the entire subject line exactly
  # --format=%h: Output only the abbreviated commit hash if found
  # --: Separator indicating paths follow
  # "${target_subdir}": Limit the log search to this specific subdirectory
  result=$(git log --grep="^${commit_message_subject}$" -F --format=%h -- "${target_subdir}")

  # Output the result - will be captured by the caller
  echo "$result"
}

# Execute git command with dry-run support
# Arguments:
#   $@: All arguments are passed to git command
# Returns:
#   Command exit code or 0 if in dry-run mode
function execute_git() {
  if [ "$DRY_RUN" = true ]; then
    echo -e "${cl_cyan}dry run: git $*${cl_reset}" >&2
    return 0
  fi

  # Is immediate exit on error enabled? Remember the state
  local immediate_exit_on_error
  [[ $- == *e* ]] && immediate_exit_on_error=true || immediate_exit_on_error=false
  set +e # disable immediate exit on error

  echo -n -e "${cl_cyan}execute: git $*" >&2
  local output result
  output=$(git "$@" 2>&1)
  result=$?
  echo -e " code: ${cl_yellow}$result${cl_reset}" >&2
  [ -n "$output" ] && [ "$SILENT_GIT" = false ] && echo -e "$output" >&2

  [ "$immediate_exit_on_error" = "true" ] && set -e # recover state
  return $result
}

# Function to apply a single patch
# Arguments:
#   $1: patch_file (string, path to patch file)
#   $2: target_subdir (string, path to target subdirectory)
#   $3: commit_message_subject (string, commit message for the patch - not used here)
#   $4: commit_hash (string, original commit hash for logging)
#   $5: repo_name (string, repository name for logging)
# Returns:
#   - On success: returns 0 with no output
#   - On failure: returns 1 and outputs error info to be captured
function apply_single_patch() {
  local patch_file="$1"
  local target_subdir="$2"
  local commit_hash="$4"
  local repo_name="$5"
  local patch_basename

  patch_basename=$(basename "${patch_file}")
  echo "  Commit subject not found in ${target_subdir}. Applying patch..."

  # Step 1: Check if the patch applies cleanly
  if ! execute_git apply --check --directory="${target_subdir}" "${patch_file}"; then
    echo:Error "Patch ${patch_basename} (Commit ${commit_hash}) does not apply cleanly. Aborting ${repo_name} processing."
    # Echo the error info that will be captured as failed_patch_info
    echo "${patch_basename} (Commit ${commit_hash})"
    return 1
  fi

  # Step 2: Apply the patch
  if ! execute_git apply --directory="${target_subdir}" "${patch_file}"; then
    echo:Error "Failed to apply patch ${patch_basename} (Commit ${commit_hash}) even after check."
    echo "  Attempting to clean working directory..."
    execute_git restore "${target_subdir}"
    execute_git restore --staged "${target_subdir}"
    # Echo the error info that will be captured as failed_patch_info
    echo "${patch_basename} (Commit ${commit_hash})"
    return 1
  fi

  return 0
}

# Function to stage and commit changes after patch
# Arguments:
#   $1: target_subdir (string, path to target subdirectory)
#   $2: commit_message_subject (string, commit message)
#   $3: patch_file (string, patch file path for logging)
#   $4: commit_hash (string, original commit hash for logging)
# Returns:
#   - On success: returns 0 with no output for capturing
#   - On failure: returns 1 and outputs error info to be captured
function stage_and_commit_patch() {
  local target_subdir="$1"
  local commit_message_subject="$2"
  local patch_file="$3"
  local commit_hash="$4"
  local patch_basename

  patch_basename=$(basename "${patch_file}")

  # Stage the changes
  if ! execute_git add "${target_subdir}"; then
    echo:Error "Failed to stage changes for patch ${patch_basename} (Commit ${commit_hash})."
    echo "  Attempting to clean working directory and index..."
    execute_git restore --staged "${target_subdir}"
    execute_git restore "${target_subdir}"
    # Echo the error info that will be captured as failed_patch_info
    echo "${patch_basename} (Commit ${commit_hash})"
    return 1
  fi

  # Commit the changes
  if ! execute_git commit -m "${commit_message_subject}"; then
    echo:Error "Failed to commit changes for patch ${patch_basename} (Commit ${commit_hash})."
    echo "  Attempting to clean index..."
    execute_git restore --staged "${target_subdir}"
    # Echo the error info that will be captured as failed_patch_info
    echo "${patch_basename} (Commit ${commit_hash})"
    return 1
  fi

  echo "  ${cl_green}Successfully applied and committed patch ${patch_basename}.${cl_reset}"
  return 0
}

# Function to print summary of patch application
# Arguments:
#   $1: repo_name (string, repository name)
#   $2: applied_count (integer, number of patches applied)
#   $3: skipped_count (integer, number of patches skipped)
#   $4: failed_patch_info (string, info about failed patch if any)
# Returns:
#   0 on success, 1 if any patch failed
# Function to print summary of patch application process
# Arguments:
#   $1: repo_name (string, name of repository)
#   $2: applied_count (number, count of applied patches)
#   $3: skipped_count (number, count of skipped patches)
#   $4: failed_patch_info (string, information about failed patch if any)
# Returns:
#   0 on success, 1 if any patch failed
function print_patch_summary() {
  local repo_name="$1"
  local applied_count="$2"
  local skipped_count="$3"
  local failed_patch_info="$4"
  local status=0

  echo ""
  info:GitSync "Finished processing for ${repo_name}"
  echo:Sync "  Applied: ${applied_count}"
  echo:Sync "  Skipped: ${skipped_count}"

  if [ -n "${failed_patch_info}" ]; then
    echo:Error "FAILED on patch: ${failed_patch_info}"
    status=1
  fi

  return $status
}

# Main function to process patches for a single source repository
# Arguments:
#   $1: repo_name (string, for logging)
#   $2: patch_dir (string, path)
#   $3: log_file (string, path)
#   $4: target_subdir (string, path relative to current dir)
# Returns:
#   0 on success, 1 on failure
function apply_patches() {
  # Assign arguments to named local variables for clarity
  local repo_name="$1"
  local patch_dir="$2"
  local log_file="$3"
  local target_subdir="$4"
  local status=0

  # Initialize counters and state variables
  local applied_count=0
  local skipped_count=0
  local failed_patch_info=""
  local patch_index=0 # To track patch number for sequential files (1-based)
  local total_patches=0
  local commit_info=""
  local commit_hash=""
  local commit_message_subject=""
  local patch_file=""
  local existing_commit_hash=""
  local apply_result=""
  local commit_result=""

  # Count total patches for progress tracking
  total_patches=$(wc -l <"$log_file")

  info:GitSync "Processing patches for ${repo_name} into ${target_subdir}"

  # Validate inputs
  if ! validate_patch_inputs "$log_file" "$patch_dir" "$target_subdir"; then
    return 1
  fi

  # Process log file line by line
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines
    [ -z "$line" ] && continue

    patch_index=$((patch_index + 1))
    show_progress "$patch_index" "$total_patches"

    # Parse commit info
    commit_info=$(parse_commit_line "$line")
    commit_hash="${commit_info%%$'\t'*}"
    commit_message_subject="${commit_info#*$'\t'}"

    # Find patch file
    if ! patch_file=$(find_patch_file "$patch_dir" "$patch_index"); then
      echo ""
      echo:Warning "Could not find patch file number ${patch_index} in ${patch_dir} for commit ${commit_hash}. Skipping."
      skipped_count=$((skipped_count + 1))
      continue
    fi

    # Print info about current patch
    echo ""
    echo:Sync "Processing Commit ${commit_hash} (Patch ${patch_index}: $(basename "${patch_file}"))"
    echo:Sync "  Subject: ${commit_message_subject:0:70}..."

    # Check if commit already exists
    existing_commit_hash=$(is_commit_applied "$commit_message_subject" "$target_subdir")

    if [ -z "$existing_commit_hash" ]; then
      # Apply the patch
      if ! apply_result=$(apply_single_patch "$patch_file" "$target_subdir" "$commit_message_subject" "$commit_hash" "$repo_name"); then
        failed_patch_info="$apply_result"
        break
      fi

      # Stage and commit changes
      if ! commit_result=$(stage_and_commit_patch "$target_subdir" "$commit_message_subject" "$patch_file" "$commit_hash"); then
        failed_patch_info="$commit_result"
        break
      fi

      applied_count=$((applied_count + 1))
    else
      # Skip patch - already applied
      echo:Sync "  Skipping: Commit subject already found in history for ${target_subdir} (Example commit: ${existing_commit_hash})."
      skipped_count=$((skipped_count + 1))
    fi
  done <"${log_file}"

  # Print summary and return status
  status=$(print_patch_summary "$repo_name" "$applied_count" "$skipped_count" "$failed_patch_info")
  return $status
}

# --- Set up error handling ---

# Function to clean up on exit
# shellcheck disable=SC2317
function cleanup() {
  local exit_code=$?
  local target_dir=${ARG_TARGET_SUBDIR:-""}

  if [ -n "$target_dir" ] && [ -d "$target_dir" ]; then
    echo:Sync "Cleaning up working directory..."
    # Use execute_git to honor dry-run mode
    execute_git restore --staged "$target_dir" 2>/dev/null
    execute_git restore "$target_dir" 2>/dev/null
  fi

  echo:Sync "Script exiting with code: ${exit_code}"
  return ${exit_code}
}

# Set up trap to catch interrupts and errors
trap cleanup EXIT INT TERM

# Function to display version information
# Arguments:
#   None
# Returns:
#   None, exits with code 0
function print_version() {
  echo "version: ${VERSION}"
  exit 0
}

# Function to print usage help message
# Arguments:
#   $1: (Optional) Exit code. If provided, exits with this code after printing help
# Returns:
#   None, or exits if exit code is provided
function print_help() {
  local exit_code=$1

  echo ""
  echo "Usage: $0 [options] <RepoName> <PathToPatchDir> <PathToChangesLog> <TargetSubdir>"
  echo ""
  echo "Where:"
  echo "  <RepoName>         The name of the source repository (for logging)"
  echo "  <PathToPatchDir>   Directory containing the numbered patch files"
  echo "  <PathToChangesLog> File containing commit hashes and messages"
  echo "  <TargetSubdir>     Target subdirectory in the monorepo"
  echo ""
  echo "Options:"
  echo "  -h, --help         Show this help message and exit"
  echo "  -d, --dry-run      Show what would be done without making any changes"
  echo "  -v, --verbose      Show detailed git command output"
  echo "      --version      Show version information and exit"
  echo ""
  echo "Example:"
  echo "  $0 \"Repo1\" \"/path/to/source/repo1/patches\" \"/path/to/source/repo1/changes.log\" \"repo1_subfolder\""
  echo "  $0 --dry-run \"Repo1\" \"/path/to/source/repo1/patches\" \"/path/to/source/repo1/changes.log\" \"repo1_subfolder\""
  echo ""
  echo "Arguments:"
  echo "  <RepoName>:         A name for logging purposes (e.g., \"Repo1\"). Enclose in quotes if it contains spaces."
  echo "  <PathToPatchDir>:   Absolute or relative path to the directory containing sequentially named .patch files."
  echo "  <PathToChangesLog>: Absolute or relative path to the changes.log file (format: '<hash> <subject>')."
  echo "  <TargetSubdir>:     The subdirectory within this repository (relative path) to apply patches to."
  echo ""
  echo "Ensure you run this script from the root directory of the final monorepo."

  # If exit code was provided, exit with that code
  if [ -n "$exit_code" ]; then
    exit "$exit_code"
  fi
}

# --- Main Function ---
# Main execution function
# Arguments:
#   $1: Repository name (string)
#   $2: Path to patch directory (string)
#   $3: Path to changes log file (string)
#   $4: Target subdirectory (string)
main() {
  # First, verify dependencies
  verify_dependencies >&2 # to stderr

  # Process command line options
  while [[ $# -gt 0 ]]; do
    case $1 in
    -h | --help)
      print_help 0
      ;;
    -d | --dry-run)
      DRY_RUN=true
      shift
      ;;
    -v | --verbose)
      SILENT_GIT=false
      shift
      ;;
    --version)
      print_version
      ;;
    -*)
      echo:Error "Unknown option: $1"
      print_help $WRONG_PARAMS_NUMBER
      ;;
    *)
      # If not an option, assume it's a positional argument
      break
      ;;
    esac
  done

  # Check if the correct number of command-line arguments is provided
  if [ "$#" -ne 4 ]; then
    # Print usage instructions if arguments are incorrect and exit with error code
    print_help $WRONG_PARAMS_NUMBER
  fi

  # Assign command-line arguments to descriptive variables
  ARG_REPO_NAME="$1"
  ARG_PATCH_DIR="${2:-"patches"}"
  ARG_LOG_FILE="${3:-"commits.log"}"
  ARG_TARGET_SUBDIR="${4:-"repo1_subfolder"}"

  # --- Pre-Execution Checks and Info ---
  echo:Sync "Starting patch application process..."
  echo:Sync "Repository Name: ${ARG_REPO_NAME}"
  echo:Sync "Patch Directory: ${ARG_PATCH_DIR}"

  # Print dry-run warning if enabled
  if [ "$DRY_RUN" = true ]; then
    echo:Sync "${cl_yellow}Running in DRY-RUN mode. No changes will be made.${cl_reset}"
  fi
  echo:Sync "Log File:        ${ARG_LOG_FILE}"
  echo:Sync "Target Subdir:   ${ARG_TARGET_SUBDIR}"
  echo:Sync "Current Dir:     $(pwd)" # Verify script is running in the expected directory
  echo:Sync "(Ensure git user.name and user.email are correctly configured)"
  echo:Sync ""

  # --- Execute Patch Application ---
  # Call the main processing function with the provided arguments
  apply_patches "${ARG_REPO_NAME}" "${ARG_PATCH_DIR}" "${ARG_LOG_FILE}" "${ARG_TARGET_SUBDIR}"
  local status=$?

  # --- Post-Execution Reporting ---
  echo ""

  # Print dry-run reminder if enabled
  if [ "$DRY_RUN" = true ]; then
    echo:Info "${cl_yellow}This was a DRY-RUN. No changes were made to ${ARG_REPO_NAME}.${cl_reset}"
  fi

  # Check the exit status and report final outcome
  if [ $status -ne 0 ]; then
    echo:Error "Patch application failed for ${ARG_REPO_NAME}."
    return 1 # Return with failure code
  else
    echo:Success "Patch application process finished successfully for ${ARG_REPO_NAME}."
    return 0 # Return with success code
  fi
}

# --- Script Execution ---
# Call the main function with all command line arguments and exit with its return code
main "$@"
exit $?
