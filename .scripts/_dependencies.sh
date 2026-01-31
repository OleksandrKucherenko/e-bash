#!/usr/bin/env bash
# shellcheck disable=SC2034

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-30
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# shellcheck disable=SC2155
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1090 source=./_commons.sh
source "$E_BASH/_commons.sh"
# shellcheck disable=SC1090 source=./_logger.sh
source "$E_BASH/_logger.sh"

#set -x # Uncomment to DEBUG

# shellcheck disable=SC2001,SC2155,SC2046,SC2116

##
## Check if --debug flag is present in arguments
##
## Parameters:
## - args - Arguments to check, string array, variadic
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Returns:
## - "true" if --debug present, "false" otherwise
##
function isDebug() {
  local args=("$@")
  if [[ "${args[*]}" =~ "--debug" ]]; then echo true; else echo false; fi
}

##
## Check if --exec flag is present in arguments
##
## Parameters:
## - args - Arguments to check, string array, variadic
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Returns:
## - "true" if --exec present, "false" otherwise
##
function isExec() {
  local args=("$@")
  if [[ "${args[*]}" =~ "--exec" ]]; then echo true; else echo false; fi
}

##
## Check if --optional flag is present in arguments
##
## Parameters:
## - args - Arguments to check, string array, variadic
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Returns:
## - "true" if --optional present, "false" otherwise
##
function isOptional() {
  local args=("$@")
  if [[ "${args[*]}" =~ "--optional" ]]; then echo true; else echo false; fi
}

##
## Check if --silent flag is present in arguments
##
## Parameters:
## - args - Arguments to check, string array, variadic
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Returns:
## - "true" if --silent present, "false" otherwise
##
function isSilent() {
  local args=("$@")
  if [[ "${args[*]}" =~ "--silent" ]]; then echo true; else echo false; fi
}

##
## Check if --no-cache flag is present in arguments
##
## Parameters:
## - args - Arguments to check, string array, variadic
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Returns:
## - "true" if --no-cache present, "false" otherwise
##
function isNoCache() {
  local args=("$@")
  if [[ "${args[*]}" =~ "--no-cache" ]]; then echo true; else echo false; fi
}

# Internal: Cache configuration
# Cache TTL in seconds (1 day = 86400 seconds)
declare -g __DEPS_CACHE_TTL=${__DEPS_CACHE_TTL:-86400}

# Cache directory (XDG compliant)
declare -g __DEPS_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/e-bash"

# Cache file path
declare -g __DEPS_CACHE_FILE="$__DEPS_CACHE_DIR/dependencies.cache"

# In-memory cache (loaded from disk on first access)
declare -gA __DEPS_CACHE
declare -g __DEPS_CACHE_LOADED=false
declare -g __DEPS_CACHE_PATH_HASH=""

# Global: last dependency discovery result
declare -g __DEPS_FOUND_STATUS=""
declare -g __DEPS_FOUND_PATH=""
declare -g __DEPS_FOUND_VERSION=""

##
## Generate hash of PATH variable for cache invalidation
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: PATH
## - mutate/publish: none
##
## Returns:
## - Short hash string (8 chars)
##
function _cache:path:hash() {
  # Use first 8 chars of md5/sha256 hash of PATH, or cksum as fallback
  if command -v md5sum >/dev/null 2>&1; then
    echo -n "$PATH" | md5sum | cut -c1-8
  elif command -v md5 >/dev/null 2>&1; then
    echo -n "$PATH" | md5 -q | cut -c1-8
  elif command -v sha256sum >/dev/null 2>&1; then
    echo -n "$PATH" | sha256sum | cut -c1-8
  elif command -v cksum >/dev/null 2>&1; then
    # cksum outputs "checksum size", use checksum part
    echo -n "$PATH" | cksum | cut -d' ' -f1
  else
    # Fallback: simple length-based hash
    echo "${#PATH}"
  fi
}

##
## Check if cache is disabled globally
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: SKIP_DEPS_CACHE
## - mutate/publish: none
##
## Returns:
## - 0 if cache is disabled, 1 otherwise
##
## Usage:
## - if _cache:is:disabled; then echo "cache off"; fi
##
function _cache:is:disabled() {
  case "${SKIP_DEPS_CACHE:-}" in
  1 | true | yes) return 0 ;;
  *) return 1 ;;
  esac
}

##
## Check if cache file is valid (exists, not expired, PATH matches)
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: __DEPS_CACHE_FILE, __DEPS_CACHE_TTL
## - mutate/publish: none
##
## Returns:
## - 0 if cache is valid, 1 otherwise
##
function _cache:is:valid() {
  _cache:is:disabled && return 1
  [[ -f "$__DEPS_CACHE_FILE" ]] || return 1

  # Check TTL (file modification time)
  local now file_time age
  now=$(date +%s)
  if [[ "$OSTYPE" == "darwin"* ]]; then
    file_time=$(stat -f %m "$__DEPS_CACHE_FILE" 2>/dev/null) || return 1
  else
    file_time=$(stat -c %Y "$__DEPS_CACHE_FILE" 2>/dev/null) || return 1
  fi
  age=$((now - file_time))
  [[ $age -lt $__DEPS_CACHE_TTL ]] || return 1

  # Check PATH hash (first line of cache file)
  local stored_hash current_hash
  stored_hash=$(head -1 "$__DEPS_CACHE_FILE" 2>/dev/null)
  current_hash=$(_cache:path:hash)
  [[ "$stored_hash" == "$current_hash" ]] || return 1

  return 0
}

##
## Load cache from disk into memory
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: __DEPS_CACHE_FILE
## - mutate/publish: __DEPS_CACHE, __DEPS_CACHE_LOADED, __DEPS_CACHE_PATH_HASH
##
## Returns:
## - 0 always
##
function _cache:load() {
  _cache:is:disabled && return 0
  __DEPS_CACHE=()
  __DEPS_CACHE_PATH_HASH=$(_cache:path:hash)

  if ! _cache:is:valid; then
    __DEPS_CACHE_LOADED=true
    return 0
  fi

  # Read cache file (skip first line which is PATH hash)
  local line key value
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    key="${line%%=*}"
    value="${line#*=}"
    __DEPS_CACHE[$key]="$value"
  done < <(tail -n +2 "$__DEPS_CACHE_FILE" 2>/dev/null)

  __DEPS_CACHE_LOADED=true
}

##
## Save cache from memory to disk
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: __DEPS_CACHE, __DEPS_CACHE_DIR, __DEPS_CACHE_FILE
## - mutate/publish: none (writes to disk)
##
## Returns:
## - 0 on success, 1 on failure
##
function _cache:save() {
  _cache:is:disabled && return 0
  # Ensure cache directory exists
  mkdir -p "$__DEPS_CACHE_DIR" 2>/dev/null || return 1

  # Write PATH hash as first line, then cache entries
  {
    _cache:path:hash
    for key in "${!__DEPS_CACHE[@]}"; do
      echo "${key}=${__DEPS_CACHE[$key]}"
    done
  } >"$__DEPS_CACHE_FILE" 2>/dev/null
}

##
## Ensure cache is loaded from disk
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: __DEPS_CACHE_LOADED
## - mutate/publish: calls _cache:load if needed
##
## Returns:
## - 0 always
##
function _cache:ensure:loaded() {
  if _cache:is:disabled; then
    __DEPS_CACHE_LOADED=true
    return 0
  fi
  $__DEPS_CACHE_LOADED || _cache:load
}

##
## Generate cache key for dependency verification
##
## Parameters:
## - tool_path - Absolute path to tool, string, required
## - version_pattern - Version pattern, string, required
## - version_flag - Version flag, string, required
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Returns:
## - Cache key string (path-based for multi-version support)
##
## Usage:
## - key=$(_cache:key "/usr/bin/bash" "5.*.*" "--version")
##
## Note:
## - Using path as key allows caching multiple versions of the same tool
## - e.g., /usr/bin/bash (3.x) and /opt/homebrew/bin/bash (5.x)
##
function _cache:key() {
  local tool_path="$1"
  local version_pattern="$2"
  local version_flag="$3"
  echo "${tool_path}:${version_pattern}:${version_flag}"
}

##
## Generate cache key for dependency path search with minimum version
##
## Parameters:
## - tool_name - Tool name (resolved), string, required
## - min_version - Minimum version, string, required
## - version_flag - Version flag, string, required
## - version_regex - Version regex, string, required
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Returns:
## - Cache key string
##
## Usage:
## - key=$(_cache:key:find "ctags" "6.0.0" "--version" "[0-9]+\.[0-9]+\.[0-9]+")
##
function _cache:key:find() {
  local tool_name="$1"
  local min_version="$2"
  local version_flag="$3"
  local version_regex="$4"
  echo "find:${tool_name}:${min_version}:${version_flag}:${version_regex}"
}

##
## Get cached dependency verification result
##
## Parameters:
## - key - Cache key from _cache:key, string, required
##
## Globals:
## - reads/listen: __DEPS_CACHE
## - mutate/publish: __DEPS_CACHE_STATUS, __DEPS_CACHE_VERSION, __DEPS_CACHE_PATH
##
## Returns:
## - 0 if cache hit, sets __DEPS_CACHE_STATUS, __DEPS_CACHE_VERSION, __DEPS_CACHE_PATH
## - 1 if cache miss
##
## Usage:
## - if _cache:get "$key"; then
##     echo "Cached: status=$__DEPS_CACHE_STATUS, version=$__DEPS_CACHE_VERSION, path=$__DEPS_CACHE_PATH"
##   fi
##
function _cache:get() {
  local key="$1"

  _cache:is:disabled && return 1

  _cache:ensure:loaded

  if [[ -v __DEPS_CACHE[$key] ]]; then
    local value="${__DEPS_CACHE[$key]}"
    # Format: status:version:path
    __DEPS_CACHE_STATUS="${value%%:*}"
    local rest="${value#*:}"
    __DEPS_CACHE_VERSION="${rest%%:*}"
    __DEPS_CACHE_PATH="${rest#*:}"
    return 0
  fi
  return 1
}

##
## Set cached dependency verification result
##
## Parameters:
## - key - Cache key from _cache:key, string, required
## - status - Exit status (0 or 1), number, required
## - version - Extracted version string, string, optional
## - path - Absolute path to command, string, optional
##
## Globals:
## - reads/listen: none
## - mutate/publish: __DEPS_CACHE
##
## Returns:
## - 0 always
##
## Usage:
## - _cache:set "$key" 0 "5.1.16" "/usr/bin/bash"
##
function _cache:set() {
  local key="$1"
  local status="$2"
  local version="${3:-}"
  local cmd_path="${4:-}"

  _cache:is:disabled && return 0

  _cache:ensure:loaded
  __DEPS_CACHE[$key]="${status}:${version}:${cmd_path}"
  _cache:save
}

##
## Clear the dependency verification cache (memory and disk)
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: __DEPS_CACHE_FILE
## - mutate/publish: __DEPS_CACHE
##
## Returns:
## - 0 always
##
## Usage:
## - _cache:clear
##
function _cache:clear() {
  __DEPS_CACHE=()
  __DEPS_CACHE_LOADED=true
  _cache:is:disabled && return 0
  rm -f "$__DEPS_CACHE_FILE" 2>/dev/null
}

##
## Check if a tool exists (short form for if/else expressions)
##
## Parameters:
## - tool_name - Tool to check, string, required
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Returns:
## - 0 if tool exists, 1 otherwise
##
## Usage:
## - if dependency:exists go; then echo "Go is installed"; fi
## - dependency:exists python && python --version
##
function dependency:exists() {
  local tool_name="$1"
  local tool_name_resolved=$(dependency:dealias "$tool_name")
  command -v "$tool_name_resolved" >/dev/null 2>&1
}

# Internal: Version flag exceptions - tools that don't use --version
# shellcheck disable=SC2034
declare -gA __DEPS_VERSION_FLAGS_EXCEPTIONS

# Internal: Cache for dependency verification results
# Key format: tool_name:version_pattern:version_flag
# Value format: status:version_cleaned (e.g., "0:5.1.16" or "1:")
# shellcheck disable=SC2034
declare -gA __DEPS_CACHE

# Populate version flag exceptions
__DEPS_VERSION_FLAGS_EXCEPTIONS[java]="-version"
__DEPS_VERSION_FLAGS_EXCEPTIONS[javac]="-version"
__DEPS_VERSION_FLAGS_EXCEPTIONS[scala]="-version"
__DEPS_VERSION_FLAGS_EXCEPTIONS[kotlin]="-version"
__DEPS_VERSION_FLAGS_EXCEPTIONS[ant]="-version"
__DEPS_VERSION_FLAGS_EXCEPTIONS[go]="version"
__DEPS_VERSION_FLAGS_EXCEPTIONS[ssh]="-V"
__DEPS_VERSION_FLAGS_EXCEPTIONS[tmux]="-VV"
__DEPS_VERSION_FLAGS_EXCEPTIONS[ab]="-V"
__DEPS_VERSION_FLAGS_EXCEPTIONS[unrar]="-V"
__DEPS_VERSION_FLAGS_EXCEPTIONS[composer]="-V"
__DEPS_VERSION_FLAGS_EXCEPTIONS[screen]="-v"
__DEPS_VERSION_FLAGS_EXCEPTIONS[unzip]="-v"

##
## Resolve tool aliases to their canonical command names
##
## Parameters:
## - alias_name - Tool alias to resolve, string, required
##
## Globals:
## - reads/listen: SKIP_DEALIAS
## - mutate/publish: none
##
## Returns:
## - Canonical command name
##
## Usage:
## - dependency:dealias "rust" -> "rustc"
## - dependency:dealias "brew" -> "brew"
## - SKIP_DEALIAS=1 dependency:dealias "rust" -> "rust"
##
function dependency:dealias() {
  # Skip dealiasing if requested (workaround for wrong resolutions)
  if [[ "${SKIP_DEALIAS:-}" == "1" ]]; then
    echo "$1"
    return
  fi

  local alias_name="$1"

  case "$alias_name" in
  rust | rustc) echo "rustc" ;;
  golang | go) echo "go" ;;
  nodejs | node) echo "node" ;;
  jre | java) echo "java" ;;
  jdk | javac) echo "javac" ;;
  homebrew | brew) echo "brew" ;;
  awsebcli | eb) echo "eb" ;;
  awscli | aws) echo "aws" ;;
  postgresql | psql) echo "psql" ;;
  mongodb | mongo) echo "mongo" ;;
  openssh) echo "ssh" ;;
  goreplay | gor) echo "gor" ;;
  httpie | http) echo "http" ;;
  *) echo "$alias_name" ;;
  esac
}

##
## Get the version flag for a tool (exception or default --version)
##
## Parameters:
## - tool - Tool name, string, required
## - provided_flag - User-provided flag override, string, optional
##
## Globals:
## - reads/listen: __DEPS_VERSION_FLAGS_EXCEPTIONS
## - mutate/publish: none
##
## Returns:
## - Version flag (e.g. "--version", "-V", "-version")
##
## Usage:
## - dependency:known:flags "java" -> "-version"
## - dependency:known:flags "git" -> "--version"
##
function dependency:known:flags() {
  local tool="$1"
  local provided_flag="$2"

  if [[ -n "$provided_flag" ]]; then
    echo "$provided_flag"
  elif [[ -v __DEPS_VERSION_FLAGS_EXCEPTIONS[$tool] ]]; then
    echo "${__DEPS_VERSION_FLAGS_EXCEPTIONS[$tool]}"
  else
    echo "--version"
  fi
}

##
## Compare two semantic versions (major.minor.patch)
##
## Parameters:
## - left - Left version string, string, required
## - right - Right version string, string, required
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Returns:
## - Echoes: 1 if left > right, -1 if left < right, 0 if equal
##
## Usage:
## - dependency:version:compare "1.2.3" "1.2.4"
##
function dependency:version:compare() {
  local left="$1" right="$2"
  local left_major left_minor left_patch
  local right_major right_minor right_patch

  IFS='.' read -r left_major left_minor left_patch <<<"$left"
  IFS='.' read -r right_major right_minor right_patch <<<"$right"

  left_major=${left_major:-0}
  left_minor=${left_minor:-0}
  left_patch=${left_patch:-0}
  right_major=${right_major:-0}
  right_minor=${right_minor:-0}
  right_patch=${right_patch:-0}

  if ((left_major > right_major)); then
    echo 1
    return 0
  fi
  if ((left_major < right_major)); then
    echo -1
    return 0
  fi
  if ((left_minor > right_minor)); then
    echo 1
    return 0
  fi
  if ((left_minor < right_minor)); then
    echo -1
    return 0
  fi
  if ((left_patch > right_patch)); then
    echo 1
    return 0
  fi
  if ((left_patch < right_patch)); then
    echo -1
    return 0
  fi

  echo 0
}

##
## Check if version is greater than or equal to minimum
##
## Parameters:
## - version - Version string, string, required
## - minimum - Minimum version string, string, required
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Returns:
## - 0 if version >= minimum, 1 otherwise
##
## Usage:
## - dependency:version:gte "6.0.0" "6.0.0"
##
function dependency:version:gte() {
  local version="$1" minimum="$2"
  local compare_result

  compare_result=$(dependency:version:compare "$version" "$minimum")
  [[ "$compare_result" -ge 0 ]]
}

##
## Find a tool in PATH that satisfies a minimum version
##
## Parameters:
## - tool_name - Tool name or alias, string, required
## - min_version - Minimum semver, string, required
## - version_flag - Version flag, string, optional
## - version_regex - Version regex, string, optional (default: "[0-9]+\.[0-9]+\.[0-9]+")
##
## Globals:
## - reads/listen: PATH, __DEPS_VERSION_FLAGS_EXCEPTIONS
## - mutate/publish: __DEPS_FOUND_STATUS, __DEPS_FOUND_PATH, __DEPS_FOUND_VERSION
##
## Returns:
## - 0 if a matching tool is found, echoes path
## - 1 otherwise (sets __DEPS_FOUND_STATUS: not_found, no_version, version_mismatch)
##
## Usage:
## - tool_path=$(dependency:find:version "ctags" "6.0.0" "--version")
##
function dependency:find:version() {
  local tool_name="$1" min_version="$2" version_flag="$3" version_regex="$4"
  local tool_name_resolved
  local path_dirs path_dir candidate
  local found_any=false
  local first_candidate_path=""
  local best_match_path="" best_match_version=""
  local best_seen_version="" best_seen_path=""
  local version_message version_found compare_result
  local cache_key="" cache_status="" cache_version="" cache_path=""

  __DEPS_FOUND_STATUS="not_found"
  __DEPS_FOUND_PATH=""
  __DEPS_FOUND_VERSION=""

  version_regex=${version_regex:-"[0-9]+\.[0-9]+\.[0-9]+"}
  tool_name_resolved=$(dependency:dealias "$tool_name")
  version_flag=$(dependency:known:flags "$tool_name_resolved" "$version_flag")

  cache_key=$(_cache:key:find "$tool_name_resolved" "$min_version" "$version_flag" "$version_regex")
  if [[ -z "${E_BASH_SKIP_CACHE:-}" ]] && _cache:get "$cache_key"; then
    cache_status="$__DEPS_CACHE_STATUS"
    cache_version="$__DEPS_CACHE_VERSION"
    cache_path="$__DEPS_CACHE_PATH"

    if [[ "$cache_status" == "0" ]]; then
      __DEPS_FOUND_STATUS="ok"
      __DEPS_FOUND_PATH="$cache_path"
      __DEPS_FOUND_VERSION="$cache_version"
      echo "$cache_path"
      return 0
    fi

    __DEPS_FOUND_PATH="$cache_path"
    __DEPS_FOUND_VERSION="$cache_version"
    if [[ -z "$cache_path" ]]; then
      __DEPS_FOUND_STATUS="not_found"
    elif [[ -z "$cache_version" ]]; then
      __DEPS_FOUND_STATUS="no_version"
    else
      __DEPS_FOUND_STATUS="version_mismatch"
    fi
    return 1
  fi

  IFS=':' read -r -a path_dirs <<<"$PATH"
  for path_dir in "${path_dirs[@]}"; do
    [[ -z "$path_dir" ]] && continue
    candidate="${path_dir}/${tool_name_resolved}"
    [[ -x "$candidate" ]] || continue

    found_any=true
    [[ -z "$first_candidate_path" ]] && first_candidate_path="$candidate"

    version_message=$("$candidate" "$version_flag" 2>&1)
    version_found=$(echo "$version_message" | grep -oE "$version_regex" | head -1)
    [[ -z "$version_found" ]] && continue

    if [[ -z "$best_seen_version" ]]; then
      best_seen_version="$version_found"
      best_seen_path="$candidate"
    else
      compare_result=$(dependency:version:compare "$version_found" "$best_seen_version")
      [[ "$compare_result" -gt 0 ]] && best_seen_version="$version_found" && best_seen_path="$candidate"
    fi

    if dependency:version:gte "$version_found" "$min_version"; then
      if [[ -z "$best_match_version" ]]; then
        best_match_version="$version_found"
        best_match_path="$candidate"
      else
        compare_result=$(dependency:version:compare "$version_found" "$best_match_version")
        [[ "$compare_result" -gt 0 ]] && best_match_version="$version_found" && best_match_path="$candidate"
      fi
    fi
  done

  if [[ -n "$best_match_path" ]]; then
    __DEPS_FOUND_STATUS="ok"
    __DEPS_FOUND_PATH="$best_match_path"
    __DEPS_FOUND_VERSION="$best_match_version"
    _cache:set "$cache_key" 0 "$best_match_version" "$best_match_path"
    echo "$best_match_path"
    return 0
  fi

  if [[ "$found_any" != true ]]; then
    __DEPS_FOUND_STATUS="not_found"
    _cache:set "$cache_key" 1 "" ""
    return 1
  fi

  if [[ -z "$best_seen_version" ]]; then
    [[ -z "$best_seen_path" ]] && best_seen_path="$first_candidate_path"
    __DEPS_FOUND_STATUS="no_version"
    __DEPS_FOUND_PATH="$best_seen_path"
    _cache:set "$cache_key" 1 "" "$best_seen_path"
    return 1
  fi

  __DEPS_FOUND_STATUS="version_mismatch"
  __DEPS_FOUND_PATH="$best_seen_path"
  __DEPS_FOUND_VERSION="$best_seen_version"
  _cache:set "$cache_key" 1 "$best_seen_version" "$best_seen_path"
  return 1
}

##
## Check if CI auto-install mode is enabled
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: CI, CI_E_BASH_INSTALL_DEPENDENCIES
## - mutate/publish: none
##
## Returns:
## - "true" if in CI and auto-install enabled, "false" otherwise
##
## Usage:
## - if [ "$(isCIAutoInstallEnabled)" = "true" ]; then ...; fi
##
function isCIAutoInstallEnabled() {
  # Only enable auto-install if we're in a CI environment AND the flag is set
  if [[ -n "${CI:-}" ]]; then
    local value="${CI_E_BASH_INSTALL_DEPENDENCIES:-}"
    # Convert to lowercase for case-insensitive comparison (bash 4.0+ syntax)
    value="${value,,}"
    case "$value" in
    1 | true | yes) echo true ;;
    *) echo false ;;
    esac
  else
    echo false
  fi
}

##
## Check and optionally install a dependency with version constraint
##
## Parameters:
## - tool_name - Tool to check, string, required
## - tool_version_pattern - Semver pattern (e.g. "5.*.*", "HEAD-[a-f0-9]{1,8}"), string, optional
##   - If omitted or empty, only checks tool existence (short form)
## - tool_fallback - Install command, string, default: "No details. Please google it."
## - tool_version_flag - Custom version flag, string, default: auto-detected
## - --optional - Mark as optional dependency (soft fail)
## - --exec - Execute install command on version mismatch
## - --debug - Enable debug output
## - --no-cache - Bypass cache and force re-verification
## - --silent - Suppress output (useful for scripting)
##
## Globals:
## - reads/listen: CI, CI_E_BASH_INSTALL_DEPENDENCIES, E_BASH_SKIP_CACHE, SKIP_DEALIAS, __DEPS_CACHE
## - mutate/publish: __DEPS_CACHE (stores verification results)
##
## Side effects:
## - May execute install command in CI or with --exec
## - Caches verification results for performance
##
## Returns:
## - 0 if dependency found/installed, 1 otherwise
##
## Usage:
## - dependency bash "5.*.*" "brew install bash"
## - dependency shellspec "0.28.*" "brew install shellspec" "--version"
## - optional kcov "43" "brew install kcov"
## - dependency go  # Short form: just check if tool exists
## - if dependency go --silent; then echo "Go is installed"; fi
##
function dependency() {
  # Detect flags first (before processing positional args)
  local is_exec=$(isExec "$@")
  local is_optional=$(isOptional "$@")
  local is_silent=$(isSilent "$@")
  local is_no_cache=$(isNoCache "$@")
  local is_ci_auto_install=$(isCIAutoInstallEnabled)

  # Filter out flag arguments to get positional args only
  local filtered_args=()
  for arg in "$@"; do
    case "$arg" in
    --exec | --optional | --silent | --no-cache | --debug) continue ;;
    *) filtered_args+=("$arg") ;;
    esac
  done

  local tool_name="${filtered_args[0]:-""}"
  local tool_name_resolved=$(dependency:dealias "$tool_name")
  local tool_version_pattern="${filtered_args[1]:-""}"
  local tool_fallback="${filtered_args[2]:-"No details. Please google it."}"
  local tool_version_flag="${filtered_args[3]:-""}"

  # Resolve version flag (user-provided or built-in exception or default --version)
  tool_version_flag=$(dependency:known:flags "$tool_name_resolved" "$tool_version_flag")

  # Local constants for success/failure symbols
  local YEP="${cl_green}✓${cl_reset}"
  local BAD="${cl_red}✗${cl_reset}"

  # Only refresh debug flags if not silent and tool_name is not empty
  ! $is_silent && [[ -n "$tool_name" ]] && config:logger:Dependencies "${filtered_args[@]}"

  # Short form: if no version pattern provided, just check existence
  if [[ -z "$tool_version_pattern" ]]; then
    local which_tool=$(command -v "$tool_name_resolved")
    if [[ -n "$which_tool" ]]; then
      $is_silent || echo "Dependency [${cl_green}OK${cl_reset}]: \`$tool_name\` - found"
      return 0
    else
      $is_silent || echo "Dependency [${cl_red}NO${cl_reset}]: \`$tool_name\` - not found"
      return 1
    fi
  fi

  # Find tool path first (needed for cache key)
  local which_tool=$(command -v "$tool_name_resolved")

  # Generate cache key using absolute path (supports multiple versions at different paths)
  # e.g., /usr/bin/bash:5.*.*:--version vs /opt/homebrew/bin/bash:5.*.*:--version
  local cache_key=""
  if [[ -n "$which_tool" ]]; then
    cache_key=$(_cache:key "$which_tool" "$tool_version_pattern" "$tool_version_flag")
  else
    # Tool not found - use tool name as key for caching "not found" status
    cache_key=$(_cache:key "$tool_name_resolved" "$tool_version_pattern" "$tool_version_flag")
  fi

  # Check cache (unless --no-cache or E_BASH_SKIP_CACHE is set)
  if ! $is_no_cache && [[ -z "${E_BASH_SKIP_CACHE:-}" ]] && _cache:get "$cache_key"; then
    ! $is_silent && printf:Dependencies "cache hit: %s -> status=%s, version=%s, path=%s\n" \
      "$cache_key" "$__DEPS_CACHE_STATUS" "$__DEPS_CACHE_VERSION" "$__DEPS_CACHE_PATH"
    if [[ "$__DEPS_CACHE_STATUS" == "0" ]]; then
      if $is_optional; then echo -n "Optional   "; else echo -n "Dependency "; fi
      echo "[${cl_green}OK${cl_reset}]: \`$tool_name\` - version: $__DEPS_CACHE_VERSION (cached)"
      return 0
    else
      # Cache indicates failure - but we may need to try auto-install in CI
      # So we fall through to the normal flow for proper handling
      printf:Dependencies "cache indicates failure, checking if CI auto-install should be attempted\n"
    fi
  fi

  # escape symbols: & / . { }, remove end of line, replace * by expectation from 1 to 4 digits
  local tool_version=$(sed -e 's#[&\\/\.{}]#\\&#g; s#$#\\#' -e '$s#\\$##' -e 's#*#[0-9]\\{1,4\\}#g' <<<$tool_version_pattern)

  if [ -z "$which_tool" ]; then
    ! $is_silent && printf:Dependencies "which  : %s\npattern: %s, sed: \"s#.*\(%s\).*#\1#g\"\n-------\n" \
      "${which_tool:-"command -v $tool_name"}" "$tool_version_pattern" "$tool_version"

    if $is_ci_auto_install && ! $is_optional; then
      # In CI mode: only auto-install required dependencies, skip optional ones
      echo:Install "auto-installing missing dependency \`${cl_yellow}$tool_name${cl_reset}\`"

      if eval $tool_fallback; then
        # Trust the exit code - if install command succeeded, assume it worked
        # Optionally check if tool is now available (informational only)
        if command -v "$tool_name_resolved" >/dev/null 2>&1; then
          echo:Install "$YEP Successfully installed \`$tool_name\`"
        else
          # Installation command succeeded but tool not in PATH yet
          # This can happen if PATH needs to be reloaded or in test environments
          printf:Dependencies "Note: Install command succeeded but \`$tool_name\` not immediately found in PATH\n"
        fi
        _cache:set "$cache_key" 0 ""
        return 0
      else
        echo:Install "$BAD Failed to install \`$tool_name\`"
        _cache:set "$cache_key" 1 ""
        return 1
      fi
    elif $is_optional; then
      # shellcheck disable=SC2154
      echo "Optional   [${cl_red}NO${cl_reset}]: \`$tool_name\` - ${cl_red}not found${cl_reset}! Try: ${cl_purple}$tool_fallback${cl_reset}"
      _cache:set "$cache_key" 1 ""
      return 0
    else
      echo "${cl_red}Error: dependency \`$tool_name\` not found."
      echo "${cl_reset} Hint. To install tool use the command below: "
      echo " \$>  $tool_fallback"
      _cache:set "$cache_key" 1 ""
      return 1
    fi
  fi

  local version_message=$($tool_name_resolved $tool_version_flag 2>&1)
  local version_cleaned=$(echo "'$version_message'" | sed -n "s#.*\($tool_version\).*#\1#p" | head -1)

  ! $is_silent && printf:Dependencies "which  : %s\nversion: %s\npattern: %s, sed: \"s#.*\(%s\).*#\\\1#g\"\nver.   : %s\n-------\n" \
    "$which_tool" "$version_message" "$tool_version_pattern" "$tool_version" "$version_cleaned"

  if [ "$version_cleaned" == "" ]; then
    if $is_ci_auto_install && ! $is_optional; then
      # In CI mode: only auto-install required dependencies, skip optional ones
      echo:Install "auto-installing dependency with wrong version \`${cl_yellow}$tool_name${cl_reset}\`"

      if eval $tool_fallback; then
        # Trust the exit code - if install command succeeded, assume it worked
        # Optionally check if tool is now available (informational only)
        if command -v "$tool_name_resolved" >/dev/null 2>&1; then
          echo:Install "$YEP Successfully installed \`$tool_name\`"
        else
          # Installation command succeeded but tool not in PATH yet
          # This can happen if PATH needs to be reloaded or in test environments
          printf:Dependencies "Note: Install command succeeded but \`$tool_name\` not immediately found in PATH\n"
        fi
        _cache:set "$cache_key" 0 "" "$which_tool"
        return 0
      else
        echo:Install "$BAD Failed to install \`$tool_name\`"
        _cache:set "$cache_key" 1 "" "$which_tool"
        return 1
      fi
    elif $is_optional; then
      echo "Optional   [${cl_red}NO${cl_reset}]: \`$tool_name\` - ${cl_red}wrong version${cl_reset}! Try: ${cl_purple}$tool_fallback${cl_reset}"
      _cache:set "$cache_key" 1 "" "$which_tool"
      return 0
    else
      echo "${cl_red}Error: dependency version \`$tool_name\` is wrong."
      echo " Captured : ${cl_grey}$version_message${cl_red}"
      echo " Extracted: \`$version_cleaned\`"
      echo " Expected : \`$tool_version_pattern\`${cl_reset}"

      if $is_exec; then
        # shellcheck disable=SC2006,SC2154
        echo " Executing: ${cl_yellow}${tool_fallback}${cl_reset}"
        echo ""
        if eval $tool_fallback; then
          _cache:set "$cache_key" 0 "" "$which_tool"
          return 0
        else
          _cache:set "$cache_key" 1 "" "$which_tool"
          return 1
        fi
      else
        echo ""
        echo " Hint. To install tool use the command below: "
        echo " \$>  $tool_fallback"
        _cache:set "$cache_key" 1 "" "$which_tool"
        return 1
      fi
    fi
  else
    # Cache successful verification
    _cache:set "$cache_key" 0 "$version_cleaned" "$which_tool"
    if $is_optional; then echo -n "Optional   "; else echo -n "Dependency "; fi
    # shellcheck disable=SC2154
    echo "[${cl_green}OK${cl_reset}]: \`$tool_name\` - version: $version_cleaned"
  fi
}

##
## Declare an optional dependency (wrapper for dependency with --optional flag)
##
## Parameters:
## - tool_name - Tool to check, string, required
## - tool_version_pattern - Semver pattern, string, required
## - tool_fallback - Install command, string, default: "No details. Please google it."
## - tool_version_flag - Custom version flag, string, default: "--version"
##
## Globals:
## - reads/listen: none
## - mutate/publish: none (forwards to dependency)
##
## Returns:
## - 0 (always succeeds for optional deps)
##
## Usage:
## - optional kcov "43" "brew install kcov"
## - optional hyperfine "" "brew install hyperfine"
##
function optional() {
  local args=("$@")

  # Ensure we have minimum required parameters before adding --optional flag
  # This prevents --optional from being treated as a positional parameter
  case ${#args[@]} in
  2) args+=("No details. Please google it." "--version") ;;
  3) args+=("--version") ;;
  esac

  # Add --optional flag and forward to dependency()
  dependency "${args[@]}" --optional
}

# This is the writing style presented by ShellSpec, which is short but unfamiliar.
# Note that it returns the current exit status (could be non-zero).
# DO NOT allow execution of code bellow those line in shellspec tests
${__SOURCED__:+return}

logger dependencies "$@" # register own debug tag & logger functions
logger:redirect dependencies ">&2"

logger:init install "${cl_blue}[install]${cl_reset} " ">&2" # register logger for CI auto-install operations

logger loader "$@" # initialize loader logger
echo:Loader "loaded: ${cl_grey}${BASH_SOURCE[0]}${cl_reset}"

##
## Module: Dependency Management with Version Constraints
##
## This module provides dependency checking with semantic versioning constraints,
## result caching for performance, and optional auto-installation in CI environments.
##
## References:
## - demo: demo.dependencies.sh, demo.cache.sh
## - bin: git.sync-by-patches.sh, version-up.v2.sh, vhd.sh,
##   ci.validate-envrc.sh, npm.versions.sh, un-link.sh
## - documentation: Referenced in docs/public/installation.md
## - tests: spec/dependencies_spec.sh
##
## Globals:
## - E_BASH - Path to .scripts directory
## - __DEPS_VERSION_FLAGS_EXCEPTIONS - Associative array of tools with non-standard version flags
## - __DEPS_CACHE - Associative array caching verification results
## - __DEPS_CACHE_TTL - Cache time-to-live in seconds (default: 86400 = 1 day)
## - __DEPS_CACHE_DIR - Cache directory (default: $XDG_CACHE_HOME/e-bash or ~/.cache/e-bash)
## - __DEPS_CACHE_FILE - Full path to cache file
## - CI - Set by CI environments (GitHub Actions, GitLab CI, etc.)
## - CI_E_BASH_INSTALL_DEPENDENCIES - Enable auto-install in CI (1/true/yes)
## - SKIP_DEALIAS - Bypass alias resolution when set to "1"
## - SKIP_DEPS_CACHE - Disable cache layer when set to 1/true/yes
##
## Caching:
## Dependency verification results are cached persistently on disk:
## - Cache location: $XDG_CACHE_HOME/e-bash/dependencies.cache (or ~/.cache/e-bash/)
## - Cache TTL: 1 day (configurable via __DEPS_CACHE_TTL in seconds)
## - Cache is invalidated when PATH changes (hash-based detection)
## - First call verifies the tool and caches the result
## - Subsequent calls with same arguments return cached result (marked "(cached)")
## - Use --no-cache flag to bypass cache and force re-verification
## - Use SKIP_DEPS_CACHE=1 to disable cache globally
## - Use _cache:clear to clear all cached entries (memory and disk)
##
## Short Form (Existence Check):
## When called with only a tool name (no version pattern), checks existence only:
## - dependency go              # Check if 'go' exists
## - dependency:exists python   # Alternative function for scripting
## - if dependency go --silent; then ... fi  # Use in conditions
##
## Supported Version Patterns:
## - "5.*.*" - Any 5.x.x version
## - "^1.0.0" - 1.0.0 or higher (compatible)
## - "~1.2.3" - 1.2.x versions (patch-level updates)
## - "HEAD-[a-f0-9]{1,8}" - Git commit hash pattern
## - ">1.0.0" - Greater than 1.0.0
##
## Tool Aliases (auto-resolved):
## - rust/rustc -> rustc
## - golang/go -> go
## - nodejs/node -> node
## - jre/java -> java
## - homebrew/brew -> brew
##
## ref:
##  https://docs.gradle.org/current/userguide/single_versions.html
##  https://github.com/qzb/sh-semver
##  https://stackoverflow.com/questions/4023830/how-to-compare-two-strings-in-dot-separated-version-format-in-bash
##
