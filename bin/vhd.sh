#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-14
## Version: 2.0.2
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


# Bootstrap: 1) E_BASH discovery (only if not set), 2) gnubin setup (always)
[ "$E_BASH" ] || { _src=${BASH_SOURCE:-$0}; E_BASH=$(cd "${_src%/*}/../.scripts" 2>&- && pwd || echo ~/.e-bash/.scripts); readonly E_BASH; }
. "$E_BASH/_gnu.sh"; PATH="$(cd "$E_BASH/../bin/gnubin" 2>&- && pwd):$PATH"

# DEBUG variable initialization
DEBUG=${DEBUG:-"vhd,exec,error,success,warning,-loader,-internal,-parser"}

ARGS_DEFINITION=" -h,--help"                     # Display help
ARGS_DEFINITION+=" -l,--list=COMMAND:list"       # List VHD files
ARGS_DEFINITION+=" -m,--mount=COMMAND:mount"     # Mount VHD files
ARGS_DEFINITION+=" -u,--unmount=COMMAND:unmount" # Unmount VHD files
ARGS_DEFINITION+=" -a,--add=COMMAND:add"         # Add new VHD
ARGS_DEFINITION+=" -s,--size=SIZE:10G"           # Size for new VHD
ARGS_DEFINITION+=" -p,--path=PATH:."             # Path for new VHD or search
ARGS_DEFINITION+=" -r,--range=RANGE"             # Range of VHDs to operate on
ARGS_DEFINITION+=" --dry-run=DRY_RUN:true"       # Run in dry-run mode without making actual changes
export ARGS_DEFINITION

# shellcheck disable=SC1090  source=../.scripts/_colors.sh
source /dev/null
# shellcheck disable=SC1090  source=../.scripts/_logger.sh
source "$E_BASH/_logger.sh"
# shellcheck disable=SC1090  source=../.scripts/_dependencies.sh
source "$E_BASH/_dependencies.sh"
# shellcheck disable=SC1090  source=../.scripts/_arguments.sh
source "$E_BASH/_arguments.sh"

# Declare loggers
logger:init vhd "${cl_cyan}[vhd]${cl_reset} "
logger:init exec "${cl_lblue}execute:${cl_reset} "
logger:init error "${cl_red}[error]${cl_reset} "
logger:init success "${cl_green}[success]${cl_reset} "
logger:init warning "${cl_yellow}[warning]${cl_reset} "
logger:init debug " ${cl_gray}|${cl_reset} "

# Global internal variables
declare -A MOUNTED_STATUS # Association array for mounting status
declare -a VHD_FILES      # Array of found VHD files

# Set up help
args:d "-h" "Show this help message"
args:d "-l" "List all VHD files"
args:d "-m" "Mount selected VHD files"
args:d "-u" "Unmount selected VHD files"
args:d "-a" "Add new VHD file"
args:d "-s" "Size for new VHD (default: 10G)"
args:d "-p" "Path for new VHD or search directory (default: current directory)"
args:d "-r" "Range of VHDs to operate on (example: 1,2,5-10)"
args:d "--dry-run" "Run in dry-run mode without making actual changes"

# Global flag for dry run mode is now set by the --dry-run argument
# The DRY_RUN variable is populated by the arguments parser

# Trap to capture exit/interrupt and print exit code
function on_exit() {
    local exit_code=$?

    local CLR="${cl_green}"
    [ $exit_code -ne 0 ] && CLR="${cl_red}"

    echo -e "\n${cl_gray}${st_italic}exit code:${st_no_i} ${CLR}$exit_code${cl_reset}" >&2
    return $exit_code
}

trap on_exit EXIT

# Command execution wrappers
export SILENT_EXEC=false
function compose:exec() {
    local cmd=${1}

    cat <<EOF
    #
    # begin
    #
    function exec:${cmd}() {
        if [ "\$DRY_RUN" = true ]; then
            echo "${cl_gray}${cmd} \$*${cl_reset}" | log:Exec "(dry run) " 
            return 0
        fi

        local output result immediate_exit_on_error CLR="\${cl_green}"

        # Remember the error exit state
        [[ \$- == *e* ]] && immediate_exit_on_error=true || immediate_exit_on_error=false
        set +e # disable immediate exit on error

        echo:Exec -n -e "${cl_gray}${cmd} \$*${cl_reset}"
        output=\$($cmd "\$@" 2>&1)
        result=\$?
        echo -e " / code: ${cl_yellow}\$result${cl_reset}" >&2
        [ -n "\$output" ] && [ "\$SILENT_EXEC" = false ] && echo -e "\$output" | log:Debug

        [ "\$immediate_exit_on_error" = "true" ] && set -e # recover state
        return \$result
    }
    #
    # end
    #
EOF
}

# Wrapper for hdiutil command with dry-run support
eval "$(compose:exec hdiutil)"

# Wrapper for mount command with dry-run support
eval "$(compose:exec mount)"

# Wrapper for umount command with dry-run support
eval "$(compose:exec umount)"

# Wrapper for wsl command with dry-run support
eval "$(compose:exec wsl)"

# Wrapper for qemu-img command with dry-run support
eval "$(compose:exec qemu-img)"

# Function to check if qemu-img is installed
function check_dependencies() {
    dependency "qemu-img" "9.2.*" "brew install qemu"
}

# Function to find all VHD files in the given directory recursively
function find_vhd_files() {
    local search_dir="${1:-$PWD}"
    echo:Debug "Searching for VHD files in: ${cl_yellow}${search_dir}${cl_reset}"

    # Find all VHD files (with extensions: .vhd, .vhdx, .vmdk, .qcow2)
    mapfile -t VHD_FILES < <(find "$search_dir" -type f \( -name "*.vhd" -o -name "*.vhdx" -o -name "*.vmdk" -o -name "*.qcow2" \) | sort)

    if [[ ${#VHD_FILES[@]} -eq 0 ]]; then
        echo:Warning "No VHD files found in ${cl_yellow}${search_dir}${cl_reset}"
        return 1
    fi

    echo:Success "Found ${cl_green}${#VHD_FILES[@]}${cl_reset} VHD files"
    return 0
}

# Function to check if a VHD is mounted
function check_mount_status() {
    local vhd_file="$1"
    local is_mounted=0

    # Check if the VHD is mounted by looking for it in the mount points
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS - use exec:hdiutil with info param to check if mounted
        if exec:hdiutil info 2>&1 | grep -q "$(basename "$vhd_file")"; then
            is_mounted=1
        fi
    elif [[ "$(uname)" == "Linux" ]]; then
        # Linux - use exec:mount to check if mounted
        if exec:mount 2>&1 | grep -q "$vhd_file"; then
            is_mounted=1
        fi
    elif [[ "$(uname -r)" == *Microsoft* ]]; then
        # WSL2 - use exec:wsl to check if mounted
        if exec:wsl --mount 2>&1 | grep -q "$vhd_file"; then
            is_mounted=1
        fi
    fi

    MOUNTED_STATUS["$vhd_file"]=$is_mounted
    return $is_mounted
}

# create spacer with specified number of symbols and filler
function sp() {
    local num=$1
    local filler=${2:-'-'}
    printf "%${num}s\n" | tr ' ' "$filler"
}

# Function to display list of VHD files
function list_vhd_files() {
    local search_dir="${1:-$PWD}"
    echo:Vhd "Listing VHD files in: ${cl_yellow}${search_dir}${cl_reset}"

    if ! find_vhd_files "$search_dir"; then
        return 1
    fi

    # Print header
    echo ""
    printf "%4s | %-10s | %-60s | %-10s | %-20s |\n" "#" "Status" "VHD Path" "Size" "Last Modified"
    printf "%4s | %-10s | %-60s | %-10s | %-20s |\n" "$(sp 2)" "$(sp 10)" "$(sp 60)" "$(sp 10)" "$(sp 20)"

    # Print each VHD file with its details
    local index=1
    for vhd in "${VHD_FILES[@]}"; do
        check_mount_status "$vhd"
        local status="${MOUNTED_STATUS[$vhd]}"
        local status_text=$([ "$status" -eq 1 ] && echo "Mounted" || echo "Unmounted")

        # Get file details
        local file_size=$(du -h "$vhd" | cut -f1)
        local last_modified=$(date -r "$vhd" "+%Y-%m-%d %H:%M:%S")
        local vhd_path=${vhd//$HOME/\~}

        # Print formatted output
        printf "%4s | %-10s | %-60s | %-10s | %-20s |\n" "$index" "$status_text" "$vhd_path" "$file_size" "$last_modified"
        ((index++))
    done
    printf "\n"

    return 0
}

# Function to parse range input and return array of indices
function parse_range() {
    local range="$1"
    local indices=()

    echo:Debug "Parsing range: ${cl_yellow}${range}${cl_reset}"

    # Split by comma
    IFS=',' read -ra RANGES <<<"$range"

    for r in "${RANGES[@]}"; do
        # Check if range has a dash (e.g., 1-5)
        if [[ "$r" == *-* ]]; then
            local start="${r%-*}"
            local end="${r#*-}"

            # Validate start and end are numbers
            if ! [[ "$start" =~ ^[0-9]+$ ]] || ! [[ "$end" =~ ^[0-9]+$ ]]; then
                echo:Error "Invalid range format: ${cl_red}${r}${cl_reset}. Must be numbers."
                return 1
            fi

            # Add all numbers in the range
            local i=0 # make $i local to avoid conflicts
            for ((i = start; i <= end; i++)); do
                indices+=("$i")
            done
        else
            # Single number
            if ! [[ "$r" =~ ^[0-9]+$ ]]; then
                echo:Error "Invalid range format: ${cl_red}${r}${cl_reset}. Must be a number."
                return 1
            fi

            indices+=("$r")
        fi
    done

    # Remove duplicates and sort
    local unique_indices=($(printf "%s\n" "${indices[@]}" | sort -nu))

    # Validate indices against VHD_FILES array
    for idx in "${unique_indices[@]}"; do
        if ((idx < 1 || idx > ${#VHD_FILES[@]})); then
            echo:Error "Index ${cl_red}${idx}${cl_reset} is out of range. Valid range: 1-${#VHD_FILES[@]}"
            return 1
        fi
    done

    # Return the validated indices
    echo "${unique_indices[@]}"
    return 0
}

# Function to mount a VHD file
function mount_vhd() {
    local vhd_file="$1"
    local index="$2"

    echo:Vhd "Mounting VHD: ${cl_green}${vhd_file}${cl_reset}"

    # Check if already mounted
    check_mount_status "$vhd_file"
    if [[ "${MOUNTED_STATUS[$vhd_file]}" -eq 1 ]]; then
        echo:Warning "VHD is already mounted: ${cl_yellow}${vhd_file}${cl_reset}"
        return 0
    fi

    # Mount based on OS
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS
        exec:hdiutil attach "$vhd_file"
        local exit_code=$?
    elif [[ "$(uname)" == "Linux" ]]; then
        # Linux
        local mount_point="/mnt/vhd_$(basename "$vhd_file")"
        mkdir -p "$mount_point" 2>&1 | log:Mount
        exec:mount -o loop "$vhd_file" "$mount_point"
        local exit_code=$?
    elif [[ "$(uname -r)" == *Microsoft* ]]; then
        # WSL2
        exec:wsl --mount "$vhd_file"
        local exit_code=$?
    else
        echo:Error "Unsupported operating system"
        return 1
    fi

    if [[ $exit_code -eq 0 ]]; then
        echo:Success "Successfully mounted VHD #${cl_green}${index}${cl_reset}: ${cl_green}${vhd_file}${cl_reset}"
        MOUNTED_STATUS["$vhd_file"]=1
        return 0
    else
        echo:Error "Failed to mount VHD #${cl_red}${index}${cl_reset}: ${cl_red}${vhd_file}${cl_reset}"
        return 1
    fi
}

# Function to unmount a VHD file
function unmount_vhd() {
    local vhd_file="$1"
    local index="$2"

    echo:Vhd "Unmounting VHD: ${cl_yellow}${vhd_file}${cl_reset}"

    # Check if already unmounted
    check_mount_status "$vhd_file"
    if [[ "${MOUNTED_STATUS[$vhd_file]}" -eq 0 ]]; then
        echo:Warning "VHD is already unmounted: ${cl_yellow}${vhd_file}${cl_reset}"
        return 0
    fi

    # Unmount based on OS
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS
        exec:hdiutil detach "$vhd_file"
        local exit_code=$?
    elif [[ "$(uname)" == "Linux" ]]; then
        # Linux
        local mount_point="/mnt/vhd_$(basename "$vhd_file")"
        exec:umount "$mount_point"
        local exit_code=$?
        rmdir "$mount_point" 2>&1 | log:Unmount
    elif [[ "$(uname -r)" == *Microsoft* ]]; then
        # WSL2
        exec:wsl --unmount "$vhd_file"
        local exit_code=$?
    else
        echo:Error "Unsupported operating system"
        return 1
    fi

    if [[ $exit_code -eq 0 ]]; then
        echo:Success "Successfully unmounted VHD #${cl_green}${index}${cl_reset}: ${cl_green}${vhd_file}${cl_reset}"
        MOUNTED_STATUS["$vhd_file"]=0
        return 0
    else
        echo:Error "Failed to unmount VHD #${cl_red}${index}${cl_reset}: ${cl_red}${vhd_file}${cl_reset}"
        return 1
    fi
}

# Function to add a new VHD file
function add_vhd() {
    local vhd_path="${1:-$PWD}"
    local vhd_size="${2:-10G}"

    echo:Vhd "Creating new VHD with size ${cl_yellow}${vhd_size}${cl_reset} at ${cl_yellow}${vhd_path}${cl_reset}"

    # Prompt for file name if not in non-interactive mode
    local vhd_name

    # In TUI mode, prompt for filename
    if [[ -t 0 && -t 1 ]]; then
        read -p "Enter VHD file name (without extension): " vhd_name

        if [[ -z "$vhd_name" ]]; then
            echo:Error "No file name provided"
            return 1
        fi
    else
        # In non-interactive mode, generate a name
        vhd_name="vhd_$(date +%Y%m%d_%H%M%S)"
    fi

    # Add .vhd extension if none provided
    if [[ ! "$vhd_name" =~ \.(vhd|vhdx|vmdk|qcow2)$ ]]; then
        vhd_name="${vhd_name}.vhd"
    fi

    local full_path="${vhd_path}/${vhd_name}"

    # Check if file already exists
    if [[ -f "$full_path" ]]; then
        echo:Error "File already exists: ${cl_red}${full_path}${cl_reset}"
        return 1
    fi

    # Create the VHD file using qemu-img
    echo:Vhd "Creating VHD: ${cl_green}${full_path}${cl_reset} with size ${cl_yellow}${vhd_size}${cl_reset}"
    exec:qemu-img create -f vpc "$full_path" "$vhd_size"

    # Should we format to exFat newly created image?

    if [[ $? -eq 0 ]]; then
        echo:Success "Successfully created VHD: ${cl_green}${full_path}${cl_reset}"
        return 0
    else
        echo:Error "Failed to create VHD: ${cl_red}${full_path}${cl_reset}"
        return 1
    fi
}

# Function to process commands with a range
function process_with_range() {
    local command="$1"
    local range="$2"
    local search_dir="${3:-$PWD}"

    echo:Debug "Processing command: ${cl_yellow}${command}${cl_reset} with range: ${cl_yellow}${range}${cl_reset}"

    # First find VHD files
    if ! find_vhd_files "$search_dir"; then
        return 1
    fi

    # Parse the range if provided
    local indices
    if [[ -n "$range" ]]; then
        indices=($(parse_range "$range"))
        if [[ $? -ne 0 ]]; then
            return 1
        fi
    else
        # If no range provided, use all indices
        for ((i = 1; i <= ${#VHD_FILES[@]}; i++)); do
            indices+=($i)
        done
    fi

    echo:Debug "Processing indices: ${cl_yellow}${indices[*]}${cl_reset}"

    # Execute the requested command for each index
    for idx in "${indices[@]}"; do
        # Convert to 0-based index for array access
        local array_idx=$((idx - 1))
        local vhd_file="${VHD_FILES[$array_idx]}"

        case "$command" in
        mount)
            mount_vhd "$vhd_file" "$idx"
            ;;
        unmount)
            unmount_vhd "$vhd_file" "$idx"
            ;;
        *)
            echo:Error "Unknown command: ${cl_red}${command}${cl_reset}"
            return 1
            ;;
        esac
    done

    return 0
}

# remove all ansi escape sequences from input string
function onlytext() {
    local result=$(echo -n "$1" | gsed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g' | gsed -E $'s/\x1B\\([A-Z]//g')
    echo -n "$result" | tr -s ' '
}

# Function to show TUI
function show_tui() {
    # Initial listing
    list_vhd_files

    # Define command options with colored labels
    declare -A -g cmd_options && cmd_options=(
        ["mount"]="${cl_blue}Mount VHDs${cl_reset}"
        ["unmount"]="${cl_yellow}Unmount VHDs${cl_reset}"
        ["add"]="${cl_green}Add new VHD${cl_reset}"
        ["exit"]="${cl_red}Exit${cl_reset}"
    )

    # Main TUI loop
    while true; do
        echo -e -n "\n${cl_cyan}VHD Manager${cl_reset} - Select command:"
        selected=$(input:selector "cmd_options" key)
        echo ""

        case "$selected" in
        "exit")
            echo:Vhd "Exiting..."
            exit 0
            ;;
        "mount")
            list_vhd_files
            read -p "Enter VHD indices to mount (e.g., 1,2,5-10): " range
            process_with_range "mount" "$range"
            ;;
        "unmount")
            list_vhd_files
            read -p "Enter VHD indices to unmount (e.g., 1,2,5-10): " range
            process_with_range "unmount" "$range"
            ;;
        "add")
            add_vhd "${PWD}"
            list_vhd_files # Refresh the list
            ;;
        *)
            echo:Error "Unknown command: ${cl_red}${cmd}${cl_reset}"
            ;;
        esac
    done
}

# Main function
function main() {
    echo:Vhd "Starting VHD Manager..."

    # Check dependencies
    check_dependencies

    # Handle command-line arguments
    if [[ -n "$help" ]]; then
        print:help
        exit 0
    fi

    # Process based on command
    case "$COMMAND" in
    list)
        list_vhd_files
        ;;
    mount)
        process_with_range "mount" "$RANGE"
        ;;
    unmount)
        process_with_range "unmount" "$RANGE"
        ;;
    add)
        add_vhd
        ;;
    *)
        # No command specified, show TUI if terminal is interactive
        if [[ -t 0 && -t 1 ]]; then
            show_tui
        else
            echo:Error "No command specified and not in interactive mode"
            print:help
            exit 1
        fi
        ;;
    esac

    echo:Vhd "VHD Manager completed successfully"
    exit 0
}

# Run main function
main
