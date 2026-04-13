#!/usr/bin/env bash
# Integration test for bin/git.ssh-setup.sh using pilotty
# Validates the full TUI workflow: prompts, multiline editors, file creation, git config
#
# Note: pilotty type interprets leading dashes as flags, so PEM headers
# (-----BEGIN...) are typed character-by-character via pilotty key.

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-04-13
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
E_BASH="$PROJECT_DIR/.scripts"
SESSION_PREFIX="ssh-test-$$"
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILURES=()

cl_green=$'\033[32m'
cl_red=$'\033[31m'
cl_yellow=$'\033[33m'
cl_grey=$'\033[90m'
cl_reset=$'\033[0m'

_session() { echo "${SESSION_PREFIX}-${1}"; }

_type() { local s; s=$(_session "$1"); shift; pilotty type -s "$s" "$@" 2>/dev/null; }
_key() { local s; s=$(_session "$1"); shift; pilotty key -s "$s" "$@" 2>/dev/null; }
_snap() { local s; s=$(_session "$1"); pilotty snapshot -s "$s" --format text 2>/dev/null; }
_kill() { local s; s=$(_session "$1"); pilotty kill -s "$s" 2>/dev/null || true; }

_screen_contains() { echo "$1" | grep -qF "$2"; }

# Type text that may contain leading dashes (pilotty workaround).
# Uses `key` for individual characters when text starts with `-`.
_type_safe() {
  local session="$1" text="$2"
  local s
  s=$(_session "$session")
  if [[ "$text" == -* ]]; then
    # Type character by character using key command
    local i char keys=""
    for ((i = 0; i < ${#text}; i++)); do
      char="${text:i:1}"
      case "$char" in
        " ") keys+="Space " ;;
        *) keys+="$char " ;;
      esac
    done
    pilotty key -s "$s" $keys 2>/dev/null
  else
    pilotty type -s "$s" "$text" 2>/dev/null
  fi
}

_create_test_repo() {
  local dir
  dir=$(mktemp -d)
  git init "$dir" --initial-branch=main 2>/dev/null >/dev/null
  git -C "$dir" config user.name "Test" 2>/dev/null
  git -C "$dir" config user.email "test@test.com" 2>/dev/null
  git -C "$dir" remote add origin git@github.com:test/repo.git 2>/dev/null
  ln -s "$E_BASH" "$dir/.scripts"
  cp -r "$PROJECT_DIR/bin" "$dir/bin"
  echo "$dir"
}

_spawn_ssh_setup() {
  local name="$1" repo_dir="$2" extra_args="${3:-}"
  local session
  session=$(_session "$name")
  pilotty kill -s "$session" 2>/dev/null || true
  sleep 0.1
  pilotty spawn --name "$session" --cwd "$repo_dir" \
    bash -c "export E_BASH='$repo_dir/.scripts'; export TERM=xterm-256color; bash bin/git.ssh-setup.sh $extra_args; sleep 3" \
    2>/dev/null
  sleep 2
}

run_test() {
  local name="$1" func="$2"
  TESTS_RUN=$((TESTS_RUN + 1))
  printf "  %-60s" "$name"
  if "$func" 2>/tmp/ssh-test-err-$$; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "${cl_green}PASS${cl_reset}"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "${cl_red}FAIL${cl_reset}"
    FAILURES+=("$name")
    cat /tmp/ssh-test-err-$$ 2>/dev/null | sed 's/^/    /'
  fi
  rm -f /tmp/ssh-test-err-$$
}

# ── Tests ────────────────────────────────────────────

test_dry_run_full_flow() {
  local repo
  repo=$(_create_test_repo)
  _spawn_ssh_setup "dry" "$repo" "--dry-run"

  local screen
  screen=$(_snap "dry")
  _screen_contains "$screen" "Git SSH Key Setup" || { echo "FAIL: header missing" >&2; _kill "dry"; rm -rf "$repo"; return 1; }
  _screen_contains "$screen" "Git host" || { echo "FAIL: host prompt missing" >&2; _kill "dry"; rm -rf "$repo"; return 1; }

  # Accept defaults
  _key "dry" Enter; sleep 0.3
  _key "dry" Enter; sleep 2

  screen=$(_snap "dry")
  _screen_contains "$screen" "Private key" || { echo "FAIL: step 3 missing" >&2; _kill "dry"; rm -rf "$repo"; return 1; }

  # Type PEM key
  _type_safe "dry" "-----BEGIN KEY-----"; sleep 0.3
  _key "dry" Enter; sleep 0.2
  _type "dry" "dGVzdC1rZXktZGF0YQ=="; sleep 0.3
  _key "dry" Enter; sleep 0.2
  _type_safe "dry" "-----END KEY-----"; sleep 0.5

  # Save private key
  _key "dry" Ctrl+D; sleep 2

  screen=$(_snap "dry")
  # May get validation prompt if dashes were dropped — handle either case
  if _screen_contains "$screen" "Continue anyway"; then
    _type "dry" "y"; _key "dry" Enter; sleep 2
  fi

  screen=$(_snap "dry")
  _screen_contains "$screen" "Private key received" || _screen_contains "$screen" "Public key" || {
    echo "FAIL: didn't progress past step 3" >&2; _kill "dry"; rm -rf "$repo"; return 1
  }

  # Skip public key
  _key "dry" Escape; sleep 2

  screen=$(_snap "dry")
  _screen_contains "$screen" "DRY RUN" || _screen_contains "$screen" "Dry run complete" || {
    echo "FAIL: dry run output missing" >&2; _kill "dry"; rm -rf "$repo"; return 1
  }

  _kill "dry"
  rm -rf "$repo"
}

test_real_run_creates_files() {
  local repo
  repo=$(_create_test_repo)
  _spawn_ssh_setup "real" "$repo"

  # Accept defaults
  _key "real" Enter; sleep 0.3
  _key "real" Enter; sleep 2

  # Type private key (short, valid header)
  _type_safe "real" "-----BEGIN KEY-----"; sleep 0.3
  _key "real" Enter; sleep 0.2
  _type "real" "c2VjcmV0LWtleS1kYXRh"; sleep 0.3
  _key "real" Enter; sleep 0.2
  _type_safe "real" "-----END KEY-----"; sleep 0.5
  _key "real" Ctrl+D; sleep 2

  local screen
  screen=$(_snap "real")
  if _screen_contains "$screen" "Continue anyway"; then
    _type "real" "y"; _key "real" Enter; sleep 2
  fi

  # Type public key
  _type "real" "ssh-ed25519 AAAA testkey"; sleep 0.5
  _key "real" Ctrl+D; sleep 2

  # Answer "test connection?" with No
  screen=$(_snap "real")
  if _screen_contains "$screen" "Test SSH"; then
    _type "real" "n"; _key "real" Enter; sleep 1
  fi

  screen=$(_snap "real")

  # Verify files were created
  [[ -f "$repo/.secrets/id_ed25519" ]] || { echo "FAIL: private key not created" >&2; _kill "real"; rm -rf "$repo"; return 1; }
  [[ -f "$repo/.secrets/id_ed25519.pub" ]] || { echo "FAIL: public key not created" >&2; _kill "real"; rm -rf "$repo"; return 1; }

  # Verify private key permissions
  local perms
  perms=$(stat -c '%a' "$repo/.secrets/id_ed25519" 2>/dev/null || stat -f '%A' "$repo/.secrets/id_ed25519" 2>/dev/null)
  [[ "$perms" == "600" ]] || { echo "FAIL: private key perms are $perms, expected 600" >&2; _kill "real"; rm -rf "$repo"; return 1; }

  # Verify git config was set
  local ssh_cmd
  ssh_cmd=$(git -C "$repo" config core.sshCommand 2>/dev/null)
  [[ "$ssh_cmd" == *"id_ed25519"* ]] || { echo "FAIL: git sshCommand not set, got: $ssh_cmd" >&2; _kill "real"; rm -rf "$repo"; return 1; }

  # Verify .gitignore
  grep -qF ".secrets" "$repo/.gitignore" 2>/dev/null || { echo "FAIL: .gitignore missing .secrets" >&2; _kill "real"; rm -rf "$repo"; return 1; }

  # Verify public key content
  local pub_content
  pub_content=$(cat "$repo/.secrets/id_ed25519.pub")
  [[ "$pub_content" == *"ssh-ed25519"* ]] || { echo "FAIL: public key content wrong" >&2; _kill "real"; rm -rf "$repo"; return 1; }

  _kill "real"
  rm -rf "$repo"
}

test_escape_cancels_at_private_key() {
  local repo
  repo=$(_create_test_repo)
  _spawn_ssh_setup "cancel" "$repo"

  # Accept defaults
  _key "cancel" Enter; sleep 0.3
  _key "cancel" Enter; sleep 2

  # Cancel at private key
  _key "cancel" Escape; sleep 2

  local screen
  screen=$(_snap "cancel")
  _screen_contains "$screen" "No private key" || _screen_contains "$screen" "Aborting" || {
    echo "FAIL: cancel message not shown" >&2; _kill "cancel"; rm -rf "$repo"; return 1
  }

  # Verify no files created
  [[ ! -f "$repo/.secrets/id_ed25519" ]] || { echo "FAIL: key created despite cancel" >&2; _kill "cancel"; rm -rf "$repo"; return 1; }

  _kill "cancel"
  rm -rf "$repo"
}

test_autodetects_github_remote() {
  local repo
  repo=$(_create_test_repo)
  _spawn_ssh_setup "detect" "$repo" "--dry-run"

  local screen
  screen=$(_snap "detect")
  _screen_contains "$screen" "github.com" || { echo "FAIL: didn't detect github.com" >&2; _kill "detect"; rm -rf "$repo"; return 1; }

  _kill "detect"
  rm -rf "$repo"
}

test_skip_public_key() {
  local repo
  repo=$(_create_test_repo)
  _spawn_ssh_setup "skip" "$repo"

  # Accept defaults
  _key "skip" Enter; sleep 0.3
  _key "skip" Enter; sleep 2

  # Type minimal private key
  _type "skip" "test-private-key-data"; sleep 0.5
  _key "skip" Ctrl+D; sleep 2

  # Handle validation prompt
  local screen
  screen=$(_snap "skip")
  if _screen_contains "$screen" "Continue anyway"; then
    _type "skip" "y"; _key "skip" Enter; sleep 2
  fi

  # Skip public key with Escape
  _key "skip" Escape; sleep 2

  # Decline connection test
  screen=$(_snap "skip")
  if _screen_contains "$screen" "Test SSH"; then
    _type "skip" "n"; _key "skip" Enter; sleep 1
  fi

  # Verify only private key exists
  [[ -f "$repo/.secrets/id_ed25519" ]] || { echo "FAIL: private key not created" >&2; _kill "skip"; rm -rf "$repo"; return 1; }
  [[ ! -f "$repo/.secrets/id_ed25519.pub" ]] || { echo "FAIL: public key created despite skip" >&2; _kill "skip"; rm -rf "$repo"; return 1; }

  _kill "skip"
  rm -rf "$repo"
}

test_help_flag() {
  local repo
  repo=$(_create_test_repo)
  local session
  session=$(_session "help")

  pilotty spawn --name "$session" --cwd "$repo" \
    bash -c "export E_BASH='$repo/.scripts'; export TERM=xterm-256color; bash bin/git.ssh-setup.sh --help; sleep 2" \
    2>/dev/null
  sleep 1.5

  local screen
  screen=$(_snap "help")
  _screen_contains "$screen" "Usage:" || { echo "FAIL: help text missing" >&2; _kill "help"; rm -rf "$repo"; return 1; }
  _screen_contains "$screen" "dry-run" || { echo "FAIL: --dry-run not in help" >&2; _kill "help"; rm -rf "$repo"; return 1; }

  _kill "help"
  rm -rf "$repo"
}

# ── Main ─────────────────────────────────────────────

main() {
  echo ""
  echo "=== git.ssh-setup.sh Integration Tests (pilotty) ==="
  echo ""

  if ! command -v pilotty >/dev/null 2>&1; then
    echo "${cl_red}ERROR${cl_reset}: pilotty not found"
    exit 1
  fi

  echo "  ${cl_grey}pilotty $(pilotty --version 2>&1)${cl_reset}"
  echo ""

  echo "${cl_yellow}CLI Flags${cl_reset}"
  run_test "shows help with --help" test_help_flag
  echo ""

  echo "${cl_yellow}Auto-detection${cl_reset}"
  run_test "detects github.com from origin remote" test_autodetects_github_remote
  echo ""

  echo "${cl_yellow}Full Workflow${cl_reset}"
  run_test "dry-run: prompts + editors + validation" test_dry_run_full_flow
  run_test "real run: creates files, sets perms, configures git" test_real_run_creates_files
  echo ""

  echo "${cl_yellow}Edge Cases${cl_reset}"
  run_test "Escape cancels at private key step" test_escape_cancels_at_private_key
  run_test "skip public key with Escape" test_skip_public_key
  echo ""

  echo "=== Results ==="
  echo "  Total:  $TESTS_RUN"
  echo "  ${cl_green}Passed: $TESTS_PASSED${cl_reset}"
  if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "  ${cl_red}Failed: $TESTS_FAILED${cl_reset}"
    for f in "${FAILURES[@]}"; do echo "    - $f"; done
  fi

  # Cleanup
  for session in $(pilotty list-sessions 2>/dev/null | jq -r '.sessions[]?.name // empty' 2>/dev/null); do
    [[ "$session" == ${SESSION_PREFIX}* ]] && pilotty kill -s "$session" 2>/dev/null || true
  done

  [[ $TESTS_FAILED -eq 0 ]]
}

main "$@"
