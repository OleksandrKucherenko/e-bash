#!/usr/bin/env bash
# shell: bash altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-04-14
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

Describe 'Scoped parsing /'
  BeforeRun 'export DEBUG="*"'
  Include ".scripts/_arguments.sh"

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
  # ARGS_UNPARSED collection
  # ============================================================
  Describe 'ARGS_UNPARSED /'

    It 'collects unknown flags'
      helper() {
        parse:arguments "$@"
        echo "${ARGS_UNPARSED[*]}"
      }
      BeforeCall 'export ARGS_DEFINITION="--verbose"'
      When call helper --verbose --unknown
      The stdout should eq '--unknown'
    End

    It 'collects unknown --flag=value (reconstructed)'
      helper() {
        parse:arguments "$@"
        echo "${ARGS_UNPARSED[*]}"
      }
      BeforeCall 'export ARGS_DEFINITION="--verbose"'
      When call helper --verbose --replicas=3
      The stdout should eq '--replicas=3'
    End

    It 'collects unmatched positionals'
      helper() {
        parse:arguments "$@"
        echo "${ARGS_UNPARSED[*]}"
      }
      BeforeCall 'export ARGS_DEFINITION="\$1=cmd::1"'
      When call helper "deploy" "extra1" "extra2"
      The stdout should eq 'extra1 extra2'
    End

    It 'is empty when all args consumed'
      helper() {
        parse:arguments "$@"
        echo "${#ARGS_UNPARSED[@]}"
      }
      BeforeCall 'export ARGS_DEFINITION="--verbose \$1=cmd::1"'
      When call helper --verbose "deploy"
      The stdout should eq '0'
    End

    It 'resets on each parse:arguments call'
      helper() {
        export ARGS_DEFINITION="--verbose"
        parse:arguments --verbose --unknown1
        local first="${ARGS_UNPARSED[*]}"
        parse:arguments --verbose --unknown2
        echo "first=$first second=${ARGS_UNPARSED[*]}"
      }
      When call helper
      The stdout should eq 'first=--unknown1 second=--unknown2'
    End

    It 'collects post--- unmatched positionals'
      helper() {
        parse:arguments "$@"
        echo "${ARGS_UNPARSED[*]}"
      }
      BeforeCall 'export ARGS_DEFINITION="--verbose \$1=cmd::1"'
      When call helper --verbose -- "deploy" "--extra" "more"
      # deploy matches $1, --extra and "more" are unmatched
      The stdout should eq '--extra more'
    End

    It 'preserves order for re-parsing'
      helper() {
        parse:arguments "$@"
        local IFS=$'\n'
        printf '%s\n' "${ARGS_UNPARSED[@]}"
      }
      BeforeCall 'export ARGS_DEFINITION="--verbose"'
      When call helper --verbose --replicas 3 --region eu
      The line 1 of stdout should eq '--replicas'
      The line 2 of stdout should eq '3'
      The line 3 of stdout should eq '--region'
      The line 4 of stdout should eq 'eu'
    End
  End

  # ============================================================
  # args:reset
  # ============================================================
  Describe 'args:reset /'

    It 'clears lookup arrays'
      helper() {
        export ARGS_DEFINITION="--verbose"
        parse:arguments --verbose
        local before=${#lookup_arguments[@]}
        args:reset
        echo "before=$before after=${#lookup_arguments[@]}"
      }
      When call helper
      The stdout should include 'after=0'
    End

    It 'clears ARGS_UNPARSED'
      helper() {
        export ARGS_DEFINITION="--verbose"
        parse:arguments --verbose --unknown
        local before=${#ARGS_UNPARSED[@]}
        args:reset
        echo "before=$before after=${#ARGS_UNPARSED[@]}"
      }
      When call helper
      The stdout should eq 'before=1 after=0'
    End
  End

  # ============================================================
  # args:scope
  # ============================================================
  Describe 'args:scope /'

    It 'parses with named scope variable'
      helper() {
        local DEPLOY_SCOPE="--replicas=replicas::1 --region=region::1"
        args:scope DEPLOY_SCOPE --replicas 3 --region eu
        echo "replicas=$replicas region=$region"
      }
      When call helper
      The stdout should eq 'replicas=3 region=eu'
    End

    It 'resets state before parsing'
      helper() {
        export ARGS_DEFINITION="--verbose --flag"
        parse:arguments --verbose --flag
        local SCOPE="--port=port::1"
        args:scope SCOPE --port 8080
        # verbose and flag should NOT be in lookup_arguments
        echo "port=$port lookup_count=${#lookup_arguments[@]}"
      }
      When call helper
      # Only --port + auto-appended --completion + --install-completion = 3 definitions
      # But each def has multiple keys, so lookup count varies
      The stdout should include 'port=8080'
    End
  End

  # ============================================================
  # Two-phase subcommand pattern (end-to-end)
  # ============================================================
  Describe 'Two-phase subcommand /'

    It 'global flags + deploy subcommand'
      helper() {
        # Phase 1: global
        export ARGS_DEFINITION="--verbose \$1=command::1"
        parse:arguments "$@"
        local cmd="$command"
        local -a remaining=("${ARGS_UNPARSED[@]}")

        # Phase 2: deploy scope
        local DEPLOY_SCOPE="--replicas=replicas::1 --region=region::1"
        args:scope DEPLOY_SCOPE "${remaining[@]}"

        echo "verbose=$verbose cmd=$cmd replicas=$replicas region=$region"
      }
      When call helper --verbose deploy --replicas 3 --region eu
      The stdout should eq 'verbose=1 cmd=deploy replicas=3 region=eu'
    End

    It 'global flags + serve subcommand'
      helper() {
        export ARGS_DEFINITION="--verbose \$1=command::1"
        parse:arguments "$@"
        local cmd="$command"
        local -a remaining=("${ARGS_UNPARSED[@]}")

        local SERVE_SCOPE="--port=port::1 --host=host::1"
        args:scope SERVE_SCOPE "${remaining[@]}"

        echo "verbose=$verbose cmd=$cmd port=$port host=$host"
      }
      When call helper --verbose serve --port 8080 --host 0.0.0.0
      The stdout should eq 'verbose=1 cmd=serve port=8080 host=0.0.0.0'
    End

    It 'three-phase: global -> command -> subcommand'
      helper() {
        # Phase 1
        export ARGS_DEFINITION="--verbose \$1=command::1"
        parse:arguments "$@"
        local cmd="$command"
        local -a phase2_args=("${ARGS_UNPARSED[@]}")

        # Phase 2
        local CMD_SCOPE="\$1=subcmd::1"
        args:scope CMD_SCOPE "${phase2_args[@]}"
        local sub="$subcmd"
        local -a phase3_args=("${ARGS_UNPARSED[@]}")

        # Phase 3
        local SUB_SCOPE="--replicas=replicas::1"
        args:scope SUB_SCOPE "${phase3_args[@]}"

        echo "cmd=$cmd sub=$sub replicas=$replicas"
      }
      When call helper --verbose deploy api --replicas 5
      The stdout should eq 'cmd=deploy sub=api replicas=5'
    End

    It 'completion flags only in phase 1 (not leaked to phase 2)'
      helper() {
        export ARGS_DEFINITION="--verbose"
        parse:arguments "$@"
        local -a remaining=("${ARGS_UNPARSED[@]}")

        local SCOPE="--port=port::1"
        args:scope SCOPE "${remaining[@]}"
        # --completion should be unknown in phase 2, goes to ARGS_UNPARSED
        echo "port=$port unparsed=${ARGS_UNPARSED[*]}"
      }
      When call helper --verbose --port 8080 --completion bash
      # --port and --completion are unknown in phase 1 -> ARGS_UNPARSED
      # In phase 2, --port is consumed, --completion is unknown
      The stdout should include 'port=8080'
      The stdout should include 'unparsed=--completion bash'
    End
  End

  # ============================================================
  # Backward compatibility
  # ============================================================
  Describe 'Backward compatibility /'

    It 'single-phase scripts: ARGS_UNPARSED is empty'
      helper() {
        export ARGS_DEFINITION="-h,--help -v,--verbose"
        parse:arguments --help --verbose
        echo "${#ARGS_UNPARSED[@]}"
      }
      When call helper
      The stdout should eq '0'
    End

    It 'single-phase: existing behavior unchanged'
      preserve() { %preserve help:H verbose:V; }
      BeforeCall 'export ARGS_DEFINITION="-h,--help -v,--verbose"'
      AfterCall preserve
      When call parse:arguments --help --verbose
      The variable H should eq '1'
      The variable V should eq '1'
    End
  End
End
