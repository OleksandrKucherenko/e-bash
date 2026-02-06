#!/usr/bin/env bash
# shell: bash altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-02-06
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

Describe 'args:completion /'
  BeforeRun 'export DEBUG="*"'
  Include ".scripts/_arguments.sh"

  Mock echo:Common
    echo "$@"
  End

  Mock echo:Parser
    echo "$@"
  End

  Mock printf:Common
    printf "$@" # dummy
  End

  Mock printf:Parser
    printf "$@" # dummy
  End

  Describe '_args:get:all_flags() /'

    It 'returns all flags excluding positional arguments'
      BeforeCall 'export ARGS_DEFINITION="-h,--help -v,--verbose --output=::1 \$1,<command>=cmd:dummy:1"'

      When call eval 'parse:mapping && _args:get:all_flags'

      The status should be success
      The stdout should include '-h'
      The stdout should include '--help'
      The stdout should include '-v'
      The stdout should include '--verbose'
      The stdout should include '--output'
      The stdout should not include '$1'
      The stdout should not include '<command>'
    End

    It 'returns empty for positional-only definitions'
      BeforeCall 'export ARGS_DEFINITION="\$1,<command>=cmd:dummy:1"'

      When call eval 'parse:mapping && _args:get:all_flags'

      The status should be success
      # stdout should only contain mapping debug output, no flags
    End
  End

  Describe '_args:get:value_flags() /'

    It 'identifies flags that expect values'
      BeforeCall 'export ARGS_DEFINITION="-h,--help -o,--output=output::1 -f,--format=format:text:1"'

      When call eval 'parse:mapping && _args:get:value_flags'

      The status should be success
      The stdout should include '-o'
      The stdout should include '--output'
      The stdout should include '-f'
      The stdout should include '--format'
      The stdout should not include '-h'
      The stdout should not include '--help'
    End

    It 'returns empty when no flags expect values'
      BeforeCall 'export ARGS_DEFINITION="-h,--help -v,--verbose"'

      When call eval 'parse:mapping && _args:get:value_flags'

      The status should be success
      # No value flags expected
    End
  End

  Describe '_args:get:description() /'

    It 'returns description for a registered flag'
      setup() {
        export ARGS_DEFINITION="-h,--help"
        parse:mapping
        args:d "-h" "Show help and exit."
      }
      BeforeCall 'setup'

      When call _args:get:description "-h"

      The status should be success
      The stdout should eq "Show help and exit."
    End

    It 'returns empty for unknown flag'
      setup() {
        export ARGS_DEFINITION="-h,--help"
        parse:mapping
      }
      BeforeCall 'setup'

      When call _args:get:description "--unknown"

      The status should be success
      The stdout should eq ""
    End
  End

  Describe 'args:completion() /'

    It 'prints usage on missing arguments'
      When call args:completion

      The status should be failure
      The stderr should include 'Usage:'
    End

    It 'rejects unsupported shell type'
      BeforeCall 'export ARGS_DEFINITION="-h,--help"'

      When call args:completion fish myscript

      The status should be failure
      The stderr should include "unsupported shell type"
    End
  End

  Describe '_args:completion:bash /'

    It 'generates valid bash completion script with flags'
      setup() {
        export ARGS_DEFINITION="-h,--help -v,--verbose -o,--output=output::1"
        parse:mapping
      }
      BeforeCall 'setup'

      When call _args:completion:bash myscript

      The status should be success
      The stdout should include 'complete -F _myscript_complete myscript'
      The stdout should include '_myscript_complete()'
      The stdout should include '-h'
      The stdout should include '--help'
      The stdout should include '-v'
      The stdout should include '--verbose'
      The stdout should include '--output'
      The stdout should include 'compgen'
    End

    It 'includes value flags in the completion script'
      setup() {
        export ARGS_DEFINITION="-h,--help -o,--output=output::1"
        parse:mapping
      }
      BeforeCall 'setup'

      When call _args:completion:bash myscript

      The status should be success
      The stdout should include 'value_flags='
      The stdout should include '-o'
      The stdout should include '--output'
    End

    It 'sanitizes script name with special characters'
      setup() {
        export ARGS_DEFINITION="-h,--help"
        parse:mapping
      }
      BeforeCall 'setup'

      When call _args:completion:bash "my-script.sh"

      The status should be success
      The stdout should include '_my_script_sh_complete()'
      The stdout should include 'complete -F _my_script_sh_complete my-script.sh'
    End

    It 'handles empty ARGS_DEFINITION'
      setup() {
        export ARGS_DEFINITION=""
        parse:mapping
      }
      BeforeCall 'setup'

      When call _args:completion:bash myscript

      The status should be success
      The stdout should include 'complete -F _myscript_complete myscript'
    End
  End

  Describe '_args:completion:zsh /'

    It 'generates valid zsh completion script with compdef'
      setup() {
        export ARGS_DEFINITION="-h,--help -v,--verbose -o,--output=output::1"
        parse:mapping
        args:d "-h" "Show help and exit."
        args:d "-v" "Enable verbose output."
        args:d "-o" "Output file path."
      }
      BeforeCall 'setup'

      When call _args:completion:zsh myscript

      The status should be success
      The stdout should include '#compdef myscript'
      The stdout should include '_myscript()'
      The stdout should include '_arguments -s -S'
      The stdout should include '_myscript "$@"'
    End

    It 'includes descriptions in zsh completion'
      setup() {
        export ARGS_DEFINITION="-h,--help"
        parse:mapping
        args:d "-h" "Show help and exit."
      }
      BeforeCall 'setup'

      When call _args:completion:zsh myscript

      The status should be success
      The stdout should include 'Show help and exit.'
    End

    It 'marks value flags with :value:_files'
      setup() {
        export ARGS_DEFINITION="-o,--output=output::1"
        parse:mapping
        args:d "-o" "Output file path."
      }
      BeforeCall 'setup'

      When call _args:completion:zsh myscript

      The status should be success
      The stdout should include ':value:_files'
    End

    It 'handles empty ARGS_DEFINITION'
      setup() {
        export ARGS_DEFINITION=""
        parse:mapping
      }
      BeforeCall 'setup'

      When call _args:completion:zsh myscript

      The status should be success
      The stdout should include '#compdef myscript'
      The stdout should include '_myscript()'
    End
  End

  Describe 'args:completion integration /'

    It 'generates bash completion via args:completion function'
      setup() {
        export ARGS_DEFINITION="-h,--help --verbose -o,--output=output::1"
        parse:mapping
      }
      BeforeCall 'setup'

      When call args:completion bash testscript

      The status should be success
      The stdout should include 'complete -F _testscript_complete testscript'
      The stdout should include '--help'
      The stdout should include '--verbose'
      The stdout should include '--output'
    End

    It 'generates zsh completion via args:completion function'
      setup() {
        export ARGS_DEFINITION="-h,--help --verbose"
        parse:mapping
        args:d "-h" "Show help."
        args:d "--verbose" "Verbose mode."
      }
      BeforeCall 'setup'

      When call args:completion zsh testscript

      The status should be success
      The stdout should include '#compdef testscript'
      The stdout should include '_arguments -s -S'
    End

    It 'writes to output file when third argument provided'
      setup() {
        export ARGS_DEFINITION="-h,--help"
        parse:mapping
      }
      BeforeCall 'setup'

      output_file="${SHELLSPEC_TMPBASE}/completion_output.bash"

      When call args:completion bash testscript "$output_file"

      The status should be success
      The file "$output_file" should be exist
    End

    It 'generates completion for real-world npm.versions-like definition'
      setup() {
        export ARGS_DEFINITION=""
        ARGS_DEFINITION+=" -h,--help=help"
        ARGS_DEFINITION+=" -r,--registry=REGISTRY:https://registry.npmjs.org:1"
        ARGS_DEFINITION+=" --dry-run=DRY_RUN:true"
        ARGS_DEFINITION+=" --silent=SILENT_NPM:true"
        ARGS_DEFINITION+=" \$1,<package-name>=PACKAGE_NAME:@scope/pkg"
        parse:mapping
      }
      BeforeCall 'setup'

      When call args:completion bash npm-versions

      The status should be success
      The stdout should include '-h'
      The stdout should include '--help'
      The stdout should include '-r'
      The stdout should include '--registry'
      The stdout should include '--dry-run'
      The stdout should include '--silent'
      The stdout should not include '$1'
      The stdout should not include '<package-name>'
    End
  End
End
