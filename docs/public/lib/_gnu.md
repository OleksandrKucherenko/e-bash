# _gnu.sh

**_gnu**

-----------------------------------------------------------------------------
Purpose:
GNU tools compatibility layer for macOS/Linux cross-platform development.
This script creates symbolic links in bin/gnubin/ to provide g-prefixed
GNU tools (ggrep, gsed, gawk, etc.) on Linux, matching macOS GNU coreutils
naming conventions.

## References

- docs/public/installation.md: Installation and setup documentation
- bin/gnubin/: Directory containing GNU tool symlinks
- .scripts/_colors.sh: Module that uses gnubin tools for color detection
- All scripts requiring GNU text processing tools (grep, sed, awk)
Globals Introduced:
- BIN_DIR - Path to bin/gnubin directory (created if not exists)
Platform Behavior:
- Linux: Creates symlinks for ggrep, gsed, gawk, gfind, gmv, gcp, gln, greadlink, gdate
- macOS: Does nothing (GNU tools already available with 'g' prefix via coreutils)
- WSL: Same as Linux (creates symlinks)
Function Categories:
- Initialization: (none - script runs inline when sourced)
- Note: This is a configuration script, not a function library. It executes
  initialization code when sourced rather than providing reusable functions.

