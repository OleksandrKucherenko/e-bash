#!/usr/bin/env bash
# clipboard-image-save.sh - Save image from Windows clipboard to disk (WSL)
# Version: 2.1.0
# Author: e-bash
# Description: Extracts images from Windows clipboard history and saves them.
#              Interactive clipboard history browser for WSL with smart graphics detection.

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-02-03
## Version: 2.4.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


set -euo pipefail

# Script metadata
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="2.1.0"

# Default output directory
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/Desktop}"
OUTPUT_PREFIX="${OUTPUT_PREFIX:-clipboard}"
INTERACTIVE="${INTERACTIVE:-true}"
PREVIEW_ENABLED="${PREVIEW_ENABLED:-true}"
SELECT_TIMEOUT="${SELECT_TIMEOUT:-15}"  # Auto-select after N seconds (0 to disable)

# Temporary files
TEMP_DIR="${TEMP_DIR:-/tmp/clipboard-save}"
TEMP_INDEX="$TEMP_DIR/index.json"
TEMP_CAPS_CACHE="$TEMP_DIR/terminal-caps.cache"

# Find PowerShell (pwsh or powershell.exe)
find_powershell() {
  local pwsh_paths=() ps_paths=()

  # Try PowerShell Core first (faster, better)
  pwsh_paths=(
    "pwsh.exe"
    "pwsh"
  )

  # Check Scoop installations
  if [[ -d "/mnt/c/Users" ]]; then
    # Current user's scoop
    if [[ -n "${USER:-}" ]] && [[ -d "/mnt/c/Users/${USER}/scoop/apps/pwsh" ]]; then
      pwsh_paths+=("/mnt/c/Users/${USER}/scoop/apps/pwsh/current/pwsh.exe")
    fi

    # All users' scoop installations
    shopt -s nullglob
    for user_dir in /mnt/c/Users/*/scoop/apps/pwsh/current; do
      [[ -f "$user_dir/pwsh.exe" ]] && pwsh_paths+=("$user_dir/pwsh.exe")
    done
    shopt -u nullglob

    # Global scoop
    pwsh_paths+=("/mnt/c/ProgramData/scoop/apps/pwsh/current/pwsh.exe")
  fi

  # Try pwsh paths
  for ps_path in "${pwsh_paths[@]}"; do
    if command -v "$ps_path" >/dev/null 2>&1; then
      echo "$ps_path"
      return 0
    fi
  done

  # Fall back to Windows PowerShell 5.1
  ps_paths=(
    "powershell.exe"
    "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
    "/mnt/c/WINDOWS/System32/WindowsPowerShell/v1.0/powershell.exe"
  )

  for ps_path in "${ps_paths[@]}"; do
    if command -v "$ps_path" >/dev/null 2>&1; then
      echo "$ps_path"
      return 0
    fi
  done

  return 1
}

# Cache PowerShell command
POWERSHELL_CMD="$(find_powershell)" || {
  echo "Error: PowerShell not found. Please ensure PowerShell is installed." >&2
  echo "Checked: pwsh.exe, powershell.exe, Scoop installations" >&2
  exit 1
}

# Detect multiplexer for graphics passthrough
get_passthrough_mode() {
  if [[ -n "${TMUX:-}" ]]; then
    echo "tmux"
  elif [[ -n "${STY:-}" ]]; then
    echo "screen"
  else
    echo "none"
  fi
}

# Detect terminal graphics capabilities
detect_terminal_graphics() {
  # Return cached result if available
  if [[ -f "$TEMP_CAPS_CACHE" ]]; then
    cat "$TEMP_CAPS_CACHE"
    return 0
  fi

  local protocol="symbols"
  local term_program="${TERM_PROGRAM:-}"
  local term="${TERM:-}"
  local in_ssh="${SSH_CONNECTION:+yes}"

  # Phase 1: Quick detection based on known terminals
  case "$term_program" in
    "WezTerm") protocol="iterm2" ;;
    "Tabby") protocol="sixels" ;;
    "iTerm.app") protocol="iterm2" ;;
    "kitty") protocol="kitty" ;;
  esac

  # Check TERM variable for hints
  if [[ "$protocol" == "symbols" ]]; then
    case "$term" in
      *kitty*) protocol="kitty" ;;
      *sixel*) protocol="sixels" ;;
      xterm-256color)
        # Over SSH, many modern terminals support sixels
        # This includes Tabby, WezTerm, and others
        if [[ -n "$in_ssh" ]]; then
          # Try sixels first for SSH sessions with modern terminals
          protocol="sixels"
        fi
        ;;
    esac
  fi

  # Cache the result
  echo "$protocol" > "$TEMP_CAPS_CACHE"
  echo "$protocol"
}

# Display image preview using chafa with smart protocol selection
display_image_preview() {
  local image_path="$1"

  # Check if chafa is available
  if ! command -v chafa >/dev/null 2>&1; then
    echo -e "\033[90m[Preview unavailable: chafa not installed]\033[0m" >&2
    echo -e "\033[90m[Install with: sudo apt install chafa]\033[0m" >&2
    return 1
  fi

  # Detect best protocol
  local protocol
  protocol=$(detect_terminal_graphics)

  # Get multiplexer passthrough mode
  local passthrough
  passthrough=$(get_passthrough_mode)

  # Get terminal dimensions
  local term_cols="${COLUMNS:-80}"
  local term_lines="${LINES:-24}"
  local preview_width=$((term_cols - 4))
  local preview_height=$((term_lines / 2))

  # Build chafa command
  local chafa_args=(
    "--size=${preview_width}x${preview_height}"
  )

  # Set format based on detected protocol
  case "$protocol" in
    kitty)
      chafa_args+=("--format=kitty")
      ;;
    sixels)
      chafa_args+=("--format=sixels")
      ;;
    iterm2)
      chafa_args+=("--format=iterm")
      ;;
    symbols|*)
      chafa_args+=("--format=symbols" "--symbols=braille+stipple")
      ;;
  esac

  # Add passthrough if needed
  if [[ "$passthrough" != "none" ]] && [[ "$protocol" != "symbols" ]]; then
    chafa_args+=("--passthrough=$passthrough")
  fi

  # Display preview
  local preview_label="Preview: $protocol"
  [[ "$passthrough" != "none" ]] && preview_label="$preview_label via $passthrough"

  echo -e "\033[90m┌─ $preview_label ─────────────────────────────────────\033[0m"
  chafa "${chafa_args[@]}" "$image_path" 2>/dev/null || {
    echo -e "\033[33m[Graphics preview failed, trying ASCII fallback]\033[0m"
    chafa --format=symbols --symbols=braille+stipple --size="${preview_width}x${preview_height}" "$image_path" 2>/dev/null
  }
  echo -e "\033[90m└───────────────────────────────────────────────────────\033[0m"
}

# Help message
show_help() {
  cat <<EOF
$SCRIPT_NAME v$SCRIPT_VERSION

Save image from Windows clipboard to disk (WSL).

USAGE:
    $SCRIPT_NAME [OPTIONS] [INDEX]

OPTIONS:
    -d, --dir DIR       Output directory (default: \$HOME/Desktop)
    -p, --prefix PREFIX Filename prefix (default: clipboard)
    -o, --output FILE   Specific output filename (overrides prefix)
    -i, --index NUM     Save clipboard item by index number
    -l, --list          List clipboard history and exit
    -n, --no-interactive Skip history menu, save current item
    --no-preview        Disable inline image preview
    -h, --help          Show this help message
    -v, --version       Show version

ARGUMENTS:
    INDEX               Direct index of clipboard item to save

INTERACTIVE MODE:
    When run without options, shows clipboard history with previews.
    Auto-selects item 0 after 15 seconds if no input (configurable via
    SELECT_TIMEOUT env var, set to 0 to disable timeout).

PREVIEW MODES (auto-detected):
    kitty     Kitty graphics protocol (kitty terminal)
    sixels    Sixel graphics (Tabby via SSH, xterm-compatible)
    iterm2    iTerm2 inline images (WezTerm via SSH, iTerm2)
    symbols   ASCII art with Unicode (universal fallback)

EXAMPLES:
    $SCRIPT_NAME              # Interactive clipboard history
    $SCRIPT_NAME -i 1         # Save item at index 1
    $SCRIPT_NAME -l           # List all items
    $SCRIPT_NAME -n           # Non-interactive, save current

REQUIREMENTS:
    - WSL environment with PowerShell accessible
    - Windows 10/11 with clipboard history enabled (Win+V)
    - chafa (optional): Install for image previews
      sudo apt install chafa  # Ubuntu/Debian

DETECTED:
    PowerShell: $POWERSHELL_CMD
    Graphics: $(detect_terminal_graphics)
    Multiplexer: $(get_passthrough_mode)

EOF
}

# Parse arguments
SELECTED_INDEX=""
LIST_ONLY=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) show_help; exit 0 ;;
    -v|--version) echo "$SCRIPT_NAME $SCRIPT_VERSION"; exit 0 ;;
    -d|--dir) OUTPUT_DIR="$2"; shift 2 ;;
    -p|--prefix) OUTPUT_PREFIX="$2"; shift 2 ;;
    -o|--output) OUTPUT_FILE="$2"; shift 2 ;;
    -i|--index) SELECTED_INDEX="$2"; shift 2 ;;
    -l|--list) LIST_ONLY=true; shift ;;
    -n|--no-interactive) INTERACTIVE=false; shift ;;
    --no-preview) PREVIEW_ENABLED=false; shift ;;
    -*) echo "Error: Unknown option: $1" >&2; show_help; exit 1 ;;
    *) SELECTED_INDEX="$1"; shift ;;
  esac
done

# Ensure temp directory exists
mkdir -p "$TEMP_DIR"

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Generate output filename if not specified
if [[ -z "${OUTPUT_FILE:-}" ]]; then
  timestamp=$(date +%Y%m%d-%H%M%S)
  OUTPUT_FILE="$OUTPUT_DIR/${OUTPUT_PREFIX}_${timestamp}.png"
fi

# Convert to Windows path for PowerShell
WIN_OUTPUT_FILE="$(wslpath -w "$OUTPUT_FILE")"

# PowerShell script for clipboard operations
get_clipboard_history() {
  local ps_script="$TEMP_DIR/get-clipboard.ps1"

  # Write PowerShell script to temp file
  cat > "$ps_script" <<'PSEOF'
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $hasImage = [System.Windows.Forms.Clipboard]::ContainsImage()
    $hasText = [System.Windows.Forms.Clipboard]::ContainsText()
    $hasFileDropList = [System.Windows.Forms.Clipboard]::ContainsFileDropList()

    $output = @{ items = @() }

    if ($hasImage) {
      try {
        $image = [System.Windows.Forms.Clipboard]::GetImage()
        if ($image) {
          $output.items += @{
            index = 0
            type = "image"
            format = "$($image.Width)x$($image.Height)px"
            timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
          }
          $image.Dispose()
        }
      } catch {
        # Ignore errors
      }
    }

    if ($hasFileDropList) {
      try {
        $files = [System.Windows.Forms.Clipboard]::GetFileDropList()
        foreach ($file in $files) {
          if ($file -match "\.(jpg|jpeg|png|gif|bmp|webp)$") {
            $output.items += @{
              index = $output.items.Count
              type = "file"
              path = $file
              name = (Split-Path $file -Leaf)
              timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
          }
        }
      } catch {
        # Ignore errors
      }
    }

    if ($hasText -and -not $hasImage) {
      try {
        $text = [System.Windows.Forms.Clipboard]::GetText()
        if ($text.Length -gt 0) {
          $preview = if ($text.Length -gt 50) { $text.Substring(0, 50) + "..." } else { $text }
          $output.items += @{
            index = $output.items.Count
            type = "text"
            preview = $preview -replace "`n", " " -replace "`r", ""
            length = $text.Length
            timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
          }
        }
      } catch {
        # Ignore errors
      }
    }

    if ($output.items.Count -eq 0) {
      $output.items += @{
        index = 0
        type = "empty"
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
      }
    }

    $output | ConvertTo-Json -Depth 3
PSEOF

  local win_script="$(wslpath -w "$ps_script")"
  "$POWERSHELL_CMD" -NoProfile -ExecutionPolicy Bypass -File "$win_script" </dev/null 2>/dev/null | tr -d '\r'
}

# Save image from clipboard
save_clipboard_image() {
  local output_file="$1"
  local win_output_file="$2"

  "$POWERSHELL_CMD" -NoProfile -Command "
    Add-Type -AssemblyName System.Windows.Forms;
    Add-Type -AssemblyName System.Drawing;

    if ([System.Windows.Forms.Clipboard]::ContainsImage()) {
      \$image = [System.Windows.Forms.Clipboard]::GetImage();
      if (\$image) {
        \$image.Save('$win_output_file', [System.Drawing.Imaging.ImageFormat]::Png);
        \$image.Dispose();
        Write-Output 'SAVED';
        exit 0;
      }
    }
    Write-Output 'EMPTY';
    exit 1;
  " </dev/null 2>/dev/null | tr -d '\r'
}

# Save image file from file drop list
save_clipboard_file() {
  local source_file="$1"
  local dest_file="$2"
  local win_source="$(wslpath -w "$source_file")"
  local win_dest="$(wslpath -w "$dest_file")"

  "$POWERSHELL_CMD" -NoProfile -Command "
    Copy-Item '$win_source' '$win_dest' -Force
    Write-Output 'COPIED'
  " </dev/null 2>/dev/null | tr -d '\r'
}

# Display clipboard history
display_history() {
  local json="$1"

  echo ""
  echo -e "\033[1;94m┌─ Clipboard History ─────────────────────────────────────\033[0m"
  echo -e "\033[1;94m│\033[0m"

  # Parse JSON using sed extraction
  local type_list format_list preview_list
  local path_list name_list length_list timestamp_list

  mapfile -t type_list < <(echo "$json" | grep '"type"' | sed 's/.*"type"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
  mapfile -t format_list < <(echo "$json" | grep '"format"' | sed 's/.*"format"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
  mapfile -t preview_list < <(echo "$json" | grep '"preview"' | sed 's/.*"preview"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
  mapfile -t path_list < <(echo "$json" | grep '"path"' | sed 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
  mapfile -t name_list < <(echo "$json" | grep '"name"' | sed 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
  mapfile -t length_list < <(echo "$json" | grep '"length"' | sed 's/.*"length"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/')
  mapfile -t timestamp_list < <(echo "$json" | grep '"timestamp"' | sed 's/.*"timestamp"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

  # Display each item
  for i in "${!type_list[@]}"; do
    display_item "$i" "${type_list[$i]:-}" "${format_list[$i]:-}" "${preview_list[$i]:-}" \
                     "${path_list[$i]:-}" "${name_list[$i]:-}" "${length_list[$i]:-}" "${timestamp_list[$i]:-}"
  done

  echo -e "\033[1;94m│\033[0m"
  echo -e "\033[1;94m└──────────────────────────────────────────────────────────\033[0m"
  echo ""
}

# Display a single clipboard item
display_item() {
  local index="$1"
  local type="$2"
  local format="$3"
  local preview="$4"
  local path="$5"
  local name="$6"
  local length="$7"
  local timestamp="$8"

  local icon="" info="" details=""

  case "$type" in
    image)
      icon="🖼️ "
      info=$'\033[92mImage\033[0m'
      details="$format"
      ;;
    file)
      icon="📁 "
      info=$'\033[93mFile\033[0m'
      details="$name"
      ;;
    text)
      icon="📝 "
      info=$'\033[96mText\033[0m'
      details="${preview//\$/\\\$} ($length chars)"
      ;;
    empty)
      icon="⚪ "
      info=$'\033[90mEmpty\033[0m'
      details="No clipboard content"
      ;;
  esac

  printf "│  %s  [\033[1m%2d\033[0m]  %s  \033[90m%s\033[0m  " "$icon" "$index" "$info" "$timestamp"
  echo ""
  if [[ -n "$details" ]]; then
    printf "│      %s\n" "$details"
  fi
}

# Main execution
echo -e "\033[90m⟳ Reading clipboard...\033[0m" >&2
CLIPBOARD_JSON=$(get_clipboard_history)

# Store for later use
echo "$CLIPBOARD_JSON" > "$TEMP_INDEX"

# Display history
display_history "$CLIPBOARD_JSON"

# List only mode
if [[ "$LIST_ONLY" == "true" ]]; then
  exit 0
fi

# Determine which index to use
if [[ -n "$SELECTED_INDEX" ]]; then
  # User specified index
  TARGET_INDEX="$SELECTED_INDEX"
elif [[ "$INTERACTIVE" == "true" ]]; then
  # Prompt for selection with timeout
  if [[ "$SELECT_TIMEOUT" -gt 0 ]]; then
    echo -en "\033[1mSelect item to save [0-9] (auto-select 0 in ${SELECT_TIMEOUT}s): \033[0m" >&2
    read -t "$SELECT_TIMEOUT" -r TARGET_INDEX 2>/dev/null || TARGET_INDEX="0"
    echo "" >&2
    if [[ "$TARGET_INDEX" == "0" ]]; then
      echo -e "\033[90mTimeout: auto-selected item 0\033[0m" >&2
    fi
  else
    echo -en "\033[1mSelect item to save [0-9]: \033[0m" >&2
    read -r TARGET_INDEX
    echo "" >&2
  fi
else
  # Default to first item
  TARGET_INDEX="0"
fi

# Validate index
if [[ ! "$TARGET_INDEX" =~ ^[0-9]+$ ]]; then
  echo -e "\033[31m✗ Invalid index: $TARGET_INDEX\033[0m" >&2
  exit 1
fi

# Extract item type at index
ITEM_TYPE=$(echo "$CLIPBOARD_JSON" | grep '"type"' | head -1 | cut -d'"' -f4)

# Save based on type
case "$ITEM_TYPE" in
  image)
    echo -e "\033[90m⟳ Saving image...\033[0m" >&2
    result=$(save_clipboard_image "$OUTPUT_FILE" "$WIN_OUTPUT_FILE")

    if [[ "$result" == "SAVED" ]]; then
      echo -e "\033[32m✓ Saved:\033[0m $OUTPUT_FILE" >&2
      echo ""

      # Show preview if enabled
      if [[ "$PREVIEW_ENABLED" == "true" ]]; then
        display_image_preview "$OUTPUT_FILE"
        echo ""
      fi

      echo -e "\033[1mFor LLM (copy this line):\033[0m"
      echo "Please analyze the image at: $OUTPUT_FILE"
      echo ""
      echo -e "\033[90mQuick reference:\033[0m $OUTPUT_FILE"
    else
      echo -e "\033[31m✗ Failed to save image\033[0m" >&2
      exit 1
    fi
    ;;
  file)
    FILE_PATH=$(echo "$CLIPBOARD_JSON" | grep '"path"' | head -1 | cut -d'"' -f4)
    FILE_PATH="${FILE_PATH//\\/\/}"

    echo -e "\033[90m⟳ Copying file...\033[0m" >&2
    result=$(save_clipboard_file "$FILE_PATH" "$OUTPUT_FILE")

    if [[ "$result" == "COPIED" ]]; then
      echo -e "\033[32m✓ Saved:\033[0m $OUTPUT_FILE" >&2
      echo ""

      # Show preview if enabled
      if [[ "$PREVIEW_ENABLED" == "true" ]]; then
        display_image_preview "$OUTPUT_FILE"
        echo ""
      fi

      echo -e "\033[1mFor LLM (copy this line):\033[0m"
      echo "Please analyze the image at: $OUTPUT_FILE"
      echo ""
      echo -e "\033[90mQuick reference:\033[0m $OUTPUT_FILE"
    else
      echo -e "\033[31m✗ Failed to copy file\033[0m" >&2
      exit 1
    fi
    ;;
  text)
    echo -e "\033[33m⚠ Text content - use clipboard paste directly\033[0m" >&2
    ;;
  empty|"")
    echo -e "\033[31m✗ No image found in clipboard\033[0m" >&2
    echo "" >&2
    echo "Make sure you've copied an image to the clipboard first:" >&2
    echo "  - Windows: Right-click image → Copy" >&2
    echo "  - Screenshot: Win+Shift+S, then copy" >&2
    exit 1
    ;;
  *)
    echo -e "\033[31m✗ Unknown item type: $ITEM_TYPE\033[0m" >&2
    exit 1
    ;;
esac
