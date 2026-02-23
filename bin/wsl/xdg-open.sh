#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-02-18
## Version: 2.7.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# WSL xdg-open shim with first-run TUI configuration.
# In WSL environments, routes open calls to the Windows host via
# PowerShell/pwsh/cmd.exe; in non-WSL environments falls back to real xdg-open.
#
# Usage:
#   xdg-open.sh <url-or-path>       # Open URL/file (runs wizard on first use)
#   xdg-open.sh --config            # Re-run configuration wizard
#   xdg-open.sh --status            # Show current configuration
#   xdg-open.sh --uninstall         # Remove config and generated shim
#   xdg-open.sh --help              # Show usage information
#   xdg-open.sh --version           # Show version
#
# Environment:
#   DEBUG         - comma-separated logger tags to enable (e.g. DEBUG=wsl,xdg)
#   DRY_RUN       - "true" to print commands without executing (default: false)
#   ORIG_XDG_OPEN - override path to the real xdg-open (default: /usr/bin/xdg-open)
#   XDG_WSL_USERS - Windows Users directory (default: /mnt/c/Users)
#   XDG_WSL_WIN   - Windows Program Files directory (default: /mnt/c/Program Files)
#   XDG_WSL_WIN86 - Windows Program Files (x86) directory (default: /mnt/c/Program Files (x86))

# Version info
readonly VERSION="1.1.0"

# Configurable Windows paths (for advanced users)
readonly XDG_WSL_USERS="${XDG_WSL_USERS:-/mnt/c/Users}"
readonly XDG_WSL_WIN="${XDG_WSL_WIN:-/mnt/c/Program Files}"
readonly XDG_WSL_WIN86="${XDG_WSL_WIN86:-/mnt/c/Program Files (x86)}"

# Disable wsl/xdg loggers by default; users opt-in via DEBUG=wsl or DEBUG=xdg
DEBUG="${DEBUG:-"-wsl,-xdg"}"
DRY_RUN="${DRY_RUN:-false}"

# Bootstrap: 1) E_BASH discovery (only if not set), 2) gnubin setup (always)
# Note: this script lives at bin/wsl/, so .scripts/ is two levels up (../../.scripts)
[ "$E_BASH" ] || {
  _src=${BASH_SOURCE:-$0}
  E_BASH=$(cd "${_src%/*}/../../.scripts" 2>&- && pwd || echo ~/.e-bash/.scripts)
  readonly E_BASH
}
# shellcheck source=../../.scripts/_gnu.sh
source "$E_BASH/_gnu.sh"
PATH="$(cd "$E_BASH/../bin/gnubin" 2>&- && pwd):$PATH"

# shellcheck source=../../.scripts/_colors.sh
source "$E_BASH/_colors.sh"
# shellcheck source=../../.scripts/_logger.sh
source "$E_BASH/_logger.sh"
# shellcheck source=../../.scripts/_commons.sh
source "$E_BASH/_commons.sh"

# Initialize loggers.
# Note: $@ is intentionally NOT forwarded here - xdg-open args are URLs/paths,
# not script control flags like --debug. Use DEBUG=wsl or DEBUG=xdg env vars.
logger:init wsl "[${cl_gray}wsl${cl_reset}]  " ">&2"
logger:init xdg "[${cl_cyan}xdg${cl_reset}]  " ">&2"

readonly ORIG_XDG_OPEN="${ORIG_XDG_OPEN:-/usr/bin/xdg-open}"

# Configuration paths
readonly CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/xdg-open-wsl"
readonly CONFIG_FILE="$CONFIG_DIR/config"
readonly DEFAULT_SHIM_DIR="$HOME/.local/bin"

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
## Supports both <scheme>:// and <scheme>: formats (e.g., mailto:)
##
## Parameters:
## - $1 - candidate string
##
## Returns:
## - 0 (true)  when $1 matches <scheme>:// or <scheme>:
## - 1 (false) otherwise
##
function xdg:is_url() {
  [[ "$1" =~ ^[a-zA-Z][a-zA-Z0-9+.-]*:(//)? ]]
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

  # Non-file URLs (http, https, mailto, tel, etc.) need no translation
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
## Detect available Windows launchers (powershell, pwsh, cmd).
## Checks system PATH, Scoop, and Winget installation locations.
##
## Outputs:
## - List of available launcher names, one per line
##
function xdg:detect:launcher() {
  local launchers=()

  # System PATH
  command -v powershell.exe &>/dev/null && launchers+=("powershell")
  command -v pwsh.exe &>/dev/null && launchers+=("pwsh")
  command -v cmd.exe &>/dev/null && launchers+=("cmd")

  # Scoop installations (using Windows user's scoop directory)
  local scoop_dir
  scoop_dir=$(xdg:windows:scoop_dir)
  if [[ -n "$scoop_dir" ]]; then
    [[ -f "$scoop_dir/shims/pwsh.exe" ]] && launchers+=("pwsh-scoop")
    [[ -f "$scoop_dir/shims/powershell.exe" ]] && launchers+=("powershell-scoop")
  fi

  # Winget/Microsoft Store PowerShell 7 installations
  local pwsh_winget="$XDG_WSL_WIN/PowerShell/7/pwsh.exe"
  [[ -f "$pwsh_winget" ]] && launchers+=("pwsh-winget")

  printf '%s\n' "${launchers[@]}"
}

##
## Get the executable name for a launcher selection.
##
## Parameters:
## - $1 - launcher selection (e.g., "powershell", "pwsh-scoop")
##
## Outputs:
## - Executable name (e.g., "powershell.exe", "pwsh.exe")
##
function xdg:launcher:exe() {
  local selection="$1"
  case "$selection" in
  "powershell" | "powershell-scoop") echo "powershell.exe" ;;
  "pwsh" | "pwsh-scoop" | "pwsh-winget" | "pwsh (scoop)" | "pwsh (winget)") echo "pwsh.exe" ;;
  "cmd") echo "cmd.exe" ;;
  *) echo "powershell.exe" ;; # Default fallback
  esac
}

##
## Get the full resolved path for a launcher selection.
## Returns the actual executable path, not just the basename.
##
## Parameters:
## - $1 - launcher selection (e.g., "powershell", "pwsh-winget")
##
## Outputs:
## - Full path to launcher executable
##
function xdg:launcher:path() {
  local selection="$1"
  local launcher_exe
  launcher_exe=$(xdg:launcher:exe "$selection")

  # Get Windows user's Scoop directory
  local scoop_dir
  scoop_dir=$(xdg:windows:scoop_dir)

  case "$selection" in
  "pwsh-winget" | "pwsh (winget)")
    echo "$XDG_WSL_WIN/PowerShell/7/pwsh.exe"
    ;;
  "pwsh-scoop" | "pwsh (scoop)")
    if [[ -n "$scoop_dir" ]]; then
      echo "$scoop_dir/shims/pwsh.exe"
    else
      echo "$launcher_exe"
    fi
    ;;
  "powershell-scoop")
    if [[ -n "$scoop_dir" ]]; then
      echo "$scoop_dir/shims/powershell.exe"
    else
      echo "$launcher_exe"
    fi
    ;;
  *)
    # For system launchers, just use the exe name (in PATH)
    echo "$launcher_exe"
    ;;
  esac
}

##
## Verify a launcher is available at its expected path.
##
## Parameters:
## - $1 - launcher selection (e.g., "powershell", "pwsh-winget")
##
## Returns:
## - 0 (true) if launcher is available
## - 1 (false) otherwise
##
function xdg:launcher:verify() {
  local selection="$1"
  local launcher_path
  launcher_path=$(xdg:launcher:path "$selection")

  # For system PATH executables
  if [[ "$launcher_path" != /* ]]; then
    command -v "$launcher_path" &>/dev/null
    return $?
  fi

  # For full paths
  [[ -x "$launcher_path" ]]
}

##
## Detect Windows user accounts from /mnt/c/Users/
## Filters out system accounts: All Users, Default, Default User, Public
##
## Outputs:
## - List of real Windows usernames, one per line
##
function xdg:windows:users() {
  local users_dir="$XDG_WSL_USERS"
  local skip_users=("All Users" "Default" "Default User" "Public" "desktop.ini")

  if [[ ! -d "$users_dir" ]]; then
    return 1
  fi

  for entry in "$users_dir"/*; do
    local name="${entry##*/}"
    local is_skip=false

    # Check if this is a system account to skip
    for skip in "${skip_users[@]}"; do
      [[ "$name" == "$skip" ]] && is_skip=true && break
    done

    # Only include real user directories
    if ! $is_skip && [[ -d "$entry" ]]; then
      echo "$name"
    fi
  done
}

##
## Get the Windows user's Scoop directory.
## Uses XDG_OPEN_WINDOWS_USER if set, otherwise auto-detects.
##
## Outputs:
## - Path to Windows user's scoop directory (e.g., /mnt/c/Users/username/scoop)
##
function xdg:windows:scoop_dir() {
  local win_user="${XDG_OPEN_WINDOWS_USER:-}"

  # If no user set, try to auto-detect
  if [[ -z "$win_user" ]]; then
    local users
    users=$(xdg:windows:users)
    local user_count
    user_count=$(echo "$users" | grep -c .)

    if [[ $user_count -eq 1 ]]; then
      # Only one user, use it
      win_user=$(echo "$users" | head -1)
    elif [[ $user_count -gt 1 ]]; then
      # Multiple users - check if one matches the Linux username
      local linux_user="${USER:-$(whoami 2>/dev/null)}"
      if echo "$users" | grep -qx "$linux_user"; then
        win_user="$linux_user"
      fi
    fi
  fi

  if [[ -n "$win_user" ]]; then
    echo "$XDG_WSL_USERS/$win_user/scoop"
  fi
}

##
## Get the Windows user's LocalAppData directory.
## Used for per-user browser installations (Chrome, Edge, etc.).
##
## Outputs:
## - Path to Windows user's AppData/Local directory (e.g., /mnt/c/Users/username/AppData/Local)
##
function xdg:windows:local_appdata() {
  local win_user="${XDG_OPEN_WINDOWS_USER:-}"

  # If no user set, try to auto-detect
  if [[ -z "$win_user" ]]; then
    local users
    users=$(xdg:windows:users)
    local user_count
    user_count=$(echo "$users" | grep -c .)

    if [[ $user_count -eq 1 ]]; then
      win_user=$(echo "$users" | head -1)
    elif [[ $user_count -gt 1 ]]; then
      local linux_user="${USER:-$(whoami 2>/dev/null)}"
      if echo "$users" | grep -qx "$linux_user"; then
        win_user="$linux_user"
      fi
    fi
  fi

  if [[ -n "$win_user" ]]; then
    echo "$XDG_WSL_USERS/$win_user/AppData/Local"
  fi
}

##
## Get the Windows path for a browser selection.
## Returns the executable path for launching the browser.
##
## Parameters:
## - $1 - browser selection (e.g., "default", "chrome", "custom")
## - $2 - custom path (optional, for "custom" selection)
##
## Outputs:
## - Browser executable path or empty for default browser
##
function xdg:browser:path() {
  local selection="$1"
  local custom_path="${2:-}"

  # Get Windows user's Scoop and LocalAppData directories
  local scoop_dir local_appdata
  scoop_dir=$(xdg:windows:scoop_dir)
  local_appdata=$(xdg:windows:local_appdata)

  case "$selection" in
    "default") echo "" ;;  # Use Windows default
    "chrome"*)
      # Chrome - system, user, Scoop installations (stable only)
      # TODO: Add Chocolatey support
      local chrome_paths=(
        "$XDG_WSL_WIN/Google/Chrome/Application/chrome.exe"
        "$XDG_WSL_WIN86/Google/Chrome/Application/chrome.exe"
      )
      # Add user-specific AppData\Local path (common for user installs)
      [[ -n "$local_appdata" ]] && chrome_paths+=("$local_appdata/Google/Chrome/Application/chrome.exe")
      # Add Scoop path if available
      [[ -n "$scoop_dir" ]] && chrome_paths+=("$scoop_dir/apps/googlechrome/current/Google Chrome.exe")
      for path in "${chrome_paths[@]}"; do
        [[ -f "$path" ]] && echo "$path" && return 0
      done
      echo "chrome.exe"  # Fallback to PATH
      ;;
    "firefox"*)
      # Firefox - system, user, Scoop installations (stable only)
      # TODO: Add Chocolatey support
      local firefox_paths=(
        "$XDG_WSL_WIN/Mozilla Firefox/firefox.exe"
        "$XDG_WSL_WIN86/Mozilla Firefox/firefox.exe"
      )
      # Add user-specific AppData\Local path
      [[ -n "$local_appdata" ]] && firefox_paths+=("$local_appdata/Mozilla Firefox/firefox.exe")
      [[ -n "$scoop_dir" ]] && firefox_paths+=("$scoop_dir/apps/firefox/current/firefox.exe")
      for path in "${firefox_paths[@]}"; do
        [[ -f "$path" ]] && echo "$path" && return 0
      done
      echo "firefox.exe"
      ;;
    "edge"*)
      # Edge - system, user, Scoop installations (stable only)
      # TODO: Add Chocolatey support
      local edge_paths=(
        "$XDG_WSL_WIN86/Microsoft/Edge/Application/msedge.exe"
        "$XDG_WSL_WIN/Microsoft/Edge/Application/msedge.exe"
      )
      # Add user-specific AppData\Local path
      [[ -n "$local_appdata" ]] && edge_paths+=("$local_appdata/Microsoft/Edge/Application/msedge.exe")
      [[ -n "$scoop_dir" ]] && edge_paths+=("$scoop_dir/apps/edge/current/msedge.exe")
      for path in "${edge_paths[@]}"; do
        [[ -f "$path" ]] && echo "$path" && return 0
      done
      echo "msedge.exe"
      ;;
    "brave"*)
      # Brave - system, user, Scoop installations (stable only)
      # TODO: Add Chocolatey support
      local brave_paths=(
        "$XDG_WSL_WIN/BraveSoftware/Brave-Browser/Application/brave.exe"
        "$XDG_WSL_WIN86/BraveSoftware/Brave-Browser/Application/brave.exe"
      )
      # Add user-specific AppData\Local path
      [[ -n "$local_appdata" ]] && brave_paths+=("$local_appdata/BraveSoftware/Brave-Browser/Application/brave.exe")
      [[ -n "$scoop_dir" ]] && brave_paths+=("$scoop_dir/apps/brave/current/Application/brave.exe")
      for path in "${brave_paths[@]}"; do
        [[ -f "$path" ]] && echo "$path" && return 0
      done
      echo "brave.exe"
      ;;
    "custom")
      echo "$custom_path"
      ;;
    *)
      echo ""  # Default browser
      ;;
  esac
}

##
## Detect available browsers on Windows host.
## Checks common installation locations including Scoop paths.
## Supported browsers (stable only): Chrome, Firefox, Edge, Brave
## For other browsers, use "custom" path option.
##
## TODO: Add Chocolatey package manager support
##
## Outputs:
## - List of available browser names, one per line
##
function xdg:browser:detect() {
  local browsers=()

  # Default browser is always available
  browsers+=("default")

  # Get Windows user's Scoop and LocalAppData directories
  local scoop_dir local_appdata
  scoop_dir=$(xdg:windows:scoop_dir)
  local_appdata=$(xdg:windows:local_appdata)

  # Chrome - system, user, Scoop paths (stable only)
  local chrome_found=false
  [[ -f "$XDG_WSL_WIN/Google/Chrome/Application/chrome.exe" ]] && chrome_found=true
  [[ -f "$XDG_WSL_WIN86/Google/Chrome/Application/chrome.exe" ]] && chrome_found=true
  [[ -n "$local_appdata" && -f "$local_appdata/Google/Chrome/Application/chrome.exe" ]] && chrome_found=true
  [[ -n "$scoop_dir" && -f "$scoop_dir/apps/googlechrome/current/Google Chrome.exe" ]] && chrome_found=true
  command -v chrome.exe &>/dev/null && chrome_found=true
  $chrome_found && browsers+=("chrome")

  # Firefox (stable only)
  local firefox_found=false
  [[ -f "$XDG_WSL_WIN/Mozilla Firefox/firefox.exe" ]] && firefox_found=true
  [[ -f "$XDG_WSL_WIN86/Mozilla Firefox/firefox.exe" ]] && firefox_found=true
  [[ -n "$local_appdata" && -f "$local_appdata/Mozilla Firefox/firefox.exe" ]] && firefox_found=true
  [[ -n "$scoop_dir" && -f "$scoop_dir/apps/firefox/current/firefox.exe" ]] && firefox_found=true
  command -v firefox.exe &>/dev/null && firefox_found=true
  $firefox_found && browsers+=("firefox")

  # Edge - system, user, Scoop paths (stable only)
  local edge_found=false
  [[ -f "$XDG_WSL_WIN86/Microsoft/Edge/Application/msedge.exe" ]] && edge_found=true
  [[ -f "$XDG_WSL_WIN/Microsoft/Edge/Application/msedge.exe" ]] && edge_found=true
  [[ -n "$local_appdata" && -f "$local_appdata/Microsoft/Edge/Application/msedge.exe" ]] && edge_found=true
  [[ -n "$scoop_dir" && -f "$scoop_dir/apps/edge/current/msedge.exe" ]] && edge_found=true
  command -v msedge.exe &>/dev/null && edge_found=true
  $edge_found && browsers+=("edge")

  # Brave (stable only)
  local brave_found=false
  [[ -f "$XDG_WSL_WIN/BraveSoftware/Brave-Browser/Application/brave.exe" ]] && brave_found=true
  [[ -f "$XDG_WSL_WIN86/BraveSoftware/Brave-Browser/Application/brave.exe" ]] && brave_found=true
  [[ -n "$local_appdata" && -f "$local_appdata/BraveSoftware/Brave-Browser/Application/brave.exe" ]] && brave_found=true
  [[ -n "$scoop_dir" && -f "$scoop_dir/apps/brave/current/Application/brave.exe" ]] && brave_found=true
  command -v brave.exe &>/dev/null && brave_found=true
  $brave_found && browsers+=("brave")

  # Custom is always an option (for Vivaldi, Opera, and other browsers)
  browsers+=("custom")

  printf '%s\n' "${browsers[@]}"
}

##
## Check if configuration exists and shim is installed.
##
## Returns:
## - 0 (true)  if config file and shim exist
## - 1 (false) otherwise
##
function xdg:is_configured() {
  [[ -f "$CONFIG_FILE" ]]
}

##
## Check if this is a first run (no config file exists).
##
## Returns:
## - 0 (true)  if first run (no config)
## - 1 (false) if already configured
##
function xdg:is_first_run() {
  [[ ! -f "$CONFIG_FILE" ]]
}

##
## Read configuration file into environment variables.
##
function xdg:config:read() {
  if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
  fi
}

##
## Write configuration file with current settings.
##
## Parameters:
## - XDG_OPEN_LAUNCHER - launcher to use (powershell, pwsh, cmd)
## - XDG_OPEN_BROWSER - browser preference (default, chrome, firefox, edge, brave)
## - XDG_OPEN_SHIM_DIR - installation directory for shim
##
function xdg:config:write() {
  local launcher="${XDG_OPEN_LAUNCHER:-powershell}"
  local browser="${XDG_OPEN_BROWSER:-default}"
  local browser_path="${XDG_OPEN_BROWSER_PATH:-}"
  local windows_user="${XDG_OPEN_WINDOWS_USER:-}"
  local shim_dir="${XDG_OPEN_SHIM_DIR:-$DEFAULT_SHIM_DIR}"
  local verbose="${XDG_OPEN_VERBOSE:-false}"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S")

  mkdir -p "$CONFIG_DIR"

  cat >"$CONFIG_FILE" <<EOF
# xdg-open-wsl configuration
# Generated: $timestamp
# Version: $VERSION

XDG_OPEN_LAUNCHER="$launcher"
XDG_OPEN_BROWSER="$browser"
XDG_OPEN_BROWSER_PATH="$browser_path"
XDG_OPEN_WINDOWS_USER="$windows_user"
XDG_OPEN_SHIM_DIR="$shim_dir"
XDG_OPEN_VERBOSE="$verbose"
XDG_OPEN_INSTALLED_AT="$timestamp"
XDG_OPEN_VERSION="$VERSION"
EOF

  echo:Xdg "config written to: $CONFIG_FILE"
}

##
## Generate the lightweight shim script.
##
## Parameters:
## - $1 - output file path for the shim
##
function xdg:shim:generate() {
  local shim_file="$1"
  local launcher_exe
  launcher_exe=$(xdg:launcher:exe "$XDG_OPEN_LAUNCHER")

  # Get the actual path for pwsh (winget/scoop installations)
  local launcher_path="$launcher_exe"
  if [[ "$XDG_OPEN_LAUNCHER" == "pwsh-winget" ]]; then
    launcher_path="$XDG_WSL_WIN/PowerShell/7/pwsh.exe"
  fi

  mkdir -p "$(dirname "$shim_file")"

  cat >"$shim_file" <<'HEADER'
#!/usr/bin/env bash
# xdg-open shim for WSL - Auto-generated by xdg-open-wsl
# Do not edit manually - run 'xdg-open --config' to reconfigure

set -e

HEADER

  # Add version/launcher info comment
  echo "# Version: $VERSION | Launcher: $XDG_OPEN_LAUNCHER | Browser: $XDG_OPEN_BROWSER" >>"$shim_file"
  echo "" >>"$shim_file"

  cat >>"$shim_file" <<'BODY'
readonly _LAUNCHER_EXE="LAUNCHER_PATH_PLACEHOLDER"
readonly _LAUNCHER_CMD="LAUNCHER_CMD_PLACEHOLDER"

# WSL detection (inlined for speed)
_is_wsl() {
  [[ -n "${WSL_DISTRO_NAME:-}" ]] || [[ -n "${WSL_INTEROP:-}" ]] || \
    grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null
}

# Fallback to real xdg-open if not in WSL
if ! _is_wsl; then
  if [[ -x "/usr/bin/xdg-open" ]]; then
    exec /usr/bin/xdg-open "$@"
  fi
  echo "error: not in WSL and /usr/bin/xdg-open not found" >&2
  exit 1
fi

target="$1"

# URL passthrough for non-file URLs
_is_url() {
  [[ "$1" =~ ^[a-zA-Z][a-zA-Z0-9+.-]*:// ]]
}

if _is_url "$target" && [[ "$target" != file://* ]]; then
  win_target="$target"
else
  # Strip file:// prefix if present
  [[ "$target" == file://* ]] && target="${target#file://}"

  # Convert to Windows path
  if command -v wslpath >/dev/null 2>&1; then
    if [[ -e "$target" ]]; then
      abs_path=$(realpath "$target" 2>/dev/null || echo "$target")
      win_target=$(wslpath -w "$abs_path" 2>/dev/null || echo "$target")
    else
      win_target="$target"
    fi
  else
    win_target="$target"
  fi
fi

# Strip embedded double-quotes to prevent command injection
win_target="${win_target//\"/}"

# Launch via configured launcher
$_LAUNCHER_EXE $_LAUNCHER_CMD >/dev/null 2>&1
BODY

  # Replace placeholders
  sed -i "s|LAUNCHER_PATH_PLACEHOLDER|$launcher_path|g" "$shim_file"
  sed -i "s|LAUNCHER_CMD_PLACEHOLDER|-NoProfile -NonInteractive -Command \"Start-Process \\\"$win_target\\\"\"|g" "$shim_file" 2>/dev/null ||
    sed -i "s|LAUNCHER_CMD_PLACEHOLDER|-NoProfile -NonInteractive -Command \"Start-Process \\\\\"$win_target\\\\\"\"|g" "$shim_file"

  # For cmd.exe, use different command format
  if [[ "$XDG_OPEN_LAUNCHER" == "cmd" ]]; then
    sed -i "s|LAUNCHER_CMD_PLACEHOLDER|/c start \"\" \"$win_target\"|g" "$shim_file"
  fi

  chmod +x "$shim_file"
  echo:Xdg "shim generated at: $shim_file"
}

##
## Generate shim with proper escaping.
## Includes reference to original script for subcommand delegation.
##
function xdg:shim:generate:v2() {
  local shim_file="$1"
  local shim_dir
  shim_dir=$(dirname "$shim_file")
  mkdir -p "$shim_dir"

  # Launcher path - KEEP as Linux path (called FROM WSL)
  local launcher_path
  launcher_path=$(xdg:launcher:path "$XDG_OPEN_LAUNCHER")

  # Browser path - CONVERT to Windows path (passed TO PowerShell)
  local browser_path="${XDG_OPEN_BROWSER_PATH:-}"
  local browser_path_win=""
  if [[ -n "$browser_path" && -f "$browser_path" ]]; then
    if [[ "$browser_path" == /* ]] && command -v wslpath >/dev/null 2>&1; then
      browser_path_win=$(wslpath -w "$browser_path" 2>/dev/null || echo "$browser_path")
    else
      browser_path_win="$browser_path"
    fi
  fi

  # Get absolute path to this script (for delegation)
  local script_path
  script_path=$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || realpath "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")

  # Build the Start-Process command based on browser configuration
  local start_process_cmd
  if [[ -n "$browser_path_win" ]]; then
    start_process_cmd="Start-Process \\\"$browser_path_win\\\" -ArgumentList \\\"\$target\\\""
  else
    start_process_cmd="Start-Process \\\"\$target\\\""
  fi

  cat >"$shim_file" <<EOF
#!/usr/bin/env bash
# xdg-open shim for WSL - Auto-generated by xdg-open-wsl
# Do not edit manually - run 'xdg-open --config' to reconfigure
# Version: $VERSION | Launcher: $XDG_OPEN_LAUNCHER | Browser: $XDG_OPEN_BROWSER
# Config tool: $script_path

set -e
readonly _LAUNCHER="$launcher_path"
readonly _BROWSER="$XDG_OPEN_BROWSER"
readonly _BROWSER_PATH="$browser_path_win"
readonly _CONFIG_TOOL="$script_path"

# Delegate subcommands to the original config tool
case "\${1:-}" in
  --config|-c|--status|-s|--uninstall|--help|-h|--version|-v)
    exec "\$_CONFIG_TOOL" "\$@"
    ;;
esac

# WSL detection (inlined for speed)
[[ -n "\${WSL_DISTRO_NAME:-}" ]] || [[ -n "\${WSL_INTEROP:-}" ]] || \\
  grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null || \\
  exec /usr/bin/xdg-open "\$@"

target="\$1"

# URL passthrough (supports both scheme:// and scheme: formats like mailto:)
[[ "\$target" =~ ^[a-zA-Z][a-zA-Z0-9+.-]*:(//)? ]] || \\
  target=\$(wslpath -w "\$(realpath "\$target" 2>/dev/null || echo "\$target")" 2>/dev/null || echo "\$target")

# Strip embedded quotes for safety
target="\${target//\"/}"

# Launch via configured launcher
\$_LAUNCHER -NoProfile -NonInteractive -Command "$start_process_cmd" >/dev/null 2>&1
EOF

  chmod +x "$shim_file"
}

##
## Install the generated shim.
##
function xdg:shim:install() {
  local shim_dir="${XDG_OPEN_SHIM_DIR:-$DEFAULT_SHIM_DIR}"
  local shim_file="$shim_dir/xdg-open"

  xdg:shim:generate:v2 "$shim_file"

  echo "${cl_green}✓${cl_reset} Shim installed to: ${cl_cyan}$shim_file${cl_reset}"

  # PATH warning if needed
  if [[ ":$PATH:" != *":$shim_dir:"* ]]; then
    echo ""
    echo "${cl_yellow}⚠${cl_reset} Add ${cl_cyan}$shim_dir${cl_reset} to your PATH for the shim to take effect:"
    echo "    export PATH=\"$shim_dir:\$PATH\""
    echo ""
    echo "  Or add to your ~/.bashrc or ~/.zshrc:"
    echo "    echo 'export PATH=\"$shim_dir:\$PATH\"' >> ~/.bashrc"
  fi
}

##
## Uninstall configuration and shim.
##
function xdg:uninstall() {
  # Read config to get shim location
  xdg:config:read
  local shim_dir="${XDG_OPEN_SHIM_DIR:-$DEFAULT_SHIM_DIR}"
  local shim_file="$shim_dir/xdg-open"

  local removed=()

  if [[ -f "$shim_file" ]]; then
    rm -f "$shim_file"
    removed+=("shim: $shim_file")
  fi

  if [[ -f "$CONFIG_FILE" ]]; then
    rm -f "$CONFIG_FILE"
    removed+=("config: $CONFIG_FILE")
  fi

  if [[ -d "$CONFIG_DIR" ]]; then
    rmdir "$CONFIG_DIR" 2>/dev/null || true
  fi

  if [[ ${#removed[@]} -gt 0 ]]; then
    echo "${cl_green}✓${cl_reset} Removed:"
    for item in "${removed[@]}"; do
      echo "  - $item"
    done
  else
    echo "${cl_yellow}No configuration or shim found to remove.${cl_reset}"
  fi
}

##
## Show current configuration status.
##
function xdg:status:show() {
  echo "${cl_cyan}xdg-open-wsl Status${cl_reset}"
  echo ""

  if [[ -f "$CONFIG_FILE" ]]; then
    echo "${cl_green}Configuration:${cl_reset}"
    echo "  File: $CONFIG_FILE"
    echo ""
    cat "$CONFIG_FILE" | grep -v "^#" | grep -v "^$" | while read -r line; do
      echo "  $line"
    done
    echo ""

    local shim_dir
    shim_dir=$(grep "^XDG_OPEN_SHIM_DIR=" "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f2)
    shim_dir="${shim_dir:-$DEFAULT_SHIM_DIR}"
    local shim_file="$shim_dir/xdg-open"

    echo "${cl_green}Shim:${cl_reset}"
    if [[ -f "$shim_file" ]]; then
      echo "  File: $shim_file"
      echo "  Status: ${cl_green}installed${cl_reset}"
      echo "  Executable: $([[ -x "$shim_file" ]] && echo "yes" || echo "${cl_red}no${cl_reset}")"
    else
      echo "  Status: ${cl_yellow}not installed${cl_reset}"
    fi
    echo ""
  else
    echo "${cl_yellow}Not configured${cl_reset}"
    echo "  Run 'xdg-open --config' to set up."
    echo ""
  fi

  echo "${cl_green}Available Windows Launchers:${cl_reset}"
  local launchers
  launchers=$(xdg:detect:launcher)
  if [[ -n "$launchers" ]]; then
    echo "$launchers" | while read -r launcher; do
      echo "  - $launcher"
    done
  else
    echo "  ${cl_red}None detected${cl_reset}"
  fi
  echo ""

  echo "${cl_green}Environment:${cl_reset}"
  echo "  WSL_DISTRO_NAME: ${WSL_DISTRO_NAME:-${cl_yellow}not set${cl_reset}}"
  echo "  WSL_INTEROP: ${WSL_INTEROP:+set}"
  echo "  In WSL: $(wsl:is_wsl && echo "${cl_green}yes${cl_reset}" || echo "${cl_yellow}no${cl_reset}")"
}

##
## Run the TUI configuration wizard.
##
function xdg:config:wizard() {
  echo ""
  echo "${cl_cyan}╔══════════════════════════════════════════════════════════╗${cl_reset}"
  echo "${cl_cyan}║${cl_reset}          ${cl_lwhite}xdg-open-wsl Configuration Wizard${cl_reset}               ${cl_cyan}║${cl_reset}"
  echo "${cl_cyan}║${cl_reset}  Configure how URLs and files open in WSL environment    ${cl_cyan}║${cl_reset}"
  echo "${cl_cyan}╚══════════════════════════════════════════════════════════╝${cl_reset}"
  echo ""

  # Check if in WSL
  if ! wsl:is_wsl; then
    echo "${cl_yellow}⚠ Warning: Not running in WSL environment.${cl_reset}"
    echo "  The shim will fall back to /usr/bin/xdg-open."
    echo ""
  fi

  # Detect Windows users for Scoop installations
  local win_users win_user_count
  win_users=$(xdg:windows:users)
  win_user_count=$(echo "$win_users" | grep -c . 2>/dev/null || echo "0")

  if [[ $win_user_count -gt 1 ]]; then
    # Multiple Windows users - ask which one to use for Scoop
    echo "${cl_lblue}Step 0:${cl_reset} Select Windows User"
    echo "Multiple Windows user accounts found."
    echo "Select the user for Scoop installations (if any)."
    echo ""

    declare -A user_options
    while IFS= read -r user; do
      [[ -n "$user" ]] && user_options["$user"]="$user"
    done <<< "$win_users"

    echo -n "Select Windows user: "
    local selected_user
    selected_user=$(input:selector "user_options" "key")

    if [[ -z "$selected_user" ]]; then
      echo "${cl_red}Aborted.${cl_reset}"
      return 1
    fi

    XDG_OPEN_WINDOWS_USER="$selected_user"
    echo ""
    echo "${cl_green}✓${cl_reset} Selected: ${cl_cyan}$XDG_OPEN_WINDOWS_USER${cl_reset}"
    echo ""
  elif [[ $win_user_count -eq 1 ]]; then
    # Single Windows user - use automatically
    XDG_OPEN_WINDOWS_USER=$(echo "$win_users" | head -1)
    echo "Detected Windows user: ${cl_cyan}$XDG_OPEN_WINDOWS_USER${cl_reset}"
    echo ""
  fi

  # Step 1: Launcher Selection
  echo "${cl_lblue}Step 1:${cl_reset} Select Windows Launcher"
  echo "Choose how to open URLs/files in Windows."
  echo ""

  # Detect available launchers and build options dynamically
  local -A launcher_options
  local detected_launchers
  detected_launchers=$(xdg:detect:launcher)

  if [[ -z "$detected_launchers" ]]; then
    echo "${cl_red}Error: No Windows launchers detected!${cl_reset}"
    echo "  Please ensure PowerShell or cmd.exe is available in your WSL PATH."
    echo ""
    return 1
  fi

  while IFS= read -r launcher; do
    case "$launcher" in
      "powershell")        launcher_options["powershell"]="Windows PowerShell 5.1" ;;
      "pwsh")              launcher_options["pwsh"]="PowerShell Core 7+" ;;
      "cmd")               launcher_options["cmd"]="Command Prompt (minimal)" ;;
      "pwsh-scoop")        launcher_options["pwsh-scoop"]="PowerShell Core (Scoop)" ;;
      "powershell-scoop")  launcher_options["powershell-scoop"]="Windows PowerShell (Scoop)" ;;
      "pwsh-winget")       launcher_options["pwsh-winget"]="PowerShell Core (Winget)" ;;
    esac
  done <<< "$detected_launchers"

  echo -n "Select launcher: "
  XDG_OPEN_LAUNCHER=$(input:selector "launcher_options" "key")

  if [[ -z "$XDG_OPEN_LAUNCHER" ]]; then
    echo "${cl_red}Aborted.${cl_reset}"
    return 1
  fi

  echo ""
  echo "${cl_green}✓${cl_reset} Selected: ${cl_cyan}$XDG_OPEN_LAUNCHER${cl_reset}"

  # Show resolved launcher path
  local launcher_path
  launcher_path=$(xdg:launcher:path "$XDG_OPEN_LAUNCHER")
  if [[ "$launcher_path" != /* ]]; then
    # System PATH executable
    echo "  Executable: ${cl_grey}${launcher_path}${cl_reset} (in PATH)"
  else
    echo "  Resolved: ${cl_grey}${launcher_path}${cl_reset}"
  fi
  echo ""

  # Step 2: Browser Selection
  echo "${cl_lblue}Step 2:${cl_reset} Select Browser Preference"
  echo "Choose which browser to use for opening URLs."
  echo ""

  # Detect available browsers and build options
  declare -A browser_options
  local detected_browsers
  detected_browsers=$(xdg:browser:detect)

  while IFS= read -r browser; do
    case "$browser" in
      "default") browser_options["default"]="Windows Default Browser" ;;
      "chrome")  browser_options["chrome"]="Google Chrome" ;;
      "firefox") browser_options["firefox"]="Mozilla Firefox" ;;
      "edge")    browser_options["edge"]="Microsoft Edge" ;;
      "brave")   browser_options["brave"]="Brave Browser" ;;
      "custom")  browser_options["custom"]="Custom path..." ;;
    esac
  done <<< "$detected_browsers"

  echo -n "Select browser: "
  XDG_OPEN_BROWSER=$(input:selector "browser_options" "key")

  if [[ -z "$XDG_OPEN_BROWSER" ]]; then
    echo "${cl_red}Aborted.${cl_reset}"
    return 1
  fi

  # Handle custom browser path
  local browser_custom_path=""
  if [[ "$XDG_OPEN_BROWSER" == "custom" ]]; then
    echo ""
    echo "${cl_white}Enter custom browser path:${cl_reset}"
    echo "  Example: $XDG_WSL_WIN/Browser/browser.exe"
    echo ""
    validate:input browser_custom_path "" "Path to browser executable"
    if [[ -z "$browser_custom_path" ]]; then
      echo "${cl_red}Aborted.${cl_reset}"
      return 1
    fi
    # Verify the custom path exists
    if [[ ! -f "$browser_custom_path" ]]; then
      echo "${cl_yellow}⚠ Warning: Path does not exist: ${browser_custom_path}${cl_reset}"
    fi
    XDG_OPEN_BROWSER_PATH="$browser_custom_path"
    echo ""
    echo "${cl_green}✓${cl_reset} Selected: ${cl_cyan}${browser_custom_path}${cl_reset}"
  else
    # Show resolved browser path
    local browser_path
    browser_path=$(xdg:browser:path "$XDG_OPEN_BROWSER")
    if [[ -n "$browser_path" && "$browser_path" != *.exe ]]; then
      # Path couldn't be resolved, using fallback
      echo ""
      echo "${cl_green}✓${cl_reset} Selected: ${cl_cyan}$XDG_OPEN_BROWSER${cl_reset} (Windows default handler)"
    elif [[ -n "$browser_path" ]]; then
      echo ""
      echo "${cl_green}✓${cl_reset} Selected: ${cl_cyan}$XDG_OPEN_BROWSER${cl_reset}"
      echo "  Resolved: ${cl_grey}${browser_path}${cl_reset}"
    else
      echo ""
      echo "${cl_green}✓${cl_reset} Selected: ${cl_cyan}$XDG_OPEN_BROWSER${cl_reset} (Windows default)"
    fi
    XDG_OPEN_BROWSER_PATH="$browser_path"
  fi
  echo ""

  # Step 3: Installation Location
  echo "${cl_lblue}Step 3:${cl_reset} Select Installation Location"
  echo "Choose where to install the xdg-open shim."
  echo ""

  declare -A location_options=(
    ["$DEFAULT_SHIM_DIR"]="User local (recommended)"
    ["/usr/local/bin"]="System-wide (requires sudo)"
  )

  echo -n "Installation location: "
  XDG_OPEN_SHIM_DIR=$(input:selector "location_options" "key")

  if [[ -z "$XDG_OPEN_SHIM_DIR" ]]; then
    echo "${cl_red}Aborted.${cl_reset}"
    return 1
  fi

  echo ""
  echo "${cl_green}✓${cl_reset} Selected: ${cl_cyan}$XDG_OPEN_SHIM_DIR${cl_reset}"
  echo ""

  # Summary and Confirmation
  echo "${cl_white}═════════════════════════════════════════════════════════${cl_reset}"
  echo "${cl_white}Configuration Summary:${cl_reset}"
  echo "  Launcher:    ${cl_cyan}$XDG_OPEN_LAUNCHER${cl_reset}"
  if [[ "$XDG_OPEN_BROWSER" == "custom" && -n "$XDG_OPEN_BROWSER_PATH" ]]; then
    echo "  Browser:     ${cl_cyan}${XDG_OPEN_BROWSER_PATH}${cl_reset}"
  else
    echo "  Browser:     ${cl_cyan}$XDG_OPEN_BROWSER${cl_reset}"
  fi
  if [[ -n "$XDG_OPEN_WINDOWS_USER" ]]; then
    echo "  Win User:    ${cl_cyan}$XDG_OPEN_WINDOWS_USER${cl_reset}"
  fi
  echo "  Shim dir:    ${cl_cyan}$XDG_OPEN_SHIM_DIR${cl_reset}"
  echo "${cl_white}═════════════════════════════════════════════════════════${cl_reset}"
  echo ""

  local confirm
  validate:input:yn confirm "y" "Save configuration and install shim?"
  echo ""

  if [[ "$confirm" != "true" ]]; then
    echo "${cl_yellow}Configuration cancelled.${cl_reset}"
    return 1
  fi

  # Write config and install shim
  xdg:config:write
  xdg:shim:install

  echo ""
  echo "${cl_green}✓ Configuration complete!${cl_reset}"
  echo "  Run 'xdg-open --status' to view configuration."
  echo "  Run 'xdg-open --config' to reconfigure."
  echo ""
}

##
## Show help message.
##
function xdg:help:show() {
  cat <<EOF
${cl_cyan}xdg-open-wsl${cl_reset} - Open URLs and files from WSL in Windows

${cl_white}Usage:${cl_reset}
  xdg-open <url-or-path>       Open URL or file in Windows
  xdg-open --config            Run configuration wizard
  xdg-open --status            Show current configuration
  xdg-open --uninstall         Remove configuration and shim
  xdg-open --help              Show this help message
  xdg-open --version           Show version information

${cl_white}First Run:${cl_reset}
  On first run, xdg-open will launch a configuration wizard to:
  1. Select Windows launcher (PowerShell, pwsh, cmd)
  2. Select browser preference (default, Chrome, Firefox, etc.)
  3. Choose installation location for the shim

${cl_white}Examples:${cl_reset}
  xdg-open https://example.com           Open URL in browser
  xdg-open /mnt/c/Users/file.txt         Open file in Windows
  xdg-open file:///home/user/doc.pdf     Open file in Windows

${cl_white}Environment:${cl_reset}
  DEBUG         Enable debug logging (e.g., DEBUG=wsl,xdg)
  DRY_RUN       Print commands without executing (DRY_RUN=true)
  XDG_WSL_USERS Windows Users directory (default: /mnt/c/Users)
  XDG_WSL_WIN   Windows Program Files (default: /mnt/c/Program Files)
  XDG_WSL_WIN86 Windows Program Files x86 (default: /mnt/c/Program Files (x86))

${cl_white}Files:${cl_reset}
  Config:  $CONFIG_FILE
  Shim:    ~/.local/bin/xdg-open (or custom location)

${cl_white}Version:${cl_reset} $VERSION
EOF
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

  # Read user preference
  local launcher="${XDG_OPEN_LAUNCHER:-powershell}"
  local browser_path="${XDG_OPEN_BROWSER_PATH:-}"
  local launcher_exe
  launcher_exe=$(xdg:launcher:exe "$launcher")

  echo:Wsl "launcher: $launcher_exe (preference: $launcher)"
  echo:Wsl "browser: ${XDG_OPEN_BROWSER:-default} (path: ${browser_path:-<default>})"

  # Convert browser path to Windows format if it's a Linux path
  local browser_path_win="$browser_path"
  if [[ -n "$browser_path" && "$browser_path" == /* ]]; then
    if command -v wslpath >/dev/null 2>&1; then
      browser_path_win=$(wslpath -w "$browser_path" 2>/dev/null || echo "$browser_path")
      echo:Wsl "converted browser path: $browser_path -> $browser_path_win"
    fi
  fi

  # Build PowerShell command - use specific browser if configured
  local ps_command
  if [[ -n "$browser_path_win" ]]; then
    # Use specific browser with URL as argument
    ps_command="Start-Process \"${browser_path_win}\" -ArgumentList \"${win_target}\""
    echo:Wsl "using specific browser: $browser_path_win"
  else
    # Use Windows default handler
    ps_command="Start-Process \"${win_target}\""
    echo:Wsl "using Windows default handler"
  fi

  # Use configured launcher
  if [[ "$launcher_exe" == "cmd.exe" ]]; then
    if command -v cmd.exe >/dev/null 2>&1; then
      if [[ -n "$browser_path_win" ]]; then
        cmd.exe /c start "" "${browser_path_win}" "${win_target}" >/dev/null 2>&1 && return 0
      else
        cmd.exe /c start "" "${win_target}" >/dev/null 2>&1 && return 0
      fi
    fi
  elif [[ "$launcher_exe" == "pwsh.exe" ]]; then
    # Check for pwsh in various locations
    local pwsh_path="pwsh.exe"
    if [[ "$launcher" == "pwsh-winget" ]]; then
      pwsh_path="$XDG_WSL_WIN/PowerShell/7/pwsh.exe"
    fi
    if command -v "$pwsh_path" >/dev/null 2>&1 || [[ -f "$pwsh_path" ]]; then
      "$pwsh_path" -NoProfile -NonInteractive -Command "$ps_command" \
        >/dev/null 2>&1 && return 0
    fi
  fi

  # Default: PowerShell is preferred - handles UNC paths, spaces, and all URL schemes
  if command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -NonInteractive -Command "$ps_command" \
      >/dev/null 2>&1 && return 0
    echo:Wsl "powershell.exe failed, trying cmd.exe"
  fi

  # cmd.exe start is the universal fallback on older/minimal Windows setups
  if command -v cmd.exe >/dev/null 2>&1; then
    echo:Wsl "launcher: cmd.exe"
    if [[ -n "$browser_path_win" ]]; then
      cmd.exe /c start "" "${browser_path_win}" "${win_target}" >/dev/null 2>&1 && return 0
    else
      cmd.exe /c start "" "${win_target}" >/dev/null 2>&1 && return 0
    fi
    echo:Wsl "cmd.exe also failed"
  fi

  echo "${cl_red}error:${cl_reset} no Windows launcher found (powershell.exe / cmd.exe); cannot open: ${win_target}" >&2
  return 1
}

##
## Open URL/file directly (non-config flow).
##
function xdg:open() {
  local target="$1"
  echo:Wsl "target: ${target}"

  if wsl:is_wsl; then
    local distro="${WSL_DISTRO_NAME:-unknown}"
    echo:Wsl "WSL detected (distro: ${distro})"

    local win_target
    win_target=$(xdg:to_win_path "$target")
    echo:Wsl "resolved: ${win_target}"

    xdg:open_in_windows "$win_target"
    return $?
  fi

  # Non-WSL: hand off to the real xdg-open
  echo:Xdg "non-WSL environment, delegating to: ${ORIG_XDG_OPEN}"
  if [[ -x "$ORIG_XDG_OPEN" ]]; then
    exec "$ORIG_XDG_OPEN" "$@"
  fi

  echo "${cl_red}error:${cl_reset} real xdg-open not found at ${ORIG_XDG_OPEN}" >&2
  return 1
}

##
## Entry point
##
function main() {
  # Handle subcommands
  case "${1:-}" in
  --config | -c)
    xdg:config:wizard
    exit $?
    ;;
  --status | -s)
    xdg:status:show
    exit 0
    ;;
  --uninstall)
    xdg:uninstall
    exit 0
    ;;
  --help | -h)
    xdg:help:show
    exit 0
    ;;
  --version | -v)
    echo "xdg-open-wsl $VERSION"
    exit 0
    ;;
  esac

  # Require argument for normal operation
  if [[ $# -lt 1 ]]; then
    xdg:help:show
    exit 1
  fi

  # First run detection - launch wizard
  if xdg:is_first_run; then
    echo "${cl_cyan}First run detected. Starting configuration wizard...${cl_reset}"
    echo ""
    xdg:config:wizard || exit $?
    echo ""
    echo "${cl_cyan}Now opening: ${cl_white}$1${cl_reset}"
    echo ""
  fi

  # Read config and open
  xdg:config:read
  xdg:open "$1"
}

# Only run main if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
