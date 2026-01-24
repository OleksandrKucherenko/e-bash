# _logger

**Version:** 2.0.0



## Functions


### `logger:compose`

Description: Internal function generator that creates echo:Tag and printf:Tag
             functions for a specific logger tag. These functions only output
             when the tag is enabled in the TAGS array and respect custom
             prefixes and redirections.
Arguments:
  $1 (tag)    - Logger tag name (lowercase, e.g., "myapp")
  $2 (suffix) - Function suffix (capitalized, e.g., "Myapp")
  $3 (flags)  - Optional flags for future use (currently unused)
Returns:
  stdout: Shell code defining echo:${suffix} and printf:${suffix} functions
  exit code: 0 (always succeeds)
Side Effects:
  - Generates code that references TAGS, TAGS_PREFIX, and TAGS_REDIRECT arrays
  - Generated functions use builtin echo/printf for performance
Example:
  eval "$(logger:compose "myapp" "Myapp")"
  # Creates: echo:Myapp and printf:Myapp functions
###############################################################################


### `logger:compose:helpers`

Description: Internal function generator that creates config:logger:Tag and
             log:Tag helper functions. config:logger:Tag handles tag enabling
             based on DEBUG variable and --debug flag. log:Tag supports both
             piping and direct logging modes.
Arguments:
  $1 (tag)    - Logger tag name (lowercase, e.g., "myapp")
  $2 (suffix) - Function suffix (capitalized, e.g., "Myapp")
  $3 (flags)  - Optional flags for future use (currently unused)
Returns:
  stdout: Shell code defining config:logger:${suffix} and log:${suffix}
  exit code: 0 (always succeeds)
Side Effects:
  - config:logger:Tag modifies TAGS array based on DEBUG and --debug
  - log:Tag reads from stdin with timeout or returns named pipe path
  - Generated functions reference TAGS and TAGS_PIPE arrays
Example:
  eval "$(logger:compose:helpers "myapp" "Myapp")"
  # Creates: config:logger:Myapp and log:Myapp functions
  find . -name "*.sh" | log:Myapp  # Pipe mode
  FIFO=$(log:Myapp)                # Get named pipe path
###############################################################################


### `pipe:killer:compose`

Description: Internal function that generates cleanup script for named pipes.
             Creates a background process that monitors the parent process and
             automatically removes the named pipe when the parent exits or is
             killed. Ensures proper cleanup without manual intervention.
Arguments:
  $1 (pipe)  - Full path to the named pipe to monitor and cleanup
  $2 (myPid) - PID of parent process to monitor (defaults to ${BASHPID})
Returns:
  stdout: Shell code for background cleanup process
  exit code: 0 (always succeeds)
Side Effects:
  - Generated code sets up traps for multiple signals
  - Removes named pipe on parent process exit
  - Runs as background process polling every 0.1 seconds
Example:
  bash <(pipe:killer:compose "/tmp/pipe.123" "$$") &
  # Background process monitors PID $$ and cleans up pipe on exit
###############################################################################


### `logger`

Description: PUBLIC API - Main entry point for logger system. Registers a new
             logger tag and creates associated functions (echo:Tag, printf:Tag,
             log:Tag, config:logger:Tag). Enables/disables based on DEBUG
             environment variable and --debug flag. Creates named pipe for
             advanced IPC scenarios.
Arguments:
  $1 (tag)       - Logger tag name (lowercase, e.g., "myapp", "api", "db")
  $@ (remaining) - Additional arguments passed to config:logger:Tag
                   Supports: --debug to force enable this logger
Returns:
  exit code: 0 (always succeeds, even if logger exists)
Side Effects:
  - Creates echo:Tag, printf:Tag, log:Tag, config:logger:Tag functions
  - Adds entry to TAGS array (disabled by default, enabled via DEBUG)
  - Creates named pipe at /tmp/_logger.${Tag}.${__SESSION}
  - Starts background process to cleanup pipe on parent exit
  - Logs registration to echo:Common (if common logger exists)
Example:
  logger myapp "$@"
  DEBUG=myapp ./script.sh
  echo:Myapp "This only prints if DEBUG=myapp"

  logger api --debug  # Force enable
  echo:Api "Always prints"

  DEBUG=* logger db   # Enable all including db
  DEBUG=*,-internal logger internal  # Enable all except internal
###############################################################################


### `logger:push`

Description: PUBLIC API - Saves the current state of all logger tags to a
             stack. Useful for temporarily modifying logger states and then
             restoring them. Enables nested state management for complex
             operations or recursive functions.
Arguments:
  None
Returns:
  exit code: 0 (always succeeds)
Side Effects:
  - Increments TAGS_STACK counter
  - Creates new global associative array __TAGS_STACK_N
  - Copies all TAGS array entries to stack
Example:
  logger:push  # Save current logger states
  TAGS["debug"]=1  # Enable debug logger temporarily
  echo:Debug "This will print"
  logger:pop  # Restore previous logger states

  # Nested state management
  logger:push
    TAGS["verbose"]=1
    logger:push
      TAGS["trace"]=1
    logger:pop  # Restore to verbose only
  logger:pop  # Restore to original state
###############################################################################
bashsupport disable=BP2001


### `logger:pop`

Description: PUBLIC API - Restores the previous state of logger tags from the
             stack. Must be paired with logger:push. Replaces current TAGS
             array with the most recently saved state and cleans up the stack
             entry.
Arguments:
  None
Returns:
  exit code: 0 (always succeeds, even if stack is empty)
Side Effects:
  - Decrements TAGS_STACK counter
  - Clears current TAGS array
  - Restores TAGS from __TAGS_STACK_N array
  - Removes __TAGS_STACK_N array from memory
Example:
  logger:push
  TAGS["api"]=1
  TAGS["db"]=0
  echo:Api "Temporarily enabled"
  logger:pop  # Restore previous TAGS state

  # Error handling with state restoration
  logger:push
  if complex_operation; then
    logger:pop
  else
    logger:pop
    return 1
  fi
###############################################################################


### `logger:cleanup`

Description: PUBLIC API - Manually removes all named pipes created by loggers
             and clears the TAGS_PIPE array. Normally not needed as pipes are
             auto-cleaned by background killer processes, but useful for
             explicit cleanup or troubleshooting.
Arguments:
  None
Returns:
  exit code: 0 (always succeeds)
Side Effects:
  - Removes all named pipe files in TAGS_PIPE array
  - Clears TAGS_PIPE array
  - Pipe killer background processes become orphaned (harmless)
Example:
  logger:cleanup  # Remove all logger pipes

  # Explicit cleanup before exit
  trap logger:cleanup EXIT

  # Troubleshooting: remove stale pipes
  logger:cleanup
  logger myapp  # Recreates pipe with fresh state
###############################################################################


### `logger:listen`

Description: PUBLIC API - Starts a background process that reads from a
             logger's named pipe and outputs to the current TTY. Useful for
             monitoring inter-process communication or displaying async log
             messages in real-time.
Arguments:
  $1 (tag) - Logger tag name whose named pipe to listen to
Returns:
  exit code: 0 (always succeeds)
Side Effects:
  - Starts background cat process reading from TAGS_PIPE[$tag]
  - Output goes to current TTY (/dev/tty)
  - Process runs until pipe is closed or parent exits
Example:
  logger myapp
  logger:listen myapp &  # Listen in background
  FIFO=$(log:Myapp)
  echo "Message from another process" >"$FIFO" &
  # Output appears in current terminal

  # Monitor async operations
  logger:listen api
  background_api_calls &  # Writes to named pipe
###############################################################################


### `logger:redirect`

Description: PUBLIC API - Changes output destination for a logger by setting
             redirect command and regenerating echo:Tag/printf:Tag functions.
             Supports stdout, stderr, files, pipes, and complex redirections.
Arguments:
  $1 (tag)      - Logger tag name to redirect
  $2 (redirect) - Redirect command (e.g., ">&2", "> file", "| tee file >&2")
                  Empty string resets to default (no redirect)
Returns:
  exit code: 0 (always succeeds)
Side Effects:
  - Updates TAGS_REDIRECT[$tag] with redirect command
  - Regenerates echo:Tag and printf:Tag functions
  - Does not affect log:Tag function
Example:
  logger:redirect myapp ">&2"  # Send to stderr
  logger:redirect myapp "> /tmp/app.log"  # Write to file
  logger:redirect myapp ">> /tmp/app.log"  # Append to file
  logger:redirect myapp "| tee -a /tmp/app.log >&2"  # Both file and stderr
  logger:redirect myapp  # Reset to default

  # Dynamic redirect based on environment
  [[ "$CI" == "true" ]] && logger:redirect api "> /dev/null"
###############################################################################


### `logger:prefix`

Description: PUBLIC API - Sets or removes a custom prefix that appears before
             all log messages for a specific logger tag. Prefixes are applied
             by echo:Tag and printf:Tag functions. Supports color codes and
             any string content.
Arguments:
  $1 (tag)    - Logger tag name to set prefix for
  $2 (prefix) - Prefix string to prepend to all messages
                Empty string removes the prefix
Returns:
  exit code: 0 (always succeeds)
Side Effects:
  - Updates TAGS_PREFIX[$tag] with prefix string
  - Removes TAGS_PREFIX[$tag] entry if prefix is empty
  - Prefix applies immediately to all subsequent logs
  - Does not regenerate logger functions (prefix stored in array)
Example:
  logger:prefix myapp "[MyApp] "
  echo:Myapp "Started"  # Output: [MyApp] Started

  # Color-coded prefixes
  logger:prefix error "${cl_red}[ERROR]${cl_reset} "
  logger:prefix warn "${cl_yellow}[WARN]${cl_reset} "
  logger:prefix info "${cl_blue}[INFO]${cl_reset} "

  # Dynamic prefix with timestamp (use subshell in message instead)
  logger:prefix api "[API] "
  echo:Api "$(date +%H:%M:%S) Request received"

  # Remove prefix
  logger:prefix myapp ""  # No prefix
###############################################################################


### `logger:init`

Description: PUBLIC API - Convenience function that combines logger creation,
             prefix setup, and redirect configuration in one call. Default
             behavior creates a logger with [tag] prefix sent to stderr,
             which is the most common pattern.
Arguments:
  $1 (tag)      - Logger tag name to initialize
  $2 (prefix)   - Custom prefix (default: "[${tag}] ")
  $3 (redirect) - Redirect command (default: ">&2")
Returns:
  exit code: 0 if all operations succeed
Side Effects:
  - Creates logger with all associated functions
  - Sets TAGS_PREFIX[$tag] to specified prefix
  - Sets TAGS_REDIRECT[$tag] to specified redirect
  - Regenerates logger functions with redirect
Example:
  # Standard initialization (stderr with [tag] prefix)
  logger:init myapp
  echo:Myapp "Error occurred"  # stderr: [myapp] Error occurred

  # Custom prefix, stderr output
  logger:init api "${cl_blue}[API]${cl_reset} "
  echo:Api "Request received"  # stderr: [API] Request received

  # Custom prefix and redirect to file
  logger:init audit "[AUDIT] " ">> /var/log/audit.log"
  echo:Audit "User login"  # appends: [AUDIT] User login

  # Initialize multiple loggers with common pattern
  for tag in error warn info debug; do
    logger:init "$tag" "[$tag] " ">&2"
  done
###############################################################################

