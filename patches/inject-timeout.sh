#!/usr/bin/env bash
# Direct file injection of ShellSpec timeout feature (patch-free fallback)
# Uses perl for portable multi-line text manipulation (available on macOS + Linux)

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-02-23
## Version: 1.2.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# Usage: inject-timeout.sh <SHELLSPEC_DIR> <FILES_DIR>
# Injects timeout feature directly into ShellSpec source files.
# Idempotent - safe to run multiple times.

set -euo pipefail

SHELLSPEC_DIR="${1:?Usage: inject-timeout.sh <SHELLSPEC_DIR> <FILES_DIR>}"
FILES_DIR="${2:?Usage: inject-timeout.sh <SHELLSPEC_DIR> <FILES_DIR>}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INJECT]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[INJECT]${NC} $*"; }
log_error() { echo -e "${RED}[INJECT]${NC} $*" >&2; }
log_skip() { echo -e "${YELLOW}[SKIP]${NC}   $*"; }
log_ok()   { echo -e "${GREEN}[OK]${NC}     $*"; }

# Verify perl is available
if ! command -v perl >/dev/null 2>&1; then
    log_error "perl is required for direct injection but not found"
    exit 1
fi

# --- 1. Copy new files ---
log_info "Installing new timeout files..."

mkdir -p "$SHELLSPEC_DIR/lib/libexec"
mkdir -p "$SHELLSPEC_DIR/libexec"

cp "$FILES_DIR/lib/libexec/timeout-parser.sh" "$SHELLSPEC_DIR/lib/libexec/timeout-parser.sh"
cp "$FILES_DIR/libexec/shellspec-timeout-watchdog.sh" "$SHELLSPEC_DIR/libexec/shellspec-timeout-watchdog.sh"
chmod +x "$SHELLSPEC_DIR/libexec/shellspec-timeout-watchdog.sh"

_patched=0
_skipped=0

# --- 2. shellspec (main binary): Update version ---
if grep -q "SHELLSPEC_VERSION='0.28" "$SHELLSPEC_DIR/shellspec" 2>/dev/null; then
    if ! grep -q "0.29.0-dev" "$SHELLSPEC_DIR/shellspec"; then
        log_info "Patching shellspec: version string..."
        perl -i -pe "s/SHELLSPEC_VERSION='0\.28\.\d+'/SHELLSPEC_VERSION='0.29.0-dev'/" "$SHELLSPEC_DIR/shellspec"
        grep -q "0.29.0-dev" "$SHELLSPEC_DIR/shellspec" \
            && { log_ok "shellspec: version updated to 0.29.0-dev"; _patched=$((_patched + 1)); } \
            || log_warn "shellspec: version update may have failed"
    else
        log_skip "shellspec: already at 0.29.0-dev"
        _skipped=$((_skipped + 1))
    fi
fi

# --- 3. bootstrap.sh: Load timeout parser ---
if ! grep -q "timeout-parser" "$SHELLSPEC_DIR/lib/bootstrap.sh" 2>/dev/null; then
    log_info "Patching bootstrap.sh..."
    perl -i -pe '
        if (/\.\s+"\$SHELLSPEC_LIB\/general\.sh"/ && !$done) {
            $_ .= qq{\n# Load timeout parser (fallback to simple parser if missing)\nif [ -f "\$SHELLSPEC_LIB/libexec/timeout-parser.sh" ]; then\n  . "\$SHELLSPEC_LIB/libexec/timeout-parser.sh"\nelse\n  shellspec_parse_timeout() { echo "\${1:-\${SHELLSPEC_TIMEOUT:-60}}"; }\nfi\n};
            $done = 1;
        }
    ' "$SHELLSPEC_DIR/lib/bootstrap.sh"
    grep -q "timeout-parser" "$SHELLSPEC_DIR/lib/bootstrap.sh" \
        && { log_ok "bootstrap.sh: timeout-parser injected"; _patched=$((_patched + 1)); } \
        || log_warn "bootstrap.sh: patch may have failed"
else
    log_skip "bootstrap.sh: timeout-parser already present"
    _skipped=$((_skipped + 1))
fi

# --- 4. outputs.sh: Add TIMEOUT output function ---
if ! grep -q "shellspec_output_TIMEOUT" "$SHELLSPEC_DIR/lib/core/outputs.sh" 2>/dev/null; then
    log_info "Patching outputs.sh..."
    perl -i -pe '
        if (/^shellspec_output_NOT_IMPLEMENTED\(\)/ && !$done) {
            $_ = qq{shellspec_output_TIMEOUT() {\n  shellspec_output_statement "tag:timeout" "note:TIMEOUT" "fail:y" \\\\\n    "timeout:\$1" \\\\\n    "failure_message:\${SHELLSPEC_LINENO:+<\$SHELLSPEC_LINENO>}Test exceeded timeout" \\\\\n    "message:Test exceeded timeout of \$1 seconds"\n}\n\n} . $_;
            $done = 1;
        }
    ' "$SHELLSPEC_DIR/lib/core/outputs.sh"
    grep -q "shellspec_output_TIMEOUT" "$SHELLSPEC_DIR/lib/core/outputs.sh" \
        && { log_ok "outputs.sh: TIMEOUT function injected"; _patched=$((_patched + 1)); } \
        || log_warn "outputs.sh: patch may have failed"
else
    log_skip "outputs.sh: shellspec_output_TIMEOUT already present"
    _skipped=$((_skipped + 1))
fi

# --- 5. directives: Add %timeout ---
if ! grep -q "timeout" "$SHELLSPEC_DIR/lib/libexec/grammar/directives" 2>/dev/null; then
    log_info "Patching directives..."
    echo '%timeout     => timeout_metadata' >> "$SHELLSPEC_DIR/lib/libexec/grammar/directives"
    grep -q "timeout" "$SHELLSPEC_DIR/lib/libexec/grammar/directives" \
        && { log_ok "directives: %timeout added"; _patched=$((_patched + 1)); } \
        || log_warn "directives: patch may have failed"
else
    log_skip "directives: %timeout already present"
    _skipped=$((_skipped + 1))
fi

# --- 6. optparser.sh: Add check_timeout_format ---
if ! grep -q "check_timeout_format" "$SHELLSPEC_DIR/lib/libexec/optparser/optparser.sh" 2>/dev/null; then
    log_info "Patching optparser.sh..."
    # Add function before check_formatter
    perl -i -pe '
        if (/^check_formatter\(\)/ && !$done) {
            $_ = qq{check_timeout_format() {\n  case \$OPTARG in\n    0) return 0 ;;\n    *[!0-9smSM]*) return 1 ;;\n    *[0-9]|*[sSmM]) return 0 ;;\n    *) return 1 ;;\n  esac\n}\n\n} . $_;
            $done = 1;
        }
    ' "$SHELLSPEC_DIR/lib/libexec/optparser/optparser.sh"
    # Add error handler
    perl -i -pe '
        if (/check_number:\*\)/ && !$done) {
            $_ .= qq{    check_timeout_format:*) set -- "\$1" "Invalid timeout format (use NUMBER[s|m], e.g., 30, 30s, 1m): \$4" ;;\n};
            $done = 1;
        }
    ' "$SHELLSPEC_DIR/lib/libexec/optparser/optparser.sh"
    grep -q "check_timeout_format" "$SHELLSPEC_DIR/lib/libexec/optparser/optparser.sh" \
        && { log_ok "optparser.sh: check_timeout_format injected"; _patched=$((_patched + 1)); } \
        || log_warn "optparser.sh: patch may have failed"
else
    log_skip "optparser.sh: check_timeout_format already present"
    _skipped=$((_skipped + 1))
fi

# --- 7. parser_definition.sh: Add --timeout options ---
if ! grep -q "TIMEOUT" "$SHELLSPEC_DIR/lib/libexec/optparser/parser_definition.sh" 2>/dev/null; then
    log_info "Patching parser_definition.sh..."
    perl -i -pe '
        if (/--log-file/ && !$done) {
            $_ = qq{  param TIMEOUT --timeout validate:check_timeout_format init:=60 var:SECONDS -- \\\\\n    '\''Specify the default timeout for each test [default: 60]'\'' \\\\\n    '\''  Format: NUMBER[s|m] (e.g., 30, 30s, 1m, 90s)'\'' \\\\\n    '\''  Set to 0 to disable timeout'\''\n\n  flag TIMEOUT --no-timeout on:0 -- \\\\\n    '\''Disable timeout for all tests'\''\n\n} . $_;
            $done = 1;
        }
    ' "$SHELLSPEC_DIR/lib/libexec/optparser/parser_definition.sh"
    grep -q "TIMEOUT" "$SHELLSPEC_DIR/lib/libexec/optparser/parser_definition.sh" \
        && { log_ok "parser_definition.sh: TIMEOUT option injected"; _patched=$((_patched + 1)); } \
        || log_warn "parser_definition.sh: patch may have failed"
else
    log_skip "parser_definition.sh: TIMEOUT already present"
    _skipped=$((_skipped + 1))
fi

# --- 8. parser_definition_generated.sh: The big one - add exports + CLI parsing + help text ---
if ! grep -q "SHELLSPEC_TIMEOUT" "$SHELLSPEC_DIR/lib/libexec/optparser/parser_definition_generated.sh" 2>/dev/null; then
    log_info "Patching parser_definition_generated.sh..."

    # Add export line
    perl -i -pe '
        if (/SHELLSPEC_LOGFILE/ && !$done) {
            $_ = qq{export SHELLSPEC_TIMEOUT='\''60'\''\n} . $_;
            $done = 1;
        }
    ' "$SHELLSPEC_DIR/lib/libexec/optparser/parser_definition_generated.sh"

    # Add CLI completion entries (before --log-file completion)
    perl -i -0pe '
        s{(case\s+'\''--log-file'\'' in)}{      case '\''--timeout'\'' in
        "\$1") OPTARG=; break ;;
        \$1*) OPTARG="\$OPTARG --timeout"
      esac
      case '\''--no-timeout'\'' in
        "\$1") OPTARG=; break ;;
        \$1*) OPTARG="\$OPTARG --no-timeout"
      esac
      $1}ms' "$SHELLSPEC_DIR/lib/libexec/optparser/parser_definition_generated.sh"

    # Add option handlers (before --log-file handler)
    perl -i -0pe "
        s{(\\s+'\\''\\'--log-file'\\''\\'\\))}{      '--timeout')
        [ \\\$# -le 1 ] && set \"required\" \"\\\$1\" && break
        OPTARG=\\\$2
        check_timeout_format || { set -- check_timeout_format:\\\$? \"\\\$1\" check_timeout_format; break; }
        export SHELLSPEC_TIMEOUT=\"\\\$OPTARG\"
        shift ;;
      '--no-timeout')
        [ \"\\\${OPTARG:-}\" ] && OPTARG=\\\${OPTARG#*\\\\=} && set \"noarg\" \"\\\$1\" && break
        eval '[ \\\${OPTARG+x} ] &&:' && OPTARG='0' || OPTARG=''
        export SHELLSPEC_TIMEOUT=\"\\\$OPTARG\"
        ;;\n\$1}ms" "$SHELLSPEC_DIR/lib/libexec/optparser/parser_definition_generated.sh"

    # Add help text (before --log-file help line)
    perl -i -pe '
        if (/--log-file LOGFILE/ && !$done) {
            $_ = qq{        --timeout SECONDS           Specify the default timeout for each test [default: 60]\n                                      Format: NUMBER[s|m] (e.g., 30, 30s, 1m, 90s)\n                                      Set to 0 to disable timeout\n        --no-timeout                Disable timeout for all tests\n} . $_;
            $done = 1;
        }
    ' "$SHELLSPEC_DIR/lib/libexec/optparser/parser_definition_generated.sh"
    grep -q "SHELLSPEC_TIMEOUT" "$SHELLSPEC_DIR/lib/libexec/optparser/parser_definition_generated.sh" \
        && { log_ok "parser_definition_generated.sh: SHELLSPEC_TIMEOUT injected"; _patched=$((_patched + 1)); } \
        || log_warn "parser_definition_generated.sh: patch may have failed"
else
    log_skip "parser_definition_generated.sh: SHELLSPEC_TIMEOUT already present"
    _skipped=$((_skipped + 1))
fi

# --- 9. translator.sh: Add timeout override parsing ---
if ! grep -q "shellspec_timeout_override" "$SHELLSPEC_DIR/lib/libexec/translator.sh" 2>/dev/null; then
    log_info "Patching translator.sh..."

    # Add timeout_override init in check_filter + timeout parsing before check_tag_filter
    perl -i -0pe '
        s{(check_filter\(\)\s*\{[^\n]*\n\s*check_filter="\$1")}{$1\n  shellspec_timeout_override=""}ms;

        s{(\s+check_tag_filter\s+"\$\@")}{
  while [ \$# -gt 0 ]; do
    case \$1 in
      timeout:*) shellspec_timeout_override="\${1#timeout:}" ;;
    esac
    shift
  done

$1}ms;

        s{(^include\(\)\s*\{)}{timeout_metadata() {\n  :\n}\n\n$1}ms;
    ' "$SHELLSPEC_DIR/lib/libexec/translator.sh"
    grep -q "shellspec_timeout_override" "$SHELLSPEC_DIR/lib/libexec/translator.sh" \
        && { log_ok "translator.sh: timeout_override injected"; _patched=$((_patched + 1)); } \
        || log_warn "translator.sh: patch may have failed"
else
    log_skip "translator.sh: shellspec_timeout_override already present"
    _skipped=$((_skipped + 1))
fi

# --- 10. shellspec-translate.sh: Inject SHELLSPEC_EXAMPLE_TIMEOUT ---
if ! grep -q "SHELLSPEC_EXAMPLE_TIMEOUT" "$SHELLSPEC_DIR/libexec/shellspec-translate.sh" 2>/dev/null; then
    log_info "Patching shellspec-translate.sh..."
    perl -i -pe '
        if (/shellspec_example_id/ && !$done) {
            $_ .= qq{  if [ "\${shellspec_timeout_override:-}" ]; then\n    putsn "SHELLSPEC_EXAMPLE_TIMEOUT='\''\\$shellspec_timeout_override'\''"\n  else\n    putsn "SHELLSPEC_EXAMPLE_TIMEOUT='\'''\''"\n  fi\n};
            $done = 1;
        }
    ' "$SHELLSPEC_DIR/libexec/shellspec-translate.sh"
    grep -q "SHELLSPEC_EXAMPLE_TIMEOUT" "$SHELLSPEC_DIR/libexec/shellspec-translate.sh" \
        && { log_ok "shellspec-translate.sh: EXAMPLE_TIMEOUT injected"; _patched=$((_patched + 1)); } \
        || log_warn "shellspec-translate.sh: patch may have failed"
else
    log_skip "shellspec-translate.sh: SHELLSPEC_EXAMPLE_TIMEOUT already present"
    _skipped=$((_skipped + 1))
fi

# --- 11. dsl.sh: Add timeout execution logic (most complex modification) ---
# Check for the watchdog invocation specifically - not just shellspec_timeout_seconds,
# which can be partially written by 'patch --force' without the full functional logic.
if ! grep -q "shellspec-timeout-watchdog" "$SHELLSPEC_DIR/lib/core/dsl.sh" 2>/dev/null; then
    log_info "Patching dsl.sh (timeout execution logic)..."
    perl -i -0777 -pe '
        # Match the original execution block pattern (flexible whitespace matching)
        s{
            ([ \t]+return[ \t]+0\n[ \t]+fi\n)        # end of skip block
            (\n[ \t]+shellspec_profile_start)          # profile start
            (\n[ \t]+case[ \t]+\$-[ \t]+in\n[ \t]+\*e\*\).*?\n[ \t]+\*\).*?\n[ \t]+esac\n[ \t]+set[ \t]+\+e\n)  # set +e block
            [ \t]+\([ \t]+set[ \t]+-e\n              # ( set -e
            [ \t]+shift\n                             # shift
            [ \t]+case[ \t]+\$\#.*?\n                  # case $#
            [ \t]+0\)[ \t]+shellspec_invoke_example[ \t]+3>&2.*?\n  # 0) case
            [ \t]+\*\)[ \t]+shellspec_invoke_example.*?3>&2.*?\n    # *) case
            [ \t]+esac\n                              # esac
            [ \t]+\)\n                                # )
            [ \t]+set[ \t]+"\$1"[ \t]+--[ \t]+\$\?[ \t]+"\$SHELLSPEC_LEAK_FILE"  # set result
        }
        {$1
  # Timeout configuration per example
  shellspec_effective_timeout="\${SHELLSPEC_EXAMPLE_TIMEOUT:-\${SHELLSPEC_TIMEOUT:-60}}"
  shellspec_timeout_seconds=\$(shellspec_parse_timeout "\$shellspec_effective_timeout")
  shellspec_timeout_seconds=\${shellspec_timeout_seconds:-0}
  SHELLSPEC_TIMEOUT_SIGNAL_FILE="\$SHELLSPEC_STDIO_FILE_BASE.timeout_signal"
  SHELLSPEC_TIMEOUT_RESULT_FILE="\$SHELLSPEC_STDIO_FILE_BASE.timeout_result"
  if [ "\$shellspec_timeout_seconds" -gt 0 ] 2>/dev/null; then
    : > "\$SHELLSPEC_TIMEOUT_SIGNAL_FILE"
    : > "\$SHELLSPEC_TIMEOUT_RESULT_FILE"
  fi
$2$3
  if [ "\$shellspec_timeout_seconds" -gt 0 ] 2>/dev/null; then
    ( set -e
      shift
      case \$# in
        0) shellspec_invoke_example 3>&2 ;;
        *) shellspec_invoke_example "\$@" 3>&2 ;;
      esac
    ) &
    shellspec_test_pid=\$!

    ( "\$SHELLSPEC_SHELL" "\$SHELLSPEC_LIBEXEC/shellspec-timeout-watchdog.sh" \\
      "\$shellspec_timeout_seconds" "\$shellspec_test_pid" \\
      "\$SHELLSPEC_TIMEOUT_SIGNAL_FILE" "\$SHELLSPEC_TIMEOUT_RESULT_FILE" \\
    ) &

    wait "\$shellspec_test_pid"
    shellspec_exit_status=\$?

    shellspec_rm -f "\$SHELLSPEC_TIMEOUT_SIGNAL_FILE"
    if [ -s "\$SHELLSPEC_TIMEOUT_RESULT_FILE" ]; then
      shellspec_exit_status=124
      shellspec_timeout_occurred=1
    else
      shellspec_timeout_occurred=0
    fi
    shellspec_rm -f "\$SHELLSPEC_TIMEOUT_RESULT_FILE"
  else
    ( set -e
      shift
      case \$# in
        0) shellspec_invoke_example 3>&2 ;;
        *) shellspec_invoke_example "\$@" 3>&2 ;;
      esac
    )
    shellspec_exit_status=\$?
    shellspec_timeout_occurred=0
  fi

  set "\$1" -- \$shellspec_exit_status "\$SHELLSPEC_LEAK_FILE"

  if [ "\$shellspec_timeout_occurred" -eq 1 ]; then
    shellspec_output TIMEOUT "\$shellspec_timeout_seconds"
    shellspec_output FAILED
    shellspec_profile_end
    return 0
  fi
}xms' "$SHELLSPEC_DIR/lib/core/dsl.sh"

    # Verify the dsl.sh modification worked
    if grep -q "shellspec-timeout-watchdog" "$SHELLSPEC_DIR/lib/core/dsl.sh"; then
        log_ok "dsl.sh: timeout execution logic injected"
        _patched=$((_patched + 1))
    else
        log_warn "dsl.sh: perl regex did not match - per-example timeout will NOT work"
        log_warn "Expected to find 'shellspec_invoke_example 3>&2' block near 'shellspec_profile_start'."
        log_warn "Actual surrounding context in dsl.sh (for diagnosis):"
        grep -n "shellspec_invoke_example\|shellspec_profile_start\|set +e" \
            "$SHELLSPEC_DIR/lib/core/dsl.sh" 2>/dev/null | head -10 >&2 || true
    fi
else
    log_skip "dsl.sh: shellspec-timeout-watchdog already present"
    _skipped=$((_skipped + 1))
fi

log_info "Direct injection complete ($_patched patched, $_skipped skipped)"
