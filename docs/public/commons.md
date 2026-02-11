# e-bash Commons Utilities Documentation

<!-- TOC -->

- [e-bash Commons Utilities Documentation](#e-bash-commons-utilities-documentation)
  - [Quick Start Guide](#quick-start-guide)
    - [Git Repository Root Detection](#git-repository-root-detection)
    - [Configuration File Hierarchy](#configuration-file-hierarchy)
    - [XDG-Compliant Configuration Discovery](#xdg-compliant-configuration-discovery)
    - [Template Variable Expansion](#template-variable-expansion)
    - [Multi-line Text Input](#multi-line-text-input)
  - [Git Repository Functions](#git-repository-functions)
    - [git:root - Find Git Repository Root](#gitroot---find-git-repository-root)
      - [Function Signature](#function-signature)
      - [Arguments](#arguments)
      - [Return Values](#return-values)
      - [Examples](#examples)
      - [Repository Type Detection](#repository-type-detection)
      - [Safety Features](#safety-features)
  - [Configuration Discovery Functions](#configuration-discovery-functions)
    - [config:hierarchy - Hierarchical Config Search](#confighierarchy---hierarchical-config-search)
      - [Function Signature](#function-signature-1)
      - [Arguments](#arguments-1)
      - [Return Values](#return-values-1)
      - [Examples](#examples-1)
      - [Search Order](#search-order)
    - [config:hierarchy:xdg - XDG Base Directory Spec](#confighierarchyxdg---xdg-base-directory-spec)
      - [Function Signature](#function-signature-2)
      - [Arguments](#arguments-2)
      - [Return Values](#return-values-2)
      - [Examples](#examples-2)
      - [Search Priority](#search-priority)
  - [Variable Resolution Functions](#variable-resolution-functions)
    - [env:resolve - Template Variable Expansion](#envresolve---template-variable-expansion)
      - [Function Signature](#function-signature-3)
      - [Arguments](#arguments-3)
      - [Return Values](#return-values-3)
      - [Examples](#examples-3)
      - [Resolution Priority](#resolution-priority)
      - [Pipeline Mode](#pipeline-mode)
      - [Safety Features](#safety-features-1)
  - [Use Cases and Patterns](#use-cases-and-patterns)
    - [Monorepo Project Root Detection](#monorepo-project-root-detection)
    - [Multi-Environment Configuration Loading](#multi-environment-configuration-loading)
    - [User-Specific Config Overrides](#user-specific-config-overrides)
    - [Configuration Merging Strategy](#configuration-merging-strategy)
  - [Best Practices](#best-practices)
    - [Error Handling](#error-handling)
    - [Configuration File Precedence](#configuration-file-precedence)
    - [Security Considerations](#security-considerations)
  - [UI Components - Interactive Input](#ui-components---interactive-input)
    - [input:multi-line - Multi-line Text Editor](#inputmulti-line---multi-line-text-editor)
    - [input:readpwd - Password Input](#inputreadpwd---password-input)
    - [input:selector - Menu Selector](#inputselector---menu-selector)
  - [Reference](#reference)
    - [Safety Features](#safety-features-2)
    - [Cross-Platform Compatibility](#cross-platform-compatibility)

<!-- /TOC -->

## Quick Start Guide

### Git Repository Root Detection

```bash
source "$E_BASH/_commons.sh"

# Find git repository root from current directory
repo_root=$(git:root)
echo "Repository root: $repo_root"

# Detect repository type
repo_type=$(git:root "." "type")
echo "Repository type: $repo_type"  # regular, worktree, or submodule
```

### Configuration File Hierarchy

```bash
source "$E_BASH/_commons.sh"

# Find all .eslintrc files from current directory up to git root
configs=$(config:hierarchy ".eslintrc" "." "git" ",.js,.json,.yaml,.yml")
echo "$configs"
# Output (one per line, root to current):
# /project/.eslintrc.json
# /project/packages/app/.eslintrc.js

# Load and merge configs in correct order
while IFS= read -r config_file; do
  [[ -n "$config_file" ]] && echo "Loading: $config_file"
done <<< "$configs"
```

### XDG-Compliant Configuration Discovery

```bash
source "$E_BASH/_commons.sh"

# Find nvim configuration files following XDG spec
configs=$(config:hierarchy:xdg "nvim" "init.vim,.nvimrc" "." "home")
echo "$configs"
# Output (priority order):
# /current/project/.nvim/init.vim          (project-specific, highest priority)
# ~/.config/nvim/init.vim                   (user config)
# /etc/xdg/nvim/init.vim                    (system-wide XDG)
# /etc/nvim/init.vim                        (traditional system config)
```

### Template Variable Expansion

```bash
source "$E_BASH/_commons.sh"

# Expand environment variables in template strings
export API_HOST="api.example.com"
export API_VERSION="v2"

result=$(env:resolve "https://{{env.API_HOST}}/{{env.API_VERSION}}/users")
echo "$result"
# Output: https://api.example.com/v2/users

# Use custom configuration array
declare -A CONFIG
CONFIG[DB_HOST]="localhost"
CONFIG[DB_PORT]="5432"

result=$(env:resolve "postgres://{{env.DB_HOST}}:{{env.DB_PORT}}/mydb" "CONFIG")
echo "$result"
# Output: postgres://localhost:5432/mydb

# Process templates from files using pipeline mode
cat template.conf | env:resolve > config.conf
```

### Multi-line Text Input

```bash
source "$E_BASH/_commons.sh"

# Open a multi-line text editor (Ctrl+D to save, Esc to cancel)
text=$(input:multi-line -w 60 -h 10)
echo "Captured: $text"

# Full-screen editor
commit_msg=$(input:multi-line)

# Stream mode - inline editor at cursor position (5 lines, full width)
description=$(input:multi-line -m stream)
```

## Git Repository Functions

### git:root - Find Git Repository Root

Finds the Git repository root folder by searching upward from the current directory. Properly detects regular repositories, git worktrees, and submodules.

#### Function Signature

```bash
git:root [start_path] [output_type]
```

#### Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `start_path` | `.` (current directory) | Starting directory path for search |
| `output_type` | `path` | Type of output to return |

**Output Type Options:**

- `path`: Return only the repository root path
- `type`: Return only the repository type (`regular`, `worktree`, `submodule`, `none`)
- `both`: Return `type:path` format
- `all`: Return detailed info as `type:path:git_dir`

#### Return Values

- **Exit Code**: `0` if git root found, `1` otherwise
- **STDOUT**: Based on `output_type` parameter

#### Examples

```bash
# Basic usage - get repository root
root=$(git:root)
echo "Repository: $root"
# Output: /home/user/my-project

# From specific directory
root=$(git:root "/path/to/nested/folder")
echo "Root: $root"
# Output: /path/to/my-project

# Get repository type only
type=$(git:root "." "type")
echo "Type: $type"
# Output: regular

# Get both type and path
info=$(git:root "." "both")
echo "Info: $info"
# Output: regular:/home/user/my-project

# Get all details
details=$(git:root "." "all")
echo "Details: $details"
# Output: regular:/home/user/my-project:/home/user/my-project/.git

# Handle non-repository directories
if ! root=$(git:root "/tmp"); then
  echo "Not in a git repository"
fi
```

#### Repository Type Detection

**Regular Repository:**
- Contains a `.git` directory
- Standard git repository structure

**Git Worktree:**
- Contains a `.git` file (not directory)
- File points to `.git/worktrees/` directory
- Created with `git worktree add`

**Submodule:**
- Contains a `.git` file (not directory)
- File points to parent's `.git/modules/` directory
- Nested within another git repository

#### Safety Features

- **Infinite Loop Protection**: Maximum 1000 iterations prevents hanging
- **Symlink Safety**: Resolves symlinks to real paths
- **Filesystem Root Detection**: Stops at `/` to prevent infinite loops
- **Directory Comparison**: Detects when `dirname` returns same path

```bash
# Safety in action - handles edge cases gracefully
git:root "/some/malformed/symlink/path"  # Returns failure safely
git:root "/tmp"                           # No git repo, returns failure
```

## Configuration Discovery Functions

### config:hierarchy - Hierarchical Config Search

Finds configuration files by searching upward from the current directory to a stop point. Similar to [c12](https://www.npmjs.com/package/c12) but for declarative config files only.

#### Function Signature

```bash
config:hierarchy [config_names] [start_path] [stop_at] [extensions]
```

#### Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `config_names` | `.config` | Base config file name(s), comma-separated |
| `start_path` | `.` | Starting directory for search |
| `stop_at` | `git` | Where to stop searching |
| `extensions` | `,.json,.yaml,.yml,.toml,.ini,.conf,.rc` | File extensions to try |

**Stop At Options:**

- `git`: Stop at git repository root
- `home`: Stop at user home directory (`$HOME`)
- `root`: Stop at filesystem root (`/`)
- `/custom/path`: Stop at specific absolute path

**Extensions:**

- Empty string `""`: Exact match only (no extension)
- Comma-separated list: Try all extensions for each config name

#### Return Values

- **Exit Code**: `0` if at least one config found, `1` otherwise
- **STDOUT**: Config file paths, one per line, ordered from root to current (bottom-up)

#### Examples

```bash
# Find .eslintrc files with various extensions
configs=$(config:hierarchy ".eslintrc" "." "git" ",.js,.json,.yaml,.yml")
echo "$configs"
# Output:
# /project/.eslintrc.json
# /project/src/.eslintrc.js
# /project/src/components/.eslintrc.yaml

# Multiple config names
configs=$(config:hierarchy "package.json,tsconfig.json" "." "home" ".json")
echo "$configs"

# Exact filename match (no extension)
shellspec_file=$(config:hierarchy ".shellspec" "." "git" "")
echo "$shellspec_file"
# Output: /project/.shellspec

# Stop at custom path
configs=$(config:hierarchy ".myrc" "." "/home/user/project" ".json,.yaml")

# Default extensions when parameter omitted
configs=$(config:hierarchy ".config")
# Tries: .config, .config.json, .config.yaml, .config.yml, .config.toml, etc.

# Check if any configs found
if config:hierarchy ".prettierrc" "." "git" ",.js,.json,.yaml" >/dev/null; then
  echo "Prettier config found"
fi
```

#### Search Order

1. Starts at `start_path`
2. Checks for each `config_name` with each `extension`
3. Moves up one directory
4. Repeats until reaching `stop_at` or filesystem root
5. Returns results in **root-to-current order** (for proper config merging)

```bash
# Directory structure:
# /project/.eslintrc.json          <- Found 1st (root)
# /project/src/                    <- No config
# /project/src/app/.eslintrc.js    <- Found 2nd (current)

# Search from /project/src/app
configs=$(config:hierarchy ".eslintrc" "/project/src/app" "git" ",.js,.json")
# Returns (in this order):
# /project/.eslintrc.json
# /project/src/app/.eslintrc.js

# This order allows proper config merging:
while IFS= read -r config; do
  merge_config "$config"  # Root configs first, local configs override
done <<< "$configs"
```

### config:hierarchy:xdg - XDG Base Directory Spec

Finds configuration files following the [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html). Combines hierarchical search with XDG-compliant system directories.

#### Function Signature

```bash
config:hierarchy:xdg app_name [config_names] [start_path] [stop_at] [extensions]
```

#### Arguments

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `app_name` | **Yes** | - | Application name for XDG directories |
| `config_names` | No | `config` | Config file name(s), comma-separated |
| `start_path` | No | `.` | Starting directory for hierarchical search |
| `stop_at` | No | `home` | Where to stop hierarchical search |
| `extensions` | No | `,.json,.yaml,.yml,.toml,.ini,.conf,.rc` | File extensions |

#### Return Values

- **Exit Code**: `0` if at least one config found, `1` otherwise
- **STDOUT**: Config file paths, one per line, ordered by priority (highest to lowest)

#### Examples

```bash
# Find nvim configuration
configs=$(config:hierarchy:xdg "nvim" "init.vim,.nvimrc")
echo "$configs"
# Output (in priority order):
# /current/project/.config/nvim/init.vim  (project, highest priority)
# ~/.config/nvim/init.vim                  (user XDG)
# /etc/xdg/nvim/init.vim                   (system XDG)

# Find application config with XDG_CONFIG_HOME override
export XDG_CONFIG_HOME="/custom/config"
configs=$(config:hierarchy:xdg "myapp" "config" "." "home" ".json,.yaml")
echo "$configs"
# Searches:
# - Current directory hierarchy
# - /custom/config/myapp/
# - ~/.config/myapp/
# - /etc/xdg/myapp/
# - /etc/myapp/

# Real-world example: Git config hierarchy
configs=$(config:hierarchy:xdg "git" "config" "." "home" "")
# Searches for exact filename "config" (no extension)
# Priority: .git/config > ~/.config/git/config > /etc/xdg/git/config > /etc/git/config

# Application-specific settings
configs=$(config:hierarchy:xdg "myapp" ".myapprc,config" "." "root" ".json,.toml")

# Validate app_name is required
if ! configs=$(config:hierarchy:xdg "" "config" 2>&1); then
  echo "Error: app_name required"
fi
```

#### Search Priority

Configuration files are returned in priority order (highest to lowest):

1. **Hierarchical search** (current directory → stop_at)
   - Highest priority
   - Project-specific configurations

2. **$XDG_CONFIG_HOME/app_name/** (if `XDG_CONFIG_HOME` is set)
   - User override directory

3. **~/.config/app_name/** (XDG default)
   - Standard user configuration

4. **/etc/xdg/app_name/** (XDG system-wide)
   - System-wide XDG configuration

5. **/etc/app_name/** (traditional)
   - Traditional system configuration

```bash
# Deduplication: Same file in multiple locations only appears once
# Hierarchical search takes precedence over XDG directories

# Example:
# If ~/.config/myapp/config.json exists in BOTH:
#   - Project directory (.config/myapp/config.json)
#   - User XDG directory (~/.config/myapp/config.json)
# Only the project directory version is returned (higher priority)
```

## Variable Resolution Functions

### env:resolve - Template Variable Expansion

Resolves `{{env.VAR_NAME}}` template patterns in strings by expanding them to their environment variable values or custom associative array values. Supports both direct string expansion and pipeline-based template processing.

#### Function Signature

```bash
env:resolve [input_string] [array_name]

# Pipeline mode
cat template.txt | env:resolve [array_name]
```

#### Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `input_string` | - | String containing `{{env.*}}` patterns (required in direct mode) |
| `array_name` | - | Name of globally defined associative array for custom variable resolution (optional) |

**Pattern Syntax:**
- `{{env.VAR_NAME}}` - Standard format
- `{{ env.VAR_NAME }}` - Whitespace allowed
- `{{  env.VAR_NAME  }}` - Multiple spaces supported

**Variable Name Rules:**
- Must start with letter or underscore: `[A-Za-z_]`
- Followed by alphanumeric or underscore: `[A-Za-z0-9_]*`
- Examples: `VAR`, `MY_VAR`, `var123`, `_private`

#### Return Values

- **Exit Code**: `0` on success, `1` on error (infinite loop detected)
- **STDOUT**: Expanded string with all patterns replaced
- **STDERR**: Error messages for self-referential patterns or infinite loops

#### Examples

**Basic Environment Variable Expansion:**

```bash
# Simple variable expansion
export API_HOST="api.example.com"
result=$(env:resolve "Host: {{env.API_HOST}}")
echo "$result"
# Output: Host: api.example.com

# Multiple variables in one string
export API_HOST="api.example.com"
export API_PORT="8080"
export API_VERSION="v2"
result=$(env:resolve "https://{{env.API_HOST}}:{{env.API_PORT}}/{{env.API_VERSION}}/users")
echo "$result"
# Output: https://api.example.com:8080/v2/users

# Whitespace variations (all valid)
export HOME="/home/user"
env:resolve "{{env.HOME}}/config"           # No whitespace
env:resolve "{{ env.HOME }}/config"         # With whitespace
env:resolve "{{  env.HOME  }}/config"       # Multiple spaces
# All output: /home/user/config
```

**Using Custom Associative Arrays:**

```bash
# Declare configuration array
declare -A CONFIG
CONFIG[DB_HOST]="localhost"
CONFIG[DB_PORT]="5432"
CONFIG[DB_NAME]="myapp"

# Resolve using custom array
result=$(env:resolve "postgres://{{env.DB_HOST}}:{{env.DB_PORT}}/{{env.DB_NAME}}" "CONFIG")
echo "$result"
# Output: postgres://localhost:5432/myapp

# Array values override environment variables
export API_VERSION="v1"  # Environment variable
declare -A OVERRIDE
OVERRIDE[API_VERSION]="v2"  # Array value (takes priority)

result=$(env:resolve "Version: {{env.API_VERSION}}" "OVERRIDE")
echo "$result"
# Output: Version: v2

# Fallback to environment when key not in array
declare -A PARTIAL
PARTIAL[HOST]="api.example.com"
export PORT="8080"  # Not in array, uses env var

result=$(env:resolve "{{env.HOST}}:{{env.PORT}}" "PARTIAL")
echo "$result"
# Output: api.example.com:8080
```

**Pipeline Mode - Template File Processing:**

```bash
# Process template file with environment variables
cat > template.conf <<'EOF'
server {
  host: {{env.SERVER_HOST}}
  port: {{env.SERVER_PORT}}
}
database {
  url: {{env.DB_URL}}
}
EOF

export SERVER_HOST="localhost"
export SERVER_PORT="8080"
export DB_URL="postgresql://localhost/mydb"

# Pipeline mode without array
cat template.conf | env:resolve > config.conf

# View result
cat config.conf
# Output:
# server {
#   host: localhost
#   port: 8080
# }
# database {
#   url: postgresql://localhost/mydb
# }

# Pipeline mode with custom array
declare -A DEPLOY_VARS
DEPLOY_VARS[ENVIRONMENT]="production"
DEPLOY_VARS[REGION]="us-east-1"

cat template.yaml | env:resolve "DEPLOY_VARS" > deploy.yaml
```

**Real-World Use Cases:**

```bash
# 1. Docker Compose template expansion
cat > docker-compose.template.yml <<'EOF'
version: '3.8'
services:
  app:
    image: {{env.APP_IMAGE}}
    ports:
      - "{{env.APP_PORT}}:{{env.APP_PORT}}"
    environment:
      NODE_ENV: {{env.NODE_ENV}}
      API_URL: {{env.API_URL}}
EOF

export APP_IMAGE="node:18-alpine"
export APP_PORT="3000"
export NODE_ENV="production"
export API_URL="https://api.example.com"

cat docker-compose.template.yml | env:resolve > docker-compose.yml

# 2. Kubernetes manifest generation
declare -A K8S_CONFIG
K8S_CONFIG[NAMESPACE]="production"
K8S_CONFIG[REPLICAS]="3"
K8S_CONFIG[IMAGE_TAG]="v1.2.3"

cat k8s.template.yaml | env:resolve "K8S_CONFIG" > k8s.yaml

# 3. CI/CD configuration templating
export CI_BRANCH="main"
export CI_COMMIT_SHA="abc123"
export DEPLOY_ENV="staging"

result=$(env:resolve "Deploying {{env.CI_BRANCH}}@{{env.CI_COMMIT_SHA}} to {{env.DEPLOY_ENV}}")
echo "$result"
# Output: Deploying main@abc123 to staging

# 4. URL construction with query parameters
export BASE_URL="https://example.com/api"
export TOKEN="secret123"
export USER_ID="456"

result=$(env:resolve "{{env.BASE_URL}}/users/{{env.USER_ID}}?token={{env.TOKEN}}")
echo "$result"
# Output: https://example.com/api/users/456?token=secret123
```

**Nested Variable Expansion:**

```bash
# Valid nested expansion (one variable references another)
export INNER="final_value"
export OUTER='{{env.INNER}}'

result=$(env:resolve "Value: {{env.OUTER}}")
echo "$result"
# Output: Value: final_value

# Deep nesting (up to 10 levels supported)
export L0="base"
export L1='{{env.L0}}'
export L2='{{env.L1}}'
export L3='{{env.L2}}'

result=$(env:resolve "Deep: {{env.L3}}")
echo "$result"
# Output: Deep: base
```

#### Resolution Priority

Variables are resolved in the following priority order:

1. **Associative Array** (if provided)
   - Highest priority
   - Custom configuration values

2. **Environment Variables**
   - Fallback when key not found in array
   - Standard shell environment

3. **Empty String**
   - When variable is unset or not found
   - No error thrown for missing variables

```bash
# Priority demonstration
export VAR="from_env"
declare -A CUSTOM
CUSTOM[VAR]="from_array"

# Array takes priority
result=$(env:resolve "{{env.VAR}}" "CUSTOM")
echo "$result"
# Output: from_array

# No array - uses environment
result=$(env:resolve "{{env.VAR}}")
echo "$result"
# Output: from_env

# Variable not found - empty string
result=$(env:resolve "{{env.NONEXISTENT}}")
echo "$result"
# Output: (empty)
```

#### Pipeline Mode

Pipeline mode is automatically activated when stdin is not a terminal.

**Detection Logic:**
- `$# -eq 0` AND stdin available → Pipeline mode without array
- `$# -eq 1` AND arg matches `^[A-Z_][A-Z0-9_]*$` AND stdin available → Pipeline mode with array
- Otherwise → Direct mode

```bash
# Stdin from pipe - pipeline mode
echo "Value: {{env.VAR}}" | env:resolve

# Stdin from file redirect - pipeline mode
env:resolve < template.txt

# Stdin from heredoc - pipeline mode
env:resolve <<'EOF'
Line 1: {{env.VAR1}}
Line 2: {{env.VAR2}}
EOF

# Pipeline mode with array
declare -A CONFIG
CONFIG[KEY]="value"
cat template.txt | env:resolve "CONFIG"

# Direct mode (no stdin)
result=$(env:resolve "{{env.VAR}}")  # Direct mode

# Empty lines are preserved in pipeline mode
env:resolve <<'EOF'
{{env.LINE1}}

{{env.LINE2}}
EOF
# Output includes blank line between expansions
```

#### Safety Features

**Infinite Loop Protection:**

The function includes robust protection against circular references and self-referential patterns.

```bash
# Self-referential pattern detected immediately
export SELF='{{env.SELF}}'
result=$(env:resolve "{{env.SELF}}" 2>&1)
# Exit code: 1
# Error: env:resolve detected self-referential pattern for variable 'SELF'

# Circular reference (A→B→A)
export A='{{env.B}}'
export B='{{env.A}}'
result=$(env:resolve "{{env.A}}" 2>&1)
# Exit code: 1
# Error: env:resolve exceeded maximum iterations (10), possible infinite loop

# Complex cycle (A→B→C→D→E→A)
export CYCLE_A='{{env.CYCLE_B}}'
export CYCLE_B='{{env.CYCLE_C}}'
export CYCLE_C='{{env.CYCLE_D}}'
export CYCLE_D='{{env.CYCLE_E}}'
export CYCLE_E='{{env.CYCLE_A}}'
result=$(env:resolve "{{env.CYCLE_A}}" 2>&1)
# Exit code: 1
# Error: env:resolve exceeded maximum iterations (10), possible infinite loop
```

**Special Character Handling:**

The function correctly handles all special characters in variable values, including `&`, `\`, and other characters. The implementation uses pure bash substring operations (string slicing) rather than parameter expansion for replacement, ensuring portable behavior across all bash versions and compilation options.

```bash
# Ampersands in URLs
export URL='https://api.com?a=1&b=2&c=3'
result=$(env:resolve "URL: {{env.URL}}")
echo "$result"
# Output: URL: https://api.com?a=1&b=2&c=3

# Backslashes in Windows paths
export WIN_PATH='C:\Users\Admin\Documents'
result=$(env:resolve "Path: {{env.WIN_PATH}}")
echo "$result"
# Output: Path: C:\Users\Admin\Documents

# Combined special characters
export MIXED='C:\Path\file.txt?query=a&b=c'
result=$(env:resolve "{{env.MIXED}}")
echo "$result"
# Output: C:\Path\file.txt?query=a&b=c

# Sed replacement patterns
export SED_PATTERN='s/old/& new/g'
result=$(env:resolve "{{env.SED_PATTERN}}")
echo "$result"
# Output: s/old/& new/g
```

**Safety Limits:**

- **Max iterations**: 10 (prevents infinite loops)
- **Progress detection**: Breaks if no change after replacement
- **Error reporting**: Clear messages to stderr with original pattern
- **Exit codes**: Non-zero on error for proper error handling

**Best Practices:**

```bash
# Always check return codes
if ! result=$(env:resolve "{{env.VAR}}" 2>&1); then
  echo "ERROR: Variable expansion failed" >&2
  echo "$result" >&2
  exit 1
fi

# Validate critical variables exist before expansion
if [[ -z "$API_KEY" ]]; then
  echo "ERROR: API_KEY must be set" >&2
  exit 1
fi
result=$(env:resolve "API Key: {{env.API_KEY}}")

# Use arrays for structured configuration
declare -A CONFIG
CONFIG[HOST]="${HOST:-localhost}"
CONFIG[PORT]="${PORT:-8080}"
result=$(env:resolve "{{env.HOST}}:{{env.PORT}}" "CONFIG")
```

**Advanced Templating:**

For more complex templating scenarios beyond simple variable expansion, consider using specialized templating tools:

- **[Mo (Mustache templates in Bash)](https://github.com/tests-always-included/mo)** - Full Mustache templating support with:
  - Conditional rendering (`{{#variable}}...{{/variable}}`)
  - Loops and iteration (`{{#array}}...{{/array}}`)
  - Partials and includes (`{{>partial}}`)
  - Lambda functions and custom helpers
  - Comment blocks and whitespace control

The `env:resolve` function is designed for simple, secure variable expansion. For advanced template rendering with logic and control structures, Mo provides a comprehensive solution while maintaining bash compatibility.

## Use Cases and Patterns

### Monorepo Project Root Detection

```bash
# Find monorepo root regardless of current working directory
monorepo_root=$(git:root)
cd "$monorepo_root" || exit 1

# Detect if working in a worktree
if [[ "$(git:root . type)" == "worktree" ]]; then
  echo "Working in git worktree"
  # Get main worktree location
  git_dir=$(git:root . all | cut -d: -f3)
  echo "Worktree git dir: $git_dir"
fi
```

### Multi-Environment Configuration Loading

```bash
# Load configs from most general to most specific
load_configs() {
  local configs
  configs=$(config:hierarchy ".myapprc" "." "git" ",.json,.yaml,.toml")

  if [[ $? -eq 0 ]]; then
    while IFS= read -r config_file; do
      if [[ -n "$config_file" && -f "$config_file" ]]; then
        echo "Loading config: $config_file"
        # Load and merge configuration
        case "$config_file" in
          *.json) jq -s 'reduce .[] as $item ({}; . * $item)' "$config_file" ;;
          *.yaml) yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' "$config_file" ;;
          *.toml) # TOML merge logic
        esac
      fi
    done <<< "$configs"
  else
    echo "No configuration files found"
    return 1
  fi
}
```

### User-Specific Config Overrides

```bash
# XDG-compliant config loading with user overrides
load_app_config() {
  local app_name="$1"
  local configs

  configs=$(config:hierarchy:xdg "$app_name" "config,.${app_name}rc" "." "home" ",.json,.yaml")

  if [[ $? -eq 0 ]]; then
    echo "Found configs (highest priority first):"
    echo "$configs"

    # Process in reverse order (lowest to highest priority)
    # Later configs override earlier ones
    local -a config_array
    while IFS= read -r line; do
      [[ -n "$line" ]] && config_array+=("$line")
    done <<< "$configs"

    # Reverse iteration for merging
    for ((i=${#config_array[@]}-1; i>=0; i--)); do
      echo "Merging: ${config_array[$i]}"
      merge_config "${config_array[$i]}"
    done
  fi
}

# Usage
load_app_config "myapp"
```

### Configuration Merging Strategy

```bash
# Proper config merging respecting hierarchy
merge_configurations() {
  local config_name="$1"
  local final_config="{}"

  # Get all configs from root to current
  local configs
  configs=$(config:hierarchy "$config_name" "." "git" ".json")

  if [[ $? -eq 0 ]]; then
    # Configs are already in root-to-current order
    # Each config overrides/merges with previous
    while IFS= read -r config_file; do
      if [[ -n "$config_file" ]]; then
        echo "Merging: $config_file"
        final_config=$(jq -s '.[0] * .[1]' <(echo "$final_config") "$config_file")
      fi
    done <<< "$configs"

    echo "$final_config"
  fi
}

# Example: ESLint-style config merging
final_config=$(merge_configurations ".eslintrc")
echo "$final_config" > .eslintrc.merged.json
```

## Best Practices

### Error Handling

```bash
# Always check return codes
if root=$(git:root); then
  cd "$root" || exit 1
  echo "Working in: $root"
else
  echo "ERROR: Not in a git repository" >&2
  exit 1
fi

# Validate configs exist before processing
if ! configs=$(config:hierarchy ".myrc" "." "git"); then
  echo "WARNING: No configuration files found, using defaults" >&2
  use_default_config
fi

# Handle missing app_name gracefully
if ! configs=$(config:hierarchy:xdg "$app_name" "config" 2>&1); then
  echo "ERROR: $configs" >&2
  return 1
fi
```

### Configuration File Precedence

```bash
# Document your precedence rules clearly
# Example: Project > User > System

# Option 1: Hierarchical only (project-specific wins)
config:hierarchy ".prettierrc" "." "git"

# Option 2: XDG-compliant (project > user XDG > system XDG)
config:hierarchy:xdg "prettier" ".prettierrc,prettier.config"

# Option 3: Custom precedence
custom_precedence() {
  # 1. Environment variable override
  [[ -n "$MY_CONFIG" ]] && echo "$MY_CONFIG" && return

  # 2. Project config
  local project_config
  project_config=$(config:hierarchy ".myrc" "." "git" ".json" | head -1)
  [[ -n "$project_config" ]] && echo "$project_config" && return

  # 3. User config
  local user_config="$HOME/.config/myapp/config.json"
  [[ -f "$user_config" ]] && echo "$user_config" && return

  # 4. Default
  echo "/etc/myapp/config.json"
}
```

### Security Considerations

```bash
# Validate config file ownership and permissions
validate_config() {
  local config_file="$1"

  # Check file exists and is readable
  if [[ ! -r "$config_file" ]]; then
    echo "ERROR: Cannot read config: $config_file" >&2
    return 1
  fi

  # Check file ownership (optional, for security-sensitive configs)
  if [[ "$(stat -c '%U' "$config_file" 2>/dev/null)" != "$USER" ]]; then
    echo "WARNING: Config not owned by current user: $config_file" >&2
  fi

  # Check permissions (warn if world-writable)
  if [[ "$(stat -c '%a' "$config_file" 2>/dev/null)" =~ [0-9][0-9][2367] ]]; then
    echo "WARNING: Config is world-writable: $config_file" >&2
  fi
}

# Safe config loading
load_safe_config() {
  local configs
  configs=$(config:hierarchy:xdg "myapp" "config" "." "home" ".json")

  while IFS= read -r config_file; do
    if [[ -n "$config_file" ]]; then
      if validate_config "$config_file"; then
        echo "Loading: $config_file"
        source "$config_file"
      fi
    fi
  done <<< "$configs"
}
```

## UI Components - Interactive Input

The `_commons.sh` module provides three interactive terminal input components, each designed for different use cases.

### input:multi-line - Multi-line Text Editor

A full-featured modal text editor that opens directly in the terminal. Supports multi-line editing with arrow key navigation, scrolling, word/line deletion, and clipboard paste.

#### Function Signature

```bash
text=$(input:multi-line [-m mode] [-x pos_x] [-y pos_y] [-w width] [-h height] [--alt-buffer] [--no-status])
```

#### Arguments

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `-m` | string | `box` | Rendering mode: `box` (positioned overlay) or `stream` (inline at cursor) |
| `-x` | integer | `0` | Left offset (column position, box mode only) |
| `-y` | integer | `0` | Top offset (row position, box mode only) |
| `-w` | integer | terminal width | Editor width in columns |
| `-h` | integer | terminal height (box) or `5` (stream) | Editor height in rows |
| `--alt-buffer` | flag | off | Use alternative terminal buffer (box mode only, preserves scroll history) |
| `--no-status` | flag | off | Hide the status bar |

#### Examples

```bash
source "$E_BASH/_commons.sh"

# Full-screen editor (box mode, default)
text=$(input:multi-line)

# Sized editor (60 columns x 10 rows)
text=$(input:multi-line -w 60 -h 10)

# Alternative buffer (preserves scroll history, like vim)
text=$(input:multi-line --alt-buffer)

# Stream mode - inline editor at current cursor position
# Uses full terminal width, default height of 5 lines
text=$(input:multi-line -m stream)

# Stream mode with custom height (10 lines)
text=$(input:multi-line -m stream -h 10)

# Custom save keybinding (Ctrl+S instead of Ctrl+D)
ML_KEY_SAVE=$'\x13' text=$(input:multi-line -w 60 -h 10)

# Handle save vs cancel
if text=$(input:multi-line -w 60 -h 10); then
  echo "User saved:"
  echo "$text"
else
  echo "User cancelled (Esc)"
fi
```

#### Rendering Modes

**Box mode** (default): Position and size the editor explicitly with `-x`, `-y`, `-w`, `-h`.
Useful for modal dialog overlays. Width and height are clamped to terminal boundaries
so the editor cannot exceed available space. Supports `--alt-buffer` to preserve
terminal scroll history.

**Stream mode** (`-m stream`): Uses the current cursor position and full terminal width.
Defaults to 5 lines of height. If the cursor is near the bottom of the terminal,
emits newlines to scroll up and make room. On exit, repositions the cursor to the
editor area so output reuses those lines. Does not support `--alt-buffer`.

#### Keyboard Controls

| Key | Action |
|-----|--------|
| Arrow keys | Navigate cursor (up, down, left, right) |
| Page Up/Down | Scroll by page |
| Home / End | Move cursor to beginning/end of line |
| Enter | Insert newline (splits line at cursor) |
| Backspace | Delete character before cursor; joins lines at boundary |
| Ctrl+D | Save and exit (returns 0) |
| Esc | Cancel and exit (returns 1) |
| Ctrl+E | Edit current line with full readline (word movement, history) |
| Ctrl+W | Delete word backward |
| Ctrl+U | Clear current line |
| Ctrl+V | Paste from system clipboard (xclip or pbpaste) |
| Tab | Insert 2 spaces |

#### Configurable Keybindings

All control keys can be overridden via environment variables using semantic token names
(use `_input:capture-key` to discover tokens):

| Variable | Default Token | Description |
|----------|---------------|-------------|
| `ML_KEY_SAVE` | `ctrl-d` | Save and exit |
| `ML_KEY_EDIT` | `ctrl-e` | Enter readline editing mode |
| `ML_KEY_PASTE` | `ctrl-v` | Paste from clipboard |
| `ML_KEY_DEL_WORD` | `ctrl-w` | Delete word backward |
| `ML_KEY_DEL_LINE` | `ctrl-u` | Clear current line |

#### Architecture

The editor separates **pure state logic** from **terminal I/O** for testability. All editing operations are implemented as internal `_input:ml:*` functions that manipulate shared state arrays (`__ML_LINES[]`, `__ML_ROW`, `__ML_COL`, `__ML_SCROLL`). These functions are fully unit-testable with ShellSpec (55 tests).

The rendering and input loop (`_input:ml:render`, `input:multi-line`) form a thin I/O wrapper around the state logic.

**Terminal modes managed by the editor:**
- **Bracketed paste** (`\033[?2004h`): Enabled on entry, disabled on exit. When the terminal sends `ESC[200~`...`ESC[201~` around pasted text, `_input:read-key` returns a `paste:payload` token containing the pasted content, which is inserted directly into the buffer.
- **Line-wrap** (`\033[?7l`/`\033[?7h`): Disabled during each render pass to prevent visual glitches when drawing full-width lines, then re-enabled after rendering completes.

**Stream mode helpers** (`_input:ml:stream:*`): Four functions handle cursor detection, height normalization, terminal scrolling when at the bottom, and cursor restoration on exit.

#### Status Bar

The editor includes a status bar (top row) showing:
- Help hints: `Ctrl+D save | Esc cancel | Ctrl+E edit line`
- Cursor position: `L{row}:C{col}`
- Modified indicator: `[+]` when buffer has been changed
- Total line count

Disable with `--no-status` flag.

#### Clipboard Support

Paste (Ctrl+V) auto-detects the available clipboard command:
- **Linux**: `xclip -o -selection clipboard`
- **macOS**: `pbpaste`

Multi-line clipboard content is properly split and inserted across multiple lines.

### input:readpwd - Password Input

Single-line password input with character masking (asterisks) and line editing support.

```bash
source "$E_BASH/_commons.sh"

echo -n "Enter password: "
password=$(input:readpwd) && echo ""
echo "Password: $password"
```

Supports: left/right arrow keys, Home/End, backspace, Esc (reset), Ctrl+U (clear).

### input:selector - Menu Selector

Horizontal menu selector from an associative array with arrow key navigation and character search.

```bash
source "$E_BASH/_commons.sh"

declare -A -g connections=(["d"]="production" ["s"]="staging" ["p"]="local")
echo -n "Select: " && tput civis
selected=$(input:selector "connections") && echo "${cl_blue}${selected}${cl_reset}"
```

Supports: left/right arrow keys, Enter (select), Esc (reset), character search.

## Reference

### Safety Features

All functions include robust safety mechanisms:

- **Infinite Loop Protection**: Maximum 1000 iterations
- **Filesystem Root Detection**: Stops at `/` boundary
- **Symlink Resolution**: Resolves symbolic links to real paths
- **Directory Comparison**: Detects when `dirname` returns same path
- **Path Validation**: Checks directory existence before processing

### Cross-Platform Compatibility

- **Pure Bash**: No external dependencies beyond coreutils
- **macOS Compatible**: Works with BSD and GNU tools
- **WSL2 Tested**: Verified on Windows Subsystem for Linux
- **CI/CD Ready**: Dynamic path detection for portable tests

```bash
# Works across platforms without modification
root=$(git:root)                    # ✓ Linux, macOS, WSL2
configs=$(config:hierarchy ".rc")   # ✓ All platforms
```
