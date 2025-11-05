# CI Auto-Install Mode for e-bash Dependencies

## Overview

The e-bash dependency script now supports automatic installation of tools in CI environments through the `CI_E_BASH_INSTALL_DEPENDENCIES` environment variable.

## Usage

### Enable CI Auto-Install Mode

Set the environment variable to one of these values:
- `CI_E_BASH_INSTALL_DEPENDENCIES=1`
- `CI_E_BASH_INSTALL_DEPENDENCIES=true`
- `CI_E_BASH_INSTALL_DEPENDENCIES=yes`

### Example Usage in CI

```bash
# In your CI script or Dockerfile
export CI_E_BASH_INSTALL_DEPENDENCIES=1

# Source the dependencies script (as in .envrc)
source .scripts/_dependencies.sh

# Dependencies will now be automatically installed
dependency bash "5.*.*" "brew install bash"
dependency git "2.*.*" "brew install git"
optional shellcheck "0.10.*" "curl -sS https://webi.sh/shellcheck | sh"
```

### Docker Example

```dockerfile
FROM ubuntu:latest

# Install basic tools
RUN apt-get update && apt-get install -y curl bash

# Enable CI auto-install mode
ENV CI_E_BASH_INSTALL_DEPENDENCIES=1

# Copy your project
COPY . /workspace
WORKDIR /workspace

# Dependencies will be automatically installed when sourced
RUN source .scripts/_dependencies.sh
```

## Behavior

### When CI Mode is Enabled

1. **Missing Tools**: Automatically executes the installation command
2. **Wrong Versions**: Automatically executes the upgrade command
3. **Optional Dependencies**: Also auto-installed if missing or wrong version
4. **Success**: Returns success status after installation

### When CI Mode is Disabled (Default)

1. **Missing Tools**: Shows error message with installation hint
2. **Wrong Versions**: Shows error message or executes if `--exec` flag is used
3. **Optional Dependencies**: Shows warning but continues
4. **Failure**: Returns failure status for missing/wrong required dependencies

## Integration with Existing .envrc

The existing `.envrc` file works unchanged. Simply set the environment variable before sourcing:

```bash
# Enable CI mode
export CI_E_BASH_INSTALL_DEPENDENCIES=1

# Source dependencies (existing .envrc content)
source "$PWD/.scripts/_dependencies.sh"

# All dependency calls will now auto-install
dependency bash "5.*.*" "brew install bash"
dependency direnv "2.*.*" "curl -sfL https://direnv.net/install.sh | bash"
# ... etc
```

## Testing

The implementation includes comprehensive tests covering:
- All supported environment variable values (1, true, yes)
- Invalid values (should not auto-install)
- Missing tools auto-installation
- Wrong version auto-upgrade
- Optional dependencies support
- Backward compatibility (default behavior unchanged)

Run tests with:
```bash
shellspec --no-kcov spec/dependencies_spec.sh
```

## Implementation Details

- New function: `isCIAutoInstallEnabled()` - checks environment variable
- Modified: `dependency()` function - adds CI auto-install logic
- Modified: `optional()` function - inherits CI auto-install behavior
- Backward compatible: existing behavior preserved when CI mode disabled
- Test coverage: 26 test cases including new CI functionality