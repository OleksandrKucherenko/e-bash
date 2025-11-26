#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-11-26
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

export E_BASH="${E_BASH:-.scripts}"
export DEBUG=""
source "$E_BASH/_traps.sh" >/dev/null 2>&1

cleanup_a() {
  echo "cleanup_a" >/dev/null
}

trap:on cleanup_a EXIT