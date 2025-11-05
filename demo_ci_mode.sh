#!/usr/bin/env bash

# Demo script showing CI auto-install mode in action
# This demonstrates how the new CI_E_BASH_INSTALL_DEPENDENCIES feature works

set -e

echo "=== CI Auto-Install Mode Demonstration ==="
echo

# Setup - create minimal environment
export E_BASH="$(pwd)/.scripts"

# Mock logger functions to avoid dependencies
function logger() { echo "$@" >/dev/null; }
function config:logger:Dependencies() { echo "$@" >/dev/null; }
function printf:Dependencies() { printf "$@" >/dev/null; }
function echo:Dependencies() { echo "$@" >/dev/null; }

# Source only the dependencies script functions
source <(sed -n '/^function isDebug/,/^${__SOURCED__:+return}/p' "$E_BASH/_dependencies.sh")

echo "🔧 Current environment:"
echo "   CI = ${CI:-'(not set)'}"
echo "   CI_E_BASH_INSTALL_DEPENDENCIES = ${CI_E_BASH_INSTALL_DEPENDENCIES:-'(not set)'}"
echo "   Auto-install enabled: $(isCIAutoInstallEnabled && echo 'YES' || echo 'NO')"
echo

echo "📋 Testing dependency checks..."
echo

# Test with existing tool
echo "1. Testing with existing tool (bash):"
dependency bash "5.*.*" "echo 'Would install bash here'"
echo

# Test with non-existing tool (will show different behavior based on CI mode)
echo "2. Testing with non-existing tool:"
if [ "$(isCIAutoInstallEnabled)" == "true" ]; then
    echo "   CI mode is ENABLED - would auto-install missing tools"
    echo "   Example: dependency fake_tool \"1.0.0\" \"echo 'Installing fake_tool...'\""
    dependency fake_tool "1.0.0" "echo 'Installing fake_tool...'" 2>/dev/null || echo "   ✓ Auto-install attempted (simulated)"
else
    echo "   CI mode is DISABLED - will show error for missing tools"
    echo "   Example: dependency fake_tool \"1.0.0\" \"echo 'Installing fake_tool...'\""
    dependency fake_tool "1.0.0" "echo 'Installing fake_tool...'" 2>/dev/null || echo "   ✓ Error shown as expected"
fi
echo

echo "🎯 To enable CI auto-install mode:"
echo "   export CI=1"
echo "   export CI_E_BASH_INSTALL_DEPENDENCIES=1"
echo "   # or CI_E_BASH_INSTALL_DEPENDENCIES=true/yes (case-insensitive)"
echo

echo "🚀 Usage in CI pipelines:"
echo "   - Docker: ENV CI=1 CI_E_BASH_INSTALL_DEPENDENCIES=1"
echo "   - GitHub Actions: env: CI_E_BASH_INSTALL_DEPENDENCIES: 1"
echo "   - GitLab CI: variables: CI_E_BASH_INSTALL_DEPENDENCIES: \"1\""
echo

echo "=== Demo completed! ==="