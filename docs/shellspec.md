## Troubles with tests

```bash
# filter ansi colors
no_colors_stdout() {
  local result=$(echo -n "$1" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g' | sed -E $'s/\x1B\\([A-Z]//g')
  echo -n "$result" | tr -s ' '
}

# with hex dump to detect unfiltered ANSI escape sequences
no_colors_stdout() {
  local result=$(echo -n "$1" | gsed -E 's/\x1B\[[0-9;]*[A-Za-z]//g')
  echo "$(echo -n "$result" | hexdump -C)" >&2
  echo -n "$result"
}

# Usage
The result of function no_colors_stdout should include "v1.0.0 [CURRENT] [LATEST]"

# Define a helper function to strip ANSI escape sequences
# $1 = stdout, $2 = stderr, $3 = exit status of the command
no_colors_stderr() { echo -n "$2" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g' | tr -s ' '; }
no_colors_stdout() { echo -n "$1" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g' | tr -s ' '; }

```