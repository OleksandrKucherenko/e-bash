#!/usr/bin/env bash
# Apply ShellSpec timeout patch (Ubuntu/Linux)

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-02-23
## Version: 3.1.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="$SCRIPT_DIR/shellspec-0.28.1-to-0.29.0-timeout.patch"
FILES_DIR="$SCRIPT_DIR/files"
INJECT_SCRIPT="$SCRIPT_DIR/inject-timeout.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $*"; }

# 1. Find ShellSpec Directory
find_shellspec_dir() {
    local shellspec_bin
    if ! shellspec_bin="$(command -v shellspec 2>/dev/null)"; then
        log_error "ShellSpec not found in PATH"
        return 1
    fi

    # Resolve symlinks to find actual binary location
    local resolved_bin="$shellspec_bin"
    while [[ -L "$resolved_bin" ]]; do
        local link_dir
        link_dir="$(cd "$(dirname "$resolved_bin")" && pwd)"
        local target
        target="$(readlink "$resolved_bin")"
        if [[ "$target" != /* ]]; then
            target="$link_dir/$target"
        fi
        resolved_bin="$target"
    done

    local bin_dir
    bin_dir="$(cd "$(dirname "$resolved_bin")" && pwd)"

    # Case 1: Manual install - lib/ next to binary
    if [[ -f "$bin_dir/lib/core/core.sh" ]]; then
        echo "$bin_dir"
        return 0
    fi

    # Case 2: Standard install (bin/shellspec -> ../lib/)
    local parent_dir
    parent_dir="$(cd "$bin_dir/.." && pwd)"
    if [[ -f "$parent_dir/lib/core/core.sh" ]]; then
        echo "$parent_dir"
        return 0
    fi

    # Case 3: Homebrew Cellar layout (lib/shellspec/lib/)
    if [[ -f "$parent_dir/lib/shellspec/lib/core/core.sh" ]]; then
        echo "$parent_dir/lib/shellspec"
        return 0
    fi

    echo "$bin_dir"
}

if ! SHELLSPEC_DIR="$(find_shellspec_dir)"; then
    log_error "Could not determine ShellSpec installation directory."
    exit 1
fi

if [[ ! -f "$SHELLSPEC_DIR/lib/core/core.sh" ]]; then
    log_error "ShellSpec core not found under $SHELLSPEC_DIR"
    exit 1
fi

log_info "ShellSpec Dir: $SHELLSPEC_DIR"

# 2. Check if already patched
MARKER_FILE="$SHELLSPEC_DIR/.patched-timeout"
if [[ -f "$MARKER_FILE" ]]; then
    exit 0
fi

if "$SHELLSPEC_DIR/shellspec" --help 2>/dev/null | grep -q -- '--timeout'; then
    touch "$MARKER_FILE" 2>/dev/null || true
    exit 0
fi

# 3. Try applying patch (with fuzz tolerance)
log_step "Applying patch..."
cd "$SHELLSPEC_DIR"

patch_succeeded=false

if command -v patch >/dev/null 2>&1 && [[ -f "$PATCH_FILE" ]]; then
    PATCH_OPTS=(--batch --forward -p1 -N --fuzz=3)

    if patch "${PATCH_OPTS[@]}" --dry-run -i "$PATCH_FILE" >/dev/null 2>&1; then
        log_info "Patch dry-run OK, applying..."
        if patch "${PATCH_OPTS[@]}" -i "$PATCH_FILE"; then
            patch_succeeded=true
        fi
    else
        log_warn "Patch dry-run failed (source files differ from expected). Using direct injection..."
        # Do NOT force-apply: --force can write partial content to files that tricks
        # the inject script's idempotency checks into skipping those files.
        # The inject script below is the correct robust fallback.
    fi

    # Clean up rejection/backup files
    find "$SHELLSPEC_DIR" -maxdepth 3 \( -name "*.rej" -o -name "*.orig" \) -delete 2>/dev/null || true
fi

# 4. Direct injection fallback - ensures all modifications are in place
#    This is idempotent: skips files already patched (by patch or previous run)
if [[ "$patch_succeeded" != "true" ]]; then
    if [[ -x "$INJECT_SCRIPT" ]] || [[ -f "$INJECT_SCRIPT" ]]; then
        log_step "Running direct file injection fallback..."
        bash "$INJECT_SCRIPT" "$SHELLSPEC_DIR" "$FILES_DIR"
    else
        log_error "Inject script not found: $INJECT_SCRIPT"
        exit 1
    fi
else
    # Even when patch succeeds, ensure new standalone files are in place
    if [[ -d "$FILES_DIR" ]]; then
        mkdir -p "$SHELLSPEC_DIR/lib/libexec" "$SHELLSPEC_DIR/libexec"
        cp "$FILES_DIR/lib/libexec/timeout-parser.sh" "$SHELLSPEC_DIR/lib/libexec/timeout-parser.sh" 2>/dev/null || true
        cp "$FILES_DIR/libexec/shellspec-timeout-watchdog.sh" "$SHELLSPEC_DIR/libexec/shellspec-timeout-watchdog.sh" 2>/dev/null || true
        chmod +x "$SHELLSPEC_DIR/libexec/shellspec-timeout-watchdog.sh" 2>/dev/null || true
    fi
fi

# 5. Verify patch was applied (functional test)
log_step "Verifying timeout feature..."

TEST_FILE="$SHELLSPEC_DIR/timeout_verification_spec.sh"
cat <<'EOF' > "$TEST_FILE"
Describe "timeout verification"
  Example "should timeout in 1 second" % timeout:1
    sleep 2
    The status should equal 0
  End
End
EOF

START_TIME=$(date +%s)
"$SHELLSPEC_DIR/shellspec" "$TEST_FILE" >/dev/null 2>&1 || true
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
rm -f "$TEST_FILE"

if [[ $DURATION -lt 2 ]]; then
    VERSION="$("$SHELLSPEC_DIR/shellspec" --version 2>/dev/null || echo "unknown")"
    log_info "Timeout feature verified (${DURATION}s). Version: $VERSION"
    touch "$MARKER_FILE" 2>/dev/null || true
    exit 0
else
    log_error "Verification failed: test did not timeout (Duration: ${DURATION}s, expected <2s)"
    exit 1
fi
