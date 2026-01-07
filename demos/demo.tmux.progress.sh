#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# shellcheck disable=SC2155 # evaluate E_BASH from project structure if it's not set
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../.scripts && pwd)"

# include other scripts: _colors, _logger, _commons, _dependencies, _arguments
# shellcheck disable=SC1090 source=../.scripts/_dependencies.sh
source "$E_BASH/_dependencies.sh"

# Verify dependencies
dependency tmux "3.5a" "brew install tmux" "-VV"

readonly PROGRESS_HEIGHT=2 # minimal is 2 lines, otherwise last line will be not visible

# Generate a unique session name using PID to avoid duplicates
SESSION_NAME="progress_demo_$$"

# Check if we're already in a tmux session
if [ -z "$TMUX" ]; then
  # Not in a tmux session, so start one and run this script inside it
  echo "Starting a new tmux session: $SESSION_NAME"
  # Set environment variable to track that we started tmux
  export TMUX_STARTED_BY_SCRIPT=1
  export TMUX_SESSION_NAME="$SESSION_NAME"
  exec tmux new-session -s "$SESSION_NAME" "$0"
  # The exec replaces the current process, so nothing after this will run
  # if we're starting tmux
fi

# From here, we're definitely inside tmux

# Name of the FIFO
FIFO_PATH="/tmp/progress_fifo"

# Function to clean up resources when interrupted or done
cleanup() {
  echo "Cleaning up..."
  # Make sure we're in the main pane
  tmux select-pane -t 0 2>/dev/null
  
  # Kill the bottom pane if it exists
  tmux kill-pane -t 1 2>/dev/null
  
  # Remove the FIFO
  [ -p "$FIFO_PATH" ] && rm -f "$FIFO_PATH"
  
  # If we started the tmux session, kill it
  if [ -n "$TMUX_STARTED_BY_SCRIPT" ]; then
    echo "Exiting tmux session..."
    tmux kill-session -t "$TMUX_SESSION_NAME" 2>/dev/null
  fi
  
  exit 0
}

# Set up trap to catch interrupt (Ctrl+C)
trap cleanup INT TERM EXIT

# Clean up any leftover FIFO
[ -p "$FIFO_PATH" ] && rm -f "$FIFO_PATH"

# Create the FIFO
mkfifo "$FIFO_PATH"

# Split the current tmux pane to create a "$PROGRESS_HEIGHT"-line bottom pane
# which displays the content of the FIFO in real time.
tmux split-window -v -l "$PROGRESS_HEIGHT" "tail -f $FIFO_PATH"

# We know the bottom pane is always pane 1 in a fresh split
# The top pane is always pane 0
MAIN_PANE=0
BOTTOM_PANE=1

# Make the bottom pane read-only (locked from user interaction)
tmux select-pane -t "$BOTTOM_PANE" -M on  # Enable mouse mode
tmux select-pane -t "$BOTTOM_PANE" -d     # Disable user input

# Set colors to indicate read-only status (red background)
tmux select-pane -t "$BOTTOM_PANE" -P 'bg=colour52'

# Switch focus back to the main pane to ensure it stays there
tmux select-pane -t "$MAIN_PANE"

# Simulate a long operation: count from 1 to 100, updating every second
for i in $(seq 1 100); do
    echo "Progress: ${i}%" > "$FIFO_PATH"
    echo "main thread $i"
    sleep 0.1
done

# Finally, send a "Done!" message
echo "Done!" > "$FIFO_PATH"

# Allow viewing the "Done!" message for a moment
sleep 2

# Print completion message
echo "Process completed successfully."

# If we started the tmux session ourselves, prompt for exit
if [ -n "$TMUX_STARTED_BY_SCRIPT" ]; then
  echo "Press Ctrl+C to exit the tmux session."
  # Remove the automatic exit trap so we don't exit immediately
  trap - EXIT
  # Set specific trap for Ctrl+C now
  trap cleanup INT TERM
  # Keep the script running to allow user to read the message
  while true; do
    sleep 1
  done
fi

# If we get here, we weren't in a script-created tmux session
# Let the EXIT trap handle cleanup