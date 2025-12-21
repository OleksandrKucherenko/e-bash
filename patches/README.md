# Patches

This directory contains patches that are applied to external tools used by the e-bash project.

## ShellSpec Timeout Patch

This patch adds timeout support to ShellSpec, preventing hung tests and infinite loops.

**Reference:** https://github.com/OleksandrKucherenko/shellspec/pull/356
**Latest Update:** Includes important bug fixes (ksh93t AIX workaround, syntax_error fix, conditional calls)

### Features Added

- `--timeout SECONDS` - Set global timeout for tests (default: 60)
- `--no-timeout` - Disable timeout for all tests
- `% timeout:N` - Per-test timeout override (note the space after `%`)

### Usage

```bash
# Apply the patch to your local ShellSpec installation
./patches/apply.sh

# Verify the patch is applied
shellspec --help | grep timeout

# Use timeout in tests
shellspec --timeout 30          # 30 second global timeout
shellspec --no-timeout          # Disable timeout
```

### Per-Test Timeout Override

**IMPORTANT:** The correct syntax includes a space after `%`:

```sh
Describe 'example'
  # Correct: space after % before timeout value
  It 'should complete quickly' % timeout:5
    sleep 10  # Will timeout after 5 seconds
  End

  It 'has more time' % timeout:120
    long_running_operation
  End
End
```

**Format variations:**
- `% timeout:30` - 30 seconds
- `% timeout:30s` - 30 seconds (explicit)
- `% timeout:2m` - 2 minutes
- `% timeout:1m30s` - 1 minute 30 seconds

### Patch Status Check

After reloading your shell (`direnv allow`), you can check patch status:

```bash
# Check if patch is applied
shellspec-patch-check
```

The `.envrc` file will also display a hint if the patch is not applied when you load the shell.

### Auto-Detection

The apply script automatically detects the ShellSpec installation directory by:
1. Finding the `shellspec` binary in PATH
2. Resolving symlinks to find the actual installation
3. Looking for characteristic ShellSpec files

For non-standard installations, override with:
```bash
SHELLSPEC_INSTALL_DIR=/path/to/shellspec ./patches/apply.sh
```

### Files

- `shellspec-timeout.patch` - The patch file from https://github.com/OleksandrKucherenko/shellspec/pull/356
- `apply.sh` - Script to apply the patch to the local ShellSpec installation

### CI Integration

The patch is automatically applied in CI workflows (`.github/workflows/shellspec.yaml`) before running tests.

### Rollback

If the patch causes issues, you can rollback by restoring from the backup created during patch application:

```bash
# The backup directory is shown during patch application
# Example: ~/.shellspec-backup-20231223_143000
rm -rf ~/.local/share/mise/installs/shellspec/0.28.1/shellspec-0.28.1
mv ~/.shellspec-backup-YYYYMMDD_HHMMSS ~/.local/share/mise/installs/shellspec/0.28.1/shellspec-0.28.1
```

### Verification

To verify the timeout feature is working:

```bash
# Global timeout test
cat > /tmp/test_timeout_spec.sh << 'EOF'
Describe 'timeout'
  It 'should timeout' % timeout:3
    sleep 10
    echo "This should not print"
  End
End
EOF

shellspec --timeout 60 /tmp/test_timeout_spec.sh
# Should complete in ~3 seconds, not 10
```
