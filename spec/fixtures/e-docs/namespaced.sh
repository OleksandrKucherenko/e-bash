#!/usr/bin/env bash
# Fixture with namespaced function names

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Version: 1.0.0
## License: MIT

##
## Namespaced function with colons in name
##
## Parameters:
## - tag - Logger tag name, string, required
##
function logger:init() {
  local tag=$1
  echo "init: $tag"
}

##
## Another namespaced function
##
## Parameters:
## - prefix - Prefix string, string, default: ""
##
function logger:prefix() {
  local prefix=${1:-""}
  echo "prefix: $prefix"
}
