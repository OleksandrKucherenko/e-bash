#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034,SC2059

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2024-01-02
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# include other scripts: _colors, _logger, _commons, _dependencies, _arguments
scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../.scripts"
# shellcheck disable=SC1090 source=../.scripts/_self-update.sh
source "$scripts_dir/_self-update.sh"

# ask self-update to the version >= 1.0.0 && < 2.0.0
#self-update "^1.0.0"

#rm -rf "${SELF_UPDATE_DIR}"
self-update:initialize

## extract first version
self-update:version:get:first

## extract last version
self-update:version:get:latest

## Find Highest Tag
echo -n "highest: " && self-update:version:find:highest_tag

## Find tag in constraints
echo -n "match: " && self-update:version:find "^1.0.0"

# check for version update in range >= 1.0.0 && < 2.0.0
#self-update "^1.0.0" "${BASH_SOURCE[0]}" "$REPO_URL"

## Get version of the script file
self-update:self:version "${BASH_SOURCE[0]}"
self-update:self:version "$scripts_dir/_colors.sh"
self-update:self:version "00-format.sh"

## Compute file hash
self-update:self:hash "00-format.sh"
self-update:self:hash "$scripts_dir/_colors.sh"

#self-update:rollback:backup "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_colors.sh"
