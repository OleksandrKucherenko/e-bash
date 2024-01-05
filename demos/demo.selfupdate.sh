#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034,SC2059

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2024-01-02
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

#export DEBUG=git,version,loader

# include other scripts: _colors, _logger, _commons, _dependencies, _arguments
scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.scripts" && pwd)"
# shellcheck disable=SC1090 source=../.scripts/_self-update.sh
source "$scripts_dir/_self-update.sh"

# ask self-update to the version >= 1.0.0 && < 2.0.0
#self-update "^1.0.0"

# check for version update in range >= 1.0.0 && < 2.0.0
#self-update "^1.0.0" "${BASH_SOURCE[0]}" "$REPO_URL"

## Delete repo dir, to emulate first run
#rm -rf "${SELF_UPDATE_DIR}"
self-update:initialize

## extract first version
self-update:version:get:first

## extract last version
self-update:version:get:latest

## Find Highest Tag
echo "highest: $(self-update:version:find:highest_tag)"

## Find tag in constraints
echo "match: $(self-update:version:find "^1.0.0")"

## Get version of the script file
self-update:self:version "${BASH_SOURCE[0]}"
self-update:self:version "$scripts_dir/_colors.sh"
self-update:self:version "00-format.sh"

## Compute file hash
#self-update:file:hash "00-format.sh"
self-update:file:hash "$scripts_dir/_colors.sh"

## Compute file hash for a specific version
self-update:version:hash "$scripts_dir/_colors.sh" "v1.0.0"

## Assign/Bind file version
echo "bind 1.0.0"
self-update:version:bind "v1.0.0" "$scripts_dir/_colors.sh"

echo "bind 1.0.1-alpha.1"
self-update:version:bind "v1.0.1-alpha.1" "$scripts_dir/_colors.sh"

## Rollback file changes
echo "rollback to 1.0.0"
self-update:rollback:version "v1.0.0" "$scripts_dir/_colors.sh"
# expected: _colors.sh -> ~/.e-bash/.versions/v1.0.0/.scripts/_colors.sh
ls -la "$scripts_dir" | grep _colors

## Unlinking
echo "unlink"
self-update:unlink "$scripts_dir/_colors.sh"
ls -la "$scripts_dir" | grep _colors

echo "rollback to original"
# while exists backup files run rollback
while find "${scripts_dir}" -name "_colors.sh.~*~" | grep . >/dev/null; do
  self-update:rollback:backup "${scripts_dir}/_colors.sh"
done

## Unlinking, error state
self-update:unlink "$scripts_dir/_colors.sh"
