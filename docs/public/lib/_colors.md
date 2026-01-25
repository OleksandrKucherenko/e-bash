# _colors.sh

**Terminal Color and Style Definitions**

This module provides ANSI color and style variables for terminal output.
All variables use tput for terminal capability detection.

## References

- demo: demo.colors.sh
- bin: git.graph.sh, git.log.sh, git.semantic-version.sh, ipv6.sh,
  npm.versions.sh, tree.sh, vhd.sh
- documentation: colors are referenced throughout docs/public/*.md

## Module Globals

- TERM - Terminal type (set to xterm-256color if empty)
- cl_reset - Reset all attributes (\e[0m)
- cl_red, cl_green, cl_yellow, cl_blue, cl_purple, cl_cyan, cl_white,
  cl_grey, cl_gray - Standard colors (0-7)
- cl_lred, cl_lgreen, cl_lyellow, cl_lblue, cl_lpurple, cl_lcyan,
  cl_lwhite, cl_black - Light/bright colors (8-16)
- cl_selected - Selected background (blue highlight)
- st_bold, st_b - Bold text
- st_no_b - Reset bold
- st_italic, st_i - Italic text
- st_no_i - Reset italic
- st_underline, st_u - Underline
- st_no_u - Reset underline

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

