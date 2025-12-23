#!/usr/bin/env bash
# shellcheck disable=SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-23
## Version: 1.12.6
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# shellcheck disable=SC2155
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1090 source=./_commons.sh
source /dev/null

# shellcheck disable=SC1090 source=./_logger.sh
source /dev/null

# shellcheck disable=SC1090 source=./_dependencies.sh
source "$E_BASH/_dependencies.sh"

# --- Constants ---
readonly TMUX_PROGRESS_HEIGHT=2 # minimal is 2 lines, otherwise last line will not be visible

# Pane indices, for easier naming
readonly TMUX_MAIN_PANE=0
readonly TMUX_PROGRESS_PANE=1

# --- Variables ---
# Global variables to track tmux session state
# Preserve environment variables if already set, otherwise initialize
: ${TMUX_STARTED_BY_SCRIPT:=}
: ${TMUX_SESSION_NAME:=}
: ${TMUX_PROGRESS_ACTIVE:=false}
# FIFO path for progress display
: ${TMUX_FIFO_PATH:=}

# Start a new tmux session if not already in one
# Arguments:
#   $@: script start parameters
# Returns:
#   0 on success, 1 on failure
# Side Effects:
#   Listens: TMUX_SESSION_NAME
#   Modifies: TMUX_STARTED_BY_SCRIPT, TMUX_SESSION_NAME
function tmux:ensure_session() {
  local session_name="${TMUX_SESSION_NAME:-"tmux_session_$$"}"
  
  # Only start a new session if not already in tmux
  if [ ! -z "$TMUX" ]; then return 0; fi

  echo:Tmux "Starting a new tmux session: $session_name"
  
  # Set environment variables to track that we started tmux
  export TMUX_STARTED_BY_SCRIPT=1
  export TMUX_SESSION_NAME="$session_name"
  
  # Start new session and execute the current script inside it
  echo:Tmux "exec tmux new-session -s \"$session_name\" \"$0\" $@"
  exec tmux new-session -s "$session_name" -- "$0" $@
  
  # The exec replaces the current process, so nothing after this will run
  # if we're starting tmux
  return 0
}

# Initialize progress display in a tmux pane
# Arguments:
#   $1: fifo_path (string, optional) - Path for the named pipe
# Returns:
#   0 on success, 1 on failure
# Side Effects:
#   Modifies: TMUX_FIFO_PATH, TMUX_PROGRESS_ACTIVE
function tmux:init_progress() {
  local fifo_path="${1:-"$(mktemp --dry-run -t 'tmux_progress')"}"
  
  # Store the FIFO path in the global variable
  TMUX_FIFO_PATH="$fifo_path"
  
  # Clean up any leftover FIFO
  [ -p "$TMUX_FIFO_PATH" ] && rm -f "$TMUX_FIFO_PATH"
  
  # Create the FIFO
  mkfifo "$TMUX_FIFO_PATH"
  echo:Tmux "Created FIFO: $TMUX_FIFO_PATH"
  
  # Split the current tmux pane to create a progress display area
  tmux split-window -v -l "$TMUX_PROGRESS_HEIGHT" "tail -f $TMUX_FIFO_PATH"
  
  # Configure the progress pane
  # In newer tmux versions, the mouse mode is controlled globally with 'set -g mouse on'
  # Just disable user input for the pane
  tmux select-pane -t "$TMUX_PROGRESS_PANE" -d
  
  # Set colors to indicate read-only status (light blue background)
  # possible colors, ref: https://i.sstatic.net/e63et.png
  # demos/demo.colors.sh - can be used also for that; 
  # example: 'bg=colour22,fg=white'
  tmux select-pane -t "$TMUX_PROGRESS_PANE" -P 'bg=colour25'
  
  # Switch focus back to the main pane
  tmux select-pane -t "$TMUX_MAIN_PANE"
  
  TMUX_PROGRESS_ACTIVE=true
  
  return 0
}

# Update progress display
# Arguments:
#   $1: message (string) - Progress message to display
# Returns:
#   0 on success, 1 on failure
function tmux:update_progress() {
  local message="$1"

  if [ "$TMUX_PROGRESS_ACTIVE" = true ] && [ -p "$TMUX_FIFO_PATH" ]; then
    echo -e "$message" > "$TMUX_FIFO_PATH" 2>/dev/null
    return 0
  fi

  # If progress display isn't active, just echo the message to stderr
  # This helps debug when progress is not going to the right place
  echo -e "[DEBUG: Progress not active] $message" >&2
  return 1
}

# Show percentage-based progress bar
# Arguments:
#   $1: current (number) - Current progress value
#   $2: total (number) - Total progress value
#   $3: prefix (string, optional) - Prefix for the progress bar
#   $4: width (number, optional) - Width of the progress bar
# Returns:
#   0 on success, 1 on failure
function tmux:show_progress_bar() {
  local current=$1
  local total=$2
  local prefix="${3:-"Progress"}"
  local width=${4:-50}
 
  # normalize current is greater-equal 0 and less-equal total
  local normalized_current=$((current > total ? total : current < 0 ? 0 : current))
  
  local percent=$((normalized_current * 100 / total))
  local completed=$((width * normalized_current / total))
  
  # Build progress bar
  local progress=""
  for ((i = 0; i < completed; i++)); do
    progress+="#"
  done
  for ((i = completed; i < width; i++)); do
    progress+=" "
  done
  
  # Create the progress message
  local bar="" format="%s: [%s] %d%% (%d/%d)"
  
  # highlight that current possition overpass the total and is a wrong/error number
  [ "$current" -gt "$total" ] && format="%s: [%s] %d%% (${cl_red}%d${cl_reset}/%d)"; 
  bar=$(printf "$format" "$prefix" "$progress" "$percent" "$current" "$total")
  
  # Update the progress display
  tmux:update_progress "$bar"
  
  return 0
}

# Clean up tmux progress display resources
# Returns:
#   0 on success, otherwise tmux error code
function tmux:cleanup_progress() {
  # Only clean up if progress is active, quick exit
  if [ "$TMUX_PROGRESS_ACTIVE" = false ]; then return 0; fi
  
  # Make sure we're in the main pane
  tmux select-pane -t "$TMUX_MAIN_PANE" 2>/dev/null
  
  # Kill the progress pane if it exists
  tmux kill-pane -t "$TMUX_PROGRESS_PANE" 2>/dev/null
  echo:Tmux "Killed progress pane: $TMUX_PROGRESS_PANE"
  
  # Remove the FIFO
  [ -p "$TMUX_FIFO_PATH" ] && rm -f "$TMUX_FIFO_PATH"
  echo:Tmux "Removed FIFO: $TMUX_FIFO_PATH"
  
  TMUX_PROGRESS_ACTIVE=false
  
  return 0
}

# Final cleanup and exit from tmux if needed
# Arguments:
#   $1: exit_session (boolean, optional) - Whether to exit the tmux session if we started it
# Returns:
#   None, may exit the process
function tmux:cleanup_all() {
  local exit_session="${1:-true}"
  
  # Clean up progress resources
  tmux:cleanup_progress
  
  # If we started the tmux session and exit_session is true, kill it
  if [ -n "$TMUX_STARTED_BY_SCRIPT" ] && [ "$exit_session" = true ]; then
    echo "Exiting tmux session..."
    sleep 1  # Give user a moment to see the message
    tmux kill-session -t "$TMUX_SESSION_NAME" 2>/dev/null
  fi
}

# Set up trap to catch interrupt and clean up resources
# Arguments:
#   $1: exit_session (boolean, optional) - Whether to exit the tmux session on cleanup
# Returns:
#   None
function tmux:setup_trap() {
  local exit_session="${1:-true}"
  
  # Create a trap function that calls our cleanup
  trap "tmux:cleanup_all $exit_session" INT TERM EXIT
  echo:Tmux "Set trap handler to clean up tmux resources"
}


# Check and enable mouse support if needed
# Arguments: none
# Returns:
#   None
function tmux:check_mouse_support() {
  # Get tmux version
  local tmux_version
  tmux_version=$(tmux -V | cut -d' ' -f2)
  
  # Check if mouse mode is already enabled
  if ! tmux show -g | grep -q "mouse on"; then
    echo:Tmux "Mouse support not enabled in tmux. You may want to add 'set -g mouse on' to your ~/.tmux.conf"
    echo:Tmux "For this session, enabling mouse support temporarily"
    
    # Try to enable mouse support for this session
    tmux set -g mouse on 2>/dev/null || echo:Tmux "Failed to enable mouse support for this session"

    # report about activation
    echo:Tmux "Mouse support enabled in tmux"
  fi
}

# This is the writing style presented by ShellSpec, which is short but unfamiliar.
# Note that it returns the current exit status (could be non-zero).
# DO NOT allow execution of code bellow those line in shellspec tests
${__SOURCED__:+return}

# register own logger
# make functions available: echo:Tmux, printf:Tmux and log:Tmux
logger:init tmux "[${cl_lgreen}tmux${cl_reset}] " ">&2"

# Verify dependencies, expected version 3.5a of the TMUX tool
dependency tmux "3.5a" "brew install tmux" "-VV" >&2

# Check mouse support when script is sourced
tmux:check_mouse_support