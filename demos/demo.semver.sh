#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-10
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

DEBUG=${DEBUG:-"loader,semver,-regex,-simple"}

# shellcheck disable=SC2155 # evaluate E_BASH from project structure if it's not set
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../.scripts && pwd)"

# include other scripts: _colors, _logger, _commons, _dependencies, _arguments
# shellcheck disable=SC1090 source=../.scripts/_semver.sh
source "$E_BASH/_semver.sh"

## constraints Expressions
echo "-- constraints expressions"
semver:constraints "1.0.0-alpha" "1.0.0-alpha" && echo "OK!" || echo "$? - FAIL!"                # EQUAL
semver:constraints "1.0.0-alpha" ">1.0.0-beta || <1.0.0" && echo "$? - OK!" || echo "$? - FAIL!" # expected OK
semver:constraints "1.0.0-beta.10" "~1.0.0-beta.2" && echo "OK!" || echo "$? - FAIL!"
semver:constraints "1.0.0-beta.10" "^1.0.0-beta.2" && echo "OK!" || echo "$? - FAIL!"
semver:constraints "1.0.0-alpha" "~1.0.0-beta.2 || ^1.0.0-alpha.beta || > 1.0.0-beta < 1.0.0 || 1.0.0-alpha < 1.0.0-alpha.1" && echo "OK!" || echo "$? - FAIL!"
semver:constraints "1.0.0-alpha" ">1.0.0-beta <1.0.0" && echo "$? - FAIL!" || echo "OK ($?)!"

## 1.0.0 < 2.0.0 < 2.1.0 < 2.1.1, 1.0.0-alpha < 1.0.0
echo "-- compare version in readable format"
semver:compare:readable "1.0.0" "2.0.0"
semver:compare:readable "2.0.0" "2.1.0"
semver:compare:readable "2.1.0" "2.1.1"
semver:compare:readable "1.0.0-alpha" "1.0.0"
semver:compare:readable "3.0.0" "1.0.0"

## Example: 1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-alpha.beta < 1.0.0-beta < 1.0.0-beta.2 < 1.0.0-beta.11 < 1.0.0-rc.1 < 1.0.0.
## 1.0.0-beta.10 > 1.0.0-beta.2
semver:compare:readable "1.0.0-alpha" "1.0.0-alpha"
semver:compare:readable "1.0.0-alpha" "1.0.0-alpha.1"
semver:compare:readable "1.0.0-alpha.1" "1.0.0-alpha.beta"
semver:compare:readable "1.0.0-alpha.beta" "1.0.0-beta"
semver:compare:readable "1.0.0-beta" "1.0.0-beta.2"
semver:compare:readable "1.0.0-beta.2" "1.0.0-beta.11"
semver:compare:readable "1.0.0-beta.11" "1.0.0-rc.1"
semver:compare:readable "1.0.0-rc.1" "1.0.0"
semver:compare:readable "1.0.0-beta.10" "1.0.0-beta.2"

## constraints Complex
echo "-- constraints complex"
semver:constraints:complex "~1.0.0-beta.2" && echo "" || echo "$? - FAIL!"
semver:constraints:complex "^1.0.0-alpha.beta" && echo "" || echo "$? - FAIL!"

## constraints Simple
echo "-- constraints simple"
semver:constraints:simple "1.0.0-alpha = 1.0.0-alpha" && echo "OK!" || echo "$? - FAIL!"
semver:constraints:simple "1.0.0-alpha < 1.0.0-alpha.1" && echo "OK!" || echo "$? - FAIL!"
semver:constraints:simple "1.0.0-alpha <= 1.0.0-alpha.1" && echo "OK!" || echo "$? - FAIL!"
semver:constraints:simple "1.0.0-beta.10 > 1.0.0-beta.2" && echo "OK!" || echo "$? - FAIL!"
semver:constraints:simple "1.0.0-beta.10 >= 1.0.0-beta.2" && echo "OK!" || echo "$? - FAIL!"
semver:constraints:simple "1.0.0-beta.10 != 1.0.0-beta.2" && echo "OK!" || echo "$? - FAIL!"

## Parse And Recompose
echo "-- parse and recompose"
semver:parse "1.0.0-alpha" && echo "${__semver_parse_result[@]}"
semver:parse "1.0.0-alpha0.valid" "VER_1" && echo "${VER_1[@]}"
semver:parse "2.0.0-rc.1+build.123" "V" && echo "${V[@]}"
semver:parse "1.0.0+0.build.1-rc.10000aaa-kk-0.1" && echo "${__semver_parse_result[@]}"

## Demo common cases
echo "-- parse parts"
semver:parse "2.0.0-rc.1+build.123" "V" && for i in "${!V[@]}"; do echo -n "$i: ${V[$i]}, "; done && semver:recompose "V" && unset V
semver:parse "2.2.3-rc.1" "V" && for i in "${!V[@]}"; do echo -n "$i: ${V[$i]}, "; done && semver:recompose "V" && unset V
semver:parse "2.2.3-1" "V" && for i in "${!V[@]}"; do echo -n "$i: ${V[$i]}, "; done && semver:recompose "V" && unset V
semver:parse "2.2.3-1.2.3.4.5.6" "V" && for i in "${!V[@]}"; do echo -n "$i: ${V[$i]}, "; done && semver:recompose "V" && unset V
semver:parse "2.2.3-rc+1" "V" && for i in "${!V[@]}"; do echo -n "$i: ${V[$i]}, "; done && semver:recompose "V" && unset V
semver:parse "2.2.3+1" "V" && for i in "${!V[@]}"; do echo -n "$i: ${V[$i]}, "; done && semver:recompose "V" && unset V
semver:parse "2.2.3+1.2.3.4.5.6" "V" && for i in "${!V[@]}"; do echo -n "$i: ${V[$i]}, "; done && semver:recompose "V" && unset V
semver:parse "2.2.3" "V" && for i in "${!V[@]}"; do echo -n "$i: ${V[$i]}, "; done && semver:recompose "V" && unset V

semver:parse "2.0.0-rc.1.12.yy.14+build.123.xz.12" "V" && for i in "${!V[@]}"; do echo -n "$i: ${V[$i]}, "; done && semver:recompose "V" && unset V

# not valid
semver:parse "2.2" "V" && for i in "${!V[@]}"; do echo -n "$i: ${V[$i]}, "; done && semver:recompose "V" && unset V

# parsed by cannot be recomposed! (corner cases)
echo "-- parsed by cannot be recomposed! (corner cases)"
semver:parse "2.2.1-.1" "V" && for i in "${!V[@]}"; do echo -n "$i: ${V[$i]}, "; done && semver:recompose "V" && unset V
semver:parse "2.2.1+.4" "V" && for i in "${!V[@]}"; do echo -n "$i: ${V[$i]}, "; done && semver:recompose "V" && unset V
semver:parse "2.2.1-.3+.4" "V" && for i in "${!V[@]}"; do echo -n "$i: ${V[$i]}, "; done && semver:recompose "V" && unset V

## Valid
#echo "0.0.4" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.2.3" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "10.20.30" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.1.2-prerelease+meta" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.1.2+meta" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.1.2+meta-valid" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.0.0-alpha" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.0.0-beta" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.0.0-alpha.beta" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.0.0-alpha.beta.1" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.0.0-alpha.1" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.0.0-alpha0.valid" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.0.0-alpha.0valid" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.0.0-alpha-a.b-c-somethinglong+build.1-aef.1-its-okay" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.0.0-rc.1+build.1" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "2.0.0-rc.1+build.123" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.2.3-beta" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "10.2.3-DEV-SNAPSHOT" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.2.3-SNAPSHOT-123" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.0.0" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "2.0.0" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.1.7" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "2.0.0+build.1848" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "2.0.1-alpha.1227" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.0.0-alpha+beta" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.2.3----RC-SNAPSHOT.12.9.1--.12+788" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.2.3----R-S.12.9.1--.12+meta" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.2.3----RC-SNAPSHOT.12.9.1--.12" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.0.0+0.build.1-rc.10000aaa-kk-0.1" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "99999999999999999999999.999999999999999999.99999999999999999" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.0.0-0A.is.legal" | grep -E "${SEMVER_LINE}" --color=always --ignore-case

## Invalid
#echo "1" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.2" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.2.3-0123" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.2.3-0123.0123" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.1.2+.123" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "+invalid" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "-invalid" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "-invalid+invalid" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "-invalid.01" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "alpha" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "alpha.beta" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "alpha.beta.1" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "alpha.1" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "alpha+beta" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "alpha_beta" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "alpha." | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "alpha.." | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "beta" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.0.0-alpha_beta" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "-alpha." | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.0.0-alpha.." | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.0.0-alpha..1" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.0.0-alpha...1" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.0.0-alpha....1" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.0.0-alpha.....1" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.0.0-alpha......1" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.0.0-alpha.......1" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "01.1.1" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.01.1" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.1.01" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.2" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.2.3.DEV" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.2-SNAPSHOT" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.2.31.2.3----RC-SNAPSHOT.12.09.1--..12+788" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.2-RC-SNAPSHOT" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "-1.0.3-gamma+b7718" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "+justmeta" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "9.8.7+meta+meta" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "9.8.7-whatever+meta+meta" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "99999999999999999999999.999999999999999999.99999999999999999----RC-SNAPSHOT.12.09.1--------------------------------..12" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
