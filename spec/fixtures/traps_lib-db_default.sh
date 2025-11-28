#!/usr/bin/env bash
# Library initialization guard

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-11-28
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

if [[ "${LIB_DB_TRAP_LOADED}" != "yes" ]]; then
  export LIB_DB_TRAP_LOADED="yes"
  export E_BASH="${E_BASH:-.scripts}"
  export DEBUG=""
  source "$E_BASH/_traps.sh" >/dev/null 2>&1

  db_cleanup() {
    echo "db_cleanup" >/dev/null
  }

  # Only register if not already registered
  if ! trap:list EXIT 2>>"$TRAP_TEST_STDERR" | grep -q "db_cleanup"; then
    trap:on db_cleanup EXIT
  fi
fi