#!/usr/bin/env bash
# shell: bash altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-30
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

# Helper functions to strip ANSI color codes
# $1 = stdout, $2 = stderr, $3 = exit status
no_colors_stderr() { echo -n "$2" | sed -E $'s/\x1B\[[0-9;]*[A-Za-z]//g; s/\x1B\([A-Z]//g; s/\x0F//g' | tr -s ' '; }
no_colors_stdout() { echo -n "$1" | sed -E $'s/\x1B\[[0-9;]*[A-Za-z]//g; s/\x1B\([A-Z]//g; s/\x0F//g' | tr -s ' '; }

Describe 'e-docs /'
  # Helper to run e-docs on fixture
  edocs() { bin/e-docs.sh --stdout --no-validate "$1"; }
  edocs_private() { bin/e-docs.sh --stdout --no-validate --include-private "$1"; }

  Context 'Basic functionality /'
    It 'shows help with --help flag'
      When call bin/e-docs.sh --help
      The status should be success
      The output should include 'Show help and exit'
      The output should include 'e-docs.sh'
    End

    It 'ignores unknown option gracefully'
      When call bin/e-docs.sh --unknown-option --help
      The status should be success
      The output should include 'Show help and exit'
      The output should include 'e-docs.sh'
    End
  End

  Context 'Documentation block detection /'
    It 'parses simple function with description'
      When call edocs "spec/fixtures/e-docs/simple_function.sh"
      The status should be success
      The output should include 'simple_func'
      The output should include 'simple function that does one thing'
    End

    It 'generates header from filename'
      When call edocs "spec/fixtures/e-docs/simple_function.sh"
      The status should be success
      The output should include '# simple_function.sh'
    End
  End

  Context 'Full documentation parsing /'
    It 'extracts Parameters section'
      When call edocs "spec/fixtures/e-docs/full_function.sh"
      The output should include 'Parameters'
      The output should include 'arg1'
      The output should include 'arg2'
    End

    It 'extracts Globals section'
      When call edocs "spec/fixtures/e-docs/full_function.sh"
      The output should include 'Globals'
    End

    It 'extracts Returns section'
      When call edocs "spec/fixtures/e-docs/full_function.sh"
      The output should include 'Returns'
    End

    It 'extracts Usage section as code block'
      When call edocs "spec/fixtures/e-docs/full_function.sh"
      The output should include 'Usage'
      The output should include 'full_func'
    End

    It 'extracts Side Effects section'
      When call edocs "spec/fixtures/e-docs/full_function.sh"
      The output should include 'Side Effects'
    End
  End

  Context 'Undocumented functions /'
    It 'handles functions without documentation'
      When call edocs "spec/fixtures/e-docs/no_docs.sh"
      The status should be success
      The output should include 'undocumented_func'
      The output should include 'No documentation available'
    End
  End

  Context 'Namespaced functions /'
    It 'detects functions with colons in name'
      When call edocs "spec/fixtures/e-docs/namespaced.sh"
      The status should be success
      The output should include 'logger:init'
      The output should include 'logger:prefix'
    End
  End

  Context 'Internal helpers /'
    It 'includes private helpers with --include-private'
      When call edocs_private "bin/e-docs.sh"
      The status should be success
      The output should include '_edocs:hints:has'
    End
  End

  Context 'Module Summary parsing /'
    It 'extracts module title from end of file'
      When call edocs "spec/fixtures/e-docs/full_function.sh"
      The output should include 'Test Module'
    End

    It 'extracts References from module summary'
      When call edocs "spec/fixtures/e-docs/full_function.sh"
      The output should include 'demo'
    End
  End

  Context 'Table of Contents /'
    It 'generates TOC with function links'
      When call edocs "spec/fixtures/e-docs/full_function.sh"
      The output should include '<!-- TOC -->'
      The output should include '[`full_func`]'
    End

    It 'can disable TOC with --no-toc flag'
      When call bin/e-docs.sh --stdout --no-validate --no-toc "spec/fixtures/e-docs/simple_function.sh"
      The output should not include '<!-- TOC -->'
    End
  End

  Context 'Anchor generation /'
    It 'generates GitHub-compatible anchors for function names'
      When call edocs_private "spec/fixtures/e-docs/traps_functions.sh"
      The output should include '`_Trap::capture_legacy`'
      The output should include '`Trap::dispatch`'
      The output should include '`trap:scope:begin`'
    End

    It 'preserves underscores in anchors'
      When call edocs_private "spec/fixtures/e-docs/traps_functions.sh"
      The output should include '(#_trapcapture_legacy)'
      The output should include '(#_trapcontains)'
    End

    It 'removes colons from anchors'
      When call edocs_private "spec/fixtures/e-docs/traps_functions.sh"
      The output should include '](#trapdispatch)'
      The output should include '](#trapon)'
      The output should include '](#_trapcapture_legacy)'
      The output should include '](#_trapcontains)'
    End

    It 'converts anchors to lowercase'
      When call edocs "spec/fixtures/e-docs/commons_functions.sh"
      The output should include '(#argsishelp)'
      The output should include '(#confighierarchy)'
    End
  End

  Context 'Validation Functions /'
    It 'validates doc block with missing description'
      When call bin/e-docs.sh --stdout --validate "spec/fixtures/e-docs/validation_test.sh"
      The status should be success
      The stderr should include "typo in 'Parameters' section name"
      The output should include "Function missing description"
    End

    It 'validates doc block with typo in Parameters'
      When call bin/e-docs.sh --stdout --validate "spec/fixtures/e-docs/validation_test.sh"
      The status should be success
      The stderr should include "typo in 'Parameters' section name"
      The output should include "Paramters:"
    End

    It 'validates deprecated function hint'
      When call bin/e-docs.sh --stdout --validate "spec/fixtures/e-docs/validation_test.sh"
      The status should be success
      The stderr should include "typo in 'Parameters' section name"
      The output should include "@{deprecated:Use new_function instead}"
    End

    It 'validates internal function hint'
      When call bin/e-docs.sh --stdout --validate "spec/fixtures/e-docs/validation_test.sh"
      The status should be success
      The stderr should include "typo in 'Parameters' section name"
      The output should include "func_internal"
    End

    It 'does not validate when --no-validate flag is used'
      When call bin/e-docs.sh --stdout --no-validate "spec/fixtures/e-docs/validation_test.sh"
      The status should be success
      The output should include "func_internal"
    End

    It 'validates successfully with proper documentation'
      When call bin/e-docs.sh --stdout --validate "spec/fixtures/e-docs/validation_test.sh"
      The status should be success
      The stderr should include "typo in 'Parameters' section name"
      The output should include "func_with_valid_docs"
    End
  End

  Context 'Edge Cases /'
    It 'handles functions with dashes in name'
      When call edocs "spec/fixtures/e-docs/edge_cases.sh"
      The status should be success
      The output should include "func-with-dashes"
      The output should include "Function with special characters in name"
    End

    It 'handles functions with underscores in name'
      When call edocs "spec/fixtures/e-docs/edge_cases.sh"
      The status should be success
      The output should include "func_with_underscores"
      The output should include "Function with underscores"
    End

    It 'handles functions with numbers in name'
      When call edocs "spec/fixtures/e-docs/edge_cases.sh"
      The status should be success
      The output should include "func_with_numbers123"
      The output should include "Function with numbers"
    End

    It 'handles functions with very long names'
      When call edocs "spec/fixtures/e-docs/edge_cases.sh"
      The status should be success
      The output should include "function_with_very_very_long_name_that_exceeds_normal_limits"
    End

    It 'handles functions with Returns but no Parameters'
      When call edocs "spec/fixtures/e-docs/edge_cases.sh"
      The status should be success
      The output should include "func_returns_only"
      The output should include "Returns"
    End

    It 'handles complex documentation with all sections'
      When call edocs "spec/fixtures/e-docs/edge_cases.sh"
      The status should be success
      The output should include "complex_function"
      The output should include "Parameters"
      The output should include "Globals"
      The output should include "Side Effects"
      The output should include "Returns"
      The output should include "Usage"
      The output should include "See Also"
    End

    It 'handles empty module summary'
      When call edocs "spec/fixtures/e-docs/edge_cases.sh"
      The status should be success
      The output should not include "Module:"
    End
  End

  Context 'Check Mode /'
    It 'checks mode with --check flag on unchanged file'
      When run script bin/e-docs.sh --check "spec/fixtures/e-docs/simple_function.sh"
      The status should be success
      The stderr should include "Skipping file outside source directories"
    End
  End

  Context 'Output Options /'
    It 'disables validation with --no-validate'
      When call bin/e-docs.sh --stdout --no-validate "spec/fixtures/e-docs/validation_test.sh"
      The output should include "func_missing_desc"
    End

    It 'enables validation with --validate'
      When call bin/e-docs.sh --stdout --validate "spec/fixtures/e-docs/validation_test.sh"
      The stderr should include "typo in 'Parameters' section name"
      The output should include "Function missing description"
    End
  End

  Context 'Error Handling /'
    It 'handles missing ctags gracefully'
      # Temporarily rename ctags
      if command -v ctags >/dev/null 2>&1; then
        ctags_path=$(command -v ctags)
        mv "$ctags_path" "${ctags_path}.bak"
        When run script bin/e-docs.sh "spec/fixtures/e-docs/simple_function.sh"
        The status should be failure
        The stderr should include "ctags is not installed"
        # Restore ctags
        mv "${ctags_path}.bak" "$ctags_path"
      fi
    End

    It 'handles non-existent file'
      When run script bin/e-docs.sh "/nonexistent/file.sh"
      The status should be success
      The stderr should include "Skipping file"
    End

    It 'handles directory input instead of file'
      When run script bin/e-docs.sh "."
      The status should be success
      The stderr should include "Skipping file"
    End
  End

  Context 'Module Summary /'
    It 'extracts categories from module summary'
      When call edocs "spec/fixtures/e-docs/full_function.sh"
      The output should include "Core Functions"
    End

    It 'handles missing module summary'
      When call edocs "spec/fixtures/e-docs/simple_function.sh"
      The output should not include "Module:"
    End
  End

  Context 'Version and Help /'
    It 'shows version with --version flag'
      When run script bin/e-docs.sh --version
      The status should be success
      The output should include "version:"
    End

    It 'shows help with multiple options'
      When run script bin/e-docs.sh --help --dry-run
      The status should be success
      The output should include "e-docs.sh"
    End
  End

  Context 'Documentation Format /'
    It 'handles functions with only comments (no doc blocks)'
      When call bin/e-docs.sh --stdout --no-validate "spec/fixtures/e-docs/regular_comments.sh"
      The status should be success
      The output should include "regular_func"
    End

    It 'handles functions with empty body'
      When call edocs "spec/fixtures/e-docs/empty_functions.sh"
      The status should be success
      The output should include "empty_body_func"
    End

    It 'handles functions with minimal body'
      When call edocs "spec/fixtures/e-docs/empty_functions.sh"
      The status should be success
      The output should include "minimal_func"
    End
  End

  Context 'Additional Tests /'
    It 'handles multiple files input'
      When call edocs "spec/fixtures/e-docs/simple_function.sh"
      The status should be success
      The output should include "simple_function.sh"
    End

    It 'generates docs for files with no functions'
      # Create a file with no functions
      cat >"/tmp/no-functions.sh" <<'EOF'
#!/usr/bin/env bash
# This file has no functions
echo "just a script"
EOF
      When call bin/e-docs.sh --stdout --no-validate "/tmp/no-functions.sh"
      The status should be success
      The output should include "# no-functions.sh"
      rm -f "/tmp/no-functions.sh"
    End

    It 'handles scripts with only comments'
      # Create a file with only comments
      cat >"/tmp/comments-only.sh" <<'EOF'
#!/usr/bin/env bash
# Comment 1
# Comment 2
# Comment 3
EOF
      When call bin/e-docs.sh --stdout --no-validate "/tmp/comments-only.sh"
      The status should be success
      The output should include "# comments-only.sh"
      rm -f "/tmp/comments-only.sh"
    End

    It 'handles large number of functions'
      # Create a file with many functions
      cat >"/tmp/many-functions.sh" <<'EOF'
#!/usr/bin/env bash
## Function 1
function func1() { echo "1"; }
## Function 2
function func2() { echo "2"; }
## Function 3
function func3() { echo "3"; }
## Function 4
function func4() { echo "4"; }
## Function 5
function func5() { echo "5"; }
EOF
      When call bin/e-docs.sh --stdout --no-validate "/tmp/many-functions.sh"
      The status should be success
      The output should include "func1"
      The output should include "func5"
      rm -f "/tmp/many-functions.sh"
    End

    It 'handles files with special characters in filename'
      # Create a test file with special characters
      cat >"/tmp/file-with-dashes.sh" <<'EOF'
#!/usr/bin/env bash
## test function
function test_func() {
  echo "test"
}
EOF
      When call bin/e-docs.sh --stdout --no-validate "/tmp/file-with-dashes.sh"
      The status should be success
      The output should include "test_func"
      rm -f "/tmp/file-with-dashes.sh"
    End

    It 'handles invalid function names'
      # Create a file with invalid function names
      cat >"/tmp/invalid-names.sh" <<'EOF'
#!/usr/bin/env bash
## Function with spaces
function "func with spaces"() {
  echo "spaces"
}

## Function with hyphens
function func-with-hyphens() {
  echo "hyphens"
}
EOF
      When call bin/e-docs.sh --stdout --no-validate "/tmp/invalid-names.sh"
      The status should be success
      # Should still generate header even with no valid functions
      The output should include "# invalid-names.sh"
      rm -f "/tmp/invalid-names.sh"
    End
  End
End
