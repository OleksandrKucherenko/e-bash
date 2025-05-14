#!/bin/bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-04-05
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# tmux-run: Execute a command and display its command, STDOUT, and STDERR
#           in separate tmux panes with optional line processing and layouts.
#           Supports long options (e.g., --timestamp).

#set -x # trace the execution

# --- Configuration ---
SESSION_NAME="cmd_runner_$$" # Unique session name using PID
CLEANUP_ON_EXIT=true         # Set to false to leave the tmux session running after script exits

# --- Pre-requisites Check ---
# Note: This script uses the enhanced 'getopt' command (from util-linux)
#       to support long options (e.g., --timestamp).
# command -v getopt >/dev/null 2>&1 || { echo >&2 "Error: 'getopt' command not found. It might be part of 'util-linux'. Aborting."; exit 1; }
# command -v tmux >/dev/null 2>&1 || { echo >&2 "Error: tmux is required but not installed. Aborting."; exit 1; }
# command -v awk >/dev/null 2>&1 || { echo >&2 "Error: awk is required but not installed. Aborting."; exit 1; }
# command -v mktemp >/dev/null 2>&1 || { echo >&2 "Error: mktemp is required but not installed. Aborting."; exit 1; }

# --- Ensure tmux mouse support ---
# Color codes for logging (if not already defined)
readonly cl_reset=$(tput sgr0)
readonly cl_red=$(tput setaf 1)
readonly cl_yellow=$(tput setaf 3)

# Function to log with prefix
log_tmux() {
    printf "%b[tmux]%b %s\n" "$cl_yellow" "$cl_reset" "$1" >&2
}

# Check and enable mouse support if needed
_tmux_version=$(tmux -V | cut -d' ' -f2)
if ! tmux show -g | grep -q "mouse on"; then
    log_tmux "Mouse support not enabled in tmux. Enabling for this session."

    # Create or update .tmux.conf
    [ ! -f ~/.tmux.conf ] &&
        echo "set -g mouse on" >~/.tmux.conf &&
        log_tmux ".tmux.conf created with mouse support enabled." ||
        log_tmux ".tmux.conf already exists at $HOME/.tmux.conf"

    # Enable mouse support for this session
    tmux set -g mouse on 2>/dev/null &&
        log_tmux "Mouse support enabled in tmux." ||
        log_tmux "${cl_red}Failed to enable mouse support for this session${cl_reset}"
fi

# --- Option Parsing ---
show_timestamp=false
show_linenum=false
layout="T" # Default layout: T-shape

usage() {
    echo "Usage: $0 [options] -- <command> [args...]"
    echo "  Executes <command> and shows its output in a tmux session."
    echo ""
    echo "  Options:"
    echo "    -t, --timestamp           : Prefix each STDOUT/STDERR line with a timestamp (YYYY-MM-DD HH:MM:SS)."
    echo "    -n, --line-number         : Prefix each STDOUT/STDERR line with a global line number."
    echo "    -l, -L, --layout <layout> : Specify pane layout ('T' or 'E'). Default: 'T'."
    echo "                     'T': Command top, STDOUT bottom-left, STDERR bottom-right."
    echo "                     'E': Command top, STDOUT middle, STDERR bottom (vertical stack)."
    echo "    -h, --help                : Display this help message."
}

# Define short and long options
SHORT_OPTS="tnhL:"
LONG_OPTS="timestamp,line-number,layout:,help"

# Parse options using enhanced getopt
# -o specifies short options
# --long specifies long options
# -n specifies the program name for error messages
# -- "$@" passes the script's arguments to getopt
PARSED=$(getopt --options $SHORT_OPTS --longoptions $LONG_OPTS --name "$0" -- "$@")

# Check if getopt parsing was successful
if [ $? -ne 0 ]; then
    usage # getopt prints error messages, we just show usage and exit
fi

# Use eval to set positional parameters ($1, $2, etc.) to the parsed options
eval set -- "$PARSED"

# Process parsed options
while true; do
    case "$1" in
    -t | --timestamp)
        show_timestamp=true
        shift # Consume option
        ;;
    -n | --line-number)
        show_linenum=true
        shift # Consume option
        ;;
    -l | -L | --layout)
        layout=$(echo "$2" | tr '[:lower:]' '[:upper:]') # Convert to uppercase
        if [[ "$layout" != "T" && "$layout" != "E" ]]; then
            echo "Error: Invalid layout specified '$2'. Use 'T' or 'E'." >&2
            usage
        fi
        shift 2 # Consume option and argument
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    --)       # End of options marker
        shift # Consume the '--'
        break # Exit loop
        ;;
    *) # Should not happen with getopt
        echo "Internal error processing options!" >&2
        exit 1
        ;;
    esac
done

# Remaining arguments after '--' are the command to run
# --- Command Argument Check ---
if [ $# -eq 0 ]; then
    echo "Error: No command specified after '--'." >&2
    usage
fi
COMMAND_TO_RUN=("$@") # Store command and args in an array

# --- FIFO Setup ---
# Create temporary named pipes (FIFOs) for STDOUT and STDERR
FIFO_STDOUT=$(mktemp -u --tmpdir "${SESSION_NAME}_stdout.XXXXXX")
FIFO_STDERR=$(mktemp -u --tmpdir "${SESSION_NAME}_stderr.XXXXXX")

mkfifo "$FIFO_STDOUT" || {
    echo "Failed to create STDOUT FIFO"
    exit 1
}
mkfifo "$FIFO_STDERR" || {
    echo "Failed to create STDERR FIFO"
    rm -f "$FIFO_STDOUT"
    exit 1
}

# --- Cleanup Function ---
# Ensures FIFOs are removed on script exit or interruption
# shellcheck disable=SC2317
cleanup() {
    echo "Cleaning up FIFOs..."
    rm -f "$FIFO_STDOUT" "$FIFO_STDERR"
    if [ "$CLEANUP_ON_EXIT" = true ]; then
        # Check if the session still exists before trying to kill it
        if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
            echo "Killing tmux session $SESSION_NAME..."
            tmux kill-session -t "$SESSION_NAME"
        fi
    else
        echo "Tmux session '$SESSION_NAME' left running. Attach with: tmux attach -t $SESSION_NAME"
    fi
}
trap cleanup EXIT SIGINT SIGTERM

# --- Output Processors ---
# Define awk commands based on options
awk_cmd_base='{ fflush(); }' # Base command to ensure lines are printed immediately
awk_cmd_stdout=$awk_cmd_base
awk_cmd_stderr=$awk_cmd_base

# Build the awk print prefix dynamically
awk_prefix=""
if [ "$show_linenum" = true ]; then
    awk_prefix='"[L:" NR "] "'
fi
if [ "$show_timestamp" = true ]; then
    # Add space if linenum is also enabled
    [ -n "$awk_prefix" ] && awk_prefix="$awk_prefix \" \""
    awk_prefix="$awk_prefix strftime(\"[%Y-%m-%d %H:%M:%S] \")"
fi

# Combine prefix and the original line ($0)
if [ -n "$awk_prefix" ]; then
    awk_print_cmd='{ print '"$awk_prefix"' $0; fflush(); }'
    awk_cmd_stdout=$awk_print_cmd
    awk_cmd_stderr=$awk_print_cmd
else
    # If no options, just print the line
    awk_cmd_stdout='{ print; fflush(); }'
    awk_cmd_stderr='{ print; fflush(); }'
fi

# Commands to run in tmux panes (using cat to display FIFO content)
# Using 'cat' instead of 'tail -f' because the FIFO will receive EOF when the command finishes
# and the writing process closes the pipe, causing cat to exit naturally.
CMD_PANE_CMD="echo '--- Command ---'; echo; echo '$ ${COMMAND_TO_RUN[*]}'; echo; echo '--- Execution Log ---'; echo '[$(date '+%Y-%m-%d %H:%M:%S')] Starting command...'; exec sleep infinity" # Keep pane alive
STDOUT_PANE_CMD="echo '--- STDOUT ---'; echo; exec cat '$FIFO_STDOUT' | awk '$awk_cmd_stdout'"
STDERR_PANE_CMD="echo '--- STDERR ---'; echo; exec cat '$FIFO_STDERR' | awk '$awk_cmd_stderr'"

# --- Tmux Session Setup ---
echo "Setting up tmux session: $SESSION_NAME with layout: $layout"

# Start detached session, pane 0 created automatically
tmux new-session -d -s "$SESSION_NAME" -n "Runner"

# Pane 0: Command Display (Always the first pane)
tmux send-keys -t "$SESSION_NAME:Runner.0" "$CMD_PANE_CMD" C-m

# Create panes 1 (STDOUT) and 2 (STDERR) based on the selected layout
if [ "$layout" = "T" ]; then
    # T-Shape Layout: Pane 1 (STDOUT) below 0, Pane 2 (STDERR) right of 1
    tmux split-window -v -t "$SESSION_NAME:Runner.0" # Pane 1 below 0
    tmux send-keys -t "$SESSION_NAME:Runner.1" "$STDOUT_PANE_CMD" C-m
    tmux split-window -h -t "$SESSION_NAME:Runner.1" # Pane 2 right of 1
    tmux send-keys -t "$SESSION_NAME:Runner.2" "$STDERR_PANE_CMD" C-m
elif [ "$layout" = "E" ]; then
    # E-Shape Layout (Vertical Stack): Pane 1 (STDOUT) below 0, Pane 2 (STDERR) below 1
    tmux split-window -v -t "$SESSION_NAME:Runner.0" # Pane 1 below 0
    tmux send-keys -t "$SESSION_NAME:Runner.1" "$STDOUT_PANE_CMD" C-m
    tmux split-window -v -t "$SESSION_NAME:Runner.1" # Pane 2 below 1
    tmux send-keys -t "$SESSION_NAME:Runner.2" "$STDERR_PANE_CMD" C-m
fi

# Resize the top pane (Runner.0) to 12 lines
# This ensures the command/log pane is always 12 lines tall
# and output panes get the remaining space
tmux resize-pane -t "$SESSION_NAME:Runner.0" -y 12

# Select the top pane initially
tmux select-pane -t "$SESSION_NAME:Runner.0"

# --- Execute Command ---
echo "Executing command: ${COMMAND_TO_RUN[*]}"

# Execute the command in the background
# Redirect STDOUT and STDERR to the FIFOs
# Use subshell to handle redirection and ensure pipes are closed on exit
(
    # Setsid ensures the command runs in a new session, detaching it further
    # from the script's session, which might help with signal handling.
    setsid "${COMMAND_TO_RUN[@]}" >"$FIFO_STDOUT" 2>"$FIFO_STDERR"
) &
CMD_PID=$!

# Wait for the command to finish
wait $CMD_PID
CMD_EXIT_CODE=$?
echo "Command finished with exit code: $CMD_EXIT_CODE"

# Signal completion in the command pane (optional)
tmux send-keys -t "$SESSION_NAME:Runner.0" "echo '[$(date '+%Y-%m-%d %H:%M:%S')] Command finished (Exit Code: $CMD_EXIT_CODE).'" C-m
tmux send-keys -t "$SESSION_NAME:Runner.0" "echo 'You can detach (Ctrl-b d) or kill session (tmux kill-session -t $SESSION_NAME).'" C-m

# --- Attach to Session ---
echo "Attaching to tmux session: $SESSION_NAME"
echo "(Detach with Ctrl-b d)"
# Wait briefly to ensure tmux layout is stable
sleep 1
tmux attach-session -t "$SESSION_NAME"

# Cleanup will be called automatically via trap on exit

exit $CMD_EXIT_CODE

# Demo Examples:
#   - Basic usage: ./demo.tmux.runner.sh --session "MyDemo" --command "ls -l"
#   - With logging options: ./demo.tmux.runner.sh -L T -- ls -la
#     This will run the command with logging enabled to show detailed output in the tmux session.
#   - Split output to stdout/stderr: ./demo.tmux.runner.sh -L T -- bash -c "ls -la | tee /dev/stderr | grep '^d'"
#     This filters directory lines to stdout while sending all output to stderr as well.
#   - Selective output filtering: ./demo.tmux.runner.sh -L T -- bash -c "ls -la | tee >(grep '^d' >&2) | grep -v '^d'"
#     This sends directory lines to stderr and non-directory lines to stdout, ignoring nothing.
