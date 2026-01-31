#!/usr/bin/env bash
# Fixture for trap function names with colons and underscores

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Version: 1.0.0
## License: MIT

##
## Test functions for anchor generation
##

function _Trap::capture_legacy() {
  echo "legacy trap capture"
}

function Trap::dispatch() {
  echo "trap dispatch"
}

function trap:scope:begin() {
  echo "scope begin"
}

function trap:on() {
  echo "register trap"
}

function _trapcontains() {
  echo "check if trap contains"
}