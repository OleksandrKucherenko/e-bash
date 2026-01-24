# _self-update

**Version:** 2.0.0



## Functions


### `compare:versions`

Description: Compares two semantic version strings to determine ordering.
             Used internally by array:qsort for version sorting.
Arguments:
  $1 - First version string (e.g., "1.0.0")
  $2 - Second version string (e.g., "2.0.0")
Returns:
  exit code: 0 if $1 < $2, 1 otherwise
Example:
  compare:versions "1.0.0" "2.0.0"  # returns 0 (true)
  compare:versions "2.0.0" "1.0.0"  # returns 1 (false)
###############################################################################


### `array:qsort`

Description: Generic quicksort implementation for sorting arrays using a
             custom comparison function. Recursively partitions array around
             pivot element. Used to sort version tags.
Arguments:
  $1 - Comparison function name (e.g., "compare:versions")
  $@ - Array elements to sort
Returns:
  stdout: Sorted array elements (one per line)
  exit code: 0 (always succeeds)
Example:
  sorted=($(array:qsort "compare:versions" "2.0.0" "1.0.0" "1.5.0"))
  # Result: ("1.0.0" "1.5.0" "2.0.0")
###############################################################################


### `path:resolve`

Description: Internal function that resolves a file path to its absolute path,
             trying multiple resolution strategies: absolute path, current
             working directory relative, caller script directory relative, and
             stack-based resolution. Emits debug output via echo:Version.
Arguments:
  $1 - File path to resolve (can be absolute, relative, or just filename)
  $2 - Working directory (optional, defaults to $PWD)
Returns:
  stdout: Absolute path to the file
  exit code: 0 if file found, 1 if file not found
Side Effects:
  - Emits debug messages to stderr via echo:Version
  - Changes directory temporarily during resolution
Example:
  full_path=$(path:resolve "./_colors.sh")
  full_path=$(path:resolve "bin/script.sh" "/home/user/project")
###############################################################################

