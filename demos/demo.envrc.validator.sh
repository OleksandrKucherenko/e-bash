#!/usr/bin/env bash
# shellcheck disable=SC2034

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2024-01-02
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


function cleanup() {
  popd &>/dev/null || exit 1
}

trap cleanup EXIT SIGINT SIGTERM


trap

# change the CWD to the demos directory, so we work with the demo .envrc file
pushd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" &>/dev/null || exit 1

# shellcheck disable=SC1090 source=../bin/qa_validate_envrc.sh
source "../bin/qa_validate_envrc.sh"

