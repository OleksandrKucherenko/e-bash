#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034,SC2059

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

################################################################################
# MODULE: _self-update.sh
#
# DESCRIPTION:
#   Self-update functionality for projects using e-bash library. Provides
#   automatic version management with git worktrees, semantic versioning
#   constraints, file-by-file updates, hash verification, and rollback
#   capabilities. Designed for zero-downtime updates with safety guarantees.
#
# FEATURES:
#   - Semantic version constraint resolution (^, ~, ranges, latest, *)
#   - Git worktree-based version isolation at ~/.e-bash/.versions/{tag}
#   - Numbered backup files (.~N~) for safe rollback
#   - SHA1 hash verification to detect file changes
#   - Symbolic link management with auto-conversion support
#   - Branch/tag pinning for development and production scenarios
#   - Multi-file independent versioning
#   - Idempotent operations (safe to run repeatedly)
#
# ARCHITECTURE:
#   - Global repository: ~/.e-bash/ (git repo tracking e-bash releases)
#   - Version worktrees: ~/.e-bash/.versions/{tag}/ (isolated checkouts)
#   - Project files: Symlinks to versioned files in worktrees
#   - Backup files: Numbered (.~1~, .~2~, etc.) for rollback
#
# COMPATIBILITY:
#   Works with bin/install.e-bash.sh - both use ${HOME}/.e-bash/ global directory.
#   - install.e-bash.sh: Handles local (project) and global (HOME) installations
#   - self-update.sh: Manages global part only (manages ~/.e-bash/.versions/)
#   Self-update creates symlinks from project files to versioned global files.
#
# GLOBAL VARIABLES:
#   __E_BASH          - Constant ".e-bash" directory name
#   __E_ROOT          - Absolute path to ~/.e-bash/
#   __REPO_URL        - e-bash repository URL
#   __REMO_REMOTE     - Git remote name ("e-bash")
#   __REPO_MASTER     - Default branch name ("master")
#   __REPO_V1         - First version tag ("v1.0.0")
#   __WORKTREES       - Worktree directory name (".versions")
#   __VERSION_PATTERN - Regex pattern for semver tags
#   __REPO_MAPPING    - Associative array (version -> tag name)
#   __REPO_VERSIONS   - Sorted array of version strings
#
# SUPPORTED VERSION EXPRESSIONS:
#   - 'latest'           - latest stable version (no pre-release tags)
#   - '*' or 'next'      - highest version tag (including alpha, beta, rc)
#   - 'branch:{name}'    - update from specific branch
#   - 'tag:{name}'       - update to specific tag
#   - '^1.0.0'           - minor and patch releases (>= 1.0.0 < 2.0.0)
#   - '~1.0.0'           - patch releases only (>= 1.0.0 < 1.1.0)
#   - '>1.0.0 <=1.5.0'   - version range with comparison operators
#   - '1.0.0'            - exact version match
#
# RECOMMENDED USAGE PATTERN:
#   The recommended approach is to invoke self-update on script exit:
#     source "$E_BASH/_self-update.sh"
#     source "$E_BASH/_traps.sh"
#     trap:on "self-update '^1.0.0'" EXIT
#
# HOW IT WORKS:
#   1. Initializes/updates git repository at ~/.e-bash/
#   2. Fetches latest tags and branches from remote
#   3. Extracts requested version as git worktree to .versions/{tag}/
#   4. Resolves version expression to actual tag/branch name
#   5. Compares current file hash with target version hash
#   6. Creates numbered backup and symlink if update needed
#   7. Verifies update success via hash comparison
#
# PUBLIC API (5 functions):
#   self-update                 - Main entry point for version updates
#   self-update:version:bind    - Bind file to specific version
#   self-update:rollback:backup - Restore from numbered backup
#   self-update:rollback:version - Rollback to specific version
#   self-update:unlink          - Convert symlink to regular file
#
# USAGE:
#   source "$E_BASH/_self-update.sh"
#
#   # Update to latest stable version
#   self-update "latest"
#
#   # Update with version constraint
#   self-update "^1.0.0"  # Allow minor/patch updates
#   self-update "~1.5.0"  # Allow patch updates only
#
#   # Pin to specific version or branch
#   self-update "tag:v1.0.0"      # Exact version
#   self-update "branch:master"   # Track branch
#
#   # Update specific file
#   self-update "latest" ".scripts/_logger.sh"
#
#   # Rollback operations
#   self-update:rollback:version "v1.0.0"  # Rollback to version
#   self-update:rollback:backup            # Restore from backup
#
#   # Unlink file (convert to regular file)
#   self-update:unlink ".scripts/_logger.sh"
#
# SEE ALSO:
#   demos/demo.selfupdate.sh - Comprehensive usage examples
#   demos/demo.self-healing.sh - Auto-installation pattern
#   spec/self_update_spec.sh - Unit tests and behavior examples
#   docs/public/version-up.md - Version management documentation
################################################################################

# shellcheck disable=SC2155
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1090 source=./_commons.sh
# shellcheck disable=SC1090 source=./_logger.sh
# shellcheck disable=SC1090 source=./_dependencies.sh
source "$E_BASH/_dependencies.sh"
# shellcheck disable=SC1090 source=./_semver.sh
source "$E_BASH/_semver.sh"

readonly __E_BASH=".e-bash"
readonly __E_ROOT="${HOME}/${__E_BASH}"
readonly __REPO_URL="https://github.com/OleksandrKucherenko/e-bash.git"
readonly __REMO_REMOTE="e-bash"
readonly __REPO_MASTER="master"
readonly __REPO_V1="v1.0.0"
readonly __WORKTREES=".versions"
readonly __VERSION_PATTERN="v?${SEMVER}"
declare -g -A __REPO_MAPPING=()  # version-to-tag mapping
declare -g -a __REPO_VERSIONS=() # sorted array of versions

################################################################################
# Function: self-update:dependencies
# Description: Validates all required dependencies for self-update functionality.
#              Checks for bash 5+, git 2+, and GNU coreutils (gln, gmv, gcp)
#              with --backup=numbered support for safe file operations.
# Arguments:
#   None
# Returns:
#   exit code: 0 on success, non-zero if dependencies not met
# Side Effects:
#   - Calls dependency() which may exit script on missing tools
#   - May trigger auto-install in CI environments
# Example:
#   self-update:dependencies
################################################################################
function self-update:dependencies() {
  dependency bash "5.*.*" "brew install bash"
  dependency git "2.*.*" "brew install git"

  # commands that support --backup=numbered option
  dependency gln "9.2" "brew install coreutils"
  dependency gmv "9.2" "brew install coreutils"
  dependency gcp "9.2" "brew install coreutils"
}

################################################################################
# Function: compare:versions
# Description: Compares two semantic version strings to determine ordering.
#              Used internally by array:qsort for version sorting.
# Arguments:
#   $1 - First version string (e.g., "1.0.0")
#   $2 - Second version string (e.g., "2.0.0")
# Returns:
#   exit code: 0 if $1 < $2, 1 otherwise
# Example:
#   compare:versions "1.0.0" "2.0.0"  # returns 0 (true)
#   compare:versions "2.0.0" "1.0.0"  # returns 1 (false)
################################################################################
function compare:versions() {
  (semver:constraints:simple "$1<$2") && return 0 || return 1
}

################################################################################
# Function: array:qsort
# Description: Generic quicksort implementation for sorting arrays using a
#              custom comparison function. Recursively partitions array around
#              pivot element. Used to sort version tags.
# Arguments:
#   $1 - Comparison function name (e.g., "compare:versions")
#   $@ - Array elements to sort
# Returns:
#   stdout: Sorted array elements (one per line)
#   exit code: 0 (always succeeds)
# Example:
#   sorted=($(array:qsort "compare:versions" "2.0.0" "1.0.0" "1.5.0"))
#   # Result: ("1.0.0" "1.5.0" "2.0.0")
################################################################################
function array:qsort() {
  local compare=$1 && shift
  local array=("$@")
  local length=${#array[@]}

  if ((length == 0)); then
    return
  fi

  if ((length == 1)); then
    echo "${array[@]}"
    return
  fi

  local pivot="${array[0]}"
  local left=()
  local right=()

  for ((i = 1; i < length; i++)); do
    if eval "$compare" "${array[i]}" "${pivot}"; then
      left+=("${array[i]}")
    else
      right+=("${array[i]}")
    fi
  done

  array:qsort "$compare" "${left[@]}"
  echo "$pivot"
  array:qsort "$compare" "${right[@]}"
}

################################################################################
# Function: path:resolve
# Description: Internal function that resolves a file path to its absolute path,
#              trying multiple resolution strategies: absolute path, current
#              working directory relative, caller script directory relative, and
#              stack-based resolution. Emits debug output via echo:Version.
# Arguments:
#   $1 - File path to resolve (can be absolute, relative, or just filename)
#   $2 - Working directory (optional, defaults to $PWD)
# Returns:
#   stdout: Absolute path to the file
#   exit code: 0 if file found, 1 if file not found
# Side Effects:
#   - Emits debug messages to stderr via echo:Version
#   - Changes directory temporarily during resolution
# Example:
#   full_path=$(path:resolve "./_colors.sh")
#   full_path=$(path:resolve "bin/script.sh" "/home/user/project")
################################################################################
function path:resolve() {
  local file="$1"
  local working_dir=${2:-"$PWD"}

  local file_name="$(basename "${file}")"
  local dir_name="$(dirname "${file}")"
  local path_cwd="$(cd "${working_dir}/${dir_name}" 2>/dev/null && pwd)"
  local path_file_dir="$(cd "${dir_name}" 2>/dev/null && pwd)"

  # NOTE: we take path of caller script, not the current script
  local top="${#BASH_SOURCE[@]}" && ((top--))
  local path_stack_dir="$(cd "$(dirname "${BASH_SOURCE[$top]}")/${dir_name}" 2>/dev/null && pwd)"

  echo:Version "stack:" "${BASH_SOURCE[@]}" >&2
  echo:Version "file: ${cl_blue}${file}${cl_reset}" >&2
  echo:Version "dir param : ${cl_blue}${working_dir}${cl_reset}" >&2

  #  echo:Version "dir cwd   : ${cl_blue}${path_cwd}${cl_reset}" >&2
  #  echo:Version "dir stack : ${cl_blue}${path_stack_dir}${cl_reset}" >&2
  #  echo:Version "dir file  : ${cl_blue}${path_file_dir}${cl_reset}" >&2

  # Working Directory Relative or Absolute Path
  if [[ -f "${path_file_dir}/${file_name}" ]]; then
    echo:Version "file ~> ${cl_yellow}${path_file_dir}/${file_name}${cl_reset}" >&2
    echo "${path_file_dir}/${file_name}"
  elif [[ -f "${path_cwd}/${file_name}" ]]; then
    echo:Version "cwd ~> ${cl_yellow}${path_cwd}/${file_name}${cl_reset}" >&2
    echo "${path_cwd}/${file_name}"
  elif [[ -f "${path_stack_dir}/${file_name}" ]]; then
    echo:Version "stack ~> ${cl_yellow}${path_stack_dir}/${file_name}${cl_reset}" >&2
    echo "${path_stack_dir}/${file_name}"
  elif [[ -f "${file}" ]]; then
    echo:Version "FALLBACK" >&2
    echo "${file}"
  else
    echo:Version "ERROR: file not found (${working_dir}): ${cl_red}${file}${cl_reset}" >&2
    echo "${file}" # fallback to not existing file
    return 1
  fi
}

################################################################################
# Function: self-update:version:tags
# Description: Internal function that extracts all version tags from the git
#              repository and populates global arrays __REPO_VERSIONS (sorted
#              versions) and __REPO_MAPPING (version to tag name mapping).
#              Only extracts tags matching semver pattern.
# Arguments:
#   None
# Returns:
#   exit code: 0 on success, 1 if git operations fail
# Side Effects:
#   - Populates __REPO_VERSIONS array with sorted version strings
#   - Populates __REPO_MAPPING associative array (version -> tag)
#   - Changes to __E_ROOT directory temporarily
# Example:
#   self-update:version:tags
#   echo "${__REPO_VERSIONS[@]}"  # List all versions
#   echo "${__REPO_MAPPING["1.0.0"]}"  # Get tag for version 1.0.0
################################################################################
function self-update:version:tags() {
  pushd "${__E_ROOT}" &>/dev/null || exit 1

  # reset global arrays
  __REPO_VERSIONS=() && __REPO_MAPPING=()

  local line="" version=""
  local versions=()

  while IFS= read -r line; do
    [ -z "$line" ] && continue # skip empty line

    version=$(echo "$line" | sed -E "s/^v?//gi") # remove `v` prefix if exists

    versions+=("$version")
    __REPO_MAPPING["$version"]="$line"
  done < <(git tag -l --sort="v:refname" | grep -i -E "^${__VERSION_PATTERN}\$")

  # create sorted array of versions
  while IFS= read -r line; do
    [[ -z "${line//[[:space:]]/}" ]] && continue # skip empty line
    __REPO_VERSIONS+=("$line")
  done < <(array:qsort "compare:versions" "${versions[@]}")

  popd &>/dev/null || return 1
}

################################################################################
# Function: self-update:version:find
# Description: Internal function that finds the highest version tag matching
#              given semantic version constraints. Iterates through sorted
#              versions in reverse order to find first match.
# Arguments:
#   $1 - Version constraint expression (e.g., "^1.0.0", "~2.1.0", ">1.0.0 <2.0.0")
# Returns:
#   stdout: Matching tag name (e.g., "v1.5.3")
#   exit code: 0 (always succeeds, may return empty string if no match)
# Side Effects:
#   - Calls self-update:version:tags if __REPO_VERSIONS is empty
# Example:
#   tag=$(self-update:version:find "^1.0.0")  # Find highest 1.x.x version
#   tag=$(self-update:version:find "~2.1.0")  # Find highest 2.1.x version
################################################################################
function self-update:version:find() {
  local constraints="$1"

  # extract tags if they are not extracted yet
  [ ${#__REPO_VERSIONS[@]} -eq 0 ] && self-update:version:tags

  # iterate __REPO_VERSIONS and filter only versions that match
  # version expression, do it in reverse order

  local version=""
  local last=${#__REPO_VERSIONS[@]} && ((last--))
  local iLast # FIXME: do not reuse `i` variable, its a global variable
  for ((iLast = last; iLast >= 0; iLast--)); do
    version="${__REPO_VERSIONS[$iLast]}"

    if semver:constraints "${version}" "${constraints}"; then
      # found the highest version tag that matches version expression
      #      echo "${version}"
      break
    fi
  done

  # resolve version to real tag name
  echo "${__REPO_MAPPING[$version]}"
}

################################################################################
# Function: self-update:version:find:highest_tag
# Description: Internal function that finds the highest version tag in the
#              repository, including pre-release versions (alpha, beta, rc).
#              Returns the absolute latest tag available.
# Arguments:
#   None
# Returns:
#   stdout: Highest version tag name (e.g., "v2.0.0-beta.1")
#   exit code: 0 (always succeeds)
# Side Effects:
#   - Calls self-update:version:tags if __REPO_VERSIONS is empty
# Example:
#   latest=$(self-update:version:find:highest_tag)  # May include pre-release
################################################################################
function self-update:version:find:highest_tag() {
  # extract tags if they are not extracted yet
  [ ${#__REPO_VERSIONS[@]} -eq 0 ] && self-update:version:tags

  # version tag pattern: v${MAJOR}.${MINOR}.${PATCH}[-${STAGE}[.${IDENTITY}]][+${METADATA}], based on https://semver.org/
  # Example: 1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-alpha.beta < 1.0.0-beta < 1.0.0-beta.2 < 1.0.0-beta.11 < 1.0.0-rc.1 < 1.0.0

  # last element of array is the highest version tag
  local last=${#__REPO_VERSIONS[@]} && ((last--))
  local version="${__REPO_VERSIONS[$last]}"

  # old: local version=$(git tag -l --sort="v:refname" | grep -i -E "^v[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?(-[a-zA-Z]+(\.[a-z0-9]+)?)?$" | sort -V | tail -n1)

  # resolve version to real tag name
  echo "${__REPO_MAPPING[$version]}"
}

################################################################################
# Function: self-update:version:find:latest_stable
# Description: Internal function that finds the latest stable version tag,
#              excluding pre-release versions (alpha, beta, rc). Iterates from
#              highest to lowest to find first version without dash separator.
# Arguments:
#   None
# Returns:
#   stdout: Latest stable version tag name (e.g., "v1.5.0")
#   exit code: 0 (always succeeds)
# Side Effects:
#   - Calls self-update:version:tags if __REPO_VERSIONS is empty
# Example:
#   stable=$(self-update:version:find:latest_stable)  # Only stable versions
################################################################################
function self-update:version:find:latest_stable() {
  # extract tags if they are not extracted yet
  [ ${#__REPO_VERSIONS[@]} -eq 0 ] && self-update:version:tags

  # iterate from highest to lowest to find first stable version (no pre-release)
  local version=""
  local last=${#__REPO_VERSIONS[@]} && ((last--))
  local iStable # FIXME: do not reuse `i` variable, its a global variable
  for ((iStable = last; iStable >= 0; iStable--)); do
    version="${__REPO_VERSIONS[$iStable]}"

    # check if version has no pre-release part (no dash after version numbers)
    if ! echo "$version" | grep -E -- "-" >/dev/null; then
      # found the highest stable version
      break
    fi
  done

  # resolve version to real tag name
  echo "${__REPO_MAPPING[$version]}"
}

################################################################################
# Function: self-update:version:has
# Description: Internal function that checks if a specific version/tag/branch
#              has already been extracted to local disk as a git worktree.
# Arguments:
#   $1 - Tag or branch name to check (e.g., "v1.0.0", "master")
# Returns:
#   exit code: 0 if version exists locally, 1 otherwise
# Example:
#   if self-update:version:has "v1.0.0"; then
#     echo "Version already extracted"
#   fi
################################################################################
function self-update:version:has() {
  local tag_or_branch="$1"
  [ -d "${__E_ROOT}/${__WORKTREES}/${tag_or_branch}" ]
}

################################################################################
# Function: self-update:version:get
# Description: Internal function that extracts a specific version/tag/branch
#              from the git repository to local disk using git worktree.
#              Creates isolated working directory at ~/.e-bash/.versions/{tag}.
# Arguments:
#   $1 - Tag or branch name to extract (e.g., "v1.0.0", "master")
# Returns:
#   exit code: 0 on success, 1 if git operations fail
# Side Effects:
#   - Creates git worktree at ${__E_ROOT}/${__WORKTREES}/{tag}
#   - Emits status message via echo:Version
#   - Changes to __E_ROOT directory temporarily
# Example:
#   self-update:version:get "v1.0.0"
#   # Creates: ~/.e-bash/.versions/v1.0.0/
################################################################################
# shellcheck disable=SC2088
function self-update:version:get() {
  local tag_or_branch="$1"
  local worktree="./${__WORKTREES}/${tag_or_branch}"
  local worktree_home="~/${__E_BASH}/${__WORKTREES}/${tag_or_branch}"

  pushd "${__E_ROOT}" &>/dev/null || exit 1

  # extract version
  git worktree add --checkout "$worktree" "${tag_or_branch}" &>/dev/null

  popd &>/dev/null || exit 1

  echo:Version "e-bash version ${cl_blue}${tag_or_branch}${cl_reset} ~ ${cl_yellow}${worktree_home}${cl_reset}"
}

################################################################################
# Function: self-update:version:get:first
# Description: Internal function that extracts the first/baseline version
#              (v1.0.0) to local disk. Used as fallback/rollback version.
# Arguments:
#   None
# Returns:
#   exit code: 0 on success, 1 if extraction fails
# Side Effects:
#   - Calls self-update:version:get if version not already present
#   - Emits status message via echo:Version
# Example:
#   self-update:version:get:first
################################################################################
function self-update:version:get:first() {
  local version="${__REPO_V1}"
  echo:Version "Extract first version: ${cl_blue}${version}${cl_reset}"
  self-update:version:has "${version}" || self-update:version:get "${version}"
}

################################################################################
# Function: self-update:version:get:latest
# Description: Internal function that extracts the highest version tag
#              (including pre-releases) to local disk. Used by self-update
#              to ensure latest version is always available.
# Arguments:
#   None
# Returns:
#   exit code: 0 on success, 1 if extraction fails
# Side Effects:
#   - Calls self-update:version:find:highest_tag to identify latest version
#   - Calls self-update:version:get if version not already present
#   - Emits status message via echo:Version
# Example:
#   self-update:version:get:latest
################################################################################
function self-update:version:get:latest() {
  local version=$(self-update:version:find:highest_tag)
  echo:Version "Extract latest version: ${cl_blue}${version}${cl_reset}"
  self-update:version:has "${version}" || self-update:version:get "${version}"
}

################################################################################
# Function: self-update:version:remove
# Description: Internal function that removes a specific version worktree from
#              local disk. Cleans up both git worktree and filesystem directory.
# Arguments:
#   $1 - Version tag to remove (e.g., "v1.0.0")
# Returns:
#   exit code: 0 on success, 1 if removal fails
# Side Effects:
#   - Removes git worktree for the version
#   - Deletes directory ${__E_ROOT}/${__WORKTREES}/{version}
#   - Emits status message via echo:Version
#   - Changes to __E_ROOT directory temporarily
# Example:
#   self-update:version:remove "v1.0.0-alpha"
################################################################################
function self-update:version:remove() {
  local version="$1"

  pushd "${__E_ROOT}" &>/dev/null || exit 1

  # remove version
  git worktree remove "./${__WORKTREES}/${version}" &>/dev/null

  rm -rf "./${__WORKTREES}/${version}"

  popd &>/dev/null || exit 1

  echo:Version "e-bash version ${cl_blue}${version}${cl_reset} - ${cl_red}REMOVED${cl_reset}"
}

################################################################################
# Function: self-update:version:bind
# Description: PUBLIC API - Binds a script file to a specific version by
#              creating a numbered-backup symlink from the file to the version
#              worktree. Supports files in .scripts/, bin/, demos/, and project
#              root. Skips if already bound to same version or file not found.
# Arguments:
#   $1 - Version tag to bind to (e.g., "v1.0.0")
#   $2 - File path to bind (optional, defaults to ${BASH_SOURCE[0]})
# Returns:
#   exit code: 0 on success or skip, 1 if binding fails
# Side Effects:
#   - Creates numbered backup (.~N~) of existing file
#   - Replaces file with symlink to versioned file
#   - Emits status messages via echo:Version
# Example:
#   self-update:version:bind "v1.5.0" ".scripts/_logger.sh"
#   self-update:version:bind "v2.0.0"  # Uses current script
################################################################################
# shellcheck disable=SC2088
function self-update:version:bind() {
  local version="$1"
  local filepath=${2:-"${BASH_SOURCE[0]}"}      # can be full or relative path
  local full_path=$(path:resolve "${filepath}") # resolve to absolute path
  local file_dir="$(dirname "${full_path}")"    # full path to script folder
  local file_name="$(basename "${full_path}")"  # filename
  local subs_dir=$(basename "${file_dir}")      # parent folder name

  # fallback to ".scripts/" folder
  local version_file="${__E_ROOT}/${__WORKTREES}/${version}/.scripts/${file_name}"

  # NOTE (olku): we support only one level of sub-folders,
  #   like `bin/`, `demos/`, `.scripts/` and project root folder.
  # TODO (olku): `bin/profiler/` nested folders are not supported yet.
  if [[ -f "${__E_ROOT}/${__WORKTREES}/${version}/${subs_dir}/${file_name}" ]]; then
    version_file="${__E_ROOT}/${__WORKTREES}/${version}/${subs_dir}/${file_name}"
  elif [[ -f "${__E_ROOT}/${__WORKTREES}/${version}/${file_name}" ]]; then
    version_file="${__E_ROOT}/${__WORKTREES}/${version}/${file_name}"
  fi

  # get path with ~ instead of $HOME
  local version_dir_home=$(cd "$(dirname "$version_file")" && dirs +0)

  # check is script filepath is already bind to the version or not
  if [[ -L "${full_path}" ]]; then
    local link=$(readlink "${full_path}")
    # Expand ~ to $HOME for consistent path matching
    link="${link/#\~/$HOME}"
    # NOTE: Hardcoded ".versions" with escaped dot for proper regex matching.
    # If __WORKTREES value changes, update this pattern and the test in
    # spec/self_update_version_spec.sh will fail to alert about the mismatch.
    # Extract version: match everything between /.versions/ and the next /
    local bind_version=$(echo "$link" | sed -E 's|.*/\.versions/([^/]+)/.*|\1|')

    if [[ "${bind_version}" == "${version}" ]]; then
      echo:Version "e-bash binding: ${cl_yellow}skip${cl_reset} ${cl_blue}${file_name}${cl_reset} same version"
      return 0
    fi
  fi

  # if script filepath does not exist in specific version folder
  if [[ ! -f "${version_file}" ]]; then
    echo:Version "e-bash binding: ${cl_red}skip${cl_reset}" \
      "${cl_blue}${file_name}${cl_reset} not found in" \
      "${cl_yellow}${version_dir_home}${cl_reset}"

    return 0
  fi

  # expected creation of the backup filepath: ${script_file}.~([0-9]+)~
  gln --symbolic --force --backup=numbered \
    "${version_file}" \
    "${full_path}"

  echo:Version "e-bash binding: ${cl_blue}${file_name}${cl_reset}" \
    "~>" "${cl_yellow}${version_dir_home}/${file_name}${cl_reset}"
}

################################################################################
# Function: self-update:self:version
# Description: Internal function that extracts the version of a script file by
#              checking: 1) symlink target (if linked to worktree), or
#              2) copyright comment header (## Version: x.x.x), or
#              3) defaults to v1.0.0 fallback.
# Arguments:
#   $1 - File path to check (optional, defaults to ${BASH_SOURCE[0]})
# Returns:
#   stdout: Version tag (e.g., "v1.5.0")
#   exit code: 0 (always succeeds)
# Side Effects:
#   - Emits debug messages via echo:Version to stderr
# Example:
#   version=$(self-update:self:version ".scripts/_logger.sh")
#   current=$(self-update:self:version)  # Current script version
################################################################################
function self-update:self:version() {
  local file=${1:-"${BASH_SOURCE[0]}"}
  local script_file="$(basename "${file}")"
  local script_folder="$(cd "$(dirname "${file}")" && pwd)"

  # check is script file is already bind to the version or not
  if [[ -L "${script_folder}/${script_file}" ]]; then # symbolic link
    local link=$(readlink "${script_folder}/${script_file}")
    local bind_version=$(echo "$link" | sed -E "s/.*\/\.versions\/(.*)\/\.scripts\/.*/\1/")

    echo:Version "binding: ${cl_blue}${script_file}${cl_reset} to ${cl_yellow}${bind_version}${cl_reset}" >&2
    echo "${bind_version}" # expected tag: v1.0.0
  else                     # file content
    # try to extract version from script copyright comments, expected `## Version: 1.0.0`
    local file_version=$(
      grep -E "^## Version: ${__VERSION_PATTERN}$" "${script_folder}/${script_file}" \
        | head -n 1 \
        | sed -E "s/^## Version: (.*)$/\1/"
    )

    if [ -n "${file_version}" ]; then
      echo:Version "copyright: ${cl_blue}${script_file}${cl_reset} to ${cl_yellow}${file_version}${cl_reset}" >&2
      # if first char of version is `v` then print version, otherwise add 'v' prefix
      # expected pure version: 1.0.0 (without `v` prefix)
      [[ "${file_version:0:1}" == "v" ]] && echo "${file_version}" || echo "v${file_version}"
    else
      echo:Version "fallback: ${cl_blue}${script_file}${cl_reset} to ${cl_yellow}${__REPO_V1}${cl_reset}" >&2
      # no version comments found, return default version
      echo "${__REPO_V1}" # expected tag: v1.0.0
    fi
  fi

  # TODO (olku): should we try to extract version from git tags if file is a part of repo?
}

################################################################################
# Function: self-update:file:hash
# Description: Internal function that calculates SHA1 hash of a file and caches
#              result in a .sha1 file with numbered backup. Used to verify if
#              file content has changed.
# Arguments:
#   $1 - File path to hash (optional, defaults to ${BASH_SOURCE[0]})
# Returns:
#   stdout: SHA1 hash string (40 hex characters)
#   exit code: 0 (always succeeds)
# Side Effects:
#   - Creates/updates {file}.sha1 cache file with numbered backup
#   - Emits debug messages via echo:Version to stderr
# Example:
#   hash=$(self-update:file:hash ".scripts/_logger.sh")
#   # Also creates: .scripts/_logger.sh.sha1
################################################################################
function self-update:file:hash() {
  local filepath=${1:-"${BASH_SOURCE[0]}"}

  # convert to fully resolved path
  local name="$(basename "${filepath}")"
  local file="$(cd "$(dirname "${filepath}")" && pwd)/$(basename "${filepath}")"

  # calculate hash of the script file content, SHA1, ref: https://manned.org/shasum
  local hash=$(shasum --algorithm 1 "${file}" | awk '{print $1}')

  # detect hash file changes and print a debug message
  local create_hash_file=false
  if [[ "$(cat "${file}.sha1" 2>/dev/null)" != "${hash}" ]]; then
    echo:Version "hash: ${cl_yellow}${hash}${cl_reset} of ${cl_blue}${file}${cl_reset}" >&2
    create_hash_file=true
  else
    echo:Version "hash: ${cl_yellow}${hash}${cl_reset} of ${cl_blue}${file}${cl_reset} from ${cl_green}${name}.sha1${cl_reset}" >&2
  fi

  # make a hash file if it does not exist, otherwise create a numbered backup file
  # for existing hash file and replace it
  if $create_hash_file; then
    echo "${hash}" >"${file}.sha1.tmp"
    gmv --backup=numbered --force "${file}.sha1.tmp" "${file}.sha1"
  fi

  echo "${hash}"
}

################################################################################
# Function: self-update:version:hash
# Description: Internal function that calculates SHA1 hash of a file from a
#              specific version worktree. Used to compare current file against
#              versioned file to detect if update needed.
# Arguments:
#   $1 - File path (relative to project structure)
#   $2 - Version tag (e.g., "v1.5.0")
# Returns:
#   stdout: SHA1 hash string (40 hex characters)
#   exit code: 0 (always succeeds)
# Side Effects:
#   - Calls self-update:file:hash on versioned file
#   - Emits debug messages via echo:Version to stderr
# Example:
#   version_hash=$(self-update:version:hash ".scripts/_logger.sh" "v2.0.0")
################################################################################
# shellcheck disable=SC2088
function self-update:version:hash() {
  local filepath=${1:-"${BASH_SOURCE[0]}"} # can be full or relative path
  local version=${2}

  local full_path=$(path:resolve "${filepath}") # resolve to absolute path
  local file_dir="$(dirname "${full_path}")"    # full path to script folder
  local file_name="$(basename "${full_path}")"  # filename
  local subs_dir=$(basename "${file_dir}")      # parent folder name

  # in case of troubles fallback to ".scripts/" folder
  local version_file="${__E_ROOT}/${__WORKTREES}/${version}/.scripts/${file_name}"

  # NOTE (olku): we support only one level of sub-folders,
  #   like `bin/`, `demos/`, `.scripts/` and project root folder.
  # TODO (olku): `bin/profiler/` nested folders are not supported yet.
  if [[ -f "${__E_ROOT}/${__WORKTREES}/${version}/${subs_dir}/${file_name}" ]]; then
    version_file="${__E_ROOT}/${__WORKTREES}/${version}/${subs_dir}/${file_name}"
  elif [[ -f "${__E_ROOT}/${__WORKTREES}/${version}/${file_name}" ]]; then
    version_file="${__E_ROOT}/${__WORKTREES}/${version}/${file_name}"
  fi

  echo:Version "hash versioned file: ${cl_blue}${version_file}${cl_reset}"

  self-update:file:hash "${version_file}"
}

################################################################################
# Function: self-update:rollback:backup
# Description: PUBLIC API - Restores a file from its latest numbered backup
#              (.~N~ format). Finds highest numbered backup and moves it back
#              to original filename. Useful for undoing failed updates.
# Arguments:
#   $1 - File path to restore (optional, defaults to ${BASH_SOURCE[0]})
# Returns:
#   exit code: 0 on success, non-zero if no backup found
# Side Effects:
#   - Moves backup file to original location (destructive)
#   - Emits status messages via echo:Version
# Example:
#   self-update:rollback:backup ".scripts/_logger.sh"
#   # Restores from: .scripts/_logger.sh.~3~ (highest numbered backup)
################################################################################
function self-update:rollback:backup() {
  local file=${1:-"${BASH_SOURCE[0]}"}

  local script_file="$(basename "${file}")"
  local script_folder="$(cd "$(dirname "${file}")" && pwd)"

  # find the latest backup file by pattern ${script_file}.~([0-9]+)~
  # Use numeric sort (-n) with tilde delimiter to work on both BSD and GNU sort
  local backup_file=$(find "${script_folder}" -maxdepth 1 -name "${script_file}.~*~" | sort -t~ -k2 -n | tail -n1)
  echo:Version "Found backup file: ${cl_yellow}${backup_file:-"<none>"}${cl_reset}"

  # restore script file from backup file, use move command for recovering
  if [[ -n "${backup_file}" ]]; then
    mv -f "${backup_file}" "${script_folder}/${script_file}"
  fi
}

################################################################################
# Function: self-update:rollback:version
# Description: PUBLIC API - Rolls back a file to a specific version. Ensures
#              version is available locally, then binds file to that version.
#              Creates a new backup of current file before rollback.
# Arguments:
#   $1 - Version tag to rollback to (optional, defaults to v1.0.0)
#   $2 - File path to rollback (optional, defaults to ${BASH_SOURCE[0]})
# Returns:
#   exit code: 0 on success, non-zero if rollback fails
# Side Effects:
#   - Calls self-update:version:get to extract version if needed
#   - Calls self-update:version:bind to perform rollback
#   - Creates numbered backup of current file
# Example:
#   self-update:rollback:version "v1.0.0" ".scripts/_logger.sh"
#   self-update:rollback:version "v2.0.0"  # Rollback current script
################################################################################
function self-update:rollback:version() {
  local version=${1:-"${__REPO_V1}"}
  local file=${2:-"${BASH_SOURCE[0]}"}

  # rollback to specified version
  self-update:version:has "${version}" || self-update:version:get "${version}"

  self-update:version:bind "${version}" "${file}"

  # NOTE: rollback to specific version does not remove backup files, it will actually create a new one
}

################################################################################
# Function: self-update:unlink
# Description: PUBLIC API - Converts a symbolic link to a regular file by
#              copying the link target content. Useful for freezing a file at
#              current version or preparing for manual edits.
# Arguments:
#   $1 - File path to unlink (optional, defaults to ${BASH_SOURCE[0]})
# Returns:
#   exit code: 0 on success or if not a link, 1 if copy operation fails
# Side Effects:
#   - Removes symbolic link
#   - Creates regular file copy of link target
#   - Emits status messages via echo:Version
# Example:
#   self-update:unlink ".scripts/_logger.sh"
#   # Converts symlink to regular file copy
################################################################################
function self-update:unlink() {
  local filepath=${1:-"${BASH_SOURCE[0]}"}

  # convert to fully resolved path
  local name="$(basename "${filepath}")"
  local file_dir="$(cd "$(dirname "${filepath}")" && pwd)"
  local file="${file_dir}/$(basename "${filepath}")"

  if ! find "$file_dir" -type l -name "$name" -maxdepth 1 | grep .; then
    echo:Version "e-bash unlink: ${cl_blue}${name}${cl_reset} - ${cl_red}NOT A LINK${cl_reset}"
    return 0
  fi

  local link_target=$(greadlink --canonicalize-existing --no-newline --verbose "$file")

  local cmd=""
  if [[ -d "$link_target" ]]; then # directory
    cmd="rm -f '$file' && cp -r '$link_target' '$file'"
  else # file
    cmd="rm -f '$file' && cp '$link_target' '$file'"
  fi

  echo:Version "e-bash unlink: ${cl_blue}${name}${cl_reset} <~ ${cl_yellow}${link_target}${cl_reset}"

  if ! eval "$cmd"; then
    echo:Version "WARNING: Problem running '$cmd' for ${cl_yellow}${file}${cl_reset}" >&2
    return 1
  fi
}

################################################################################
# Function: self-update:initialize
# Description: Internal function that initializes the e-bash git repository at
#              ~/.e-bash/ if not already present. Sets up git remote, fetches
#              latest changes, configures worktree exclusions, and extracts
#              first version. Safe to call multiple times (idempotent).
# Arguments:
#   None
# Returns:
#   exit code: 0 on success, 1 if initialization fails
# Side Effects:
#   - Creates ${__E_ROOT} directory if missing
#   - Initializes git repository
#   - Adds e-bash remote and disables push
#   - Fetches all branches and tags
#   - Resets to master branch
#   - Updates .gitignore to exclude .versions/
#   - Calls self-update:version:get:first
#   - Emits status message via echo:Git
# Example:
#   self-update:initialize
#   # Creates: ~/.e-bash/.git and ~/.e-bash/.versions/v1.0.0/
################################################################################
function self-update:initialize() {
  # create folder if it does not exist
  mkdir -p "${__E_ROOT}"

  pushd "${__E_ROOT}" &>/dev/null || exit 1

  # create git repo if it's not initialized yet
  if [[ ! -d "${__E_ROOT}/.git" ]]; then
    git init "${__E_ROOT}" &>/dev/null
  fi

  # register git remote if it's not registered yet, on purpose use name different from origin
  if ! (git remote -v | grep "${__REMO_REMOTE}" &>/dev/null); then
    git remote add "${__REMO_REMOTE}" "${__REPO_URL}" &>/dev/null
    git remote set-url --push "${__REMO_REMOTE}" no_push &>/dev/null
  fi

  # assumptions:
  # - repo stay on master branch
  # - repo not modified by user directly

  # fetch latest changes
  git fetch --all &>/dev/null
  git checkout "${__REPO_MASTER}" &>/dev/null
  git reset --hard "${__REMO_REMOTE}/${__REPO_MASTER}" &>/dev/null
  echo:Git "e-bash repo initialized in ${cl_green}~/${__E_BASH}${cl_reset}"

  # exclude VERSIONS_DIR folder from git, by updating .gitignore file (if needed)
  if ! grep "${__WORKTREES}/" .gitignore &>/dev/null; then
    {
      echo ""
      echo "# exclude $__WORKTREES worktree folder from git"
      echo "$__WORKTREES/"
    } >>.gitignore
  fi

  popd &>/dev/null || exit 1

  # extract first version of the script
  self-update:version:get:first
}

################################################################################
# Function: self-update:version:resolve
# Description: Internal function that resolves version expression notation to
#              actual git tag/branch name. Supports: latest, *, next,
#              branch:{name}, tag:{name}, and semver constraints (^, ~, ranges).
# Arguments:
#   $1 - Version expression (e.g., "latest", "*", "^1.0.0", "branch:master")
# Returns:
#   stdout: Resolved tag or branch name (e.g., "v1.5.0", "master")
#   exit code: 0 (always succeeds)
# Side Effects:
#   - May call version finding functions which populate __REPO_VERSIONS
# Example:
#   tag=$(self-update:version:resolve "latest")      # Latest stable
#   tag=$(self-update:version:resolve "*")           # Highest version
#   tag=$(self-update:version:resolve "^1.0.0")      # Latest 1.x.x
#   branch=$(self-update:version:resolve "branch:master")
################################################################################
function self-update:version:resolve() {
  local version_expression="$1"
  local resolved_version=""

  # Handle special version notations
  if [[ "$version_expression" == "latest" ]]; then
    # latest stable version (no pre-release tags)
    resolved_version=$(self-update:version:find:latest_stable)
  elif [[ "$version_expression" == "*" || "$version_expression" == "next" ]]; then
    # any highest version tag (including alpha, beta, rc)
    resolved_version=$(self-update:version:find:highest_tag)
  elif [[ "$version_expression" =~ ^branch:(.+)$ ]]; then
    # branch notation: branch:master, branch:develop, etc.
    resolved_version="${BASH_REMATCH[1]}"
  elif [[ "$version_expression" =~ ^tag:(.+)$ ]]; then
    # tag notation: tag:v1.0.0, tag:v2.0.0-beta, etc.
    resolved_version="${BASH_REMATCH[1]}"
  else
    # standard semver constraint expression
    resolved_version=$(self-update:version:find "$version_expression")
  fi

  echo "$resolved_version"
}

################################################################################
# Function: self-update
# Description: PUBLIC API - Main entry point for self-update functionality.
#              Updates a file to match version constraint by initializing repo,
#              resolving version expression, comparing hashes, and creating
#              symlink if needed. Safe to call on every script execution.
# Arguments:
#   $1 - Version expression (e.g., "latest", "^1.0.0", "branch:master")
#   $2 - File path to update (optional, defaults to ${BASH_SOURCE[0]})
# Returns:
#   exit code: 0 on success, non-zero if update fails
# Side Effects:
#   - Calls self-update:initialize (creates ~/.e-bash/ if needed)
#   - Calls self-update:version:get:latest
#   - Calls self-update:version:resolve
#   - May call self-update:version:bind (creates symlink with backup)
#   - Emits status messages via echo:Version
# Recommended Usage:
#   trap "self-update '^1.0.0'" EXIT
# Example:
#   self-update "latest"                    # Update to latest stable
#   self-update "*"                         # Update to cutting edge
#   self-update "^1.0.0"                    # Stay on 1.x.x
#   self-update "~1.5.0"                    # Only patch updates
#   self-update "branch:master"             # Track master branch
#   self-update "tag:v2.0.0"                # Pin to specific tag
#   self-update "latest" ".scripts/_logger.sh"  # Update specific file
################################################################################
function self-update() {
  local version_expression="$1"
  local file=${2:-"${BASH_SOURCE[0]}"}

  # initialize git repo on $HOME/.e-bash folder
  self-update:initialize

  # always, get latest version on disk
  self-update:version:get:latest

  # resolve version expression to actual version/tag/branch
  local upgrade_version=$(self-update:version:resolve "$version_expression")

  # ensure version is available locally
  self-update:version:has "${upgrade_version}" || self-update:version:get "${upgrade_version}"

  local current_version=$(self-update:self:version "${file}")

  function do_upgrade() {
    echo:Version "e-bash is outdated: ${cl_blue}${current_version}${cl_reset} -> ${cl_yellow}${upgrade_version}${cl_reset}"
    self-update:version:bind "${upgrade_version}" "${file}"

    # calculate hash of the script file content
    self-update:file:hash "${file}"
    self-update:version:hash "${file}" "${upgrade_version}"
  }

  # is current version of file matches the found update
  if [[ "${current_version}" == "${upgrade_version}" ]]; then
    # verify hash of the script file content to be 100% sure
    local current_hash=$(self-update:file:hash "${file}")
    local update_hash=$(self-update:version:hash "${file}" "${upgrade_version}")

    if [[ "${current_hash}" != "${update_hash}" ]]; then
      do_upgrade
    else
      echo:Version "e-bash is up-to-date: ${cl_blue}${upgrade_version}${cl_reset}"
    fi
  else
    do_upgrade
  fi

  # TODO (olku): should we exit when upgrade executed?
  #   or restart the process with the same parameters?
}

# This is the writing style presented by ShellSpec, which is short but unfamiliar.
# Note that it returns the current exit status (could be non-zero).
${__SOURCED__:+return}

logger git "$@"     # declare echo:Git, printf:Git
logger version "$@" # declare echo:Version, printf:Version

logger loader "$@" # initialize logger
echo:Loader "loaded: ${cl_grey}${BASH_SOURCE[0]}${cl_reset}"

# Refs:
# - https://stackoverflow.com/questions/4023830/how-to-compare-two-strings-in-dot-separated-version-format-in-bash
# - https://stackoverflow.com/questions/3338030/multiple-bash-traps-for-the-same-signal
