#!/usr/bin/env bash
# shell: bash altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-04-14
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# Stress test corpus for _arguments.sh parser.
#
# Parser capabilities:
#   SUPPORTED: --key=value, --key value, -k value, --flag (boolean),
#              positional args ($1,$2), multi-arg (args_qt>1),
#              last-wins overwrite, ARGS_DEFINITION declarative syntax
#
#   NOT SUPPORTED (xIt = known limitation):
#     - Short option bundling (-abc)
#     - Counter flags (-vvv)
#     - --no-flag negation
#     - -- end-of-options marker
#     - List accumulation (repeated flag appends)
#     - Map options (--map key value)
#     - Subcommand-style parsing

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

    # #4: --no-flag negation not supported
    xIt '#4 --no-flag -> flag=false (NOT SUPPORTED: negation prefix)'
    End

    # #5-9: Counter flags (-v/-vvv) not supported
    xIt '#5 -v -> verbose=1 (NOT SUPPORTED: counter flags)'
    End
    xIt '#6 -vv -> verbose=2 (NOT SUPPORTED: counter flags)'
    End
    xIt '#7 -vvv -> verbose=3 (NOT SUPPORTED: counter flags)'
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
  # 4) Short option bundling (NOT SUPPORTED)
  # ============================================================
  Describe '4) Short option bundling /'
    xIt '#31 -abc (NOT SUPPORTED: bundling)'
    End
    xIt '#35 -xzf archive.tar.gz (NOT SUPPORTED: bundling with value)'
    End
    xIt '#37 -ovalue (NOT SUPPORTED: value attached to short flag)'
    End
    xIt '#39 -I/usr/include (NOT SUPPORTED: value attached to short flag)'
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

    # #57-60: -- end-of-options marker not supported
    xIt '#57 build -- target1 target2 (NOT SUPPORTED: -- marker)'
    End
    xIt '#58 -- --flag -v file.txt (NOT SUPPORTED: -- marker)'
    End
  End

  # ============================================================
  # 7) List-valued options (NOT SUPPORTED - last wins)
  # ============================================================
  Describe '7) List-valued options /'
    xIt '#63 --include=a --include=b -> [a,b] (NOT SUPPORTED: list accumulation, last wins instead)'
    End
    xIt '#66 --tag=one --tag=two --tag=three (NOT SUPPORTED: list accumulation)'
    End
    xIt '#67 --env A=1 --env B=2 (NOT SUPPORTED: list accumulation)'
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

    It '#84 --pattern --not-a-flag (flag-like string consumed as value)'
      preserve() { %preserve pattern:PATTERN; }
      BeforeCall 'export ARGS_DEFINITION="--pattern=pattern::1"'
      AfterCall preserve
      When call parse:arguments --pattern "--not-a-flag"
      The variable PATTERN should eq '--not-a-flag'
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
  # 10) End-of-options marker (NOT SUPPORTED)
  # ============================================================
  Describe '10) End-of-options -- /'
    xIt '#91 --flag -- file.txt (NOT SUPPORTED: -- marker)'
    End
    xIt '#92 -- --flag (NOT SUPPORTED: -- marker)'
    End
    xIt '#93 --key=1 -- --key=2 (NOT SUPPORTED: -- marker)'
    End
    xIt '#94 -v -- -q -abc (NOT SUPPORTED: -- marker)'
    End
  End

  # ============================================================
  # 11) Subcommand-style (NOT SUPPORTED as native feature)
  # ============================================================
  Describe '11) Subcommand-style /'
    xIt '#96-100 (NOT SUPPORTED: subcommand model)'
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

    It 'git.semantic-version style: multiple flags + positional'
      preserve() { %preserve help:H verbose:V format:F branch:B; }
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

    It 'all flags with defaults, none provided'
      preserve() { %preserve debug:DBG version:VER; }
      BeforeCall 'export ARGS_DEFINITION="--debug=debug:false --version=version:1.0.0"'
      AfterCall preserve
      When call parse:arguments
      # No flags provided → variables stay unset (defaults not applied without flag)
      The variable DBG should be undefined
      The variable VER should be undefined
    End

    It 'flag=value where value contains single quotes'
      preserve() { %preserve msg:MSG; }
      BeforeCall 'export ARGS_DEFINITION="--msg=msg::1"'
      AfterCall preserve
      When call parse:arguments --msg "it's a test"
      The variable MSG should eq "it's a test"
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
  End
End
