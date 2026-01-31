#!/usr/bin/env bash
# Test file for edge cases

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Version: 1.0.0
## License: MIT

##
## Function with special characters in name
##
function func-with-dashes() {
  echo "dash function"
}

##
## Function with underscores
##
function func_with_underscores() {
  echo "underscore function"
}

##
## Function with numbers
##
function func_with_numbers123() {
  echo "number function"
}

##
## Function with very long name
##
function function_with_very_very_long_name_that_exceeds_normal_limits() {
  echo "long name function"
}

##
## Function with no parameters but has Returns
##
## Returns:
## - status code
## - output message
##
function func_returns_only() {
  local status=$1
  local message=$2
  echo "$message"
  return $status
}

##
## Function with complex documentation
##
## This function handles complex scenarios with multiple sections
##
## Parameters:
## - input_string - The input to process
## - options - Various options as flags
##
## Globals:
## - DEBUG - Enable debug output
##
## Side effects:
## - Modifies global OUTPUT variable
## - Creates temporary files
##
## Returns:
## - Processed string
## - Exit code
##
## Usage:
## - result=$(complex_func "hello" --verbose)
## - echo "$result"
##
## References:
## - docs/advanced.md
## - examples/complex.sh
##
function complex_function() {
  local input="$1"
  local options="$2"
  OUTPUT="$input (processed)"
  echo "$OUTPUT"
  return 0
}

##
## Empty module summary
##