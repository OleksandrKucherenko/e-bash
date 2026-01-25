#!/usr/bin/env bash
# shellcheck disable=SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-25
## Version: 2.7.8
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# Prepares repository headers for a release by updating version/date metadata.

# E_BASH is globally available via direnv. If for some reason it's not set, provide a fallback
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../../.scripts && pwd)"

export DEBUG=${DEBUG:-"prep,warn,error,ok,exec,dry,output"}
export DRY_RUN=${DRY_RUN:-false}
export SKIP_ARGS_PARSING=1 # skip arguments parsing during script loading

# shellcheck disable=SC1090 source=../../../.scripts/_commons.sh
source "${E_BASH}/_commons.sh"
# shellcheck disable=SC1090 source=../../../.scripts/_dryrun.sh
source "${E_BASH}/_dryrun.sh"
# shellcheck disable=SC1090 source=../../../.scripts/_arguments.sh
source "${E_BASH}/_arguments.sh"

logger:init prep "  " ">&2"
logger:init warn "[${cl_yellow}warn${cl_reset}] " ">&2"
logger:init error "[${cl_red}error${cl_reset}] " ">&2"
logger:init ok "[${cl_green}ok${cl_reset}] " ">&1"

dry-run gsed ggrep
declare help version args_version args_date

readonly VERSION="1.0.0"
export ARGS_DEFINITION=""
export COMPOSER="
  $(args:i help -a "-h,--help" -d "1" -h "Show help and exit." -g mode)
  $(args:i version -a "--version" -d "${VERSION}" -h "Show version and exit." -g mode)
  $(args:i args_version -a "-n,--next-version" -q 1 -h "Release version to write in headers (required)." -g common)
  $(args:i args_date -a "--date" -q 1 -d "$(date +%Y-%m-%d)" -h "Date to write in headers (YYYY-MM-DD)." -g common)
  $(args:i DRY_RUN -a "--dry-run" -d "true" -h "Show gsed commands without modifying files." -g mode)
  $(args:i DEBUG -a "--verbose" -d "*" -h "Log each processed file." -g mode)
"
eval "$COMPOSER" >/dev/null
parse:arguments "$@"

usage() {
  echo "Usage:"
  echo "  ${cl_yellow}$0${cl_reset} --next-version <version> [--date <date>] [--dry-run] [--verbose]"
  echo ""
  print:help
}

is_excluded_path() {
  case "$1" in
  .github/scripts/*) return 0 ;;
  spec/fixtures/*) return 0 ;;
  .githook/*) return 0 ;;
  .claude/*) return 0 ;;
  .clavix/*) return 0 ;;
  docs/*) return 0 ;;
  esac

  return 1
}

should_include_path() {
  local path="$1"

  if is_excluded_path "$path"; then
    return 1
  fi

  case "$path" in

  .githook/*)
    return 0
    ;;
  *.sh)
    return 0
    ;;
  esac

  return 1
}

# Verify arguments that allows quick exit from the script: help, version.
function parse_quick_arguments() {
  local args=("$@")

  # parse input parameters
  if [[ "$help" == "1" ]]; then
    usage
    # shellcheck disable=SC2086
    exit 0
  elif [[ -n "$version" ]]; then
    echo "version: ${version}"
    # shellcheck disable=SC2086
    exit 0
  fi
}

function main() {
  # check arguments for quick exit flags
  parse_quick_arguments "$@"

  local repo_root
  repo_root=$(git:root)

  if [[ -z "$args_version" ]]; then
    echo:Error "Missing required --next-version argument"
    usage
    return 1
  fi

  local updated=0
  local missing_headers=0
  local skipped=0
  local rel_path abs_path
  local has_date has_version
  local repo_files=()

  # read all files from the repository
  mapfile -d '' repo_files < <(git -C "$repo_root" ls-files -z)

  echo:Ok "Processing ${#repo_files[@]} files..."

  for rel_path in "${repo_files[@]}"; do
    if ! should_include_path "$rel_path"; then
      skipped=$((skipped + 1))
      continue
    fi

    abs_path="${repo_root}/${rel_path}"
    [[ -f "$abs_path" ]] || continue

    # detect copyright header current values
    has_date=false
    has_version=false

    if "ggrep" -q "^## Last revisit:" "$abs_path"; then
      has_date=true
    fi
    if "ggrep" -q "^## Version:" "$abs_path"; then
      has_version=true
    fi

    # skip if no header found
    if [[ "$has_date" != "true" || "$has_version" != "true" ]]; then
      missing_headers=$((missing_headers + 1))
      echo:Warn "missing header: ${rel_path}"
      continue
    fi

    # patching header values
    dry:gsed -i -e "s/^## Last revisit:.*/## Last revisit: ${args_date}/" "$abs_path"
    dry:gsed -i -e "s/^## Version:.*/## Version: ${args_version}/" "$abs_path"

    updated=$((updated + 1))
    echo:Prep "📝 ${rel_path}"
  done

  printf:Ok "updated=%s missing_headers=%s skipped=%s\n" "$updated" "$missing_headers" "$skipped"
}

main "$@"
