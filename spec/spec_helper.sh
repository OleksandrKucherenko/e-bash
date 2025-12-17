#!/usr/bin/env bash
# shell: bash altsh=shellspec
# shellcheck shell=bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-17
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


# Test helper functions for git.verify-all-commits.sh tests

# Set up test environment
set_test_env() {
  export TEST_DIR=$(mktemp -d)
  export ORIGINAL_DIR=$(pwd)
  cd "$TEST_DIR"

  # Disable colors for consistent test output
  export NO_COLOR=1

  # Initialize a git repository for testing
  git init >/dev/null 2>&1
  git config user.email "test@example.com"
  git config user.name "Test User"
}

# Clean up test environment
cleanup_test_env() {
  cd "$ORIGINAL_DIR" >/dev/null
  rm -rf "$TEST_DIR" 2>/dev/null || true
  unset TEST_DIR ORIGINAL_DIR
}

# Create a test commit with given message
create_test_commit() {
  local message="$1"
  local file="test_${RANDOM}.txt"
  echo "test content" >"$file"
  git add "$file"
  git commit -m "$message" >/dev/null 2>&1
}

# Mock git commands for testing
mock_git_commands() {
  # Override git commands for controlled testing
  git() {
    case "$1" in
    "rev-parse")
      if [[ "$2" == "--git-dir" ]]; then
        return 0 # Simulate being in a git repo
      fi
      ;;
    "log")
      if [[ "$2" == "--format=%H" ]]; then
        echo "abc123def456"
        echo "def456abc123"
      elif [[ "$2" == "-1" && "$3" == "--pretty=%B" ]]; then
        if [[ "$4" == "abc123def456" ]]; then
          echo "feat: add new feature"
        elif [[ "$4" == "def456abc123" ]]; then
          echo "bad commit message"
        else
          echo "fix: valid commit message"
        fi
      fi
      ;;
    "branch")
      if [[ "$2" =~ backup-before-rewrite ]]; then
        return 0 # Simulate successful backup creation
      fi
      ;;
    "diff-index")
      return 0 # Simulate clean working tree
      ;;
    "filter-branch")
      return 0 # Simulate successful filter-branch
      ;;
    "commit")
      if [[ "$2" == "--amend" ]]; then
        return 0 # Simulate successful amend
      fi
      ;;
    "rev-parse")
      if [[ "$2" == "HEAD" ]]; then
        echo "abc123def456"
      fi
      ;;
    esac
  }
}

# Strip ANSI color codes for output comparison
strip_colors() {
  sed 's/\x1B\[[0-9;]*[mK]//g'
}

# Helper to test if script sourced correctly
script_sourced() {
  # Mock the source guard test
  [[ "${BASH_SOURCE[0]}" != "${0}" ]]
}
