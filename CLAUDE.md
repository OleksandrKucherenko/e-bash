# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**e-bash** is a comprehensive Bash script enhancement framework that provides reusable utilities, tools, and best practices for Bash development. It's designed as a library that projects can integrate to get professional-grade logging, dependency management, argument parsing, semantic versioning, and more.

**Current Version:** v1.1.0
**License:** MIT
**Repository:** https://github.com/OleksandrKucherenko/e-bash

## Core Architecture

### Library Structure
- `.scripts/` - Core library functions (16 modules) that can be sourced individually
- `bin/` - Standalone tools and scripts (11 executables)
- `spec/` - ShellSpec test suite (8 test files)
- `docs/` - Comprehensive documentation (11 markdown files)
- `demos/` - Demo scripts showing usage patterns

### Key Components
- **_logger.sh** - Advanced logging system with tag-based filtering, pipe/redirect support
- **_dependencies.sh** - Dependency management with version constraints and auto-install
- **_arguments.sh** - Command-line argument parsing with aliases and auto-help generation
- **_semver.sh** - Full semantic versioning support (parsing, comparison, constraints)
- **_commons.sh** - Common utilities, UI components, input functions
- **_self-update.sh** - Script self-updating and version rollback capabilities
- **_tmux.sh** - Tmux integration for progress displays and session management

## Development Commands

### Testing
```bash
# Run all tests
shellspec

# Run only failed tests (quick mode)
shellspec --quick

# Run tests without coverage
shellspec --quick --no-kcov

# TDD - run tests on file change
watchman-make -p 'spec/*_spec.sh' '.scripts/*.sh' --run "shellspec"
```

### Code Quality
```bash
# Format code (requires altshfmt)
make format

# Linting runs automatically via pre-commit hooks
# Can also run manually with shellcheck
shellcheck .scripts/*.sh bin/*.sh
```

### Environment Setup
```bash
# Allow direnv to set up environment
direnv allow

# Install dependencies (auto-managed by .envrc)
# Dependencies are defined in .envrc and automatically validated
```

## Installation & Integration

### Quick Installation (for other projects)
```bash
curl -sSL https://git.new/e-bash | bash -s --
```

### Manual Installation (git subtree)
```bash
git remote add -f e-bash https://github.com/OleksandrKucherenko/e-bash.git
git checkout -b e-bash-temp e-bash/master
git subtree split -P .scripts -b e-bash-scripts
git checkout master
git subtree merge --prefix .scripts e-bash-scripts --squash
```

## Key Usage Patterns

### Logging System
```bash
source ".scripts/_logger.sh"
logger common "$@"  # Creates echo:Common and printf:Common functions

export DEBUG=common  # Enable only common tag logs
export DEBUG=*       # Enable all logs
export DEBUG=*,-dbg  # Enable all except debug

echo:Common "Hello World"  # Only outputs if 'common' tag enabled
find . | log:Common        # Pipe mode logging
```

### Dependency Management
```bash
source ".scripts/_dependencies.sh"

dependency bash "5.*.*" "brew install bash"
dependency shellspec "0.28.*" "brew install shellspec"
optional kcov "43" "brew install kcov"  # Optional dependency
```

### Argument Parsing
```bash
export ARGS_DEFINITION="-h,--help -v,--version=:1.0.0 --debug=DEBUG:*"
source "$E_BASH/_arguments.sh"  # Auto-parses $@

# Access parsed variables
echo "Help: $help, Version: $version, Debug: $DEBUG"
```

## Environment Variables

### Core Configuration
- `E_BASH` - Path to .scripts directory (set by .envrc)
- `DEBUG` - Comma-separated list of logger tags to enable (supports wildcards)
- `CI_E_BASH_INSTALL_DEPENDENCIES` - Enable auto-install in CI (1/true/yes)

### Development Tools
- `ALTSHFMT` - Path to altshfmt formatter (understands ShellSpec files)
- `SKIP_ARGS_PARSING` - Skip argument parsing during script loading

## Testing & Quality Assurance

### Test Framework
- **ShellSpec 0.28.*** - BDD-style testing for shell scripts
- **kcov 43** - Code coverage reporting
- **ShellCheck 0.1[01].*** - Static analysis
- **Pre-commit hooks** - Automatic quality checks

### Test Coverage Configuration
Located in `.shellspec`:
- Includes `.sh` files and specific binaries
- Excludes test files, coverage, and report directories
- JUnit output format for CI integration

## Cross-Platform Support

### macOS/Linux Compatibility
- Automatic GNU tool setup on macOS via `bin/gnubin/`
- WSL2-friendly FIFO creation with retry logic
- Terminal color and capability detection

### Dependencies Management
- Version constraints using semantic versioning
- Support for HEAD/stable version patterns
- Auto-install of missing tools (when permitted)

## Self-Update System

The framework includes sophisticated self-update capabilities:
```bash
source ".scripts/_self-update.sh"

# Update to latest patch/stable versions
self-update "~1.0.0"  # Patch releases only
self-update "^1.0.0"  # Minor and patch releases

# Update from specific branches/tags
self-update "branch:master"
self-update "tag:v1.0.0"
```

## Integration Points

### Git Hooks
- Located in `.githook/`
- Automatically configured by `.envrc`
- Pre-commit quality checks

### CI/CD Pipeline
- GitHub Actions in `.github/workflows/shellspec.yaml`
- Multi-platform testing (macOS/Ubuntu)
- Coverage reporting and artifact collection

### IDE Integration
- VS Code settings in `.vscode/settings.json`
- ShellCheck integration
- Custom shell formatter support

## Documentation Structure

### Core Documentation
- `docs/installation.md` - Detailed installation scenarios
- `docs/logger.md` - Logger usage patterns
- `docs/arguments.md` - Argument parsing guide
- `docs/version-up.md` - Version management guide

### Technical Analysis
- `TMUX_PATTERN_ANALYSIS.md` - Deep analysis of tmux integration
- `ROADMAP.IDEAS.MD` - Future development plans
- Various demo scripts in `demos/` directory

## Best Practices

### Script Development
- Use `source "$E_BASH/_module.sh"` pattern for loading modules
- Follow the logging tag conventions for consistent output
- Implement dependency checks using the `dependency` function
- Use semantic versioning for script releases

### Testing
- Write ShellSpec tests for all new functionality
- Test both success and failure scenarios
- Use coverage reports to ensure comprehensive testing
- Run tests in TDD mode during development

### Code Quality
- Use altshfmt for consistent formatting
- Run ShellCheck and address all warnings
- Follow the established naming conventions
- Document complex logic with inline comments
