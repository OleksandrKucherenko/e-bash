#!/usr/bin/env bash
# shellcheck disable=SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-04-28
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

DEBUG=${DEBUG:-"-tree,-loader"}

# shellcheck disable=SC1090 source=../.scripts/_logger.sh
source "$E_BASH/_logger.sh"

logger:init tree

readonly TREE_NODE="├── "
readonly TREE_LAST="└── "
readonly TREE_PIPE="│   "
readonly TREE_FILL="    "
readonly osc="\e]"
readonly st="\e\\"

# Function to detect terminal hyperlink support
function detect_hyperlink_support() {
  # Check for known terminals that support hyperlinks
  case "$TERM" in
  *-256color | *-direct | xterm* | rxvt* | alacritty | foot | konsole* | vte* | iterm*)
    # iTerm2, modern xterm, Terminal.app, GNOME Terminal, Konsole, etc.
    # Also check if we're in WSL with a modern terminal
    if [[ -n "$WSLENV" || -n "$WSL_DISTRO_NAME" || -n "$WSL_INTEROP" ]]; then
      # Windows Terminal and modern VSCode terminals both support hyperlinks
      echo "true"
      return
    fi

    # For other terminals, we'll check if we can extract version info from environment
    # TERM_PROGRAM and TERM_PROGRAM_VERSION can help detect specific terminal types
    if [[ "$TERM_PROGRAM" == "iTerm.app" || "$TERM_PROGRAM" == "vscode" || "$TERM_PROGRAM" == "WezTerm" ]]; then
      echo "true"
      return
    fi

    # For terminals we can't confidently detect, use the COLORTERM indicator
    # which is usually set on modern terminals with extended capabilities
    if [[ "$COLORTERM" == "truecolor" || "$COLORTERM" == "24bit" ]]; then
      echo "true"
      return
    fi

    # Default for terminals we recognize but can't confirm support
    echo "true"
    ;;
  dumb | *)
    # Safe default for unknown/generic terminals
    echo "false"
    ;;
  esac
}

# function compose URL from absolute path, it can be vscode:// or file:// or https://
function compose_url() {
  local abs_path="$1"

  echo "file://${abs_path}"
}

function tree_bash() {
  local sep="/" paths=() i=0

  # Argument parsing
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --sep)
      sep="$2"
      shift 2
      ;;
    --help | -h)
      echo "Usage: tree_bash [--sep SEP] [paths...]"
      return 0
      ;;
    *)
      paths+=("$1")
      shift
      ;;
    esac
  done

  # Read from stdin if no args
  if [[ ${#paths[@]} -eq 0 ]]; then
    while IFS= read -r line; do
      [[ -n "$line" ]] && paths+=("$line")
    done
    echo:Tree "reading from stdin. Caught: ${#paths[@]} lines"
  fi

  # Collect unique paths and organize them hierarchically
  declare -A nodes=()

  for path in "${paths[@]}"; do
    IFS="$sep" read -ra parts <<<"$path"
    local parent=""

    for ((i = 0; i < ${#parts[@]}; i++)); do
      local current="${parts[i]}"
      local key="$parent$current"

      # Store each unique node only once
      echo:Tree "storing node: $key = $current / $path / ${parts[*]}"

      # Skip empty keys to avoid 'bad array subscript' errors
      if [[ -n "$key" ]]; then
        nodes["$key"]="$current"
      else
        echo:Tree "skipping empty key"
      fi

      # Update parent for next iteration
      parent+="$current$sep"
    done
  done

  function _tree_print() {
    local prefix="${1:-""}" parent="${2:-""}"
    local -a children=()
    local -i idx=0

    # Find direct children of current parent
    declare -A direct_children=()
    for k in "${!nodes[@]}"; do
      # Check if this node is a direct child of parent

      # Check if this node is a direct child of parent
      if [[ "$k" == "$parent"* && "$k" != "$parent" ]]; then
        # Get the first segment after parent
        local child_part="${k#$parent}"
        if [[ "$child_part" == *"$sep"* ]]; then
          child_part="${child_part%%$sep*}"
        fi

        # Store the full path to this child for recursion
        if [[ -n "$child_part" ]]; then
          # Create key for direct child
          local child_key="$parent$child_part"

          # Add to direct children if not already there
          if [[ -z "${direct_children[$child_key]}" ]]; then
            direct_children["$child_key"]="$child_part"
          fi
        fi
      fi
    done

    # Convert to sorted array
    for child_key in "${!direct_children[@]}"; do
      children+=("$child_key")
    done

    # Sort children alphabetically
    if [[ ${#children[@]} -gt 0 ]]; then
      # Use mapfile (readarray) for safer array handling
      mapfile -t children < <(printf '%s\n' "${children[@]}" | sort)
    fi

    local total=${#children[@]}
    for ((idx = 0; idx < total; idx++)); do
      local child_key="${children[$idx]}"
      local child_name="${direct_children[$child_key]}"

      # Construct full path for this node
      local cleaned_parent="${parent//\/$sep/$sep}"
      local full_path="${cleaned_parent%"$sep"}${cleaned_parent:+/}${child_name}"

      # Determine if this is the last item
      local is_last=$((idx == total - 1))
      local connector="${TREE_NODE}"
      [[ $is_last -eq 1 ]] && connector="${TREE_LAST}"

      # Get absolute path by prepending working directory if path is relative
      local abs_path="${full_path}"
      [[ "${abs_path:0:1}" != "/" ]] && abs_path="$(pwd)/${full_path}"

      # Default output without hyperlink
      local output="${prefix}${connector}${child_name}"

      # Create clickable hyperlink for VS Code according to spec:
      local link_uri=$(compose_url "${abs_path}")
      local link_text="^link" # Short clickable indicator

      # Format the hyperlink according to iTerm2 spec
      # ref1: https://code.visualstudio.com/docs/editor/command-line#_opening-vs-code-with-urls
      # ref2: https://iterm2.com/feature-reporting/Hyperlinks_in_Terminal_Emulators.html
      local link="${osc}8;;${link_uri}${st}${link_text}${osc}8;;${st}"

      # Check if hyperlinks are supported
      if [[ "$(detect_hyperlink_support)" == "true" ]]; then
        # ref1: https://code.visualstudio.com/docs/editor/command-line#_opening-vs-code-with-urls
        # ref2: https://iterm2.com/feature-reporting/Hyperlinks_in_Terminal_Emulators.html

        # Print the node with hyperlink
        output="${prefix}${connector}${child_name} ${cl_grey}[${link}]${cl_reset}"
      fi

      # Output the result
      echo -e "$output"
      echo:Tree -e "$output  ${cl_grey}# ${abs_path} [${link}]${cl_reset}"

      # Determine prefix for children of this node
      local next_prefix="${prefix}$([[ $is_last -eq 1 ]] && echo "${TREE_FILL}" || echo "${TREE_PIPE}")"

      # Recurse with updated parent path
      _tree_print "${next_prefix}" "$child_key$sep"
    done
  }

  # start printing the tree
  _tree_print
}

# Allow script execution
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  tree_bash "$@"
fi
