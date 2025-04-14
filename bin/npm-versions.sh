#!/usr/bin/env bash
# shellcheck disable=SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-04-14
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


# Script for visualizing and managing NPM package versions from NPM registry
# Allows for easy selection and unpublishing of versions in various range formats

# E_BASH is globally available via direnv
# If for some reason it's not set, provide a fallback
if [[ -z "$E_BASH" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  E_BASH="$(cd "$SCRIPT_DIR/.." && pwd)/.scripts"
  echo "Warning: E_BASH not found, using fallback: $E_BASH" >&2
fi

# Set up debug variable before sourcing logger
DEBUG=${DEBUG:-"npmv,-dump,versions,registry,-loader"}

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

# Default package name
DEFAULT_PACKAGE="@klarna/personalization-data-platform-attributes"
PACKAGE_NAME="$DEFAULT_PACKAGE"
REGISTRY="https://artifactory.klarna.net/artifactory/api/npm/v-npm-production"

# Set to true to enable dry-run mode (no actual npm commands will be executed)
DRY_RUN=${DRY_RUN:-false}

# Set to true to silence npm command output
SILENT_NPM=${SILENT_NPM:-false}

# Initialize loggers with domain-specific names
logger npmv "$@" && logger:prefix npmv "${cl_cyan}[npmv]${cl_reset} "
logger npm "$@" && logger:prefix npm "" && logger:redirect npm ">&2"
logger versions "$@" && logger:prefix versions "${cl_blue}[ver]${cl_reset} " && logger:redirect versions ">&2"
logger registry "$@" && logger:prefix registry "${cl_green}[reg]${cl_reset} " && logger:redirect registry ">&2"
logger dump "$@" && logger:prefix dump "${cl_gray}|${cl_reset} " && logger:redirect dump ">&2"

# Determine terminal width for column layout
TERM_WIDTH=$(tput cols)

# Function to print usage instructions
function print_usage() {
  echo:Npmv "${cl_yellow}Usage:${cl_reset} npm-versions.sh [options] [package-name]"
  echo:Npmv ""
  echo:Npmv "${cl_yellow}Options:${cl_reset}"
  echo:Npmv "  -h, --help        Display this help message"
  echo:Npmv "  -r, --registry    Specify NPM registry URL (default: $REGISTRY)"
  echo:Npmv "  --dry-run         Simulate commands without actual execution"
  echo:Npmv "  --silent          Hide npm command output details"
  echo:Npmv ""
  echo:Npmv "${cl_yellow}Examples:${cl_reset}"
  echo:Npmv "  npm-versions.sh                                # Use default package"
  echo:Npmv "  npm-versions.sh lodash                         # Display versions for lodash"
  echo:Npmv "  npm-versions.sh -r https://my-registry.com/    # Use custom registry"
}

# Function to fetch package versions from NPM registry
function fetch_versions() {
  local package_name="$1"
  local registry="${2:-$REGISTRY}"
  
  echo:Registry "Fetching versions for ${cl_yellow}${package_name}${cl_reset}"
  echo:Registry "From registry ${cl_yellow}${registry}${cl_reset}"
  
  # Configure NPM registry temporarily
  exec:npm config set registry "$registry"
  
  # Fetch versions using npm view command
  local versions
  versions=$(exec:npm view "$package_name" versions --json 2>/dev/null) || {
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
  
  echo "${cl_green}Found ${cl_yellow}$version_count${cl_green} version(s):${cl_reset}"
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
  local versions=("$@")
  shift # Skip the first argument (input)
  
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
  
  # Ensure we're using the configured registry
  exec:npm unpublish "$package_name@$version" --registry="$REGISTRY" || {
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
  if exec:npm view "$package_name@$version" version --registry="$REGISTRY" &>/dev/null; then
    echo:Registry "${cl_red}Failed: ${cl_yellow}$package_name@$version${cl_red} still exists in registry!${cl_reset}"
    return 1
  else
    echo:Registry "${cl_green}Verified: ${cl_yellow}$package_name@$version${cl_green} has been removed from registry.${cl_reset}"
    return 0
  fi
}

# Execute npm command with dry-run support
# Arguments:
#   $@: All arguments are passed to npm command
# Returns:
#   Command exit code or 0 if in dry-run mode
function exec:npm() {
  if [ "$DRY_RUN" = true ]; then
    echo:Registry "${cl_cyan}dry run: npm $*${cl_reset}"
    
    # Special case for npm view in dry run mode, simulate output
    if [[ "$1" == "view" && "$3" == "versions" && "$4" == "--json" ]]; then
      echo '["0.0.1","0.0.2","0.0.3","1.0.0","1.0.1","1.1.0"]'
    fi
    
    return 0
  fi

  # Is immediate exit on error enabled? Remember the state
  local immediate_exit_on_error
  [[ $- == *e* ]] && immediate_exit_on_error=true || immediate_exit_on_error=false
  set +e # disable immediate exit on error

  echo:Npm -n "${cl_cyan}execute:${cl_reset} npm $*"
  local output result
  output=$(npm "$@" 2>&1)
  result=$?
  echo:Npm "${cl_cyan} code: ${cl_yellow}$result${cl_reset}"
  [ -n "$output" ] && [ "$SILENT_NPM" = false ] && echo:Npm "${cl_gray}$output${cl_reset}"

  [ "$immediate_exit_on_error" = "true" ] && set -e # recover state
  
  if [ "$1" == "view" ] && [ "$3" == "versions" ] && [ "$4" == "--json" ]; then
    # For view command, pass the output to stdout for capture
    echo "$output"
  fi
  
  return $result
}

# Parse command line arguments
# REGISTRY is already defined with default value
function parse_arguments() {
  for arg in "$@"; do
    case $arg in
      -h|--help)
        print_usage
        exit 0
        ;;
      -r|--registry)
        REGISTRY="$2"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --silent)
        SILENT_NPM=true
        shift
        ;;
      -*)
        echo:Npmv "${cl_red}Unknown option: ${cl_yellow}$arg${cl_reset}"
        print_usage
        exit 1
        ;;
      *)
        # If not an option, assume it's a package name
        if [[ -n "$arg" ]]; then
          PACKAGE_NAME="$arg"
        fi
        ;;
    esac
  done
}

# Main function with program execution logic
function main() {
  # Parse command line arguments
  parse_arguments "$@"
  
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
  echo:Npmv "${cl_purple}Enter version numbers to unpublish (e.g., '1,5,10-15,20', Ctrl+C to exit):${cl_reset}"
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

# Execute the main function and exit with its return code
main "$@"
exit $?
