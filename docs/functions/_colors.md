# _colors

**Version:** 2.0.0

Terminal color definitions and utilities for ANSI color support

## Functions


### `cl:unset`


Description:
  Unsets all color and style variables exported by this module.
  Use this to prevent colored output in contexts where ANSI codes are not desired.

Arguments:
  None

Returns:
  None (void function)

Side Effects:
  - Unsets all cl_* color variables (cl_red, cl_green, cl_blue, etc.)
  - Unsets all st_* style variables (st_bold, st_italic, st_underline, etc.)
  - Unsets cl_reset and cl_selected

Example:
  # Disable colors for log file output
  cl:unset
  echo "This output has no colors" > output.log


