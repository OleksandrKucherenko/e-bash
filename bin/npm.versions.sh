#!/usr/bin/env bash
# shellcheck disable=SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-14
## Version: 2.0.2
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# Script for visualizing and managing NPM package versions from NPM registry
# Allows for easy selection and unpublishing of versions in various range formats

# Bootstrap: 1) E_BASH discovery (only if not set), 2) gnubin setup (always)
[ "$E_BASH" ] || { _src=${BASH_SOURCE:-$0}; E_BASH=$(cd "${_src%/*}/../.scripts" 2>&- && pwd || echo ~/.e-bash/.scripts); readonly E_BASH; }
. "$E_BASH/_gnu.sh"; PATH="$(cd "$E_BASH/../bin/gnubin" 2>&- && pwd):$PATH"

# Skip automatic argument parsing - we'll call parse:arguments manually
export SKIP_ARGS_PARSING=1

# Pre-declare variables for shellcheck
declare help REGISTRY PACKAGE_NAME DRY_RUN SILENT_NPM

# Define command-line arguments
ARGS_DEFINITION=""
ARGS_DEFINITION+=" \$1,<package-name>=PACKAGE_NAME:@oleksandrkucherenko/mcp-obsidian"
ARGS_DEFINITION+=" -h,--help=help"
ARGS_DEFINITION+=" -r,--registry=REGISTRY:https://registry.npmjs.org:1"
ARGS_DEFINITION+=" --dry-run=DRY_RUN:true"
ARGS_DEFINITION+=" --silent=SILENT_NPM:true"

# Set up debug variable before sourcing logger
DEBUG=${DEBUG:-"npm,npmv,versions,registry,dry,run,exec,-output,-dump,-loader"}

# Source e-bash components
# shellcheck disable=SC1090 source="../.scripts/_colors.sh"
source "$E_BASH/_colors.sh"

# shellcheck disable=SC1090 source="../.scripts/_logger.sh"
source "$E_BASH/_logger.sh"

# shellcheck disable=SC1090 source="../.scripts/_commons.sh"
source "$E_BASH/_commons.sh"

# shellcheck disable=SC1090 source="../.scripts/_dependencies.sh"
source "$E_BASH/_dependencies.sh"

# shellcheck disable=SC1090 source="../.scripts/_arguments.sh"
source "$E_BASH/_arguments.sh"

# shellcheck disable=SC1090 source="../.scripts/_dryrun.sh"
source "$E_BASH/_dryrun.sh"

# Set up help documentation for arguments (just metadata, not dynamic functions)
args:d '<package-name>' 'NPM package name to manage' "arguments" 1
args:d '-h' 'Display this help message and exit' "global" 0
args:d '-r' 'Specify NPM registry URL (env: REGISTRY, default: https://registry.npmjs.org)' "options" 2
args:d '--dry-run' 'Simulate commands without actual execution (env: DRY_RUN)' "options" 2
args:d '--silent' 'Hide npm command output details (env: SILENT_NPM)' "options" 2

# Apply defaults for variables if not set by arguments
PACKAGE_NAME=${PACKAGE_NAME:-"@oleksandrkucherenko/mcp-obsidian"}
REGISTRY=${REGISTRY:-"https://registry.npmjs.org"}
DRY_RUN=${DRY_RUN:-false}
SILENT_NPM=${SILENT_NPM:-false}

# Determine terminal width for column layout (can be mocked in tests)
TERM_WIDTH=${TERM_WIDTH:-$(tput cols 2>/dev/null || echo 80)}

# Function to print usage instructions (wraps print:help with examples)
function print_usage() {
  # Ensure argument metadata is initialized when sourced in tests
  parse:mapping

  echo "${cl_yellow}Usage:${cl_reset} npm.versions.sh [options] [package-name]"
  echo ""
  print:help
  echo "${cl_yellow}Examples:${cl_reset}"
  echo "  npm.versions.sh                                # Use default package"
  echo "  npm.versions.sh lodash                         # Display versions for lodash"
  echo "  npm.versions.sh -r https://my-registry.com/    # Use custom registry"
}

# Function to fetch package versions from NPM registry
function fetch_versions() {
  local package_name="$1"
  local registry="${2:-$REGISTRY}"

  echo:Registry "Fetching versions for ${cl_yellow}${package_name}${cl_reset}"
  echo:Registry "From registry ${cl_yellow}${registry}${cl_reset}"

  # Configure NPM registry temporarily (state-modifying operation)
  dry:npm config set registry "$registry"

  # Fetch versions using npm view command
  #set -x
  local versions
  #run:npm view "$package_name" versions --json
  versions=$(run:npm view "$package_name" versions --json) || {
    echo:Npmv "${cl_red}Error: Failed to fetch versions for ${cl_yellow}$package_name${cl_reset}"
    echo:Npmv "${cl_red}Please check if the package exists and you have access to it.${cl_reset}"
    return 1
  }

  echo:Dump "Versions JSON:" "${versions[*]}"
  
  # Parse JSON output and sort versions
  local result=$(echo "$versions" | tr -d '[]" ' | tr ',' '\n' | grep -v '^$' | sort -V)
  echo:Dump "Sorted versions: ${result}"

  echo "$result"
}

# Function to display versions in columns
function display_versions() {
  local versions=("$@")
  local version_count=${#versions[@]}
  
  if [[ $version_count -eq 0 ]]; then
    echo:Versions "${cl_red}No versions found.${cl_reset}"
    return 1
  fi
  
  local version_label="version"
  if (( version_count != 1 )); then
    version_label="versions"
  fi

  echo "${cl_green}Found ${cl_yellow}$version_count${cl_green} ${version_label}:${cl_reset}"
  echo ""
  
  # Calculate columns based on terminal width and max version length
  # Find the maximum length of all version strings
  local max_version_length=0
  local version_length
  
  for version in "${versions[@]}"; do
    version_length=${#version}
    if (( version_length > max_version_length )); then
      max_version_length=$version_length
    fi
  done
  
  # Add padding and account for the index number (3 digits max) + closing parenthesis + spacing
  local column_width=$((max_version_length + 8))
  
  # Calculate how many columns can fit in the terminal
  local columns=$((TERM_WIDTH / column_width))
  columns=$((columns < 1 ? 1 : columns))
  
  # Calculate number of rows needed
  local rows=$(( (version_count + columns - 1) / columns ))
  
  # Calculate column positions for alignment
  local col_positions=()
  for ((i=0; i<columns; i++)); do
    col_positions[i]=$((i * (column_width + 2)))
  done
  
  # Create a "table" of versions - printing left-to-right, row by row
  for ((row=0; row<rows; row++)); do
    printf "  "  # Consistent 2-space indentation at start of each row
    
    for ((col=0; col<columns; col++)); do
      # Calculate the index in the versions array
      local index=$((row + col * rows))
      
      # Check if we've gone past the end of our array
      if [[ $index -ge $version_count ]]; then
        continue
      fi
      
      # Move cursor to column position if not the first column
      if [[ $col -gt 0 ]]; then
        # Add consistent spacing between columns
        printf "%-$((col_positions[col] - col_positions[col-1] - column_width + 2))s" ""
      fi
      
      # Extract the current version
      local current_version="${versions[$index]}"
      
      # Define color formatting based on version content
      local version_color="" version_reset=""
      
      # Use gray color for canary versions
      if [[ "$current_version" == *"canary"* ]]; then
        version_color="$cl_gray"
        version_reset="$cl_reset"
      fi
      
      # Standard prefix for all versions (index in green)
      local prefix="${cl_green}%3d)${cl_reset} "
      
      # Print version with appropriate formatting
      printf "${prefix}${version_color}%-${max_version_length}s${version_reset}" "$((index+1))" "${current_version}"
    done
    
    # End each row with a newline
    printf "\n"
  done
  
  echo ""
  return 0
}

# Function to parse version range from user input
function parse_range() {
  local input="$1"
  shift # Skip the first argument (input)
  local versions=("$@")
  
  # Remove whitespace
  input=$(echo "$input" | tr -d ' ')
  
  # Split by comma
  local segments
  IFS=',' read -ra segments <<< "$input"
  
  local selected=()
  
  for segment in "${segments[@]}"; do
    # Check if it's a range (contains -)
    if [[ $segment == *-* ]]; then
      IFS='-' read -r start end <<< "$segment"
      
      # Validate start and end
      if ! [[ $start =~ ^[0-9]+$ ]] || ! [[ $end =~ ^[0-9]+$ ]]; then
        echo:Versions "${cl_red}Invalid range: ${cl_yellow}$segment${cl_reset}"
        return 1
      fi
      
      # Adjust for 1-based indexing
      ((start--))
      ((end--))
      
      # Add all versions in range
      local i=0 # make $i local to avoid conflicts
      for ((i=start; i<=end; i++)); do
        if [[ $i -ge 0 && $i -lt ${#versions[@]} ]]; then
          selected+=("$i")
        else
          echo:Versions "${cl_red}Index out of range: ${cl_yellow}$((i+1))${cl_reset}"
          return 1
        fi
      done
    else
      # Single number
      if ! [[ $segment =~ ^[0-9]+$ ]]; then
        echo:Versions "${cl_red}Invalid index: ${cl_yellow}$segment${cl_reset}"
        return 1
      fi
      
      # Adjust for 1-based indexing
      local idx=$((segment-1))
      
      if [[ $idx -ge 0 && $idx -lt ${#versions[@]} ]]; then
        selected+=("$idx")
      else
        echo:Versions "${cl_red}Index out of range: ${cl_yellow}$segment${cl_reset}"
        return 1
      fi
    fi
  done
  
  # Return selected indexes
  for idx in "${selected[@]}"; do
    echo "$idx"
  done
  
  return 0
}

# Function to confirm unpublishing versions
function confirm_unpublish() {
  local package_name="$1"
  local to_unpublish=("${@:2}")
  
  echo:Npmv "${cl_yellow}You are about to unpublish these versions of ${cl_white}$package_name${cl_yellow}:${cl_reset}"
  for version in "${to_unpublish[@]}"; do
    echo:Versions "  - ${cl_red}$version${cl_reset}"
  done
  
  echo:Npmv ""
  echo:Npmv "${cl_yellow}This action ${cl_red}CANNOT${cl_yellow} be undone!${cl_reset}"
  read -rp "$(echo -e "${cl_cyan}Proceed with unpublishing? (yes/no): ${cl_reset}")" confirm
  
  if [[ "${confirm,,}" == "yes" ]]; then
    return 0
  else
    echo:Npmv "${cl_green}Operation cancelled.${cl_reset}"
    return 1
  fi
}

# Function to unpublish a specific version
function unpublish_version() {
  local package_name="$1"
  local version="$2"
  
  echo:Registry "${cl_cyan}Unpublishing ${cl_yellow}$package_name@$version${cl_reset}..."

  # Ensure we're using the configured registry (dry:npm for destructive operation)
  dry:npm unpublish "$package_name@$version" --registry="$REGISTRY" || {
    echo:Registry "${cl_red}Failed to unpublish ${cl_yellow}$package_name@$version${cl_reset}"
    return 1
  }
  
  echo:Registry "${cl_green}Successfully unpublished ${cl_yellow}$package_name@$version${cl_reset}"
  return 0
}

# Function to verify package version is unpublished
function verify_unpublish() {
  local package_name="$1"
  local version="$2"
  
  echo:Registry "${cl_cyan}Verifying ${cl_yellow}$package_name@$version${cl_cyan} is unpublished...${cl_reset}"
  
  # Check if version still exists (using configured registry)
  if run:npm view "$package_name@$version" version --registry="$REGISTRY" &>/dev/null; then
    echo:Registry "${cl_red}Failed: ${cl_yellow}$package_name@$version${cl_red} still exists in registry!${cl_reset}"
    return 1
  else
    echo:Registry "${cl_green}Verified: ${cl_yellow}$package_name@$version${cl_green} has been removed from registry.${cl_reset}"
    return 0
  fi
}

# Main function with program execution logic
function main() {
  # Parse command line arguments using _arguments module
  parse:arguments "$@"

  # Check if help was requested
  if [[ "${help:-}" == "true" ]] || [[ "${help:-}" == "1" ]]; then
    print_usage
    return 0
  fi
  
  # Show program header
  echo:Npmv "NPM Package Version Manager"

  # Fetch all versions
  local VERSIONS
  readarray -t VERSIONS < <(fetch_versions "$PACKAGE_NAME" "$REGISTRY")

  if [[ ${#VERSIONS[@]} -eq 0 ]]; then
    echo:Npmv "${cl_red}No versions found.${cl_reset}"
    return 1
  fi

  # Display versions in columns
  display_versions "${VERSIONS[@]}"

  # Prompt for versions to unpublish
  echo -e "${cl_purple}Enter version numbers to unpublish (e.g., '1,5,10-15,20', Ctrl+C to exit):${cl_reset}"
  local VERSION_RANGE
  read -r VERSION_RANGE

  if [[ -z "$VERSION_RANGE" ]]; then
    echo:Npmv "${cl_yellow}No versions selected. Exiting.${cl_reset}"
    return 0
  fi

  # Parse version range
  local SELECTED_INDEXES
  readarray -t SELECTED_INDEXES < <(parse_range "$VERSION_RANGE" "${VERSIONS[@]}")

  if [[ ${#SELECTED_INDEXES[@]} -eq 0 ]]; then
    echo:Npmv "${cl_red}No valid versions selected. Exiting.${cl_reset}"
    return 1
  fi

  # Get selected versions
  local SELECTED_VERSIONS=()
  local idx
  for idx in "${SELECTED_INDEXES[@]}"; do
    SELECTED_VERSIONS+=("${VERSIONS[$idx]}")
  done

  # Confirm unpublish
  if confirm_unpublish "$PACKAGE_NAME" "${SELECTED_VERSIONS[@]}"; then
    # Unpublish selected versions
    local version
    for version in "${SELECTED_VERSIONS[@]}"; do
      if unpublish_version "$PACKAGE_NAME" "$version"; then
        verify_unpublish "$PACKAGE_NAME" "$version"
      fi
    done
    
    echo:Npmv "${cl_green}Operation completed.${cl_reset}"
  else
    echo:Npmv "${cl_yellow}Operation cancelled.${cl_reset}"
  fi

  return 0
}

# This is the writing style presented by ShellSpec, which is short but unfamiliar.
# Note that it returns the current exit status (could be non-zero).
# DO NOT allow execution of code below this line in shellspec tests
${__SOURCED__:+return}

# Initialize loggers with domain-specific names (creates dynamic functions)
logger:init npmv "${cl_cyan}[npmv]${cl_reset} " ">&1"
logger:init npm " " ">&2"
logger:init versions "${cl_blue}[ver]${cl_reset} " ">&2"
logger:init registry "${cl_green}[reg]${cl_reset} " ">&2"
logger:init dump "${cl_gray}|${cl_reset} " ">&2"

# Setup dry-run wrapper for npm command (creates dynamic functions)
# This creates three wrapper functions:
#   run:npm   - for readonly operations (view)
#   dry:npm   - for destructive operations (config set, unpublish)
#   rollback:npm - for registering rollback commands
dry-run npm

# Execute the main function and exit with its return code
main "$@"
exit $?
