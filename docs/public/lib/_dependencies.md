# _dependencies.sh

**Dependency Management with Version Constraints**

This module provides dependency checking with semantic versioning constraints
and optional auto-installation in CI environments.

## References

- demo: demo.dependencies.sh, demo.cache.sh
- bin: git.sync-by-patches.sh, version-up.v2.sh, vhd.sh,
  ci.validate-envrc.sh, npm.versions.sh, un-link.sh
- documentation: Referenced in docs/public/installation.md
- tests: spec/dependencies_spec.sh

## Module Globals

- E_BASH - Path to .scripts directory
- __DEPS_VERSION_FLAGS_EXCEPTIONS - Associative array of tools with non-standard version flags
- CI - Set by CI environments (GitHub Actions, GitLab CI, etc.)
- CI_E_BASH_INSTALL_DEPENDENCIES - Enable auto-install in CI (1/true/yes)
- SKIP_DEALIAS - Bypass alias resolution when set to "1"

## Additional Information

### Supported Version Patterns

- "5.*.*" - Any 5.x.x version
- "^1.0.0" - 1.0.0 or higher (compatible)
- "~1.2.3" - 1.2.x versions (patch-level updates)
- "HEAD-[a-f0-9]{1,8}" - Git commit hash pattern
- ">1.0.0" - Greater than 1.0.0
Tool Aliases (auto-resolved):
- rust/rustc -> rustc
- golang/go -> go
- nodejs/node -> node
- jre/java -> java
- homebrew/brew -> brew
ref:
 https://docs.gradle.org/current/userguide/single_versions.html
 https://github.com/qzb/sh-semver
 https://stackoverflow.com/questions/4023830/how-to-compare-two-strings-in-dot-separated-version-format-in-bash


## Index

* [`dependency`](#dependency)
* [`dependency:dealias`](#dependency-dealias)
* [`dependency:known:flags`](#dependency-known-flags)
* [`isCIAutoInstallEnabled`](#isciautoinstallenabled)
* [`isDebug`](#isdebug)
* [`isExec`](#isexec)
* [`isOptional`](#isoptional)
* [`isSilent`](#issilent)
* [`optional`](#optional)

---

## Functions

---

### dependency

Check and optionally install a dependency with version constraint

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `tool_name` | string | required | Tool to check |
| `tool_version_pattern` | string | required | Semver pattern (e.g. "5.*.*", "HEAD-[a-f0-9]{1,8}") |
| `tool_fallback` | string | default: "No details. Please google it." | Install command |
| `tool_version_flag` | string | default: auto-detected | Custom version flag |
| `--optional` | string | required | Mark as optional dependency (soft fail) |
| `--exec` | string | required | Execute install command on version mismatch |
| `--debug` | string | required | Enable debug output |

#### Globals

- reads/listen: CI, CI_E_BASH_INSTALL_DEPENDENCIES, SKIP_DEALIAS
- mutate/publish: none (may execute install command)

#### Side Effects

- May execute install command in CI or with --exec

#### Returns

- 0 if dependency found/installed, 1 otherwise

#### Usage

```bash
dependency bash "5.*.*" "brew install bash"
dependency shellspec "0.28.*" "brew install shellspec" "--version"
optional kcov "43" "brew install kcov"
```

---

### dependency:dealias

Resolve tool aliases to their canonical command names

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `alias_name` | string | required | Tool alias to resolve |

#### Globals

- reads/listen: SKIP_DEALIAS
- mutate/publish: none

#### Returns

- Canonical command name

#### Usage

```bash
dependency:dealias "rust" -> "rustc"
dependency:dealias "brew" -> "brew"
SKIP_DEALIAS=1 dependency:dealias "rust" -> "rust"
```

---

### dependency:known:flags

Get the version flag for a tool (exception or default --version)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `tool` | string | required | Tool name |
| `provided_flag` | string | optional | User-provided flag override |

#### Globals

- reads/listen: __DEPS_VERSION_FLAGS_EXCEPTIONS
- mutate/publish: none

#### Returns

- Version flag (e.g. "--version", "-V", "-version")

#### Usage

```bash
dependency:known:flags "java" -> "-version"
dependency:known:flags "git" -> "--version"
```

---

### isCIAutoInstallEnabled

Check if CI auto-install mode is enabled

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- reads/listen: CI, CI_E_BASH_INSTALL_DEPENDENCIES
- mutate/publish: none

#### Returns

- "true" if in CI and auto-install enabled, "false" otherwise

#### Usage

```bash
if [ "$(isCIAutoInstallEnabled)" = "true" ]; then ...; fi
```

---

### isDebug

Check if --debug flag is present in arguments

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `args` | string array | variadic | Arguments to check |

#### Globals

- reads/listen: none
- mutate/publish: none

#### Returns

- "true" if --debug present, "false" otherwise

---

### isExec

Check if --exec flag is present in arguments

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `args` | string array | variadic | Arguments to check |

#### Globals

- reads/listen: none
- mutate/publish: none

#### Returns

- "true" if --exec present, "false" otherwise

---

### isOptional

Check if --optional flag is present in arguments

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `args` | string array | variadic | Arguments to check |

#### Globals

- reads/listen: none
- mutate/publish: none

#### Returns

- "true" if --optional present, "false" otherwise

---

### isSilent

Check if --silent flag is present in arguments

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `args` | string array | variadic | Arguments to check |

#### Globals

- reads/listen: none
- mutate/publish: none

#### Returns

- "true" if --silent present, "false" otherwise

---

### optional

Declare an optional dependency (wrapper for dependency with --optional flag)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `tool_name` | string | required | Tool to check |
| `tool_version_pattern` | string | required | Semver pattern |
| `tool_fallback` | string | default: "No details. Please google it." | Install command |
| `tool_version_flag` | string | default: "--version" | Custom version flag |

#### Globals

- reads/listen: none
- mutate/publish: none (forwards to dependency)

#### Returns

- 0 (always succeeds for optional deps)

#### Usage

```bash
optional kcov "43" "brew install kcov"
optional hyperfine "" "brew install hyperfine"
```

