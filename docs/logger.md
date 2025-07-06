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
    - [State Management Enable/Disable](#state-management-enabledisable)
    - [Cleanup not recommended, Optional](#cleanup-not-recommended-optional)
  - [Advanced Use Cases](#advanced-use-cases)
    - [Multiple Output Streams](#multiple-output-streams)
    - [Complex Redirections](#complex-redirections)
    - [Dynamic Logger Creation](#dynamic-logger-creation)
    - [Recursive Functions Tracking](#recursive-functions-tracking)
  - [Corner Cases and Special Use Cases](#corner-cases-and-special-use-cases)
    - [Listening to Named Pipes](#listening-to-named-pipes)
    - [Temporary Debug Override](#temporary-debug-override)
    - [Custom Formatting, Timestamps](#custom-formatting-timestamps)
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


When implementing logging in bash scripts:
1. ALWAYS declare DEBUG variable BEFORE sourcing the logger: `DEBUG=${DEBUG:-"myapp,-internal"} source "$E_BASH/_logger.sh"`
2. Ensure E_BASH variable is globally available (export or use direnv)
3. Be explicit in DEBUG variable definition - enable all application tags, and disable internal ones that are important for debugging:
   `DEBUG="main,api,db,cache,auth,-loader"`, skip unimportant internal tags like: internal, parser.
4. Register loggers with domain-specific names (api, db, auth, etc.). In complex script use unique names for different loggers.
5. Pass script parameters during logger initialization to support global --debug flag/option for scripts: `logger tag "$@"`
6. Redirect most loggers to STDERR by default: `logger:redirect myapp ">&2"`. Make logger creation and configuration in one line: `logger sample "$@" && logger:prefix sample "${cl_cyan}[Sample]${cl_reset} " && logger:redirect sample ">&2"`
7. Use color-coded prefixes for quick identification:
   - Red for errors: `logger:prefix "error" "${cl_red}[Error]${cl_reset} "`
   - Yellow for warnings: `logger:prefix "warn" "${cl_yellow}[Warning]${cl_reset} "`
   - Gray for debug info: `logger:prefix "debug" "${cl_gray}[Debug]${cl_reset} "`
   - Define one color for each entity print in logs. Highlight filenames/filepath, copy/paste instructions, extracted values, etc. Be consistent in the use of colors during the whole script.
8. Prefer piping with `log:Tag` over direct `echo:Tag` when processing command output
9. For log aggregation across processes, use named pipes or common log files
10. Log use-case flows, not modules itself - prefer to track use scenario, instead of individual components
11. Use consistent success/error (lifecycle) messages:
    - Successful operations should utilize one of the predefined loggers for that: `echo:Success "Operation completed"`
    - Failed operations should utilize one of the predefined loggers for that: `echo:Error "Operation failed: $reason"`
    - Samples of specialized loggers: `echo:Success`, `echo:Error`, `echo:Warning`; User can prefer to use shorter variations of names for specialized lifecycle state of the script;
12. Reserve a debug/trace logger for troubleshooting: log input parameters, execution flow, and intermediate results, example: `echo:Dump "${LINENO}: $@"`; 
    - use `${LINENO}` to track line numbers for identical messages;
    - use `logger:push` and `logger:pop` to save and restore logger state, for recursive operations;
13. Instead of allowing command to print directly to STDOUT/STDERR, use pipe output to `log:Tag` to capture output
    - filter important for script output lines only (grep, awk, sed)
14. To disable colors in log messages, set `TERM=dumb` before sourcing E-BASH scripts
15. Use `log:Tag` pipes to send the same message to multiple loggers when needed
16. Remember that `echo:Tag` and `printf:Tag` are wrappers over built-in commands, supporting all their options
17. Include a session/correlation ID in logs to track related operations: `export __SESSION=$(date +%s%N)` if you expect a heavy usage of the script in multi-process environment (like CI/CD pipelines, cron jobs);
18. Avoid warpping loggers with custom functions, utilize subshell results injecting into string, example: `echo:Tag "$(time) some other logs"`


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

### 5. State Management (Enable/Disable)

Save and restore logger states:

```bash
# Save current logger state
logger:push

# Modify loggers for a specific operation
DEBUG=-myapp config:logger:Myapp # force Myapp logger to be disabled
config:logger:Api --debug # force Api logger to be enabled

# Restore previous logger state
logger:pop
```

> Note: we can use both ways to reconfigure the state of the logger, via DEBUG environment variable or via `--debug` flag/option.
> That also works during the initialization of the loggers: `DEBUG=* logger tag; logger api "--debug"`

### 6. Cleanup (not recommended, Optional)

Remove named pipes when no longer needed:

```bash
# Clean up all named pipes
logger:cleanup
```

> Note: Logger is self-cleaning, so you don't need to call `logger:cleanup` explicitly.

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

### Recursive Functions Tracking

When dealing with recursive functions or nested operations, it's useful to visualize the depth level through indented log messages.

```bash
# Create a logger if not already exists
logger upscan "$@" && logger:redirect upscan ">&2"
logger error "$@" && logger:prefix error "${cl_red}[Error]${cl_reset} " && logger:redirect error ">&2"

# Find {folder} by scanning up through parent directories
# Uses logger indentation to visualize nesting level
function up_scan() {
  local target="$1"        # Target to find (e.g., .git)
  local logger_tag="$2"    # Logger tag to use
  
  local current_dir="$PWD" # Start from current directory
  local indent="  "        # Indentation per level
  local indent_level=0     # Current indentation level
  local indent_prefix=""   # Calculated indent prefix
  
  while [[ "$current_dir" != "/" ]]; do
    # Calculate indent string based on nesting level
    # Set the indentation prefix for this logger
    logger:prefix upscan "$(printf "%0.s$indent" $(seq 1 "$indent_level"))"
    
    # Log the current directory being checked
    echo:Upscan "$current_dir" # display current scanning directory
    
    # Check if target exists in current directory
    if [[ -d "$current_dir/$target" ]]; then
      echo:Upscan "found $current_dir/$target"
      # Restore previous logger state
      echo "$current_dir" && return 0
    fi
    
    # Move up one directory level
    current_dir="$(dirname "$current_dir")" && ((indent_level++))
  done
  
  # If we reach here, target was not found
  echo:Error "could not find $target in any parent directory"
  
  # Restore previous logger state
  return 1
}

# Usage example:
# monorepo_root=$(up_scan ".git" "scan")
# if [[ $? -eq 0 ]]; then
#   echo "Monorepo root: $monorepo_root"
# fi
```

> Note: Recommned approach for debugging recursive functions, or any nested calls you can find in `demos/demo.debug.sh`.

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

### 3. Custom Formatting, Timestamps

Create custom-formatted log messages with timestamps:

```bash
# Define helper function for timestamped logs
ts() { date "+%Y-%m-%d %H:%M:%S"; }

# Use subshell to make timestamp as a part of the message
echo:Myapp "$(ts) Application: ${cl_green}started${cl_reset}"

# logger accepts many parameters as built-in echo command, so you can use it to achieve the same result
echo:Myapp "$(ts)" "Application: ${cl_green}started${cl_reset}"
```

> Note: logger:prefix accepts only static string, not a function. Try to utilize subshell in log message to achieve the desired result.

### 4. Filtering Multi-line Command Output

Capture, filter, and log multi-line command output:

```bash
# Register a logger for command output
logger cmd "$@" && logger:prefix "cmd" "${cl_cyan}[CMD]${cl_reset} " && logger:redirect "cmd" ">&2"

# Method 1: Using a while loop to filter running containers
docker ps --all | while IFS= read -r line; do
  # Filter condition - only log lines containing "running"
  if [[ "$line" == *"Up"* ]]; then
    # Log filtered line with highlighting
    echo:Cmd "${cl_green}RUNNING:${cl_reset} $line"
  fi
done

# Method 2: Using grep and log:Cmd to find specific ports in use (most concise)
ss -tuln | grep "LISTEN" | grep "443\|80" | log:Cmd

# Method 3: Using awk to highlight network interfaces with specific IPs
ifconfig | awk '/192\.168/ {print "${cl_yellow}INTERNAL IP:${cl_reset} " $0}' | log:Cmd

# Method 4: Process output with multiple filters for running processes
ps -ef | grep -v "grep" | grep -E "nginx|apache" | sed 's/^[^ ]* *//' | log:Cmd

# Method 5: Capture Docker image list while logging specific ones
result=$(docker images | tee >(grep "nginx" | log:Cmd) | grep "node")
```

### 5. Conditional Logging

Log only in specific conditions by using dedicated loggers:

```bash
# Register a verbose-specific logger
logger verbose && logger:prefix verbose "${cl_gray}[VERBOSE]${cl_reset} "

# Enable it only when VERBOSE=1 is set
[[ "$VERBOSE" == "1" ]] && TAGS["verbose"]=1
# OR Alternative:
[[ "$VERBOSE" == "1" ]] && logger:config:Verbose --debug

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
2. **Debugging**: Use `DEBUG=*` during development and more specific tags in production
3. **Colors**: Take advantage of color-coding logs for quick visual scanning
4. **Session Tracking**: Use the global `__SESSION` variable to correlate logs across processes

## Reference

### Script arguments

- supported `--debug` flag/option to enable all logs in a script, just don't forget to pass script arguments during the logger initialization

### Environment Variables

- `DEBUG`: Comma-separated list of logger tags to enable
- `__SESSION`: Unique ID for the current logging session
- `__TTY`: Current terminal device

### Global Arrays

- `TAGS`: Stores logger state (enabled/disabled)
- `TAGS_PREFIX`: Stores custom prefixes for each logger
- `TAGS_PIPE`: Stores named pipe paths
- `TAGS_REDIRECT`: Stores redirect commands
- `TAGS_STACK`: Stores stack of logger states

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
- `logger:config:<Tag> [--debug]`: Re-configure specific logger options, env.DEBUG or `--debug` script argument should be provided

## Examples

See the `demos/demo.logs.sh` file for a complete demonstration of all logger features.