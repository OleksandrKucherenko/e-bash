# _colors.sh

**Terminal Color and Style Definitions**

This module provides ANSI color and style variables for terminal output.
All variables use tput for terminal capability detection.

## References

- demo: demo.colors.sh
- bin: git.graph.sh, git.log.sh, git.semantic-version.sh, ipv6.sh,
  npm.versions.sh, tree.sh, vhd.sh
- documentation: colors are referenced throughout docs/public/*.md

## Index

* [`cl:unset`](#cl-unset)

---

## Functions

---

### cl:unset

Unset all color and style variables to disable colored output

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- reads/listen: none
- mutate/publish: unsets all cl_*, st_* variables

#### Side Effects

- Removes all color and style variables from environment

#### Usage

```bash
cl:unset    # disable all colors
echo "plain text"
```

