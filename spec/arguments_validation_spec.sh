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

Describe 'args:validate /'
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
  # Enum validation
  # ============================================================
  Describe 'enum /'

    It 'accepts valid enum value'
      helper() {
        export ARGS_DEFINITION="--format=format:json:1"
        parse:arguments --format csv
        args:t "--format" "enum:json,csv,text"
        args:validate
      }
      When call helper
      The status should be success
    End

    It 'rejects invalid enum value'
      helper() {
        export ARGS_DEFINITION="--format=format:json:1"
        parse:arguments --format xml
        args:t "--format" "enum:json,csv,text"
        args:validate
      }
      When call helper
      The status should be failure
      The stderr should include "not one of"
      The stderr should include "xml"
    End

    It 'accepts default enum value (pre-filled)'
      helper() {
        export ARGS_DEFINITION="--format=format:json:1"
        parse:arguments  # no --format, default "json" pre-filled
        args:t "--format" "enum:json,csv,text"
        args:validate
      }
      When call helper
      The status should be success
    End
  End

  # ============================================================
  # Integer validation
  # ============================================================
  Describe 'int /'

    It 'accepts integer in range'
      helper() {
        export ARGS_DEFINITION="--count=count::1"
        parse:arguments --count 50
        args:t "--count" "int:1:100"
        args:validate
      }
      When call helper
      The status should be success
    End

    It 'rejects value below minimum'
      helper() {
        export ARGS_DEFINITION="--count=count::1"
        parse:arguments --count 0
        args:t "--count" "int:1:100"
        args:validate
      }
      When call helper
      The status should be failure
      The stderr should include "below minimum"
    End

    It 'rejects value above maximum'
      helper() {
        export ARGS_DEFINITION="--count=count::1"
        parse:arguments --count 200
        args:t "--count" "int:1:100"
        args:validate
      }
      When call helper
      The status should be failure
      The stderr should include "exceeds maximum"
    End

    It 'rejects non-integer input'
      helper() {
        export ARGS_DEFINITION="--count=count::1"
        parse:arguments --count abc
        args:t "--count" "int:1:100"
        args:validate
      }
      When call helper
      The status should be failure
      The stderr should include "not an integer"
    End

    It 'accepts negative integer in range'
      helper() {
        export ARGS_DEFINITION="--offset=offset::1"
        parse:arguments --offset -5
        args:t "--offset" "int:-10:10"
        args:validate
      }
      When call helper
      The status should be success
    End

    It 'accepts boundary values'
      helper() {
        export ARGS_DEFINITION="--port=port::1"
        parse:arguments --port 1
        args:t "--port" "int:1:65535"
        args:validate
      }
      When call helper
      The status should be success
    End
  End

  # ============================================================
  # Float validation
  # ============================================================
  Describe 'float /'

    It 'accepts float in range'
      helper() {
        export ARGS_DEFINITION="--ratio=ratio::1"
        parse:arguments --ratio 0.75
        args:t "--ratio" "float:0.0:1.0"
        args:validate
      }
      When call helper
      The status should be success
    End

    It 'rejects float above maximum'
      helper() {
        export ARGS_DEFINITION="--ratio=ratio::1"
        parse:arguments --ratio 1.5
        args:t "--ratio" "float:0.0:1.0"
        args:validate
      }
      When call helper
      The status should be failure
      The stderr should include "exceeds maximum"
    End

    It 'rejects non-numeric input'
      helper() {
        export ARGS_DEFINITION="--ratio=ratio::1"
        parse:arguments --ratio abc
        args:t "--ratio" "float:0.0:1.0"
        args:validate
      }
      When call helper
      The status should be failure
      The stderr should include "not a number"
    End
  End

  # ============================================================
  # String length validation
  # ============================================================
  Describe 'string /'

    It 'accepts string within length bounds'
      helper() {
        export ARGS_DEFINITION="--name=name::1"
        parse:arguments --name "Alice"
        args:t "--name" "string:2:50"
        args:validate
      }
      When call helper
      The status should be success
    End

    It 'rejects string too short'
      helper() {
        export ARGS_DEFINITION="--name=name::1"
        parse:arguments --name "A"
        args:t "--name" "string:2:50"
        args:validate
      }
      When call helper
      The status should be failure
      The stderr should include "shorter than minimum"
    End

    It 'rejects string too long'
      helper() {
        export ARGS_DEFINITION="--code=code::1"
        parse:arguments --code "ABCDEF"
        args:t "--code" "string:1:3"
        args:validate
      }
      When call helper
      The status should be failure
      The stderr should include "longer than maximum"
    End
  End

  # ============================================================
  # Pattern validation
  # ============================================================
  Describe 'pattern /'

    It 'accepts value matching regex'
      helper() {
        export ARGS_DEFINITION="--email=email::1"
        parse:arguments --email "user@example.com"
        args:t "--email" "pattern:^[^@]+@[^@]+$"
        args:validate
      }
      When call helper
      The status should be success
    End

    It 'rejects value not matching regex'
      helper() {
        export ARGS_DEFINITION="--email=email::1"
        parse:arguments --email "not-an-email"
        args:t "--email" "pattern:^[^@]+@[^@]+$"
        args:validate
      }
      When call helper
      The status should be failure
      The stderr should include "does not match pattern"
    End
  End

  # ============================================================
  # Skips and edge cases
  # ============================================================
  Describe 'edge cases /'

    It 'skips validation for unset variables'
      helper() {
        export ARGS_DEFINITION="--count=count::1"
        parse:arguments  # count gets default "" (empty), but no default in def
        args:t "--count" "int:1:100"
        args:validate
      }
      When call helper
      # count has no default (empty), pre-fill skips it, variable unset → skip validation
      The status should be success
    End

    It 'validates multiple rules - all pass'
      helper() {
        export ARGS_DEFINITION="--port=port:8080:1 --format=format:json:1"
        parse:arguments --port 443 --format csv
        args:t "--port" "int:1:65535"
        args:t "--format" "enum:json,csv,text"
        args:validate
      }
      When call helper
      The status should be success
    End

    It 'validates multiple rules - first failure stops'
      helper() {
        export ARGS_DEFINITION="--port=port:8080:1 --format=format:json:1"
        parse:arguments --port 99999 --format csv
        args:t "--port" "int:1:65535"
        args:t "--format" "enum:json,csv,text"
        args:validate
      }
      When call helper
      The status should be failure
      The stderr should include "exceeds maximum"
    End

    It 'works with scoped parsing'
      helper() {
        export ARGS_DEFINITION="\$1=cmd::1"
        parse:arguments deploy --replicas 200
        local SCOPE="--replicas=replicas:1:1"
        args:scope SCOPE "${ARGS_UNPARSED[@]}"
        args:t "--replicas" "int:1:100"
        args:validate
      }
      When call helper
      The status should be failure
      The stderr should include "exceeds maximum"
    End
  End
End
