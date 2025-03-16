# Git Hooks Testing Guide

This directory contains Git hooks that manage copyright notices in shell scripts and ensure they stay up-to-date. This README provides guidance on how to test these hooks manually.

<!-- TOC -->

- [Git Hooks Testing Guide](#git-hooks-testing-guide)
  - [Available Hooks](#available-hooks)
  - [Testing Hooks Manually](#testing-hooks-manually)
    - [Testing Copyright Verification Hook](#testing-copyright-verification-hook)
    - [Testing Last Revisit Date Update Hook](#testing-last-revisit-date-update-hook)
    - [Testing Missmatched Copyright Format](#testing-missmatched-copyright-format)
    - [Testing Different Number of Lines](#testing-different-number-of-lines)
    - [Testing Tools Comment On File Beggining](#testing-tools-comment-on-file-beggining)
    - [Testing Both Hooks Together](#testing-both-hooks-together)
  - [Cleanup After Testing](#cleanup-after-testing)
  - [Installing the Hooks for Normal Use](#installing-the-hooks-for-normal-use)

<!-- /TOC -->

## Available Hooks

- **pre-commit**: The main hook orchestrator that calls other hooks
- **pre-commit-copyright**: Verifies and adds copyright notices to shell scripts
- **pre-commit-copyright-last-revisit**: Updates the "Last revisit" date in modified files

## Testing Hooks Manually

All hooks support a test mode activated by setting the `HOOK_TEST=1` environment variable and providing file paths as arguments.

### Testing Copyright Verification Hook

This hook checks if shell scripts have the proper copyright notice and adds it if missing:

```bash
# Create a test file
cat > test_file.sh << 'EOF'
#!/usr/bin/env bash
echo "Hello World"
EOF

# Test the hook on the file (should add copyright)
HOOK_TEST=1 ./.githook/pre-commit-copyright test_file.sh

# Verify the result, code should stay in the file
cat test_file.sh | grep "Hello World" 

# Verify the result, copyright should be added
cat test_file.sh | grep "##"
```

### Testing Last Revisit Date Update Hook

This hook updates the "Last revisit" date in files that already have a copyright notice:

```bash
# Create a test file with copyright but old date
cat > test_file2.sh << 'EOF'
#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-03-16
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

echo "Hello World"
EOF

# Test the hook on the file (should update the date)
HOOK_TEST=1 ./.githook/pre-commit-copyright-last-revisit test_file2.sh

# Verify the result
cat test_file2.sh
```

### Testing Missmatched Copyright Format

```bash
# Create a test file with missmatched copyright
cat > test_file3.sh << 'EOF'
#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-03-16
## Source: https://github.com/OleksandrKucherenko/e-bash
## Changes:
## - Initial commit

echo "Hello World"
EOF

# Test the hook on the file (should update the date)
HOOK_TEST=1 ./.githook/pre-commit-copyright test_file3.sh
```

Output:

```text
⚠️  Files with non standard copyright (fix manually):
   - test_file3.sh, code: 3

Codes:
   2 - Different number of lines
   3 - Format mismatch

Expected format:
## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-03-16
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

Commit aborted. Please fix the copyright issues and try again.
```

### Testing Different Number of Lines

```bash
# Create a test file with missmatched number of lines
cat > test_file4.sh << 'EOF'
#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-03-16
## Source: https://github.com/OleksandrKucherenko/e-bash

echo "Hello World"
EOF

# Test the hook on the file (should update the date)
HOOK_TEST=1 ./.githook/pre-commit-copyright test_file4.sh

# repeat test with backup
cp -f test_file4.sh.\~2\~ test_file4.sh; \
HOOK_TEST=1 ./.githook/pre-commit-copyright test_file4.sh
```

Output:

```text
⚠️  Files with non standard copyright (fix manually):
   - test_file4.sh, code: 2

Codes:
   2 - Different number of lines
   3 - Format mismatch

Expected format:
## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-03-16
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

Commit aborted. Please fix the copyright issues and try again.
```

### Testing Tools Comment On File Beggining

```bash
# Create a test file with tools comment
cat > test_file5.sh << 'EOF'
#!/usr/bin/env bash
# shellcheck disable=SC2155

echo "Hello World"
EOF

# Test the hook on the file (should update the date)
HOOK_TEST=1 ./.githook/pre-commit-copyright test_file5.sh

cat test_file5.sh | grep "shellcheck"
```

### Testing Both Hooks Together

To test the entire pre-commit flow:

```bash
# Create multiple test files
cat > test_missing_copyright.sh << 'EOF'
#!/usr/bin/env bash
echo "No copyright here"
EOF

cat > test_old_date.sh << 'EOF'
#!/usr/bin/env bash
## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-03-16
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

echo "Hello World with old date"
EOF

# Test copyright hook
HOOK_TEST=1 ./.githook/pre-commit-copyright test_missing_copyright.sh test_old_date.sh

# Test last revisit hook
HOOK_TEST=1 ./.githook/pre-commit-copyright-last-revisit test_missing_copyright.sh test_old_date.sh

# Verify results
cat test_missing_copyright.sh
cat test_old_date.sh
```

## Cleanup After Testing

Remove test files and any backup files created by `gsed -i`:

```bash
# Clean up test files
rm -f test_file.sh test_file2.sh test_missing_copyright.sh test_old_date.sh

# Clean up any backup files created by gnu tools
rm -f test_*.~[0-9]~
```

## Installing the Hooks for Normal Use

To install these hooks for development:

```bash
# From project root
git config core.hooksPath .githook
```

This configures Git to use hooks from the .githook directory rather than the default .git/hooks.
