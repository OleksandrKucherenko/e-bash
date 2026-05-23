#!/usr/bin/env bash
# shell: bash altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2155,SC2317,SC2016,SC2329,SC2034

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-05-23
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

readonly PROJECT_ROOT="$(pwd)"
readonly SCRIPT_DIR="${PROJECT_ROOT}/bin"
readonly UNDER_TEST="${SCRIPT_DIR}/logs.sh"

# Set E_BASH before sourcing the script
export E_BASH="${PROJECT_ROOT}/.scripts"
export NO_COLOR=1

readonly ESC="$(printf '\033')"

# Mock the tool's own logger so logger:init / status lines never run in tests.
Mock echo:Logs
  echo "$*" >&2
End
Mock printf:Logs
  printf '%s' "$@" >&2
End

# Mock loggers used internally by _arguments.sh / _commons.sh.
Mock echo:Common
  :
End
Mock printf:Common
  :
End
Mock echo:Parser
  :
End
Mock printf:Parser
  :
End

Describe 'bin/logs.sh /'
  # ShellSpec's Include sets __SOURCED__, stopping execution at ${__SOURCED__:+return}.
  Include "$UNDER_TEST"
  BeforeAll 'cl:unset'

  Context 'sourcing and public surface /'
    Parameters
      logs:run_dir
      logs:latest_run
      logs:capture
      logs:capture:main
      logs:search:feed
      logs:search:preview
      logs:search:main
      logs:view:tail
      _logs:parse_service
      _logs:slug
      _logs:is_json
      _logs:reader
      _logs:worker
      _logs:colorize
      _logs:cleanup
      _logs:load_config
    End

    It "defines function $1"
      The function "$1" should be defined
    End
  End

  Context '_logs:parse_service /'
    It 'splits on the first = so the command may contain ='
      parse() { _logs:parse_service "db=psql -c 'a=1'" T C && echo "$T :: $C"; }
      When call parse
      The output should eq "db :: psql -c 'a=1'"
    End

    It 'rejects a spec without ='
      parse() { _logs:parse_service "broken" T C; }
      When call parse
      The status should be failure
    End

    It 'rejects an empty tag'
      parse() { _logs:parse_service "=cmd" T C; }
      When call parse
      The status should be failure
    End
  End

  Context '_logs:slug /'
    It 'replaces unsafe characters with underscore'
      When call _logs:slug 'my/weird tag:1'
      The output should eq 'my_weird_tag_1'
    End
  End

  Context '_logs:is_json /'
    Parameters
      '{"a":1}'        success
      '[1,2,3]'        success
      '   {"x":true}'  success
      'plain text'     failure
      '{not json'      failure
      ''               failure
    End

    It "classifies [$1]"
      When call _logs:is_json "$1"
      The status should be "$2"
    End
  End

  Context '_logs:reader (capture fan-out) /'
    setup() {
      RD="$(mktemp -d "$SHELLSPEC_TMPBASE/reader.XXXXXX")"
    }
    cleanup() { rm -rf "$RD"; }
    BeforeEach 'setup'
    AfterEach 'cleanup'

    It 'writes raw lines to the per-tag file and tagged lines to the consolidated file'
      run_reader() { printf 'hello\nERROR boom\n' | _logs:reader api "$RD/api.log" "$RD/all.log"; }
      When call run_reader
      The contents of file "$RD/api.log" should include 'hello'
      The contents of file "$RD/api.log" should include 'ERROR boom'
      The contents of file "$RD/all.log" should include 'api hello'
      The contents of file "$RD/all.log" should include 'api ERROR boom'
    End

    It 'writes no ANSI escape codes to files'
      run_reader() { printf 'plain\n' | _logs:reader api "$RD/api.log" "$RD/all.log"; }
      When call run_reader
      The contents of file "$RD/all.log" should not include "$ESC"
      The contents of file "$RD/api.log" should not include "$ESC"
    End

    # Regression: the logger's pipe mode uses `read -t 0.1` and would drop output
    # after any quiet gap. The capture reader must survive idle gaps.
    It 'keeps reading across an idle gap longer than 0.1s'
      run_reader() { { echo first; sleep 0.3; echo second; } | _logs:reader gap "$RD/gap.log" "$RD/all.log"; }
      When call run_reader
      The contents of file "$RD/gap.log" should include 'first'
      The contents of file "$RD/gap.log" should include 'second'
    End

    It 'flushes a trailing line that has no newline'
      run_reader() { printf 'no-newline-here' | _logs:reader api "$RD/api.log" "$RD/all.log"; }
      When call run_reader
      The contents of file "$RD/api.log" should include 'no-newline-here'
    End
  End

  Context '_logs:colorize (NO_COLOR) /'
    It 'splits the tag and passes plain text through'
      colorize_one() { printf 'api hello world\n' | _logs:colorize; }
      When call colorize_one
      The output should eq 'api hello world'
    End

    It 'compacts a JSON body'
      colorize_one() { printf 'api {"b":2,"a":1}\n' | _logs:colorize; }
      When call colorize_one
      The output should include '"b":2'
      The output should include 'api '
    End
  End

  Context 'logs:search:feed /'
    setup() { SD="$(mktemp -d "$SHELLSPEC_TMPBASE/feed.XXXXXX")"; }
    cleanup() { rm -rf "$SD"; }
    BeforeEach 'setup'
    AfterEach 'cleanup'

    It 'emits visible<TAB>raw and compacts JSON in the visible column'
      printf '%s\n' 'api {"level":"error"}' 'db connected' >"$SD/all.log"
      feed() { logs:search:feed "$SD/all.log" "" | tr '\t' '|'; }
      When call feed
      The line 1 of output should eq 'api {"level":"error"}|api {"level":"error"}'
      The line 2 of output should eq 'db connected|db connected'
    End
  End

  Context 'logs:search:preview /'
    It 'pretty-prints a JSON line (tagged)'
      When call logs:search:preview 'api {"a":1}'
      The output should include '"a"'
      The output should include '1'
    End

    It 'passes plain text through'
      When call logs:search:preview 'db just connected'
      The output should include 'just connected'
    End
  End

  Context '_logs:load_config /'
    setup() { CD="$(mktemp -d "$SHELLSPEC_TMPBASE/cfg.XXXXXX")"; }
    cleanup() { rm -rf "$CD"; }
    BeforeEach 'setup'
    AfterEach 'cleanup'

    It 'loads tag=command lines, skips comments/blanks, and lets the CLI win'
      printf '%s\n' '# a comment' 'web=echo web' 'db=echo cfg-db' '' >"$CD/.logs-services"
      load() {
        SERVICES=("db=echo cli-db")
        _logs:load_config "$CD/.logs-services"
        printf '%s\n' "${SERVICES[@]}"
      }
      When call load
      The line 1 of output should eq 'db=echo cli-db'
      The line 2 of output should eq 'web=echo web'
    End
  End

  Context '_logs:worker (end to end) /'
    setup() {
      WD="$(mktemp -d "$SHELLSPEC_TMPBASE/worker.XXXXXX")"
      : >"$WD/all.log"
      : >"$WD/.pids"
      __LOGS_RUN_DIR="$WD"
      __LOGS_FIFOS=()
    }
    cleanup() { rm -rf "$WD"; }
    BeforeEach 'setup'
    AfterEach 'cleanup'

    It 'captures a finite command to per-tag and consolidated files'
      run_worker() {
        _logs:worker w "$WD" "$WD/all.log" "printf 'one\ntwo\n'"
        wait
      }
      When call run_worker
      The contents of file "$WD/w.log" should include 'one'
      The contents of file "$WD/w.log" should include 'two'
      The contents of file "$WD/all.log" should include 'w one'
      The contents of file "$WD/all.log" should not include "$ESC"
    End
  End

  Context '_logs:cleanup (signal delivery) /'
    setup() {
      KD="$(mktemp -d "$SHELLSPEC_TMPBASE/clean.XXXXXX")"
      __LOGS_RUN_DIR="$KD"
      __LOGS_CLEANED=""
      __LOGS_FIFOS=()
      printf '%s\n' '4242' >"$KD/.pids"
      # record kill invocations instead of signalling real processes
      kill() { echo "kill $*" >>"$KD/kills.txt"; }
    }
    cleanup() {
      unset -f kill
      rm -rf "$KD"
    }
    BeforeEach 'setup'
    AfterEach 'cleanup'

    # On Linux (setsid present) the target is the negative process group "-4242";
    # on macOS the fallback signals the plain pid "4242". Both contain "4242".
    It 'signals the recorded process and is idempotent'
      run_cleanup() {
        _logs:cleanup
        _logs:cleanup # second call must be a no-op (guarded)
        cat "$KD/kills.txt"
      }
      When call run_cleanup
      The output should include '4242'
    End
  End
End
