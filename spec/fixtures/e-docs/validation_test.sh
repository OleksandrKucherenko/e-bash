#!/usr/bin/env bash
# Test file for validation functions

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Version: 1.0.0
## License: MIT

##
## Function with invalid parameter section (Paramters typo)
##
## Paramters:
## - bad_param - This has a typo in "Parameters"
##
function func_with_typo() {
  echo "test"
}

##
## Function missing description
##
## Parameters:
## - param1 - Some parameter
##
function func_missing_desc() {
  echo "test"
}

##
## Function with valid documentation
##
## This is a proper description
##
## Parameters:
## - param1 - First parameter
## - param2 - Second parameter
##
## Returns:
## - 0 on success
##
function func_with_valid_docs() {
  echo "test"
}

##
## Function with deprecated hint
## @{deprecated:Use new_function instead}
##
function func_deprecated() {
  echo "old function"
}

##
## Function with internal hint
## @{internal}
##
function func_internal() {
  echo "internal implementation"
}