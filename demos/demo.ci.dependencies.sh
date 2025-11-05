#!/usr/bin/env bash

# Simple CI Auto-Install Mode Demonstration
# This demonstrates the concept without complex dependencies

set -e

echo "=== CI Auto-Install Mode Demonstration ==="
echo

# Simple function to check CI auto-install mode
function isCIAutoInstallEnabled() {
  local ci_enabled=false
  local auto_install_enabled=false
  
  # Check if CI is enabled (case-insensitive)
  case "${CI,,}" in
    1|true|yes) ci_enabled=true ;;
  esac
  
  # Check if auto-install is enabled (case-insensitive)
  case "${CI_E_BASH_INSTALL_DEPENDENCIES,,}" in
    1|true|yes) auto_install_enabled=true ;;
  esac
  
  if [[ "$ci_enabled" == "true" && "$auto_install_enabled" == "true" ]]; then
    echo "true"
  else
    echo "false"
  fi
}

# Simple dependency check simulation
function simulate_dependency_check() {
  local tool="$1"
  local version="$2"
  local install_cmd="$3"
  
  echo "Checking dependency: $tool"
  
  if command -v "$tool" >/dev/null 2>&1; then
    echo "  ✓ $tool found"
    return 0
  else
    echo "  ✗ $tool not found"
    
    if [[ "$(isCIAutoInstallEnabled)" == "true" ]]; then
      echo "  🔧 CI auto-install mode enabled - would execute: $install_cmd"
      return 0
    else
      echo "  💡 CI auto-install mode disabled - manual installation required"
      echo "     Run: $install_cmd"
      return 1
    fi
  fi
}

echo "🔧 Current environment:"
echo "   CI = ${CI:-'(not set)'}"
echo "   CI_E_BASH_INSTALL_DEPENDENCIES = ${CI_E_BASH_INSTALL_DEPENDENCIES:-'(not set)'}"
echo "   Auto-install enabled: $(isCIAutoInstallEnabled)"
echo

echo "📋 Testing dependency checks..."
echo

echo "1. Testing with existing tool (bash):"
simulate_dependency_check "bash" "5.*.*" "apt-get install bash"
echo

echo "2. Testing with non-existing tool (fake_tool):"
simulate_dependency_check "fake_tool" "1.0.0" "echo 'Installing fake_tool...'"
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

echo "📦 DIRENV Integration:"
echo "   # Install DIRENV in CI"
echo "   curl -sfL https://direnv.net/install.sh | bash"
echo "   echo \"\$HOME/.local/bin\" >> \"\$GITHUB_PATH\""
echo "   # Load project environment with auto-install"
echo "   direnv allow ."
echo "   direnv export gha >> \"\$GITHUB_ENV\""
echo "   # Now all dependencies from .envrc are available!"
echo

echo "🔗 Real implementation:"
echo "   See .scripts/_dependencies.sh for the full implementation"
echo "   See .envrc for project dependency declarations"
echo "   See .github/workflows/shellspec.yaml for CI integration"
echo

echo "=== Demo completed! ==="