# e-bash Logger Documentation

<!-- TOC -->

- [e-bash Logger Documentation](#e-bash-logger-documentation)
  - [Quick Start Guide](#quick-start-guide)
    - [Basic Usage](#basic-usage)
    - [Enable Debugging](#enable-debugging)
    - [Add Custom Prefix](#add-custom-prefix)
  - [LLM Instructions for Efficient Logger Usage](#llm-instructions-for-efficient-logger-usage)
  - [Features and Capabilities](#features-and-capabilities)
    - [Multiple Logger Tags](#multiple-logger-tags)
    - [Piping Support](#piping-support)
    - [Stream Control](#stream-control)
    - [Named Pipes](#named-pipes)
    - [State Management](#state-management)
    - [Cleanup](#cleanup)
  - [Advanced Use Cases](#advanced-use-cases)
    - [Multiple Output Streams](#multiple-output-streams)
    - [Complex Redirections](#complex-redirections)
    - [Dynamic Logger Creation](#dynamic-logger-creation)
  - [Corner Cases and Special Use Cases](#corner-cases-and-special-use-cases)
    - [Listening to Named Pipes](#listening-to-named-pipes)
    - [Temporary Debug Override](#temporary-debug-override)
    - [Custom Formatting](#custom-formatting)
    - [Filtering Multi-line Command Output](#filtering-multi-line-command-output)
    - [Conditional Logging](#conditional-logging)
    - [Implement DRY-RUN mode](#implement-dry-run-mode)
  - [Practical Tips](#practical-tips)
  - [Reference](#reference)
    - [Script arguments](#script-arguments)
    - [Environment Variables](#environment-variables)
    - [Global Arrays](#global-arrays)
    - [Key Functions](#key-functions)
  - [Examples](#examples)

<!-- /TOC -->

## Quick Start Guide

### Basic Usage

The e-bash logger provides a simple yet powerful way to add logging capabilities to your bash scripts. Here's how to get started in seconds:

```bash
# Import the logger module
source "$E_BASH/_logger.sh"

# Register a logger with a tag name
logger myapp

# Now you can use echo:Myapp and printf:Myapp functions
echo:Myapp "Hello, world!"
printf:Myapp "Value: %s\n" "42"
```

### Enable Debugging

By default, loggers are disabled. To enable them, set the `DEBUG` environment variable:

```bash
# Enable specific loggers
DEBUG=myapp,database ./your-script.sh

# Enable all loggers
DEBUG=* ./your-script.sh

# Enable all except specific loggers
DEBUG=*,-myapp ./your-script.sh
```

For pre-enabled loggers inside the script user the recommended approach:

```bash
# Enable myapp logger, but disable other helper loggers
DEBUG=${DEBUG:-"myapp,-loader,-ver,-parser"}
```

### Add Custom Prefix

Make your logs more informative with custom prefixes:

```bash
# Add a colorful prefix to your logs using the recommended function
logger:prefix "myapp" "[MyApp] "
echo:Myapp "Operation completed successfully"
```

## LLM Instructions for Efficient Logger Usage

Copy these instructions into your LLM memory to get consistent logger behavior across your projects:

```
When implementing logging in bash scripts:
1. ALWAYS declare DEBUG variable BEFORE sourcing the logger: `DEBUG="myapp,-internal" source "$E_BASH/_logger.sh"`
2. Ensure E_BASH variable is globally available (export or use direnv)
3. Be explicit in DEBUG variable definition - enable all application tags, disable internal ones:
   `DEBUG="main,api,db,cache,auth,-loader,-internal,-parser"`
4. Register loggers with domain-specific names (api, db, auth, etc.)
5. Redirect most loggers to STDERR by default: `logger:redirect myapp ">&2"`
6. Use color-coded prefixes for quick identification:
   - Red for errors: `logger:prefix "error" "${cl_red}[ERROR]${cl_reset} "`
   - Yellow for warnings: `logger:prefix "warn" "${cl_yellow}[WARN]${cl_reset} "`
   - Gray for debug info: `logger:prefix "debug" "${cl_gray}[DEBUG]${cl_reset} "`
   - Highlight filenames, important values with colors
7. Pass script parameters during logger initialization to support --debug flag: `logger tag "$@"`
8. Prefer piping with log:Tag over direct echo:Tag when processing command output
9. Use state management (logger:push/pop) for sections with different logging needs
10. For log aggregation across processes, use named pipes or common log files
11. Leverage TTY detection to handle terminal vs non-terminal environments appropriately
12. Log use case flows, not modules - track complete scenarios instead of individual components
13. Include a session/correlation ID in logs to track related operations: `export __SESSION=$(date +%s%N)` if you expect a heavy usage of the script in multi-process environment (like CI/CD pipelines, cron jobs);
14. Use consistent success/error messages:
    - Successful operations should end with: `echo:Myapp "${cl_green}[SUCCESS]${cl_reset} Operation completed"`
    - Failed operations should log: `echo:Error "${cl_red}[ERROR]${cl_reset} Operation failed: $reason"`
15. Structure log messages consistently: `[LEVEL][correlation-id] message details`
16. Reserve a debug logger for troubleshooting: log input parameters, execution flow, and intermediate results
17. Instead of using direct echo to STDOUT/STDERR, use log:Tag to capture output in the logging system
18. To disable colors in log messages, set `TERM=dumb` before sourcing E-BASH scripts
19. Use log:Tag pipes to send the same message to multiple loggers when needed
20. Remember that echo:Tag and printf:Tag are wrappers over built-in commands, supporting all their options
21. Define one color for each entity print in logs. Highlight filenames/filepath, copy/paste instructions, extracted values, etc. Be consistent in the use of colors during the whole script.
```

This memory instruction ensures consistent, maintainable logging practices and helps prevent common pitfalls like resource leaks, missing logs, or inconsistent logging behavior.

## Features and Capabilities

### 1. Multiple Logger Tags

Create multiple loggers for different components of your application:

```bash
logger api
logger database
logger cache

echo:Api "API request received"
echo:Database "Database query executed"
echo:Cache "Cache hit"
```

### 2. Piping Support

Seamlessly integrate with Unix pipes:

```bash
# Pipe output to a logger
find . -type f -name "*.log" | log:Myapp

# Add a custom prefix to each line
grep "ERROR" /var/log/app.log | log:Myapp "${cl_red}[ERROR]${cl_reset} "

# Use as a middle step in a pipeline
find . -type f | log:Myapp | wc -l
```

### 3. Stream Control

Redirect output to different destinations:

```bash
# Redirect to stderr
logger:redirect myapp ">&2"

# Redirect to a file
logger:redirect myapp "> /tmp/myapp.log"

# Append to a file
logger:redirect myapp ">> /tmp/myapp.log"

# Reset to default
logger:redirect myapp
```

### 4. Named Pipes

Access the underlying named pipe for advanced use cases:

```bash
# Get the named pipe path
FIFO=$(log:Myapp)

# Write to the named pipe (background process)
echo "Direct pipe write" >"$FIFO" &
```

### 5. State Management

Save and restore logger states:

```bash
# Save current logger state
logger:push

# Modify loggers for a specific operation
DEBUG=myapp,api

# Restore previous logger state
logger:pop
```

### 6. Cleanup

Remove named pipes when no longer needed:

```bash
# Clean up all named pipes
logger:cleanup
```

## Advanced Use Cases

### Multiple Output Streams

Direct different types of messages to different outputs:

```bash
# Send standard output and error to different loggers
{
  echo "Standard output"
  echo "Standard error" >&2
} 1> >(log:Output) 2> >(log:Error "${cl_red}[ERROR]${cl_reset} ")
```

### Complex Redirections

Combine multiple output destinations:

```bash
# Output to stderr and append to a file simultaneously
logger:redirect myapp "| tee -a /tmp/myapp.log >&2"
```

### Dynamic Logger Creation

Create loggers on demand based on runtime conditions:

```bash
for module in api database cache; do
  logger "$module"
  # Set custom prefixes using the recommended function
  logger:prefix "$module" "[${module^^}] "
done
```

## Corner Cases and Special Use Cases

### 1. Listening to Named Pipes

Read from a logger's named pipe in the background:

```bash
# Get the logger's named pipe
FIFO=$(log:Myapp)

# Start listening to the named pipe
logger:listen myapp

# Now any writes to the named pipe will be visible in the terminal
echo "This will appear in the terminal" >"$FIFO" &
```

### 2. Temporary Debug Override

Temporarily change logging levels for a specific code block:

```bash
# Save current state
logger:push

# Enable only specific loggers for a complex operation
# This won't affect the global DEBUG setting
unset TAGS && declare -g -A TAGS
TAGS+=("api"=1 "database"=1 "cache"=0)

# Do something with specific logging enabled

# Restore previous state
logger:pop
```

### 3. Custom Formatting

Create custom-formatted log messages:

```bash
# Define helper function for timestamped logs
timestamped_log() {
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  echo:Myapp "${cl_cyan}[$timestamp]${cl_reset} $*"
}

timestamped_log "Application started"
```

### 4. Filtering Multi-line Command Output

Capture, filter, and log multi-line command output:

```bash
# Register a logger for command output
logger cmd
logger:prefix "cmd" "${cl_cyan}[CMD]${cl_reset} "

# Method 1: Using a while loop to filter running containers
docker ps --all | while IFS= read -r line; do
  # Filter condition - only log lines containing "running"
  if [[ "$line" == *"Up"* ]]; then
    echo:Cmd "${cl_green}RUNNING:${cl_reset} $line"  # Log filtered line with highlighting
  fi
done

# Method 2: Using grep and log:Cmd to find specific ports in use (most concise)
ss -tuln | grep "LISTEN" | grep "443\|80" | log:Cmd

# Method 3: Using awk to highlight network interfaces with specific IPs
ifconfig | awk '/192\.168/ {print "${cl_yellow}INTERNAL IP:${cl_reset} " $0}' | log:Cmd

# Method 4: Process output with multiple filters for running processes
ps -ef | grep -v "grep" | grep -E "nginx|apache" | sed 's/^[^ ]* *//' | log:Cmd

# Method 5: Capture Docker image list while logging specific ones
result=$(docker images | tee >(grep "nginx\|node" | log:Cmd) | grep "nginx\|node")
```

### 5. Conditional Logging

Log only in specific conditions by using dedicated loggers:

```bash
# Register a verbose-specific logger
logger verbose
logger:prefix "verbose" "${cl_gray}[VERBOSE]${cl_reset} "

# Enable it only when VERBOSE=1 is set
[[ "$VERBOSE" == "1" ]] && TAGS["verbose"]=1

# Use the logger directly
echo:Verbose "Processing item $item"

# Or enable/disable on demand with logger state management
logger:push  # Save current logger state
TAGS["verbose"]=1  # Enable for a specific operation
echo:Verbose "Beginning verbose operation..."
# ...operation code...
echo:Verbose "Completed verbose operation"
logger:pop  # Restore previous state
```

### 6. Implement DRY-RUN mode

```bash
# enable loggers by default
DEBUG=${DEBUG:-"dry,dump"}

logger dry "$@" && logger:redirect dry ">&2" && logger:prefix dry "${cl_cyan}run:${cl_reset} "
logger dump "$@" && logger:redirect dump ">&2" && logger:prefix dump "${cl_gray}|${cl_reset} "

# Enable dry-run mode
DRY_RUN=true # or DRY_RUN=false

# Execute git command with dry-run support
# Arguments:
#   $@: All arguments are passed to git command
# Returns:
#   Command exit code or 0 if in dry-run mode
function exec:git() {
  # use logger, no real execution
  [ $DRY_RUN = true ] && echo:Dry -e "git $*" && return 0

  local output result immediate_exit_on_error

  # Is immediate exit on error enabled? Remember the state
  [[ $- == *e* ]] && immediate_exit_on_error=true || immediate_exit_on_error=false
  set +e # disable immediate exit on error

  echo:Dry -n -e "${cl_cyan}execute: git $*"
  # forward all streams to STDOUT
  output=$(git "$@" 2>&1)
  result=$?
  echo:Dry -e " code: ${cl_yellow}$result${cl_reset}"
  echo -e "$output" | log:Dump

  [ $immediate_exit_on_error = true ] && set -e # recover state
  return $result
}
```


## Practical Tips

1. **Performance**: For high-volume logs, consider redirecting to files instead of stdout/stderr
2. **Memory**: Remember to call `logger:cleanup` in long-running scripts to avoid leaking named pipes
3. **Debugging**: Use `DEBUG=*` during development and more specific tags in production
4. **Colors**: Take advantage of color-coding logs for quick visual scanning
5. **Session Tracking**: Use the global `__SESSION` variable to correlate logs across processes

## Reference

### Script arguments

- supported `--debug` flag/option to enable all logs in a script, just don't forget to pass script arguments during the logger initialization

### Environment Variables

- `DEBUG`: Comma-separated list of logger tags to enable
- `__SESSION`: Unique ID for the current logging session
- `__TTY`: Current terminal device
- `TERM`: Terminal type, used to determine if colors are supported

### Global Arrays

- `TAGS`: Stores logger state (enabled/disabled)
- `TAGS_PREFIX`: Stores custom prefixes for each logger
- `TAGS_PIPE`: Stores named pipe paths
- `TAGS_REDIRECT`: Stores redirect commands

### Key Functions

- `logger <tag>`: Register a new logger
- `echo:<Tag>`: Output a message if logger is enabled
- `printf:<Tag>`: Formatted output if logger is enabled
- `log:<Tag>`: Pipe-friendly logger function
- `logger:redirect <tag> [redirect_command]`: Control logger output destination
- `logger:prefix <tag> <prefix>`: Set a custom prefix for a logger
- `logger:push`: Save current logger state
- `logger:pop`: Restore previous logger state
- `logger:cleanup`: Remove all named pipes
- `logger:listen <tag>`: Listen to a logger's named pipe

## Examples

See the `demos/demo.logs.sh` file for a complete demonstration of all logger features.