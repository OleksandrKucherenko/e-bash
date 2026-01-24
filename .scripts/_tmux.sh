#!/usr/bin/env bash
# shellcheck disable=SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# =============================================================================
# Module: _tmux.sh
# Description: Tmux integration for progress displays and session management
#
# This module provides utilities for creating interactive tmux-based UIs in
# Bash scripts. It supports:
#   - Automatic tmux session creation and management
#   - Split-pane progress displays using FIFOs
#   - Real-time progress bars with percentage tracking
#   - Mouse support detection and configuration
#   - Automatic cleanup of tmux resources and sessions
#
# Typical workflow:
#   1. Call tmux:ensure_session to start/detect tmux session
#   2. Call tmux:init_progress to create a progress display pane
#   3. Use tmux:update_progress or tmux:show_progress_bar to show updates
#   4. Call tmux:setup_trap to auto-cleanup on script exit
#   5. Cleanup happens automatically via trap, or call tmux:cleanup_all manually
#
# Global variables used:
#   TMUX_STARTED_BY_SCRIPT - Set when script creates its own tmux session
#   TMUX_SESSION_NAME - Name of the tmux session
#   TMUX_PROGRESS_ACTIVE - Boolean flag indicating if progress display is active
#   TMUX_FIFO_PATH - Path to the FIFO used for progress updates
#
# See demos/demo.tmux.progress.sh, demos/demo.tmux.runner.sh, and
# demos/demo.tmux.exec.sh for usage examples.
# =============================================================================

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

# Function: tmux:ensure_session
# Description: Start a new tmux session if not already in one. This function
#              detects whether the script is running inside tmux, and if not,
#              creates a new tmux session and re-executes the script within it.
#              Uses exec to replace the current process with the tmux session.
# Arguments:
#   $@ - Script arguments to pass when re-executing inside tmux
# Returns:
#   0 - Already in tmux session (no action needed)
#   N/A - If not in tmux, exec replaces process (doesn't return)
# Side Effects:
#   - Checks $TMUX environment variable to detect existing session
#   - Sets TMUX_STARTED_BY_SCRIPT=1 when creating a new session
#   - Sets/exports TMUX_SESSION_NAME (uses "tmux_session_$$" if not set)
#   - Calls echo:Tmux for logging (requires logger module)
#   - Executes 'exec tmux new-session' which replaces the current process
# Example:
#   #!/usr/bin/env bash
#   source "$E_BASH/_tmux.sh"
#   export TMUX_SESSION_NAME="my_app_$$"
#   tmux:ensure_session "$@"
#   # Script continues here only if already in tmux
#   echo "Running inside tmux session: $TMUX_SESSION_NAME"
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

# Function: tmux:init_progress
# Description: Initialize a progress display pane at the bottom of the tmux window.
#              Creates a FIFO (named pipe) for sending progress updates and splits
#              the current pane horizontally, dedicating the bottom portion to
#              displaying real-time progress via 'tail -f' on the FIFO. Configures
#              the progress pane as read-only with a distinctive background color.
# Arguments:
#   $1 - fifo_path (optional, string) - Custom path for the named pipe.
#        Defaults to a temporary file path created with mktemp.
# Returns:
#   0 - Progress display initialized successfully
# Side Effects:
#   - Sets global variable TMUX_FIFO_PATH to the FIFO path
#   - Sets global variable TMUX_PROGRESS_ACTIVE to true
#   - Creates a FIFO at $TMUX_FIFO_PATH (removes existing if present)
#   - Splits tmux window vertically with height TMUX_PROGRESS_HEIGHT (2 lines)
#   - Starts 'tail -f' in the progress pane (TMUX_PROGRESS_PANE=1)
#   - Disables user input on the progress pane (select-pane -d)
#   - Sets progress pane background to colour25 (light blue)
#   - Returns focus to the main pane (TMUX_MAIN_PANE=0)
#   - Calls echo:Tmux for logging (requires logger module)
# Example:
#   source "$E_BASH/_tmux.sh"
#   tmux:ensure_session "$@"
#   tmux:init_progress
#   tmux:update_progress "Starting task..."
#   tmux:show_progress_bar 50 100 "Processing"
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

# Function: tmux:update_progress
# Description: Send a text message to the progress display pane. The message
#              is written to the FIFO and appears in real-time in the progress
#              pane. If the progress display is not active, outputs a debug
#              message to stderr instead.
# Arguments:
#   $1 - message (required, string) - Progress message to display in the pane
# Returns:
#   0 - Message sent successfully to FIFO
#   1 - Progress display not active or FIFO not available
# Side Effects:
#   - Writes message to TMUX_FIFO_PATH (if active and pipe exists)
#   - Outputs debug message to stderr if progress display is not active
#   - Uses echo -e to support escape sequences (e.g., ANSI colors, \n)
#   - Suppresses errors from echo (2>/dev/null) to prevent broken pipe messages
# Example:
#   tmux:init_progress
#   tmux:update_progress "Downloading files..."
#   tmux:update_progress "${cl_green}Download complete!${cl_reset}"
#   tmux:update_progress "Processing: 10/100 files"
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

# Function: tmux:show_progress_bar
# Description: Display a visual progress bar with percentage and count in the
#              progress pane. Automatically normalizes the current value to be
#              within [0, total] range and highlights errors when current exceeds
#              total. The progress bar shows filled (#) and empty spaces.
# Arguments:
#   $1 - current (required, number) - Current progress value (normalized to [0, total])
#   $2 - total (required, number) - Total progress value (denominator)
#   $3 - prefix (optional, string) - Label prefix for the bar. Default: "Progress"
#   $4 - width (optional, number) - Character width of the bar. Default: 50
# Returns:
#   0 - Progress bar displayed successfully
# Side Effects:
#   - Calls tmux:update_progress to send the formatted bar to the FIFO
#   - Normalizes current to be >= 0 and <= total before calculations
#   - Uses cl_red and cl_reset color codes (from _colors.sh) when current > total
#   - Progress bar format: "Prefix: [####    ] 50% (current/total)"
#   - If current > total, the current value is highlighted in red
# Example:
#   tmux:init_progress
#   for i in {1..100}; do
#     tmux:show_progress_bar "$i" 100 "Installing" 60
#     sleep 0.1
#   done
#   # With error highlighting:
#   tmux:show_progress_bar 150 100 "Error"  # Shows 150 in red
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

# Function: tmux:cleanup_progress
# Description: Clean up the progress display pane and FIFO resources. Kills the
#              progress pane, removes the FIFO file, and resets the progress state.
#              Safe to call multiple times (no-op if already cleaned up).
# Arguments:
#   None
# Returns:
#   0 - Cleanup successful or progress was not active
# Side Effects:
#   - Returns immediately if TMUX_PROGRESS_ACTIVE is false (quick exit)
#   - Selects the main pane (TMUX_MAIN_PANE=0) before cleanup
#   - Kills the progress pane (TMUX_PROGRESS_PANE=1) using tmux kill-pane
#   - Removes the FIFO file at TMUX_FIFO_PATH (if it exists as a named pipe)
#   - Sets TMUX_PROGRESS_ACTIVE to false
#   - Calls echo:Tmux for logging cleanup actions
#   - Suppresses tmux errors with 2>/dev/null
# Example:
#   tmux:init_progress
#   tmux:update_progress "Working..."
#   # ... do work ...
#   tmux:cleanup_progress  # Clean up before script ends
#   # Or rely on tmux:cleanup_all via trap
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

# Function: tmux:cleanup_all
# Description: Comprehensive cleanup of all tmux resources. Cleans up the progress
#              display and optionally kills the tmux session if it was started by
#              the script. Typically called from an EXIT trap or manually at script end.
# Arguments:
#   $1 - exit_session (optional, boolean) - Whether to kill the tmux session.
#        Default: true. Set to "false" to keep session running after cleanup.
# Returns:
#   None - May terminate the tmux session (does not return in that case)
# Side Effects:
#   - Calls tmux:cleanup_progress to clean up progress pane and FIFO
#   - If TMUX_STARTED_BY_SCRIPT is set and exit_session is true:
#     * Displays "Exiting tmux session..." message
#     * Sleeps for 1 second to let user see the message
#     * Kills the tmux session using TMUX_SESSION_NAME
#   - Suppresses tmux errors with 2>/dev/null
# Example:
#   # Keep session running after script ends
#   tmux:cleanup_all false
#
#   # Exit session when script ends (default)
#   tmux:cleanup_all
#
#   # Typical usage with trap
#   tmux:setup_trap  # Sets up automatic cleanup on EXIT
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

# Function: tmux:setup_trap
# Description: Configure a trap handler to automatically clean up tmux resources
#              when the script exits (normally, via interrupt, or termination).
#              Installs a trap for INT, TERM, and EXIT signals that calls
#              tmux:cleanup_all with the specified exit_session parameter.
# Arguments:
#   $1 - exit_session (optional, boolean) - Whether to kill the tmux session on exit.
#        Default: true. Passed through to tmux:cleanup_all.
# Returns:
#   None
# Side Effects:
#   - Installs trap handler for signals: INT, TERM, EXIT
#   - When triggered, calls tmux:cleanup_all with the exit_session argument
#   - Logs trap installation via echo:Tmux
#   - Replaces any existing trap handlers for these signals
# Example:
#   source "$E_BASH/_tmux.sh"
#   tmux:ensure_session "$@"
#   tmux:init_progress
#   tmux:setup_trap  # Auto-cleanup on script exit
#   # ... script continues ...
#   # Cleanup happens automatically when script exits
#
#   # Keep session alive after script ends
#   tmux:setup_trap false
function tmux:setup_trap() {
  local exit_session="${1:-true}"
  
  # Create a trap function that calls our cleanup
  trap "tmux:cleanup_all $exit_session" INT TERM EXIT
  echo:Tmux "Set trap handler to clean up tmux resources"
}


# Function: tmux:check_mouse_support
# Description: Detect and enable mouse support in tmux if not already enabled.
#              Checks the global mouse setting and attempts to enable it for the
#              current session. Provides informational messages about the mouse
#              support status and configuration recommendations.
# Arguments:
#   None
# Returns:
#   None
# Side Effects:
#   - Retrieves tmux version using 'tmux -V' command
#   - Checks global tmux settings with 'tmux show -g' for "mouse on"
#   - If mouse is not enabled:
#     * Logs recommendation to add 'set -g mouse on' to ~/.tmux.conf
#     * Attempts to enable mouse support for current session with 'tmux set -g mouse on'
#     * Logs success or failure of the operation via echo:Tmux
#   - If mouse is already enabled, takes no action (silent)
#   - Called automatically when the module is sourced (at bottom of file)
# Example:
#   # Called automatically when sourcing _tmux.sh
#   source "$E_BASH/_tmux.sh"
#   # Mouse support is checked and enabled if needed
#
#   # Can also be called manually
#   tmux:check_mouse_support
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