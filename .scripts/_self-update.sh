#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034,SC2059

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-20
## Version: 0.11.15
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash
##
## Purpose:
##   Self-update functionality for projects using e-bash scripts library.
##   Allows automatic detection of e-bash source updates and file-by-file
##   library updates. Designed for BASH scripts built on top of e-bash.
##
## Compatibility:
##   Works with bin/install.e-bash.sh - both use ${HOME}/.e-bash/ global directory.
##   - install.e-bash.sh: Supports local (project) and global (HOME) installations
##   - self-update.sh: Works only with global part (manages ~/.e-bash/.versions/)
##   Self-update creates symlinks from project files to versioned global files.
##
## Main Usage Pattern:
##   The recommended approach is to invoke self-update on script exit:
##     trap "self-update '^1.0.0'" EXIT
##
## How It Works:
##   1. Maintains local git repo at ~/.e-bash/ with multiple version worktrees
##   2. Creates symbolic links from project .scripts/ to version-specific files
##   3. Performs file-by-file updates with automatic backup creation
##   4. Verifies updates using SHA1 hash comparison
##   5. Supports rollback to previous versions or backup files
##
## Supported Version Expressions:
##   - 'latest'           - latest stable version (no pre-release tags)
##   - '*' or 'next'      - highest version tag (including alpha, beta, rc)
##   - 'branch:{name}'    - update from specific branch
##   - 'tag:{name}'       - update to specific tag
##   - '^1.0.0'           - minor and patch releases (>= 1.0.0 < 2.0.0)
##   - '~1.0.0'           - patch releases only (>= 1.0.0 < 1.1.0)
##   - '>1.0.0 <=1.5.0'   - version range with comparison operators
##   - '1.0.0'            - exact version match

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

# check if script dependencies are satisfied
function self-update:dependencies() {
  dependency bash "5.*.*" "brew install bash"
  dependency git "2.*.*" "brew install git"

  # commands that support --backup=numbered option
  dependency gln "9.2" "brew install coreutils"
  dependency gmv "9.2" "brew install coreutils"
  dependency gcp "9.2" "brew install coreutils"
}

# compare two version strings
function compare:versions() {
  (semver:constraints:simple "$1<$2") && return 0 || return 1
}

# Quick-Sort implementation
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

# resolve provided path to absolute path, relative to caller script path
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

# extract all version tags of the repo into global array
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

# find the highest version tag in git repo that matches version expression/constraints
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

# find highest version tag in git repo
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

# find latest stable version tag (no pre-release tags like alpha, beta, rc)
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

# check if version is already extracted on local disk
function self-update:version:has() {
  local tag_or_branch="$1"
  [ -d "${__E_ROOT}/${__WORKTREES}/${tag_or_branch}" ]
}

# extract specified version from git repo to local disk VERSIONS_DIR folder
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

# extract first/rollback version to local disk
function self-update:version:get:first() {
  local version="${__REPO_V1}"
  echo:Version "Extract first version: ${cl_blue}${version}${cl_reset}"
  self-update:version:has "${version}" || self-update:version:get "${version}"
}

# extract latest version from git repo to local disk VERSIONS_DIR folder
function self-update:version:get:latest() {
  local version=$(self-update:version:find:highest_tag)
  echo:Version "Extract latest version: ${cl_blue}${version}${cl_reset}"
  self-update:version:has "${version}" || self-update:version:get "${version}"
}

# remove version from local disk VERSIONS_DIR folder
function self-update:version:remove() {
  local version="$1"

  pushd "${__E_ROOT}" &>/dev/null || exit 1

  # remove version
  git worktree remove "./${__WORKTREES}/${version}" &>/dev/null

  rm -rf "./${__WORKTREES}/${version}"

  popd &>/dev/null || exit 1

  echo:Version "e-bash version ${cl_blue}${version}${cl_reset} - ${cl_red}REMOVED${cl_reset}"
}

# bind script file to a specified version of the script
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

# extract executable script version
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

# calculate hash of the script file content, create a *.sha1 file for caching
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

# calculate hash of the script file content, create a *.sha1 file for caching
# but use version folder as a source of file content
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

# restore script file from LN backup file
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

# rollback to specified version or if version not provided to ${ROLLBACK_VERSION}
function self-update:rollback:version() {
  local version=${1:-"${__REPO_V1}"}
  local file=${2:-"${BASH_SOURCE[0]}"}

  # rollback to specified version
  self-update:version:has "${version}" || self-update:version:get "${version}"

  self-update:version:bind "${version}" "${file}"

  # NOTE: rollback to specific version does not remove backup files, it will actually create a new one
}

# convert current file symbolic link to a file copy
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

# initialize git repo in local disk that helps to manage versions of the script(s)
# in addition: extract first version of the script files on disk;
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

# Resolve version expression to actual version/tag/branch
# This function handles all supported version notation patterns
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

# Entry point for self-update
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
