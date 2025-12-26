# e-bash Commons Utilities Documentation

<!-- TOC -->

- [e-bash Commons Utilities Documentation](#e-bash-commons-utilities-documentation)
  - [Quick Start Guide](#quick-start-guide)
    - [Git Repository Root Detection](#git-repository-root-detection)
    - [Configuration File Hierarchy](#configuration-file-hierarchy)
    - [XDG-Compliant Configuration Discovery](#xdg-compliant-configuration-discovery)
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
  - [Use Cases and Patterns](#use-cases-and-patterns)
    - [Monorepo Project Root Detection](#monorepo-project-root-detection)
    - [Multi-Environment Configuration Loading](#multi-environment-configuration-loading)
    - [User-Specific Config Overrides](#user-specific-config-overrides)
    - [Configuration Merging Strategy](#configuration-merging-strategy)
  - [Best Practices](#best-practices)
    - [Error Handling](#error-handling)
    - [Configuration File Precedence](#configuration-file-precedence)
    - [Security Considerations](#security-considerations)
  - [Reference](#reference)
    - [Safety Features](#safety-features-1)
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
