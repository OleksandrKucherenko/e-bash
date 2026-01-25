#!/usr/bin/env bash
# Fixture with @{keyword} hints for e-docs testing

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Version: 1.0.0
## License: MIT

##
## Public function visible in output
## @{since:v1.0.0}
##
function public_func() {
  echo "public"
}

##
## Internal function - should be skipped
## @{internal}
##
function internal_helper() {
  echo "internal"
}

##
## Deprecated function with message
## @{deprecated:Use new_func instead}
##
function old_func() {
  echo "deprecated"
}

##
## Module: Hint Test Module
##
## For testing @{keyword} hint system
##
