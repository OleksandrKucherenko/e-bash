#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-23
## Version: 1.12.6
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

## Hook: decide-cache.sh (exec mode)
## Purpose: Decide if compilation should be skipped based on cache

decision="Continue"
if [[ "${CI_FORCE_BUILD:-}" != "true" ]] && [[ -f ".build-cache" ]]; then
  echo "[ci-20] Build cache found, checking if rebuild needed..." >&2
  decision="Skip"
fi

echo "$decision"
