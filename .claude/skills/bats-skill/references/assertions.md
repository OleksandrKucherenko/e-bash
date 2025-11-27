# BATS Assertions Reference

Complete reference for bats-assert and bats-file assertion libraries.

## Loading Libraries

```bash
setup() {
    load 'test_helper/bats-support/load'  # Required by bats-assert
    load 'test_helper/bats-assert/load'
    load 'test_helper/bats-file/load'
}
```

---

## Exit Status Assertions (bats-assert)

### assert_success

Verify command exited with status 0.

```bash
@test "command succeeds" {
    run my_command
    assert_success
}
```

On failure, prints:
```
-- command failed --
status : 1
output : Error message
```

### assert_failure

Verify command exited with non-zero status.

```bash
@test "command fails" {
    run my_command --invalid
    assert_failure
}

@test "specific exit code" {
    run my_command --not-found
    assert_failure 2
}
```

---

## Output Assertions (bats-assert)

### assert_output

Verify entire output matches expected value.

```bash
# Exact match
@test "exact output" {
    run echo "hello world"
    assert_output "hello world"
}

# Partial match (substring)
@test "partial output" {
    run echo "hello world"
    assert_output --partial "world"
}

# Regex match
@test "regex output" {
    run date
    assert_output --regexp "^[A-Z][a-z]{2} [A-Z][a-z]{2}"
}

# From stdin/heredoc
@test "multiline output" {
    run my_command
    assert_output <<EOF
line 1
line 2
EOF
}
```

### refute_output

Verify output does NOT match.

```bash
@test "no error in output" {
    run my_command
    refute_output --partial "ERROR"
}

@test "output is not empty" {
    run my_command
    refute_output ""
}
```

### assert_line

Verify specific line matches.

```bash
# Match any line
@test "any line" {
    run my_command
    assert_line "expected line"
}

# Match specific line by index (0-based)
@test "first line" {
    run my_command
    assert_line --index 0 "Header"
}

# Match last line
@test "last line" {
    run my_command
    assert_line --index -1 "Footer"
}

# Partial match on line
@test "partial line" {
    run my_command
    assert_line --index 0 --partial "Status:"
}

# Regex match on line
@test "regex line" {
    run my_command
    assert_line --index 0 --regexp "^[0-9]+:"
}
```

### refute_line

Verify line does NOT exist.

```bash
@test "no debug output" {
    run my_command
    refute_line --partial "DEBUG"
}
```

---

## Stderr Assertions (bats-assert)

When using `run --separate-stderr`:

```bash
@test "stderr assertions" {
    run --separate-stderr my_command
    
    # Check stderr
    assert_stderr "Error message"
    assert_stderr --partial "Warning"
    
    # Verify clean stdout
    refute_output --partial "Error"
}

# Access stderr lines array
@test "stderr lines" {
    run --separate-stderr my_command
    [ "${#stderr_lines[@]}" -eq 2 ]
    [ "${stderr_lines[0]}" = "First error" ]
}
```

---

## File Assertions (bats-file)

### Existence

```bash
assert_file_exists "/path/to/file"
assert_file_not_exists "/path/to/file"
assert_dir_exists "/path/to/dir"
assert_dir_not_exists "/path/to/dir"
assert_link_exists "/path/to/symlink"
assert_link_not_exists "/path/to/symlink"
assert_block_exists "/dev/sda"
assert_character_exists "/dev/null"
assert_socket_exists "/var/run/docker.sock"
assert_fifo_exists "/tmp/my_pipe"
```

### Permissions

```bash
assert_file_executable "/path/to/script"
assert_file_not_executable "/path/to/file"
```

### Content

```bash
# File is empty
assert_file_empty "/path/to/file"
assert_file_not_empty "/path/to/file"

# File contains string
assert_file_contains "/path/to/file" "search text"
assert_file_not_contains "/path/to/file" "forbidden text"
```

### Size

```bash
# Check file size
assert_file_size_equals "/path/to/file" 1024
```

### Ownership (if supported)

```bash
assert_file_owner "/path/to/file" "username"
assert_file_group "/path/to/file" "groupname"
assert_file_permission "/path/to/file" 755
```

### Symbolic Links

```bash
# Check symlink target
assert_symlink_to "/path/to/link" "/path/to/target"
```

---

## Generic Assertions (bats-assert)

### assert_equal

Compare two values.

```bash
@test "equal values" {
    result=$(calculate 5 3)
    assert_equal "$result" "8"
}
```

### assert

Evaluate condition.

```bash
@test "condition check" {
    assert [ -f "$file" ]
    assert [[ "$string" =~ pattern ]]
}
```

### fail

Force test failure with message.

```bash
@test "custom failure" {
    if [ "$condition" = "bad" ]; then
        fail "Unexpected condition: $condition"
    fi
}
```

---

## Working with Output Arrays

```bash
@test "check line count" {
    run my_command
    
    # Number of lines
    [ "${#lines[@]}" -eq 5 ]
    
    # First line
    [ "${lines[0]}" = "Header" ]
    
    # Last line
    [ "${lines[-1]}" = "Footer" ]
    
    # Loop through lines
    for line in "${lines[@]}"; do
        refute [ "$line" = "ERROR" ]
    done
}
```

---

## Custom Assertions

Create reusable assertions:

```bash
# test_helper/custom-assertions.bash
assert_json_valid() {
    local json="$1"
    if ! echo "$json" | jq . >/dev/null 2>&1; then
        fail "Invalid JSON: $json"
    fi
}

assert_http_success() {
    local status="$1"
    if [ "$status" -lt 200 ] || [ "$status" -ge 300 ]; then
        fail "HTTP status $status is not successful (2xx)"
    fi
}

# Usage in tests
@test "api returns valid json" {
    load 'test_helper/custom-assertions'
    
    run curl -s api.example.com/data
    assert_success
    assert_json_valid "$output"
}
```

---

## Assertion Options Summary

| Assertion | Options |
|-----------|---------|
| `assert_output` | `--partial`, `--regexp`, `-` (stdin) |
| `refute_output` | `--partial`, `--regexp` |
| `assert_line` | `--index N`, `--partial`, `--regexp` |
| `refute_line` | `--index N`, `--partial`, `--regexp` |
| `assert_stderr` | `--partial`, `--regexp` |

---

## Common Patterns

### Verify JSON Output

```bash
@test "json output" {
    run my_command --json
    assert_success
    
    # Check structure
    assert_output --partial '"status":'
    
    # Parse with jq
    run bash -c "echo '$output' | jq -r '.status'"
    assert_output "success"
}
```

### Verify CSV Output

```bash
@test "csv output" {
    run my_command --csv
    assert_success
    
    # Check header
    assert_line --index 0 "name,value,date"
    
    # Check data row
    assert_line --index 1 --regexp "^[^,]+,[0-9]+,"
}
```

### Verify Error Handling

```bash
@test "handles missing file" {
    run --separate-stderr my_command /nonexistent
    
    assert_failure 1
    assert_output ""  # stdout is clean
    assert_stderr --partial "File not found"
}
```

### Golden File Comparison

```bash
@test "output matches golden file" {
    run my_command
    assert_success
    
    # Compare with expected output
    diff <(echo "$output") "$BATS_TEST_DIRNAME/fixtures/expected.txt"
}
```
