#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# shellcheck disable=SC2155
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../.scripts && pwd)"

# Enable hooks logging to see context tracking (respects existing DEBUG value)
export DEBUG=${DEBUG:-"hooks"}

# shellcheck disable=SC1090 source=../.scripts/_hooks.sh
source "$E_BASH/_hooks.sh"

# shellcheck disable=SC1090 source=../.scripts/_colors.sh
source "$E_BASH/_colors.sh"

echo "${cl_cyan}═══════════════════════════════════════════════════════════${cl_reset}"
echo "${cl_cyan}  Hooks System - Nested/Composed Hooks Demo${cl_reset}"
echo "${cl_cyan}═══════════════════════════════════════════════════════════${cl_reset}"
echo

#
# Example 1: Creating a Library with Hooks
#
echo "${cl_green}Example 1: Library Script with Hooks${cl_reset}"
echo "Creating a temporary library that defines init and cleanup hooks..."
echo

# Create a temporary library file
cat > /tmp/demo_library.sh <<'EOF'
#!/usr/bin/env bash
# demo_library.sh - A reusable library that uses hooks

# Library sources the hooks system
source "$E_BASH/_hooks.sh"

# Library defines its own hooks
hooks:declare init cleanup process

# Library provides implementations
hook:init() {
  echo "  [Library] Initializing database connection"
  echo "  [Library] Loading configuration"
}

hook:cleanup() {
  echo "  [Library] Closing database connection"
  echo "  [Library] Cleaning up temp files"
}

hook:process() {
  echo "  [Library] Processing with library logic"
}

# Library exports a helper function
library:helper() {
  echo "  [Library] Helper function called"
}
EOF

# Source the library
echo "Sourcing library..."
source /tmp/demo_library.sh
echo

#
# Example 2: Main Script Defining Same Hooks
#
echo "${cl_green}Example 2: Main Script Defines Same Hooks (Nested)${cl_reset}"
echo "Main script also defines init, cleanup, and process hooks..."
echo

# Main script defines the same hooks - this will trigger warnings
hooks:declare init cleanup process

# Main script provides its own implementations
hook:init() {
  echo "  [Main] Starting application"
  echo "  [Main] Validating environment"
}

hook:cleanup() {
  echo "  [Main] Shutting down gracefully"
  echo "  [Main] Saving state"
}

hook:process() {
  echo "  [Main] Processing with main logic"
}

echo

#
# Example 3: Executing Nested Hooks
#
echo "${cl_green}Example 3: Executing Hooks (Both Implementations Run)${cl_reset}"
echo

echo "${cl_yellow}→ Executing init hook:${cl_reset}"
hooks:do init
echo

echo "${cl_yellow}→ Executing process hook:${cl_reset}"
hooks:do process
echo

echo "${cl_yellow}→ Executing cleanup hook:${cl_reset}"
hooks:do cleanup
echo

#
# Example 4: Listing Hooks Shows Context Information
#
echo "${cl_green}Example 4: Listing Hooks (Shows Multiple Contexts)${cl_reset}"
echo
hooks:list
echo

#
# Example 5: Three-Level Nesting
#
echo "${cl_green}Example 5: Three-Level Nesting${cl_reset}"
echo "Creating another helper that also defines 'init' hook..."
echo

# Create second library
cat > /tmp/demo_helper.sh <<'EOF'
#!/usr/bin/env bash
source "$E_BASH/_hooks.sh"
hooks:declare init

hook:init() {
  echo "  [Helper] Helper initialization"
}
EOF

# Source the second library - creates third context
source /tmp/demo_helper.sh
echo

echo "${cl_yellow}→ Now executing init with THREE contexts:${cl_reset}"
hooks:do init
echo

echo "${cl_yellow}→ Listing hooks shows 3 contexts:${cl_reset}"
hooks:list
echo

#
# Example 6: Intentional Design Pattern
#
echo "${cl_green}Example 6: Why This Is Useful${cl_reset}"
echo
echo "This feature enables powerful composition patterns:"
echo "  • Libraries can define lifecycle hooks (init, cleanup, etc.)"
echo "  • Main scripts can also define the same hooks"
echo "  • All implementations execute in order"
echo "  • Enables proper initialization/cleanup cascading"
echo "  • Each component manages its own resources"
echo
echo "Example scenario:"
echo "  1. Library initializes database connection (hook:init)"
echo "  2. Main script initializes application state (hook:init)"
echo "  3. hooks:do init runs BOTH in sequence"
echo "  4. Both components are properly initialized!"
echo

#
# Example 7: Same Context Re-definition (No Warning)
#
echo "${cl_green}Example 7: Re-defining Hook in Same Context${cl_reset}"
echo "If the same context defines a hook twice, no warning is shown..."
echo

hooks:declare test_hook
hooks:declare test_hook  # Same context, no warning

echo

#
# Cleanup
#
echo "${cl_cyan}═══════════════════════════════════════════════════════════${cl_reset}"
echo "Cleaning up temporary files..."
rm -f /tmp/demo_library.sh /tmp/demo_helper.sh
echo "${cl_green}Demo complete!${cl_reset}"
