#!/usr/bin/env bash
# Test file with empty/edge case functions

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Version: 1.0.0
## License: MIT

##
## Function with only documentation, no body
##
function empty_body_func() {
}

##
## Function with minimal documentation
##
function minimal_func() {
  :
}

##
## Function with complex nested commands
##
if [[ true ]]; then
  function conditional_func() {
    echo "conditional"
  fi
fi

##
## Function with multiple lines
##
function multi_line_func() {
  line1="first"
  line2="second"
  line3="third"
  echo "$line1$line2$line3"
}