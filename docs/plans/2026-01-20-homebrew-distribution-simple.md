# Simplified Homebrew Distribution Plan

**Date:** 2026-01-20
**Status:** Draft
**Author:** Claude Code

---

## Executive Summary

This plan transforms the Homebrew distribution approach from a bespoke e-bash solution into a **universal, product-agnostic tap repository** capable of distributing any artifact. The design prioritizes extreme simplicity by eliminating all non-essential processes.

**Core Philosophy:** The tap repository should be as simple as possible - just formulas. All automation lives in source repositories.

---

## Architecture: Universal Tap Repository

### Repository: `OleksandrKucherenko/homebrew`

```
homebrew/
├── Formula/
│   ├── e-bash.rb
│   ├── another-tool.rb      # Future products
│   └── yet-another.rb       # Future products
├── README.md
└── LICENSE
```

**That's it.** No additional directories, no workflows, no custom commands.

---

## Key Simplifications from Original Plan

| Aspect | Original Plan | Simplified Plan |
|--------|---------------|-----------------|
| Repository name | `homebrew-e-bash` | `homebrew` (product-agnostic) |
| Custom brew commands | `cmd/brew-e-bash-setup.sh` | **Removed** |
| Tap CI/CD workflows | 2 workflows (update, test) | **Removed** |
| Formula complexity | Wrapper scripts, multiple helpers | Single self-contained formula |
| Shell RC auto-modification | Automated via custom command | Manual (standard Homebrew pattern) |
| Test workflows in tap | Multi-platform matrix | **Removed** (test locally) |
| Archive checksums | Workflow-generated SHA256 | Direct release artifact URLs |
| `e-bash` wrapper command | Delegates to installer | **Removed** |

---

## Formula Design: `Formula/e-bash.rb`

```ruby
# Formula for e-bash - Bash script enhancement framework
class EBash < Formula
  desc "Comprehensive Bash script enhancement framework with logging, dependencies, and more"
  homepage "https://github.com/OleksandrKucherenko/e-bash"
  url "https://github.com/OleksandrKucherenko/e-bash/archive/refs/tags/v1.16.2.tar.gz"
  sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"  # Update on release
  license "MIT"

  head "https://github.com/OleksandrKucherenko/e-bash.git", branch: "master"

  depends_on "bash"

  def install
    # Install library scripts to libexec (not in PATH)
    libexec.install Dir[".scripts/*"]

    # Install tools to bin
    bin.install Dir["bin/*"].reject { |f| File.directory?(f) }

    # Install documentation
    doc.install "README.md", "LICENSE"
    (doc/"public").install Dir["docs/public/*"] if Dir.exist?("docs/public")

    # Install demos
    (pkgshare/"demos").install Dir["demos/*"] if Dir.exist?("demos")
  end

  def caveats
    <<~EOS
      e-bash library has been installed to: #{libexec}

      To use e-bash in your scripts, add to your ~/.bashrc or ~/.zshrc:
        export E_BASH="#{opt_libexec}"

      For project-level installation, use:
        curl -sSL https://git.new/e-bash | bash

      Documentation: #{opt_doc}
    EOS
  end

  test do
    # Verify core scripts exist
    assert_predicate libexec/"_logger.sh", :exist?
    assert_predicate libexec/"_commons.sh", :exist?

    # Test sourcing works
    system Formula["bash"].opt_bin/"bash", "-c",
           "export E_BASH='#{libexec}' && source '#{libexec}/_colors.sh'"
  end
end
```

---

## Automation: Single Workflow in Source Repo

### File: `.github/workflows/release-homebrew.yaml` (in e-bash repo)

```yaml
name: Update Homebrew Formula

on:
  release:
    types: [published]
  workflow_dispatch:
    inputs:
      tag:
        description: 'Tag to update (e.g., v1.16.2)'
        required: true

permissions:
  contents: read

jobs:
  update-formula:
    runs-on: ubuntu-latest
    steps:
      - name: Get release info
        id: release
        run: |
          TAG="${{ github.event.release.tag_name || github.event.inputs.tag }}"
          VERSION="${TAG#v}"

          # Get download URL and checksum
          URL="https://github.com/OleksandrKucherenko/e-bash/archive/refs/tags/${TAG}.tar.gz"
          CHECKSUM=$(curl -sL "$URL" | sha256sum | cut -d' ' -f1)

          echo "tag=$TAG" >> $GITHUB_OUTPUT
          echo "version=$VERSION" >> $GITHUB_OUTPUT
          echo "url=$URL" >> $GITHUB_OUTPUT
          echo "checksum=$CHECKSUM" >> $GITHUB_OUTPUT

      - name: Update formula
        uses: fjogeleit/http-request-action@v1
        with:
          url: ${{ secrets.HOMEBREW_FORMULA_UPDATE_URL }}
          method: 'POST'
          customHeaders: '{"Content-Type": "application/json"}'
          data: '{"tag":"${{ steps.release.outputs.tag }}","version":"${{ steps.release.outputs.version }}","url":"${{ steps.release.outputs.url }}","checksum":"${{ steps.release.outputs.checksum }}"}'
```

**Alternative (no webhook service):** Direct GitHub API call to update the formula file.

---

## Manual Update Process (Fallback)

When automation fails, update is a single manual step:

```bash
# 1. Download release archive and compute checksum
VERSION="1.16.2"
curl -sL "https://github.com/OleksandrKucherenko/e-bash/archive/refs/tags/v${VERSION}.tar.gz" | sha256sum

# 2. Clone tap repo
git clone https://github.com/OleksandrKucherenko/homebrew.git
cd homebrew

# 3. Update 3 lines in Formula/e-bash.rb
# - url line
# - sha256 line
# - version line (if embedded)

# 4. Commit and push
git add Formula/e-bash.rb
git commit -m "e-bash ${VERSION}"
git push
```

---

## User Experience

### Installation

```bash
brew tap OleksandrKucherenko/homebrew
brew install e-bash
```

### Configuration (Manual - Standard Homebrew Pattern)

```bash
# User adds to ~/.bashrc or ~/.zshrc
export E_BASH="$(brew --prefix)/opt/e-bash/libexec"
```

### Upgrade

```bash
brew upgrade e-bash
```

---

## Repository Settings

### `OleksandrKucherenko/homebrew`

- **Visibility:** Public
- **Branch protection:** Optional (enable if desired)
- **Secrets:** None needed
- **No workflows needed** - automation triggers from source repos

---

## Adding New Products to Tap

To add a new product (e.g., `another-tool`) to the universal tap:

```bash
cd homebrew
# Create formula
brew create https://github.com/user/another-tool/archive/refs/tags/v1.0.0.tar.gz
# Edit Formula/another-tool.rb as needed
git add Formula/another-tool.rb
git commit -m "Add another-tool"
git push
```

---

## Implementation Tasks

### Phase 1: Tap Repository Creation (One-time)

- [ ] Create GitHub repository `OleksandrKucherenko/homebrew`
- [ ] Create `Formula/` directory
- [ ] Create `README.md` with installation instructions
- [ ] Add `LICENSE` (MIT)

### Phase 2: Initial Formula

- [ ] Create `Formula/e-bash.rb` for current version
- [ ] Test locally: `brew install --build-from-source ./Formula/e-bash.rb`
- [ ] Verify: `brew test e-bash`
- [ ] Commit and push to tap repo

### Phase 3: Source Repo Automation

- [ ] Create `.github/workflows/release-homebrew.yaml` in e-bash repo
- [ ] Configure PAT with `repo` scope for tap updates
- [ ] Add `HOMEBREW_GITHUB_TOKEN` secret to e-bash repo
- [ ] Test workflow with `workflow_dispatch`

### Phase 4: Documentation

- [ ] Update `docs/public/installation.md` with Homebrew instructions
- [ ] Update `README.md` in main repo
- [ ] Create README in tap repo

---

## Testing Strategy

### Local Testing

```bash
# Clone tap locally
git clone https://github.com/OleksandrKucherenko/homebrew.git
cd homebrew

# Test installation
brew install --build-from-source ./Formula/e-bash.rb

# Run tests
brew test e-bash

# Test formula validity
brew audit --new ./Formula/e-bash.rb
```

### Release Testing

1. Create test tag: `v1.16.3-test.1`
2. Run release workflow manually
3. Verify formula updates
4. Test install from updated tap

---

## Rollback & Recovery

### Bad Formula Update

```bash
cd homebrew
git revert HEAD
git push
```

### Users Can Pin Version

```bash
brew install OleksandrKucherenko/homebrew/e-bash@1.16.1
```

---

## Appendix: Tap README Template

```markdown
# Homebrew Tap

Universal tap repository for OleksandrKucherenko tools.

## Installation

```bash
brew tap OleksandrKucherenko/homebrew
```

## Formulae

| Formula | Description |
|---------|-------------|
| `e-bash` | Bash script enhancement framework |

## Usage

```bash
brew install e-bash
```

## License

MIT
```

---

## Summary: What Was Removed

1. **Custom brew commands** - Not essential; users can manually set `E_BASH`
2. **Tap CI/CD workflows** - Automation lives in source repo
3. **Formula test workflow** - Test locally during development
4. **Complex installer wrapper** - Homebrew installation is straightforward
5. **Archive generation complexity** - Use GitHub release archives directly
6. **Shell RC auto-modification** - Not a Homebrew convention
7. **Multiple update mechanisms** - Single workflow from source repo

---

## Rationale: Why This Works

1. **Homebrew taps are simple** - They're just Git repositories with formulas
2. **Source repo owns automation** - The product repo knows when releases happen
3. **Manual fallback is easy** - Only 3 lines change per release
4. **Universal design** - Tap can host any future formula
5. **Less to maintain** - No workflows in tap = less to break

---

## Decision: Naming Convention

**Repository name:** `OleksandrKucherenko/homebrew`

This follows the pattern where the tap is a personal/org namespace that can host multiple formulas, rather than being tied to a single product. Users tap with `brew tap OleksandrKucherenko/homebrew` and install specific formulas with `brew install e-bash`.

---

**End of Plan**
