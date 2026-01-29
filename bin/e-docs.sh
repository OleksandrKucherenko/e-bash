#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-29
## Version: 2.3.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# e-docs: Documentation generator for e-bash scripts
# Uses ctags for function detection and bash for doc parsing

# -----------------------------------------------------------------------------
# Bootstrap e-bash (discover E_BASH location)
# -----------------------------------------------------------------------------
# Get script directory and find e-bash .scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
E_BASH="$(cd "$PROJECT_ROOT/.scripts" 2>&- && pwd)"
readonly E_BASH

# shellcheck disable=SC1091 source=../.scripts/_gnu.sh
. "$E_BASH/_gnu.sh"
PATH="$(cd "$E_BASH/../bin/gnubin" 2>&- && pwd):$PATH"

# Enable strict mode after bootstrap (set -e causes issues with logger module sourcing)
set -o pipefail

# -----------------------------------------------------------------------------
# Load e-bash modules
# -----------------------------------------------------------------------------
# Tag-based logging (must be before _dependencies.sh)
DEBUG=${DEBUG:-"-edocs,ok,warn,error,parse,generate,ctags,validate,-loader"}

# Colors for output
# shellcheck disable=SC1091 source=../.scripts/_colors.sh
source "$E_BASH/_colors.sh"

# shellcheck disable=SC1091 source=../.scripts/_logger.sh
source "$E_BASH/_logger.sh"

# shellcheck disable=SC1091 source=../.scripts/_dependencies.sh
source "$E_BASH/_dependencies.sh"

# Skip automatic argument parsing - we'll use modern args:i pattern
export SKIP_ARGS_PARSING=1

# Source arguments module after SKIP_ARGS_PARSING is set
# shellcheck disable=SC1091 source=../.scripts/_arguments.sh
source "$E_BASH/_arguments.sh"

# Source traps module for cleanup handlers
# shellcheck disable=SC1091 source=../.scripts/_traps.sh
source "$E_BASH/_traps.sh"

# Source dry-run module for command wrapping (AFTER logger is initialized)
# shellcheck disable=SC1091 source=../.scripts/_dryrun.sh
source "$E_BASH/_dryrun.sh"

# Generate dry-run wrappers for commands we'll use
# This creates run:mkdir, dry:mkdir, rollback:mkdir, undo:mkdir
dryrun mkdir

# Domain-specific loggers
logger:init edocs "[${cl_blue}edocs${cl_reset}] " ">&2"
logger:init parse "[${cl_cyan}parse${cl_reset}] " ">&2"
logger:init generate "[${cl_purple}gen${cl_reset}] " ">&2"
logger:init ctags "[${cl_yellow}ctags${cl_reset}] " ">&2"
logger:init validate "[${cl_yellow}valid${cl_reset}] " ">&2"
logger:init warn "[${cl_yellow}Warning${cl_reset}] " ">&2"
logger:init ok "[${cl_green}OK${cl_reset}] " ">&2"
logger:init err "[${cl_red}ERROR${cl_reset}] " ">&2"

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

# Load user configuration
if [[ -f "$PROJECT_ROOT/.edocsrc" ]]; then
  # shellcheck disable=SC1091
  source "$PROJECT_ROOT/.edocsrc"
fi

# Defaults
EDOCS_OUTPUT_DIR="${EDOCS_OUTPUT_DIR:-docs/public/lib}"
EDOCS_SOURCE_DIRS="${EDOCS_SOURCE_DIRS:-.scripts}"
EDOCS_STYLE="${EDOCS_STYLE:-github}"
EDOCS_TOC="${EDOCS_TOC:-true}"
EDOCS_INCLUDE_PRIVATE="${EDOCS_INCLUDE_PRIVATE:-false}"
EDOCS_VALIDATE="${EDOCS_VALIDATE:-true}"

# Normalize EDOCS_OUTPUT_DIR to absolute path if relative
if [[ ! "$EDOCS_OUTPUT_DIR" =~ ^/ ]]; then
  EDOCS_OUTPUT_DIR="$PROJECT_ROOT/$EDOCS_OUTPUT_DIR"
fi

# Temporary directory for processing (cleaned up on exit)
readonly TEMP_DIR=$(mktemp -d -t e-docs.XXXXXX)
trap:on "rm -rf '$TEMP_DIR'" EXIT INT TERM

# -----------------------------------------------------------------------------
# Utility Functions
# -----------------------------------------------------------------------------

# Trim leading and trailing whitespace from a string
# Arguments: $1 = string to trim
# Output: trimmed string
trim() {
  local str="$1"
  str="${str#"${str%%[![:space:]]*}"}"
  str="${str%"${str##*[![:space:]]}"}"
  echo "$str"
}

# Show progress when processing multiple files
# Arguments: $1 = current index (1-based), $2 = total count, $3 = filename
show_progress() {
  local current=$1
  local total=$2
  local filename=$3

  # Calculate percentage
  local percent=$((current * 100 / total))
  local bar_width=20
  local filled=$((percent * bar_width / 100))
  local empty=$((bar_width - filled))

  # Build progress bar
  local bar=""
  for ((i = 0; i < filled; i++)); do bar+="█"; done
  for ((i = 0; i < empty; i++)); do bar+="░"; done

  # Print progress (overwrite previous line if not first)
  printf "\r${cl_blue}[%3d%%]${cl_reset} [%s] (%d/%d) %s" \
    "$percent" "$bar" "$current" "$total" "$(basename "$filename")"

  # Newline on last file
  # [[ $current -eq $total ]] && echo
  echo ""
}

# -----------------------------------------------------------------------------
# Validation Functions
# -----------------------------------------------------------------------------

# Validate documentation block format
# Arguments: $1 = script file, $2 = function name, $3 = function line, $4 = doc block
# Output: Warnings to stderr if issues found
validate_doc_block() {
  local script="$1"
  local func_name="$2"
  local func_line="$3"
  local doc_block="$4"
  local issues=()

  # Check if doc block is empty
  if [[ -z "$doc_block" ]]; then
    issues+=("missing documentation")
  else
    # Check for description (first non-empty line after ##)
    local has_description=false
    while IFS= read -r line; do
      local content="${line#*##}"
      content=$(trim "$content")
      if [[ -n "$content" && ! "$content" =~ ^(Parameters|Globals|Returns|Side|Usage|References|Categories|@\{): ]]; then
        has_description=true
        break
      fi
    done <<<"$doc_block"

    [[ "$has_description" != "true" ]] && issues+=("missing description")

    # Check for common typos in section names
    if echo "$doc_block" | grep -qiE '##[[:space:]]*(Paramters|Parmeters|Paramater):'; then
      issues+=("typo in 'Parameters' section name")
    fi
    if echo "$doc_block" | grep -qiE '##[[:space:]]*(Gloabls|Golobals):'; then
      issues+=("typo in 'Globals' section name")
    fi
    if echo "$doc_block" | grep -qiE '##[[:space:]]*(Retuns|Reutrns):'; then
      issues+=("typo in 'Returns' section name")
    fi
  fi

  # Report issues
  if [[ ${#issues[@]} -gt 0 ]]; then
    local issue_list
    issue_list=$(
      IFS=", "
      echo "${issues[*]}"
    )
    echo:Warn "$(basename "$script"):$func_line: $func_name() - $issue_list"
  fi
}

# Validate ctags version and installation
# Arguments: none
# Returns: 0 if ctags is available and meets version requirements, 1 otherwise
validate_ctags() {
  if ! command -v ctags >/dev/null 2>&1; then
    echo:Err "ctags is not installed"
    echo:Err "Install with: brew install universal-ctags"
    return 1
  fi

  local ctags_version
  ctags_version=$(ctags --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')

  if [[ ! "$ctags_version" =~ ^[6-9]\..* ]]; then
    echo:Err "ctags version $ctags_version does not meet requirement (>= 6.0.0)"
    return 1
  fi

  return 0
}

# Validate gawk version and installation
# Arguments: none
# Returns: 0 if gawk is available and meets version requirements, 1 otherwise
validate_gawk() {
  if ! command -v gawk >/dev/null 2>&1; then
    echo:Err "gawk is not installed"
    echo:Err "Install with: brew install gawk"
    return 1
  fi

  local gawk_version
  gawk_version=$(gawk --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')

  if [[ ! "$gawk_version" =~ ^[4-9]\..* ]]; then
    echo:Err "gawk version $gawk_version does not meet requirement (>= 4.0.0)"
    return 1
  fi

  return 0
}

# Validate script structure (6-zone format)
# Arguments: $1 = script file
# Output: Warnings to stderr if structure issues found
validate_structure() {
  local script="$1"
  local issues=()

  # Check for shebang
  local first_line
  first_line=$(head -1 "$script")
  if [[ ! "$first_line" =~ ^#! ]]; then
    issues+=("missing shebang")
  fi

  # Check for copyright header (Zone 1)
  if ! grep -q "## Copyright" "$script"; then
    issues+=("missing copyright header (Zone 1)")
  fi

  # Check for Module Summary at end (Zone 6)
  if ! grep -q "## Module:" "$script"; then
    issues+=("missing Module Summary at end of file (Zone 6)")
  fi

  # Check for sourced guard pattern
  if ! grep -q "__SOURCED__" "$script" && ! grep -q "BASH_SOURCE" "$script"; then
    issues+=("missing sourced guard pattern")
  fi

  # Report issues
  if [[ ${#issues[@]} -gt 0 ]]; then
    for issue in "${issues[@]}"; do
      echo:Warn "$(basename "$script"): $issue"
    done
  fi
}

# -----------------------------------------------------------------------------
# Dependency Checking
# -----------------------------------------------------------------------------

# Skip dependency checks for --help flag only (showing help doesn't need ctags)
# Also skip if no file arguments provided (catches unknown options early)
skip_deps=false
[[ " $* " == *" --help "* ]] || [[ " $* " == *" -h "* ]] && skip_deps=true

# Check if file arguments are provided
has_file_arg=false
for arg in "$@"; do
  [[ "$arg" != -* ]] && has_file_arg=true && break
done

# Only check dependencies if we have file arguments AND not showing help
if ! $skip_deps && $has_file_arg; then
  validate_ctags || exit 1
  validate_gawk || exit 1
fi

# -----------------------------------------------------------------------------
# @{keyword} Hint Parsing
# -----------------------------------------------------------------------------

# Parse @{keyword} hints from documentation
# Arguments: $1 = documentation block
# Output: "keyword:value" pairs, one per line
parse_hints() {
  local doc_block="$1"

  while IFS= read -r line; do
    # Match @{keyword} or @{keyword:value} patterns
    if [[ "$line" =~ @\{([a-zA-Z]+)(:[^}]*)?\} ]]; then
      local keyword="${BASH_REMATCH[1]}"
      local value="${BASH_REMATCH[2]#:}" # Remove leading colon
      echo "${keyword}:${value}"
    fi
  done <<<"$doc_block"
}

# Check if a hint is present
# Arguments: $1 = doc block, $2 = keyword to find
# Returns: 0 if found, 1 if not
has_hint() {
  local doc_block="$1"
  local keyword="$2"

  [[ "$doc_block" =~ @\{$keyword(\}|:) ]]
}

# Get hint value
# Arguments: $1 = doc block, $2 = keyword
# Output: hint value or empty
get_hint() {
  local doc_block="$1"
  local keyword="$2"

  if [[ "$doc_block" =~ @\{$keyword:([^}]*)\} ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "$doc_block" =~ @\{$keyword\} ]]; then
    echo "true"
  fi
}

# -----------------------------------------------------------------------------
# Function Detection via ctags
# -----------------------------------------------------------------------------

# Get functions from a script file using ctags JSON output
# Arguments: $1 = script file path
# Output: JSON lines with function name and line number
get_functions() {
  local script="$1"

  # Use ctags with JSON output format
  ctags --language-force=sh \
    --kinds-sh=f \
    --output-format=json \
    --fields=+n \
    -o- "$script" 2>/dev/null |
    grep 'kind.*function' || true
}

# Parse ctags JSON output to extract function names and line numbers
# Input: stdin with JSON lines
# Output: "function_name:line_number" per line
# Skips nested functions (indented) and variable assignments ctags misclassifies
parse_ctags_json() {
  while IFS= read -r line; do
    # Guard: skip empty lines
    [[ -z "$line" ]] && continue

    local name line_num
    name=$(echo "$line" | sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    line_num=$(echo "$line" | sed -n 's/.*"line"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')

    # Skip variable assignments ctags misclassifies as functions
    # Pattern contains: "/^  local ", "/^  declare ", "/^  readonly "
    # We check if the pattern value contains these keywords
    if echo "$line" | grep -qE '"pattern"[[:space:]]*:[[:space:]]*"/\^[[:space:]]*(local|declare|readonly)[[:space:]]'; then
      continue
    fi

    # Skip nested functions (pattern contains space after ^ before "function")
    if echo "$line" | grep -qE '"pattern"[[:space:]]*:[[:space:]]*"/\^[[:space:]]+[[:space:]]*function'; then
      continue
    fi

    # Only output valid pairs (use @ as separator since function names may contain :)
    [[ -n "$name" && -n "$line_num" ]] && echo "${name}@${line_num}"
  done
}

# -----------------------------------------------------------------------------
# Documentation Parsing
# -----------------------------------------------------------------------------
# Check if line is a documentation comment (##)
# Arguments: $1 = line to check
# Returns: 0 if ## comment, 1 otherwise
is_doc_comment() {
  local line="$1"
  [[ "$line" =~ ^[[:space:]]*## ]]
}

# Check if line is a regular comment (#)
# Arguments: $1 = line to check
# Returns: 0 if # comment, 1 otherwise
is_regular_comment() {
  local line="$1"
  [[ "$line" =~ ^[[:space:]]*# && ! "$line" =~ ^[[:space:]]*## ]]
}

# Find documentation block boundaries in lines array
# Arguments: $1 = lines array name (passed by reference)
# Outputs: doc_start and doc_end variables
find_doc_boundaries() {
  local -n lines_ref=$1
  local doc_start=-1
  local doc_end=-1
  local in_gap=false
  local line_count

  # Get array length
  eval "line_count=\${#${lines_ref}[@]}"

  # Search backwards from end
  for ((i = line_count - 1; i >= 0; i--)); do
    local line
    eval "line=\${${lines_ref}[\$i]}"

    # Skip empty lines at start
    if [[ $doc_end -eq -1 && -z "${line// /}" ]]; then
      continue
    fi

    if is_doc_comment "$line"; then
      # Found ## comment
      if [[ $doc_end -eq -1 ]]; then
        doc_end=$i
      fi
      doc_start=$i
      in_gap=false
    elif is_regular_comment "$line"; then
      # Other # comments - skip if we're in a block or gap
      [[ $doc_start -ne -1 || $in_gap == true ]] && continue
    else
      # Non-comment line
      if [[ $doc_start -ne -1 ]]; then
        break
      fi
      # Haven't found docs yet
      if [[ -n "${line// /}" ]]; then
        break
      fi
      in_gap=true
    fi
  done

  echo "$doc_start $doc_end"
}

# Extract documentation block above a given line number
# Arguments: $1 = script file, $2 = function line number
# Output: Documentation text
extract_doc_block() {
  local script="$1"
  local func_line="$2"
  local doc_lines=()
  local in_doc=false
  local line_num=0

  # Read file backwards from function line to find ## block
  while IFS= read -r line; do
    ((line_num++))

    # Stop when we reach the function
    if [[ $line_num -ge $func_line ]]; then
      break
    fi

    # Collect lines that might be documentation
    doc_lines+=("$line")
  done <"$script"

  # Process backwards from the function line to find ## block
  # Skip shellcheck/shell comments that may appear between docs and function
  local doc_start=-1
  local doc_end=-1
  local in_gap=false

  for ((i = ${#doc_lines[@]} - 1; i >= 0; i--)); do
    local line="${doc_lines[$i]}"

    # Skip empty lines at the start
    if [[ $doc_end -eq -1 && -z "${line// /}" ]]; then
      continue
    fi

    # Check for ## comment
    if [[ "$line" =~ ^[[:space:]]*## ]]; then
      if [[ $doc_end -eq -1 ]]; then
        doc_end=$i
      fi
      doc_start=$i
      in_gap=false
    elif [[ "$line" =~ ^[[:space:]]*# ]]; then
      # Other # comments (like # shellcheck disable) - skip, don't treat as end of doc block
      # Only skip if we're already in a doc block or gap, don't break if we haven't found docs yet
      [[ $doc_start -ne -1 || $in_gap == true ]] && continue
    else
      # Non-##, non-# line found
      if [[ $doc_start -ne -1 ]]; then
        # Already found a ## block, non-## line ends it
        break
      fi
      # Haven't found any ## block yet
      if [[ -n "${line// /}" ]]; then
        # Non-empty non-## line - there's a gap, no doc block for this function
        break
      fi
      in_gap=true
    fi
  done

  # Output the doc block
  if [[ $doc_start -ne -1 && $doc_end -ne -1 ]]; then
    for ((i = doc_start; i <= doc_end; i++)); do
      echo "${doc_lines[$i]}"
    done
  fi
}

# Parse a documentation block into sections
# Arguments: $1 = documentation block text (multiline)
# Output: Parsed sections in a structured format
parse_doc_sections() {
  local current_section="description"
  local section_content=""

  while IFS= read -r line; do
    # Remove ## prefix
    local content="${line#*##}"
    content="${content# }" # Remove leading space

    # Check for section header
    if [[ "$content" =~ ^(Parameters|Globals|Side[[:space:]]effects|Returns|Usage|References|Categories): ]]; then
      # Output previous section
      if [[ -n "$section_content" ]]; then
        echo "SECTION:${current_section}"
        echo "$section_content"
        echo "END_SECTION"
      fi

      # Start new section
      current_section="${BASH_REMATCH[1]}"
      current_section="${current_section// /_}" # Replace space with underscore
      section_content=""
    elif [[ -n "$content" || -n "$section_content" ]]; then
      # Add to current section
      if [[ -n "$section_content" ]]; then
        section_content+=$'\n'
      fi
      section_content+="$content"
    fi
  done

  # Output last section
  if [[ -n "$section_content" ]]; then
    echo "SECTION:${current_section}"
    echo "$section_content"
    echo "END_SECTION"
  fi
}

# -----------------------------------------------------------------------------
# Module Summary Extraction (Zone 6)
# -----------------------------------------------------------------------------

# Extract module summary from the end of file
# Arguments: $1 = script file
# Output: Module summary documentation block
extract_module_summary() {
  local script="$1"
  local in_summary=false
  local summary_lines=()
  local found_module=false

  # Read file and look for ## Module: pattern near the end
  while IFS= read -r line; do
    if [[ "$line" =~ ^##[[:space:]]*Module: ]]; then
      in_summary=true
      found_module=true
      summary_lines=()
    fi

    if $in_summary; then
      if [[ "$line" =~ ^## ]] || [[ -z "${line// /}" && ${#summary_lines[@]} -gt 0 ]]; then
        summary_lines+=("$line")
      elif [[ ! "$line" =~ ^## ]] && [[ -n "${line// /}" ]]; then
        # Non-## non-empty line ends module summary
        break
      fi
    fi
  done <"$script"

  if $found_module; then
    printf '%s\n' "${summary_lines[@]}"
  fi
}

# -----------------------------------------------------------------------------
# Markdown Generation
# -----------------------------------------------------------------------------

# Generate markdown header for a script
# Arguments: $1 = script basename, $2 = module summary
generate_header() {
  local basename="$1"
  local module_summary="$2"

  echo "# ${basename}"
  echo ""

  if [[ -n "$module_summary" ]]; then
    # Extract module title and description
    local title
    title=$(echo "$module_summary" | grep -o 'Module: .*' | head -1 | sed 's/Module: //')

    if [[ -n "$title" ]]; then
      echo "**${title}**"
      echo ""
    fi

    # State machine for parsing sections
    local current_section=""
    local desc_content=""
    local refs_content=""
    local globals_content=""
    local extra_sections=""
    local current_extra_name=""
    local current_extra_content=""

    while IFS= read -r line; do
      local content="${line#*##}"
      content="${content# }"

      # Skip horizontal dividers and empty decorative lines
      if [[ "$content" =~ ^-{3,}$ ]] || [[ "$content" =~ ^={3,}$ ]]; then
        continue
      fi

      # Detect section headers
      if [[ "$content" =~ ^Module: ]]; then
        current_section="module"
        continue
      elif [[ "$content" =~ ^Purpose: ]]; then
        current_section="purpose"
        continue
      elif [[ "$content" =~ ^References: ]]; then
        current_section="references"
        continue
      elif [[ "$content" =~ ^(Globals|Globals[[:space:]]Introduced): ]]; then
        current_section="globals"
        continue
      elif [[ "$content" =~ ^(Categories|Key[[:space:]]Features|Function[[:space:]]Categories): ]]; then
        current_section="categories"
        continue
      elif [[ "$content" =~ ^([A-Z][a-zA-Z[:space:]]+): ]]; then
        # Other section headers (Platform Behavior:, Execution Modes:, etc.)
        # Save previous extra section if any
        if [[ -n "$current_extra_name" && -n "$current_extra_content" ]]; then
          extra_sections+="### ${current_extra_name}"$'\n\n'
          extra_sections+="${current_extra_content}"$'\n'
        fi
        current_extra_name="${BASH_REMATCH[1]}"
        current_extra_content=""
        current_section="extra"
        continue
      fi

      # Accumulate content based on current section
      case "$current_section" in
      module | purpose)
        if [[ -n "$content" ]]; then
          desc_content+="$content"$'\n'
        fi
        ;;
      references)
        if [[ -n "$content" ]]; then
          refs_content+="$content"$'\n'
        fi
        ;;
      globals)
        if [[ -n "$content" ]]; then
          globals_content+="$content"$'\n'
        fi
        ;;
      extra)
        if [[ -n "$content" ]]; then
          current_extra_content+="$content"$'\n'
        fi
        ;;
      esac
    done <<<"$module_summary"

    # Save last extra section if any
    if [[ -n "$current_extra_name" && -n "$current_extra_content" ]]; then
      extra_sections+="### ${current_extra_name}"$'\n\n'
      extra_sections+="${current_extra_content}"$'\n'
    fi

    # Output description
    if [[ -n "$desc_content" ]]; then
      echo "$desc_content"
    fi

    # Output references section
    if [[ -n "$refs_content" ]]; then
      echo "## References"
      echo ""
      echo "$refs_content"
    fi

    # Output globals section from module summary
    if [[ -n "$globals_content" ]]; then
      echo "## Module Globals"
      echo ""
      echo "$globals_content"
    fi

    # Output extra sections (Platform Behavior, etc.)
    if [[ -n "$extra_sections" ]]; then
      echo "## Additional Information"
      echo ""
      echo "$extra_sections"
    fi
  fi
}

# Generate table of contents
# Arguments: function names (one per line on stdin)
generate_toc() {
  echo "## Index"
  echo ""
  while IFS=@ read -r name line_num; do
    local anchor="${name//[^a-zA-Z0-9_-]/-}"
    anchor="${anchor,,}" # lowercase
    echo "* [\`${name}\`](#${anchor})"
  done
  echo ""
}

# Format a parameter line as table row
# Input: "- name - description, type, default"
# Output: Markdown table row or empty if parsing fails
# Note: Uses smarter parsing to handle commas in descriptions/examples
# shellcheck disable=SC2155,SC2310
format_parameter_row() {
  local line="$1"

  # Guard: must match expected format (- name - rest)
  [[ ! "$line" =~ ^-[[:space:]]*([^[:space:]]+)[[:space:]]*-[[:space:]]*(.*) ]] && return

  local name="${BASH_REMATCH[1]}"
  local rest="${BASH_REMATCH[2]}"

  # Smart comma parsing: find type/default at the END of the line
  # Expected format: "description text, type, default" or "description, type"
  # But description may contain commas like: "First arg (e.g., \"hello\"), string, required"

  local desc type default

  # Try to extract from the end using known type/default patterns
  # Common types: string, integer, number, boolean, array, variadic, flag
  # Common defaults: required, optional, default: X, "value"

  # Check for pattern: ", type, default" at end
  if [[ "$rest" =~ ^(.+),[[:space:]]*(string|integer|number|boolean|array|variadic|flag|[a-z]+[[:space:]]array)[[:space:]]*,[[:space:]]*(.+)$ ]]; then
    desc="${BASH_REMATCH[1]}"
    type="${BASH_REMATCH[2]}"
    default="${BASH_REMATCH[3]}"
  # Check for pattern: ", type" at end (no explicit default)
  elif [[ "$rest" =~ ^(.+),[[:space:]]*(string|integer|number|boolean|array|variadic|flag|[a-z]+[[:space:]]array)$ ]]; then
    desc="${BASH_REMATCH[1]}"
    type="${BASH_REMATCH[2]}"
    default="required"
  # Check for pattern: ", default: value" (type implied as string)
  elif [[ "$rest" =~ ^(.+),[[:space:]]*(default:[[:space:]]*.+|optional|required)$ ]]; then
    desc="${BASH_REMATCH[1]}"
    type="string"
    default="${BASH_REMATCH[2]}"
  else
    # Fallback: simple split on last two commas
    local count
    count=$(echo "$rest" | tr -cd ',' | wc -c)
    if [[ $count -ge 2 ]]; then
      # Split keeping description intact (may have commas)
      default="${rest##*, }"
      local without_default="${rest%, *}"
      type="${without_default##*, }"
      desc="${without_default%, *}"
    elif [[ $count -eq 1 ]]; then
      # Just one comma: description, type
      type="${rest##*, }"
      desc="${rest%, *}"
      default="required"
    else
      # No commas: just description
      desc="$rest"
      type="string"
      default="required"
    fi
  fi

  # Clean up whitespace using trim
  desc=$(trim "$desc")
  type=$(trim "${type:-string}")
  default=$(trim "${default:-required}")

  echo "| \`${name}\` | ${type} | ${default} | ${desc} |"
}

# Generate documentation for a single function
# Arguments: $1 = function name, $2 = parsed sections
generate_function_doc() {
  local func_name="$1"
  local sections="$2"

  echo "---"
  echo ""
  echo "### ${func_name}"
  echo ""

  local current_section=""
  local in_section=false

  while IFS= read -r line; do
    if [[ "$line" =~ ^SECTION:(.+) ]]; then
      current_section="${BASH_REMATCH[1]}"
      in_section=true

      case "$current_section" in
      description)
        # Description is just text, no header
        ;;
      Parameters)
        echo "#### Parameters"
        echo ""
        echo "| Name | Type | Default | Description |"
        echo "|------|------|---------|-------------|"
        ;;
      Globals)
        echo "#### Globals"
        echo ""
        ;;
      Returns)
        echo "#### Returns"
        echo ""
        ;;
      Side_effects)
        echo "#### Side Effects"
        echo ""
        ;;
      Usage)
        echo "#### Usage"
        echo ""
        echo '```bash'
        ;;
      References)
        echo "#### See Also"
        echo ""
        ;;
      esac
    elif [[ "$line" == "END_SECTION" ]]; then
      if [[ "$current_section" == "Usage" ]]; then
        echo '```'
      fi
      echo ""
      in_section=false
    elif $in_section && [[ -n "$line" ]]; then
      case "$current_section" in
      description)
        echo "$line"
        ;;
      Parameters)
        local row
        row=$(format_parameter_row "$line")
        if [[ -n "$row" ]]; then
          echo "$row"
        fi
        ;;
      Globals | Returns | Side_effects)
        # Source docs already have "- " prefix, output as-is
        echo "$line"
        ;;
      Usage)
        # Remove leading "- " if present
        echo "${line#- }"
        ;;
      References)
        echo "- $line"
        ;;
      *)
        echo "$line"
        ;;
      esac
    fi
  done <<<"$sections"
}

# -----------------------------------------------------------------------------
# Main Processing
# -----------------------------------------------------------------------------

# Process a single script file
# Arguments: $1 = script file path
# Output: Markdown documentation to stdout
process_script() {
  local script="$1"
  local basename
  basename=$(basename "$script")

  echo:Edocs "Processing: $script"

  # Get module summary from end of file
  local module_summary
  module_summary=$(extract_module_summary "$script")

  # Generate header
  generate_header "$basename" "$module_summary"

  # Get all functions via ctags (read-only operation)
  local functions
  functions=$(get_functions "$script" | parse_ctags_json)

  if [[ -z "$functions" ]]; then
    echo:Warn "No functions found in $script"
    # Still output a note for configuration scripts
    echo ""
    echo "> **Note:** This is a configuration module that executes initialization code when sourced."
    echo "> It does not provide reusable functions."
    echo ""
    return
  fi

  # Generate TOC if enabled
  if [[ "$EDOCS_TOC" == "true" ]]; then
    echo "$functions" | generate_toc
  fi

  echo "---"
  echo ""
  echo "## Functions"
  echo ""

  # Process each function
  while IFS=@ read -r func_name func_line; do
    # Skip private functions if not included
    if [[ "$EDOCS_INCLUDE_PRIVATE" != "true" && "$func_name" =~ ^_ ]]; then
      continue
    fi

    # Extract and parse documentation
    local doc_block sections
    doc_block=$(extract_doc_block "$script" "$func_line")

    # Validate documentation if enabled
    if [[ "$EDOCS_VALIDATE" == "true" ]]; then
      validate_doc_block "$script" "$func_name" "$func_line" "$doc_block"
    fi

    # Check for @{internal} hint - skip internal functions
    if has_hint "$doc_block" "internal"; then
      continue
    fi

    # Check for @{ignore} hint - skip functions marked to be excluded from docs
    if has_hint "$doc_block" "ignore"; then
      continue
    fi

    # Check for @{deprecated} hint - add deprecation notice
    local deprecated_msg=""
    if has_hint "$doc_block" "deprecated"; then
      deprecated_msg=$(get_hint "$doc_block" "deprecated")
    fi

    if [[ -n "$doc_block" ]]; then
      sections=$(echo "$doc_block" | parse_doc_sections)
      generate_function_doc "$func_name" "$sections" "$deprecated_msg"
    else
      # Function without documentation
      echo "---"
      echo ""
      echo "### ${func_name}"
      echo ""
      echo "_No documentation available._"
      echo ""
    fi
  done <<<"$functions"
}

# Check mode (--check flag)
check_mode() {
  local script="$1"
  local output_file="$2"

  if [[ ! -f "$output_file" ]]; then
    echo:Err "Documentation missing: $output_file"
    return 1
  fi

  local current new_content
  current=$(cat "$output_file")
  new_content=$(process_script "$script" 2>/dev/null)

  if [[ "$current" != "$new_content" ]]; then
    echo:Err "Documentation out of date: $output_file"
    return 1
  fi

  echo:Ok "Documentation up to date: $output_file"
  return 0
}

# -----------------------------------------------------------------------------
# CLI Interface
# -----------------------------------------------------------------------------

# Declare variables for argument parsing
declare help version OUTPUT_DIR FORCE VERBOSE KEEP_TEMP DEBUG \
  args_check args_dry_run args_stdout args_no_toc args_validate args_no_validate \
  args_include_private

# Build argument definition using args:i COMPOSER pattern
export COMPOSER="
  $(args:i help -a "-h,--help" -h "Show help and exit." -g global)
  $(args:i version -a "--version" -h "Show version and exit." -g global)
  $(args:i OUTPUT_DIR -a "-o,--output-dir" -q 1 -h "Output directory for documentation." -g options)
  $(args:i args_check -a "-c,--check" -h "Check if docs are up to date (exit 1 if not)." -g options)
  $(args:i args_dry_run -a "-n,--dry-run" -h "Print to stdout without creating files/directories." -g options)
  $(args:i args_stdout -a "-s,--stdout" -h "Alias for --dry-run (for backwards compatibility)." -g options)
  $(args:i args_no_toc -a "--no-toc" -h "Disable table of contents." -g options)
  $(args:i args_validate -a "-v,--validate" -h "Enable validation warnings." -g options)
  $(args:i args_no_validate -a "--no-validate" -h "Disable validation warnings." -g options)
  $(args:i args_include_private -a "--include-private" -h "Include private functions (starting with _)." -g options)
  $(args:i DEBUG -a "--debug" -d "*" -h "Enable debug mode." -g debug)
"
eval "$COMPOSER" >/dev/null
parse:arguments "$@"

# Manual collection of positional arguments (files)
# ARGS_NO_FLAGS doesn't work properly with args:i pattern that has options with values
ARGS_NO_FLAGS=()
skip_next=false
for arg in "$@"; do
  if $skip_next; then
    skip_next=false
    continue
  fi
  case "$arg" in
  -h | --help | --version | -c | --check | -n | --dry-run | -s | --stdout | --no-toc | -v | --validate | --no-validate | --include-private | --debug)
    # Flags without values
    ;;
  -o | --output-dir)
    # Flags with values - skip next arg too
    skip_next=true
    ;;
  -*)
    # Unknown flag, skip it
    ;;
  *)
    # Positional argument (file)
    ARGS_NO_FLAGS+=("$arg")
    ;;
  esac
done

# Simplified usage function using print:help
usage() {
  print:help
  echo ""
  echo "Examples:"
  echo "  $(basename "$0")                        # Generate docs for all scripts"
  echo "  $(basename "$0") .scripts/_logger.sh    # Generate docs for specific file"
  echo "  $(basename "$0") --dry-run file.sh      # Preview docs without writing"
  echo "  $(basename "$0") --check                # Verify docs are current"
  echo ""
  echo "@{keyword} Hints:"
  echo "  @{internal}        Skip this function in output (internal implementation)"
  echo "  @{ignore}          Skip this function in output (explicit exclusion)"
  echo "  @{deprecated:msg}  Mark function as deprecated with message"
  echo "  @{since:version}   Version when function was added"
}

main() {
  local check_only=false
  local dry_run=false
  local files=()

  # Apply parsed arguments
  [[ "${args_check:-}" == "1" ]] && check_only=true
  [[ "${args_dry_run:-}" == "1" ]] && dry_run=true
  [[ "${args_stdout:-}" == "1" ]] && dry_run=true
  [[ "${args_no_toc:-}" == "1" ]] && EDOCS_TOC="false"
  [[ "${args_validate:-}" == "1" ]] && EDOCS_VALIDATE="true"
  [[ "${args_no_validate:-}" == "1" ]] && EDOCS_VALIDATE="false"
  [[ "${args_include_private:-}" == "1" ]] && EDOCS_INCLUDE_PRIVATE="true"
  if [[ -n "${OUTPUT_DIR:-}" ]]; then
    # Normalize to absolute path
    if [[ "$OUTPUT_DIR" =~ ^/ ]]; then
      EDOCS_OUTPUT_DIR="$OUTPUT_DIR"
    else
      EDOCS_OUTPUT_DIR="$PROJECT_ROOT/$OUTPUT_DIR"
    fi
  fi

  # Handle help and version flags
  if [[ "${help:-}" == "1" ]]; then
    usage
    exit 0
  fi

  if [[ -n "${version:-}" ]]; then
    echo "version: 2.7.9"
    exit 0
  fi

  # Create output directory only when writing files (not in dry-run mode)
  if ! $dry_run && ! $check_only; then
    mkdir -p "$EDOCS_OUTPUT_DIR"
  fi

  # Determine files to process
  # ARGS_NO_FLAGS contains all positional arguments (populated by parse:exclude_flags_from_args)
  # This is the preferred way to handle variadic positional arguments in _arguments.sh
  if [[ ${#ARGS_NO_FLAGS[@]} -eq 0 ]]; then
    # Process all files in source directories
    for dir in $EDOCS_SOURCE_DIRS; do
      for script in "$PROJECT_ROOT/$dir"/*.sh; do
        if [[ -f "$script" ]]; then
          files+=("$script")
        fi
      done
    done
  else
    # Process files from positional arguments (ARGS_NO_FLAGS)
    # Skip filtering in dry-run mode to allow testing with fixture files
    if $dry_run; then
      # In dry-run mode, allow any file
      files+=("${ARGS_NO_FLAGS[@]}")
    else
      local filtered_files=()
      for file in "${ARGS_NO_FLAGS[@]}"; do
        local is_allowed=false
        local file_abs_path

        # Resolve absolute path
        if [[ "$file" =~ ^/ ]]; then
          file_abs_path="$file"
        else
          file_abs_path="$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
        fi

        # Check if file is within any of the source directories
        for dir in $EDOCS_SOURCE_DIRS; do
          local source_dir="$PROJECT_ROOT/$dir"
          # Normalize paths for comparison
          local normalized_file="${file_abs_path#$source_dir/}"
          if [[ "$file_abs_path" == "$source_dir"* ]]; then
            is_allowed=true
            break
          fi
        done

        if $is_allowed; then
          filtered_files+=("$file")
        else
          echo:Warn "Skipping file outside source directories: $file"
        fi
      done
      files=("${filtered_files[@]}")
    fi
  fi

  # Process files with progress display
  local exit_code=0
  local total=${#files[@]}
  local current=0

  for script in "${files[@]}"; do
    ((current++))
    local script_basename output_file
    script_basename=$(basename "$script" .sh)
    output_file="$EDOCS_OUTPUT_DIR/${script_basename}.md"

    # Show progress for multiple files
    if [[ $total -gt 1 ]]; then
      show_progress "$current" "$total" "$script"
    fi

    # Validate structure if enabled (but skip in dry-run mode for cleaner output)
    if [[ "$EDOCS_VALIDATE" == "true" ]] && ! $dry_run; then
      validate_structure "$script"
    fi

    if $check_only; then
      if ! check_mode "$script" "$output_file"; then
        exit_code=1
      fi
    else
      if $dry_run; then
        # Suppress logger messages in dry-run mode for cleaner output
        process_script "$script" 2>/dev/null
      else
        # Write output file (state-mutating operation)
        process_script "$script" >"$output_file"
        if [[ $total -eq 1 ]]; then
          echo:Ok "Generated: $output_file"
        fi
      fi
    fi
  done

  # Final summary
  if [[ $total -gt 1 && ! $check_only ]]; then
    echo:Ok "Generated documentation for $total files"
  fi

  if $check_only && [[ $exit_code -eq 0 ]]; then
    echo:Ok "All documentation is up to date"
  fi

  return $exit_code
}

# Run main if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # ARGS_NO_FLAGS is populated by parse:exclude_flags_from_args (called during module load)
  main "${ARGS_NO_FLAGS[@]}"
fi

##
## Module: e-docs Documentation Generator
##
## Generates Markdown documentation from e-bash script files.
## Uses ctags for function detection and pure bash for doc parsing.
##
## References:
## - documentation: docs/public/e-docs.md
## - configuration: .edocsrc
## - tests: spec/e_docs_spec.sh
##
## Dependencies (e-bash modules):
## - _gnu.sh - Cross-platform GNU tools
## - _colors.sh - Color definitions
## - _dependencies.sh - Version-aware dependency checking
## - _logger.sh - Tag-based logging
##
## Globals:
## - EDOCS_OUTPUT_DIR - Output directory for generated docs
## - EDOCS_SOURCE_DIRS - Source directories to scan
## - EDOCS_TOC - Enable/disable table of contents
## - EDOCS_INCLUDE_PRIVATE - Include private functions
##
## Categories:
##
## Utility Functions:
## - trim() - Remove leading/trailing whitespace
##
## Function Detection:
## - get_functions() - Extract functions via ctags JSON output
## - parse_ctags_json() - Parse ctags output to name:line pairs
##
## Documentation Parsing:
## - extract_doc_block() - Get ## block above function
## - parse_doc_sections() - Split doc into sections
## - extract_module_summary() - Get Module Summary from EOF
##
## Markdown Generation:
## - generate_header() - Create file header with module info
## - generate_toc() - Create Table of Contents
## - format_parameter_row() - Format parameter as table row
## - generate_function_doc() - Render function documentation
##
## Main Processing:
## - process_script() - Process single script file
## - check_mode() - Verify docs are up to date
## - main() - CLI entry point
##
