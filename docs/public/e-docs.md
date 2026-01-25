# e-docs

Documentation generator for e-bash shell scripts.

## Overview

`e-docs` extracts documentation from e-bash script files and generates GitHub-flavored Markdown. It uses:

- **ctags** for reliable function detection
- **Bash** for documentation block parsing and Markdown generation

## Installation

e-docs is included in the e-bash framework. No additional installation required.

## Usage

```bash
# Generate docs for all scripts in .scripts/
bin/e-docs.sh

# Generate docs for a specific file
bin/e-docs.sh .scripts/_logger.sh

# Check if docs are up to date (for CI/pre-commit)
bin/e-docs.sh --check

# Custom output directory
bin/e-docs.sh -o docs/api

# Disable table of contents
bin/e-docs.sh --no-toc

# Include private functions (starting with _)
bin/e-docs.sh --include-private
```

## Configuration

Create a `.edocsrc` file in your project root:

```bash
# Output directory for generated documentation
EDOCS_OUTPUT_DIR="docs/public/lib"

# Source directories to scan
EDOCS_SOURCE_DIRS=".scripts"

# Output style: github, minimal
EDOCS_STYLE="github"

# Generate Table of Contents
EDOCS_TOC="true"

# Include private functions
EDOCS_INCLUDE_PRIVATE="false"
```

## Documentation Format

e-docs parses the standard e-bash documentation format:

```bash
##
## Brief description of the function
##
## Parameters:
## - arg1 - Description, type, required
## - arg2 - Description, type, default: value
##
## Globals:
## - reads/listen: VAR1, VAR2
## - mutate/publish: VAR3
##
## Side effects:
## - Description of side effect
##
## Returns:
## - 0 on success, 1 on failure
## - Echoes result
##
## Usage:
## - example_call "hello" 42
##
function my_func() {
  ...
}
```

### Module Summary

Place a Module Summary at the **end of the file** to provide overview documentation:

```bash
##
## Module: Module Title
##
## Description of what this module provides.
##
## References:
## - demo: demo.example.sh
## - documentation: docs/public/module.md
## - tests: spec/module_spec.sh
##
## Categories:
##
## Category Name:
## - function_name() - Brief description
##
```

### Inline Hint Tags

e-docs supports special `@{keyword}` tags that can be placed anywhere within a `##` documentation block to control documentation generation behavior:

#### Available Hints

| Tag                           | Description                                                                                                               |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `@{internal}`                 | Mark function as internal implementation detail. Function will be excluded from generated documentation.                  |
| `@{ignore}`                   | Explicitly exclude function from documentation. Similar to `@{internal}` but semantically indicates deliberate exclusion. |
| `@{deprecated}`               | Mark function as deprecated. Adds deprecation notice to output.                                                           |
| `@{deprecated:message}`       | Mark as deprecated with a custom message explaining the deprecation reason or migration path.                             |
| `@{since:version}`            | Document the version when the function was introduced (e.g., `@{since:2.0.0}`).                                           |
| `@{example}...@{example:end}` | Define a multi-line example block for complex usage patterns.                                                             |

#### Usage Examples

**Excluding internal functions:**

```bash
##
## Internal helper for signal normalization @{internal}
##
## Parameters:
## - signal - Raw signal name, string, required
##
function _internal_helper() {
  # ...
}
```

**Marking deprecated functions:**

```bash
##
## Old logging function @{deprecated:Use logger:compose instead}
##
## This function will be removed in v3.0.0
##
function old_log() {
  # ...
}
```

**Documenting version information:**

```bash
##
## New feature function @{since:2.1.0}
##
## Provides enhanced logging capabilities with structured output.
##
function new_feature() {
  # ...
}
```

**Multi-line example blocks:**

```bash
##
## Complex function with detailed examples
##
## @{example}
## # Basic usage
## result=$(complex_func "input")
##
## # With options
## complex_func --verbose --format=json "input"
##
## # Pipeline usage
## echo "data" | complex_func | process_output
## @{example:end}
##
function complex_func() {
  # ...
}
```

> **Note:** Hint tags can be placed anywhere in the documentation block - at the end of a description line, on their own line, or within any section. The parser will detect and process them regardless of position.

## Git Integration

e-docs includes a pre-commit hook that automatically updates documentation when `.scripts/*.sh` files are modified:

```bash
# The hook is at .githook/pre-commit.d/docs-update.sh
# It runs automatically if git hooks are configured:
git config core.hooksPath .githook
```

## Mise Tasks

```bash
# Generate all documentation
mise run docs

# Check if docs are up to date
mise run docs:check
```

## Requirements

- **Universal Ctags** - For function detection
- **gawk** - For text processing (optional, bash fallback available)
- **Bash 4.0+** - For script execution

## Generated Output

Documentation is generated to `docs/public/lib/` by default:

```
docs/public/lib/
├── _colors.md
├── _commons.md
├── _logger.md
├── _dependencies.md
└── ...
```

Each file includes:
- Module title and description (from Module Summary)
- Table of Contents
- Function documentation with Parameters, Globals, Returns, etc.
