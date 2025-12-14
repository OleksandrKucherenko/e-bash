# ShellSpec Troubleshooting Guide

Systematic approaches to debugging test failures and preparing scripts for testability.

## Debugging Workflow

### Decision Tree

```
Test Fails
├─> Run with --xtrace (execution trace)
├─> Use Dump directive (inspect output)
├─> Run --syntax-check (verify spec)
├─> Run --translate (see generated code)
└─> Isolate with --focus (run single test)
```

### Systematic Process

**Step 1: Verify Spec Syntax**
```bash
shellspec --syntax-check spec/my_spec.sh
```

**Step 2: Enable Trace Mode**
```bash
shellspec --xtrace spec/my_spec.sh
```

**Step 3: Inspect Generated Code**
```bash
shellspec --translate spec/my_spec.sh
```

**Step 4: Use Dump**
```bash
It 'fails mysteriously'
  When call my_function "input"
  Dump  # Shows stdout, stderr, status
  The output should eq "expected"
End
```

**Step 5: Run Single Test**
```bash
shellspec spec/my_spec.sh:42
```

## Running One Test Only

### Multiple Approaches

```bash
# 1. Specific file
shellspec spec/my_module_spec.sh

# 2. Specific line
shellspec spec/my_module_spec.sh:42

# 3. By example ID
shellspec spec/my_module_spec.sh:@1-5

# 4. By pattern
shellspec --example "handles empty input"

# 5. Tagged tests
shellspec --tag critical:true

# 6. Focus mode
fIt 'only run this'
  When call my_function
End

shellspec --focus

# 7. Quick mode (failed tests only)
shellspec --quick
```

## Isolating Failed Specs

### Differentiating Test vs. Script Issues

**Diagnostic Questions**:
1. Does test fail when run alone?
2. Does test fail with `--xtrace`?
3. Does script work manually?
4. Did recent changes break it?

**Isolation Strategy**:

```bash
# Step 1: Run alone
shellspec spec/my_spec.sh:42

# Step 2: Check spec syntax
shellspec --syntax-check spec/my_spec.sh

# Step 3: Test minimal script
mv lib/module.sh lib/module.sh.backup
cat > lib/module.sh << 'EOF'
my_function() {
  echo "minimal"
  return 0
}
EOF

shellspec spec/my_spec.sh:42

# If passes, issue is in script
# If fails, issue is in test
mv lib/module.sh.backup lib/module.sh
```

## Common Failure Patterns

### Pattern 1: Global State Leakage

```bash
# BAD: Modifies global state
Describe 'leaky tests'
  COUNTER=0
  
  It 'test 1'
    COUNTER=$((COUNTER + 1))
    The variable COUNTER should eq 1
  End
  
  It 'test 2'
    # Fails because COUNTER is already 1
    The variable COUNTER should eq 0
  End
End

# GOOD: Reset state
Describe 'isolated tests'
  BeforeEach 'reset_counter'
  
  reset_counter() {
    COUNTER=0
  }
  
  It 'test 1'
    COUNTER=$((COUNTER + 1))
    The variable COUNTER should eq 1
  End
  
  It 'test 2'
    The variable COUNTER should eq 0
  End
End
```

### Pattern 2: Unmocked Dependencies

```bash
# BAD: Hits real network
It 'fetches data'
  When call fetch_from_api
  The output should include "data"
End

# GOOD: Mock the dependency
Mock curl
  echo '{"data": "mocked"}'
End

It 'fetches data'
  When call fetch_from_api
  The output should include "data"
End
```

## Preparing Scripts for Testing

### Refactoring Example

**Before: Untestable**
```bash
#!/bin/bash
# Runs immediately when sourced
curl https://api.example.com > /tmp/data.json
/usr/local/bin/process /tmp/data.json
```

**After: Testable**
```bash
#!/bin/bash

# Functions
fetch_data() {
  local url="${1:-https://api.example.com}"
  local curl_cmd="${CURL_CMD:-curl}"
  "$curl_cmd" "$url"
}

process_data() {
  local input="$1"
  local processor="${PROCESSOR:-/usr/local/bin/process}"
  "$processor" "$input"
}

# Main function
main() {
  fetch_data > /tmp/data.json
  process_data /tmp/data.json
}

# Source guard
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
```

**Test File**
```bash
Describe 'testable_script'
  Include testable_script.sh
  
  Mock curl
    echo "mock data"
  End
  
  It 'fetches data'
    When call fetch_data
    The output should eq "mock data"
  End
End
```

### Source Guard Patterns

**Pattern 1: Bash/Zsh**
```bash
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
```

**Pattern 2: POSIX Compatible**
```bash
if [ "$(basename -- "$0")" = "myscript.sh" ]; then
  main "$@"
fi
```

**Pattern 3: ShellSpec Flag**
```bash
${__SOURCED__:+return}
main "$@"
```

## Common Error Messages

### "Command not found"
**Cause**: Unmocked external command
**Solution**: Add Mock block

### "Function not found"
**Cause**: Script not sourced
**Solution**: Add `Include` directive

### "Permission denied"
**Cause**: Script not executable
**Solution**: `chmod +x script.sh` or use `sh script.sh`

### "Variable not preserved"
**Cause**: Variable in subshell
**Solution**: Use `%preserve` directive

## Quick Diagnostic Script

Create `debug_test.sh`:

```bash
#!/bin/bash
spec_file="$1"

echo "=== Diagnostics ==="
echo "1. Syntax Check:"
shellspec --syntax-check "$spec_file"

echo "2. Translation:"
shellspec --translate "$spec_file" | head -30

echo "3. Run Test:"
shellspec "$spec_file"

echo "Next: shellspec --xtrace $spec_file"
```

**Usage**: `./debug_test.sh spec/failing_spec.sh`

## Best Practices Checklist

### Do's
✅ Run tests in isolation first
✅ Use `--xtrace` to see execution
✅ Use `Dump` to inspect state
✅ Mock all external dependencies
✅ Add source guards to scripts
✅ Use temp directories
✅ Clean up in `AfterEach`

### Don'ts
❌ Ignore failed tests
❌ Use global state
❌ Hard-code paths
❌ Skip test isolation
❌ Forget cleanup
❌ Leave `fIt` in commits
