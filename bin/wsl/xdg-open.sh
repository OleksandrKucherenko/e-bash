#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-02-17
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# WSL xdg-open shim: in WSL environments, routes open calls to the Windows host
# via PowerShell/cmd.exe; in non-WSL environments falls back to the real xdg-open.
#
# Usage:
#   xdg-open.sh <url-or-path>
#
# Environment:
#   DEBUG         - comma-separated logger tags to enable (e.g. DEBUG=wsl,xdg)
#   DRY_RUN       - "true" to print commands without executing (default: false)
#   ORIG_XDG_OPEN - override path to the real xdg-open (default: /usr/bin/xdg-open)

# Disable wsl/xdg loggers by default; users opt-in via DEBUG=wsl or DEBUG=xdg
DEBUG="${DEBUG:-"-wsl,-xdg"}"
DRY_RUN="${DRY_RUN:-false}"

# Bootstrap: 1) E_BASH discovery (only if not set), 2) gnubin setup (always)
# Note: this script lives at bin/wsl/, so .scripts/ is two levels up (../../.scripts)
[ "$E_BASH" ] || { _src=${BASH_SOURCE:-$0}; E_BASH=$(cd "${_src%/*}/../../.scripts" 2>&- && pwd || echo ~/.e-bash/.scripts); readonly E_BASH; }
. "$E_BASH/_gnu.sh"; PATH="$(cd "$E_BASH/../bin/gnubin" 2>&- && pwd):$PATH"

# shellcheck source=../../.scripts/_colors.sh
source "$E_BASH/_colors.sh"
# shellcheck source=../../.scripts/_logger.sh
source "$E_BASH/_logger.sh"

# Initialize loggers.
# Note: $@ is intentionally NOT forwarded here - xdg-open args are URLs/paths,
# not script control flags like --debug. Use DEBUG=wsl or DEBUG=xdg env vars.
logger wsl && logger:prefix wsl "[${cl_gray}wsl${cl_reset}]  " && logger:redirect wsl ">&2"
logger xdg && logger:prefix xdg "[${cl_cyan}xdg${cl_reset}]  " && logger:redirect xdg ">&2"

readonly ORIG_XDG_OPEN="${ORIG_XDG_OPEN:-/usr/bin/xdg-open}"

##
## Detect if running inside a WSL environment (WSL1 or WSL2).
## Checks environment variables first (fast path) then /proc/version (slow path).
##
## Returns:
## - 0 (true)  if running in WSL
## - 1 (false) otherwise
##
function wsl:is_wsl() {
  # WSL_DISTRO_NAME is set in both WSL1 and WSL2
  [[ -n "${WSL_DISTRO_NAME-}" ]] && return 0
  # WSL_INTEROP is the WSL2 socket; present only under WSL2
  [[ -n "${WSL_INTEROP-}" ]] && return 0
  # Fallback: the Microsoft kernel announces itself in /proc/version
  grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null && return 0
  return 1
}

##
## Test whether a string carries a URI scheme (i.e. looks like a URL).
##
## Parameters:
## - $1 - candidate string
##
## Returns:
## - 0 (true)  when $1 matches <scheme>://
## - 1 (false) otherwise
##
function xdg:is_url() {
  [[ "$1" =~ ^[a-zA-Z][a-zA-Z0-9+.-]*:// ]]
}

##
## Translate a Linux path (or file:// URL) to its Windows equivalent using wslpath.
## Non-file:// URLs are returned unchanged so browsers receive them as-is.
##
## Parameters:
## - $1 - Linux filesystem path, file:// URL, or any other URL
##
## Outputs:
## - Windows-compatible path or original URL to stdout
##
function xdg:to_win_path() {
  local target="$1"

  # Non-file:// URLs (http, https, mailto, …) need no translation
  if xdg:is_url "$target" && [[ "$target" != file://* ]]; then
    echo:Xdg "url passthrough: ${target}"
    printf '%s' "$target"
    return 0
  fi

  # Unwrap file:// so we are left with a plain filesystem path
  if [[ "$target" == file://* ]]; then
    target="${target#file://}"
    echo:Xdg "stripped file:// prefix -> ${target}"
  fi

  # wslpath does the heavy lifting when it is available
  if command -v wslpath >/dev/null 2>&1; then
    local abs_path="" win_path=""

    if [[ "$target" == /* ]] && [[ -e "$target" ]]; then
      abs_path="$target"
    elif [[ -e "$target" ]]; then
      abs_path=$(realpath "$target" 2>/dev/null) || abs_path="$target"
    fi

    if [[ -n "$abs_path" ]]; then
      win_path=$(wslpath -w "$abs_path" 2>/dev/null)
      if [[ -n "$win_path" ]]; then
        echo:Xdg "wslpath: ${abs_path} -> ${win_path}"
        printf '%s' "$win_path"
        return 0
      fi
      echo:Wsl "wslpath returned empty for: ${abs_path}"
    else
      echo:Wsl "path does not exist locally: ${target}"
    fi
  else
    echo:Wsl "wslpath not available - skipping path translation"
  fi

  # Return target unchanged; Windows may still handle a Linux-style path
  echo:Wsl "returning target as-is: ${target}"
  printf '%s' "$target"
}

##
## Open a URL or file with the Windows default application.
## Tries PowerShell first (more capable) then falls back to cmd.exe start.
##
## Parameters:
## - $1 - Windows path or URL to open
##
## Returns:
## - 0 on success
## - 1 when neither launcher is available or both fail
##
function xdg:open_in_windows() {
  # Strip embedded double-quotes to prevent command injection
  local win_target="${1//\"/}"

  echo:Xdg "opening in windows: ${win_target}"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY RUN] Start-Process \"${win_target}\"" >&2
    return 0
  fi

  # PowerShell is preferred: handles UNC paths, spaces, and all URL schemes
  if command -v powershell.exe >/dev/null 2>&1; then
    echo:Wsl "launcher: powershell.exe"
    powershell.exe -NoProfile -NonInteractive -Command "Start-Process \"${win_target}\"" \
      >/dev/null 2>&1 && return 0
    echo:Wsl "powershell.exe failed, trying cmd.exe"
  fi

  # cmd.exe start is the universal fallback on older/minimal Windows setups
  if command -v cmd.exe >/dev/null 2>&1; then
    echo:Wsl "launcher: cmd.exe"
    cmd.exe /c start "" "${win_target}" >/dev/null 2>&1 && return 0
    echo:Wsl "cmd.exe also failed"
  fi

  echo "${cl_red}error:${cl_reset} no Windows launcher found (powershell.exe / cmd.exe); cannot open: ${win_target}" >&2
  return 1
}

##
## Entry point
##
function main() {
  if [[ $# -lt 1 ]]; then
    echo "Usage: xdg-open <url-or-path>" >&2
    exit 1
  fi

  local target="$1"
  echo:Wsl "target: ${target}"

  if wsl:is_wsl; then
    local distro="${WSL_DISTRO_NAME:-unknown}"
    echo:Wsl "WSL detected (distro: ${distro})"

    local win_target
    win_target=$(xdg:to_win_path "$target")
    echo:Wsl "resolved: ${win_target}"

    xdg:open_in_windows "$win_target"
    exit $?
  fi

  # Non-WSL: hand off to the real xdg-open
  echo:Xdg "non-WSL environment, delegating to: ${ORIG_XDG_OPEN}"
  if [[ -x "$ORIG_XDG_OPEN" ]]; then
    exec "$ORIG_XDG_OPEN" "$@"
  fi

  echo "${cl_red}error:${cl_reset} real xdg-open not found at ${ORIG_XDG_OPEN}" >&2
  exit 1
}

main "$@"
