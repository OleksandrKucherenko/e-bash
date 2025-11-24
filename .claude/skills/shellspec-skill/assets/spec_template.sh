#!/bin/bash
# ShellSpec Template - Best Practices Example
#
# Copy and modify this template for your tests

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-11-24
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


#shellcheck shell=sh

Describe 'ModuleName'
  # Load script under test
  Include lib/your_module.sh
  
  # Global setup/teardown
  BeforeAll 'setup_global'
  AfterAll 'cleanup_global'
  
  setup_global() {
    export GLOBAL_VAR="value"
  }
  
  cleanup_global() {
    unset GLOBAL_VAR
  }
  
  # Per-test setup/teardown
  BeforeEach 'setup_test'
  AfterEach 'cleanup_test'
  
  setup_test() {
    TEST_DIR=$(mktemp -d)
    export TEST_DIR
    setup_mocks
  }
  
  cleanup_test() {
    rm -rf "$TEST_DIR"
  }
  
  setup_mocks() {
    # Mock external commands
    curl() {
      echo '{"status": "success"}'
      return 0
    }
    
    date() {
      echo "2024-01-01 00:00:00"
    }
  }
  
  # Test groups
  Context 'when input is valid'
    It 'processes input successfully'
      # GIVEN
      local input="test_data"
      
      # WHEN
      When call your_function "$input"
      
      # THEN
      The status should be success
      The output should include "processed"
    End
    
    It 'returns correct format'
      When call your_function "data"
      The output should match pattern '[0-9]{4}-[0-9]{2}-[0-9]{2}'
    End
  End
  
  Context 'when input is invalid'
    It 'handles empty input'
      When call your_function ""
      The status should be failure
      The stderr should include "cannot be empty"
    End
  End
  
  # Parameterized tests
  Context 'with various inputs'
    Parameters
      "case1" "value1" "output1" 0
      "case2" "value2" "output2" 0
      "case3" "invalid" "error" 1
    End
    
    It "handles $1"
      When call your_function "$2"
      The status should eq $4
      The output should include "$3"
    End
  End
  
  # Error handling
  Describe 'error_handling()'
    It 'logs errors to stderr'
      When call error_function
      The status should be failure
      The stderr should include "ERROR:"
    End
  End
  
  # Side effects
  Describe 'side_effects()'
    It 'creates expected files'
      When call create_file "$TEST_DIR/output.txt"
      The path "$TEST_DIR/output.txt" should be file
    End
  End
  
  # Mock different endpoints
  Describe 'external_dependencies()'
    Mock curl
      case "$2" in
        *"/success"*) echo '{"status": "ok"}' ;;
        *"/error"*) echo '{"status": "error"}' >&2; return 1 ;;
      esac
    End
    
    It 'handles success'
      When call api_call "/success"
      The status should be success
    End
  End
  
  # Spy pattern
  Describe 'call_verification()'
    setup_spy() {
      call_log=""
      tracked_function() {
        call_log="${call_log}$*;"
        echo "result"
      }
    }
    
    BeforeEach 'setup_spy'
    
    It 'tracks calls'
      When call wrapper_function "arg1"
      The variable call_log should include "arg1"
    End
  End
  
  # Conditional tests
  Describe 'conditional()'
    Skip if "[ -z \"$CI\" ]" "CI only"
    
    It 'runs in CI'
      When call ci_function
      The status should be success
    End
  End
End

# Tips:
# 1. Replace 'ModuleName' with actual name
# 2. Update Include path
# 3. Customize setup_mocks()
# 4. Use fIt/fDescribe during TDD
# 5. Run: shellspec spec/your_spec.sh
#
# Commands:
#   shellspec                  # All tests
#   shellspec --focus          # Focused tests
#   shellspec --quick          # Failed tests
#   shellspec --xtrace         # Debug trace
#   shellspec --kcov           # Coverage
