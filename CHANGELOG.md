# Release 2.1.0

Version 2.1.0 is a major enhancement to the argument parsing system, adding shell completion generation, scoped parsing for subcommand-style CLIs, type validation, and numerous parser bug fixes discovered via comprehensive TDD testing (214 new tests).

## ✨ Features

### Shell Completion (#73)
- Add `args:completion` for generating Bash and Zsh completion scripts from `ARGS_DEFINITION` metadata
- Add `args:completion:install` for cross-platform auto-install to OS completion directories
- Add `args:dispatch` for auto-handling `--version`, `--debug`, `--completion`, `--install-completion` flags
- Completion flags auto-appended to every `ARGS_DEFINITION` — all scripts get completion for free

### Scoped Parsing (#73)
- Add `ARGS_UNPARSED` array — collects unknown flags and unmatched positionals for forwarding to sub-parsers
- Add `args:reset` — clears all parser state for clean re-parsing in a new scope
- Add `args:scope` — convenience wrapper taking a variable name (nameref) for scoped definitions
- Enable 2-3 phase subcommand-style parsing: `global → service → action`

### Defaults Pre-fill (#73)
- Value flags (`args_qt > 0`) with defaults are now pre-filled before CLI parsing
- CLI values override defaults — standard pattern: defaults first, user input wins
- Boolean flags (`args_qt == 0`) are NOT pre-filled

### Type Validation (#73)
- Add `args:t` to register type/validation rules per flag
- Add `args:validate` with 5 type checkers: `enum`, `int`, `float`, `string` (length), `pattern` (regex)
- Returns descriptive error messages to stderr on validation failure

### End-of-Options Sentinel (#73)
- `--` now stops flag processing — everything after becomes positional
- Works correctly with `ARGS_UNPARSED` for scoped parsing

### Short Option Unbundling (#73)
- Add `args:unbundle` helper to decompose `-abc` into `-a -b -c` before parsing

### Other Features
- feat: Add interactive multi-line text editor component (#75)
- feat(wsl): Add xdg-open shim for WSL environments (#77)
- feat: Smart graphics detection for clipboard-image-save
- feat: Improve ASCII preview quality with sextant symbols
- feat: Add JSON structural logging in ECS format (#64)
- feat: Add caching and short-form existence checks to dependency management (#68)
- feat: Fix semantic version script tag capture (#60)

## 🐛 Bug Fixes

### Parser Security & Correctness (#73)
- fix: Replace unsafe `eval "export X='$val'"` with safe `export "${X}=${val}"` — prevents command injection via values with quotes or shell metacharacters
- fix: `--key=val=ue` no longer truncates at first `=` — splits only on first `=` sign
- fix: `parse:arguments` returns 1 instead of `exit 1` on missing args — no longer kills caller
- fix: Value consumed by preceding flag (e.g., `--env KEY=VALUE`) no longer corrupted by `=` splitter
- fix: `args:dispatch` propagates completion/install errors instead of masking with `exit 0`

### Other Fixes
- fix: strict mode compatibility (set -euo pipefail) (#89)
- fix: make ShellSpec timeout patching resilient to Homebrew formula changes (#74)
- fix(ci): include lib/ directory in Homebrew cache for baseline workflow
- fix(xdg): tested on win11 work configuration
- fix: detect sixels support for SSH sessions

## 📝 Documentation
- Add CLI strategy guide for building AWS-grade CLI tools (`docs/public/cli-strategy.md`)
- Update `docs/public/arguments.md` with scoped parsing, defaults, validation sections
- Add shell completion documentation (`docs/public/completion.md`)
- Add Zsh manual completion testing guide
- Add e-docs auto-generated API reference for new functions
- Create BASH to e-bash migration guide (#62)
- Add self-installing dependencies mode documentation (#65)

## 🧪 Testing
- 214 new argument parser tests across 6 test files
- Stress test corpus covering 110 CLI argument patterns
- Edge case tests for parser correctness
- Scoped parsing tests with multi-phase subcommand scenarios
- Type validation tests for all 5 type checkers
- Completion generation and install tests

## ♻️ Refactoring
- Improve `_arguments.sh` debug logging — replace cryptic `[L1]`-`[L4]` labels with descriptive messages
- All parser logs use `echo:Parser` exclusively (not `echo:Common`)
- Move completion demos to `demos/completion/` subfolder
- Standardize bootstrap across all scripts

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
