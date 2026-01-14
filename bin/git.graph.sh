#!/usr/bin/env bash
# shellcheck disable=SC2155,SC1090,SC2034

## Git Branch Graph Visualization
## Simple wrapper around git log with beautiful formatting
##
## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-14
## Version: 2.0.1
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# Ultra-optimized bootstrap: E_BASH discovery + gnubin PATH
[ "$E_BASH" ] || { _src=${BASH_SOURCE:-$0}; E_BASH=$(cd "${_src%/*}/../.scripts" 2>&- && pwd || echo ~/.e-bash/.scripts); readonly E_BASH; . "$E_BASH/_gnu.sh"; PATH="$E_BASH/../bin/gnubin:$PATH"; }

# Import colors
# shellcheck source=../.scripts/_colors.sh
source "$E_BASH/_colors.sh"

## Print help message
function print_help() {
  cat <<EOF
${st_bold}${cl_cyan}git.graph.sh${cl_reset} - Git Branch Graph Visualization

${st_bold}USAGE:${cl_reset}
  git.graph.sh [OPTIONS] [GIT_LOG_OPTIONS]

${st_bold}OPTIONS:${cl_reset}
  -h, --help        Show this help message
  -n, --lines N     Number of commits to show (default: 20)
  -a, --all         Show all branches (default: current branch only)
  -s, --simple      Simple format without dates
  -f, --full        Full format with author and date

${st_bold}EXAMPLES:${cl_reset}
  # Show last 20 commits of current branch
  git.graph.sh

  # Show last 50 commits of all branches
  git.graph.sh --all --lines 50

  # Show simple graph without dates
  git.graph.sh --simple

  # Pass custom git log options
  git.graph.sh --since="2 weeks ago" --author="John"

${st_bold}GIT ALIASES:${cl_reset}
  You can add these to your ~/.gitconfig:

  [alias]
    graph = log --all --decorate --oneline --graph
    lg = log --graph --pretty=format:'%C(red)%h%C(reset) -%C(yellow)%d%C(reset) %s %C(green)(%cr) %C(bold blue)<%an>%C(reset)' --abbrev-commit

EOF
}

## Main function
function main() {
  local lines=20
  local show_all=false
  local format="medium"
  local extra_args=()

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        print_help
        return 0
        ;;
      -n|--lines)
        lines="$2"
        shift 2
        ;;
      -a|--all)
        show_all=true
        shift
        ;;
      -s|--simple)
        format="simple"
        shift
        ;;
      -f|--full)
        format="full"
        shift
        ;;
      *)
        # Pass through to git log
        extra_args+=("$1")
        shift
        ;;
    esac
  done

  # Build git log command
  local git_cmd="git log"
  [[ "$show_all" == "true" ]] && git_cmd+=" --all"
  git_cmd+=" --decorate"
  git_cmd+=" --graph"
  git_cmd+=" -n $lines"

  # Set format
  case "$format" in
    simple)
      git_cmd+=" --oneline"
      ;;
    full)
      git_cmd+=" --pretty=format:'%C(red)%h%C(reset) -%C(yellow)%d%C(reset) %s %C(green)(%cr) %C(bold blue)<%an>%C(reset)'"
      git_cmd+=" --abbrev-commit"
      ;;
    medium)
      git_cmd+=" --pretty=format:'%C(auto)%h%C(reset) -%C(auto)%d%C(reset) %s %C(green)(%cr)%C(reset)'"
      git_cmd+=" --abbrev-commit"
      ;;
  esac

  # Add extra arguments
  for arg in "${extra_args[@]}"; do
    git_cmd+=" $arg"
  done

  # Execute command
  echo "${cl_cyan}${st_bold}Git Branch Graph${cl_reset}" >&2
  echo "${cl_grey}Command: $git_cmd${cl_reset}" >&2
  echo "" >&2

  eval "$git_cmd"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
