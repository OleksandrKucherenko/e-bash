#!/usr/bin/env bash
# shellcheck disable=SC2155,SC1090,SC1091,SC2034,SC2059

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-05-23
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# logs.sh - capture and search logs from multiple services at once.
#
#   capture: run several long-running commands in parallel, tag every line,
#            write raw per-service files + one consolidated file, and stream a
#            colored, keyword-highlighted, JSON-aware joined view to the terminal.
#   search:  fuzzy-search a recorded run with fzf, previewing the focused line
#            (pretty JSON when applicable).
#
# See `logs.sh --help`, `logs.sh capture --help`, `logs.sh search --help`.

# Setup terminal
if [[ -z $TERM ]]; then export TERM=xterm-256color; fi

# We parse arguments ourselves (the --service flag is repeatable).
export SKIP_ARGS_PARSING=1

# Bootstrap: 1) E_BASH discovery (only if not set), 2) gnubin setup (always)
[ "$E_BASH" ] || {
  _src=${BASH_SOURCE:-$0}
  E_BASH=$(cd "${_src%/*}/../.scripts" 2>&- && pwd || echo ~/.e-bash/.scripts)
  readonly E_BASH
}
. "$E_BASH/_gnu.sh"
PATH="$(cd "$E_BASH/../bin/gnubin" 2>&- && pwd):$PATH"

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>&- && pwd)/$SCRIPT_NAME"
readonly SCRIPT_VERSION="1.0.0"

# Keep our own status line visible by default; silence with DEBUG="" or tune with DEBUG=*.
DEBUG="${DEBUG:-logs}"

# shellcheck source=../.scripts/_colors.sh
source "$E_BASH/_colors.sh"
# shellcheck source=../.scripts/_logger.sh
source "$E_BASH/_logger.sh"
# shellcheck source=../.scripts/_dependencies.sh
source "$E_BASH/_dependencies.sh"
# shellcheck source=../.scripts/_commons.sh
source "$E_BASH/_commons.sh"

# Exit codes
readonly EXIT_OK=0
readonly EXIT_ERROR=1
readonly EXIT_INVALID_ARGS=2
readonly EXIT_MISSING_DEP=3

# Module configuration (overridable via env or flags)
LOGS_BASE_DIR="${LOGS_BASE_DIR:-}"                                                            # default resolved to $PWD/.logs
LOGS_CONFIG_NAME="${LOGS_CONFIG_NAME:-.logs-services}"                                         # discovered config file name
LOGS_HIGHLIGHT="${LOGS_HIGHLIGHT:-ERROR:lred,FATAL:lred,FAIL:lred,WARN:yellow,WARNING:yellow}" # keyword:color pairs
LOGS_TIMESTAMPS="${LOGS_TIMESTAMPS:-}"                                                         # non-empty => prepend UTC time to each line

# Runtime state
declare -a SERVICES=() # registered "tag=command" specs
VIEW="${VIEW:-joined}" # joined | separated | none

# Module internals
__LOGS_RUN_DIR=""
__LOGS_CLEANED=""
__LOGS_HAS_JQ=""
__LOGS_HAS_STDBUF=""
__LOGS_HAS_SETSID=""
declare -a __LOGS_FIFOS=()
declare -a __LOGS_PALETTE=()

# Capability probes + per-tag color palette (built before the source guard so
# tests that `Include` this file can exercise the pure functions).
__LOGS_HAS_JQ="$(command -v jq || true)"
__LOGS_HAS_STDBUF="$(command -v stdbuf || true)"
__LOGS_HAS_SETSID="$(command -v setsid || true)"
# Only the basic 3x ANSI foregrounds are reliably well-formed across terminfos
# (the cl_l* "light" variants resolve to malformed setaf 9..16 sequences here).
__LOGS_PALETTE=("$cl_green" "$cl_yellow" "$cl_blue" "$cl_purple" "$cl_cyan" "$cl_red" "$cl_white")

# ============================================================================
# Small helpers
# ============================================================================

function _logs:die() {
  local code="$1"
  shift
  echo "${cl_red}error:${cl_reset} $*" >&2
  exit "$code"
}

# Die when a value-taking flag has no value left to consume (prevents the
# parser from spinning when `shift 2` would fail on a missing argument).
function _logs:need() {
  [[ "$1" -ge 2 ]] || _logs:die "$EXIT_INVALID_ARGS" "missing value for $2"
}

# Are colors disabled for this session?
function _logs:no_color() {
  [[ -n "${NO_COLOR:-}" || "$TERM" == "dumb" ]]
}

# Sanitize a tag into a safe file name component.
function _logs:slug() {
  local s="$1"
  printf '%s' "${s//[^A-Za-z0-9._-]/_}"
}

# Split "tag=command" into tag + command via namerefs. First '=' wins so the
# command may itself contain '='. Returns 1 when malformed.
function _logs:parse_service() {
  local spec="$1"
  local -n _ps_tag="$2" _ps_cmd="$3"
  [[ "$spec" != *=* ]] && return 1
  _ps_tag="${spec%%=*}"
  _ps_cmd="${spec#*=}"
  [[ -z "$_ps_tag" || -z "$_ps_cmd" ]] && return 1
  return 0
}

# Is a "tag" already registered in SERVICES?
function _logs:has_tag() {
  local want="$1" spec
  for spec in "${SERVICES[@]}"; do
    [[ "${spec%%=*}" == "$want" ]] && return 0
  done
  return 1
}

# ============================================================================
# Run directory management
# ============================================================================

function _logs:base_dir() {
  if [[ -n "$LOGS_BASE_DIR" ]]; then
    printf '%s' "$LOGS_BASE_DIR"
  else
    printf '%s' "$PWD/.logs"
  fi
}

# Create and echo a fresh run directory: <base>/<UTC-timestamp>/
function logs:run_dir() {
  local base ts dir
  base="$(_logs:base_dir)"
  ts="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
  dir="$base/$ts"
  mkdir -p "$dir" || return 1
  printf '%s' "$dir"
}

# Echo the newest run directory under <base> (latest symlink preferred).
function logs:latest_run() {
  local base="${1:-$(_logs:base_dir)}" latest
  if [[ -L "$base/latest" ]]; then
    latest="$(readlink -f "$base/latest" 2>/dev/null)"
    [[ -d "$latest" ]] && {
      printf '%s' "$latest"
      return
    }
  fi
  latest="$(ls -1d "$base"/*/ 2>/dev/null | grep -v '/latest/$' | LC_ALL=C sort | tail -1)"
  [[ -n "$latest" ]] && printf '%s' "${latest%/}"
}

function _logs:update_latest() {
  local run_dir="$1" base
  base="$(dirname "$run_dir")"
  ln -sfn "$run_dir" "$base/latest" 2>/dev/null || true
}

# ============================================================================
# Rendering: per-tag color, JSON detection, keyword highlight, colorizer
# ============================================================================

# Deterministic ANSI color for a tag (empty when colors are disabled).
function _logs:tag_color() {
  local tag="$1" sum=0 i ch n
  _logs:no_color && return 0
  n=${#__LOGS_PALETTE[@]}
  [[ "$n" -eq 0 ]] && return 0
  for ((i = 0; i < ${#tag}; i++)); do
    printf -v ch '%d' "'${tag:i:1}"
    sum=$((sum + ch))
  done
  printf '%s' "${__LOGS_PALETTE[$((sum % n))]}"
}

# Return success when $1 is a JSON object/array (cheap first-char gate, then jq).
function _logs:is_json() {
  [[ -n "$__LOGS_HAS_JQ" ]] || return 1
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}" # left-trim
  case "$s" in
  '{'* | '['*) printf '%s' "$1" | jq -e . >/dev/null 2>&1 ;;
  *) return 1 ;;
  esac
}

# Colorize keywords (terminal only). Echoes the transformed text (no newline).
function _logs:highlight() {
  local text="$1" pairs pair kw clr var
  { _logs:no_color || [[ -z "$LOGS_HIGHLIGHT" ]]; } && {
    printf '%s' "$text"
    return
  }
  IFS=',' read -ra pairs <<<"$LOGS_HIGHLIGHT"
  for pair in "${pairs[@]}"; do
    kw="${pair%%:*}"
    clr="${pair##*:}"
    var="cl_${clr}"
    [[ -z "$kw" ]] && continue
    text="$(printf '%s' "$text" | sed -E "s/\b(${kw})\b/${!var:-}\1${cl_reset}/Ig")"
  done
  printf '%s' "$text"
}

# Render a JSON value compact (colored unless colors are disabled), or fall
# back to the raw text on any jq failure.
function _logs:render_json_compact() {
  local raw="$1" out
  local -a flags=(-c)
  _logs:no_color || flags=(-C -c)
  if out="$(printf '%s' "$raw" | jq "${flags[@]}" . 2>/dev/null)"; then
    printf '%s' "$out"
  else
    printf '%s' "$raw"
  fi
}

# Read consolidated "<tag> <body>" lines from stdin, render to the terminal.
function _logs:colorize() {
  local line tag rest color
  while IFS= read -r line; do
    if [[ "$line" == *" "* ]]; then
      tag="${line%% *}"
      rest="${line#* }"
    else
      tag="$line"
      rest=""
    fi
    color="$(_logs:tag_color "$tag")"
    if _logs:is_json "$rest"; then
      rest="$(_logs:render_json_compact "$rest")"
    else
      rest="$(_logs:highlight "$rest")"
    fi
    if [[ -n "$color" ]]; then
      printf '%s%s%s %s\n' "$color" "$tag" "$cl_reset" "$rest"
    else
      printf '%s %s\n' "$tag" "$rest"
    fi
  done
}

# ============================================================================
# Capture: workers, supervisor, views
# ============================================================================

# Drain a worker's FIFO from stdin: raw line -> per-tag file, tagged line ->
# consolidated file. Both via O_APPEND fds so concurrent workers never
# interleave a single (sub-PIPE_BUF) line. No read timeout: long idle gaps are
# fine (unlike the logger's pipe mode).
function _logs:reader() {
  local tag="$1" per_tag="$2" all="$3" line body
  exec 3>>"$per_tag" 4>>"$all"
  while IFS= read -r line; do
    if [[ -n "$LOGS_TIMESTAMPS" ]]; then body="$(date -u +%H:%M:%S.%3N) $line"; else body="$line"; fi
    printf '%s\n' "$body" >&3
    printf '%s %s\n' "$tag" "$body" >&4
  done
  # flush a trailing partial line that arrived without a newline
  if [[ -n "${line:-}" ]]; then
    if [[ -n "$LOGS_TIMESTAMPS" ]]; then body="$(date -u +%H:%M:%S.%3N) $line"; else body="$line"; fi
    printf '%s\n' "$body" >&3
    printf '%s %s\n' "$tag" "$body" >&4
  fi
  exec 3>&- 4>&-
}

# Launch one service: FIFO + reader (child) + producer (detached process group).
function _logs:worker() {
  local tag="$1" run_dir="$2" all="$3" cmd="$4"
  local slug per_tag fifo bufwrap=""
  slug="$(_logs:slug "$tag")"
  per_tag="$run_dir/$slug.log"
  fifo="$run_dir/.fifo.$slug"
  : >"$per_tag"
  mkfifo "$fifo" 2>/dev/null || true
  __LOGS_FIFOS+=("$fifo")

  # Reader is a normal child; it ends on producer EOF.
  _logs:reader "$tag" "$per_tag" "$all" <"$fifo" &

  [[ -n "$__LOGS_HAS_STDBUF" ]] && bufwrap="stdbuf -oL -eL "

  # Producer: a new session (setsid) so the whole subtree is killable as one
  # process group. It records its own leader PID (== PGID), then exec's the
  # user command with merged stdout+stderr into the FIFO.
  if [[ -n "$__LOGS_HAS_SETSID" ]]; then
    setsid bash -c 'echo "$$" >>"$1"; shift; exec '"$bufwrap"'bash -c "$1"' \
      _ "$run_dir/.pids" "$cmd" >"$fifo" 2>&1 &
  else
    # Fallback (e.g. macOS without setsid): direct child, killed by PID only.
    eval "$bufwrap"'bash -c "$cmd"' >"$fifo" 2>&1 &
    echo "$!" >>"$run_dir/.pids"
  fi
}

# Terminate every recorded producer process group, stop our jobs, drop FIFOs.
function _logs:cleanup() {
  [[ -n "$__LOGS_CLEANED" ]] && return 0
  __LOGS_CLEANED=1
  local pid f j
  if [[ -r "$__LOGS_RUN_DIR/.pids" ]]; then
    while read -r pid; do
      [[ -n "$pid" ]] || continue
      if [[ -n "$__LOGS_HAS_SETSID" ]]; then kill -TERM -- "-$pid" 2>/dev/null || true; else kill -TERM "$pid" 2>/dev/null || true; fi
    done <"$__LOGS_RUN_DIR/.pids"
    sleep 0.2
    while read -r pid; do
      [[ -n "$pid" ]] || continue
      if [[ -n "$__LOGS_HAS_SETSID" ]]; then kill -KILL -- "-$pid" 2>/dev/null || true; else kill -KILL "$pid" 2>/dev/null || true; fi
    done <"$__LOGS_RUN_DIR/.pids"
  fi
  for j in $(jobs -p 2>/dev/null); do kill "$j" 2>/dev/null || true; done
  for f in "${__LOGS_FIFOS[@]}"; do [[ -p "$f" ]] && rm -f "$f"; done
}

# Print "tail -F" hints for the separated-view fallback.
function _logs:print_tail_hints() {
  local run_dir="$1" spec tag _cmd
  echo "  watch a single service with tail -F:" >&2
  for spec in "${SERVICES[@]}"; do
    _logs:parse_service "$spec" tag _cmd || continue
    echo "    tail -F '$run_dir/$(_logs:slug "$tag").log'" >&2
  done
  echo "    tail -F '$run_dir/all.log'   # consolidated" >&2
}

# One tmux pane per service (used by --separated and the __tailview subcommand).
function logs:view:tail() {
  local run_dir="$1" tag="$2" slug f line
  slug="$(_logs:slug "$tag")"
  f="$run_dir/$slug.log"
  printf '=== %s (%s) ===\n' "$tag" "$f"
  tail -n +1 -F "$f" 2>/dev/null | while IFS= read -r line; do
    if _logs:is_json "$line"; then
      _logs:render_json_compact "$line"
      printf '\n'
    else
      _logs:highlight "$line"
      printf '\n'
    fi
  done
}

function _logs:view_separated() {
  local run_dir="$1" session="logs_$$" spec tag _cmd first_tag=""
  if ! command -v tmux >/dev/null 2>&1 || [[ ! -t 1 ]]; then
    echo:Logs "${cl_yellow}separated view needs tmux on a terminal; logs are still on disk${cl_reset}"
    _logs:print_tail_hints "$run_dir"
    wait
    return
  fi
  for spec in "${SERVICES[@]}"; do
    _logs:parse_service "$spec" first_tag _cmd && break
  done
  tmux new-session -d -s "$session" "'$SCRIPT_PATH' __tailview '$run_dir' '$first_tag'" 2>/dev/null || {
    echo:Logs "${cl_yellow}could not start tmux; falling back to files${cl_reset}"
    _logs:print_tail_hints "$run_dir"
    wait
    return
  }
  local started=""
  for spec in "${SERVICES[@]}"; do
    _logs:parse_service "$spec" tag _cmd || continue
    if [[ -z "$started" ]]; then
      started=1
      continue
    fi # first pane already created
    tmux split-window -t "$session" "'$SCRIPT_PATH' __tailview '$run_dir' '$tag'" 2>/dev/null
    tmux select-layout -t "$session" tiled >/dev/null 2>&1
  done
  # When tmux exits (window closed / detached), fall through to cleanup via trap.
  tmux attach-session -t "$session"
  tmux kill-session -t "$session" 2>/dev/null || true
}

# Read a config file of "tag=command" lines into SERVICES (CLI wins on conflict).
function _logs:load_config() {
  local explicit="$1" file="" line tag
  if [[ -n "$explicit" ]]; then
    file="$explicit"
    [[ -r "$file" ]] || _logs:die "$EXIT_INVALID_ARGS" "config not readable: $file"
  else
    # config:hierarchy lists matches root-to-current; the nearest is last.
    file="$(config:hierarchy "$LOGS_CONFIG_NAME" "." "git" "" 2>/dev/null | tail -1)"
  fi
  [[ -z "$file" || ! -r "$file" ]] && return 0
  echo:Logs "loading services from ${cl_yellow}$file${cl_reset}"
  while IFS= read -r line; do
    line="${line%%#*}"                          # strip comments
    line="${line#"${line%%[![:space:]]*}"}"     # ltrim
    line="${line%"${line##*[![:space:]]}"}"      # rtrim
    [[ -z "$line" || "$line" != *=* ]] && continue
    tag="${line%%=*}"
    _logs:has_tag "$tag" && continue # CLI override
    SERVICES+=("$line")
  done <"$file"
}

# Capture supervisor: spawn workers, register cleanup, run the chosen view.
function logs:capture() {
  local run_dir all spec tag cmd
  run_dir="$(logs:run_dir)" || _logs:die "$EXIT_ERROR" "could not create run directory"
  all="$run_dir/all.log"
  __LOGS_RUN_DIR="$run_dir"
  : >"$all"
  : >"$run_dir/.pids"
  {
    echo "# logs.sh capture"
    echo "started=$(date -u +%FT%TZ)"
    echo "version=$SCRIPT_VERSION"
  } >"$run_dir/manifest.env"

  trap '_logs:cleanup' INT TERM EXIT

  for spec in "${SERVICES[@]}"; do
    _logs:parse_service "$spec" tag cmd || {
      echo:Logs "${cl_red}skipping invalid --service: $spec${cl_reset}"
      continue
    }
    if [[ ! "$tag" =~ ^[A-Za-z0-9._-]+$ ]]; then
      echo:Logs "${cl_red}skipping bad tag (allowed: A-Z a-z 0-9 . _ -): $tag${cl_reset}"
      continue
    fi
    printf '%s=%q\n' "$tag" "$cmd" >>"$run_dir/manifest.env"
    echo:Logs "registered ${cl_cyan}$tag${cl_reset} -> $cmd"
    _logs:worker "$tag" "$run_dir" "$all" "$cmd"
  done

  _logs:update_latest "$run_dir"
  echo:Logs "capturing into ${cl_yellow}$run_dir${cl_reset} (Ctrl-C to stop)"

  case "$VIEW" in
  separated) _logs:view_separated "$run_dir" ;;
  none) wait ;;
  *) tail -n +1 -F "$all" 2>/dev/null | _logs:colorize ;;
  esac
}

# Parse capture arguments, merge config, then run the supervisor.
function logs:capture:main() {
  SERVICES=()
  local config_file=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -s | --service)
      _logs:need "$#" "$1"
      SERVICES+=("$2")
      shift 2
      ;;
    -c | --config)
      _logs:need "$#" "$1"
      config_file="$2"
      shift 2
      ;;
    -o | --out)
      _logs:need "$#" "$1"
      LOGS_BASE_DIR="$2"
      shift 2
      ;;
    --joined)
      VIEW="joined"
      shift
      ;;
    --separated)
      VIEW="separated"
      shift
      ;;
    --no-view)
      VIEW="none"
      shift
      ;;
    --timestamps)
      LOGS_TIMESTAMPS=1
      shift
      ;;
    --highlight)
      _logs:need "$#" "$1"
      LOGS_HIGHLIGHT="$2"
      shift 2
      ;;
    -h | --help)
      logs:capture:usage
      return 0
      ;;
    --)
      shift
      break
      ;;
    -*) _logs:die "$EXIT_INVALID_ARGS" "unknown capture flag: $1" ;;
    *)
      SERVICES+=("$1")
      shift
      ;;
    esac
  done

  _logs:load_config "$config_file"

  [[ ${#SERVICES[@]} -eq 0 ]] && {
    logs:capture:usage
    _logs:die "$EXIT_INVALID_ARGS" "no services registered (use --service \"tag=command\")"
  }
  [[ -z "$__LOGS_HAS_JQ" ]] && echo:Logs "${cl_yellow}jq not found; JSON lines won't be formatted${cl_reset}"

  logs:capture
}

# ============================================================================
# Search
# ============================================================================

# Emit "<visible>\t<raw>" lines for fzf (visible = scannable, raw = previewed).
function logs:search:feed() {
  local src="$1" tag_filter="$2" line tag rest rendered
  while IFS= read -r line; do
    if [[ -n "$tag_filter" ]]; then
      tag="$tag_filter"
      rest="$line"
    elif [[ "$line" == *" "* ]]; then
      tag="${line%% *}"
      rest="${line#* }"
    else
      tag="$line"
      rest=""
    fi
    if _logs:is_json "$rest"; then
      rendered="$(printf '%s' "$rest" | jq -c . 2>/dev/null)"
    else
      rendered="$rest"
    fi
    printf '%s\t%s\n' "$tag${rendered:+ }$rendered" "$line"
  done <"$src"
}

# Pretty-print one selected raw line for the fzf preview pane.
function logs:search:preview() {
  local raw="$*" rest
  local -a jqc=(-C)
  _logs:no_color && jqc=()
  if _logs:is_json "$raw"; then
    printf '%s' "$raw" | jq "${jqc[@]}" .
    return
  fi
  rest="${raw#* }"
  if [[ "$raw" == *" "* ]] && _logs:is_json "$rest"; then
    printf '%s' "$rest" | jq "${jqc[@]}" .
  else
    _logs:highlight "$raw"
    printf '\n'
  fi
}

function logs:search:main() {
  local run="" base="" tag="" query="" src
  while [[ $# -gt 0 ]]; do
    case "$1" in
    __preview)
      shift
      logs:search:preview "$@"
      return $?
      ;;
    --run)
      _logs:need "$#" "$1"
      run="$2"
      shift 2
      ;;
    --base)
      _logs:need "$#" "$1"
      base="$2"
      shift 2
      ;;
    --tag)
      _logs:need "$#" "$1"
      tag="$2"
      shift 2
      ;;
    -g | --grep)
      _logs:need "$#" "$1"
      query="$2"
      shift 2
      ;;
    -h | --help)
      logs:search:usage
      return 0
      ;;
    *) _logs:die "$EXIT_INVALID_ARGS" "unknown search argument: $1" ;;
    esac
  done

  [[ -z "$base" ]] && base="$(_logs:base_dir)"
  [[ -z "$run" ]] && run="$(logs:latest_run "$base")"
  [[ -z "$run" || ! -d "$run" ]] && _logs:die "$EXIT_ERROR" "no run found under $base (capture some logs first)"
  src="$run/all.log"
  [[ -n "$tag" ]] && src="$run/$(_logs:slug "$tag").log"
  [[ -r "$src" ]] || _logs:die "$EXIT_ERROR" "not readable: $src"

  dependency fzf "*" "brew install fzf  # or: apt-get install fzf" || _logs:die "$EXIT_MISSING_DEP" "fzf is required for search"

  echo:Logs "searching ${cl_yellow}$src${cl_reset}"
  logs:search:feed "$src" "$tag" |
    fzf --ansi --delimiter=$'\t' --with-nth=1 --no-sort --layout=reverse --height=90% \
      ${query:+--query="$query"} \
      --preview "'$SCRIPT_PATH' search __preview {2}" \
      --preview-window='right,60%,wrap' \
      --header 'Enter: print | Ctrl-/: toggle preview | Esc: quit'
}

# ============================================================================
# Usage
# ============================================================================

function logs:usage() {
  cat <<EOF
${cl_yellow}logs.sh${cl_reset} - capture and search logs from multiple services.

${cl_yellow}Usage:${cl_reset}
  logs.sh capture --service "tag=command" [--service ...] [options]
  logs.sh search  [--run DIR] [--tag TAG] [--grep TEXT]
  logs.sh --help | --version

Run a subcommand with --help for its options:
  logs.sh capture --help
  logs.sh search  --help
EOF
}

function logs:capture:usage() {
  cat <<EOF
${cl_yellow}logs.sh capture${cl_reset} - run services in parallel and tail their logs.

${cl_yellow}Usage:${cl_reset}
  logs.sh capture --service "api=node server.js" --service "db=docker logs -f db"

${cl_yellow}Options:${cl_reset}
  -s, --service "tag=cmd"  Register a service (repeatable). 'tag' is [A-Za-z0-9._-].
  -c, --config FILE        Load services from FILE (one 'tag=command' per line).
                           Without --config, the nearest ${LOGS_CONFIG_NAME} up to the
                           git root is used if present. CLI services win on conflict.
  -o, --out DIR            Base directory for runs (default: ./.logs).
      --joined             Interleaved colored stream (default).
      --separated          One tmux pane per service (falls back to file hints).
      --no-view            Capture to files only; no live terminal output.
      --timestamps         Prepend a UTC timestamp to every captured line.
      --highlight PAIRS    Keyword colors, e.g. "ERROR:lred,WARN:yellow".
  -h, --help               Show this help.

${cl_yellow}Output (under ./.logs/<UTC-timestamp>/):${cl_reset}
  <tag>.log    raw per-service stream     all.log   consolidated, tag-prefixed
  manifest.env tag=command map            latest -> newest run (symlink)

Stop with Ctrl-C. One service dying leaves the others running.
EOF
}

function logs:search:usage() {
  cat <<EOF
${cl_yellow}logs.sh search${cl_reset} - fuzzy-search a recorded run with fzf.

${cl_yellow}Usage:${cl_reset}
  logs.sh search [--run DIR] [--base DIR] [--tag TAG] [--grep TEXT]

${cl_yellow}Options:${cl_reset}
  --run DIR     Search this run (default: newest under the base directory).
  --base DIR    Base directory holding runs (default: ./.logs).
  --tag TAG     Search a single service's file instead of the consolidated one.
  -g, --grep T  Seed the fzf query with T.
  -h, --help    Show this help.

Inside fzf: Enter prints the line, the preview pane shows pretty JSON when the
focused line is JSON. Requires fzf and (for JSON) jq.
EOF
}

# ============================================================================
# Entry point (ShellSpec stops here via __SOURCED__)
# ============================================================================
${__SOURCED__:+return}

logger:init logs "${cl_grey}[logs]${cl_reset} " ">&2"

subcmd="${1:-}"
shift 2>/dev/null || true
case "$subcmd" in
capture) logs:capture:main "$@" ;;
search) logs:search:main "$@" ;;
__tailview) logs:view:tail "$@" ;;
-h | --help | help | "") logs:usage ;;
-v | --version) echo "$SCRIPT_VERSION" ;;
*)
  echo "${cl_red}unknown subcommand: $subcmd${cl_reset}" >&2
  logs:usage
  exit "$EXIT_INVALID_ARGS"
  ;;
esac
