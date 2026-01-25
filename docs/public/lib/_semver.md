# _semver.sh

**Semantic Versioning (SemVer) Parser and Comparator**

This module provides semantic versioning (SemVer 2.0.0) support including
parsing, comparison, constraint checking, and version sorting.

## References

- demo: demo.semver.sh, demo.sorting.sh, demo.sorting.v2.sh
- bin: git.semantic-version.sh, version-up.v2.sh, install.e-bash.sh
- documentation: Referenced in docs/public/version-up.md
- tests: spec/semver_spec.sh

## Index

* [`semver:compare`](#semver-compare)
* [`semver:compare:readable`](#semver-compare-readable)
* [`semver:compare:to:operator`](#semver-compare-to-operator)
* [`semver:constraints`](#semver-constraints)
* [`semver:constraints:complex`](#semver-constraints-complex)
* [`semver:constraints:simple`](#semver-constraints-simple)
* [`semver:constraints:v1`](#semver-constraints-v1)
* [`semver:constraints:v2`](#semver-constraints-v2)
* [`semver:grep`](#semver-grep)
* [`semver:increase:major`](#semver-increase-major)
* [`semver:increase:minor`](#semver-increase-minor)
* [`semver:increase:patch`](#semver-increase-patch)
* [`semver:parse`](#semver-parse)
* [`semver:recompose`](#semver-recompose)

---

## Functions

---

### semver:compare

Compare two semantic versions

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `version1` | string | required | First version string |
| `version2` | string | required | Second version string |

#### Globals

- reads/listen: __semver_compare_v1, __semver_compare_v2
- mutate/publish: creates temporary associative arrays for comparison

#### Returns

- 0 if versions are equal
- 1 if version1 > version2
- 2 if version1 < version2
- 3 if error (invalid version)

#### Usage

```bash
semver:compare "1.2.3" "1.2.4"  # Returns 2
semver:compare "2.0.0" "1.9.9"  # Returns 1
Implementation of https://semver.org/#spec-item-11 specs
```

---

### semver:compare:readable

Generate human-readable version comparison output

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `version1` | string | required | First version string |
| `version2` | string | required | Second version string |

#### Globals

- reads/listen: none
- mutate/publish: none

#### Returns

- Echoes formatted string: "version1 operators version2"

#### Usage

```bash
semver:compare:readable "1.2.3" "1.2.4"  # Returns "1.2.3 < <= != 1.2.4"
```

---

### semver:compare:to:operator

Convert semver:compare result code to operator string

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `result` | 1 | 2, 3), number, required | Result code from semver:compare (0 |

#### Globals

- reads/listen: none
- mutate/publish: none

#### Returns

- Echoes operator string: "==", ">", "<", or "error"

#### Usage

```bash
semver:compare "1.2.3" "1.2.3"
operator=$(semver:compare:to:operator "$?")  # Returns "=="
```

---

### semver:constraints

Main entry point for semantic version constraint checking

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `version` | string | required | Version string to check |
| `expression` | string | required | Constraint expression |

#### Globals

- reads/listen: SEMVER_CONSTRAINTS_IMPL (v1 or v2, default: v2)
- mutate/publish: none

#### Returns

- 0 if version satisfies constraints
- 1 if version does not satisfy constraints

#### Usage

```bash
semver:constraints "1.2.3" ">=1.0.0 <2.0.0"
SEMVER_CONSTRAINTS_IMPL=v1 semver:constraints "1.2.3" "^1.0.0"
```

---

### semver:constraints:complex

Expand tilde (~) and caret (^) constraint operators to simple expressions

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `molecule` | string | required | Constraint expression with ~ or ^ operators |

#### Globals

- reads/listen: none
- mutate/publish: creates temporary __semver_constraints_complex_atom array

#### Returns

- 0 on success, 1 on parse error
- Echoes one or two constraint expressions

#### Usage

```bash
semver:constraints:complex "~1.2.3"  # Returns ">=1.2.3" and "<1.3.0"
semver:constraints:complex "^1.0.0"  # Returns ">=1.0.0" and "<2.0.0"
```

---

### semver:constraints:simple

Simple semantic version constraint check

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `expression` | "1.2.3>=1.0.0") | string, required | Constraint expression (e.g. |

#### Globals

- reads/listen: none
- mutate/publish: none

#### Returns

- 0 if constraint satisfied
- 1 if constraint not satisfied
- 3 if expression invalid

#### Usage

```bash
semver:constraints:simple "1.2.3>=1.0.0"  # Returns 0
The basic comparisons are:
=: equal (aliased to no operator)
!=: not equal
>: greater than
<: less than
>=: greater than or equal to
<=: less than or equal to
ref: https://github.com/Masterminds/semver?tab=readme-ov-file#basic-comparisons
```

---

### semver:constraints:v1

Verify version matches constraints (v1 - legacy behavior)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `version` | string | required | Version string to check |
| `expression` | string | required | Constraint expression |

#### Globals

- reads/listen: none
- mutate/publish: none

#### Returns

- 0 if version satisfies constraints
- 1 if version does not satisfy constraints

#### Usage

```bash
semver:constraints:v1 "1.2.3" ">=1.0.0"
```

---

### semver:constraints:v2

Verify version matches constraints (v2 - npm-like with prerelease handling)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `version` | string | required | Version string to check |
| `expression` | string | required | Constraint expression |

#### Globals

- reads/listen: none
- mutate/publish: creates temporary __semver_constraints_v2_* arrays

#### Returns

- 0 if version satisfies constraints
- 1 if version does not satisfy constraints

#### Usage

```bash
semver:constraints:v2 "1.2.3-alpha" ">=1.0.0"
```

---

### semver:grep

Generate semantic versioning regex pattern

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- reads/listen: none
- mutate/publish: none

#### Returns

- Echoes extended regex pattern for semver matching

#### Usage

```bash
pattern=$(semver:grep)
ref: https://regex101.com/r/vkijKf/1/,
^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$
\d - any digit
ref: https://semver.org/#backusnaur-form-grammar-for-valid-semver-versions
```

---

### semver:increase:major

Increment major version number (resets minor and patch to 0)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `version` | string | required | Version string to increment |

#### Globals

- reads/listen: none
- mutate/publish: creates temporary __major associative array

#### Returns

- Echoes incremented version (major+1.0.0)

#### Usage

```bash
# shellcheck disable=SC2154
Increment major version number (resets minor and patch to 0)
```

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `version` | string | required | Version string to increment |

#### Globals

- reads/listen: none
- mutate/publish: creates temporary __major associative array

#### Returns

- Echoes incremented version (major+1.0.0)

#### Usage

```bash
semver:increase:major "1.2.3"  # Returns "2.0.0"
```

---

### semver:increase:minor

Increment minor version number (resets patch to 0)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `version` | string | required | Version string to increment |

#### Globals

- reads/listen: none
- mutate/publish: creates temporary __minor associative array

#### Returns

- Echoes incremented version (major.minor+1.0)
# shellcheck disable=SC2154
Increment minor version number (resets patch to 0)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `version` | string | required | Version string to increment |

#### Globals

- reads/listen: none
- mutate/publish: creates temporary __minor associative array

#### Returns

- Echoes incremented version (major.minor+1.0)

#### Usage

```bash
semver:increase:minor "1.2.3"  # Returns "1.3.0"
```

---

### semver:increase:patch

Increment patch version number

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `version` | string | required | Version string to increment |

#### Globals

- reads/listen: none
- mutate/publish: creates temporary __patch associative array

#### Returns

- Echoes incremented version (major.minor.patch+1)
# shellcheck disable=SC2154
Increment patch version number

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `version` | string | required | Version string to increment |

#### Globals

- reads/listen: none
- mutate/publish: creates temporary __patch associative array

#### Returns

- Echoes incremented version (major.minor.patch+1)

#### Usage

```bash
semver:increase:patch "1.2.3"  # Returns "1.2.4"
```

---

### semver:parse

Parse semantic version string into components

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `version` | string | required | Version string to parse |
| `output_variable` | string | default: "__semver_parse_result" | Name of associative array to store results |

#### Globals

- reads/listen: SEMVER (regex pattern)
- mutate/publish: creates global associative array with components

#### Returns

- 0 if version matches semver pattern, 1 otherwise
- Populates output array with: version, version-core, major, minor, patch, pre-release, build

#### Usage

```bash
semver:parse "1.2.3-alpha+build" "result"
```

---

### semver:recompose

Create version string from parsed semver components

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `sourceVariableName` | string | default: "__semver_parse_result" | Name of associative array with parsed parts |

#### Globals

- reads/listen: associative array with semver components
- mutate/publish: none

#### Returns

- Echoes formatted version string (major.minor.patch-pre-release+build)

#### Usage

```bash
semver:parse "1.2.3-alpha" "parsed"
version=$(semver:recompose "parsed")
```

