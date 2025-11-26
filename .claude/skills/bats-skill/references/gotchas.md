# BATS Gotchas and Debugging Guide

## Critical Execution Model

**Every `.bats` file is evaluated n+1 times**:
1. First pass: Counts test cases
2. Subsequent passes: Runs each test in isolation

**Implication**: Code outside functions runs multiple times.

```bash
# BAD - Connects to database 11 times for 10 tests
echo "Connecting..."
DB_CONN=$(expensive_connection)

# GOOD - Connects once
setup_file() {
    export DB_CONN=$(expensive_connection)
}
```

---

## Negation Doesn't Fail Tests

**Problem**: Bash's `-e` excludes negated commands from causing failures.

```bash
@test "negation bug" {
    ! true  # Test PASSES (should fail!)
}
```

**Solutions**:

```bash
# Option 1: Use run ! (BATS 1.5+)
@test "correct" {
    run ! true
}

# Option 2: Explicit false
@test "correct" {
    ! true || false
}

# Option 3: Check status
@test "correct" {
    run true
    [ "$status" -ne 0 ]
}
```

---

## Pipes Don't Work with `run`

**Problem**: Bash parses `|` before function calls.

```bash
@test "pipe bug" {
    run echo "test" | grep "test"
    # Actually: (run echo "test") | grep "test"
    # grep runs OUTSIDE run!
}
```

**Solutions**:

```bash
# Option 1: bash -c wrapper
@test "correct" {
    run bash -c "echo 'test' | grep 'test'"
}

# Option 2: bats_pipe helper
@test "correct" {
    run bats_pipe echo "test" \| grep "test"
}

# Option 3: Function wrapper
my_pipeline() { echo "test" | grep "test"; }

@test "correct" {
    run my_pipeline
}
```

---

## `run` Always Succeeds

**Problem**: `run` returns 0 regardless of command exit status.

```bash
@test "always passes" {
    run false  # Test passes!
}
```

**Solution**: Always check `$status` or use assertions.

```bash
@test "correct" {
    run false
    assert_failure
}
```

---

## Variables Lost After `run`

**Problem**: `run` executes in a subshell.

```bash
@test "variable lost" {
    run export MY_VAR="value"
    echo "$MY_VAR"  # Empty!
}
```

**Solution**: Don't use `run` for state changes.

```bash
@test "correct" {
    export MY_VAR="value"
    echo "$MY_VAR"  # Works
}
```

---

## Background Tasks Hang Tests

**Problem**: Background processes inherit FD 3, preventing test termination.

```bash
@test "hangs forever" {
    long_running_process &
    # Test never completes!
}
```

**Solutions**:

```bash
# Option 1: Close FD 3
@test "correct" {
    long_running_process 3>&- &
    disown
}

# Option 2: Trap cleanup
@test "correct" {
    long_running_process &
    PID=$!
    trap "kill $PID 2>/dev/null" EXIT
}
```

---

## `[[` and `((` Don't Fail Tests

**Problem**: These constructs don't trigger `-e` exit.

```bash
@test "passes incorrectly" {
    [[ "foo" == "bar" ]]  # Test passes!
}
```

**Solution**: Use assertions or explicit status check.

```bash
@test "correct" {
    run bash -c '[[ "foo" == "bar" ]]'
    assert_failure
}
```

---

## Dynamic Test Registration Doesn't Work

**Problem**: Can't generate tests in loops.

```bash
# DOESN'T WORK - Redefines same function
for value in 1 2 3; do
    @test "test $value" {
        run process "$value"
    }
done
```

**Workaround**: Loop inside test or use CI matrix.

```bash
@test "process multiple values" {
    for value in 1 2 3; do
        run process "$value"
        assert_success
    done
}
```

---

## ANSI Color Codes Break Assertions

**Problem**: Scripts output colors that break string matching.

```bash
@test "fails due to colors" {
    run colorful_script
    assert_output "Success"  # Fails - output has escape codes
}
```

**Solutions**:

```bash
# Option 1: Set NO_COLOR
@test "correct" {
    NO_COLOR=1 run colorful_script
    assert_output "Success"
}

# Option 2: Strip colors
strip_colors() {
    sed 's/\x1b\[[0-9;]*m//g'
}

@test "correct" {
    run colorful_script
    clean=$(echo "$output" | strip_colors)
    [ "$clean" = "Success" ]
}
```

---

## Parallel Test Interference

**Problem**: Tests share state when run with `--jobs`.

```bash
# BAD - Race condition
@test "test A" {
    echo "data" > /tmp/shared_file
}

@test "test B" {
    echo "data" > /tmp/shared_file  # Conflict!
}
```

**Solution**: Use `$BATS_TEST_TMPDIR` for isolation.

```bash
@test "test A" {
    echo "data" > "$BATS_TEST_TMPDIR/file"
}
```

---

## `load` vs `source`

**Problem**: `load` only works with `.bash` files.

```bash
load 'my_script.sh'  # Error!
```

**Solution**:

```bash
# Use source for .sh files
source "${BATS_TEST_DIRNAME}/my_script.sh"

# Use load for .bash files (auto-appends extension)
load 'test_helper/common'
```

---

## Focus Mode Exit Code

**Problem**: `bats:focus` tag exits with 1 even on success.

```bash
# bats test_tags=bats:focus
@test "debug this" { }
# Exits 1 to prevent accidental CI commits
```

**Override for git bisect**:

```bash
BATS_NO_FAIL_FOCUS_RUN=1 bats test/
```

---

## Mocking External Commands

### Basic Mock (Stub)

```bash
@test "mock curl" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/curl" <<'EOF'
#!/bin/bash
echo '{"status":"ok"}'
exit 0
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/curl"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
    
    run my_script
    assert_output --partial "ok"
}
```

### Spy (Capture Arguments)

```bash
@test "verify arguments" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    export SPY_LOG="$BATS_TEST_TMPDIR/spy.log"
    
    cat > "$BATS_TEST_TMPDIR/bin/curl" <<'EOF'
#!/bin/bash
echo "$@" >> "$SPY_LOG"
echo '{"status":"ok"}'
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/curl"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
    
    run my_script "https://example.com"
    
    # Verify arguments
    run cat "$SPY_LOG"
    assert_output --partial "https://example.com"
}
```

### Function Override

```bash
@test "mock internal function" {
    # Source script to get functions
    source my_script.sh
    
    # Override function
    fetch_data() {
        echo "mocked response"
    }
    export -f fetch_data
    
    run process_data
    assert_output --partial "mocked"
}
```

---

## Making Scripts Testable

**Problem**: Scripts execute immediately when sourced.

```bash
# BAD - Untestable
#!/bin/bash
calculate_sum() { echo $(($1 + $2)); }
calculate_sum 10 20  # Runs immediately
```

**Solution**: Use "If Main" guard.

```bash
# GOOD - Testable
#!/bin/bash
calculate_sum() { echo $(($1 + $2)); }

main() {
    calculate_sum "$1" "$2"
}

# Only run if executed directly, not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

Now tests can source and test functions:

```bash
@test "test function" {
    source my_script.sh
    run calculate_sum 5 3
    assert_output "8"
}
```

---

## Debugging Techniques

### Print to Terminal

```bash
@test "debug output" {
    echo "Debug: $variable" >&3  # Goes to terminal
}
```

### Focus on Single Test

```bash
# bats test_tags=bats:focus
@test "debug this test" {
    # Only this test runs
}
```

### Bash Trace

```bash
bash -x test/bats/bin/bats test/my_test.bats
```

### Breakpoint

```bash
@test "pause for inspection" {
    echo "Pausing at: $(pwd)"
    read -p "Press enter to continue"
}
```

### Preserve Temp Directories

```bash
# Keep temp dirs on failure
BATSLIB_TEMP_PRESERVE_ON_FAILURE=1 bats test/

# Keep all temp dirs
bats --no-tempdir-cleanup test/
```

---

## Quick Troubleshooting Decision Tree

```
Test failing?
├─ Check $status explicitly? → Use assert_success/assert_failure
├─ Using pipes? → Use bash -c or bats_pipe
├─ Using negation? → Use run ! or || false
├─ Variables disappear? → Don't use run for assignments
├─ Can't see output? → Use assert_output or echo >&3
├─ Test hangs? → Check for background tasks, close FD 3
└─ Tests interfere? → Use $BATS_TEST_TMPDIR for isolation
```
