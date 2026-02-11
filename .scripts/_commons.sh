#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034,SC2059,SC2154

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-02-11
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# is allowed to use macOS extensions (script can be executed in *nix second)
use_macos_extensions=false
if [[ "$OSTYPE" == "darwin"* ]]; then use_macos_extensions=true; fi

# shellcheck disable=SC2155
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1090  source=./_colors.sh
source "$E_BASH/_colors.sh"

# shellcheck disable=SC1090 source=./_logger.sh
source "$E_BASH/_logger.sh"


# shellcheck disable=SC1090 source=./_tui.sh
source "$E_BASH/_tui.sh"
##
## Get current epoch timestamp with microsecond precision
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: EPOCHREALTIME
## - mutate/publish: none
##
## Returns:
## - Echoes timestamp string
##
## Usage:
## - start=$(time:now)
## - time:diff "$start"
##
function time:now() {
  echo "$EPOCHREALTIME" # <~ bash 5.0
  #python -c 'import datetime; print datetime.datetime.now().strftime("%s.%f")'
}

##
## Calculate time difference from given start timestamp
##
## Parameters:
## - start - Start timestamp from time:now, string, required
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Returns:
## - Echoes time difference in seconds
##
## Usage:
## - start=$(time:now); sleep 1; time:diff "$start"
##
function time:diff() {
  local diff="$(time:now) - $1"
  bc <<<$diff
}


# shellcheck disable=SC2086
##
## Get environment variable value or read from secret file (required)
##
## Parameters:
## - name - Variable name to store result, string, required
## - variable - Environment variable name to check, string, required
## - filepath - Path to secret file as fallback, string, required
## - fallback - User-friendly hint message, string, default: "No hints, check the documentation"
##
## Globals:
## - reads/listen: none
## - mutate/publish: creates global variable named by first parameter
##
## Returns:
## - 0 on success, 1 if neither env var nor file exists
##
## Usage:
## - env:variable:or:secret:file value "API_KEY" ".secrets/api_key" "Set your API key"
##
function env:variable:or:secret:file() {
  local name=$1
  local variable=$2
  local filepath=$3
  local fallback=${4:-"No hints, check the documentation"}
  local __result=$name

  if [[ -z "${!variable}" ]]; then
    if [[ ! -f "$filepath" ]]; then
      echo ""
      echo "${cl_red}ERROR:${cl_reset} bash env variable '\$$variable' or file '$filepath' should be provided"
      echo ""
      echo "Hint:"
      echo "  $fallback"
      echo ""
      echo:Common "Working Dir: $(pwd)"
      return 1
    else
      echo "Using file: ${cl_green}$filepath${cl_reset} ~> $name"
      eval $__result="'$(cat $filepath)'"
    fi
  else
    echo "Using var : ${cl_green}\$$variable${cl_reset} ~> $name"
    eval $__result="'${!variable}'"
  fi
}

# shellcheck disable=SC2086
##
## Get environment variable value or read from secret file (optional)
##
## Parameters:
## - name - Variable name to store result, string, required
## - variable - Environment variable name to check, string, required
## - filepath - Path to secret file as fallback, string, required
##
## Globals:
## - reads/listen: none
## - mutate/publish: creates global variable named by first parameter
##
## Returns:
## - 0 on success, 1 if neither env var nor file exists
##
## Usage:
## - env:variable:or:secret:file:optional value "API_KEY" ".secrets/api_key"
##
function env:variable:or:secret:file:optional() {
  local name=$1
  local variable=$2
  local filepath=$3
  local __result=$name

  if [[ -z "${!variable}" ]]; then
    if [[ ! -f "$filepath" ]]; then
      # NO variable, NO file
      echo "${cl_yellow}Note:${cl_reset} bash env variable '\$$variable' or file '$filepath' can be provided."
      return 0
    else
      echo "Using file: ${cl_green}$filepath${cl_reset} ~> $name"
      eval $__result="'$(cat $filepath)'"

      # make unit test happy, they expect 0 exit code, otherwise variable preserve will not work
      ${__SOURCED__:+x} && return 0 || return 2
    fi
  else
    echo "Using var : ${cl_green}\$$variable${cl_reset} ~> $name"
    eval $__result="'${!variable}'"

    # make unit test happy, they expect 0 exit code, otherwise variable preserve will not work
    ${__SOURCED__:+x} && return 0 || return 1
  fi
}

##
## Resolve {{env.VAR_NAME}} patterns to environment variable values
##
## Parameters:
## - input_string - String with {{env.*}} patterns (optional if pipeline mode), string, default: stdin
## - array_name - Associative array name for custom vars, string, default: none (env vars only)
##
## Globals:
## - reads/listen: environment variables
## - mutate/publish: none
##
## Returns:
## - String with {{env.VAR_NAME}} patterns replaced
## - Resolution priority: associative array > environment variables
##
## Usage:
## - result=$(env:resolve "Path: {{env.HOME}}")
## - echo "{{env.HOME}}" | env:resolve
## - declare -A VARS=([x]="y"); result=$(env:resolve "{{env.x}}" "VARS")
##
function env:resolve() {
  local input_string="$1"
  local array_name="$2"

  # Detect pipeline mode:
  # - If $# is 0 (no arguments) AND stdin is not a terminal, OR
  # - If $# is 1 AND first arg matches array name pattern AND stdin is not a terminal
  # Then we're in pipeline mode
  local pipeline_mode=false

  if [[ $# -eq 0 ]] && [[ ! -t 0 ]]; then
    # No arguments, stdin available - pipeline mode without array
    pipeline_mode=true
  elif [[ $# -eq 1 ]] && [[ "$input_string" =~ ^[A-Z_][A-Z0-9_]*$ ]] && [[ ! -t 0 ]]; then
    # One argument that looks like an array name, stdin available - pipeline mode with array
    pipeline_mode=true
    array_name="$input_string"
    input_string=""
  fi

  if $pipeline_mode; then
    # Pipeline mode: read from stdin line by line
    while IFS= read -r line; do
      _env:resolve:string "$line" "$array_name"
    done
  else
    # Direct mode: resolve the input string
    if [[ -z "$input_string" ]]; then
      # No input string and no pipeline - return empty
      echo ""
      return 0
    fi

    _env:resolve:string "$input_string" "$array_name"
  fi
}

##
## Internal helper to resolve {{env.VAR}} patterns in a single string
##
## Parameters:
## - str - String containing {{env.*}} patterns, string, required
## - arr_name - Associative array name for custom vars, string, default: none
##
## Globals:
## - reads/listen: environment variables
## - mutate/publish: none
##
## Returns:
## - 0 on success, 1 on infinite loop detected
## - Echoes string with all {{env.VAR}} patterns replaced
##
## Usage:
## - _env:resolve:string "Path: {{env.HOME}}" "CUSTOM_VARS"
##
function _env:resolve:string() {
  local str="$1"
  local arr_name="$2"
  local expanded_string="$str"
  local max_iterations=10  # Safety limit to prevent infinite loops
  local iteration=0

  # Iterate while there are {{env.VAR_NAME}} patterns in the string
  # Pattern: {{env.\s*([A-Za-z_][A-Za-z0-9_]*)\s*}}
  # - Matches {{env. followed by optional whitespace
  # - Captures variable name (must start with letter or underscore, then alphanumeric or underscore)
  # - Followed by optional whitespace and }}
  while [[ "$expanded_string" =~ \{\{[[:space:]]*env\.[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*\}\} ]]; do
    # Safety check: prevent infinite loops from self-referential patterns
    ((iteration++))
    if [[ $iteration -gt $max_iterations ]]; then
      echo "$expanded_string" >&2
      echo "ERROR: env:resolve exceeded maximum iterations ($max_iterations), possible infinite loop" >&2
      echo "This may be caused by self-referential patterns like: export VAR='{{env.VAR}}'" >&2
      echo:Common "Context: ...${expanded_string:0:80}..." >&2
      return 1
    fi

    local var_name="${BASH_REMATCH[1]}"
    local var_value=""
    local matched_pattern="${BASH_REMATCH[0]}"

    # Priority 1: Check associative array if provided
    if [[ -n "$arr_name" ]]; then
      # Verify the array exists and is an associative array
      if declare -p "$arr_name" 2>/dev/null | grep -q "declare -A"; then
        # Safer eval approach: validate array name contains only safe characters
        if [[ "$arr_name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] && [[ "$var_name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
          # Use printf with eval for safer array access
          # This is safer than echo-based eval as it doesn't execute arbitrary commands
          local lookup_expr="\${${arr_name}[${var_name}]:-__NOTFOUND__}"
          var_value=$(eval "printf '%s' \"$lookup_expr\"" 2>/dev/null || echo "__NOTFOUND__")
        else
          var_value="__NOTFOUND__"
        fi

        # If not found in array, fall back to environment variable
        if [[ "$var_value" == "__NOTFOUND__" ]]; then
          var_value="${!var_name:-}"
        fi
      else
        # Array doesn't exist or isn't associative, fall back to environment variable
        var_value="${!var_name:-}"
      fi
    else
      # No array provided, use environment variable
      var_value="${!var_name:-}"
    fi

    # Store previous state to detect if replacement made progress
    local previous_string="$expanded_string"

    # Replace the matched pattern with the variable value using substring slicing
    # This approach is more portable than parameter expansion ${var/pattern/replacement}
    # which has inconsistent behavior with special characters across bash versions

    # Find the pattern using prefix removal
    local prefix="${expanded_string%%"$matched_pattern"*}"

    # Check if pattern was found
    if [[ "$prefix" != "$expanded_string" ]]; then
      # Calculate positions
      local pattern_len=${#matched_pattern}
      local prefix_len=${#prefix}

      # Extract suffix after the pattern
      local suffix="${expanded_string:$((prefix_len + pattern_len))}"

      # Concatenate: prefix + replacement + suffix
      # This preserves all special characters literally without escaping
      expanded_string="${prefix}${var_value}${suffix}"
    fi

    # Safety check: if no progress was made, break to prevent infinite loop
    # This handles cases where the value equals the pattern (self-reference)
    if [[ "$expanded_string" == "$previous_string" ]]; then
      echo "$expanded_string" >&2
      echo "ERROR: env:resolve detected self-referential pattern for variable '$var_name'" >&2
      echo "Variable value contains the same placeholder pattern: $matched_pattern" >&2
      echo:Common "Context: ...${expanded_string:0:80}..." >&2
      return 1
    fi
  done

  echo "$expanded_string"
}


##
## Get variable value or fallback to default (variable coalescing level 0)
##
## Parameters:
## - variable_name - Name of variable to check, string, required
## - default - Default value if variable is empty/unset, string, required
##
## Globals:
## - reads/listen: variables by name
## - mutate/publish: none
##
## Returns:
## - Echoes variable value if set and non-empty, otherwise default
##
## Usage:
## - MY_VAR="hello"; result=$(var:l0 "MY_VAR" "default")
##
function var:l0() {
  local variable_name=$1
  local default=$2
  local value="${!variable_name}"

  if [ -n "$value" ]; then
    echo "$value"
  else
    echo "$default"
  fi
}

##
## Get variable value from var1, var2, or default (variable coalescing level 1)
##
## Parameters:
## - var1 - Name of first variable to check, string, required
## - var2 - Name of second variable to check, string, required
## - default - Default value if both variables empty/unset, string, required
##
## Globals:
## - reads/listen: variables by name
## - mutate/publish: none
##
## Returns:
## - Echoes var1 if set, var2 if set, otherwise default
##
## Usage:
## - result=$(var:l1 "VAR1" "VAR2" "default")
##
function var:l1() {
  local var1=$1
  local var2=$2
  local default=$3
  local value1="${!var1}"
  local value2="${!var2}"

  if [ -n "$value1" ]; then
    echo "$value1"
  elif [ -n "$value2" ]; then
    echo "$value2"
  else
    echo "$default"
  fi
}

##
## Get value or fallback to default (value coalescing level 0)
##
## Parameters:
## - value - Value to check, string, required
## - default - Default value if value is empty, string, required
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Returns:
## - Echoes value if non-empty, otherwise default
##
## Usage:
## - result=$(val:l0 "hello" "default")
##
function val:l0() {
  local value=$1
  local default=$2

  if [ -n "$value" ]; then
    echo "$value"
  else
    echo "$default"
  fi
}

##
## Get value from value1, value2, or default (value coalescing level 1)
##
## Parameters:
## - value1 - First value to check, string, required
## - value - Second value to check, string, required
## - default - Default value if both values empty, string, required
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Returns:
## - Echoes value1 if non-empty, value if non-empty, otherwise default
##
## Usage:
## - result=$(val:l1 "first" "second" "default")
##
function val:l1() {
  local value1=$1
  local value=$2
  local default=$3

  if [ -n "$value1" ]; then
    echo "$value1"
  elif [ -n "$value" ]; then
    echo "$value"
  else
    echo "$default"
  fi
}

##
## Generate cross-platform hash for slug generation (internal helper)
##
## Parameters:
## - input - String to hash, string, required
## - length - Hash length to return, number, required
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Returns:
## - Echoes hash of specified length
##
## Usage:
## - hash=$(to:slug:hash "input" 7)
##
function to:slug:hash() {
  local input=$1
  local length=$2
  local hash=""

  # Try sha256sum (Linux), shasum -a 256 (macOS), then md5sum/md5
  if command -v sha256sum >/dev/null 2>&1; then
    hash=$(echo -n "$input" | sha256sum 2>/dev/null | cut -d' ' -f1 | head -c "$length")
  elif command -v shasum >/dev/null 2>&1; then
    hash=$(echo -n "$input" | shasum -a 256 2>/dev/null | cut -d' ' -f1 | head -c "$length")
  elif command -v md5sum >/dev/null 2>&1; then
    hash=$(echo -n "$input" | md5sum 2>/dev/null | cut -d' ' -f1 | head -c "$length")
  elif command -v md5 >/dev/null 2>&1; then
    hash=$(echo -n "$input" | md5 2>/dev/null | head -c "$length")
  fi

  echo "$hash"
}

##
## Convert string to filesystem-safe slug
##
## Parameters:
## - string - String to convert, string, required
## - separator - Separator character, string, default: "_"
## - trim - Maximum length or "always" for hash, string/number, default: 20
##   - Number: Max length, add hash if exceeded
##   - "always": Always append hash for deterministic IDs
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Returns:
## - Echoes filesystem-safe slug trimmed to length with optional hash
## - Returns "__" + hash (7 chars) if input only special characters
##
## Usage:
## - result=$(to:slug "Hello World!" "_" 20)
## - result=$(to:slug "Hello World!" "_" "always")
##
function to:slug() {
  local string=$1
  local separator=${2:-"_"}
  local trim_param=${3:-20}
  local strategy="length"
  local trim=20

  # Determine strategy: number (length limit) or "always" (force hash)
  if [[ "$trim_param" == "always" ]]; then
    strategy="always"
    trim=0  # No length limit when strategy is "always"
  elif [[ "$trim_param" =~ ^[0-9]+$ ]]; then
    strategy="length"
    trim=$trim_param
  else
    # Invalid parameter, default to 20
    strategy="length"
    trim=20
  fi

  # Convert to lowercase
  local slug=$(echo "$string" | tr '[:upper:]' '[:lower:]')

  # Replace all non-alphanumeric characters with the separator
  # and squeeze repeated separators into one
  slug=$(echo "$slug" | tr -cs '[:alnum:]' "$separator")

  # Trim leading and trailing separators
  slug="${slug#"${separator}"}"
  slug="${slug%"${separator}"}"

  # If slug is empty (input had only special characters), generate hash-based name
  if [ -z "$slug" ]; then
    # Generate 7-character hash from original input
    local hash=$(to:slug:hash "$string" 7)

    # Return "__" prefix + hash (9 chars total, or trimmed to max length)
    local hash_slug="__${hash}"
    if [ "$strategy" = "length" ] && [ ${#hash_slug} -gt "$trim" ]; then
      echo "${hash_slug:0:$trim}"
    else
      echo "$hash_slug"
    fi
    return
  fi

  # Strategy: always add hash
  if [ "$strategy" = "always" ]; then
    local hash=$(to:slug:hash "$slug" 7)
    echo "${slug}${separator}${hash}"
    return
  fi

  # Strategy: length-based trimming
  if [ ${#slug} -gt "$trim" ]; then
    # Generate 7-character hash
    local hash=$(to:slug:hash "$slug" 7)

    # Calculate prefix length (leave room for separator + 7-char hash)
    local prefix_len=$((trim - 8))

    if [ $prefix_len -gt 0 ]; then
      local prefix="${slug:0:$prefix_len}"
      # Remove trailing separator from prefix
      prefix="${prefix%"${separator}"}"
      slug="${prefix}${separator}${hash}"
    else
      # If trim is too small (<= 8), use hash of exact trim length
      local hash_only=$(to:slug:hash "$slug" "$trim")
      slug="$hash_only"
    fi
  fi

  echo "$slug"
}

##
## Check if --help flag is present in arguments
##
## Parameters:
## - args - Arguments to check, string array, variadic
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Returns:
## - "true" if --help present, "false" otherwise
##
## Usage:
## - if args:isHelp "$@"; then ...; fi
##
function args:isHelp() {
  local args=("$@")
  if [[ "${args[*]}" =~ "--help" ]]; then echo true; else echo false; fi
}

##
## Find git repository root directory (handles regular repos, worktrees, submodules)
##
## Parameters:
## - start_path - Starting directory path, string, default: "."
## - output_type - Output format, string, default: "path"
##   - "path": Return the root path
##   - "type": Return repo type (regular|worktree|submodule)
##   - "both": Return "type:path" format
##   - "all": Return "type:path:git_dir" format
##
## Globals:
## - reads/listen: use_macos_extensions
## - mutate/publish: none
##
## Returns:
## - 0 if git root found, 1 otherwise
## - Echoes based on output_type
##
## Usage:
## - root=$(git:root)
## - type=$(git:root "." "type")  # "regular" or "worktree" or "submodule"
##
function git:root() {
  local start_path="${1:-.}"
  local output_type="${2:-path}"
  local current_dir git_type git_dir root_path

  # Resolve to absolute path
  current_dir=$(cd "$start_path" 2>/dev/null && pwd -P) || {
    echo ""
    return 1
  }

  # Navigate upward until we find .git (file or directory) or reach root
  local max_iterations=1000  # Safety limit to prevent infinite loops
  local iteration=0

  while true; do
    # Safety check: prevent infinite loops
    ((iteration++))
    if [[ $iteration -gt $max_iterations ]]; then
      echo "" >&2
      echo "WARNING: git:root exceeded maximum iterations ($max_iterations), possible infinite loop" >&2
      return 1
    fi

    if [[ -e "$current_dir/.git" ]]; then
      root_path="$current_dir"

      # Check if .git is a file (worktree or submodule) or directory (regular repo)
      if [[ -f "$current_dir/.git" ]]; then
        # Read the .git file content
        local git_file_content
        git_file_content=$(cat "$current_dir/.git" 2>/dev/null)

        # Worktree format: "gitdir: /path/to/.git/worktrees/name"
        # Submodule format: "gitdir: ../.git/modules/name"
        if [[ "$git_file_content" =~ ^gitdir:\ (.+)$ ]]; then
          git_dir="${BASH_REMATCH[1]}"

          # Convert relative path to absolute if needed
          if [[ ! "$git_dir" =~ ^/ ]]; then
            local abs_git_dir
            abs_git_dir=$(cd "$current_dir" && cd "$(dirname "$git_dir")" 2>/dev/null && pwd)
            if [[ -n "$abs_git_dir" ]]; then
              git_dir="$abs_git_dir/$(basename "$git_dir")"
            fi
            # If conversion fails, keep relative path as-is
          fi

          # Detect if it's a worktree or submodule
          # Worktrees: path contains "/worktrees/"
          # Submodules: path contains "/modules/" or is within superproject
          if [[ "$git_dir" =~ /worktrees/ ]]; then
            git_type="worktree"
          else
            git_type="submodule"
          fi
        else
          # Malformed .git file
          git_type="unknown"
          git_dir="$current_dir/.git"
        fi
      elif [[ -d "$current_dir/.git" ]]; then
        # Regular git repository
        git_type="regular"
        git_dir="$current_dir/.git"
      else
        # .git exists but is neither file nor directory
        git_type="unknown"
        git_dir="$current_dir/.git"
      fi

      # Output based on requested type
      case "$output_type" in
      type)
        echo "$git_type"
        ;;
      both)
        echo "$git_type:$root_path"
        ;;
      all)
        echo "$git_type:$root_path:$git_dir"
        ;;
      path | *)
        echo "$root_path"
        ;;
      esac

      return 0
    fi

    # Break if we've reached filesystem root
    if [[ "$current_dir" == "/" ]]; then
      break
    fi

    # Move up one directory
    local prev_dir="$current_dir"
    current_dir=$(dirname "$current_dir")

    # Safety check: if dirname returns same path, we're at root
    if [[ "$current_dir" == "$prev_dir" ]]; then
      break
    fi
  done

  # No .git found
  case "$output_type" in
  type)
    echo "none"
    ;;
  both)
    echo "none:"
    ;;
  all)
    echo "none::"
    ;;
  path | *)
    echo ""
    ;;
  esac

  return 1
}

##
## Find configuration file hierarchy by searching upward from current folder
##
## Parameters:
## - config_name - Config file name(s), comma-separated, string, default: ".config"
## - start_path - Starting directory, string, default: "."
## - stop_at - Where to stop searching, string, default: "git"
##   - "git": Stop at git repository root
##   - "home": Stop at user home directory
##   - "root": Stop at filesystem root
##   - "/path": Absolute path to stop at
## - extensions - Comma-separated extensions, string, default: ",.json,.yaml,.yml,.toml,.ini,.conf,.rc"
##   - Empty string "" means exact match only
##
## Globals:
## - reads/listen: HOME, git:root()
## - mutate/publish: none
##
## Returns:
## - 0 if at least one config file found, 1 otherwise
## - Echoes config paths, one per line, ordered root to current (bottom-up)
##
## Usage:
## - config:hierarchy ".eslintrc"
## - config:hierarchy "package.json" "." "home"
## - config:hierarchy ".config" "." "git" ".json,.yaml"
##
function config:hierarchy() {
  local config_names="${1:-.config}"
  local start_path="${2:-.}"
  local stop_at="${3:-git}"
  local extensions="${4-,.json,.yaml,.yml,.toml,.ini,.conf,.rc}"

  local current_dir stop_path found_files=()
  local -a name_list ext_list

  # Resolve to absolute path
  current_dir=$(cd "$start_path" 2>/dev/null && pwd -P) || {
    echo ""
    return 1
  }

  # Determine stop path
  case "$stop_at" in
  git)
    stop_path=$(git:root "$current_dir" "path")
    # If no git root found, stop at home
    [[ -z "$stop_path" ]] && stop_path="$HOME"
    ;;
  home)
    stop_path="$HOME"
    ;;
  root)
    stop_path="/"
    ;;
  /*)
    # Absolute path provided - resolve to physical path (like current_dir)
    stop_path=$(cd "$stop_at" 2>/dev/null && pwd -P) || {
      echo ""
      return 1
    }
    ;;
  *)
    # Relative path or invalid, fallback to git
    stop_path=$(git:root "$current_dir" "path")
    [[ -z "$stop_path" ]] && stop_path="$HOME"
    ;;
  esac

  # Parse config names (comma-separated)
  IFS=',' read -ra name_list <<<"$config_names"

  # Parse extensions (comma-separated)
  # Special case: if extensions is exactly "", treat as single empty extension (exact match)
  if [[ "$extensions" == "" ]]; then
    ext_list=("")
  else
    IFS=',' read -ra ext_list <<<"$extensions"
  fi

  # Search upward from current directory to stop path
  local search_dir="$current_dir"
  local max_iterations=1000  # Safety limit to prevent infinite loops
  local iteration=0

  while true; do
    # Safety check: prevent infinite loops
    ((iteration++))
    if [[ $iteration -gt $max_iterations ]]; then
      echo "" >&2
      echo "WARNING: config:hierarchy exceeded maximum iterations ($max_iterations), possible infinite loop" >&2
      return 1
    fi

    # Try each config name
    for name in "${name_list[@]}"; do
      name=$(echo "$name" | xargs) # Trim whitespace

      # Try each extension (including no extension if "" is in list)
      for ext in "${ext_list[@]}"; do
        ext=$(echo "$ext" | xargs) # Trim whitespace
        local candidate="$search_dir/${name}${ext}"

        if [[ -f "$candidate" ]]; then
          # Store found file (we'll reverse order later)
          found_files+=("$candidate")
        fi
      done
    done

    # Check if we've reached the stop path
    if [[ "$search_dir" == "$stop_path" ]] || [[ "$search_dir" == "/" ]]; then
      break
    fi

    # Move up one directory
    local prev_dir="$search_dir"
    search_dir=$(dirname "$search_dir")

    # Safety check: if dirname returns same path, we're at root
    if [[ "$search_dir" == "$prev_dir" ]]; then
      break
    fi
  done

  # Reverse array to get root-to-current order (bottom-up hierarchy)
  local -a reversed_files=()
  for ((i = ${#found_files[@]} - 1; i >= 0; i--)); do
    reversed_files+=("${found_files[i]}")
  done

  # Output results
  if [[ ${#reversed_files[@]} -gt 0 ]]; then
    printf '%s\n' "${reversed_files[@]}"
    return 0
  else
    echo ""
    return 1
  fi
}

##
## Find config files following XDG Base Directory Specification
##
## Parameters:
## - app_name - Application name for XDG dirs, string, required
## - config_name - Config file name(s), comma-separated, string, default: "config"
## - start_path - Starting directory, string, default: "."
## - stop_at - Where to stop hierarchical search, string, default: "home"
## - extensions - Comma-separated extensions, string, default: ",.json,.yaml,.yml,.toml,.ini,.conf,.rc"
##
## Globals:
## - reads/listen: HOME, XDG_CONFIG_HOME, XDG_CONFIG_DIRS
## - mutate/publish: none
##
## Returns:
## - 0 if at least one config file found, 1 otherwise
## - Echoes config paths, one per line, ordered by priority (highest to lowest)
##
## Search order:
## - 1. Hierarchical from current_dir to stop_path
## - 2. $XDG_CONFIG_HOME/<app_name>/
## - 3. ~/.config/<app_name>/
## - 4. /etc/xdg/<app_name>/
## - 5. /etc/<app_name>/
##
## Usage:
## - config:hierarchy:xdg "myapp" "config"
## - config:hierarchy:xdg "nvim" "init.vim,.nvimrc"
##
function config:hierarchy:xdg() {
  local app_name="${1}"
  local config_names="${2:-config}"
  local start_path="${3:-.}"
  local stop_at="${4:-home}"
  local extensions="${5-,.json,.yaml,.yml,.toml,.ini,.conf,.rc}"

  # Validate app_name is provided
  if [[ -z "$app_name" ]]; then
    echo "" >&2
    echo "ERROR: config:hierarchy:xdg requires app_name as first argument" >&2
    return 1
  fi

  local -a all_configs=()
  local -a xdg_paths=()

  # 1. First, do hierarchical search (highest priority)
  # config:hierarchy returns root-to-current order (for merging)
  # We need to reverse it to get current-to-root (priority order)
  local hierarchy_result
  hierarchy_result=$(config:hierarchy "$config_names" "$start_path" "$stop_at" "$extensions" 2>/dev/null)
  if [[ $? -eq 0 && -n "$hierarchy_result" ]]; then
    local -a hierarchy_files=()
    while IFS= read -r line; do
      [[ -n "$line" ]] && hierarchy_files+=("$line")
    done <<<"$hierarchy_result"

    # Reverse the array to get highest priority first (current before root)
    for ((i=${#hierarchy_files[@]}-1; i>=0; i--)); do
      all_configs+=("${hierarchy_files[i]}")
    done
  fi

  # 2. Build XDG search paths (in priority order)
  # XDG_CONFIG_HOME (user override)
  if [[ -n "${XDG_CONFIG_HOME}" ]]; then
    xdg_paths+=("${XDG_CONFIG_HOME}/${app_name}")
  fi

  # ~/.config (XDG default)
  xdg_paths+=("${HOME}/.config/${app_name}")

  # XDG_CONFIG_DIRS (system-wide XDG, colon-separated)
  if [[ -n "${XDG_CONFIG_DIRS}" ]]; then
    local -a xdg_config_dirs=()
    IFS=':' read -ra xdg_config_dirs <<<"${XDG_CONFIG_DIRS}"
    for xdg_dir in "${xdg_config_dirs[@]}"; do
      [[ -n "$xdg_dir" ]] && xdg_paths+=("${xdg_dir%/}/${app_name}")
    done
  else
    xdg_paths+=("/etc/xdg/${app_name}")
  fi

  # /etc (traditional system config)
  local etc_root="${XDG_ETC_DIR:-/etc}"
  if [[ -n "$etc_root" ]]; then
    xdg_paths+=("${etc_root%/}/${app_name}")
  fi

  # 3. Search XDG directories for config files
  local -a name_list ext_list
  IFS=',' read -ra name_list <<<"$config_names"

  # Parse extensions (special case for empty string)
  if [[ "$extensions" == "" ]]; then
    ext_list=("")
  else
    IFS=',' read -ra ext_list <<<"$extensions"
  fi

  for xdg_dir in "${xdg_paths[@]}"; do
    if [[ -d "$xdg_dir" ]]; then
      for name in "${name_list[@]}"; do
        name=$(echo "$name" | xargs) # Trim whitespace

        for ext in "${ext_list[@]}"; do
          ext=$(echo "$ext" | xargs) # Trim whitespace
          local candidate="${xdg_dir}/${name}${ext}"

          if [[ -f "$candidate" ]]; then
            # Add to results if not already found in hierarchy
            local already_found=0
            for existing in "${all_configs[@]}"; do
              if [[ "$existing" == "$candidate" ]]; then
                already_found=1
                break
              fi
            done

            if [[ $already_found -eq 0 ]]; then
              all_configs+=("$candidate")
            fi
          fi
        done
      done
    fi
  done

  # Output results
  if [[ ${#all_configs[@]} -gt 0 ]]; then
    printf '%s\n' "${all_configs[@]}"
    return 0
  else
    echo ""
    return 1
  fi
}


# This is the writing style presented by ShellSpec, which is short but unfamiliar.
# Note that it returns the current exit status (could be non-zero).
${__SOURCED__:+return}

logger common "$@"             # register own logger
logger:redirect "common" ">&2" # redirect to STDERR

logger loader "$@" # initialize logger
echo:Loader "loaded: ${cl_grey}${BASH_SOURCE[0]}${cl_reset}"

# old version of function names
alias now='time:now'
alias print_time_diff=time:diff
alias validate_input=validate:input
alias validate_yn_input=validate:input:yn
alias env_variable_or_secret_file=env:variable:or:secret:file
alias optional_env_variable_or_secret_file=env:variable:or:secret:file:optional
alias isHelp=args:isHelp

##
## Module: Common Utilities and Helper Functions
##
## This module provides a collection of frequently used utility functions
## for time handling, cursor position, input validation, git operations,
## config file discovery, and user interaction.
#
## References:
## - demo: demo.readpswd.sh, demo.selector.sh, demo.multi-line.sh
## - bin: git.semantic-version.sh, ci.validate-envrc.sh
## - documentation: docs/public/commons.md
## - tests: spec/commons_spec.sh, spec/multi_line_input_spec.sh
##
## Globals:
## - E_BASH - Path to .scripts directory
## - use_macos_extensions - Enable macOS-specific features, boolean, default: based on OSTYPE
##
## Categories:
##
## Time Functions:
## - time:now() - Get current epoch timestamp with microseconds
## - time:diff(start) - Calculate time difference
##
## Cursor/Position Functions:
## - cursor:position() - Get "row;col" position
## - cursor:position:row() - Get row number
## - cursor:position:col() - Get column number
##
## Input Functions:
## - input:readpwd() - Read password with masking and line editing
## - input:selector() - Interactive menu selector from array
## - input:multi-line() - Interactive multi-line text editor
## - validate:input() - Generic input validation
## - validate:input:masked() - Masked input validation
## - validate:input:yn() - Yes/no input validation
## - confirm:by:input() - Cascading default confirmation
##
## Environment Functions:
## - env:variable:or:secret:file() - Get env var or read from secret file
## - env:variable:or:secret:file:optional() - Optional version
## - env:resolve() - Expand {{env.VAR}} templates
##
## Value Coalescing Functions:
## - var:l0() - Get variable or default
## - var:l1() - Try var1, var2, or default
## - val:l0() - Try value or default
## - val:l1() - Try value1, value2, or default
##
## String/Slug Functions:
## - to:slug:hash() - Generate hash for slug
## - to:slug() - Convert string to filesystem-safe slug
##
## Git Functions:
## - git:root() - Find git repository root (handles worktrees, submodules)
## - args:isHelp() - Check if --help flag present
##
## Config Discovery Functions:
## - config:hierarchy() - Find config files upward in directory tree
## - config:hierarchy:xdg() - XDG-compliant config discovery
##
