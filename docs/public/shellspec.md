# ShellSpec Testing Guide

## Overview

This document covers common issues, solutions, and best practices for ShellSpec testing in the e-bash project.

## Major Issue: junit_tests_0 Unbound Variable Error

### Problem Description

When running tests with `shellspec spec/git_semantic_version_spec.sh`, the following error occurred:

```
Bail out! Aborted by unexpected errors.
/home/linuxbrew/.linuxbrew/lib/shellspec/lib/libexec/reporter/junit_formatter.sh: line 117: junit_tests_0: unbound variable
Aborted with status code [executor: 1] [reporter: 1] [error handler: 102]
Fatal error occurred, terminated with exit status 102.
```

### Root Cause Analysis

The issue was caused by **EXIT trap interference** when scripts were sourced by ShellSpec:

1. **Primary Issue**: The script `bin/git.semantic-version.sh` was setting up EXIT and INT/TERM traps unconditionally when sourced
2. **Secondary Issue**: The BeforeAll command in the test was failing due to incorrect path calculation
3. **Impact**: The trap setup was disrupting ShellSpec's execution flow, causing the junit formatter to fail with unbound variables

### Solution Implemented

#### 1. ShellSpec Pattern for Script Execution Control

**Before (Problematic)**:
```bash
# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  trap on_exit EXIT
  trap on_interrupt INT TERM
  main "$@"
  exit $?
fi
```

**After (Fixed)**:
```bash
# This is the writing style presented by ShellSpec, which is short but unfamiliar.
# Note that it returns the current exit status (could be non-zero).
${__SOURCED__:+return}

# Setup exit and interrupt traps
trap on_exit EXIT
trap on_interrupt INT TERM

# Run main function
main "$@"
exit $?
```

#### 2. BeforeAll Command Fix

**Before (Problematic)**:
```bash
BeforeAll 'E_BASH="$(cd "$(dirname "$SHELLSPEC_SPECFILE")" && cd ../.scripts && pwd)"'
```

**After (Fixed)**:
```bash
# BeforeAll 'E_BASH="$(cd "$(dirname "$SHELLSPEC_SPECFILE")" && cd ../.scripts && pwd)"'
# Note: Commented out because the path calculation fails in test environment.
# The script's fallback mechanism works correctly.
```

### Results

- **95 examples, 0 failures, 2 skips** - All tests pass
- **Exit code 0** - No errors
- **Junit output working** - TAP format output generated correctly
- **Code coverage working** - 10.11% coverage, 475 executed lines

## Best Practices

### 1. Script Execution Control

Use the ShellSpec pattern to prevent script execution when sourced:

```bash
# This prevents execution when sourced by ShellSpec
${__SOURCED__:+return}

# Your script execution code here
```

This pattern is:
- **Shorter** than conditional checks
- **More reliable** than `[[ "${BASH_SOURCE[0]}" == "${0}" ]]`
- **ShellSpec-recommended** approach

### 2. Avoid Problematic BeforeAll Commands

- Don't rely on complex path calculations in BeforeAll
- Let scripts use their built-in fallback mechanisms for variable initialization
- Test BeforeAll commands in isolation before using them

### 3. Trap Management

- Never set up traps unconditionally in sourced scripts
- Use the ShellSpec pattern to control when traps are set
- Traps should only be active when scripts run directly, not when sourced

## ANSI Color Filtering Utilities

```bash
# Define helper functions to strip ANSI escape sequences
# $1 = stdout, $2 = stderr, $3 = exit status of the command
no_colors_stderr() { echo -n "$2" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | tr -s ' '; }
no_colors_stdout() { echo -n "$1" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | tr -s ' '; }

# Usage example
The result of function no_colors_stdout should include "v1.0.0 [CURRENT] [LATEST]"
```

## Configuration

### .shellspec Configuration

```bash
--require spec_helper
--shell bash
--format t
--skip-message quiet
--pending-message quiet
--output junit

## Default kcov (coverage) options
--kcov
--kcov-options "--include-path=. --path-strip-level=1"
--kcov-options "--exclude-pattern=/.shellspec,/spec/,/coverage/,/report/,/demos/"
--kcov-options "--include-pattern=.scripts/,bin/"
```

## Global Timeout Support

This project uses a ShellSpec patch that adds native timeout support to prevent hung tests. The patch adds `--timeout` and per-test timeout directives.

### Applying the Patch

The timeout feature is provided via a patch that must be applied to your local ShellSpec installation:

```bash
# Apply the patch
./patches/apply.sh

# Verify patch is applied
shellspec --help | grep timeout
```

See `patches/README.md` for full documentation on the timeout patch.

### Using Native Timeout

Once the patch is applied, use the native `--timeout` flag:

```bash
# Set global timeout for all tests (default: 60 seconds)
shellspec --timeout 30

# Disable timeout
shellspec --no-timeout

# Timeout format variations
shellspec --timeout 30s    # 30 seconds (explicit)
shellspec --timeout 2m     # 2 minutes
shellspec --timeout 1m30s  # 1 minute 30 seconds
```

### Per-Test Timeout Override

**IMPORTANT:** The correct syntax includes a space after `%`:

```bash
Describe "example"
  # Correct: space after % before timeout value
  It "should complete quickly" % timeout:5
    sleep 10  # Will timeout after 5 seconds
  End

  It "has more time" % timeout:120
    long_running_operation
  End
End
```

### Patch Reference

- **Source:** https://github.com/OleksandrKucherenko/shellspec/pull/356
- **Status:** Patch is automatically applied in CI workflows
- **Detection:** Run `shellspec-patch-check` to verify patch status

## Debugging Tips

1. **Test in isolation**: Create minimal test files to isolate issues
2. **Check syntax**: Use `bash -n script.sh` to verify syntax
3. **Disable coverage**: Use `--no-kcov` for faster debugging
4. **Use format d**: Use `--format d` for detailed output during debugging
5. **Check exit codes**: Monitor exit codes to identify failure points

## Common Patterns

### Mock Functions
```bash
Mock logger:init
  echo "$@" >/dev/null
End

Mock echo:SemVer
  echo "$@" >/dev/null
End
```

### Include Scripts
```bash
Include "bin/script-name.sh"
```

### Test Structure
```bash
Describe "Feature name"
  It "should do something"
    When call function_name "arg1" "arg2"
    The output should eq "expected output"
    The status should be success
  End
End
```

## Bash Pitfalls to Avoid in ShellSpec Tests

When writing ShellSpec tests, avoid common Bash pitfalls from [mywiki.wooledge.org/BashPitfalls](http://mywiki.wooledge.org/BashPitfalls) that can cause tests to be fragile, fail intermittently, or behave unexpectedly.

### Variable Quoting (Most Common Issues)

**Always quote variable expansions:**
```bash
# WRONG - Subject to word splitting and globbing
When call process_file $filename

# RIGHT
When call process_file "$filename"
```

**Use correct test syntax:**
```bash
# POSIX compliant - use with =
[ "$foo" = "bar" ]

# Bash preferred
[[ $foo == "bar" ]]    # Pattern matching if right side unquoted
[[ $foo == "$bar" ]]   # String comparison (quoted)
```

**Use proper numeric comparisons:**
```bash
# WRONG - > does string collation, not numeric comparison
[[ $foo > 7 ]]

# RIGHT - Use (( for arithmetic
(( foo > 7 ))

# POSIX alternative
[ "$foo" -gt 7 ]
```

### Command Substitution Issues

**Avoid `for f in $(ls *.mp3)` patterns:**
```bash
# WRONG - Word splitting on whitespace, glob expansion, no way to handle newlines
for file in $(ls *.mp3); do
  process "$file"
done

# RIGHT - Use globs directly
for file in ./*.mp3; do
  [ -e "$file" ] || continue  # Handle no matches
  process "$file"
done
```

**Use process substitution to avoid subshell scope issues:**
```bash
# WRONG - Variables set in while loop don't persist
grep foo bar | while read -r line; do
  ((count++))
done
echo "$count"  # Always 0

# RIGHT - Use process substitution
while IFS= read -r line; do
  ((count++))
done < <(grep foo bar)
echo "$count"  # Correct count
```

### File Handling

**Never read and write the same file in a pipeline:**
```bash
# WRONG - File gets clobbered
cat file | sed 's/foo/bar/g' > file

# RIGHT - Use temporary file
sed 's/foo/bar/g' file > tmpfile && mv tmpfile file
```

**Handle filenames with leading dashes:**
```bash
# WRONG - Leading dash interpreted as option
cp "$file" "$target"

# RIGHT - Use -- to end option processing
cp -- "$file" "$target"

# RIGHT - Or ensure paths start with ./
for file in ./*.mp3; do
  cp "$file" /target
done
```

**Use xargs -0 for null-delimited input:**
```bash
# WRONG - Breaks on whitespace in filenames
find . -type f | xargs wc

# RIGHT - Use null delimiters
find . -type f -print0 | xargs -0 wc
```

### Variable Assignment

**No spaces around = in assignments:**
```bash
# WRONG
foo = bar
foo= bar

# RIGHT
foo=bar
foo="bar"
```

**Don't use $ in assignments:**
```bash
# WRONG
$foo=bar

# RIGHT
foo=bar
```

### Loops and Iteration

**Use proper positional parameter iteration:**
```bash
# WRONG - $* splits on IFS
for arg in $*; do ... done

# RIGHT - "$@" preserves each argument
for arg in "$@"; do ... done

# RIGHT - Default behavior
for arg; do ... done
```

**Brace expansion before variable expansion:**
```bash
# WRONG - {1..$n} doesn't work (brace expansion happens first)
for i in {1..$n}; do ... done

# RIGHT - Use arithmetic for loop
for ((i=1; i<=n; i++)); do ... done
```

**No semicolon after background operator:**
```bash
# WRONG
for i in {1..10}; do ./something &; done

# RIGHT
for i in {1..10}; do ./something & done
```

### Redirection

**Redirect stderr to stdout in correct order:**
```bash
# WRONG - stderr goes to terminal, stdout to file
somecmd 2>&1 >>logfile

# RIGHT
somecmd >>logfile 2>&1
```

**Don't close file descriptors:**
```bash
# WRONG - Closing stderr can cause unpredictable behavior
myprogram 2>&-

# RIGHT - Redirect to /dev/null
myprogram 2>/dev/null
```

### String Handling

**Always provide format string to printf:**
```bash
# WRONG - Format string exploit if $foo contains \ or %
printf "$foo"

# RIGHT
printf '%s\n' "$foo"
printf %s "$foo"
```

**Understand pattern matching vs string comparison:**
```bash
# Unquoted right side = pattern matching (always true if $bar contains *)
if [[ $foo = $bar ]]; then ... fi

# RIGHT - Quote for string comparison
if [[ $foo = "$bar" ]]; then ... fi

# Or be explicit about pattern matching intent
if [[ $foo = *.txt ]]; then ... fi
```

### Arithmetic and Evaluation

**Validate arithmetic input (Code injection risk):**
```bash
# WRONG - Code injection vulnerability
read num
echo $((num+1))

# RIGHT - Validate input first
case $num in
  ("" | *[!0123456789-]*)
    echo "Invalid number" >&2; exit 1 ;;
  *)
    echo $((num+1))
esac
```

**Avoid cmd1 && cmd2 || cmd3 as if/else:**
```bash
# WRONG - Not equivalent to if/else when cmd2 can fail
[[ -s $errorlog ]] && echo "Errors" || echo "Success"

# RIGHT - Use proper if/else
if [[ -s $errorlog ]]; then
  echo "Errors"
else
  echo "Success"
fi
```

### Special Context Pitfalls

**Always check cd for errors:**
```bash
# WRONG - Commands run in wrong directory if cd fails
cd /foo; bar

# RIGHT
cd /foo && bar

# RIGHT - For multiple commands
cd /foo || exit 1
bar
baz
```

**Handle symlinks correctly in tests:**
```bash
# -e returns false for broken symlinks
[[ -e "$broken_symlink" ]]

# RIGHT - Also test for symlink
[[ -e "$broken_symlink" || -L "$broken_symlink" ]]
```

**Understand IFS behavior with read:**
```bash
# Trailing empty field gets lost
IFS=, read -ra fields <<< "a,b,"

# RIGHT - Append delimiter to input
input="a,b,"
IFS=, read -ra fields <<< "$input,"
```

**Set locale for binary data reading:**
```bash
# May have issues with multibyte locales (bash 5.0+ bug)
IFS= read -r -d '' filename

# RIGHT - Force C locale
IFS= LC_ALL=C read -r -d '' filename
```

### Test-Specific Pitfalls

**Understand set -e behavior:**
```bash
# set -e doesn't work in:
# - Command substitutions
# - Commands after if/&&/||
# - Functions tested with if

# Always check critical commands explicitly
cd -- "$dir" || return
some_command || exit 1
```

**Use read correctly:**
```bash
# WRONG - Don't use $ in read
read $foo

# RIGHT
read foo
IFS= read -r foo  # Also preserves backslashes
```

### Quick Checklist for Test Writing

When writing ShellSpec tests:
1. All variable expansions are quoted: `"$var"` not `$var`
2. Use `[[ ]]` for tests unless POSIX compliance needed
3. Use `(( ))` for arithmetic comparisons
4. Avoid `for f in $(ls)` - use globs directly
5. Use process substitution `<(cmd)` to avoid subshell scope issues
6. Validate user input before arithmetic evaluation
7. Use `--` after commands when filenames might start with `-`
8. Redirect stderr to stdout: `cmd > file 2>&1` not `cmd 2>&1 > file`
9. Check `cd` failures: `cd dir || return`
10. Use `printf '%s' "$var"` instead of `echo "$var"` for safety
11. Use `find -print0 | xargs -0` for filename handling
12. Quote right side of `=` in `[[` unless pattern matching intended

## Additional Pitfalls from Web Research

Additional pitfalls discovered from HackerOne, Julia Evans' blog, shell-tips.com, and signal/nameref research:

### PIPESTATUS and Pipeline Issues

**PIPESTATUS is fragile - Must be saved immediately:**
```bash
# WRONG - Shows echo's exit status, not the pipeline
cmd1 | cmd2
echo "${PIPESTATUS[@]}"

# RIGHT - Save immediately
cmd1 | cmd2
status=("${PIPESTATUS[@]}")
echo "${status[@]}"
```

**timeout command signal propagation:**
```bash
# WRONG - Only cmd1 gets killed on timeout
timeout 5s cmd1 | cmd2

# RIGHT - Use process groups
timeout --signal=TERM 5s bash -c "cmd1 | cmd2"
```

### Here-Document Issues

**Here-document with <<- uses tabs:**
```bash
# <<- strips ONLY leading tabs, not spaces
cat <<-EOF
		This line is indented with tabs (stripped)
    This line is indented with spaces (NOT stripped)
EOF
```

**Here-document variable escaping:**
```bash
# Variables expanded by default
cat <<EOF
$HOME  # Expands to /home/user
EOF

# Quote delimiter to prevent expansion
cat <<'EOF'
$HOME  # Literal string $HOME
EOF
```

### Nameref and Reference Issues (Bash 4.3+)

**Nameref circular references:**
```bash
# Can cause infinite loops or undefined behavior
declare -n ref="ref"  # Circular reference
# Bash should detect this but behavior varies by version
```

### Signal Handling

**SIGINT behavior in async commands:**
```bash
# SIGINT is ignored in asynchronous command lists
{
  long_running_command
} &
# Ctrl-C may not interrupt this

# Consider using explicit signal handling
trap 'kill $(jobs -p)' INT
```

### Function and Command Issues

**Overwriting system commands with functions:**
```bash
# Shadowing builtins can cause infinite recursion
cd() { echo "My cd"; builtin cd "$@"; }
# Always use `builtin` or `command` to avoid issues
```

**Background job control with jobs/fg:**
```bash
# fg takes job ID, not PID
long_cmd &
fg %1  # RIGHT - uses job ID
fg $!  # WRONG - $! is PID, not job ID
```

### Platform and Locale Issues

**Line endings (CRLF vs LF):**
```bash
# Windows CRLF endings cause \r to be part of commands
# Detect and fix in scripts
script.sh=$(sed 's/\r$//' script.sh)
# Or use dos2unix
dos2unix script.sh
```

**Shell glob order is locale-dependent:**
```bash
# Globs expand in locale collation order, not alphabetical
# Force C locale for consistent ordering
LC_ALL=C
for f in *; do ... done
```

### Variable and Array Issues

**Using unset with functions:**
```bash
# WRONG - Removes the function
unset myfunc

# RIGHT - Use -v flag for variables
unset -v myvar

# Use -f flag for functions
unset -f myfunc
```

**Arithmetic context with empty arrays:**
```bash
# Empty arrays in arithmetic context cause errors
arr=()
echo $(( arr[0] + 1 ))  # Error

# Provide defaults or check first
echo $(( ${arr[0]:-0} + 1 ))
```

**Variable names colliding with shell specials:**
```bash
# Don't use these variable names
PATH=  # Breaks command finding
HOME=  # Breaks ~ expansion
IFS=   # Changes word splitting
UID=   # Read-only in some shells
BASH_*=  # Internal bash variables

# Use prefixes to avoid collisions
my_script_PATH=/custom/path
```

**Wait returns status of last job:**
```bash
job1 & job2 & job3 &
wait  # Returns exit status of job3 only

# To check all jobs:
job1 & pids+=($!)
job2 & pids+=($!)
job3 & pids+=($!)

for pid in "${pids[@]}"; do
  wait "$pid" || echo "Job $pid failed"
done
```

### Additional Best Practices Checklist

13. Save `PIPESTATUS` immediately: `status=("${PIPESTATUS[@]}")`
14. Use `timeout --signal=TERM` in pipelines with process groups
15. Remember `<<-` strips tabs only, not spaces
16. Avoid nameref circular references; validate targets
17. Handle SIGINT explicitly in async commands
18. Use `builtin` or `command` when shadowing builtins
19. Check/fix line endings: `sed 's/\r$//'` or `dos2unix`
20. Quote heredoc delimiter `'EOF'` to prevent variable expansion
21. Use job IDs `%1` with `fg`, not PIDs
22. Set `LC_ALL=C` for locale-independent glob ordering
23. Use `unset -v` for variables, `unset -f` for functions
24. Check all background jobs individually with `wait "$pid"`
25. Provide defaults for empty arrays in arithmetic context: `${arr[0]:-0}`
26. Don't use reserved variable names: PATH, HOME, IFS, UID, BASH_*

## Variable Scope Pollution (Critical for Libraries)

**Problem: Common loop variables like `$i` pollute global namespace:**

```bash
# WRONG - Global $i persists after loop, breaks sourced scripts
for i in 1 2 3; do
  echo "$i"
done
# $i is now set to "3" - can break libraries!

# WRONG - Even in functions, variables are global by default
process_items() {
  for i in "$@"; do
    process "$i"
  done
}
# Caller's $i gets overwritten!
```

**Solution: Always declare loop variables as `local` and use descriptive names:**

```bash
# RIGHT - Declare loop variable as local
process_items() {
  local i
  for i in "$@"; do
    process "$i"
  done
}

# BETTER - Use descriptive variable names
process_files() {
  local file
  for file in "$@"; do
    process_file "$file"
  done
}

# BEST - Descriptive name with Hungarian notation
process_arguments() {
  local iArgument
  for iArgument in "$@"; do
    process "$iArgument"
  done
}
```

**Why this matters for e-bash library development:**
- Variables are **global by default** in bash (opposite of most languages)
- Common loop variables (`$i`, `$j`, `$k`) are frequently used across scripts
- A library that sets a global `$i` can break calling scripts' loops
- Sourced modules share the caller's variable namespace
- Use `local` for ALL function variables to prevent namespace pollution

**Best practice for e-bash modules:**
```bash
# Library functions should NEVER set global variables
# Declare all variables as local at the top of functions

mylib:process() {
  local item
  for item in "$@"; do
    # process each item
  done
  # 'item' is automatically unset when function returns
}
```