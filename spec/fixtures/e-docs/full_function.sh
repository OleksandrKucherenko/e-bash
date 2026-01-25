#!/usr/bin/env bash
# Full function fixture with all documentation sections

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Version: 1.0.0
## License: MIT

##
## Full function with all documentation sections
##
## Parameters:
## - arg1 - First argument, string, required
## - arg2 - Second argument, integer, default: 0
##
## Globals:
## - reads/listen: E_BASH, DEBUG
## - mutate/publish: RESULT
##
## Side effects:
## - Creates temporary file in /tmp
##
## Returns:
## - 0 on success, 1 on failure
## - Echoes result string
##
## Usage:
## - result=$(full_func "hello" 42)
##
function full_func() {
  local arg1=$1
  local arg2=${2:-0}
  RESULT="$arg1:$arg2"
  echo "$RESULT"
}

##
## Module: Test Module for e-docs
##
## A test module with full documentation structure.
##
## References:
## - demo: demo.test.sh
## - documentation: docs/public/test.md
##
## Categories:
##
## Core Functions:
## - full_func() - Full function with all sections
##
