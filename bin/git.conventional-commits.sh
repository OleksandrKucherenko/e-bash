#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# set -x


export __commit_msg=""
export __commit_sha=""

# Global array of valid conventional commit types (configurable)
declare -a -g CONVENTIONAL_COMMIT_TYPES=(
  "feat"     # A new feature
  "fix"      # A bug fix
  "docs"     # Documentation only changes
  "style"    # Changes that do not affect the meaning of the code
  "refactor" # A code change that neither fixes a bug nor adds a feature
  "perf"     # A code change that improves performance
  "test"     # Adding missing tests or correcting existing tests
  "build"    # Changes that affect the build system or external dependencies
  "ci"       # Changes to our CI configuration files and scripts
  "chore"    # Other changes that don't modify src or test files
  "revert"   # Reverts a previous commit
  "wip"      # Work in progress (not default!)
)

# Global associative array for storing parsed conventional commit components
declare -A -g __conventional_parse_result=(
  ["message"]=""     # Full commit message
  ["type"]=""        # Commit type (feat, fix, etc.)
  ["scope"]=""       # Optional scope in parentheses
  ["breaking"]=""    # Breaking change indicator (! or empty)
  ["description"]="" # Brief description
  ["body"]=""        # Optional longer description
  ["footer"]=""      # Optional footer (BREAKING CHANGE, etc.)
)

#
# Generate regex pattern for conventional commits
# Based on https://www.conventionalcommits.org/en/v1.0.0/
# Format: type(scope)!: description
#
function conventional:grep() {
  local types_pattern
  # Join array elements with | for regex alternation
  printf -v types_pattern '%s|' "${CONVENTIONAL_COMMIT_TYPES[@]}"
  types_pattern="${types_pattern%|}" # Remove trailing |

  # Conventional commit regex pattern:
  # ^(type)(\(scope\))?(!)?: description(\n\nbody)?(\n\nfooter)?$
  # Groups:
  # 1: type
  # 2: (scope) - optional
  # 3: scope - optional
  # 4: ! - optional breaking change indicator
  # 5: description
  # 6: body - optional (starts with double newline)
  # 7: footer - optional (starts with double newline)
  # Simple pattern that just captures the header (type, scope, breaking, description)
  local pattern="^(${types_pattern})(\\(([^)]+)\\))?(!)?:[[:space:]]+(.+)"

  echo "$pattern"
}

#
# Parse conventional commit message into components
# Arguments:
#   $1: commit message
#   $2: output variable name (optional, defaults to __conventional_parse_result)
# Returns:
#   0 if parsing successful, 1 otherwise
#
function conventional:parse() {
  local message="$1"
  local output_variable="${2:-"__conventional_parse_result"}"
  local CONVENTIONAL_REGEX
  CONVENTIONAL_REGEX="$(conventional:grep)"
  declare -A parsed=(["message"]="" ["type"]="" ["scope"]="" ["breaking"]="" ["description"]="" ["body"]="" ["footer"]=" ")

  if [[ "$message" =~ $CONVENTIONAL_REGEX ]]; then
    # Store full message
    parsed["message"]="$message"

    # Extract components from BASH_REMATCH
    parsed["type"]="${BASH_REMATCH[1]}"
    parsed["scope"]="${BASH_REMATCH[3]}"
    parsed["breaking"]="${BASH_REMATCH[4]}"
    parsed["description"]="${BASH_REMATCH[5]}"

    # Handle multi-line parsing by splitting description from body/footer
    local full_message="${BASH_REMATCH[5]}"

    # Check if description contains actual newline characters (body/footer)
    if [[ "$full_message" == *$'\n'* ]]; then
      # Split at first double newline to separate description from body
      local description="${full_message%%$'\n\n'*}"
      local body_footer="${full_message#*$'\n\n'}"

      # Update parsed description to only include the first part
      parsed["description"]="$description"

      # Check if body_footer contains breaking change anywhere
      if [[ "$body_footer" =~ (BREAKING[[:space:]]+CHANGE:) ]]; then
        # Extract breaking change and move to footer
        parsed["footer"]="BREAKING CHANGE: ${body_footer#*BREAKING CHANGE:}"
        # Remove breaking change from body
        parsed["body"]="${body_footer%%BREAKING CHANGE:*}"
        # Mark as breaking change
        parsed["breaking"]="!"
      else
        parsed["body"]="$body_footer"
      fi
    fi

    # Also check for BREAKING CHANGE in body if not already marked with !
    if [[ -z "${parsed[breaking]}" && "${parsed[body]}" =~ BREAKING[[:space:]]+CHANGE: ]]; then
      parsed["breaking"]="!"
      # Move breaking change from body to footer
      parsed["footer"]="BREAKING CHANGE: ${parsed[body]#*BREAKING CHANGE:}"
      parsed["body"]="${parsed[body]%%BREAKING CHANGE:*}"
    fi

    # Copy parsed results to global variable using safe methods
    if [[ "$output_variable" == "__conventional_parse_result" ]]; then
      # Direct assignment for the global variable (most efficient)
      for key in "${!parsed[@]}"; do
        __conventional_parse_result[$key]="${parsed[$key]}"
      done
    else
      # For custom variable names, use printf with proper escaping
      eval "declare -g -A ${output_variable}"
      for key in "${!parsed[@]}"; do
        # Use printf to safely escape the value
        printf -v escaped_value '%q' "${parsed[$key]}"
        eval "${output_variable}[${key}]=${escaped_value}"
      done
    fi

    return 0
  else
    return 1
  fi
}

#
# Recompose conventional commit message from parsed components
# Arguments:
#   $1: source variable name (optional, defaults to __conventional_parse_result)
# Returns:
#   Reconstructed commit message
#
function conventional:recompose() {
  local sourceVariableName="${1:-"__conventional_parse_result"}"
  declare -A parsed=()

  # Copy source associative array to local associative array
  local keys=() _keys
  _keys=$(eval "echo \"\${!${sourceVariableName}[@]}\"")
  for key in $_keys; do keys+=("$key"); done
  for key in "${keys[@]}"; do
    parsed[$key]="$(eval "echo \"\${${sourceVariableName}[\"$key\"]}\"")"
  done

  # Extract components
  local type="${parsed[type]}"
  local scope="${parsed[scope]}"
  local breaking="${parsed[breaking]}"
  local description="${parsed[description]}"
  local body="${parsed[body]}"
  local footer="${parsed[footer]}"

  # Build commit message
  local commit_msg="$type"
  [[ -n "$scope" ]] && commit_msg+="($scope)"
  [[ -n "$breaking" ]] && commit_msg+="$breaking"
  commit_msg+=": $description"
  [[ -n "$body" ]] && commit_msg+="\n\n$body"
  [[ -n "$footer" ]] && commit_msg+="\n\n$footer"

  echo -e "$commit_msg"
}

#
# Validate if a commit message follows conventional commit specification
# Arguments:
#   $1: commit message or commit hash (if hash, will fetch message)
# Returns:
#   0 if valid conventional commit, 1 otherwise
#
function conventional:is_valid_commit() {
  local input="$1"
  local commit_message

  # Determine if input is a commit hash or message
  if [[ "$input" =~ ^[a-f0-9]{7,40}$ ]]; then
    # Input looks like a commit hash, fetch the message
    if ! commit_message=$(git log -1 --pretty=%B "$input" 2>/dev/null); then
      return 1 # Failed to fetch commit message
    fi
    # Set global variables for commit hash
    __commit_sha="$input"
    __commit_msg="$commit_message"
  else
    # Input is the commit message itself
    commit_message="$input"
    # Set global variables for commit message
    __commit_sha=""
    __commit_msg="$commit_message"
  fi

  # Parse the commit message
  if conventional:parse "$commit_message"; then
    return 0 # Valid conventional commit
  else
    return 1 # Invalid conventional commit
  fi
}

#
# Detect is commit with specified hash (or HEAD) is a version modification commit
# Arguments:
#   $1: commit hash (optional)
# Returns:
#   0 if commit is a version modification commit, 1 otherwise
#
function conventional:is_version_commit() {
  local commit_sha=${1:-"HEAD"}
  local commit_msg

  # Get full commit message
  if ! commit_msg=$(git log -1 --pretty=%B "$commit_sha" 2>/dev/null); then
    return 1 # Failed to fetch commit message
  fi
  commit_msg=$(echo "$commit_msg" | tr '\n' ' ')

  # export commit message for debugging and other processing
  export __commit_msg="$commit_msg"

  # export commit sha for debugging and other processing
  export __commit_sha="$commit_sha"

  # Load config patterns or use default
  local config_file=".version-commit-config"
  local patterns=()

  if [ -f "$config_file" ]; then
    # Read patterns from config file, ignore empty lines and comments (#)
    mapfile -t patterns < <(grep -vE '^\s*(#|$)' "$config_file")
  else
    # Default set of patterns triggering version bump (adjust as needed)
    patterns=(
      '^feat(:|\!)'                             # feat: or feat!:
      '^fix(:|\!)'                              # fix: or fix!:
      '^perf(:|\!)'                             # perf: or perf!:
      'BREAKING CHANGE:'                        # any breaking change indicator
      '^(feat|fix|perf)(\([^)]+\))?(!)?:'     # any of feat, fix, perf with optional scope and exclamation mark
    )
  fi

  # Check commit message against all patterns
  for pat in "${patterns[@]}"; do
    if echo "$commit_msg" | grep -qE "$pat"; then
      return 0 # version commit detected
    fi
  done

  return 1 # no version bump trigger found
}

function conventional:is_change_commit() {
  # if detected version commit - return false (not a change commit)
  conventional:is_version_commit "$1" && return 1

  # If not a version commit, it's a change commit
  return 0
}

function conventional:validate:semantic_release() {
  if jq -e '.["release"]' package.json >/dev/null 2>&1; then
    echo "⚠️ Warning: package.json contains 'release' config (semantic-release). Please externalize it to a separate file (e.g., .releaserc.js)." >&2
  fi
}

function conventional:validate:standard_version() {
  if jq -e '.["standard-version"]' package.json >/dev/null 2>&1; then
    echo "⚠️ Warning: package.json contains 'standard-version' config. Please move this configuration to an external file (e.g., .versionrc)." >&2
  fi
}

function conventional:validate:commitizen() {
  if jq -e '.config.commitizen' package.json >/dev/null 2>&1; then
    echo "⚠️ Warning: package.json contains Commitizen config under 'config.commitizen'. Externalize to a dedicated config file (e.g., .cz-config.js)." >&2
  fi

  if jq -e '.["cz-customizable"]' package.json >/dev/null 2>&1; then
    echo "⚠️ Warning: package.json contains 'cz-customizable' config. Please externalize it."
  fi
}

function conventional:validate:commitlint() {
  if jq -e '.commitlint' package.json >/dev/null 2>&1; then
    echo "⚠️ Warning: package.json contains commitlint config. Please externalize it to a separate file (e.g., commitlint.config.js)." >&2
  fi
}

#
# Validate package.json for conventional commits setup.
# This function checks for the presence of semantic-release, standard-version, commitizen, and commitlint configurations.
# If any of these configurations are found, it prints a warning message.
# We want to keep all those configurations as externalized files and do not bloat package.json with them.
#
function conventional:validate:package_json() {
  if [ -f package.json ]; then
    conventional:validate:semantic_release
    conventional:validate:standard_version
    conventional:validate:commitizen
    conventional:validate:commitlint
  else
    echo "No package.json found. Skipping validation." >&2
  fi
}

# This is the writing style presented by ShellSpec, which is short but unfamiliar.
# Note that it returns the current exit status (could be non-zero).
# DO NOT allow execution of code bellow those line in shellspec tests
${__SOURCED__:+return}

# detect are we executed directly or sourced
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  conventional:is_valid_commit "$1" &&
    echo "Valid conventional commit (${__commit_sha:-"<no-hash>"}): ${__commit_msg}" >&2 ||
    echo "Invalid conventional commit (${__commit_sha:-"<no-hash>"}): ${__commit_msg}" >&2

  # print parsed result as key=value pairs
  for key in "${!__conventional_parse_result[@]}"; do
    echo "${key}=${__conventional_parse_result[$key]}"
  done

  # conventional:is_version_commit "$1" &&
  #   echo "Version commit (${__commit_sha}): ${__commit_msg}" >&2 ||
  #   echo "Changes commit (${__commit_sha}): ${__commit_msg}" >&2
fi

# References:
# - https://www.conventionalcommits.org/en/v1.0.0/
