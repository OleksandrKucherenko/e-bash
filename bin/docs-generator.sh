#!/usr/bin/env bash
# shellcheck disable=SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-24
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# Function Documentation Generator
# Parses function documentation comments from e-bash library scripts
# and generates markdown/HTML documentation pages

# Documentation Format:
# # Function: function_name
# #
# # Description:
# #   Brief description of what the function does
# #
# # Arguments:
# #   $1 - name (type) - Description
# #   $2 - name (type, optional) - Description
# #
# # Returns:
# #   Exit code or stdout description
# #
# # Side Effects:
# #   - List of side effects (global variables, files created, etc.)
# #
# # Example:
# #   function_name "arg1" "arg2"
# #   result=$(function_name "arg1")
# #
# function function_name() { ... }

set -eo pipefail

# Discover E_BASH if not set
if [ -z "${E_BASH:-}" ]; then
  readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.scripts" && pwd)"
fi

# shellcheck disable=SC1090 source=../.scripts/_colors.sh
source "$E_BASH/_colors.sh"

# Configuration
OUTPUT_DIR="${1:-docs/functions}"
SCRIPTS_DIR="${E_BASH}"

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Function: parse_function_doc
#
# Description:
#   Extracts documentation comments from a function definition
#
# Arguments:
#   $1 - file_path - Path to the script file
#   $2 - function_name - Name of the function to document
#
# Returns:
#   Outputs structured markdown for the function
#
function parse_function_doc() {
  local file_path="$1"
  local func_name="$2"
  local in_doc=false
  local doc_lines=()

  # Find the function and its documentation
  while IFS= read -r line; do
    # Check if we found the function marker
    if [[ "$line" =~ ^#[[:space:]]*Function:[[:space:]]*(.+)$ ]]; then
      local marker_func="${BASH_REMATCH[1]}"
      if [[ "$marker_func" == "$func_name" ]]; then
        in_doc=true
        continue
      fi
    fi

    # Collect documentation lines
    if [ "$in_doc" = true ]; then
      if [[ "$line" =~ ^#[[:space:]]?(.*)$ ]]; then
        doc_lines+=("${BASH_REMATCH[1]}")
      elif [[ "$line" =~ ^function[[:space:]]+$func_name ]]; then
        # End of documentation
        break
      fi
    fi
  done < "$file_path"

  # Output markdown
  if [ ${#doc_lines[@]} -gt 0 ]; then
    for line in "${doc_lines[@]}"; do
      echo "$line"
    done
  fi
}

# Function: extract_functions
#
# Description:
#   Extracts all function names from a script file
#
# Arguments:
#   $1 - file_path - Path to the script file
#
# Returns:
#   List of function names, one per line
#
function extract_functions() {
  local file_path="$1"
  grep -E '^function [a-zA-Z0-9_:]+\(\)' "$file_path" | \
    sed -E 's/^function ([a-zA-Z0-9_:]+)\(\).*/\1/' || true
}

# Function: generate_module_doc
#
# Description:
#   Generates documentation for a single module file
#
# Arguments:
#   $1 - script_file - Path to the script file
#
# Returns:
#   Creates a markdown file in OUTPUT_DIR
#
function generate_module_doc() {
  local script_file="$1"
  local module_name=$(basename "$script_file" .sh)
  local output_file="$OUTPUT_DIR/${module_name}.md"

  echo "${cl_cyan}Generating documentation for: ${cl_white}${module_name}${cl_reset}"

  # Extract module header info
  local version=$(grep -E '^## Version:' "$script_file" | sed 's/## Version: //' || echo "unknown")
  local description=$(grep -E '^## Description:' "$script_file" | sed 's/## Description: //' || echo "")

  # Start markdown file
  cat > "$output_file" <<EOF
# ${module_name}

**Version:** ${version}

${description}

## Functions

EOF

  # Extract all functions
  local functions=($(extract_functions "$script_file"))

  if [ ${#functions[@]} -eq 0 ]; then
    echo "  ${cl_yellow}No functions found${cl_reset}"
    echo "No documented functions found." >> "$output_file"
    return
  fi

  echo "  Found ${cl_green}${#functions[@]}${cl_reset} functions"

  # Process each function
  for func in "${functions[@]}"; do
    echo "    - $func"

    # Check if function has documentation marker
    if grep -q "^# Function: $func\$" "$script_file"; then
      {
        echo ""
        echo "### \`$func\`"
        echo ""
        parse_function_doc "$script_file" "$func"
        echo ""
      } >> "$output_file"
    else
      {
        echo ""
        echo "### \`$func\`"
        echo ""
        echo "⚠️ _Documentation pending_"
        echo ""
      } >> "$output_file"
    fi
  done

  echo "  ${cl_green}✓${cl_reset} Generated: $output_file"
}

# Function: generate_index
#
# Description:
#   Generates an index page for all modules
#
# Returns:
#   Creates index.md in OUTPUT_DIR
#
function generate_index() {
  local index_file="$OUTPUT_DIR/index.md"

  cat > "$index_file" <<'EOF'
# e-bash Function Reference

Complete API reference for all e-bash library functions.

## Modules

EOF

  # List all module documentation files
  for doc_file in "$OUTPUT_DIR"/_*.md; do
    if [ -f "$doc_file" ]; then
      local module=$(basename "$doc_file" .md)
      echo "- [$module]($module.md)" >> "$index_file"
    fi
  done

  echo ""
  echo "${cl_green}✓ Generated index: $index_file${cl_reset}"
}

# Main execution
main() {
  echo ""
  echo "${cl_lblue}${st_b}=== e-bash Documentation Generator ===${st_no_b}${cl_reset}"
  echo ""
  echo "Scripts dir: ${cl_white}$SCRIPTS_DIR${cl_reset}"
  echo "Output dir:  ${cl_white}$OUTPUT_DIR${cl_reset}"
  echo ""

  # Process each script file in .scripts/
  for script_file in "$SCRIPTS_DIR"/_*.sh; do
    if [ -f "$script_file" ]; then
      generate_module_doc "$script_file"
    fi
  done

  echo ""
  generate_index
  echo ""
  echo "${cl_green}${st_b}Documentation generation complete!${st_no_b}${cl_reset}"
  echo ""
}

main "$@"
