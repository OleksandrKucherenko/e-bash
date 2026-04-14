#!/usr/bin/env bash
# shell: bash altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-04-14
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# Stress test corpus for _arguments.sh parser.
#
# Each test is a combination of ARGS_DEFINITION + CLI arguments.
# For features not natively supported, workarounds via ARGS_DEFINITION
# patterns are shown. Only genuinely impossible cases use xIt.
#
# Workaround patterns:
#   --flag/--no-flag  -> two definitions mapping to same variable with different defaults
#   list accumulation -> user-side post-processing (parser extracts last value correctly)
#   -- end-of-options -> not supported (parser has no sentinel detection)
#   -abc bundling     -> not supported (parser doesn't decompose single-char bundles)
#   -vvv counters     -> not supported (parser doesn't count repeated chars)
#   -ovalue attached  -> not supported (parser needs whitespace: -o value)

eval "$(shellspec - -c) exit 1"

Describe '_arguments.sh stress tests /'
  BeforeRun 'export DEBUG="*"'
  Include ".scripts/_arguments.sh"

  # Suppress all logger output
  Mock echo:Common
    :
  End
  Mock echo:Parser
    :
  End
  Mock printf:Common
    :
  End
  Mock printf:Parser
    :
  End

  # ============================================================
  # 1) Basic forms
  # ============================================================
  Describe '1) Basic forms /'

    It '#1 --key=value'
      preserve() { %preserve key:KEY; }
      BeforeCall 'export ARGS_DEFINITION="--key=key::1"'
      AfterCall preserve
      When call parse:arguments --key=value
      The variable KEY should eq 'value'
    End

    It '#2 --key value'
      preserve() { %preserve key:KEY; }
      BeforeCall 'export ARGS_DEFINITION="--key=key::1"'
      AfterCall preserve
      When call parse:arguments --key value
      The variable KEY should eq 'value'
    End

    It '#3 --flag (boolean)'
      preserve() { %preserve flag:FLAG; }
      BeforeCall 'export ARGS_DEFINITION="--flag"'
      AfterCall preserve
      When call parse:arguments --flag
      The variable FLAG should eq '1'
    End

    It '#4 --no-flag -> flag=false (workaround: two defs, same variable)'
      # Pattern: --flag sets flag=true, --no-flag sets flag=false
      preserve() { %preserve flag:FLAG; }
      BeforeCall 'export ARGS_DEFINITION="--flag=flag:true --no-flag=flag:false"'
      AfterCall preserve
      When call parse:arguments --no-flag
      The variable FLAG should eq 'false'
    End

    It '#5 -v -> verbose=1 (workaround: separate defs for -v, -vv, -vvv)'
      preserve() { %preserve verbose:V; }
      BeforeCall 'export ARGS_DEFINITION="-v=verbose:1 -vv=verbose:2 -vvv=verbose:3"'
      AfterCall preserve
      When call parse:arguments -v
      The variable V should eq '1'
    End

    It '#6 -vv -> verbose=2'
      preserve() { %preserve verbose:V; }
      BeforeCall 'export ARGS_DEFINITION="-v=verbose:1 -vv=verbose:2 -vvv=verbose:3"'
      AfterCall preserve
      When call parse:arguments -vv
      The variable V should eq '2'
    End

    It '#7 -vvv -> verbose=3'
      preserve() { %preserve verbose:V; }
      BeforeCall 'export ARGS_DEFINITION="-v=verbose:1 -vv=verbose:2 -vvv=verbose:3"'
      AfterCall preserve
      When call parse:arguments -vvv
      The variable V should eq '3'
    End

    It '#10 positional: file.txt'
      preserve() { %preserve arg1:ARG1; }
      BeforeCall 'export ARGS_DEFINITION="\$1=arg1::1"'
      AfterCall preserve
      When call parse:arguments "file.txt"
      The variable ARG1 should eq 'file.txt'
    End

    It '#11 two positionals: file1 file2'
      preserve() { %preserve arg1:ARG1 arg2:ARG2; }
      BeforeCall 'export ARGS_DEFINITION="\$1=arg1::1 \$2=arg2::1"'
      AfterCall preserve
      When call parse:arguments "file1" "file2"
      The variable ARG1 should eq 'file1'
      The variable ARG2 should eq 'file2'
    End

    It '#12 --flag file.txt (flag + positional)'
      preserve() { %preserve flag:FLAG arg1:ARG1; }
      BeforeCall 'export ARGS_DEFINITION="--flag \$1=arg1::1"'
      AfterCall preserve
      When call parse:arguments --flag "file.txt"
      The variable FLAG should eq '1'
      The variable ARG1 should eq 'file.txt'
    End
  End

  # ============================================================
  # 2) Mixed short and long options
  # ============================================================
  Describe '2) Mixed short and long options /'

    It '#13 -v --flag (short + long)'
      preserve() { %preserve verbose:VERBOSE flag:FLAG; }
      BeforeCall 'export ARGS_DEFINITION="-v,--verbose --flag"'
      AfterCall preserve
      When call parse:arguments -v --flag
      The variable VERBOSE should eq '1'
      The variable FLAG should eq '1'
    End

    It '#14 --flag -v (long + short)'
      preserve() { %preserve verbose:VERBOSE flag:FLAG; }
      BeforeCall 'export ARGS_DEFINITION="-v,--verbose --flag"'
      AfterCall preserve
      When call parse:arguments --flag -v
      The variable FLAG should eq '1'
      The variable VERBOSE should eq '1'
    End

    It '#15 -v --key=value'
      preserve() { %preserve verbose:VERBOSE key:KEY; }
      BeforeCall 'export ARGS_DEFINITION="-v,--verbose --key=key::1"'
      AfterCall preserve
      When call parse:arguments -v --key=value
      The variable VERBOSE should eq '1'
      The variable KEY should eq 'value'
    End

    It '#16 -v --key value'
      preserve() { %preserve verbose:VERBOSE key:KEY; }
      BeforeCall 'export ARGS_DEFINITION="-v,--verbose --key=key::1"'
      AfterCall preserve
      When call parse:arguments -v --key value
      The variable VERBOSE should eq '1'
      The variable KEY should eq 'value'
    End

    It '#17 -v file.txt (short flag + positional)'
      preserve() { %preserve verbose:VERBOSE arg1:ARG1; }
      BeforeCall 'export ARGS_DEFINITION="-v,--verbose \$1=arg1::1"'
      AfterCall preserve
      When call parse:arguments -v "file.txt"
      The variable VERBOSE should eq '1'
      The variable ARG1 should eq 'file.txt'
    End

    It '#18 file.txt -v (positional before short flag)'
      preserve() { %preserve verbose:VERBOSE arg1:ARG1; }
      BeforeCall 'export ARGS_DEFINITION="-v,--verbose \$1=arg1::1"'
      AfterCall preserve
      When call parse:arguments "file.txt" -v
      The variable VERBOSE should eq '1'
      The variable ARG1 should eq 'file.txt'
    End

    It '#19 -v --flag file.txt'
      preserve() { %preserve verbose:VERBOSE flag:FLAG arg1:ARG1; }
      BeforeCall 'export ARGS_DEFINITION="-v,--verbose --flag \$1=arg1::1"'
      AfterCall preserve
      When call parse:arguments -v --flag "file.txt"
      The variable VERBOSE should eq '1'
      The variable FLAG should eq '1'
      The variable ARG1 should eq 'file.txt'
    End

    It '#20 --key=abc file1 file2'
      preserve() { %preserve key:KEY arg1:A1 arg2:A2; }
      BeforeCall 'export ARGS_DEFINITION="--key=key::1 \$1=arg1::1 \$2=arg2::1"'
      AfterCall preserve
      When call parse:arguments --key=abc "file1" "file2"
      The variable KEY should eq 'abc'
      The variable A1 should eq 'file1'
      The variable A2 should eq 'file2'
    End
  End

  # ============================================================
  # 3) Repetition and overwrite behavior (last wins)
  # ============================================================
  Describe '3) Repetition / last wins /'

    It '#21 --key=a --key=b -> last wins'
      preserve() { %preserve key:KEY; }
      BeforeCall 'export ARGS_DEFINITION="--key=key::1"'
      AfterCall preserve
      When call parse:arguments --key=a --key=b
      The variable KEY should eq 'b'
    End

    It '#22 --key a --key b -> last wins'
      preserve() { %preserve key:KEY; }
      BeforeCall 'export ARGS_DEFINITION="--key=key::1"'
      AfterCall preserve
      When call parse:arguments --key a --key b
      The variable KEY should eq 'b'
    End

    It '#23 --flag --no-flag -> false (last wins via workaround)'
      preserve() { %preserve flag:FLAG; }
      BeforeCall 'export ARGS_DEFINITION="--flag=flag:true --no-flag=flag:false"'
      AfterCall preserve
      When call parse:arguments --flag --no-flag
      The variable FLAG should eq 'false'
    End

    It '#24 --no-flag --flag -> true (last wins via workaround)'
      preserve() { %preserve flag:FLAG; }
      BeforeCall 'export ARGS_DEFINITION="--flag=flag:true --no-flag=flag:false"'
      AfterCall preserve
      When call parse:arguments --no-flag --flag
      The variable FLAG should eq 'true'
    End

    It '#27 --name alice --name bob --name carol -> last wins'
      preserve() { %preserve name:NAME; }
      BeforeCall 'export ARGS_DEFINITION="--name=name::1"'
      AfterCall preserve
      When call parse:arguments --name alice --name bob --name carol
      The variable NAME should eq 'carol'
    End

    It '#28 --count=1 --count=2 --count=3 -> last wins'
      preserve() { %preserve count:COUNT; }
      BeforeCall 'export ARGS_DEFINITION="--count=count::1"'
      AfterCall preserve
      When call parse:arguments --count=1 --count=2 --count=3
      The variable COUNT should eq '3'
    End

    It '#30 --flag --flag --flag -> still true'
      preserve() { %preserve flag:FLAG; }
      BeforeCall 'export ARGS_DEFINITION="--flag"'
      AfterCall preserve
      When call parse:arguments --flag --flag --flag
      The variable FLAG should eq '1'
    End
  End

  # ============================================================
  # 4) Short option bundling
  # ============================================================
  Describe '4) Short option bundling (via args:unbundle) /'
    # args:unbundle decomposes -abc -> -a -b -c before parse:arguments

    It '#31 -abc -> a=true b=true c=true'
      helper() {
        readarray -t expanded < <(args:unbundle "$@")
        parse:arguments "${expanded[@]}"
      }
      preserve() { %preserve a:A b:B c:C; }
      BeforeCall 'export ARGS_DEFINITION="-a=a -b=b -c=c"'
      AfterCall preserve
      When call helper -abc
      The variable A should eq '1'
      The variable B should eq '1'
      The variable C should eq '1'
    End

    It '#33 -vvq -> verbose=1 quiet=1 (via unbundle, last-wins)'
      helper() {
        readarray -t expanded < <(args:unbundle "$@")
        parse:arguments "${expanded[@]}"
      }
      preserve() { %preserve verbose:V quiet:Q; }
      # -v sets verbose=1, second -v overwrites to 1 again (last-wins)
      BeforeCall 'export ARGS_DEFINITION="-v,--verbose -q,--quiet"'
      AfterCall preserve
      When call helper -vvq
      # unbundle: -v -v -q -> verbose=1 (last-wins), quiet=1
      The variable V should eq '1'
      The variable Q should eq '1'
    End

    It '#35 -xzf archive.tar.gz (last char consumes value)'
      # With unbundle: -xzf -> -x -z -f, then -f consumes next arg
      helper() {
        readarray -t expanded < <(args:unbundle "$@")
        parse:arguments "${expanded[@]}"
      }
      preserve() { %preserve x:X z:Z f:F; }
      BeforeCall 'export ARGS_DEFINITION="-x=x -z=z -f=f::1"'
      AfterCall preserve
      When call helper -xzf "archive.tar.gz"
      The variable X should eq '1'
      The variable Z should eq '1'
      The variable F should eq 'archive.tar.gz'
    End

    # -ovalue (value attached to short flag without space)
    # Parser requires whitespace: -o value. No workaround.
    xIt '#37-40 -ovalue attached (NO WORKAROUND: parser requires space between flag and value)'
    End
  End

  Describe '4b) args:unbundle unit tests /'

    It 'passes long options through unchanged'
      When call args:unbundle --flag --key=value
      The line 1 of stdout should eq '--flag'
      The line 2 of stdout should eq '--key=value'
    End

    It 'passes single short options through unchanged'
      When call args:unbundle -v -q
      The line 1 of stdout should eq '-v'
      The line 2 of stdout should eq '-q'
    End

    It 'decomposes bundled short options'
      When call args:unbundle -abc
      The line 1 of stdout should eq '-a'
      The line 2 of stdout should eq '-b'
      The line 3 of stdout should eq '-c'
    End

    It 'passes non-flag arguments through'
      When call args:unbundle "file.txt" "path/to/dir"
      The line 1 of stdout should eq 'file.txt'
      The line 2 of stdout should eq 'path/to/dir'
    End

    It 'handles mixed input'
      When call args:unbundle --flag -abc "file.txt" -v
      The line 1 of stdout should eq '--flag'
      The line 2 of stdout should eq '-a'
      The line 3 of stdout should eq '-b'
      The line 4 of stdout should eq '-c'
      The line 5 of stdout should eq 'file.txt'
      The line 6 of stdout should eq '-v'
    End

    It 'stops decomposing after --'
      When call args:unbundle -v -- -abc
      The line 1 of stdout should eq '-v'
      The line 2 of stdout should eq '--'
      The line 3 of stdout should eq '-abc'
    End

    It 'handles empty input'
      When call args:unbundle
      The stdout should eq ''
    End
  End

  # ============================================================
  # 5) Different value types
  # ============================================================
  Describe '5) Value types /'

    It '#41 --count=0 (zero value)'
      preserve() { %preserve count:COUNT; }
      BeforeCall 'export ARGS_DEFINITION="--count=count::1"'
      AfterCall preserve
      When call parse:arguments --count=0
      The variable COUNT should eq '0'
    End

    It '#42 --count=-1 (negative integer)'
      preserve() { %preserve count:COUNT; }
      BeforeCall 'export ARGS_DEFINITION="--count=count::1"'
      AfterCall preserve
      When call parse:arguments --count=-1
      The variable COUNT should eq '-1'
    End

    It '#43 --ratio=0.75 (float)'
      preserve() { %preserve ratio:RATIO; }
      BeforeCall 'export ARGS_DEFINITION="--ratio=ratio::1"'
      AfterCall preserve
      When call parse:arguments --ratio=0.75
      The variable RATIO should eq '0.75'
    End

    It '#44 --name="" (empty string via equals)'
      preserve() { %preserve name:NAME; }
      BeforeCall 'export ARGS_DEFINITION="--name=name::1"'
      AfterCall preserve
      When call parse:arguments --name=""
      The variable NAME should eq '<empty>'
    End

    It '#45 --name "John Doe" (value with space)'
      preserve() { %preserve name:NAME; }
      BeforeCall 'export ARGS_DEFINITION="--name=name::1"'
      AfterCall preserve
      When call parse:arguments --name "John Doe"
      The variable NAME should eq 'John Doe'
    End

    It '#46 --path=/tmp/file.txt (path value)'
      preserve() { %preserve path:PATH_VAR; }
      BeforeCall 'export ARGS_DEFINITION="--path=path::1"'
      AfterCall preserve
      When call parse:arguments --path=/tmp/file.txt
      The variable PATH_VAR should eq '/tmp/file.txt'
    End

    It '#47 --path "./dir with spaces/file.txt"'
      preserve() { %preserve path:PATH_VAR; }
      BeforeCall 'export ARGS_DEFINITION="--path=path::1"'
      AfterCall preserve
      When call parse:arguments --path "./dir with spaces/file.txt"
      The variable PATH_VAR should eq './dir with spaces/file.txt'
    End

    It '#48 --pattern with regex-like value'
      preserve() { %preserve pattern:PATTERN; }
      BeforeCall 'export ARGS_DEFINITION="--pattern=pattern::1"'
      AfterCall preserve
      When call parse:arguments --pattern 'a.*b'
      The variable PATTERN should eq 'a.*b'
    End

    It '#49 --json with JSON value'
      preserve() { %preserve json:JSON; }
      BeforeCall 'export ARGS_DEFINITION="--json=json::1"'
      AfterCall preserve
      When call parse:arguments --json '{"a":1,"b":2}'
      The variable JSON should eq '{"a":1,"b":2}'
    End

    It '#50 --empty= (empty value via equals)'
      preserve() { %preserve empty:EMPTY; }
      BeforeCall 'export ARGS_DEFINITION="--empty=empty::1"'
      AfterCall preserve
      When call parse:arguments --empty=
      The variable EMPTY should eq '<empty>'
    End
  End

  # ============================================================
  # 6) Positionals and indexed positionals
  # ============================================================
  Describe '6) Positionals /'

    It '#51 src.txt dst.txt (two indexed positionals)'
      preserve() { %preserve arg1:SRC arg2:DST; }
      BeforeCall 'export ARGS_DEFINITION="\$1=arg1::1 \$2=arg2::1"'
      AfterCall preserve
      When call parse:arguments "src.txt" "dst.txt"
      The variable SRC should eq 'src.txt'
      The variable DST should eq 'dst.txt'
    End

    It '#52 --force src.txt dst.txt (flag before positionals)'
      preserve() { %preserve force:FORCE arg1:SRC arg2:DST; }
      BeforeCall 'export ARGS_DEFINITION="--force \$1=arg1::1 \$2=arg2::1"'
      AfterCall preserve
      When call parse:arguments --force "src.txt" "dst.txt"
      The variable FORCE should eq '1'
      The variable SRC should eq 'src.txt'
      The variable DST should eq 'dst.txt'
    End

    It '#53 src.txt --force dst.txt (flag between positionals)'
      preserve() { %preserve force:FORCE arg1:SRC arg2:DST; }
      BeforeCall 'export ARGS_DEFINITION="--force \$1=arg1::1 \$2=arg2::1"'
      AfterCall preserve
      When call parse:arguments "src.txt" --force "dst.txt"
      The variable FORCE should eq '1'
      The variable SRC should eq 'src.txt'
      The variable DST should eq 'dst.txt'
    End

    It '#55 three positionals: deploy production api'
      preserve() { %preserve a1:A1 a2:A2 a3:A3; }
      BeforeCall 'export ARGS_DEFINITION="\$1=a1::1 \$2=a2::1 \$3=a3::1"'
      AfterCall preserve
      When call parse:arguments "deploy" "production" "api"
      The variable A1 should eq 'deploy'
      The variable A2 should eq 'production'
      The variable A3 should eq 'api'
    End

    It '#56 --profile prod deploy service-a'
      preserve() { %preserve profile:PROFILE a1:CMD a2:SVC; }
      BeforeCall 'export ARGS_DEFINITION="--profile=profile::1 \$1=a1::1 \$2=a2::1"'
      AfterCall preserve
      When call parse:arguments --profile prod "deploy" "service-a"
      The variable PROFILE should eq 'prod'
      The variable CMD should eq 'deploy'
      The variable SVC should eq 'service-a'
    End

    It '#57 build -- target1 target2 (-- stops flag processing)'
      preserve() { %preserve a1:A1 a2:A2 a3:A3; }
      BeforeCall 'export ARGS_DEFINITION="\$1=a1::1 \$2=a2::1 \$3=a3::1"'
      AfterCall preserve
      When call parse:arguments "build" -- "target1" "target2"
      The variable A1 should eq 'build'
      The variable A2 should eq 'target1'
      The variable A3 should eq 'target2'
    End

    It '#58 -- --flag -v file.txt (everything after -- is positional)'
      preserve() { %preserve a1:A1 a2:A2 a3:A3; }
      BeforeCall 'export ARGS_DEFINITION="--flag -v,--verbose \$1=a1::1 \$2=a2::1 \$3=a3::1"'
      AfterCall preserve
      When call parse:arguments -- "--flag" "-v" "file.txt"
      # --flag and -v are NOT processed as flags after --
      The variable A1 should eq '--flag'
      The variable A2 should eq '-v'
      The variable A3 should eq 'file.txt'
    End

    It '#59 file.txt -- --not-an-option'
      preserve() { %preserve a1:A1 a2:A2; }
      BeforeCall 'export ARGS_DEFINITION="\$1=a1::1 \$2=a2::1"'
      AfterCall preserve
      When call parse:arguments "file.txt" -- "--not-an-option"
      The variable A1 should eq 'file.txt'
      The variable A2 should eq '--not-an-option'
    End

    It '#60 --key=1 -- file.txt --key=2 (flag before --, positional after)'
      preserve() { %preserve key:KEY a1:A1 a2:A2; }
      BeforeCall 'export ARGS_DEFINITION="--key=key::1 \$1=a1::1 \$2=a2::1"'
      AfterCall preserve
      When call parse:arguments --key=1 -- "file.txt" "--key=2"
      The variable KEY should eq '1'
      The variable A1 should eq 'file.txt'
      The variable A2 should eq '--key=2'
    End
  End

  # ============================================================
  # 7) List-valued options
  # ============================================================
  Describe '7) List-valued options /'
    # Parser uses last-wins for repeated scalar flags.
    # Workaround: user processes the raw value themselves.
    # For "collect all values" pattern, use multi-value args_qt or
    # let user call parse:arguments in a loop.

    It '#61 --include=a (single value, user treats as list start)'
      preserve() { %preserve include:INC; }
      BeforeCall 'export ARGS_DEFINITION="--include=include::1"'
      AfterCall preserve
      When call parse:arguments --include=a
      The variable INC should eq 'a'
    End

    It '#63 --include=a --include=b -> last wins (user accumulates externally)'
      # Parser gives last value. User code can wrap to accumulate:
      #   for arg in "$@"; do [[ "$arg" == --include=* ]] && list+=("${arg#*=}"); done
      preserve() { %preserve include:INC; }
      BeforeCall 'export ARGS_DEFINITION="--include=include::1"'
      AfterCall preserve
      When call parse:arguments --include=a --include=b
      The variable INC should eq 'b'
    End

    It '#67 --env A=1 (value with = preserved for user parsing)'
      # User gets raw "A=1" and can split key/value themselves
      preserve() { %preserve env:ENV; }
      BeforeCall 'export ARGS_DEFINITION="--env=env::1"'
      AfterCall preserve
      When call parse:arguments --env "A=1"
      The variable ENV should eq 'A=1'
    End

    It '#67b --env=A=1 (equals syntax, value with = preserved)'
      preserve() { %preserve env:ENV; }
      BeforeCall 'export ARGS_DEFINITION="--env=env::1"'
      AfterCall preserve
      When call parse:arguments --env=A=1
      The variable ENV should eq 'A=1'
    End

    It '#69 --label "team=core" (quoted value with = for user map parsing)'
      preserve() { %preserve label:LABEL; }
      BeforeCall 'export ARGS_DEFINITION="--label=label::1"'
      AfterCall preserve
      When call parse:arguments --label "team=core"
      The variable LABEL should eq 'team=core'
    End
  End

  # ============================================================
  # 8) Options consuming multiple values (args_qt > 1)
  # ============================================================
  Describe '8) Multi-value options /'

    It '#71 --range 10 20 (consumes 2 args)'
      preserve() { %preserve range:RANGE; }
      BeforeCall 'export ARGS_DEFINITION="--range=range::2"'
      AfterCall preserve
      When call parse:arguments --range 10 20
      The variable RANGE should eq '10 20'
    End

    It '#72 --range -5 15 (negative number as value)'
      preserve() { %preserve range:RANGE; }
      BeforeCall 'export ARGS_DEFINITION="--range=range::2"'
      AfterCall preserve
      When call parse:arguments --range -5 15
      The variable RANGE should eq '-5 15'
    End

    It '#73 --map user alice (key-value pair, user splits)'
      # Parser delivers "user alice" as raw string; user splits on space
      preserve() { %preserve map:MAP; }
      BeforeCall 'export ARGS_DEFINITION="--map=map::2"'
      AfterCall preserve
      When call parse:arguments --map user alice
      The variable MAP should eq 'user alice'
    End

    It '#75 --rgb 255 128 0 (consumes 3 args)'
      preserve() { %preserve rgb:RGB; }
      BeforeCall 'export ARGS_DEFINITION="--rgb=rgb::3"'
      AfterCall preserve
      When call parse:arguments --rgb 255 128 0
      The variable RGB should eq '255 128 0'
    End

    It '#76 --range 10 20 file.txt (multi-val + positional after)'
      preserve() { %preserve range:RANGE arg1:ARG1; }
      BeforeCall 'export ARGS_DEFINITION="--range=range::2 \$1=arg1::1"'
      AfterCall preserve
      When call parse:arguments --range 10 20 "file.txt"
      The variable RANGE should eq '10 20'
      The variable ARG1 should eq 'file.txt'
    End

    It '#77 --map path "/tmp/a b" --flag (multi-val with spaces + flag)'
      preserve() { %preserve map:MAP flag:FLAG; }
      BeforeCall 'export ARGS_DEFINITION="--map=map::2 --flag"'
      AfterCall preserve
      When call parse:arguments --map path "/tmp/a b" --flag
      The variable MAP should eq 'path /tmp/a b'
      The variable FLAG should eq '1'
    End

    It '#78 --rgb repeated: last wins'
      preserve() { %preserve rgb:RGB; }
      BeforeCall 'export ARGS_DEFINITION="--rgb=rgb::3"'
      AfterCall preserve
      When call parse:arguments --rgb 0 0 0 --rgb 255 255 255
      The variable RGB should eq '255 255 255'
    End

    It '#80 positional --range positional'
      preserve() { %preserve range:RANGE a1:A1 a2:A2; }
      BeforeCall 'export ARGS_DEFINITION="--range=range::2 \$1=a1::1 \$2=a2::1"'
      AfterCall preserve
      When call parse:arguments "cmd" --range 1 9 "subcmd"
      The variable RANGE should eq '1 9'
      The variable A1 should eq 'cmd'
      The variable A2 should eq 'subcmd'
    End
  End

  # ============================================================
  # 9) Ambiguous values (option-looking values consumed by preceding flag)
  # ============================================================
  Describe '9) Ambiguous values /'

    It '#81 --count -1 (negative number consumed as value)'
      preserve() { %preserve count:COUNT; }
      BeforeCall 'export ARGS_DEFINITION="--count=count::1"'
      AfterCall preserve
      When call parse:arguments --count -1
      The variable COUNT should eq '-1'
    End

    It '#82 --threshold -0.5 (negative float)'
      preserve() { %preserve threshold:THRESH; }
      BeforeCall 'export ARGS_DEFINITION="--threshold=threshold::1"'
      AfterCall preserve
      When call parse:arguments --threshold -0.5
      The variable THRESH should eq '-0.5'
    End

    It '#84 --pattern --not-a-flag (flag-like string consumed as value)'
      preserve() { %preserve pattern:PATTERN; }
      BeforeCall 'export ARGS_DEFINITION="--pattern=pattern::1"'
      AfterCall preserve
      When call parse:arguments --pattern "--not-a-flag"
      The variable PATTERN should eq '--not-a-flag'
    End

    It '#85 -o - (dash as value)'
      preserve() { %preserve output:OUT; }
      BeforeCall 'export ARGS_DEFINITION="-o,--output=output::1"'
      AfterCall preserve
      When call parse:arguments -o "-"
      The variable OUT should eq '-'
    End

    It '#87 --name -v (short flag consumed as value, not as verbose)'
      preserve() { %preserve name:NAME; }
      BeforeCall 'export ARGS_DEFINITION="--name=name::1 -v,--verbose"'
      AfterCall preserve
      When call parse:arguments --name "-v"
      The variable NAME should eq '-v'
    End
  End

  # ============================================================
  # 10) End-of-options marker
  # ============================================================
  Describe '10) End-of-options -- /'

    It '#91 --flag -- file.txt'
      preserve() { %preserve flag:FLAG a1:A1; }
      BeforeCall 'export ARGS_DEFINITION="--flag \$1=a1::1"'
      AfterCall preserve
      When call parse:arguments --flag -- "file.txt"
      The variable FLAG should eq '1'
      The variable A1 should eq 'file.txt'
    End

    It '#92 -- --flag (flag after -- becomes positional)'
      preserve() { %preserve flag:FLAG a1:A1; }
      BeforeCall 'export ARGS_DEFINITION="--flag \$1=a1::1"'
      AfterCall preserve
      When call parse:arguments -- "--flag"
      The variable FLAG should be undefined
      The variable A1 should eq '--flag'
    End

    It '#93 --key=1 -- --key=2 (flag processed before --, not after)'
      preserve() { %preserve key:KEY a1:A1; }
      BeforeCall 'export ARGS_DEFINITION="--key=key::1 \$1=a1::1"'
      AfterCall preserve
      When call parse:arguments --key=1 -- "--key=2"
      The variable KEY should eq '1'
      The variable A1 should eq '--key=2'
    End

    It '#94 -v -- -q -abc (only -v processed as flag)'
      preserve() { %preserve verbose:V quiet:Q a1:A1 a2:A2; }
      BeforeCall 'export ARGS_DEFINITION="-v,--verbose -q,--quiet \$1=a1::1 \$2=a2::1"'
      AfterCall preserve
      When call parse:arguments -v -- "-q" "-abc"
      The variable V should eq '1'
      The variable Q should be undefined
      The variable A1 should eq '-q'
      The variable A2 should eq '-abc'
    End

    It '#95 --range 1 2 -- --range 3 4'
      preserve() { %preserve range:RANGE a1:A1 a2:A2 a3:A3; }
      BeforeCall 'export ARGS_DEFINITION="--range=range::2 \$1=a1::1 \$2=a2::1 \$3=a3::1"'
      AfterCall preserve
      When call parse:arguments --range 1 2 -- "--range" "3" "4"
      The variable RANGE should eq '1 2'
      The variable A1 should eq '--range'
      The variable A2 should eq '3'
      The variable A3 should eq '4'
    End
  End

  # ============================================================
  # 11) Subcommand-style
  # ============================================================
  Describe '11) Subcommand-style /'
    # Workaround: first positional is the subcommand, remaining args
    # are forwarded. User code switches on $1 and re-parses.

    It '#96 --verbose + subcommand args (global flags + positional forward)'
      # Note: -m is skipped as unknown short flag — subcommand forwarding
      # requires user-side handling (parser has no -- sentinel)
      preserve() { %preserve verbose:V a1:CMD a2:A2 a3:A3; }
      BeforeCall 'export ARGS_DEFINITION="-v,--verbose \$1=a1::1 \$2=a2::1 \$3=a3::1"'
      AfterCall preserve
      When call parse:arguments --verbose "git" "commit" "-m" "hello"
      The variable V should eq '1'
      The variable CMD should eq 'git'
      The variable A2 should eq 'commit'
      # -m is skipped (unknown flag), "hello" becomes positional $3
      The variable A3 should eq 'hello'
    End

    It '#99 app serve --host 0.0.0.0 --port 8080'
      preserve() { %preserve a1:CMD a2:SUB host:HOST port:PORT; }
      BeforeCall 'export ARGS_DEFINITION="\$1=a1::1 \$2=a2::1 --host=host::1 --port=port::1"'
      AfterCall preserve
      When call parse:arguments "app" "serve" --host "0.0.0.0" --port 8080
      The variable CMD should eq 'app'
      The variable SUB should eq 'serve'
      The variable HOST should eq '0.0.0.0'
      The variable PORT should eq '8080'
    End
  End

  # ============================================================
  # 12) Expected failures
  # ============================================================
  Describe '12) Expected failures /'

    It '#101 --key without value -> error'
      BeforeCall 'export ARGS_DEFINITION="--key=key::1"'
      When call parse:arguments --key
      The status should be failure
      The stderr should include "too few arguments"
    End

    It '#103 --range with only 1 value -> error'
      BeforeCall 'export ARGS_DEFINITION="--range=range::2"'
      When call parse:arguments --range 10
      The status should be failure
      The stderr should include "too few arguments"
    End

    It '#104 --rgb with only 2 values -> error'
      BeforeCall 'export ARGS_DEFINITION="--rgb=rgb::3"'
      When call parse:arguments --rgb 1 2
      The status should be failure
      The stderr should include "too few arguments"
    End

    It '#105 --unknown flag is silently skipped (not an error)'
      preserve() { %preserve flag:FLAG; }
      BeforeCall 'export ARGS_DEFINITION="--flag"'
      AfterCall preserve
      When call parse:arguments --flag --unknown
      # Current behavior: unknown flags are skipped, not errors
      The status should be success
      The variable FLAG should eq '1'
    End
  End

  # ============================================================
  # 13) Complex real-world scenarios
  # ============================================================
  Describe '13) Real-world scenarios /'

    It 'git.semantic-version style: multiple flags + value option'
      preserve() { %preserve verbose:V format:F branch:B; }
      BeforeCall 'export ARGS_DEFINITION="-h,--help -v,--verbose --format=format:text:1 --branch=branch::1"'
      AfterCall preserve
      When call parse:arguments --verbose --format json --branch main
      The variable V should eq '1'
      The variable F should eq 'json'
      The variable B should eq 'main'
    End

    It 'npm.versions style: registry URL + dry-run + package'
      preserve() { %preserve registry:REG dryrun:DRY pkg:PKG; }
      BeforeCall 'export ARGS_DEFINITION="--registry=registry:https://registry.npmjs.org:1 --dry-run=dryrun:false \$1=pkg::1"'
      AfterCall preserve
      When call parse:arguments --registry "https://custom.registry.io" --dry-run "@scope/pkg"
      The variable REG should eq 'https://custom.registry.io'
      The variable DRY should eq 'false'
      The variable PKG should eq '@scope/pkg'
    End

    It 'curl style: method + headers + URL'
      preserve() { %preserve request:REQ header:HDR url:URL; }
      BeforeCall 'export ARGS_DEFINITION="-X,--request=request::1 -H,--header=header::1 --url=url::1"'
      AfterCall preserve
      When call parse:arguments -X POST -H "Content-Type: application/json" --url "https://api.example.com/data"
      The variable REQ should eq 'POST'
      The variable HDR should eq 'Content-Type: application/json'
      The variable URL should eq 'https://api.example.com/data'
    End

    It 'mixed equals and space syntax in same invocation'
      preserve() { %preserve output:OUT format:FMT verbose:V; }
      BeforeCall 'export ARGS_DEFINITION="-o,--output=output::1 -f,--format=format::1 -v,--verbose"'
      AfterCall preserve
      When call parse:arguments --output=result.json -f csv -v
      The variable OUT should eq 'result.json'
      The variable FMT should eq 'csv'
      The variable V should eq '1'
    End

    It 'all flags with defaults, none provided -> pre-filled with defaults'
      preserve() { %preserve debug:DBG version:VER; }
      BeforeCall 'export ARGS_DEFINITION="--debug=debug:false --version=version:1.0.0"'
      AfterCall preserve
      When call parse:arguments
      # Defaults pre-filled for boolean-like value flags (args_qt=0, default="false")
      # Note: --debug has args_qt=0 (boolean), so its default is NOT pre-filled
      # --version has args_qt=0 (boolean), so its default is NOT pre-filled
      The variable DBG should be undefined
      The variable VER should be undefined
    End

    It 'value with single quotes'
      preserve() { %preserve msg:MSG; }
      BeforeCall 'export ARGS_DEFINITION="--msg=msg::1"'
      AfterCall preserve
      When call parse:arguments --msg "it's a test"
      The variable MSG should eq "it's a test"
    End

    It 'value with double quotes inside'
      preserve() { %preserve msg:MSG; }
      BeforeCall 'export ARGS_DEFINITION="--msg=msg::1"'
      AfterCall preserve
      When call parse:arguments --msg 'she said "hello"'
      The variable MSG should eq 'she said "hello"'
    End

    It 'value with equals sign via space syntax'
      preserve() { %preserve env:ENV; }
      BeforeCall 'export ARGS_DEFINITION="--env=env::1"'
      AfterCall preserve
      When call parse:arguments --env "KEY=VALUE"
      The variable ENV should eq 'KEY=VALUE'
    End

    It 'value with equals sign via equals syntax'
      preserve() { %preserve env:ENV; }
      BeforeCall 'export ARGS_DEFINITION="--env=env::1"'
      AfterCall preserve
      When call parse:arguments --env="KEY=VALUE"
      The variable ENV should eq 'KEY=VALUE'
    End

    It 'flag/no-flag toggle sequence (workaround pattern)'
      preserve() { %preserve dry:DRY; }
      BeforeCall 'export ARGS_DEFINITION="--dry-run=dry:true --no-dry-run=dry:false"'
      AfterCall preserve
      When call parse:arguments --dry-run --no-dry-run --dry-run
      The variable DRY should eq 'true'
    End

    It 'many flags + many positionals'
      # Note: -v,--verbose → variable name is "verbose" (from longest alias)
      # Use explicit =var to control variable names
      preserve() { %preserve v:V f:F o:O a1:A1 a2:A2 a3:A3; }
      BeforeCall 'export ARGS_DEFINITION="-v,--verbose=v -f,--force=f -o,--output=o::1 \$1=a1::1 \$2=a2::1 \$3=a3::1"'
      AfterCall preserve
      When call parse:arguments -v "src" --force -o "out.txt" "mid" "dst"
      The variable V should eq '1'
      The variable F should eq '1'
      The variable O should eq 'out.txt'
      The variable A1 should eq 'src'
      The variable A2 should eq 'mid'
      The variable A3 should eq 'dst'
    End
  End
End
