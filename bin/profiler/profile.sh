#!/bin/bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-26
## Version: 1.14.1
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

tm=$(date +%Y_%m_%d_%H_%M_%S)

# execute tracing
PS4='+ $(echo -n "$EPOCHREALTIME [$LINENO]: ")' bash -x "$@" 2>"trace.$tm.log" 1>/dev/null
# finalize the tracing
echo "+ $(gdate "+%s.%N") [0]: tracing done!" >>trace.log

# publish the results, in file remove all colors
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tracing.sh" <"./trace.$tm.log" |
    tee >(sed -r 's/\x1B\[(;?[0-9]{1,3})+[mGK]//g' >"./trace.$tm.final.log")
