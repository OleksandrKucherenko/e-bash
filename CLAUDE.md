# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**e-bash** is a comprehensive Bash script enhancement framework that provides reusable utilities, tools, and best practices for Bash development. It's designed as a library that projects can integrate to get professional-grade logging, dependency management, argument parsing, semantic versioning, and more.

**Current Version:** v1.16.2 (check individual scripts for version numbers)
**License:** MIT
**Repository:** https://github.com/OleksandrKucherenko/e-bash

## Core Architecture

### Library Structure
- `.scripts/` - Core library functions (12 modules) that can be sourced individually
  - Each module has one-time initialization guards - `source` is idempotent
  - Modules declare their own dependencies and `source` each other as needed
- `bin/` - Standalone tools and scripts (16 executables) including git helpers
- `spec/` - ShellSpec test suite (16 test files)
- `docs/` - Comprehensive documentation and analysis documents
- `demos/` - Demo scripts showing usage patterns
- `.githook/` - Git hooks for pre-commit quality checks
- `bin/gnubin/` - GNU tool shims for macOS compatibility

### Key Components
- **_logger.sh** - Advanced logging system with tag-based filtering, pipe/redirect support
  - Creates `echo:Tag` and `printf:Tag` functions via `logger tag "$@"`
  - Tags can be enabled via `export DEBUG=tag1,tag2` (supports wildcards and negation)
  - Pipe mode: `find . | log:Tag` and redirect mode: `cmd >log:Tag`
- **_dependencies.sh** - Dependency management with version constraints and auto-install
  - Uses semver for version checking (`dependency bash "5.*.*" "brew install bash"`)
  - Supports `optional` for non-required tools
- **_arguments.sh** - Command-line argument parsing with aliases and auto-help generation
  - Define via `export ARGS_DEFINITION="-h,--help -v,--version=:1.0.0"`
  - Auto-creates variables from flag names
- **_semver.sh** - Full semantic versioning support (parsing, comparison, constraints)
- **_commons.sh** - Common utilities, UI components, input functions
- **_self-update.sh** - Script self-updating and version rollback capabilities
- **_tmux.sh** - Tmux integration for progress displays and session management
- **_traps.sh** - Enhanced trap management with multiple handler support per signal
- **_hooks.sh** - Declarative hooks system for extensibility points in scripts
- **_dryrun.sh** - Dry-run wrapper system for safe command execution preview
- **_colors.sh** - Terminal color detection and ANSI color definitions

## Development Commands

### Environment Setup
```bash
# Allow direnv to set up environment (sets E_BASH, PATH, and validates dependencies)
direnv allow

# Dependencies are auto-validated by .envrc using the _dependencies.sh module
```

### Testing
```bash
# Run all tests with coverage
shellspec

# Run only failed tests (quick mode)
shellspec --quick

# Run tests without coverage
shellspec --quick --no-kcov

# Run specific test file
shellspec spec/logger_spec.sh

# Run specific test example (by line number)
shellspec spec/logger_spec.sh:42

# TDD - run tests on file change (requires watchman)
watchman-make -p 'spec/*_spec.sh' '.scripts/*.sh' --run "shellspec"
watchman-make -p 'spec/*_spec.sh' '.scripts/*.sh' --run "shellspec --quick"
```

### Code Quality
```bash
# Format all shell files (requires altshfmt - understands ShellSpec syntax)
ALTSHFMT="/path/to/altshfmt/altshfmt"
find . -name "*.sh" -exec "$ALTSHFMT" -w {} \;

# Linting runs automatically via pre-commit hooks
# Run manually:
shellcheck .scripts/*.sh bin/*.sh

# Git hooks are configured via .githook/ directory
git config core.hooksPath .githook
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
source "$E_BASH/_logger.sh"
logger common "$@"  # Creates echo:Common and printf:Common functions

export DEBUG=common  # Enable only common tag logs
export DEBUG=*       # Enable all logs
export DEBUG=*,-dbg  # Enable all except debug

echo:Common "Hello World"  # Only outputs if 'common' tag enabled
find . | log:Common        # Pipe mode logging
```

### Dependency Management
```bash
source "$E_BASH/_dependencies.sh"

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

### Traps - Enhanced Signal Handling
```bash
source "$E_BASH/_traps.sh"

# Register multiple handlers for the same signal
function cleanup_temp() { echo "Cleaning temp files..."; rm -rf /tmp/myapp/*; }
function save_state() { echo "Saving state..."; }
trap:on cleanup_temp EXIT
trap:on save_state EXIT

# Multiple signals, duplicate handlers allowed
trap:on --allow-duplicates log_error INT TERM ERR

# Handlers execute in LIFO order (last registered runs first)
```

### Hooks - Extensibility Points
```bash
source "$E_BASH/_hooks.sh"

# Declare available hooks
export HOOKS_DIR=".hooks"  # Default is 'ci-cd'
hooks:declare begin deploy end

# Execute hooks (scripts in .hooks/{hook_name}-*.sh run automatically)
hooks:do begin
deploy_application
hooks:do deploy "$VERSION"
hooks:do end

# Hook implementations live in external scripts:
# .hooks/begin-otel-trace.sh, .hooks/deploy-slack-notify.sh, etc.
```

## Environment Variables

### Core Configuration
- `E_BASH` - Path to .scripts directory (set by .envrc)
- `DEBUG` - Comma-separated list of logger tags to enable (supports wildcards: `*`, `-tag`)
- `CI_E_BASH_INSTALL_DEPENDENCIES` - Enable auto-install in CI (1/true/yes)
- `HOOKS_DIR` - Directory for hook scripts (default: `ci-cd`)
- `HOOKS_EXEC_MODE` - Hook execution: `exec` (subprocess) or `source` (current shell)
- `HOOKS_AUTO_TRAP` - Auto-install EXIT trap for `end` hooks (default: `true`)

### Development Tools
- `ALTSHFMT` - Path to altshfmt formatter (understands ShellSpec syntax)
- `ALTSHFMT_PATH` - Alternative path to altshfmt formatter
- `SKIP_ARGS_PARSING` - Skip argument parsing during script loading

### Logger Tags (for DEBUG variable)
- `common`, `debug`, `error`, `hooks`, `trap`, `dependencies`, etc.
- Use `DEBUG=hooks` for hooks execution logging
- Use `DEBUG=*` for all module logging

## Testing & Quality Assurance

### Test Framework
- **ShellSpec 0.28.*** - BDD-style testing for shell scripts
- **kcov 43** - Code coverage reporting
- **ShellCheck 0.11.*** - Static analysis
- **Pre-commit hooks** - Automatic quality checks (copyright, date refresh)

### Test Coverage Configuration
Located in `.shellspec`:
- Includes `.sh` files and specific binaries
- Excludes test files, coverage, and report directories
- JUnit output format for CI integration

### Git Helpers (bin/)
- `git.semantic-version.sh` - Compute version from conventional commit history
- `git.verify-all-commits.sh` - Verify commits follow conventional commits format
- `git.log.sh` - Pretty git log viewer
- `git.files.sh` - Show changed files in commits (plain or tree view)
- `git.conventional-commits.sh` - Parse/generate conventional commits
- `git.sync-by-patches.sh` - Sync branches via patch files
- `git.graph.sh` - Display commit graph

## Cross-Platform Support

### macOS/Linux Compatibility
- Automatic GNU tool setup on macOS via `bin/gnubin/` (gsed, ggrep, gawk, etc.)
- WSL2-friendly FIFO creation with retry logic in logger
- Terminal color and capability detection via `_colors.sh`

### Dependencies Management
- Version constraints using semantic versioning
- Support for HEAD/stable version patterns (e.g., `HEAD-[a-f0-9]{1,8}`)
- Auto-install of missing tools (when permitted via `CI_E_BASH_INSTALL_DEPENDENCIES`)

## Self-Update System

The framework includes sophisticated self-update capabilities:
```bash
source "$E_BASH/_self-update.sh"

# Update to latest patch/stable versions
self-update "~1.0.0"  # Patch releases only
self-update "^1.0.0"  # Minor and patch releases

# Update from specific branches/tags
self-update "branch:master"
self-update "tag:v1.0.0"

# Bind specific file to version
self-update:version:bind "v1.0.0" "$E_BASH/_colors.sh"
```

**Best Practice:** Invoke `self-update` in an EXIT trap to check for updates after script execution:
```bash
source "$E_BASH/_traps.sh"
function on_exit_update() {
  self-update '^1.0.0'
}
trap:on on_exit_update EXIT
```

## Integration Points

### Git Hooks
- Located in `.githook/`
- Pre-commit hooks verify copyright headers and refresh "Last revisit" dates
- Automatically configured by `.envrc`: `git config core.hooksPath .githook`

### CI/CD Pipeline
- GitHub Actions in `.github/workflows/shellspec.yaml`
- Multi-platform testing (macOS/Ubuntu)
- Coverage reporting and artifact collection

### IDE Integration
- VS Code settings in `.vscode/settings.json`
- ShellCheck integration
- Custom shell formatter support (altshfmt)

## Documentation Structure

### Core Documentation
- `docs/public/installation.md` - Detailed installation scenarios
- `docs/public/logger.md` - Logger usage patterns
- `docs/public/arguments.md` - Argument parsing guide
- `docs/public/hooks.md` - Hooks system comprehensive guide
- `docs/public/dryrun-wrapper.md` - Dry-run wrapper system guide
- `docs/public/version-up.md` - Version management guide

### Technical Analysis
- `TMUX_PATTERN_ANALYSIS.md` - Deep analysis of tmux integration
- `ROADMAP.IDEAS.MD` - Future development plans
- `docs/plans/lefthook-migration.md` - Lefthook migration plans
- Various demo scripts in `demos/` directory

## Best Practices

### Script Development
- Use `source "$E_BASH/_module.sh"` pattern for loading modules
- Follow the logging tag conventions for consistent output
- Implement dependency checks using the `dependency` function
- Use semantic versioning for script releases
- Each module file should include copyright header with version number

### Module Initialization Pattern
All modules use one-time initialization guards:
```bash
if type module_function 2>/dev/null | grep -q "is a function"; then return 0; fi
```
This allows safe multiple sourcing of the same module.

### Testing
- Write ShellSpec tests for all new functionality
- Test both success and failure scenarios
- Use `%preserve` for capturing variable values after function calls
- Mock logger and echo functions when testing non-logger modules
- Use `Describe`/`It` blocks with `Before`/`After` hooks for setup/teardown
- Run tests in TDD mode during development

### Code Quality
- Use altshfmt for consistent formatting (understands ShellSpec syntax)
- Run ShellCheck and address all warnings
- Follow the established naming conventions
- Document complex logic with inline comments
- Copyright headers are auto-verified in pre-commit hooks


<!-- CLAVIX:START -->
## Clavix Integration

This project uses Clavix for prompt improvement and PRD generation. The following slash commands are available:

### Prompt Optimization Commands

#### /clavix:improve [prompt]
Optimize prompts with smart depth auto-selection. Clavix analyzes your prompt quality and automatically selects the appropriate depth (standard or comprehensive). Use for all prompt optimization needs.

### PRD & Planning Commands

#### /clavix:prd
Launch the PRD generation workflow. Clavix will guide you through strategic questions and generate both a comprehensive PRD and a quick-reference version optimized for AI consumption.

#### /clavix:plan
Generate an optimized implementation task breakdown from your PRD. Creates a phased task plan with dependencies and priorities.

#### /clavix:implement
Execute tasks from your task plan with AI assistance. Supports automatic git commits and progress tracking.

### Session Management Commands

#### /clavix:start
Enter conversational mode for iterative prompt development. Discuss your requirements naturally, and later use `/clavix:summarize` to extract an optimized prompt.

#### /clavix:summarize
Analyze the current conversation and extract key requirements into a structured prompt and mini-PRD.

### Utility Commands

#### /clavix:execute
Run saved prompts with lifecycle awareness. Execute previously optimized prompts.

#### /clavix:prompts
Manage your saved prompts. List, view, and organize your prompt library.

#### /clavix:archive
Archive completed projects. Move finished PRDs and outputs to the archive for future reference.

**When to use which mode:**
- **Improve mode** (`/clavix:improve`): Smart prompt optimization with auto-depth selection
- **PRD mode** (`/clavix:prd`): Strategic planning with architecture and business impact

**Recommended Workflow:**
1. Start with `/clavix:prd` or `/clavix:start` for complex features
2. Generate tasks with `/clavix:plan`
3. Implement with `/clavix:implement`
4. Archive when complete with `/clavix:archive`

**Pro tip**: Start complex features with `/clavix:prd` or `/clavix:start` to ensure clear requirements before implementation.
<!-- CLAVIX:END -->

## Claude Code Skills

This project includes custom Claude Code skills to assist with testing and development:

### Available Skills

#### `/shellspec` or `Skill(shellspec)`
Expert guidance for ShellSpec unit testing framework. Use when:
- Writing or debugging ShellSpec tests
- Implementing mocking, assertions, or test patterns
- Setting up test infrastructure (setup/teardown hooks)
- Troubleshooting test failures or flaky tests
- Configuring CI/CD integration with ShellSpec

#### `/bats` or `Skill(bats-skill)`
Bash Automated Testing System (BATS) guidance. Use when:
- Writing BATS-style unit or integration tests
- Testing CLI tools or shell functions
- Setting up BATS test infrastructure
- Mocking external commands (curl, git, docker)
- Generating JUnit reports for CI/CD

#### `/pester` or `Skill(pester)`
PowerShell TDD testing framework guidance. Use when:
- Writing or structuring PowerShell unit tests
- Mocking cmdlets, native commands, or .NET types
- Isolating tests with TestDrive/TestRegistry
- Generating code coverage or JUnit/NUnit reports

#### `/gemini` or `Skill(gemini-cli)`
Use Gemini CLI as a complementary AI tool. Use when:
- Analyzing large codebases (massive context windows - 1M tokens)
- Getting second opinions on complex problems
- Deep analysis beyond Claude's context limits
- Processing files exceeding Claude's context capacity

### Invoking Skills

Skills can be invoked via:
- **Slash command**: `/shellspec` or `/bats`
- **Tool**: `Skill` tool with skill name (e.g., `Skill(shellspec)`)
- **Direct reference**: Mention the skill name in context
