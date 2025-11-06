#!/usr/bin/env bash
# shellcheck disable=SC2155,SC1090,SC2034,SC2059

## Git Semantic Version Calculator
## Analyzes conventional commits and calculates semantic version progression
##
## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-11-06
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# Setup terminal and bash options
if [[ -z $TERM ]]; then export TERM=xterm-256color; fi
shopt -s extdebug

# Skip automatic argument parsing during module loading
export SKIP_ARGS_PARSING=1

# Setup paths
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../.scripts && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_VERSION="1.0.0"

# Import utilities
# shellcheck source=../.scripts/_colors.sh
# shellcheck source=../.scripts/_commons.sh
# shellcheck source=../.scripts/_logger.sh
# shellcheck source=../.scripts/_arguments.sh
# shellcheck source=../.scripts/_semver.sh
source "$E_BASH/_colors.sh"
source "$E_BASH/_logger.sh"
source "$E_BASH/_arguments.sh"
source "$E_BASH/_semver.sh"
source "$E_BASH/_commons.sh"
# Note: _tmux.sh is loaded conditionally when --tmux-progress is used

# Configure logging
logger:init SemVer "[semver] " ">&2"

# Exit codes
readonly EXIT_OK=0
readonly EXIT_ERROR=1
readonly EXIT_NO_COMMITS=2
readonly EXIT_INVALID_ARGS=3

# ============================================================================
# Conventional Commit Configuration
# ============================================================================

## Default mapping of conventional commit types to bump types
## Format: "commit_type:bump_type" where bump_type is major|minor|patch|none
declare -A -g CONVENTIONAL_KEYWORDS=(
  [feat]="minor"
  [fix]="patch"
  [chore]="patch"
  [docs]="patch"
  [style]="patch"
  [refactor]="patch"
  [perf]="patch"
  [test]="patch"
  [build]="patch"
  [ci]="patch"
  [merge]="none"
)

## Add extra conventional commit keywords
## @param $1 - keyword name
## @param $2 - bump type (major|minor|patch|none)
function gitsv:add_keyword() {
  local keyword="$1"
  local bump_type="$2"

  # Validate bump type
  case "$bump_type" in
    major|minor|patch|none)
      CONVENTIONAL_KEYWORDS[$keyword]="$bump_type"
      echo:SemVer "Added keyword: $keyword → $bump_type"
      return 0
      ;;
    *)
      echo "${cl_red}Error: Invalid bump type '$bump_type'. Must be major, minor, patch, or none.${cl_reset}" >&2
      return 1
      ;;
  esac
}

## List all configured conventional commit keywords
function gitsv:list_keywords() {
  echo "${st_bold}${cl_cyan}Configured Conventional Commit Keywords:${cl_reset}"
  echo "────────────────────────────────────────"
  printf "%-15s | %s\n" "Keyword" "Bump Type"
  echo "────────────────────────────────────────"

  # Sort keywords alphabetically
  for keyword in $(echo "${!CONVENTIONAL_KEYWORDS[@]}" | tr ' ' '\n' | sort); do
    local bump_type="${CONVENTIONAL_KEYWORDS[$keyword]}"
    local color=""

    # Color by bump type
    case "$bump_type" in
      major) color="$cl_red" ;;
      minor) color="$cl_yellow" ;;
      patch) color="$cl_green" ;;
      none) color="$cl_grey" ;;
    esac

    printf "%-15s | ${color}%s${cl_reset}\n" "$keyword" "$bump_type"
  done

  echo "────────────────────────────────────────"
}

# ============================================================================
# PHASE 1: Conventional Commit Parsing
# ============================================================================

## Parse commit message and extract type (feat, fix, chore, etc.)
## @param $1 - commit message (first line)
## @return type name or "unknown"
function gitsv:parse_commit_type() {
  local commit_msg="$1"

  # Check for merge commit
  if [[ "$commit_msg" =~ ^Merge ]]; then
    echo "merge"
    return 0
  fi

  # Check for conventional commit pattern: type(scope)?: message
  if [[ "$commit_msg" =~ ^([a-z]+)(\([a-zA-Z0-9_-]+\))?!?:\ .+ ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi

  echo "unknown"
  return 0
}

## Check if commit message contains breaking change indicator
## @param $1 - full commit message (including body)
## @return 0 if breaking change, 1 otherwise
function gitsv:has_breaking_change() {
  local commit_msg="$1"

  # Check for ! in type
  if [[ "$commit_msg" =~ ^[a-z]+(\([a-zA-Z0-9_-]+\))?!: ]]; then
    return 0
  fi

  # Check for BREAKING CHANGE: or BREAKING-CHANGE: in body
  if [[ "$commit_msg" =~ BREAKING[\ -]CHANGE: ]]; then
    return 0
  fi

  return 1
}

## Determine version bump type based on commit message
## @param $1 - full commit message
## @return "major", "minor", "patch", or "none"
function gitsv:determine_bump() {
  local commit_msg="$1"
  local commit_type

  # Check for breaking change first (highest priority)
  if gitsv:has_breaking_change "$commit_msg"; then
    echo "major"
    return 0
  fi

  # Parse commit type
  commit_type=$(gitsv:parse_commit_type "$commit_msg")

  # Look up bump type from configuration
  if [[ -n "${CONVENTIONAL_KEYWORDS[$commit_type]}" ]]; then
    echo "${CONVENTIONAL_KEYWORDS[$commit_type]}"
  elif [[ "$commit_type" == "unknown" ]]; then
    # Ignore unknown commits (non-conventional format)
    echo "none"
  else
    # Fallback for any other case
    echo "none"
  fi

  return 0
}

## Bump version based on bump type
## @param $1 - current version (e.g., "1.2.3")
## @param $2 - bump type ("major", "minor", "patch", "none")
## @return new version
function gitsv:bump_version() {
  local current_version="$1"
  local bump_type="$2"

  case "$bump_type" in
    major)
      semver:increase:major "$current_version"
      ;;
    minor)
      semver:increase:minor "$current_version"
      ;;
    patch)
      semver:increase:patch "$current_version"
      ;;
    none)
      echo "$current_version"
      ;;
    *)
      echo "$current_version"
      ;;
  esac
}

## Calculate version difference
## @param $1 - version before
## @param $2 - version after
## @return version diff in format "+X.Y.Z" showing what was bumped
function gitsv:version_diff() {
  local ver_before="$1"
  local ver_after="$2"

  # If versions are the same, return +0.0.0
  if [[ "$ver_before" == "$ver_after" ]]; then
    echo "+0.0.0"
    return 0
  fi

  declare -A V_BEFORE V_AFTER
  semver:parse "$ver_before" V_BEFORE
  semver:parse "$ver_after" V_AFTER

  local major_diff=$((V_AFTER[major] - V_BEFORE[major]))
  local minor_diff=$((V_AFTER[minor] - V_BEFORE[minor]))
  local patch_diff=$((V_AFTER[patch] - V_BEFORE[patch]))

  # If major changed, show only major change (minor and patch were reset)
  if [[ $major_diff -ne 0 ]]; then
    echo "+${major_diff}.0.0"
    return 0
  fi

  # If minor changed, show minor and potential patch (patch was reset)
  if [[ $minor_diff -ne 0 ]]; then
    echo "+0.${minor_diff}.0"
    return 0
  fi

  # Only patch changed
  echo "+0.0.${patch_diff}"
}

# ============================================================================
# PHASE 2: Git Integration
# ============================================================================

## Get the first commit in the repository
## @return commit hash
function gitsv:get_first_commit() {
  git rev-list --max-parents=0 HEAD 2>/dev/null | head -n1
}

## Get git tags for a specific commit
## @param $1 - commit hash
## @return tag names (comma-separated if multiple)
function gitsv:get_commit_tags() {
  local commit_hash="$1"
  git tag --points-at "$commit_hash" 2>/dev/null | tr '\n' ',' | sed 's/,$//'
}

## Extract semver version from a git tag (strips any prefix)
## Uses semver:grep pattern from _semver.sh for robust extraction
## @param $1 - tag name (e.g., "v1.0.0", "package/test/v2.0.1-alpha+1")
## @return clean semver version or empty string if not a valid semver tag
function gitsv:extract_semver_from_tag() {
  local tag="$1"

  # Get semver regex pattern from _semver.sh
  local semver_pattern=$(semver:grep)

  # Extract semver part from tag using regex
  # This automatically strips any prefix (v, package/test/v, etc.)
  local semver_part=$(echo "$tag" | grep -oE "$semver_pattern")

  # Return the extracted semver (or empty if no match)
  echo "$semver_part"
}

## Get semver versions from commit tags
## @param $1 - comma-separated tag names
## @return comma-separated semver versions (may be empty if no valid semver tags)
function gitsv:extract_semvers_from_tags() {
  local tags="$1"
  local versions=""

  # Split tags by comma and process each
  IFS=',' read -ra tag_array <<< "$tags"
  for tag in "${tag_array[@]}"; do
    local version=$(gitsv:extract_semver_from_tag "$tag")
    if [[ -n "$version" ]]; then
      if [[ -z "$versions" ]]; then
        versions="$version"
      else
        versions="$versions,$version"
      fi
    fi
  done

  echo "$versions"
}

## Get the latest semantic version tag
## @return tag name (without 'v' prefix) or empty string
function gitsv:get_last_version_tag() {
  # Get all tags sorted by version
  local tags=$(git tag -l 2>/dev/null | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -n1)

  if [[ -n "$tags" ]]; then
    # Remove 'v' prefix if present
    echo "$tags" | sed 's/^v//'
  else
    echo ""
  fi
}

## Get commit hash of the latest version tag
## @return commit hash or empty string
function gitsv:get_last_version_tag_commit() {
  local tag=$(git tag -l 2>/dev/null | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -n1)

  if [[ -n "$tag" ]]; then
    git rev-list -n 1 "$tag" 2>/dev/null
  else
    echo ""
  fi
}

## Get commit where current branch diverged from main/master
## @return commit hash
function gitsv:get_branch_start_commit() {
  local main_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')

  if [[ -z "$main_branch" ]]; then
    # Try common names
    for branch in main master; do
      if git rev-parse --verify "$branch" >/dev/null 2>&1; then
        main_branch="$branch"
        break
      fi
    done
  fi

  if [[ -n "$main_branch" ]]; then
    git merge-base "$main_branch" HEAD 2>/dev/null
  else
    # Fallback to first commit
    gitsv:get_first_commit
  fi
}

## Get commit hash from N versions back
## @param $1 - number of versions to go back
## @return commit hash or empty string
function gitsv:get_commit_from_n_versions_back() {
  local n="$1"

  # Get all version tags sorted
  local tags=$(git tag -l 2>/dev/null | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+' | sort -V)
  local tag_count=$(echo "$tags" | wc -l)

  if [[ $tag_count -lt $n ]]; then
    # Not enough tags, return first commit
    gitsv:get_first_commit
    return 0
  fi

  # Get the Nth tag from the end
  local target_tag=$(echo "$tags" | tail -n "$n" | head -n1)

  if [[ -n "$target_tag" ]]; then
    git rev-list -n 1 "$target_tag" 2>/dev/null
  else
    echo ""
  fi
}

# ============================================================================
# PHASE 3: Starting Commit Strategy
# ============================================================================

## Determine starting commit based on strategy
## @param $1 - strategy name
## @param $2 - strategy parameter (optional, e.g., N for last-n-versions, hash for from-commit)
## @return commit hash
function gitsv:get_start_commit() {
  local strategy="$1"
  local param="$2"

  case "$strategy" in
    from-first-commit)
      gitsv:get_first_commit
      ;;
    from-last-tag)
      local commit=$(gitsv:get_last_version_tag_commit)
      if [[ -z "$commit" ]]; then
        echo:SemVer "No version tags found, using first commit"
        gitsv:get_first_commit
      else
        echo "$commit"
      fi
      ;;
    from-branch-start)
      gitsv:get_branch_start_commit
      ;;
    from-last-n-versions)
      if [[ -z "$param" ]] || [[ ! "$param" =~ ^[0-9]+$ ]]; then
        echo "Error: from-last-n-versions requires a numeric parameter" >&2
        return 1
      fi
      gitsv:get_commit_from_n_versions_back "$param"
      ;;
    from-commit)
      if [[ -z "$param" ]]; then
        echo "Error: from-commit requires a commit hash parameter" >&2
        return 1
      fi
      # Verify commit exists
      if git rev-parse --verify "$param" >/dev/null 2>&1; then
        git rev-parse "$param"
      else
        echo "Error: commit '$param' not found" >&2
        return 1
      fi
      ;;
    *)
      echo "Error: unknown strategy '$strategy'" >&2
      return 1
      ;;
  esac
}

# ============================================================================
# PHASE 4: Output Formatting
# ============================================================================

## Format a single output line in markdown format
## @param $1 - short hash
## @param $2 - commit message (first line)
## @param $3 - version before
## @param $4 - version after
## @param $5 - version diff (with color codes)
## @param $6 - git tag (optional)
function gitsv:format_output_line() {
  local hash="$1"
  local msg="$2"
  local ver_before="$3"
  local ver_after="$4"
  local diff="$5"
  local tag="${6:--}"

  # Markdown table format without padding
  printf "| %s | %s | %s | %s → %s | %s |\n" "$hash" "$msg" "$tag" "$ver_before" "$ver_after" "$diff"
}

## Print markdown table header
function gitsv:print_header() {
  echo "${st_bold}${cl_cyan}Semantic Version History${cl_reset}"
  echo ""
  printf "| %s | %s | %s | %s | %s |\n" "Commit" "Message" "Tag" "Version Change" "Diff"
  printf "|%s|%s|%s|%s|%s|\n" "--------" "--------" "--------" "--------" "--------"
}

## Print table footer (empty for markdown)
function gitsv:print_footer() {
  echo ""
}

# ============================================================================
# PHASE 5: Main Processing Logic
# ============================================================================

## Process commits and output version history
## @param $1 - start commit hash
## @param $2 - initial version
## @param $3 - enable tmux progress (true/false)
function gitsv:process_commits() {
  local start_commit="$1"
  local current_version="$2"
  local use_tmux="$3"

  # Get commit list from start to HEAD
  local commits=$(git rev-list --reverse "${start_commit}..HEAD" 2>/dev/null)

  if [[ -z "$commits" ]]; then
    echo "${cl_yellow}No commits found after start commit${cl_reset}" >&2
    return $EXIT_NO_COMMITS
  fi

  # Count commits for progress
  local total_commits=$(echo "$commits" | wc -l)
  local current_count=0

  # Statistics tracking
  local stat_major=0
  local stat_minor=0
  local stat_patch=0
  local stat_none=0
  local stat_tag=0

  echo:SemVer "Processing $total_commits commits from $start_commit to HEAD"

  # Print header
  gitsv:print_header

  # Setup tmux progress if enabled
  if [[ "$use_tmux" == "true" ]] && [[ -n "$TMUX" ]]; then
    # Load tmux utilities on demand
    if ! type -t tmux:init_progress >/dev/null 2>&1; then
      # shellcheck source=../.scripts/_tmux.sh
      source "$E_BASH/_tmux.sh"
    fi
    tmux:init_progress
    tmux:setup_trap
  fi

  # Process each commit
  while IFS= read -r commit_hash; do
    current_count=$((current_count + 1))

    # Get commit details
    local short_hash=$(git rev-parse --short "$commit_hash")
    local commit_msg=$(git log -1 --format=%B "$commit_hash")
    local first_line=$(git log -1 --format=%s "$commit_hash")
    local commit_tags=$(gitsv:get_commit_tags "$commit_hash")

    # Check if commit has semver tags that should override version
    local tag_versions=$(gitsv:extract_semvers_from_tags "$commit_tags")
    local version_before="$current_version"
    local version_after=""
    local bump_type=""
    local diff=""

    if [[ -n "$tag_versions" ]]; then
      # Tag sets the version - use first semver tag found
      version_after=$(echo "$tag_versions" | cut -d',' -f1)
      bump_type="tag"
      diff="=${version_after}"  # Format as ={version} for tags
      echo:SemVer "Tag found: $version_after (overriding calculated version)"
    else
      # No tag - calculate version from commit message
      bump_type=$(gitsv:determine_bump "$commit_msg")
      version_after=$(gitsv:bump_version "$current_version" "$bump_type")
      diff=$(gitsv:version_diff "$version_before" "$version_after")
    fi

    # Color the diff based on bump type and pre-release status
    local colored_diff="$diff"

    # Check if version has pre-release suffix (-alpha, -beta, -rc, etc.)
    if [[ "$version_after" =~ -[a-zA-Z] ]]; then
      # Pre-release version - purple
      colored_diff="${cl_purple}${diff}${cl_reset}"
    elif [[ "$bump_type" == "tag" ]]; then
      # Tag-based version - bold light white
      colored_diff="${st_bold}${cl_lwhite}${diff}${cl_reset}"
    else
      # Regular version - color by bump type
      case "$bump_type" in
        major)
          colored_diff="${cl_red}${st_bold}${diff}${cl_reset}"
          ;;
        minor)
          colored_diff="${cl_yellow}${diff}${cl_reset}"
          ;;
        patch)
          colored_diff="${cl_green}${diff}${cl_reset}"
          ;;
        none)
          colored_diff="${cl_grey}${diff}${cl_reset}"
          ;;
      esac
    fi

    # Format tag display with color if present
    # Show all tags (not just semver ones) in display
    local display_tag="${commit_tags:--}"
    if [[ -n "$commit_tags" && "$commit_tags" != "-" ]]; then
      display_tag="${cl_cyan}${commit_tags}${cl_reset}"
    fi

    # Format and print line
    gitsv:format_output_line \
      "$short_hash" \
      "$first_line" \
      "$version_before" \
      "$version_after" \
      "$colored_diff" \
      "$display_tag"

    # Update current version
    current_version="$version_after"

    # Track statistics
    case "$bump_type" in
      major) stat_major=$((stat_major + 1)) ;;
      minor) stat_minor=$((stat_minor + 1)) ;;
      patch) stat_patch=$((stat_patch + 1)) ;;
      none) stat_none=$((stat_none + 1)) ;;
      tag) stat_tag=$((stat_tag + 1)) ;;
    esac

    # Update progress
    echo:SemVer "[$current_count/$total_commits] $short_hash: $version_before → $version_after"

    # Update tmux progress if active
    if [[ "$use_tmux" == "true" ]] && [[ -n "$TMUX" ]]; then
      tmux:show_progress_bar "$current_count" "$total_commits" "Processing commits" 50
    fi

  done <<< "$commits"

  # Cleanup tmux if it was used
  if [[ "$use_tmux" == "true" ]] && [[ -n "$TMUX" ]]; then
    tmux:cleanup_progress
  fi

  # Print footer
  gitsv:print_footer

  # Print summary
  echo ""
  echo "${st_bold}Summary:${cl_reset}"
  echo "  Total commits processed: ${cl_cyan}${total_commits}${cl_reset}"
  echo "  Version changes:"
  echo "    ${cl_red}Major${cl_reset} (breaking): $stat_major"
  echo "    ${cl_yellow}Minor${cl_reset} (features): $stat_minor"
  echo "    ${cl_green}Patch${cl_reset} (fixes):    $stat_patch"
  echo "    ${cl_cyan}${st_bold}Tag${cl_reset}   (assigned): $stat_tag"
  echo "    ${cl_grey}None${cl_reset}  (ignored):  $stat_none"
  echo ""
  echo "${st_bold}Final Version:${cl_reset} ${cl_green}${current_version}${cl_reset}"

  return $EXIT_OK
}

# ============================================================================
# PHASE 6: CLI Argument Parsing and Help
# ============================================================================

## Print help message
function print:help() {
  cat <<EOF
${st_bold}${cl_cyan}$SCRIPT_NAME${cl_reset} v$SCRIPT_VERSION

${st_bold}DESCRIPTION:${cl_reset}
  Analyzes git commit messages using Conventional Commits specification
  and calculates semantic version progression throughout repository history.

${st_bold}USAGE:${cl_reset}
  $SCRIPT_NAME [OPTIONS]

${st_bold}OPTIONS:${cl_reset}
  -h, --help                    Show this help message
  --list-keywords               List all configured conventional commit keywords

  ${st_bold}Starting Point:${cl_reset}
  --from-first-commit           Start from the first commit in repo (default)
  --from-last-tag               Start from the most recent version tag
  --from-branch-start           Start from where current branch diverged
  --from-last-n-versions N      Start from N versions back
  --from-commit HASH            Start from specific commit hash

  ${st_bold}Configuration:${cl_reset}
  --initial-version VERSION     Initial version to use (default: 0.0.1)
  --add-keyword TYPE:BUMP       Add custom conventional commit keyword
                                TYPE is the commit prefix (e.g., wip)
                                BUMP is major, minor, patch, or none
                                Can be specified multiple times
                                Example: --add-keyword wip:patch
  --tmux-progress               Enable tmux progress display (if tmux available)

${st_bold}EXAMPLES:${cl_reset}
  # Show version history from first commit
  $SCRIPT_NAME

  # Show version history from last tagged version
  $SCRIPT_NAME --from-last-tag

  # Start from specific commit with custom initial version
  $SCRIPT_NAME --from-commit abc1234 --initial-version 1.0.0

  # Show last 3 versions of changes
  $SCRIPT_NAME --from-last-n-versions 3

  # Add custom keyword 'wip' that bumps patch version
  $SCRIPT_NAME --add-keyword wip:patch

  # Multiple custom keywords
  $SCRIPT_NAME --add-keyword wip:patch --add-keyword experiment:none

${st_bold}CONVENTIONAL COMMITS:${cl_reset}
  This tool follows the Conventional Commits specification (conventionalcommits.org)

  ${st_bold}Commit Types:${cl_reset}
    feat:      New feature (bumps ${cl_yellow}MINOR${cl_reset})
    fix:       Bug fix (bumps ${cl_green}PATCH${cl_reset})
    BREAKING:  Breaking change (bumps ${cl_red}MAJOR${cl_reset})
    chore/docs/refactor/test/ci/perf: All bump ${cl_green}PATCH${cl_reset}

  ${st_bold}Color Scheme:${cl_reset}
    ${cl_red}Red${cl_reset}     - Major version bump (breaking changes)
    ${cl_yellow}Yellow${cl_reset}  - Minor version bump (new features)
    ${cl_green}Green${cl_reset}   - Patch version bump (fixes, chores)
    ${cl_purple}Purple${cl_reset}  - Pre-release versions (-alpha, -beta, -rc)

${st_bold}OUTPUT FORMAT:${cl_reset}
  <hash> | <commit message> | <version before> → <version after> | <diff>

EOF
}

## Parse command line arguments
function parse:cli:arguments() {
  # Default values
  STRATEGY="from-first-commit"
  STRATEGY_PARAM=""
  INITIAL_VERSION="0.0.1"
  USE_TMUX="false"
  SHOW_HELP="false"
  LIST_KEYWORDS="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        SHOW_HELP="true"
        shift
        ;;
      --list-keywords)
        LIST_KEYWORDS="true"
        shift
        ;;
      --from-first-commit)
        STRATEGY="from-first-commit"
        shift
        ;;
      --from-last-tag)
        STRATEGY="from-last-tag"
        shift
        ;;
      --from-branch-start)
        STRATEGY="from-branch-start"
        shift
        ;;
      --from-last-n-versions)
        STRATEGY="from-last-n-versions"
        STRATEGY_PARAM="$2"
        shift 2
        ;;
      --from-commit)
        STRATEGY="from-commit"
        STRATEGY_PARAM="$2"
        shift 2
        ;;
      --initial-version)
        INITIAL_VERSION="$2"
        shift 2
        ;;
      --add-keyword)
        # Parse keyword:bump format
        local keyword_def="$2"
        if [[ ! "$keyword_def" =~ ^([a-z]+):(major|minor|patch|none)$ ]]; then
          echo "${cl_red}Error: Invalid keyword format '$keyword_def'${cl_reset}" >&2
          echo "Expected format: TYPE:BUMP (e.g., wip:patch)" >&2
          return $EXIT_INVALID_ARGS
        fi
        local kw_type="${BASH_REMATCH[1]}"
        local kw_bump="${BASH_REMATCH[2]}"
        gitsv:add_keyword "$kw_type" "$kw_bump" || return $EXIT_INVALID_ARGS
        shift 2
        ;;
      --tmux-progress)
        USE_TMUX="true"
        shift
        ;;
      *)
        echo "${cl_red}Error: Unknown option '$1'${cl_reset}" >&2
        echo "Use --help for usage information" >&2
        return $EXIT_INVALID_ARGS
        ;;
    esac
  done

  return $EXIT_OK
}

# ============================================================================
# Main Entry Point
# ============================================================================

## Cleanup function
function on_exit() {
  local exit_code=$?
  echo:SemVer "Exiting with code $exit_code"
  return $exit_code
}

## Main function
function main() {
  # Parse arguments
  parse:cli:arguments "$@" || return $?

  # Show help if requested
  if [[ "$SHOW_HELP" == "true" ]]; then
    print:help
    return $EXIT_OK
  fi

  # List keywords if requested
  if [[ "$LIST_KEYWORDS" == "true" ]]; then
    gitsv:list_keywords
    return $EXIT_OK
  fi

  # Verify we're in a git repository
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "${cl_red}Error: Not a git repository${cl_reset}" >&2
    return $EXIT_ERROR
  fi

  # Validate initial version
  if ! [[ "$INITIAL_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "${cl_red}Error: Invalid initial version '$INITIAL_VERSION'${cl_reset}" >&2
    echo "Expected format: X.Y.Z (e.g., 0.0.1)" >&2
    return $EXIT_INVALID_ARGS
  fi

  # Get starting commit
  local start_commit=$(gitsv:get_start_commit "$STRATEGY" "$STRATEGY_PARAM")
  if [[ $? -ne 0 ]] || [[ -z "$start_commit" ]]; then
    echo "${cl_red}Error: Could not determine starting commit${cl_reset}" >&2
    return $EXIT_ERROR
  fi

  echo:SemVer "Strategy: $STRATEGY"
  echo:SemVer "Start commit: $start_commit"
  echo:SemVer "Initial version: $INITIAL_VERSION"

  # Process commits
  gitsv:process_commits "$start_commit" "$INITIAL_VERSION" "$USE_TMUX"

  return $?
}

# Setup exit trap
trap on_exit EXIT INT TERM

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
  exit $?
fi
