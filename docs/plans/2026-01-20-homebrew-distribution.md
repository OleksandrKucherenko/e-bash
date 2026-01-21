# Homebrew Distribution Plan for e-bash

**Date:** 2026-01-20
**Status:** Draft
**Author:** Claude Code

## Overview

This plan outlines the implementation of Homebrew distribution for the e-bash library, enabling users to install and manage e-bash via `brew install`. The implementation involves three major components:

1. Creating a Homebrew formula for e-bash
2. Setting up a custom Homebrew tap repository
3. Implementing CI/CD automation for distribution

## Table of Contents

- [1. Background & Current State](#1-background--current-state)
- [2. Installation Methods Comparison & Positioning](#2-installation-methods-comparison--positioning)
- [3. Enhanced Installer Features](#3-enhanced-installer-features)
- [4. Homebrew Tap Repository Setup](#4-homebrew-tap-repository-setup)
- [5. Homebrew Formula Design](#5-homebrew-formula-design)
- [6. CI/CD Workflow for Distribution](#6-cicd-workflow-for-distribution)
- [7. User Installation Experience](#7-user-installation-experience)
- [8. Implementation Tasks](#8-implementation-tasks)
- [9. Testing Strategy](#9-testing-strategy)
- [10. Rollback & Recovery](#10-rollback--recovery)

---

## 1. Background & Current State

### Current Installation Methods

e-bash currently supports installation via:

1. **curl pipe to bash** (recommended for projects):
   ```bash
   curl -sSL https://git.new/e-bash | bash -s --
   ```

2. **Git subtree** (for embedding in repositories):
   ```bash
   git subtree merge --prefix .scripts e-bash-scripts --squash
   ```

3. **Global installation** (to `~/.e-bash/`):
   ```bash
   curl -sSL https://git.new/e-bash | bash -s -- install --global
   ```

### Current Release Infrastructure

- GitHub Releases triggered by tags (`v*`)
- Distribution archive: `e-bash.{version}.zip`
- Archive contains: `.scripts/`, `bin/`, `docs/`, `demos/`, `README.md`, `LICENSE`
- SHA256 checksum verification
- Existing workflow: `.github/workflows/release.yaml`

### Why Homebrew?

- Standard package manager for macOS developers
- Automatic dependency resolution
- Version management and upgrades
- Integration with system PATH
- Familiar UX for most developers

---

## 2. Installation Methods Comparison & Positioning

### Installation Methods Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        e-bash Installation Methods                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────────────────────┐    ┌──────────────────────────────────┐  │
│  │   curl | bash (Original)     │    │   brew install (New)             │  │
│  │   Project or Global          │    │   System-level                   │  │
│  └──────────────┬───────────────┘    └──────────────┬───────────────────┘  │
│                 │                                   │                      │
│                 │  Archive from GitHub Releases     │                      │
│                 ├───────────────────────────────────┤                      │
│                 │                                   │                      │
│                 ▼                                   ▼                      │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │              install.e-bash.sh (or e-bash cmd)                        │  │
│  │  ┌─────────────────┬─────────────────┬─────────────────────────┐    │  │
│  │  │ Default Repo    │ Custom Repo     │ Global Install          │    │  │
│  │  │ (upstream)      │ (--repo flag)   │ (--global flag)         │    │  │
│  │  └─────────────────┴─────────────────┴─────────────────────────┘    │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                              │                                            │
│                              ▼                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │         Shell RC Configuration (.bashrc, .zshrc, etc)               │  │
│  │  ┌─────────────────────────────────────────────────────────────┐    │  │
│  │  │ export E_BASH="..."                                         │    │  │
│  │  │ export PATH=".../bin:$PATH"  (for e-bash command)           │    │  │
│  │  │ [Linux] export PATH=".../bin/gnubin:$PATH"                  │    │  │
│  │  └─────────────────────────────────────────────────────────────┘    │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Method Comparison

| Feature | curl | brew |
|---------|------|------|
| **Install location** | `.scripts/` or `~/.e-bash` | `$(brew --prefix)/opt/e-bash/libexec` |
| **Project embedding** | ✅ Git subtree into repo | ❌ Not designed for this |
| **System-level** | ✅ via `--global` | ✅ Primary use case |
| **Custom repo** | ✅ Via `--repo` flag | ❌ Uses upstream only |
| **Shell RC** | ✅ Auto-modifies (`--global`) | ⚠️ Shows instructions (standard) |
| **Version pinning** | ✅ Specific tags | ✅ Versioned formulas |
| **Dependency mgmt** | Manual (via installer) | ✅ Automatic via brew |
| **Upgrades** | `upgrade` command | `brew upgrade` |
| **Multi-user** | Per-project setup | System-wide shared |

### Positioning Statement

Homebrew installation is an **ADDITIONAL method**, not a replacement:

```markdown
## Homebrew Installation Scope

Homebrew provides a **system-level** installation similar to `install.e-bash.sh --global`,
but with Homebrew's package management benefits (dependencies, upgrades, discovery).

### Use Homebrew When:
- You want e-bash available system-wide
- You prefer package manager integration
- You want automatic dependency management (bash 5.x)
- You're comfortable setting `E_BASH` in your shell RC

### Use curl Installer When:
- You want e-bash embedded in your project repository
- You need project-specific versioning
- You want git subtree integration
- You're working in a team without Homebrew
- You need custom fork installation

### Compatibility:
Both methods can coexist. Homebrew installs to `/opt/homebrew/opt/e-bash/libexec`
or `/home/linuxbrew/.linuxbrew/opt/e-bash/libexec`, while the installer uses
`~/.e-bash/.scripts` or `.scripts/` in your project.
```

### Shell RC Handling Approaches

#### curl Installer (`install.e-bash.sh`)
**Auto-modifies shell RC** for `--global` installs:

```bash
# Lines 1102-1138 in install.e-bash.sh
# Adds to ~/.bashrc automatically:
export E_BASH="${HOME}/.e-bash/.scripts"
```

#### Homebrew Formula
**Shows instructions in caveats** + **Optional helper script** (Option A - Standard Homebrew pattern):

```ruby
def caveats
  <<~EOS
    e-bash library has been installed to: #{libexec}

    To use e-bash, add the following to your ~/.bashrc or ~/.zshrc:
      export E_BASH="#{opt_libexec}"

    Or use the helper to automatically add it:
      brew e-bash-setup

    For project-level installation (embedded in your repo), use:
      curl -sSL https://git.new/e-bash | bash -s --
  EOS
end
```

**Rationale for Option A:**
- Homebrew formulas typically don't auto-modify user dotfiles
- Users expect to manually configure shell RC
- Follows Homebrew conventions (see: `nvm`, `pyenv` formulas)
- Optional helper provides automation for those who want it

---

## 3. Enhanced Installer Features

### 3.1 Custom Repository Support

The installer will support installation from custom git repositories via CLI flags.

**Current State:** Already supports via environment variables (lines 24-28)

**Enhancement:** Add user-friendly CLI flags

```bash
# New CLI flags
--repo <url>        # Custom git repository URL
--branch <name>     # Custom branch name (default: master)
```

**Implementation Changes:**

1. **Remove `readonly` from relevant variables** (lines 24-27):

```bash
# Change from:
readonly REMOTE_URL="${E_BASH_REMOTE_URL:-https://github.com/OleksandrKucherenko/e-bash.git}"

# To:
REMOTE_URL="${E_BASH_REMOTE_URL:-https://github.com/OleksandrKucherenko/e-bash.git}"
```

2. **Add to `preparse_args()` function** (around line 2228):

```bash
function preparse_args() {
  local args=("$@")

  for i in "${!args[@]}"; do
    key="${args[i]}"

    # ... existing flags ...

    elif [[ "$key" == "--repo" ]]; then
      # Get the next argument as the repository URL
      local next_idx=$((i + 1))
      if [ -n "${args[$next_idx]}" ] && [[ "${args[$next_idx]}" != --* ]]; then
        REMOTE_URL="${args[$next_idx]}"
        unset 'args[i]' 'args[next_idx]'
      else
        echo -e "${RED}Error: --repo requires a URL argument${NC}" >&2
        print_usage $EXIT_NO
      fi
    elif [[ "$key" == "--branch" ]]; then
      local next_idx=$((i + 1))
      if [ -n "${args[$next_idx]}" ] && [[ "${args[$next_idx]}" != --* ]]; then
        REMOTE_MASTER="${args[$next_idx]}"
        unset 'args[i]' 'args[next_idx]'
      fi
    # ... existing flags ...
  done
}
```

**Usage Examples:**

```bash
# Default (upstream)
curl -sSL https://git.new/e-bash | bash -s --

# Custom company fork
curl -sSL https://git.new/e-bash | bash -s -- --repo https://github.com/company/e-bash.git

# With specific branch
curl -sSL https://git.new/e-bash | bash -s -- --repo https://github.com/company/e-bash.git --branch main

# Via environment variable (existing method)
export E_BASH_REMOTE_URL="https://github.com/company/e-bash.git"
curl -sSL https://git.new/e-bash | bash -s --
```

### 3.2 Usage Documentation

Add to `print_usage()` function (lines 221-262):

```bash
echo -e "Options:"
echo -e "  ${YELLOW}--dry-run${NC}             - Run in dry run mode (no changes)"
echo -e "  ${YELLOW}--global${NC}              - Install scripts to user's '\${HOME}' directory instead of current repository"
echo -e "  ${YELLOW}--directory <path>${NC}    - Custom installation directory (default: .scripts). Creates .ebashrc config file."
echo -e "  ${YELLOW}--[no-]create-symlink${NC} - Create symlink to global e-bash scripts (default: true)"
echo -e "  ${YELLOW}--force${NC}               - Force overwrite of existing scripts with auto-backup"
echo -e "  ${YELLOW}--repo <url>${NC}          - Custom git repository URL"
echo -e "  ${YELLOW}--branch <name>${NC}       - Custom branch name (default: master)"
echo ""
```

---

## 4. Homebrew Tap Repository Setup

### 4.1 Repository Structure

Create a new GitHub repository: `OleksandrKucherenko/homebrew-e-bash`

> **Important:** GitHub-hosted taps **must** follow the naming convention `homebrew-<tapname>` to enable the short `brew tap user/tapname` command. The `homebrew-` prefix is automatically stripped when users reference the tap.

```
homebrew-e-bash/
├── Formula/
│   └── e-bash.rb              # Main formula (CLI packages)
├── Casks/                     # (optional, for future GUI tools)
├── Aliases/                   # Symlinks for alternative formula names
├── cmd/                       # Custom brew commands (optional)
├── .github/
│   └── workflows/
│       ├── test-formula.yaml   # Formula testing
│       └── update-formula.yaml # Automated updates
├── tap_migrations.json         # Track formula relocations (optional)
├── README.md
└── LICENSE
```

**Directory Discovery:** Homebrew uses regex pattern matching to discover formulas. It checks `Formula/`, `HomebrewFormula/`, or root directory (first found is used). Using `Formula/` is recommended for clearer organization.

### 4.2 Repository Creation Steps

```bash
# Create the tap repository on GitHub
# Repository name MUST follow pattern: homebrew-<tapname>

# Initialize locally
mkdir homebrew-e-bash && cd homebrew-e-bash
git init

# Create required directory structure
mkdir -p Formula .github/workflows

# Create README
cat > README.md << 'EOF'
# Homebrew Tap for e-bash

This tap provides Homebrew formulae for [e-bash](https://github.com/OleksandrKucherenko/e-bash) - a comprehensive Bash script enhancement framework.

## Installation

$$ brew tap OleksandrKucherenko/e-bash
$$ brew install e-bash

## Updating

$$ brew update
$$ brew upgrade e-bash

## Formulae

| Formula  | Description                                                                       |
| -------- | --------------------------------------------------------------------------------- |
| `e-bash` | Bash script enhancement framework with logging, dependencies, arguments, and more |

## License

MIT License - see [e-bash repository](https://github.com/OleksandrKucherenko/e-bash) for details.
EOF

# Create LICENSE (MIT)
cp /path/to/e-bash/LICENSE ./LICENSE
```

### 4.3 GitHub Repository Settings

Configure the tap repository:

- **Visibility:** Public (required for Homebrew taps)
- **Branch protection:** Protect `main` branch
- **Secrets required:**
  - `TAP_GITHUB_TOKEN` - PAT with `repo` scope for cross-repo automation

---

## 5. Homebrew Formula Design

### 5.1 Formula: `Formula/e-bash.rb`

> **Creating the formula:** Use `brew create --tap OleksandrKucherenko/e-bash <URL>` to generate a starter formula, then customize it.

```ruby
# typed: false
# frozen_string_literal: true

# Formula for e-bash - Bash script enhancement framework
# https://github.com/OleksandrKucherenko/e-bash
class EBash < Formula
  desc "Comprehensive Bash script enhancement framework with logging, dependencies, and more"
  homepage "https://github.com/OleksandrKucherenko/e-bash"
  url "https://github.com/OleksandrKucherenko/e-bash/releases/download/v1.16.2/e-bash.1.16.2.zip"
  sha256 "CHECKSUM_PLACEHOLDER"
  license "MIT"
  head "https://github.com/OleksandrKucherenko/e-bash.git", branch: "master"

  # Homebrew bash (macOS ships with Bash 3.2, e-bash requires 5.x features)
  depends_on "bash"

  # Optional dependencies for full functionality
  uses_from_macos "grep"

  def install
    # Install core library scripts to libexec (private, not in PATH)
    # libexec is for scripts that shouldn't be directly executed by users
    libexec.install Dir[".scripts/*"]

    # Install bin tools (these get symlinked to HOMEBREW_PREFIX/bin)
    bin.install Dir["bin/*"].reject { |f| File.directory?(f) }

    # Install gnubin shims to libexec (not directly in PATH)
    if Dir.exist?("bin/gnubin")
      (libexec/"gnubin").install Dir["bin/gnubin/*"]
    end

    # Install documentation to HOMEBREW_PREFIX/share/doc/e-bash
    doc.install "README.md", "LICENSE"
    (doc/"public").install Dir["docs/public/*"] if Dir.exist?("docs/public")

    # Install demos to HOMEBREW_PREFIX/share/e-bash/demos
    (pkgshare/"demos").install Dir["demos/*"] if Dir.exist?("demos")

    # Create environment setup script
    # Users source this to configure E_BASH and PATH
    (bin/"e-bash-env").write <<~EOS
      #!/usr/bin/env bash
      # Source this file to set up e-bash environment
      # Usage: source "$(brew --prefix)/bin/e-bash-env"
      export E_BASH="#{libexec}"
      [[ -d "#{libexec}/gnubin" ]] && export PATH="#{libexec}/gnubin:$PATH"
    EOS
    chmod 0755, bin/"e-bash-env"

    # Create e-bash wrapper command
    # Provides unified interface for e-bash operations
    (bin/"e-bash").write <<~EOS
      #!/usr/bin/env bash
      # e-bash command - unified interface for e-bash operations
      export E_BASH="#{libexec}"

      # If invoked with install/upgrade/rollback/versions/uninstall/help, delegate to installer
      if [[ "$1" =~ ^(install|upgrade|rollback|versions|uninstall|help)$ ]]; then
        exec "#{bin}/install.e-bash.sh" "$@"
      else
        # Show usage by default
        exec "#{bin}/install.e-bash.sh" help
      fi
    EOS
    chmod 0755, bin/"e-bash"

    # Create custom brew command for shell RC setup
    # This will be installed to cmd/ directory and available as `brew e-bash-setup`
    (buildpath/"cmd"/"brew-e-bash-setup.sh").write <<~EOS
      #!/usr/bin/env bash
      # Auto-configure shell RC for e-bash
      # Usage: brew e-bash-setup

      # Detect shell RC file
      SHELLRC="$HOME/.bashrc"
      [[ "$SHELL" == *"zsh"* ]] && SHELLRC="$HOME/.zshrc"

      E_BASH_LINE='export E_BASH="#{opt_libexec}"'

      if ! grep -q "E_BASH" "$SHELLRC" 2>/dev/null; then
        echo "" >> "$SHELLRC"
        echo "# e-bash" >> "$SHELLRC"
        echo "$E_BASH_LINE" >> "$SHELLRC"
        echo "Added e-bash to $SHELLRC"
        echo "Run 'source $SHELLRC' or restart your shell"
      else
        echo "E_BASH already configured in $SHELLRC"
      fi
    EOS
    chmod 0755, buildpath/"cmd"/"brew-e-bash-setup.sh"

    # Install custom brew command
    (prefix/"cmd"/"brew-e-bash-setup.sh").install buildpath/"cmd"/"brew-e-bash-setup.sh"

    # Rewrite shebangs in bin scripts to use Homebrew's bash
    # This ensures scripts use bash 5.x instead of macOS's bash 3.2
    bin.glob("*.sh").each do |script|
      inreplace script, %r{^#!/usr/bin/env bash}, "#!#{Formula["bash"].opt_bin}/bash"
    end
  end

  def caveats
    <<~EOS
      e-bash library has been installed to: #{libexec}

      To use e-bash in your scripts, add the following to your ~/.bashrc or ~/.zshrc:
        export E_BASH="#{opt_libexec}"

      Or use the helper to automatically add it:
        brew e-bash-setup

      Available commands after installation:
        e-bash install              # Install into current project
        e-bash install v1.16.2      # Install specific version
        e-bash upgrade              # Upgrade current installation
        e-bash versions             # List available versions
        e-bash help                 # Show help

      For project-level installation (embedded in your repo), use:
        curl -sSL https://git.new/e-bash | bash -s --

      Documentation: #{opt_doc}
      Demo scripts:  #{opt_pkgshare}/demos
    EOS
  end

  # Test block is required - verifies the formula works after installation
  # Run with: brew test e-bash
  test do
    # Verify core scripts exist
    assert_predicate libexec/"_logger.sh", :exist?
    assert_predicate libexec/"_commons.sh", :exist?
    assert_predicate libexec/"_dependencies.sh", :exist?
    assert_predicate libexec/"_semver.sh", :exist?
    assert_predicate libexec/"_arguments.sh", :exist?
    assert_predicate libexec/"_colors.sh", :exist?

    # Test that scripts can be sourced without error
    system Formula["bash"].opt_bin/"bash", "-c",
           "export E_BASH='#{libexec}' && source '#{libexec}/_colors.sh'"

    # Test logger creates functions (functional test, not just --version)
    output = shell_output("#{Formula["bash"].opt_bin}/bash -c '" \
                          "export E_BASH=\"#{libexec}\" && " \
                          "source \"#{libexec}/_logger.sh\" && " \
                          "logger test && type echo:Test'")
    assert_match "function", output

    # Test semver parsing works correctly
    output = shell_output("#{Formula["bash"].opt_bin}/bash -c '" \
                          "export E_BASH=\"#{libexec}\" && " \
                          "source \"#{libexec}/_semver.sh\" && " \
                          "semver:parse \"1.2.3\" && " \
                          "echo \"$SEMVER_MAJOR.$SEMVER_MINOR.$SEMVER_PATCH\"'")
    assert_match "1.2.3", output

    # Test e-bash command wrapper
    assert_match "Usage:", shell_output("#{bin}/e-bash help")
  end
end
```

### 5.2 Formula Key Design Decisions

| Decision                              | Rationale                                                                           |
| ------------------------------------- | ----------------------------------------------------------------------------------- |
| Use `libexec` for library scripts     | Keeps library scripts private (not symlinked to PATH); users source them explicitly |
| Use `inreplace` for shebangs          | Rewrites `#!/usr/bin/env bash` to use Homebrew's bash 5.x instead of macOS bash 3.2 |
| Create `e-bash-env` helper            | Provides single command to set up `E_BASH` and `PATH`                               |
| Create `e-bash` wrapper command       | Unified interface for all e-bash operations (delegates to installer)               |
| Create custom brew command `e-bash-setup` | Optional automation for shell RC configuration (follows Homebrew conventions)    |
| Depend on `bash` formula              | Homebrew bash provides bash 5.x features e-bash requires                            |
| Include demos in `pkgshare`           | Educational value in `share/e-bash/demos` without cluttering main install           |
| Comprehensive test block              | **Required** - tests must verify functionality, not just `--version`                |
| Use `opt_*` paths in caveats          | `opt_bin`, `opt_libexec` provide stable paths across version upgrades               |
| Archive-based installation (no git clone) | Faster downloads, smaller transfers, SHA256 verification integrity                |

### 5.3 Installation Directories

| Directory Variable | Example Path                                 | Purpose                           |
| ------------------ | -------------------------------------------- | --------------------------------- |
| `bin`              | `/opt/homebrew/bin`                          | Executables (symlinked to prefix) |
| `libexec`          | `/opt/homebrew/Cellar/e-bash/1.16.2/libexec` | Private scripts (not in PATH)     |
| `doc`              | `/opt/homebrew/share/doc/e-bash`             | Documentation                     |
| `pkgshare`         | `/opt/homebrew/share/e-bash`                 | Package-specific data files       |
| `opt_bin`          | `/opt/homebrew/opt/e-bash/bin`               | Stable path across versions       |
| `opt_libexec`      | `/opt/homebrew/opt/e-bash/libexec`           | Stable path across versions       |

### 5.4 HEAD Formula Support

The formula supports `brew install --HEAD e-bash` for development versions:

```ruby
head "https://github.com/OleksandrKucherenko/e-bash.git", branch: "master"
```

---

## 6. CI/CD Workflow for Distribution

### 6.1 Workflow Overview

```text
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Push tag v*    │────▶│  Release Action  │────▶│  Create Release │
│  to e-bash repo │     │  (existing)      │     │  with ZIP       │
└─────────────────┘     └──────────────────┘     └────────┬────────┘
                                                          │
                                                          ▼
                        ┌──────────────────┐     ┌─────────────────┐
                        │  Update Formula  │◀────│  Dispatch event │
                        │  in tap repo     │     │  or webhook     │
                        └──────────────────┘     └─────────────────┘
```

### 6.2 Enhanced Release Workflow (e-bash repo)

Add to `.github/workflows/release.yaml`:

```yaml
# ... existing release steps ...

  # NEW: Trigger tap formula update
  update-homebrew-tap:
    name: "Update Homebrew Tap"
    needs: create-release
    runs-on: ubuntu-latest
    if: ${{ !contains(github.ref, '-') }}  # Skip pre-releases

    steps:
      - name: Trigger tap update
        uses: peter-evans/repository-dispatch@v3
        with:
          token: ${{ secrets.TAP_GITHUB_TOKEN }}
          repository: OleksandrKucherenko/homebrew-e-bash
          event-type: formula-update
          client-payload: |
            {
              "version": "${{ needs.create-release.outputs.version }}",
              "tag": "${{ needs.create-release.outputs.tag }}",
              "sha256": "${{ needs.create-release.outputs.checksum }}",
              "archive_url": "https://github.com/OleksandrKucherenko/e-bash/releases/download/${{ needs.create-release.outputs.tag }}/e-bash.${{ needs.create-release.outputs.version }}.zip"
            }
```

### 6.3 Tap Repository Workflow

Create `.github/workflows/update-formula.yaml` in `homebrew-e-bash`:

```yaml
name: Update Formula

on:
  repository_dispatch:
    types: [formula-update]

  workflow_dispatch:
    inputs:
      version:
        description: 'Version (e.g., 1.16.2)'
        required: true
      tag:
        description: 'Tag (e.g., v1.16.2)'
        required: true
      sha256:
        description: 'SHA256 checksum of archive'
        required: true

jobs:
  update-formula:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write

    steps:
      - name: Checkout tap repository
        uses: actions/checkout@v4

      - name: Extract version info
        id: version
        run: |
          if [ "${{ github.event_name }}" = "repository_dispatch" ]; then
            echo "version=${{ github.event.client_payload.version }}" >> $GITHUB_OUTPUT
            echo "tag=${{ github.event.client_payload.tag }}" >> $GITHUB_OUTPUT
            echo "sha256=${{ github.event.client_payload.sha256 }}" >> $GITHUB_OUTPUT
            echo "archive_url=${{ github.event.client_payload.archive_url }}" >> $GITHUB_OUTPUT
          else
            VERSION="${{ github.event.inputs.version }}"
            TAG="${{ github.event.inputs.tag }}"
            SHA256="${{ github.event.inputs.sha256 }}"
            echo "version=$VERSION" >> $GITHUB_OUTPUT
            echo "tag=$TAG" >> $GITHUB_OUTPUT
            echo "sha256=$SHA256" >> $GITHUB_OUTPUT
            echo "archive_url=https://github.com/OleksandrKucherenko/e-bash/releases/download/$TAG/e-bash.$VERSION.zip" >> $GITHUB_OUTPUT
          fi

      - name: Verify archive exists
        run: |
          URL="${{ steps.version.outputs.archive_url }}"
          echo "Verifying archive at: $URL"

          HTTP_STATUS=$(curl -sL -o /dev/null -w "%{http_code}" "$URL")
          if [ "$HTTP_STATUS" != "200" ] && [ "$HTTP_STATUS" != "302" ]; then
            echo "ERROR: Archive not found (HTTP $HTTP_STATUS)"
            exit 1
          fi
          echo "Archive verified (HTTP $HTTP_STATUS)"

      - name: Update formula
        run: |
          VERSION="${{ steps.version.outputs.version }}"
          TAG="${{ steps.version.outputs.tag }}"
          SHA256="${{ steps.version.outputs.sha256 }}"
          ARCHIVE_URL="${{ steps.version.outputs.archive_url }}"

          # Update URL and SHA256 in formula
          sed -i "s|url \"https://github.com/OleksandrKucherenko/e-bash/releases/download/v[^/]*/e-bash\.[^\"]*\.zip\"|url \"$ARCHIVE_URL\"|" Formula/e-bash.rb
          sed -i "s|sha256 \"[a-f0-9]*\"|sha256 \"$SHA256\"|" Formula/e-bash.rb

          echo "Updated formula to version $VERSION"
          cat Formula/e-bash.rb | grep -E "(url|sha256)"

      - name: Run formula tests
        run: |
          # Install Homebrew (GitHub runners have it, but ensure it's available)
          if ! command -v brew &> /dev/null; then
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
          fi

          # Tap the local formula for testing
          brew tap --force OleksandrKucherenko/e-bash "$(pwd)"

          # Install and test
          brew install --build-from-source ./Formula/e-bash.rb
          brew test e-bash

          echo "Formula tests passed"

      - name: Create Pull Request
        uses: peter-evans/create-pull-request@v6
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          commit-message: "e-bash ${{ steps.version.outputs.version }}"
          title: "Update e-bash to ${{ steps.version.outputs.version }}"
          body: |
            Automated formula update for e-bash ${{ steps.version.outputs.version }}

            - **Version:** ${{ steps.version.outputs.version }}
            - **Tag:** ${{ steps.version.outputs.tag }}
            - **Archive:** ${{ steps.version.outputs.archive_url }}
            - **SHA256:** `${{ steps.version.outputs.sha256 }}`

            Release notes: https://github.com/OleksandrKucherenko/e-bash/releases/tag/${{ steps.version.outputs.tag }}
          branch: formula-update/${{ steps.version.outputs.version }}
          base: main
          labels: |
            formula-update
            automated
```

### 6.4 Formula Test Workflow

Create `.github/workflows/test-formula.yaml` in `homebrew-e-bash`:

```yaml
name: Test Formula

on:
  push:
    branches: [main]
    paths: ['Formula/**']
  pull_request:
    branches: [main]
    paths: ['Formula/**']

jobs:
  test:
    strategy:
      matrix:
        os: [macos-latest, macos-13]
    runs-on: ${{ matrix.os }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Homebrew
        uses: Homebrew/actions/setup-homebrew@master

      - name: Tap formula
        run: brew tap OleksandrKucherenko/e-bash "$(pwd)"

      - name: Install formula
        run: brew install --build-from-source ./Formula/e-bash.rb

      - name: Run tests
        run: brew test e-bash

      - name: Audit formula
        run: |
          brew audit --strict ./Formula/e-bash.rb || true
          brew audit --new ./Formula/e-bash.rb || true

      - name: Test e-bash functionality
        run: |
          # Source environment
          source "$(brew --prefix)/bin/e-bash-env"

          # Test logger
          source "$E_BASH/_logger.sh"
          logger test
          echo:Test "Hello from brew-installed e-bash"

          # Test semver
          source "$E_BASH/_semver.sh"
          semver:parse "1.2.3-beta+build"
          echo "Parsed: $SEMVER_MAJOR.$SEMVER_MINOR.$SEMVER_PATCH"
```

---

## 7. User Installation Experience

### 7.1 Installation Commands

```bash
# Add the tap (one-time)
brew tap OleksandrKucherenko/e-bash

# Install e-bash
brew install e-bash

# Or in one command
brew install OleksandrKucherenko/e-bash/e-bash
```

### 7.2 Upgrade Commands

```bash
# Update tap and upgrade
brew update
brew upgrade e-bash

# Upgrade to specific version
brew upgrade e-bash@1.17.0
```

### 7.3 Usage After Installation

```bash
# Option 1: Source the environment helper
source "$(brew --prefix)/bin/e-bash-env"
source "$E_BASH/_logger.sh"

# Option 2: Set E_BASH manually
export E_BASH="$(brew --prefix)/libexec"
source "$E_BASH/_logger.sh"

# Option 3: Use in scripts with auto-detection
# (add fallback for Homebrew location in bootstrap)
```

### 7.4 Using the e-bash Command

After installation, the `e-bash` command provides a unified interface:

```bash
# Display help
e-bash help

# Install into current project (delegates to curl installer)
e-bash install

# Install specific version
e-bash install v1.16.2

# Install from custom fork
e-bash install --repo https://github.com/company/e-bash.git

# Upgrade existing installation
e-bash upgrade

# Rollback to previous version
e-bash rollback

# List available versions
e-bash versions

# Uninstall from current project
e-bash uninstall
```

**Note:** The `e-bash` command is a wrapper that delegates to `install.e-bash.sh`, providing the same functionality as the curl installer but with a more convenient interface.

### 7.5 Update Bootstrap for Homebrew Support

Update the bootstrap snippet in `docs/public/installation.md` to include Homebrew:

```bash
# Enhanced bootstrap with Homebrew support
[ -z "$E_BASH" ] && readonly E_BASH="$(
  if [ -n "${E_BASH+x}" ]; then
    echo "$E_BASH"
  elif [ -f "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../.scripts/_colors.sh" ]; then
    echo "$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../.scripts && pwd)"
  elif [ -d "$HOME/.e-bash/.scripts" ]; then
    echo "$HOME/.e-bash/.scripts"
  elif command -v brew &>/dev/null && [ -d "$(brew --prefix)/opt/e-bash/libexec" ]; then
    echo "$(brew --prefix)/opt/e-bash/libexec"
  else
    echo "Error: Cannot find e-bash library" >&2
    exit 1
  fi
)"
```

---

## 8. Implementation Tasks

### Phase 1: Installer Enhancements (e-bash repo)

- [ ] Add `--repo` flag support to `install.e-bash.sh`
- [ ] Add `--branch` flag support to `install.e-bash.sh`
- [ ] Remove `readonly` from `REMOTE_URL`, `REMOTE_MASTER`, `REMOTE_NAME` variables
- [ ] Update `print_usage()` function with new flags documentation
- [ ] Add tests for custom repository installation
- [ ] Update documentation with custom repo examples

### Phase 2: Tap Repository Setup

- [ ] Create GitHub repository `OleksandrKucherenko/homebrew-e-bash`
- [ ] Initialize repository structure (Formula/, cmd/, README.md, LICENSE)
- [ ] Create initial `Formula/e-bash.rb` for current version (v1.16.2)
- [ ] Calculate SHA256 checksum for current release archive
- [ ] Set up branch protection rules
- [ ] Configure repository secrets

### Phase 3: Formula Development

- [ ] Develop and test formula locally on macOS
- [ ] Test installation: `brew install --build-from-source ./Formula/e-bash.rb`
- [ ] Verify all test blocks pass: `brew test e-bash`
- [ ] Run formula audit: `brew audit --strict ./Formula/e-bash.rb`
- [ ] Test `--HEAD` installation works
- [ ] Test `e-bash` command wrapper functionality
- [ ] Test `brew e-bash-setup` custom command
- [ ] Document caveats and post-install instructions

### Phase 4: CI/CD Integration

- [ ] Create Personal Access Token (PAT) with `repo` scope
- [ ] Add `TAP_GITHUB_TOKEN` secret to e-bash repository
- [ ] Update `.github/workflows/release.yaml` with tap update trigger
- [ ] Create `.github/workflows/update-formula.yaml` in tap repo
- [ ] Create `.github/workflows/test-formula.yaml` in tap repo
- [ ] Test full release → tap update flow

### Phase 5: Documentation Updates

- [ ] Update `docs/public/installation.md` with Homebrew instructions
- [ ] Update bootstrap snippets to include Homebrew fallback
- [ ] Update `README.md` with Homebrew installation option
- [ ] Update `CLAUDE.md` with Homebrew-related development info
- [ ] Create tap repository README with usage instructions
- [ ] Document custom repository installation process

### Phase 6: Testing & Validation

- [ ] Test installation on macOS Ventura (13.x)
- [ ] Test installation on macOS Sonoma (14.x)
- [ ] Test installation on macOS Sequoia (15.x)
- [ ] Test installation on Linux (Linuxbrew)
- [ ] Test upgrade path from previous version
- [ ] Test uninstall and reinstall
- [ ] Test `e-bash` command for all operations
- [ ] Test custom repository installation via `--repo` flag
- [ ] Verify e-bash functionality post-installation
- [ ] Document any platform-specific issues

---

## 9. Testing Strategy

### 9.1 Local Formula Testing

```bash
# Clone tap repository locally
git clone https://github.com/OleksandrKucherenko/homebrew-e-bash.git
cd homebrew-e-bash

# Install from local formula
brew install --build-from-source ./Formula/e-bash.rb

# Run tests
brew test e-bash

# Audit formula
brew audit --strict ./Formula/e-bash.rb
brew audit --new ./Formula/e-bash.rb

# Verify functionality
source "$(brew --prefix)/bin/e-bash-env"
source "$E_BASH/_logger.sh"
logger test
echo:Test "Installation verified"
```

### 9.2 CI Test Matrix

| Platform           | Test                     |
| ------------------ | ------------------------ |
| macOS 13 (Ventura) | Full install + tests     |
| macOS 14 (Sonoma)  | Full install + tests     |
| macOS 15 (Sequoia) | Full install + tests     |
| Ubuntu (optional)  | HEAD build via Linuxbrew |

### 9.3 Release Flow Testing

1. Create test tag (e.g., `v1.16.3-test.1`)
2. Verify release workflow creates archive
3. Verify tap update workflow triggers
4. Verify PR is created in tap repository
5. Verify formula installs correctly from PR branch

---

## 10. Rollback & Recovery

### 10.1 Formula Rollback

If a formula update causes issues:

```bash
# User can switch to previous version
brew unlink e-bash
brew install e-bash@1.16.1  # If versioned formula exists

# Or reinstall from git
brew uninstall e-bash
brew install --HEAD e-bash
```

### 10.2 Tap Repository Recovery

- Revert formula changes via git
- Recreate release with corrected archive
- Re-run update workflow manually

### 10.3 Emergency Procedures

1. **Bad release uploaded:** Delete release, fix, re-release with same tag
2. **Formula breaks installation:** Revert PR in tap repository, create hotfix
3. **CI/CD pipeline fails:** Run update workflow manually with correct inputs

---

## Appendix A: File Locations Reference

| Component           | Location                                                |
| ------------------- | ------------------------------------------------------- |
| Main formula        | `homebrew-e-bash/Formula/e-bash.rb`                     |
| Release workflow    | `e-bash/.github/workflows/release.yaml`                 |
| Tap update workflow | `homebrew-e-bash/.github/workflows/update-formula.yaml` |
| Tap test workflow   | `homebrew-e-bash/.github/workflows/test-formula.yaml`   |
| Installation docs   | `e-bash/docs/public/installation.md`                    |
| Installer script    | `e-bash/bin/install.e-bash.sh`                          |
| Custom brew command | `homebrew-e-bash/cmd/brew-e-bash-setup.sh`               |

## Appendix B: Required Secrets

| Repository        | Secret Name        | Purpose                         |
| ----------------- | ------------------ | ------------------------------- |
| `e-bash`          | `TAP_GITHUB_TOKEN` | Trigger tap repository dispatch |
| `homebrew-e-bash` | `GITHUB_TOKEN`     | Create PRs (built-in)           |

## Appendix C: Homebrew Best Practices References

- [Homebrew Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)
- [Creating a Homebrew Tap](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
- [Homebrew Taps](https://docs.brew.sh/Taps)
- [Homebrew Formula Test Blocks](https://docs.brew.sh/Formula-Cookbook#add-a-test-to-the-formula)
- [Acceptable Formulae](https://docs.brew.sh/Acceptable-Formulae)
- [Homebrew Custom Commands](https://docs.brew.sh/Python-for-Formula-Authors#custom-commands)

## Appendix D: Enterprise & Security Considerations

### Environment-Based Tap Restrictions

Homebrew supports environment variables for enterprise compliance:

| Variable                  | Purpose                      |
| ------------------------- | ---------------------------- |
| `HOMEBREW_ALLOWED_TAPS`   | Whitelist of permitted taps  |
| `HOMEBREW_FORBIDDEN_TAPS` | Blacklist of prohibited taps |

Example enterprise policy:
```bash
# Only allow official Homebrew and company taps
export HOMEBREW_ALLOWED_TAPS="homebrew/core,homebrew/cask,OleksandrKucherenko/e-bash"
```

### Custom URL Support

Organizations can host private tap mirrors:
```bash
# Tap from internal Git server
brew tap company/e-bash https://git.internal.company.com/homebrew-e-bash.git

# Supports any Git-compatible protocol (SSH, HTTP, FTP)
brew tap company/e-bash git@git.internal.company.com:homebrew-e-bash.git
```

### Qualified Formula Names

When multiple taps provide similarly-named formulas, use fully qualified names:
```bash
# Install from specific tap (avoids conflicts with homebrew/core)
brew install OleksandrKucherenko/e-bash/e-bash
```

## Appendix E: e-bash Command Reference

The `e-bash` command provides a unified interface for e-bash operations after Homebrew installation:

### Command Syntax

```bash
e-bash [options] [command] [version]
```

### Available Commands

| Command   | Description                                    | Example                              |
| --------- | ---------------------------------------------- | ------------------------------------ |
| `install` | Install e-bash to current project               | `e-bash install`                     |
| `upgrade` | Upgrade existing installation                  | `e-bash upgrade`                     |
| `rollback` | Rollback to previous version                   | `e-bash rollback`                    |
| `versions` | List available local and remote versions        | `e-bash versions`                    |
| `uninstall` | Uninstall e-bash from current project          | `e-bash uninstall`                   |
| `help`    | Show help message                              | `e-bash help`                        |

### Options

| Option         | Description                                          |
| -------------- | ---------------------------------------------------- |
| `--dry-run`     | Run in dry run mode (no changes)                      |
| `--global`      | Install to user's HOME directory instead of project   |
| `--directory`   | Custom installation directory                         |
| `--repo <url>`  | Custom git repository URL                             |
| `--branch`      | Custom branch name                                   |
| `--force`       | Force overwrite of existing scripts with auto-backup  |
| `--[no-]create-symlink` | Control symlink creation for global installs  |

### Custom Repository Installation

```bash
# Install from company fork
e-bash install --repo https://github.com/company/e-bash.git

# Install specific version from fork
e-bash install --repo https://github.com/company/e-bash.git v1.16.2

# Install from fork with custom branch
e-bash install --repo https://github.com/company/e-bash.git --branch develop
```

## Appendix F: Linuxbrew (Homebrew on Linux)

The formula works with Linuxbrew on Linux systems:

```bash
# Install Homebrew on Linux
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add to PATH
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Install e-bash
brew tap OleksandrKucherenko/e-bash
brew install e-bash
```

### Linux-Specific Considerations

- PATH to Homebrew differs: `/home/linuxbrew/.linuxbrew/bin`
- System bash may already be 5.x on Linux (formula dependency still applies)
- GNU tools typically available system-wide (gnubin shims less critical)
- Custom brew command path: `/home/linuxbrew/.linuxbrew/opt/e-bash/cmd/brew-e-bash-setup.sh`

## Appendix G: Future Enhancements

### Alias Support

Create `Aliases/` directory for backward compatibility:
```
Aliases/
└── ebash -> ../Formula/e-bash.rb
```

Allows users to run: `brew install OleksandrKucherenko/e-bash/ebash`

### Migration Tracking

If formula location changes, add `tap_migrations.json`:
```json
{
  "e-bash": "OleksandrKucherenko/e-bash"
}
```

### Additional Custom Brew Commands

Potential future commands in `cmd/` directory:
```bash
# cmd/brew-e-bash-version.sh
#!/bin/bash
# Print e-bash version information
E_BASH="$(brew --prefix)/opt/e-bash/libexec"
source "$E_BASH/_semver.sh"
# ... version display logic
```

Usage: `brew e-bash-version`

### Multi-Formula Tap Support

When adding additional formulas to the tap (e.g., `e-bash-tools`), the update workflow should support formula selection via input parameters.
