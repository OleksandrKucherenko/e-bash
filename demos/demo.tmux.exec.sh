#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-10
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# --- e-bash Environment Setup ---
DEBUG=${DEBUG:-"tui,exec,-internal"}

# shellcheck disable=SC2155 # evaluate E_BASH from project structure if it's not set
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../.scripts && pwd)"

# shellcheck source=../.scripts/_colors.sh
source "$E_BASH/_colors.sh"
# shellcheck source=../.scripts/_logger.sh
source "$E_BASH/_logger.sh"
# shellcheck source=../.scripts/_arguments.sh
source "$E_BASH/_arguments.sh"
# shellcheck source=../.scripts/_dependencies.sh
source "$E_BASH/_dependencies.sh"

# Register loggers and color-coded prefixes
logger:init tui "${cl_blue}[TUI]${cl_reset} " ">&2"
logger:init exec "${cl_green}[Exec]${cl_reset} " ">&2"
logger:init error "${cl_red}[Error]${cl_reset} " ">&2"
logger:init info "${cl_yellow}[Info]${cl_reset} " ">&2"

# --- Argument Parsing ---
arguments::init \
  --timestamp "Add timestamp to each output line" \
  --line-number "Add line numbers to output" \
  --help "Show help message" \
  -- "SCRIPT" "Script or command to execute (required)"

arguments::parse "$@"

if arguments::has --help; then
  echo "\n${cl_cyan}Usage:${cl_reset} $(basename "$0") [--timestamp] [--line-number] <script_or_command> [args...]\n"
  echo "Demonstrates e-bash logging, argument parsing, coloring, and tmux TUI."
  echo "\nOptions:"
  echo "  --timestamp      Prefix each output line with a timestamp."
  echo "  --line-number    Prefix each output line with a line number."
  echo "  --help           Show this help message."
  echo "  <script_or_command> [args...]  Script or command to run."
  exit 0
fi

SCRIPT_OR_CMD=$(arguments::get SCRIPT)
SCRIPT_ARGS=("${@:$(($arguments__POSITIONAL_INDEX + 1))}")

# --- Dependency & Input Validation ---
dependency tmux "3.5a" "brew install tmux" "-VV"
dependency awk "" "brew install awk"
dependency mktemp "" "brew install mktemp"

if [[ -z "$SCRIPT_OR_CMD" ]]; then
  echo:Error "No script or command provided. Use --help for usage."
  exit 1
fi

if [[ -f "$SCRIPT_OR_CMD" && ! -x "$SCRIPT_OR_CMD" ]]; then
  echo:Error "Script '$SCRIPT_OR_CMD' is not executable."
  exit 1
fi

# --- User Input Demo ---
echo:Info "About to run: ${cl_bold}${SCRIPT_OR_CMD}${cl_reset} ${SCRIPT_ARGS[*]}"
read -r -p "${cl_yellow}Proceed? (y/n): ${cl_reset}" confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo:Info "Aborted by user."
  exit 0
fi

# --- Session & Pane Setup ---
SESSION_NAME="tui_exec_$$"
STDOUT_FIFO="/tmp/tui_stdout_fifo_$$"
STDERR_FIFO="/tmp/tui_stderr_fifo_$$"

cleanup() {
  rm -f "$STDOUT_FIFO" "$STDERR_FIFO"
  tmux has-session -t "$SESSION_NAME" 2>/dev/null && tmux kill-session -t "$SESSION_NAME"
  echo:Info "Cleaned up resources."
}
trap cleanup EXIT INT TERM

mkfifo "$STDOUT_FIFO" "$STDERR_FIFO"

# --- Tmux Pane Layout ---
tmux new-session -d -s "$SESSION_NAME" -x 120 -y 40 "tail -f $STDOUT_FIFO"
tmux split-window -v -t "$SESSION_NAME:0.0" -p 30 "tail -f $STDERR_FIFO"
tmux select-pane -t "$SESSION_NAME:0.0"
tmux split-window -h -t "$SESSION_NAME:0.0" -p 50 "echo '${cl_bold}${cl_cyan}Running:${cl_reset} $SCRIPT_OR_CMD ${SCRIPT_ARGS[*]}' && sleep 2 && tail -f /dev/null"
tmux select-pane -t "$SESSION_NAME:0.0"
tmux select-layout -t "$SESSION_NAME" tiled

# --- Output Processing ---
awk_cmd='{ fflush(); print }'
if arguments::has --timestamp && arguments::has --line-number; then
  awk_cmd='{ printf("[%s] [%04d] %s\n", strftime("%Y-%m-%d %H:%M:%S"), NR, $0); fflush(); }'
elif arguments::has --timestamp; then
  awk_cmd='{ printf("[%s] %s\n", strftime("%Y-%m-%d %H:%M:%S"), $0); fflush(); }'
elif arguments::has --line-number; then
  awk_cmd='{ printf("[%04d] %s\n", NR, $0); fflush(); }'
fi

# --- Execution & Logging ---
echo:Tui "Starting execution in tmux session: $SESSION_NAME"
if [[ -f "$SCRIPT_OR_CMD" ]]; then
  ("$SCRIPT_OR_CMD" "${SCRIPT_ARGS[@]}" 2> >(awk "$awk_cmd" >"$STDERR_FIFO") | awk "$awk_cmd" >"$STDOUT_FIFO") &
else
  ($SCRIPT_OR_CMD "${SCRIPT_ARGS[@]}" 2> >(awk "$awk_cmd" >"$STDERR_FIFO") | awk "$awk_cmd" >"$STDOUT_FIFO") &
fi

# --- Attach to tmux ---
echo:Tui "Attaching to tmux session. Use 'exit' or Ctrl+B D to detach."
tmux attach-session -t "$SESSION_NAME"

echo:Success "Execution finished."
