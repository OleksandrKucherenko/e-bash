# _dryrun

**Version:** 2.0.0

Dry-run wrapper system for safe command execution preview

## Functions


### `_dryrun:exec`


Description:
  Internal shared execution function used by generated wrapper functions.
  Executes a command, captures output and exit code, and logs execution details.

Arguments:
  $1 - logger_suffix (string) - Logger tag suffix (e.g., "Exec", "Undo")
  $2 - is_silent (boolean) - Whether to suppress output logging ("true"/"false")
  $3 - cmd (string) - Command to execute
  $@ - Additional arguments passed to the command

Returns:
  Exit code of the executed command

Side Effects:
  - Logs command execution to printf:{logger_suffix}
  - Logs command output to log:Output (unless silent)
  - Outputs command result to stdout (unless silent)
  - Temporarily disables 'set -e' during execution to capture exit codes

Example:
  _dryrun:exec Exec "false" git status
  # Logs: "git status / code: 0" and outputs git status result



### `dryrun`


Description:
  Generates dynamic wrapper functions for commands with dry-run/undo capabilities.
  Creates run:{cmd}, dry:{cmd}, rollback:{cmd}, and undo:{cmd} functions that respect
  DRY_RUN, UNDO_RUN, and SILENT environment variables (global or command-specific).

Arguments:
  $1 - cmd (string) - Command name to wrap (e.g., "git", "docker", "kubectl")
  $2 - suffix (string, optional) - Custom suffix for environment variables (defaults to uppercase cmd)

Returns:
  None (defines functions in current shell)

Side Effects:
  - Dynamically creates run:{cmd}() function (executes unless UNDO_RUN=true)
  - Dynamically creates dry:{cmd}() function (dry-run when DRY_RUN=true or UNDO_RUN=true)
  - Dynamically creates rollback:{cmd}() and undo:{cmd}() functions (executes only when UNDO_RUN=true)
  - Each function respects DRY_RUN_{SUFFIX}, UNDO_RUN_{SUFFIX}, SILENT_{SUFFIX} variables

Example:
  # Generate wrappers for git command
  dryrun git

  # Use the generated functions
  dry:git status              # Executes git status normally
  DRY_RUN=true dry:git commit # Logs "dry run: git commit" without executing

  # Generate with custom suffix
  dryrun docker DOCK
  DRY_RUN_DOCK=true dry:docker ps  # Uses DRY_RUN_DOCK instead of DRY_RUN_DOCKER



### `undo:func`


Description:
  Executes or simulates undo operations for bash functions (not external commands).
  In undo mode (UNDO_RUN=true and DRY_RUN=false), executes the function.
  Otherwise, logs the function body for inspection without executing.

Arguments:
  $1 - func_name (string) - Name of the bash function to execute in undo mode
  $@ - Additional arguments passed to the function

Returns:
  Exit code 0 when in dry mode, or the function's exit code when executed

Side Effects:
  - In dry/preview mode: Logs function name and displays function body
  - In undo mode: Executes the function with provided arguments
  - Respects global DRY_RUN, UNDO_RUN, and SILENT variables

Example:
  function cleanup_files() { rm -rf /tmp/myapp/*; }

  # Preview what would be undone
  undo:func cleanup_files
  # Output: "(dry-func): cleanup_files"
  #         "    rm -rf /tmp/myapp/*"

  # Execute undo
  UNDO_RUN=true undo:func cleanup_files
  # Executes the cleanup_files function



### `rollback:func`


Description:
  Backward compatibility alias for undo:func() function.
  Provided for scripts using the rollback naming convention.

Arguments:
  $@ - All arguments are passed through to undo:func()

Returns:
  Returns value from undo:func()

Example:
  rollback:func cleanup_files  # Same as: undo:func cleanup_files


