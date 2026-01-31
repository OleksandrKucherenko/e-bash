# _gnu.sh

**_gnu**

GNU tools compatibility layer for macOS/Linux cross-platform development.
This script creates symbolic links in bin/gnubin/ to provide g-prefixed
GNU tools (ggrep, gsed, gawk, etc.) on Linux, matching macOS GNU coreutils
naming conventions.

## References

- docs/public/installation.md: Installation and setup documentation
- bin/gnubin/: Directory containing GNU tool symlinks
- .scripts/_colors.sh: Module that uses gnubin tools for color detection
- All scripts requiring GNU text processing tools (grep, sed, awk)

## Module Globals

- BIN_DIR - Path to bin/gnubin directory (created if not exists)

## Additional Information

### Platform Behavior

- Linux: Creates symlinks for ggrep, gsed, gawk, gfind, gmv, gcp, gln, greadlink, gdate
- macOS: Does nothing (GNU tools already available with 'g' prefix via coreutils)
- WSL: Same as Linux (creates symlinks)


---

## Functions

<!-- TOC -->

- [_gnu.sh](#_gnush)

<!-- /TOC -->

