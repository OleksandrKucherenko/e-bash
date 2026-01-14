#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034,SC2059

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-14
## Version: 2.0.2
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash
##
## Demo: Self-Update Functionality
##
## This demo showcases the self-update capabilities for projects using e-bash.
## It demonstrates version resolution, upgrades, downgrades, branch/tag pinning,
## and rollback scenarios.

export DEBUG=${DEBUG:-"git,version,loader"}

# Bootstrap: 1) E_BASH discovery (only if not set), 2) gnubin setup (always)
[ "$E_BASH" ] || { _src=${BASH_SOURCE:-$0}; E_BASH=$(cd "${_src%/*}/../.scripts" 2>&- && pwd || echo ~/.e-bash/.scripts); readonly E_BASH; }
. "$E_BASH/_gnu.sh"; PATH="$(cd "$E_BASH/../bin/gnubin" 2>&- && pwd):$PATH"

# include self-update module
# shellcheck disable=SC1090 source=../.scripts/_self-update.sh
source "$E_BASH/_self-update.sh"

# Helper function to print section headers
function demo:section() {
  echo ""
  echo "╔════════════════════════════════════════════════════════════════════════╗"
  echo "║ $1"
  echo "╚════════════════════════════════════════════════════════════════════════╝"
  echo ""
}

# Helper function to print step headers
function demo:step() {
  echo ""
  echo "→ $1"
  echo ""
}

# ============================================================================
# INITIALIZATION
# ============================================================================

demo:section "SELF-UPDATE DEMO: Initialization"

demo:step "Initialize e-bash repository in ~/.e-bash/"
self-update:initialize

demo:step "Extract first version (v1.0.0)"
self-update:version:get:first

demo:step "Extract latest version"
self-update:version:get:latest

# ============================================================================
# Core functions check
# ============================================================================

demo:section "CORE FUNCTIONS CHECK"
demo:step "1. self-update:version:find"

# set -x
self-update:version:find "1.0.0"

# ============================================================================
# VERSION RESOLUTION DEMONSTRATIONS
# ============================================================================

demo:section "VERSION RESOLUTION: New Notation Patterns"

demo:step "1. Resolve 'latest' notation (latest stable, no pre-release)"
echo "Expression: 'latest'"
echo "Resolves to: $(self-update:version:resolve "latest")"

demo:step "2. Resolve '*' notation (highest version, including pre-release)"
echo "Expression: '*'"
echo "Resolves to: $(self-update:version:resolve "*")"

demo:step "3. Resolve 'next' notation (same as '*')"
echo "Expression: 'next'"
echo "Resolves to: $(self-update:version:resolve "next")"

demo:step "4. Resolve 'branch:master' notation"
echo "Expression: 'branch:master'"
echo "Resolves to: $(self-update:version:resolve "branch:master")"

demo:step "5. Resolve 'tag:v1.0.0' notation"
echo "Expression: 'tag:v1.0.0'"
echo "Resolves to: $(self-update:version:resolve "tag:v1.0.0")"

demo:step "6. Resolve semver constraint '^1.0.0' (minor/patch allowed)"
echo "Expression: '^1.0.0'"
echo "Resolves to: $(self-update:version:resolve "^1.0.0")"

demo:step "7. Resolve semver constraint '~1.0.0' (patch only)"
echo "Expression: '~1.0.0'"
echo "Resolves to: $(self-update:version:resolve "~1.0.0")"

# ============================================================================
# VERSION INFORMATION
# ============================================================================

demo:section "VERSION INFORMATION: Query Available Versions"

demo:step "Find highest version tag (including pre-release)"
echo "Highest tag: $(self-update:version:find:highest_tag)"

demo:step "Find latest stable version tag (no pre-release)"
echo "Latest stable: $(self-update:version:find:latest_stable)"

demo:step "Find version matching constraint '^1.0.0'"
echo "Match for '^1.0.0': $(self-update:version:find "^1.0.0")"

demo:step "List all available versions"
self-update:version:tags
echo "Available versions:"
for version in "${__REPO_VERSIONS[@]}"; do
  tag="${__REPO_MAPPING[$version]}"
  echo "  - $tag ($version)"
done

# ============================================================================
# FILE VERSION BINDING & MANAGEMENT
# ============================================================================

demo:section "FILE VERSION BINDING: Link Files to Specific Versions"

TEST_FILE="$E_BASH/_colors.sh"

demo:step "Get current version of _colors.sh"
current_version=$(self-update:self:version "$TEST_FILE")
echo "Current version: $current_version"

demo:step "Compute file hash"
file_hash=$(self-update:file:hash "$TEST_FILE")
echo "SHA1 hash: $file_hash"

demo:step "Bind _colors.sh to v1.0.0"
self-update:version:bind "v1.0.0" "$TEST_FILE"
ls -la "$E_BASH" | grep _colors

demo:step "Compute hash of versioned file (v1.0.0)"
version_hash=$(self-update:version:hash "$TEST_FILE" "v1.0.0")
echo "Version v1.0.0 hash: $version_hash"

# ============================================================================
# UPGRADE SCENARIOS
# ============================================================================

demo:section "UPGRADE SCENARIOS: Different Upgrade Patterns"

demo:step "Scenario 1: Upgrade to latest stable version"
echo "Command: self-update \"latest\" \"$TEST_FILE\""
echo "This will upgrade to the highest stable version (no alpha/beta/rc)"
# Uncomment to execute:
# self-update "latest" "$TEST_FILE"

demo:step "Scenario 2: Upgrade to cutting edge (including pre-release)"
echo "Command: self-update \"*\" \"$TEST_FILE\""
echo "This will upgrade to the absolute highest version, including pre-releases"
# Uncomment to execute:
# self-update "*" "$TEST_FILE"

demo:step "Scenario 3: Upgrade within minor version range"
echo "Command: self-update \"^1.0.0\" \"$TEST_FILE\""
echo "This allows minor and patch updates: >= 1.0.0 && < 2.0.0"
# Uncomment to execute:
# self-update "^1.0.0" "$TEST_FILE"

demo:step "Scenario 4: Upgrade within patch version range"
echo "Command: self-update \"~1.0.0\" \"$TEST_FILE\""
echo "This allows only patch updates: >= 1.0.0 && < 1.1.0"
# Uncomment to execute:
# self-update "~1.0.0" "$TEST_FILE"

# ============================================================================
# DOWNGRADE SCENARIOS
# ============================================================================

demo:section "DOWNGRADE SCENARIOS: Reverting to Older Versions"

demo:step "Scenario 1: Downgrade to specific tag"
echo "Command: self-update \"tag:v1.0.0\" \"$TEST_FILE\""
echo "This pins the file to a specific tag version"
# Uncomment to execute:
# self-update "tag:v1.0.0" "$TEST_FILE"

demo:step "Scenario 2: Downgrade using exact version"
echo "Command: self-update \"1.0.0\" \"$TEST_FILE\""
echo "This downgrades to exactly version 1.0.0"
# Uncomment to execute:
# self-update "1.0.0" "$TEST_FILE"

demo:step "Scenario 3: Rollback to previous version"
echo "Command: self-update:rollback:version \"v1.0.0\" \"$TEST_FILE\""
echo "This manually rolls back to a specific version"
self-update:rollback:version "v1.0.0" "$TEST_FILE"
ls -la "$E_BASH" | grep _colors

# ============================================================================
# BRANCH/TAG PINNING SCENARIOS
# ============================================================================

demo:section "BRANCH/TAG PINNING: Development & Testing"

demo:step "Scenario 1: Pin to master branch (bleeding edge)"
echo "Command: self-update \"branch:master\" \"$TEST_FILE\""
echo "This tracks the master branch HEAD (latest development)"
# Uncomment to execute:
# self-update "branch:master" "$TEST_FILE"

demo:step "Scenario 2: Pin to development branch"
echo "Command: self-update \"branch:develop\" \"$TEST_FILE\""
echo "This tracks a development branch (if it exists)"
# Uncomment to execute:
# self-update "branch:develop" "$TEST_FILE"

demo:step "Scenario 3: Pin to specific pre-release tag"
echo "Command: self-update \"tag:v1.0.1-alpha.1\" \"$TEST_FILE\""
echo "This pins to a specific pre-release version for testing"
# Uncomment to execute:
# self-update "tag:v1.0.1-alpha.1" "$TEST_FILE"

# ============================================================================
# ROLLBACK & RECOVERY
# ============================================================================

demo:section "ROLLBACK & RECOVERY: Undo Changes"

demo:step "Scenario 1: Unlink file (convert symlink to regular file)"
echo "Command: self-update:unlink \"$TEST_FILE\""
self-update:unlink "$TEST_FILE"
ls -la "$E_BASH" | grep _colors

demo:step "Scenario 2: Rollback from backup files"
echo "Backup files created: .~N~ format"
find "${E_BASH}" -name "_colors.sh.~*~" | head -3

echo ""
echo "Command: self-update:rollback:backup \"$TEST_FILE\""
echo "This restores from the latest numbered backup"

# Restore from backup if backups exist
while find "${E_BASH}" -name "_colors.sh.~*~" | grep . >/dev/null; do
  self-update:rollback:backup "${E_BASH}/_colors.sh"
  break # Just do one for demo
done

demo:step "Scenario 3: Try to unlink non-linked file (error handling)"
# This should show: "e-bash unlink: _colors.sh - NOT A LINK"
self-update:unlink "$E_BASH/_colors.sh"

# ============================================================================
# REAL-WORLD USAGE PATTERNS
# ============================================================================

demo:section "REAL-WORLD USAGE PATTERNS"

demo:step "Pattern 1: Auto-update on script exit (Recommended)"
cat << 'EOF'
#!/usr/bin/env bash
source ".scripts/_self-update.sh"
source ".scripts/_traps.sh"

# Update to latest compatible version when script exits
function on_exit_update() {
  self-update '^1.0.0'
}
trap:on on_exit_update EXIT

# Your script logic here...
echo "Script running with e-bash v$(self-update:self:version)"
EOF

demo:step "Pattern 2: Conditional update based on environment"
cat << 'EOF'
#!/usr/bin/env bash
source ".scripts/_self-update.sh"
source ".scripts/_traps.sh"

function on_exit_update() {
  if [[ "${CI}" == "true" ]]; then
    # In CI: use stable versions only
    self-update 'latest'
  else
    # Local development: allow pre-releases
    self-update '*'
  fi
}
trap:on on_exit_update EXIT
EOF

demo:step "Pattern 3: Pin to specific version in production"
cat << 'EOF'
#!/usr/bin/env bash
source ".scripts/_self-update.sh"
source ".scripts/_traps.sh"

function on_exit_update() {
  if [[ "${ENVIRONMENT}" == "production" ]]; then
    # Production: pin to tested version
    self-update "tag:v1.0.0"
  else
    # Other environments: use latest stable
    self-update "latest"
  fi
}
trap:on on_exit_update EXIT
EOF

demo:step "Pattern 4: Update specific files independently"
cat << 'EOF'
#!/usr/bin/env bash
source ".scripts/_self-update.sh"

# Update core files to stable
self-update "latest" ".scripts/_logger.sh"
self-update "latest" ".scripts/_commons.sh"

# Keep experimental features on bleeding edge
self-update "*" ".scripts/_experimental.sh"
EOF

demo:step "Pattern 5: Version constraints for compatibility"
cat << 'EOF'
#!/usr/bin/env bash
source ".scripts/_self-update.sh"

# Stay on 1.x.x for compatibility with legacy systems
self-update "^1.0.0"

# Or: allow only critical patches
self-update "~1.0.0"

# Or: specific range
self-update ">1.0.0 <=1.5.0"
EOF

# ============================================================================
# PATH RESOLUTION TESTS
# ============================================================================

demo:section "PATH RESOLUTION: Testing Different Path Formats"

demo:step "Resolve absolute path"
path:resolve "$E_BASH/_colors.sh"

demo:step "Resolve relative path from current directory"
path:resolve "../.scripts/_colors.sh"

demo:step "Resolve path relative to script directory"
path:resolve "./demo.semver.sh"

demo:step "Resolve with explicit working directory"
path:resolve "./demo.semver.sh" "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# SUMMARY
# ============================================================================

demo:section "DEMO COMPLETE: Summary"

cat << 'EOF'
✅ Demonstrated Features:

1. Version Resolution:
   - latest, *, next notations
   - branch:{name} and tag:{name} patterns
   - Semver constraints (^, ~, ranges)

2. Upgrade Scenarios:
   - Latest stable vs cutting edge
   - Constrained version ranges
   - Incremental updates

3. Downgrade Scenarios:
   - Specific version pinning
   - Tag-based downgrades
   - Manual rollback

4. Branch/Tag Pinning:
   - Development branch tracking
   - Pre-release testing
   - Production version pinning

5. Rollback & Recovery:
   - Backup file management
   - Symlink unlinking
   - Version restoration

6. Real-World Patterns:
   - Auto-update on exit
   - Environment-based strategies
   - Independent file versioning

For more information:
  - README.md: Overview and quick start
  - .scripts/_self-update.sh: Implementation details
  - spec/self_update_spec.sh: Unit tests and examples

Next steps:
  - Uncomment the example commands above to test live updates
  - Integrate self-update into your own scripts
  - Experiment with different version expressions
EOF

echo ""
echo "Demo finished successfully!"
echo ""
