#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-14
## Version: 2.0.1
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# Ultra-optimized bootstrap: E_BASH discovery + gnubin PATH
[ "$E_BASH" ] || { _src=${BASH_SOURCE:-$0}; E_BASH=$(cd "${_src%/*}/../.scripts" 2>&- && pwd || echo ~/.e-bash/.scripts); readonly E_BASH; . "$E_BASH/_gnu.sh"; PATH="$E_BASH/../bin/gnubin:$PATH"; }

# include other scripts: _colors, _logger, _commons, _dependencies, _arguments
# shellcheck disable=SC1090 source=../.scripts/_dependencies.sh
source "$E_BASH/_dependencies.sh"
source "$E_BASH/_colors.sh"

# Verify dependencies
dependency tmux "3.5a" "brew install tmux" "-VV"

# Configuration options
# Set AUTO_CLOSE=1 to automatically close tmux session after script completes
# Set AUTO_CLOSE=0 to keep tmux session open after script completes
AUTO_CLOSE=${AUTO_CLOSE:-1}

# Constants
readonly SCRIPT_PANE_HEIGHT=5
readonly STDOUT_PANE_HEIGHT=10
readonly STDERR_PANE_HEIGHT=10

# Function to show usage information
usage() {
  echo "Usage: $(basename "$0") <script_to_execute> [arguments...]"
  echo
  echo "Executes a script inside tmux with 3 panels:"
  echo "  - Top panel (small): Shows the script being executed"
  echo "  - Middle panel: Shows STDOUT of the executed script"
  echo "  - Bottom panel: Shows STDERR of the executed script (red background)"
  echo
  echo "Example: $(basename "$0") demos/demo.logs.sh"
  exit 1
}

# Check if a script to execute was provided
if [ $# -lt 1 ]; then
  usage
fi

SCRIPT_TO_EXECUTE="$1"
shift
SCRIPT_ARGS=("$@")

# Check if the script exists and is executable
if [ ! -f "$SCRIPT_TO_EXECUTE" ] || [ ! -x "$SCRIPT_TO_EXECUTE" ]; then
  echo "${cl_red}Error: '$SCRIPT_TO_EXECUTE' doesn't exist or is not executable.${cl_reset}" >&2
  usage
fi

# Generate a unique session name using PID to avoid duplicates
SESSION_NAME="streams_demo_$$"

# Create named pipes for stdout and stderr
STDOUT_FIFO="/tmp/stdout_fifo_$$"
STDERR_FIFO="/tmp/stderr_fifo_$$"

# Clean up any leftover FIFOs
[ -p "$STDOUT_FIFO" ] && rm -f "$STDOUT_FIFO"
[ -p "$STDERR_FIFO" ] && rm -f "$STDERR_FIFO"

# Create the FIFOs
mkfifo "$STDOUT_FIFO"
mkfifo "$STDERR_FIFO"

# Function to clean up resources when interrupted or done
cleanup() {
  echo "Cleaning up..."
  
  # Remove the FIFOs
  [ -p "$STDOUT_FIFO" ] && rm -f "$STDOUT_FIFO"
  [ -p "$STDERR_FIFO" ] && rm -f "$STDERR_FIFO"
  
  # If we started the tmux session and AUTO_CLOSE is enabled, kill the session
  if [ -n "$TMUX_STARTED_BY_SCRIPT" ] && [ "$AUTO_CLOSE" -eq 1 ]; then
    echo "Exiting tmux session..."
    tmux kill-session -t "$TMUX_SESSION_NAME" 2>/dev/null
  elif [ -n "$TMUX_STARTED_BY_SCRIPT" ] && [ "$AUTO_CLOSE" -eq 0 ]; then
    # Just exit the script but leave tmux session running
    echo "Leaving tmux session running. Use 'exit' or 'Ctrl+D' to close it manually."
  fi
  
  exit 0
}

# Set up trap to catch interrupt (Ctrl+C)
trap cleanup INT TERM EXIT

# Check if we're already in a tmux session
if [ -z "$TMUX" ]; then
  # Not in a tmux session, so start one and run this script inside it
  echo "Starting a new tmux session: $SESSION_NAME"
  # Set environment variable to track that we started tmux
  export TMUX_STARTED_BY_SCRIPT=1
  export TMUX_SESSION_NAME="$SESSION_NAME"
  exec tmux new-session -s "$SESSION_NAME" "$0" "$SCRIPT_TO_EXECUTE" "${SCRIPT_ARGS[@]}"
  # The exec replaces the current process, so nothing after this will run
  # if we're starting tmux
fi

# From here, we're definitely inside tmux
# At this point, we're in the first pane (pane 0) of the session

# Prepare the command to execute the script with redirected streams
# The command creates a temporary script that redirects stdout and stderr to the FIFOs
SCRIPT_RUN_CMD="echo Running: \"$SCRIPT_TO_EXECUTE\" ${SCRIPT_ARGS[*]} && \"$SCRIPT_TO_EXECUTE\" ${SCRIPT_ARGS[*]} > \"$STDOUT_FIFO\" 2> \"$STDERR_FIFO\""

# Create the three-pane layout
# 1. Rename the current pane
tmux rename-window "Script Output Streams"

# 2. Set up the main execution pane (small top pane)
# We're already in pane 0, so just resize it
tmux resize-pane -y "$SCRIPT_PANE_HEIGHT"

# 3. Create STDOUT pane (middle)
tmux split-window -v -l "$STDOUT_PANE_HEIGHT" "echo -e \"${cl_green}STDOUT of script: ${cl_yellow}$SCRIPT_TO_EXECUTE ${SCRIPT_ARGS[*]}${cl_reset}\" && cat \"$STDOUT_FIFO\""

# 4. Create STDERR pane (bottom)
tmux split-window -v "echo -e \"${cl_red}STDERR of script: ${cl_yellow}$SCRIPT_TO_EXECUTE ${SCRIPT_ARGS[*]}${cl_reset}\" && cat \"$STDERR_FIFO\""

# Set background color for STDERR pane (pane 2) to red
tmux select-pane -t 2
tmux select-pane -P 'bg=colour52'

# Go back to the top pane to execute the script
tmux select-pane -t 0

# Execute the script with redirected streams
echo "${cl_cyan}Executing: $SCRIPT_TO_EXECUTE ${SCRIPT_ARGS[*]}${cl_reset}"
eval "$SCRIPT_RUN_CMD"
echo "${cl_green}Script execution completed.${cl_reset}"

# Handle session cleanup based on AUTO_CLOSE setting
if [ -n "$TMUX_STARTED_BY_SCRIPT" ]; then
  if [ "$AUTO_CLOSE" -eq 1 ]; then
    # Auto close is enabled - show message and wait briefly before exiting
    echo -e "\n${cl_cyan}Session will close in 5 seconds. (Set AUTO_CLOSE=0 to disable)${cl_reset}"
    sleep 5
    # Let the EXIT trap handle cleanup
  else
    # Auto close is disabled - keep session open until user exits
    echo -e "\n${cl_cyan}Press Ctrl+C to exit the tmux session. (AUTO_CLOSE=0)${cl_reset}"
    # Remove the automatic exit trap so we don't exit immediately
    trap - EXIT
    # Set specific trap for Ctrl+C now
    trap cleanup INT TERM
    # Keep the script running to allow user to read the output
    while true; do
      sleep 1
    done
  fi
fi
