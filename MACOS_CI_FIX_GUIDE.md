# macOS CI Test Failures - Fix Guide

## Root Cause Analysis

The macOS CI failures are caused by two main issues:

### 1. Whitespace Normalization Issue ✅ FIXED
- **Problem**: Helper functions `no_colors_stderr()` and `no_colors_stdout()` were not properly trimming leading/trailing whitespace
- **Symptom**: Test failures like `Expected "defined in 2 contexts" vs Got "defined in        2 contexts"`
- **Fix**: Added `sed 's/^ *//; s/ *$//'` to properly trim whitespace after color code removal

### 2. Script Discovery Issue - Environment Variable Isolation ⚠️ PARTIALLY FIXED
- **Problem**: `BeforeAll` and `BeforeCall` setups don't persist `HOOKS_DIR` environment variable to test execution context in macOS CI
- **Symptom**: "No implementations found for hook" errors when scripts exist in `/tmp/test_hooks/`
- **Root Cause**: shellspec environment isolation on macOS differs from Linux

## Solution Pattern ✅ PROVEN TO WORK

Convert tests from `BeforeCall 'setup'` pattern to inline setup:

### Before (Failing on macOS):
```bash
It 'test description'
  setup() {
    hooks:define hook_name
    cat > /tmp/test_hooks/hook_name-test.sh <<'EOF'
#!/usr/bin/env bash
echo "test output"
EOF
    chmod +x /tmp/test_hooks/hook_name-test.sh
  }
  BeforeCall 'setup'

  When call on:hook hook_name

  The status should be success
  The output should eq "test output"
End
```

### After (Works on both Linux and macOS):
```bash
It 'test description'
  test_function_name() {
    # Set up test environment
    mkdir -p /tmp/test_hooks
    export HOOKS_DIR=/tmp/test_hooks
    
    hooks:define hook_name
    cat > /tmp/test_hooks/hook_name-test.sh <<'EOF'
#!/usr/bin/env bash
echo "test output"
EOF
    chmod +x /tmp/test_hooks/hook_name-test.sh
    
    on:hook hook_name
    
    # Clean up
    rm -f /tmp/test_hooks/hook_name-test.sh
  }

  When call test_function_name

  The status should be success
  The output should eq "test output"
End
```

### For Tests That Check Exit Codes:
```bash
test_function_name() {
  # Set up test environment
  mkdir -p /tmp/test_hooks
  export HOOKS_DIR=/tmp/test_hooks
  
  # ... setup code ...
  
  # Execute hook and capture exit code
  on:hook hook_name
  local exit_code=$?
  
  # Clean up
  rm -f /tmp/test_hooks/*
  
  # Return the captured exit code
  return $exit_code
}
```

## Tests Already Fixed ✅

1. "executes hook script when present"
2. "passes parameters to hook script" 
3. "propagates script exit code"
4. "executes function first, then scripts when both exist"

## Tests Still Needing Fixes ⚠️

The following tests still use the `BeforeCall 'setup'` pattern and need conversion:

1. "executes multiple scripts in alphabetical order"
2. "executes scripts with numbered pattern in order"
3. "passes parameters to all hook scripts"
4. "returns exit code of last executed script"
5. "executes function before scripts"
6. "skips non-matching script names"
7. "skips non-executable script files"
8. "lists multiple script implementations"
9. "supports both dash and underscore patterns"
10. "checks if hook has implementation - script"
11. "sources script and calls hook:run function"
12. "passes parameters to hook:run function"
13. "outputs warning when script lacks hook:run function"
14. "can access parent shell variables in sourced mode"
15. "executes hooks defined from multiple contexts"

## Verification

After applying fixes, verify with:
```bash
# Test individual fixed test
shellspec spec/hooks_spec.sh:LINE_NUMBER --no-kcov --format documentation

# Test all tests
shellspec --no-kcov --format progress
```

## Status

- ✅ Root cause identified and solution proven
- ✅ Whitespace normalization fixed
- ✅ 4 tests converted and verified working
- ⚠️ ~15 tests still need conversion
- 🎯 All tests should pass on both Linux and macOS after conversion

The fix pattern is systematic and proven. Each remaining test needs the same transformation applied.