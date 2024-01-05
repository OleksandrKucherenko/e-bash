#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034,SC2059

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2024-01-05
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# one time initialization, CUID
[[ "${clr0lj0ua0003og3884k1s2sh}" == "yes" ]] && return 0 || export clr0lj0ua0003og3884k1s2sh="yes"

# shellcheck disable=SC1090 source=./_commons.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_commons.sh"
# shellcheck disable=SC1090 source=./_logger.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_logger.sh"
# shellcheck disable=SC1090 source=./_dependencies.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_dependencies.sh"
# shellcheck disable=SC1090 source=./_semver.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_semver.sh"

readonly E_BASH=".e-bash"
readonly REPO_URL="https://github.com/OleksandrKucherenko/e-bash.git"
readonly REMOTE_NAME="e-bash"
readonly SELF_UPDATE_DIR="${HOME}/${E_BASH}"
readonly NULL="/dev/null"
readonly ROLLBACK_VERSION="v1.0.0"
readonly VERSIONS_DIR=".versions"
readonly MAIN_BRANCH="master"
readonly VERSION_PATTERN="v?${SEMVER}"

# declare global associative array for storing version-to-tag mapping
declare -g -A __REPO_MAPPING=()
# declare global array for storing all version tags of the repo
declare -g -a __REPO_VERSIONS=()

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

  if ((length <= 1)); then
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

# extract all version tags of the repo into global array
function self-update:version:tags() {
  pushd "${SELF_UPDATE_DIR}" &>${NULL} || exit 1

  # reset global arrays
  __REPO_VERSIONS=() && __REPO_MAPPING=()

  local line="" version=""
  local versions=()

  while IFS= read -r line; do
    [ -z "$line" ] && continue # skip empty line

    version=$(echo "$line" | sed -E "s/^v?//gi") # remove `v` prefix if exists

    versions+=("$version")
    __REPO_MAPPING["$version"]="$line"
  done < <(git tag -l --sort="v:refname" | grep -i -E "^${VERSION_PATTERN}\$")

  # create sorted array of versions
  while IFS= read -r line; do
    [ -z "$line" ] && continue # skip empty line
    __REPO_VERSIONS+=("$line")
  done < <(array:qsort "compare:versions" "${versions[@]}")

  popd &>${NULL} || exit 1
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
  for ((i = last; i >= 0; i--)); do
    version="${__REPO_VERSIONS[$i]}"

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

# check if version is already extracted on local disk
function self-update:version:has() {
  local tag_or_branch="$1"
  [ -d "${SELF_UPDATE_DIR}/${VERSIONS_DIR}/${tag_or_branch}" ]
}

# extract specified version from git repo to local disk VERSIONS_DIR folder
# shellcheck disable=SC2088
function self-update:version:get() {
  local tag_or_branch="$1"
  local worktree="./${VERSIONS_DIR}/${tag_or_branch}"
  local worktree_home="~/${E_BASH}/${VERSIONS_DIR}/${tag_or_branch}"

  pushd "${SELF_UPDATE_DIR}" &>${NULL} || exit 1

  # extract version
  git worktree add --checkout "$worktree" "${tag_or_branch}" &>${NULL}

  popd &>${NULL} || exit 1

  echo:Version "e-bash version ${cl_blue}${tag_or_branch}${cl_reset} ~ ${cl_yellow}${worktree_home}${cl_reset}"
}

# extract first/rollback version to local disk
function self-update:version:get:first() {
  local version="${ROLLBACK_VERSION}"
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

  pushd "${SELF_UPDATE_DIR}" &>${NULL} || exit 1

  # remove version
  git worktree remove "./${VERSIONS_DIR}/${version}" &>${NULL}

  rm -rf "./${VERSIONS_DIR}/${version}"

  popd &>${NULL} || exit 1

  echo:Version "e-bash version ${cl_blue}${version}${cl_reset} - ${cl_red}REMOVED${cl_reset}"
}

# bind script file to a specified version of the script
# shellcheck disable=SC2088
function self-update:version:bind() {
  local version="$1"
  local file=${2:-"${BASH_SOURCE[0]}"}

  # we should create a new symbolic links to files of selected version
  # all files of .scripts folder are the subject of binding
  # current execution script file is the subject of binding
  local script_file="$(basename "${file}")"
  local script_folder="$(cd "$(dirname "${file}")" && pwd)"

  # TODO (olku): what should we do if $file points on other directory than `.scripts/`?
  #   we also have `bin/` folder with additional scripts.
  local version_dir_home="~/${E_BASH}/${VERSIONS_DIR}/${version}/.scripts"
  local version_file="${SELF_UPDATE_DIR}/${VERSIONS_DIR}/${version}/.scripts/${script_file}"

  # check is script file is already bind to the version or not
  if [[ -L "${script_folder}/${script_file}" ]]; then
    local link=$(readlink "${script_folder}/${script_file}")
    local bind_version=$(echo "$link" | sed -E "s/.*\/\.versions$\/(.*)\/\.scripts\/.*/\1/")

    if [[ "${bind_version}" == "${version}" ]]; then
      echo:Version "e-bash binding: skip ${cl_blue}${script_file}${cl_reset}"
      return
    fi
  fi

  # if script file exists in specific version folder or not
  if [[ ! -f "${version_file}" ]]; then
    echo:Version "e-bash binding: ${cl_red}skip${cl_reset}" \
      "${cl_blue}${script_file}${cl_reset} not found in" \
      "${cl_yellow}${version_dir_home}${cl_reset}"

    return
  fi

  # expected creation of the backup file: ${script_file}.~([0-9]+)~
  gln --symbolic --force --backup=numbered \
    "${version_file}" \
    "${script_folder}/${script_file}"

  echo:Version "e-bash binding: ${cl_blue}${script_file}${cl_reset}" \
    "~>" "${cl_yellow}${version_dir_home}/${script_file}${cl_reset}"
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
  else # file content
    # try to extract version from script copyright comments, expected `## Version: 1.0.0`
    local file_version=$(grep -E "^## Version: ${VERSION_PATTERN}$" "${script_folder}/${script_file}" | sed -E "s/^## Version: (.*)$/\1/")

    if [ -n "${file_version}" ]; then
      echo:Version "copyright: ${cl_blue}${script_file}${cl_reset} to ${cl_yellow}${file_version}${cl_reset}" >&2
      # if first char of version is `v` then print version, otherwise add 'v' prefix
      # expected pure version: 1.0.0 (without `v` prefix)
      [[ "${file_version:0:1}" == "v" ]] && echo "${file_version}" || echo "v${file_version}"
    else
      echo:Version "fallback: ${cl_blue}${script_file}${cl_reset} to ${cl_yellow}${ROLLBACK_VERSION}${cl_reset}" >&2
      # no version comments found, return default version
      echo "${ROLLBACK_VERSION}" # expected tag: v1.0.0
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
    echo:Version "hash: ${cl_blue}${file}${cl_reset} to ${cl_yellow}${hash}${cl_reset}" >&2
    create_hash_file=true
  else
    echo:Version "hash: ${cl_blue}${file}${cl_reset} to ${cl_yellow}${hash}${cl_reset} - ${cl_green}from ${name}.sha1${cl_reset}" >&2
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
  local file=${1:-"${BASH_SOURCE[0]}"}
  local version=${2}

  local script_file="$(basename "${file}")"
  #  local script_folder="$(cd "$(dirname "${file}")" && pwd)"

  # TODO (olku): what should we do if $file points on other directory than `.scripts/`?
  #   we also have `bin/` folder with additional scripts.
  local version_file="${SELF_UPDATE_DIR}/${VERSIONS_DIR}/${version}/.scripts/${script_file}"
  echo:Version "hash versioned file: ${cl_blue}${version_file}${cl_reset}"

  self-update:file:hash "${version_file}"
}

# restore script file from LN backup file
function self-update:rollback:backup() {
  local file=${1:-"${BASH_SOURCE[0]}"}

  local script_file="$(basename "${file}")"
  local script_folder="$(cd "$(dirname "${file}")" && pwd)"

  # find the latest backup file by pattern ${script_file}.~([0-9]+)~
  local backup_file=$(find "${script_folder}" -maxdepth 1 -name "${script_file}.~*~" | sort -V | tail -n1)
  echo:Version "Found backup file: ${cl_yellow}${backup_file:-"<none>"}${cl_reset}"

  # restore script file from backup file, use move command for recovering
  if [[ -n "${backup_file}" ]]; then
    mv -f "${backup_file}" "${script_folder}/${script_file}"
  fi
}

# rollback to specified version or if version not provided to ${ROLLBACK_VERSION}
function self-update:rollback:version() {
  local version=${1:-"${ROLLBACK_VERSION}"}
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
  mkdir -p "${SELF_UPDATE_DIR}"

  pushd "${SELF_UPDATE_DIR}" &>${NULL} || exit 1

  # create git repo if it's not initialized yet
  if [[ ! -d "${SELF_UPDATE_DIR}/.git" ]]; then
    git init "${SELF_UPDATE_DIR}" &>${NULL}
  fi

  # register git remote if it's not registered yet, on purpose use name different from origin
  if ! (git remote -v | grep "${REMOTE_NAME}" &>${NULL}); then
    git remote add $REMOTE_NAME "${REPO_URL}" &>${NULL}
    git remote set-url --push $REMOTE_NAME no_push &>${NULL}
  fi

  # assumptions:
  # - repo stay on master branch
  # - repo not modified by user directly

  # fetch latest changes
  git fetch --all &>${NULL}
  git checkout ${MAIN_BRANCH} &>${NULL}
  git reset --hard ${REMOTE_NAME}/${MAIN_BRANCH} &>${NULL}
  echo:Git "e-bash repo initialized in ${cl_green}~/${E_BASH}${cl_reset}"

  # exclude VERSIONS_DIR folder from git, by updating .gitignore file (if needed)
  if ! grep "${VERSIONS_DIR}/" .gitignore &>${NULL}; then
    {
      echo ""
      echo "# exclude $VERSIONS_DIR worktree folder from git"
      echo "$VERSIONS_DIR/"
    } >>.gitignore
  fi

  popd &>${NULL} || exit 1

  # extract first version of the script
  self-update:version:get:first
}

# Entry point for self-update
function self-update() {
  local version_expression="$1"
  local file=${2:-"${BASH_SOURCE[0]}"}

  # initialize git repo on $HOME/.e-bash folder
  self-update:initialize

  # always, get latest version on disk
  self-update:version:get:latest

  # find version tag that matches version expression
  local upgrade_version=$(self-update:version:find "$version_expression")
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
