# Release 2.1.0

## 📦 Installation

e-bash is now distributed via **Homebrew** for both macOS and Linux, in addition to the web installer.

### Homebrew (recommended)

```bash
# Add the tap (first time only)
brew tap artfulbits-se/tap

# Install
brew install e-bash

# Complete setup
e-bash versions
```

Upgrade from v2.0.0:

```bash
brew update && brew upgrade e-bash
```

### Web installer (alternative)

```bash
curl -sSL https://git.new/e-bash | bash -s --
```

### Upgrade guide

See [migration-v2.0-to-v2.1.md](docs/public/migration-v2.0-to-v2.1.md) — no breaking changes, all existing scripts continue to work.

---

## What's New

Version 2.1.0 brings professional-grade argument parsing: shell completion, subcommand-style scoped parsing, type validation, and 214 new tests. The TUI module (`_tui.sh`) is extracted as a standalone component.

### Shell Completion (#73)

Every script using `_arguments.sh` now supports `--completion` and `--install-completion` out of the box:

```bash
./myscript.sh --completion bash    # print Bash completion script
./myscript.sh --install-completion zsh   # install to OS directory
```

- `args:completion` generates Bash and Zsh completion scripts from `ARGS_DEFINITION` metadata
- `args:completion:install` auto-discovers OS completion directories (Homebrew, XDG, system)
- `args:dispatch` auto-handles `--version`, `--debug`, `--completion`, `--install-completion`

### Scoped Parsing (#73)

Build AWS CLI-grade tools with multi-phase subcommand parsing:

```bash
ARGS_DEFINITION="--verbose \$1=command::1"
parse:arguments "$@"

DEPLOY_SCOPE="--replicas=replicas:1:1 --region=region:us-east-1:1"
args:scope DEPLOY_SCOPE "${ARGS_UNPARSED[@]}"
```

- `ARGS_UNPARSED` array collects unknown flags and unmatched positionals
- `args:reset` clears parser state between scopes
- `args:scope` takes a variable name (nameref) for reusable scope definitions
- See [cli-strategy.md](docs/public/cli-strategy.md) for the full AWS CLI-grade pattern

### Type Validation (#73)

Declare constraints, validate after parsing:

```bash
args:t "--port" "int:1:65535"
args:t "--format" "enum:json,csv,text"
args:t "--email" "pattern:^[^@]+@[^@]+$"

parse:arguments "$@"
args:validate || exit 1
```

Supported types: `enum`, `int`, `float`, `string` (length), `pattern` (regex).

### Defaults Pre-fill (#73)

Value flags with defaults are now pre-filled before CLI parsing — CLI values override:

```bash
ARGS_DEFINITION="--port=port:8080:1"
parse:arguments  # port="8080" even without --port on CLI
```

### End-of-Options `--` (#73)

Everything after `--` becomes positional:

```bash
./script.sh --verbose -- --not-a-flag file.txt
```

### Short Option Unbundling (#73)

```bash
readarray -t expanded < <(args:unbundle "$@")
parse:arguments "${expanded[@]}"
# -abc → -a -b -c
```

### TUI Module (#75)

Terminal UI functions extracted to standalone `_tui.sh`:
- Interactive multi-line text editor component
- Cursor positioning, password input, input validation
- 62 functions — `_commons.sh` sources it automatically (backward compatible)

### Other Features

- feat(wsl): xdg-open shim for WSL environments (#77)
- feat: Smart graphics detection for clipboard-image-save
- feat: JSON structural logging in ECS format (#64)
- feat: Caching and short-form checks in dependency management (#68)

## 🐛 Bug Fixes

### Parser Security & Correctness (#73)
- Replace unsafe `eval "export X='$val'"` with safe `export "${X}=${val}"` — prevents injection
- `--key=val=ue` no longer truncates at first `=`
- `parse:arguments` returns 1 instead of `exit 1` on missing args
- `--env KEY=VALUE` via space syntax no longer corrupted by `=` splitter
- `args:dispatch` propagates completion/install errors

### Other Fixes
- fix: strict mode compatibility (set -euo pipefail) (#89)
- fix: ShellSpec timeout patching resilient to Homebrew formula changes (#74)
- fix(xdg): tested on win11 work configuration
- fix: detect sixels support for SSH sessions

## 📝 Documentation
- [cli-strategy.md](docs/public/cli-strategy.md) — strategy guide for building AWS CLI-grade tools
- [arguments.md](docs/public/arguments.md) — updated with scoped parsing, defaults, validation
- [completion.md](docs/public/completion.md) — shell completion documentation
- [migration-v2.0-to-v2.1.md](docs/public/migration-v2.0-to-v2.1.md) — upgrade guide (no breaking changes)
- [migration-guide.md](docs/public/migration-guide.md) — BASH to e-bash migration (#62)

## 🧪 Testing
- 214 new argument parser tests across 6 test files
- Stress test corpus covering 110 CLI argument patterns
- Scoped parsing tests with multi-phase subcommand scenarios
- Type validation tests for all 5 type checkers

---

# Release 2.0.0

Version 2.0.0 introduces significant enhancements to the core architecture, including a robust hooks middleware system, expanded utility functions, and improved self-update capabilities. This release also brings substantial improvements to the CI/CD pipeline with parallelized testing, macOS compatibility fixes, and new integration tools like ShellMetrics.

## ✨ Features
- Add alias resolution and version flag mapping to dependencies module (#55) (bd32ffb)
- Add environment variable expansion function (#54) (065a07d)
- Add utility functions to commons script (#53) (a73770e)
- Hooks with middleware support (#51) (8df142d)
- Implement hooks abstraction for script delegation (#46) (7b665d1)
- Self update, ability to granularly update the e-bash (#44) (831453c)
- Add 10-minute timeout to CI test chunks (#45) (1e33037)
- Junit baseline pipeline (#38) (836f4f5)
- Implement to:slug function with unit tests (#37) (9d14a8c)
- Add variable fallback functions to commons script (#33) (be8b346)
- Extra helper script for npm versions (5f3feed)
- Add custom directory option to install script (#31) (22efc44)
- Add ShellMetrics CI integration for code complexity tracking (#30) (c862c21)
- Implement multiple trap handlers for Bash (#24) (95e7d5e)
- Add mise tool support to e-bash install script (#23) (fbdee5c)
- Add Tmux integration for display and monitoring (#21) (e2a9f4e)
- Add semver support for version comparison and constraints (#12) (92e9a2d)
- Add improved clipboard image handling (fd7fe84)
- Add configuration file search utilities (97aa3e3)

## 🐛 Bug Fixes
- Fix shell quoting to handle whitespace in paths (#52) (6f8e6e7)
- Update configuration defaults for hooks (#50) (87df95b)
- Improve error handling in utility functions (#49) (98d6d53)
- Fix sed syntax for macOS compatibility (#48) (0ee5e17)
- Resolve grep conflicts in git log format (#47) (8c8b83a)
- Fix color variable initialization (#41) (7614268)
- Fix redirect issue for test coverage (#39) (07a5a70)
- Resolve macOS-specific test failures (#35) (33e7b2e)
- Fix self-update script for reliable updates (a7e7d7e)

## ♻️ Refactoring
- Refactor hook declaration and execution (#42) (29fd28a)
- Reorganize test fixtures and helpers (#40) (2c917c3)
- Migrate CI from custom runner to GitHub Actions (#36) (80c2aa4)
- Extract tmux functionality into separate module (9b66e92)
- Improve script bootstrap and module loading (d5e27e2)

## 📝 Documentation
- Add comprehensive documentation for hooks system (docs/public/hooks.md)
- Add dry-run wrapper documentation (docs/public/dryrun-wrapper.md)
- Add version management guide (docs/public/version-up.md)
- Update installation documentation with new options
- Add tmux integration analysis (TMUX_PATTERN_ANALYSIS.md)
