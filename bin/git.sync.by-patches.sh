#!/usr/bin/env bash
# shellcheck disable=SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-04-02
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

DEBUG=${DEBUG:-"sync,error,info,success,warning,dump"}
readonly VERSION="1.0.0"

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
logger:init sync "[${cl_blue}sync${cl_reset}] "
logger:init error "[${cl_red}errr${cl_reset}] " ">&2"
logger:init info "[${cl_cyan}info${cl_reset}] " ">&2"
logger:init success "[${cl_green}done${cl_reset}] "
logger:init warning "[${cl_yellow}warn${cl_reset}] " ">&2"
logger:init dump "${cl_gray}|${cl_reset} " ">&2"

## Error codes
readonly WRONG_PARAMS_NUMBER=1 # Error code for wrong number of parameters

## DRY_RUN flag - when true, commands will be printed but not executed
DRY_RUN=false

## Flag for controlling git command output verbosity
SILENT_GIT=false

## Number of patches to generate (when --patches is specified)
PATCHES_COUNT=0

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
#   $2: target_subdir (string, path to target subdirectory)
#   $3: patch_dir (string, path to patch directory)
# Returns:
#   0 on success, 1 on failure
function validate_patch_inputs() {
  local log_file="$1"
  local target_subdir="$2"
  local patch_dir="$3"

  if [ ! -f "${log_file}" ]; then
    echo:Error "Log file not found: ${log_file}"
    return 1
  fi
  if [ ! -d "${patch_dir}" ]; then
    echo:Error "Patch directory not found: ${patch_dir}"
    return 1
  fi

  if [ ! -d "${target_subdir}" ]; then
    echo:Warning "Target subdirectory ${cl_yellow}${target_subdir}${cl_reset} not found in the current directory (${cl_yellow}$(pwd)${cl_reset})."
    echo:Warning "Make sure you are running this script from the root of the final monorepo."
    echo:Info "Will be created the destination directory: ${cl_yellow}$(pwd)/${target_subdir}${cl_reset}"
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

  # FIXME (olku): subject should be properly escaped for using in grep command (otherwise use -F)
  # local escaped_subject=$(echo "$commit_message_subject" | gsed 's#[][\^$.|?*+(){}\\-]#\\&#g')

  # FIXME (olku): what if git contains multiple commits with the same subject?

  # Check if a commit with this exact message subject already exists
  # -F: Use fixed string matching (treat subject literally)
  # --grep="^${escaped_subject}$": Match the entire subject line exactly
  # --format=%h: Output only the abbreviated commit hash if found
  # --: Separator indicating paths follow
  # "${target_subdir}": Limit the log search to this specific subdirectory

  # we execute it anyway, its a search operation read-only and safe
  result=$(git log --grep="${commit_message_subject}" -F --format=%h -- "${target_subdir}")

  [ "$DRY_RUN" = true ] && exec:git log --grep="${commit_message_subject}" -F --format=%h -- "${target_subdir}"

  #result=$(git log --grep="${commit_message_subject}" -F --format=%h)
  #echo:Dump "found in logs: ${cl_purple}${result/$'\n'/$', '}${cl_reset}"

  # Output the result - will be captured by the caller
  echo "$result"
}

# Execute git command with dry-run support
# Arguments:
#   $@: All arguments are passed to git command
# Returns:
#   Command exit code or 0 if in dry-run mode
function exec:git() {
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
  local commit_message_subject="$3"
  local commit_hash="$4"
  local repo_name="$5"
  local patch_basename

  echo:Info "${cl_red}Applying${cl_reset}   : ${cl_yellow}${patch_file}${cl_reset}"

  patch_basename=$(basename "${patch_file}")
  echo "  Commit subject not found in ${target_subdir}. Applying patch..."

  # Step 1: Check if the patch applies cleanly
  if ! exec:git apply --check --directory="${target_subdir}" "${patch_file}"; then
    echo:Error "Patch ${patch_basename} (Commit ${commit_hash}) does not apply cleanly. Aborting ${repo_name} processing."
    # Echo the error info that will be captured as failed_patch_info
    echo "${patch_basename} (Commit ${commit_hash})"
    return 1
  fi

  # Step 2: Apply the patch
  if ! exec:git apply --directory="${target_subdir}" "${patch_file}"; then
    echo:Error "Failed to apply patch ${patch_basename} (Commit ${commit_hash}) even after check."
    echo "  Attempting to clean working directory..."
    exec:git restore "${target_subdir}"
    exec:git restore --staged "${target_subdir}"
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
  if ! exec:git add "${target_subdir}"; then
    echo:Error "Failed to stage changes for patch ${patch_basename} (Commit ${commit_hash})."
    echo "  Attempting to clean working directory and index..."
    exec:git restore --staged "${target_subdir}"
    exec:git restore "${target_subdir}"
    # Echo the error info that will be captured as failed_patch_info
    echo "${patch_basename} (Commit ${commit_hash})"
    return 1
  fi

  # Commit the changes
  if ! exec:git commit -m "${commit_message_subject}"; then
    echo:Error "Failed to commit changes for patch ${patch_basename} (Commit ${commit_hash})."
    echo "  Attempting to clean index..."
    exec:git restore --staged "${target_subdir}"
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
  echo:Sync "Finished processing for ${repo_name}"
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
#   $2: target_subdir (string, path relative to current dir)
#   $3: patch_dir (string, path)
#   $4: log_file (string, path)
# Returns:
#   0 on success, 1 on failure
function apply_patches() {
  # Assign arguments to named local variables for clarity
  local repo_name="$1"
  local target_subdir="$2"
  local patch_dir="$3"
  local log_file="$4"
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
  echo:Sync "Total patches: ${cl_green}${total_patches}${cl_reset}"

  # Validate inputs
  if ! validate_patch_inputs "$log_file" "$target_subdir" "$patch_dir"; then
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
    echo:Sync "Commit Hash: ${st_b}${commit_hash:0:7}${st_no_b} (Patch ${cl_green}${patch_index}${cl_reset}: ${cl_yellow}$(basename "${patch_file}")${cl_reset})"
    echo:Sync "Commit Subj: ${st_i}${cl_gray}${commit_message_subject:0:70}${cl_reset}${st_no_i}"

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
      local hashes=$(echo "$existing_commit_hash" | tr '\n' ',' | sed 's/,$//; s/,/, /g')
      echo:Info "${cl_gray}skipping${cl_reset}: subject found in commit(s): ${cl_purple}${hashes}${cl_reset}"
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
    # Use exec:git to honor dry-run mode
    exec:git restore --staged "$target_dir" 2>/dev/null
    exec:git restore "$target_dir" 2>/dev/null
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
  echo "  <RepoName>         The name of the source repository (for logging) or path to repository"
  echo "  <PathToPatchDir>   Directory containing the numbered patch files"
  echo "  <PathToChangesLog> File containing commit hashes and messages"
  echo "  <TargetSubdir>     Target subdirectory in the monorepo"
  echo ""
  echo "Options:"
  echo "  -h, --help         Show this help message and exit"
  echo "  -d, --dry-run      Show what would be done without making any changes"
  echo "  -v, --verbose      Show detailed git command output"
  echo "      --version      Show version information and exit"
  echo "      --patches N    Generate patches from the last N commits in RepoName repository"
  echo ""
  echo "Example:"
  echo "  $0 \"Repo1\" \"/path/to/source/repo1/patches\" \"/path/to/source/repo1/changes.log\" \"repo1_subfolder\""
  echo "  $0 --dry-run \"Repo1\" \"/path/to/source/repo1/patches\" \"/path/to/source/repo1/changes.log\" \"repo1_subfolder\""
  echo "  $0 --patches 5 \"/path/to/repo\" \"patches\" \"changes.log\" \"target_folder\""
  echo ""
  echo "Arguments:"
  echo "  <RepoName>:         A name for logging purposes or path to repository when using --patches."
  echo "                      Enclose in quotes if it contains spaces."
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

# --- Main Functions ---

# Function to generate patches from the last N commits in a repository
# Arguments:
#   $1: repo_path (string, path to repository on disk)
#   $2: patch_dir (string, output directory for patches)
#   $3: log_file (string, output file for commit log)
#   $4: count (integer, number of commits to process)
# Returns:
#   0 on success, 1 on failure
function generate_patches() {
  local repo_path="$1"
  local patch_dir="$2"
  local log_file="$3"
  local count="$4"
  local current_dir
  local status=0

  # Save current directory to return to it later
  current_dir=$(pwd)

  absolute_repo_path=$(cd "${repo_path}" && pwd)
  echo:Sync "Generating ${cl_green}${count}${cl_reset} patches from last commits of the repo: ${cl_yellow}${absolute_repo_path}${cl_reset}"

  # Verify repository path exists and is a git repository
  if [ ! -d "${repo_path}" ]; then
    echo:Error "Repository path does not exist: ${repo_path}"
    return 1
  fi

  # Change to repository directory
  cd "${repo_path}" || {
    echo:Error "Failed to change to repository directory: ${repo_path}"
    return 1
  }

  # Verify it's a git repository
  if [ ! -d ".git" ] && ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo:Error "Not a git repository: ${repo_path}"
    cd "${current_dir}" || true
    return 1
  fi

  # Create patches directory if it doesn't exist
  mkdir -p "${patch_dir}" || {
    echo:Error "Failed to create patches directory: ${patch_dir}"
    cd "${current_dir}" || true
    return 1
  }

  # Remove any existing patches
  rm -f "${patch_dir}"/*.patch 2>/dev/null

  # Generate patches
  if ! git format-patch -${count} --output-directory="${patch_dir}" | log:Dump; then
    echo:Error "Failed to generate patches"
    status=1
  else
    echo:Success "Successfully generated ${cl_green}$(wc -l <"${log_file}")${cl_reset} patches in ${cl_yellow}${patch_dir}${cl_reset}"
  fi

  # Generate changes.log
  if ! git log --pretty="format:%H %s" --reverse -${count} >"${log_file}"; then
    echo:Error "Failed to generate commit log"
    status=1
  else
    echo:Success "Successfully generated commit log at ${cl_yellow}${log_file}${cl_reset}"
  fi

  # Change back to original directory
  cd "${current_dir}" || true

  return ${status}
}

# Main execution function
# Arguments:
#   $1: Repository name (string) or path to repository when using --patches
#   $2: Target subdirectory (string)
#   $3: Path to patch directory (string)
#   $4: Path to changes log file (string)
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
      echo:Info "${cl_yellow}Running in DRY-RUN mode. No changes will be made.${cl_reset}"
      shift
      ;;
    -v | --verbose)
      SILENT_GIT=false
      shift
      ;;
    --version)
      print_version
      ;;
    --patches)
      shift
      if [[ $1 =~ ^[0-9]+$ ]]; then
        PATCHES_COUNT="$1"
        shift
      else
        echo:Error "--patches <N> requires a numeric argument"
        print_help $WRONG_PARAMS_NUMBER
      fi
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

  # Assign command-line arguments to descriptive variables
  ARG_REPO_NAME="$1"
  ARG_TARGET_SUBDIR="${2:-"repo1"}"
  ARG_PATCH_DIR="${3:-"patches"}"
  ARG_LOG_FILE="${4:-"${ARG_PATCH_DIR}/commits.log"}"

  # If we're generating patches
  if [ "$PATCHES_COUNT" -gt 0 ]; then
    # In this case, ARG_REPO_NAME is a path to the repository
    if ! generate_patches "${ARG_REPO_NAME}" "${ARG_PATCH_DIR}" "${ARG_LOG_FILE}" "$PATCHES_COUNT"; then
      echo:Error "Failed to generate patches"
      return 1
    fi

    # Extract repo name for logging from repo path
    local repo_dir_name
    repo_dir_name=$(basename "${ARG_REPO_NAME}")
    ARG_REPO_NAME="${repo_dir_name}"
    exit 0
  fi

  # verify that ARG_REPO_NAME is provided
  if [ -z "$ARG_REPO_NAME" ]; then
    echo:Error "Repository name is required"
    print_help $WRONG_PARAMS_NUMBER
  elif [ "$ARG_REPO_NAME" == "." ]; then
    # resolve . to current directory name
    ARG_REPO_NAME=$(basename "$(pwd)")
  fi

  # --- Pre-Execution Checks and Info ---
  echo:Sync "Starting patch application process..."
  echo:Sync "Repository Name: ${cl_green}${ARG_REPO_NAME}${cl_reset}"
  echo:Sync "Patch Directory: ${cl_yellow}${ARG_PATCH_DIR}${cl_reset}"

  echo:Sync "Log File:        ${cl_yellow}${ARG_LOG_FILE}${cl_reset}"
  echo:Sync "Target Subdir:   ${cl_yellow}${ARG_TARGET_SUBDIR}${cl_reset}"
  echo:Sync "Current Dir:     ${cl_yellow}$(pwd)${cl_reset}" # Verify script is running in the expected directory
  echo:Sync ""

  # --- Execute Patch Application ---
  # Call the main processing function with the provided arguments
  apply_patches "${ARG_REPO_NAME}" "${ARG_TARGET_SUBDIR}" "${ARG_PATCH_DIR}" "${ARG_LOG_FILE}"
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
