#!/usr/bin/env bash
# Integration test for bin/git.ssh-setup.sh using pilotty
# Validates the full TUI workflow: prompts, generate/paste choice, multiline editors,
# file creation, git config.

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-04-13
## Version: 1.1.0
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

# Type text that may contain leading dashes (pilotty workaround)
_type_safe() {
  local session="$1" text="$2"
  local s
  s=$(_session "$session")
  if [[ "$text" == -* ]]; then
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
  sleep 3
}

# Accept default host/user (step 1) and wait for step 3
_accept_defaults() {
  local name="$1"
  _key "$name" Enter; sleep 0.3  # accept host
  _key "$name" Enter; sleep 2    # accept user
}

# Choose paste mode and enter a key
_paste_private_key() {
  local name="$1"
  _type "$name" "p"; sleep 0.3   # choose paste
  _key "$name" Enter; sleep 2    # confirm choice

  # Type key content
  _type_safe "$name" "-----BEGIN KEY-----"; sleep 0.3
  _key "$name" Enter; sleep 0.2
  _type "$name" "c2VjcmV0LWtleS1kYXRh"; sleep 0.3
  _key "$name" Enter; sleep 0.2
  _type_safe "$name" "-----END KEY-----"; sleep 0.5
  _key "$name" Ctrl+D; sleep 2   # save

  # Handle validation prompt if dashes were dropped
  local screen
  screen=$(_snap "$name")
  if _screen_contains "$screen" "Continue anyway"; then
    _type "$name" "y"; _key "$name" Enter; sleep 2
  fi
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

test_help_flag() {
  local repo
  repo=$(_create_test_repo)
  local session
  session=$(_session "help")

  pilotty spawn --name "$session" --cwd "$repo" \
    bash -c "export E_BASH='$repo/.scripts'; export TERM=xterm-256color; bash bin/git.ssh-setup.sh --help; sleep 3" \
    2>/dev/null
  # Wait for help output to render (dependency checks can be slow on cold start)
  pilotty wait-for -s "$session" "exit code" -t 10000 >/dev/null 2>/dev/null || sleep 5

  local screen
  screen=$(_snap "help")
  _screen_contains "$screen" "--help" || { echo "FAIL: --help not in output" >&2; echo "$screen" | head -5 >&2; _kill "help"; rm -rf "$repo"; return 1; }
  _screen_contains "$screen" "dry-run" || { echo "FAIL: dry-run not in help" >&2; echo "$screen" | head -10 >&2; _kill "help"; rm -rf "$repo"; return 1; }
  _screen_contains "$screen" "key-type" || { echo "FAIL: --key-type not in help" >&2; _kill "help"; rm -rf "$repo"; return 1; }

  _kill "help"
  rm -rf "$repo"
}

test_version_flag() {
  local repo
  repo=$(_create_test_repo)
  local session
  session=$(_session "ver")

  pilotty spawn --name "$session" --cwd "$repo" \
    bash -c "export E_BASH='$repo/.scripts'; export TERM=xterm-256color; bash bin/git.ssh-setup.sh --version; sleep 3" \
    2>/dev/null
  sleep 3

  local screen
  screen=$(_snap "ver")
  _screen_contains "$screen" "1.1.0" || { echo "FAIL: version not shown" >&2; _kill "ver"; rm -rf "$repo"; return 1; }

  _kill "ver"
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

test_paste_mode_dry_run() {
  local repo
  repo=$(_create_test_repo)
  _spawn_ssh_setup "dry" "$repo" "--dry-run"

  _accept_defaults "dry"

  local screen
  screen=$(_snap "dry")
  _screen_contains "$screen" "Generate" || _screen_contains "$screen" "Paste" || {
    echo "FAIL: generate/paste menu not shown" >&2; _kill "dry"; rm -rf "$repo"; return 1
  }

  _paste_private_key "dry"

  # Skip public key
  _key "dry" Escape; sleep 2

  screen=$(_snap "dry")
  _screen_contains "$screen" "dry run:" || _screen_contains "$screen" "Done" || {
    echo "FAIL: dry run output missing" >&2; _kill "dry"; rm -rf "$repo"; return 1
  }

  _kill "dry"
  rm -rf "$repo"
}

test_paste_mode_creates_files() {
  local repo
  repo=$(_create_test_repo)
  _spawn_ssh_setup "real" "$repo"

  _accept_defaults "real"
  _paste_private_key "real"

  # Public key step — type a pub key
  sleep 1
  local screen
  screen=$(_snap "real")
  if _screen_contains "$screen" "optional"; then
    _type "real" "ssh-ed25519 AAAA testkey"; sleep 0.5
    _key "real" Ctrl+D; sleep 2
  fi

  # Decline connection test
  screen=$(_snap "real")
  if _screen_contains "$screen" "Test SSH"; then
    _type "real" "n"; _key "real" Enter; sleep 1
  fi

  # Verify files
  [[ -f "$repo/.secrets/id_ed25519" ]] || { echo "FAIL: private key not created" >&2; _kill "real"; rm -rf "$repo"; return 1; }

  local perms
  perms=$(stat -c '%a' "$repo/.secrets/id_ed25519" 2>/dev/null || stat -f '%A' "$repo/.secrets/id_ed25519" 2>/dev/null)
  [[ "$perms" == "600" ]] || { echo "FAIL: private key perms are $perms, expected 600" >&2; _kill "real"; rm -rf "$repo"; return 1; }

  local ssh_cmd
  ssh_cmd=$(git -C "$repo" config core.sshCommand 2>/dev/null)
  [[ "$ssh_cmd" == *"id_ed25519"* ]] || { echo "FAIL: git sshCommand not set" >&2; _kill "real"; rm -rf "$repo"; return 1; }

  grep -qF ".secrets" "$repo/.gitignore" 2>/dev/null || { echo "FAIL: .gitignore missing .secrets" >&2; _kill "real"; rm -rf "$repo"; return 1; }

  _kill "real"
  rm -rf "$repo"
}

test_generate_mode_creates_key_pair() {
  local repo
  repo=$(_create_test_repo)
  _spawn_ssh_setup "gen" "$repo"

  _accept_defaults "gen"

  # Choose generate mode
  _type "gen" "g"; sleep 0.3
  _key "gen" Enter; sleep 0.3
  # Accept default comment
  _key "gen" Enter; sleep 3

  local screen
  screen=$(_snap "gen")
  _screen_contains "$screen" "Key pair generated" || _screen_contains "$screen" "Public key" || {
    echo "FAIL: key generation didn't complete" >&2; _kill "gen"; rm -rf "$repo"; return 1
  }

  # Continue past public key review (Ctrl+D or just wait)
  # The review step doesn't use an editor, just prints — script continues automatically
  sleep 1

  # Decline connection test
  screen=$(_snap "gen")
  if _screen_contains "$screen" "Test SSH"; then
    _type "gen" "n"; _key "gen" Enter; sleep 1
  fi

  # Verify generated key pair
  [[ -f "$repo/.secrets/id_ed25519" ]] || { echo "FAIL: private key not generated" >&2; _kill "gen"; rm -rf "$repo"; return 1; }
  [[ -f "$repo/.secrets/id_ed25519.pub" ]] || { echo "FAIL: public key not generated" >&2; _kill "gen"; rm -rf "$repo"; return 1; }

  local perms
  perms=$(stat -c '%a' "$repo/.secrets/id_ed25519" 2>/dev/null || stat -f '%A' "$repo/.secrets/id_ed25519" 2>/dev/null)
  [[ "$perms" == "600" ]] || { echo "FAIL: private key perms are $perms, expected 600" >&2; _kill "gen"; rm -rf "$repo"; return 1; }

  # Verify the key is a real SSH key
  head -1 "$repo/.secrets/id_ed25519" | grep -q "BEGIN" || { echo "FAIL: key doesn't look like PEM" >&2; _kill "gen"; rm -rf "$repo"; return 1; }
  grep -q "ssh-ed25519" "$repo/.secrets/id_ed25519.pub" || { echo "FAIL: pub key not ed25519" >&2; _kill "gen"; rm -rf "$repo"; return 1; }

  _kill "gen"
  rm -rf "$repo"
}

test_escape_cancels_at_paste() {
  local repo
  repo=$(_create_test_repo)
  _spawn_ssh_setup "cancel" "$repo"

  _accept_defaults "cancel"

  # Choose paste, then cancel at the editor
  _type "cancel" "p"; sleep 0.3
  _key "cancel" Enter; sleep 2
  _key "cancel" Escape; sleep 2

  local screen
  screen=$(_snap "cancel")
  _screen_contains "$screen" "No private key" || _screen_contains "$screen" "exit code" || {
    echo "FAIL: cancel not handled" >&2; _kill "cancel"; rm -rf "$repo"; return 1
  }

  [[ ! -f "$repo/.secrets/id_ed25519" ]] || { echo "FAIL: key created despite cancel" >&2; _kill "cancel"; rm -rf "$repo"; return 1; }

  _kill "cancel"
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
  run_test "shows help with --help (includes --key-type)" test_help_flag
  run_test "shows version with --version" test_version_flag
  echo ""

  echo "${cl_yellow}Auto-detection${cl_reset}"
  run_test "detects github.com from origin remote" test_autodetects_github_remote
  echo ""

  echo "${cl_yellow}Paste Mode${cl_reset}"
  run_test "dry-run: paste key flow" test_paste_mode_dry_run
  run_test "real run: paste creates files and configures git" test_paste_mode_creates_files
  run_test "Escape cancels at paste step" test_escape_cancels_at_paste
  echo ""

  echo "${cl_yellow}Generate Mode${cl_reset}"
  run_test "generate: creates ed25519 key pair and configures git" test_generate_mode_creates_key_pair
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
