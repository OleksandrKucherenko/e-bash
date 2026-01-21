# Self-Healing Scripts Pattern

A comprehensive guide to creating truly portable, self-sufficient Bash scripts that automatically resolve their own dependencies, including the e-bash library itself.

---

## Table of Contents

- [Overview](#overview)
- [The Problem](#the-problem)
- [The Solution](#the-solution)
- [Quick Start](#quick-start)
- [How It Works](#how-it-works)
- [Complete Example](#complete-example)
- [Integration Patterns](#integration-patterns)
- [Use Cases](#use-cases)
- [Best Practices](#best-practices)
- [FAQ](#faq)

---

## Overview

**Self-healing scripts** are Bash scripts that can automatically detect and resolve their own dependencies, including the e-bash library itself. They require zero manual setup and can be copied to any environment and run immediately.

### Key Characteristics

| Traditional Script | Self-Healing Script |
|-------------------|---------------------|
| Requires pre-installed libraries | Installs e-bash automatically if missing |
| Fails with "command not found" | Shows friendly message and auto-installs |
| Needs setup instructions in README | Zero setup - just run the script |
| CI requires manual dependency setup | CI gets dependencies automatically |
| Environment-specific | Truly portable |

---

## The Problem

Traditional scripts that use e-bash require manual setup:

```bash
# ❌ Traditional approach - requires manual setup
#!/usr/bin/env bash

# User must first install e-bash manually:
# curl -sSL https://git.new/e-bash | bash -s -- --global install

source "$E_BASH/_dependencies.sh"
source "$E_BASH/_logger.sh"
# ... rest of script
```

**Issues:**
- ❌ Users must read README to know about e-bash
- ❌ Scripts fail with cryptic errors if e-bash missing
- ❌ CI pipelines need extra setup steps
- ❌ Scripts aren't truly portable
- ❌ Onboarding friction for new team members

---

## The Solution

Self-healing scripts include a bootstrap function that automatically installs e-bash if it's not available:

```bash
# ✅ Self-healing approach - zero setup required
#!/usr/bin/env bash

function ebash:bootstrap() {
  # Detects or installs e-bash automatically
  # (see complete implementation below)
}

ebash:bootstrap  # Installs e-bash if needed

# Now use e-bash normally
source "$E_BASH/_dependencies.sh"
source "$E_BASH/_logger.sh"
# ... rest of script
```

**Benefits:**
- ✅ Zero manual setup required
- ✅ Friendly messages guide users through first run
- ✅ CI pipelines work without extra configuration
- ✅ Scripts are truly portable
- ✅ Instant onboarding for new developers

---

## Quick Start

### Step 1: Copy the Bootstrap Function

Add this function to the top of your script (after shebang and comments):

```bash
#!/usr/bin/env bash
## Your script header here

set -euo pipefail

# ============================================================================
# SELF-HEALING BOOTSTRAP
# ============================================================================

function ebash:bootstrap() {
  local install_url="https://git.new/e-bash"
  local install_needed=false

  # Check if E_BASH is already set and valid
  if [[ -n "${E_BASH:-}" ]] && [[ -d "$E_BASH" ]]; then
    echo "✓ e-bash found: $E_BASH" >&2
    return 0
  fi

  # Try to discover e-bash (project-local or global)
  local _src="${BASH_SOURCE[1]:-${BASH_SOURCE[0]:-$0}}"
  local project_local
  project_local=$(cd "${_src%/*}/../.scripts" 2>&- && pwd || echo "")
  local global_location="$HOME/.e-bash/.scripts"

  if [[ -d "$project_local" ]] && [[ -f "$project_local/_dependencies.sh" ]]; then
    E_BASH="$project_local"
    readonly E_BASH
    export E_BASH
    echo "✓ e-bash found (project): $E_BASH" >&2
  elif [[ -d "$global_location" ]] && [[ -f "$global_location/_dependencies.sh" ]]; then
    E_BASH="$global_location"
    readonly E_BASH
    export E_BASH
    echo "✓ e-bash found (global): $E_BASH" >&2
  else
    install_needed=true
  fi

  # Install e-bash globally if not found
  if [[ "$install_needed" == "true" ]]; then
    echo "" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "⚠ e-bash library not found" >&2
    echo "" >&2
    echo "This script requires the e-bash library to run." >&2
    echo "Installing e-bash globally to: $HOME/.e-bash" >&2
    echo "" >&2
    echo "This is a one-time setup and takes ~5 seconds." >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "" >&2

    # Check for required tools
    if ! command -v curl >/dev/null 2>&1; then
      echo "Error: curl is required for e-bash installation" >&2
      echo "Please install curl and try again" >&2
      exit 1
    fi

    # Perform global installation
    echo "→ Downloading e-bash installer..." >&2
    if curl -sSL "$install_url" | bash -s -- --global install; then
      E_BASH="$global_location"
      readonly E_BASH
      export E_BASH

      echo "" >&2
      echo "✓ e-bash installed successfully to: $E_BASH" >&2
      echo "" >&2
    else
      echo "" >&2
      echo "✗ Failed to install e-bash" >&2
      echo "" >&2
      echo "Manual installation:" >&2
      echo "  curl -sSL $install_url | bash -s -- --global install" >&2
      echo "" >&2
      exit 1
    fi
  fi

  # Load GNU tools
  if [[ -f "$E_BASH/_gnu.sh" ]]; then
    . "$E_BASH/_gnu.sh"
    local gnubin_path
    gnubin_path=$(cd "$E_BASH/../bin/gnubin" 2>&- && pwd || echo "")
    if [[ -n "$gnubin_path" ]]; then
      PATH="$gnubin_path:$PATH"
      export PATH
    fi
  fi

  return 0
}

# Execute bootstrap
ebash:bootstrap

# ============================================================================
# END OF SELF-HEALING BOOTSTRAP
# ============================================================================
```

### Step 2: Use e-bash Normally

After the bootstrap, use e-bash modules as usual:

```bash
# Now load e-bash modules normally
source "$E_BASH/_dependencies.sh"
source "$E_BASH/_logger.sh"
source "$E_BASH/_colors.sh"

# Your script logic here
logger:init main "[Main] " ">&2"
echo:Main "Hello, self-healing world!"
```

### Step 3: Run Anywhere

Your script is now truly portable:

```bash
# Works on any machine, even without e-bash pre-installed
./your-script.sh
```

**First run output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠ e-bash library not found

This script requires the e-bash library to run.
Installing e-bash globally to: /home/user/.e-bash

This is a one-time setup and takes ~5 seconds.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

→ Downloading e-bash installer...
✓ e-bash installed successfully to: /home/user/.e-bash/.scripts

[Main] Hello, self-healing world!
```

**Subsequent runs:**
```
✓ e-bash found (global): /home/user/.e-bash/.scripts
[Main] Hello, self-healing world!
```

---

## How It Works

### Detection Logic

The bootstrap follows this decision tree:

```
┌─────────────────────────┐
│ Is E_BASH already set?  │
└───────────┬─────────────┘
            │
            ├─ Yes → ✓ Use existing E_BASH
            │
            └─ No → Check project-local (.scripts/)
                    │
                    ├─ Found → ✓ Use project-local
                    │
                    └─ Not found → Check global (~/.e-bash/.scripts)
                                   │
                                   ├─ Found → ✓ Use global
                                   │
                                   └─ Not found → Install globally
                                                  │
                                                  └─ ✓ Use newly installed
```

### Installation Process

When e-bash is not found:

1. **Friendly message** - Explains what's happening and why
2. **Verify curl** - Ensures curl is available (required for download)
3. **Download installer** - Fetches from `https://git.new/e-bash`
4. **Run installer** - Executes with `--global install` flag
5. **Verify installation** - Checks that installation succeeded
6. **Set E_BASH** - Exports E_BASH variable for script use
7. **Continue execution** - Script proceeds normally

### Safety Features

- ✅ **Idempotent** - Safe to run multiple times
- ✅ **Non-destructive** - Never overwrites existing installations
- ✅ **Clear messaging** - Users understand what's happening
- ✅ **Graceful failure** - Shows manual installation steps if auto-install fails
- ✅ **No sudo required** - Installs to user's home directory
- ✅ **Version control friendly** - Global install doesn't pollute project

---

## Complete Example

See `demos/self-healing-script.sh` for a working example:

```bash
# Run the demo
./demos/self-healing-script.sh

# Try it in dry-run mode
DRY_RUN=true ./demos/self-healing-script.sh

# Enable debug logging
DEBUG=* ./demos/self-healing-script.sh
```

The demo showcases:
- Automatic e-bash installation
- Dependency validation
- Logger usage
- Dry-run wrappers
- Cleanup traps
- Cross-platform compatibility

---

## Integration Patterns

### Pattern 1: Standalone Utility Script

**Use case:** Single-file utility that can be shared via gist/email/Slack

```bash
#!/usr/bin/env bash
## Standalone utility - works anywhere

set -euo pipefail

# Self-healing bootstrap (copy-paste this section)
function ebash:bootstrap() { ... }
ebash:bootstrap

# Your utility logic
source "$E_BASH/_dependencies.sh"
dependency jq "1.*.*" "brew install jq"

# ... rest of utility
```

**Benefits:**
- Share as single file
- Recipients can run immediately
- No setup instructions needed

---

### Pattern 2: CI/CD Pipeline Script

**Use case:** Deployment or build script used in CI pipelines

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      # No setup needed! Script installs e-bash automatically
      - name: Deploy
        run: ./scripts/deploy.sh
        env:
          CI_E_BASH_INSTALL_DEPENDENCIES: 1  # Auto-install tool deps too
```

**Benefits:**
- Zero CI configuration for e-bash
- Works across different CI providers
- Same script works locally and in CI

---

### Pattern 3: Development Environment Bootstrap

**Use case:** Onboarding script for new developers

```bash
#!/usr/bin/env bash
## bootstrap-dev.sh - One-command dev setup

function ebash:bootstrap() { ... }
ebash:bootstrap

source "$E_BASH/_dependencies.sh"

# Force-install all dev tools
dependency node "18.*.*" "brew install node" --exec
dependency docker "24.*.*" "brew install docker" --exec
dependency kubectl "1.28.*" "brew install kubectl" --exec

echo "✓ Development environment ready!"
```

**Usage:**
```bash
# New developer on day 1
./bootstrap-dev.sh  # Gets everything they need automatically
```

**Benefits:**
- One-command onboarding
- Consistent dev environments
- Self-documenting requirements

---

### Pattern 4: Project Template

**Use case:** Create a script template for your team

```bash
#!/usr/bin/env bash
## team-script-template.sh
## Copy this template for all new scripts

set -euo pipefail

# ============================================================================
# SELF-HEALING BOOTSTRAP - DO NOT REMOVE
# ============================================================================
function ebash:bootstrap() { ... }
ebash:bootstrap
# ============================================================================

# Load your standard modules
source "$E_BASH/_dependencies.sh"
source "$E_BASH/_logger.sh"
source "$E_BASH/_colors.sh"
source "$E_BASH/_dryrun.sh"
source "$E_BASH/_traps.sh"

# Configure standard logging
DEBUG=${DEBUG:-"main"}
logger:init main "[${cl_cyan}Main]${cl_reset} " ">&2"

# Your script logic here
main() {
  echo:Main "Script logic goes here"
}

main "$@"
```

---

## Use Cases

### 1. Shared Automation Scripts

**Scenario:** You have automation scripts that multiple teams use.

**Challenge:** Each team has different setups, making scripts fail unpredictably.

**Solution:** Self-healing scripts work everywhere without coordination.

```bash
# Marketing team's machine
./generate-report.sh  # ✓ Works

# DevOps team's machine
./generate-report.sh  # ✓ Works

# New contractor's laptop
./generate-report.sh  # ✓ Works (auto-installs e-bash)
```

---

### 2. Internal Tooling Distribution

**Scenario:** You maintain internal CLI tools for your organization.

**Challenge:** Installation instructions get lost, tools break on upgrades.

**Solution:** Self-healing tools work out of the box.

```bash
# Share via internal wiki/confluence
curl https://internal/tools/db-backup.sh | bash

# Tool auto-installs e-bash and runs immediately
```

---

### 3. Open Source Projects

**Scenario:** Your OSS project has build/deploy scripts.

**Challenge:** Contributors have different environments.

**Solution:** Self-healing scripts reduce contribution friction.

```bash
# Contributor clones repo
git clone https://github.com/you/project

# Build script works immediately
./scripts/build.sh  # ✓ Auto-installs e-bash, builds successfully
```

---

### 4. Multi-Environment Deployments

**Scenario:** Deploy to dev/staging/prod across different clouds.

**Challenge:** Each environment has different tooling.

**Solution:** Same self-healing script works everywhere.

```bash
# AWS EC2 instance
./deploy.sh production

# GCP instance
./deploy.sh staging

# Azure VM
./deploy.sh development

# All auto-install e-bash and required tools
```

---

## Best Practices

### DO: Keep Bootstrap Function Updated

Periodically update the bootstrap function from the latest e-bash release:

```bash
# Check for updates to ebash:bootstrap function
curl -sSL https://raw.githubusercontent.com/OleksandrKucherenko/e-bash/master/demos/self-healing-script.sh | grep -A 100 "function ebash:bootstrap"
```

### DO: Test in Clean Environment

Verify self-healing works:

```bash
# Test in Docker container without e-bash
docker run --rm -it -v "$PWD:/app" ubuntu:22.04 bash -c "
  apt-get update && apt-get install -y curl &&
  cd /app &&
  ./your-script.sh
"
```

### DO: Document the Pattern

Add to your project's README:

```markdown
## Scripts

All scripts in this project use the self-healing pattern:
- No setup required
- Run any script immediately
- e-bash installs automatically on first run
```

### DON'T: Remove the Bootstrap

❌ Never remove the bootstrap thinking "e-bash is already installed":

```bash
# ❌ BAD - breaks portability
# function ebash:bootstrap() { ... }  # Commented out
# ebash:bootstrap
source "$E_BASH/_dependencies.sh"  # Fails if E_BASH not set!
```

✅ Always keep the bootstrap:

```bash
# ✅ GOOD - maintains portability
function ebash:bootstrap() { ... }
ebash:bootstrap
source "$E_BASH/_dependencies.sh"  # Always works
```

### DON'T: Use Project-Local for Self-Healing Scripts

Self-healing scripts should prefer global installation for portability:

```bash
# ✅ GOOD - global install for portability
# bootstrap installs to ~/.e-bash/.scripts

# ❌ BAD - project-local breaks portability
# Manual: curl -sSL https://git.new/e-bash | bash -s -- install
```

### DO: Combine with Dependency Auto-Install

Maximum portability:

```bash
ebash:bootstrap  # Installs e-bash if needed

source "$E_BASH/_dependencies.sh"

# Auto-install other tools too
export CI_E_BASH_INSTALL_DEPENDENCIES=1
dependency jq "1.*.*" "brew install jq"
dependency yq "4.*.*" "brew install yq"
```

---

## FAQ

### Q: What if the user already has e-bash installed?

**A:** The bootstrap detects existing installations and uses them. It only installs if e-bash is truly missing.

---

### Q: Does this work in CI?

**A:** Yes! CI environments without e-bash will automatically install it. Set `CI_E_BASH_INSTALL_DEPENDENCIES=1` to auto-install other tools too.

---

### Q: What if curl is not available?

**A:** The bootstrap checks for curl and shows a clear error message if it's missing. Users must install curl manually (it's available by default on most systems).

---

### Q: Can I use this with project-local e-bash installations?

**A:** Yes! The bootstrap prefers project-local installations if they exist. It only installs globally as a fallback.

---

### Q: What about air-gapped or restricted environments?

**A:** For air-gapped environments:
1. Pre-install e-bash globally: `curl -sSL https://git.new/e-bash | bash -s -- --global install`
2. Or bundle `.scripts/` with your project
3. The bootstrap will detect and use the existing installation

---

### Q: Does this add significant overhead?

**A:** Minimal:
- **First run**: ~5 seconds for e-bash installation (one-time)
- **Subsequent runs**: ~0.01 seconds for detection (negligible)

---

### Q: Can I customize the installation location?

**A:** The bootstrap uses `~/.e-bash/.scripts` for global installs (standard location). To use a different location, pre-set `E_BASH` before running the script:

```bash
export E_BASH=/opt/e-bash/.scripts
./your-script.sh  # Uses /opt/e-bash/.scripts
```

---

### Q: What if installation fails?

**A:** The bootstrap shows manual installation instructions and exits gracefully:

```
✗ Failed to install e-bash

Manual installation:
  curl -sSL https://git.new/e-bash | bash -s -- --global install
```

---

## Summary

Self-healing scripts represent the pinnacle of script portability:

| Feature | Traditional | Self-Healing |
|---------|-------------|--------------|
| **Setup required** | Yes (manual) | No (automatic) |
| **Works in CI** | Needs config | Yes (zero config) |
| **Portable** | No | Yes |
| **User-friendly** | No | Yes |
| **Onboarding time** | Hours | Seconds |
| **Failure mode** | Cryptic errors | Friendly messages |

**Copy the bootstrap function, add it to your scripts, and never worry about e-bash installation again!**

For a working example, see: `demos/self-healing-script.sh`
