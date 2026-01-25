#!/usr/bin/env bash
# shellcheck disable=SC2155

# Lefthook pre-commit hook to verify copyright notices in *.sh files
# Ported from .githook/pre-commit-copyright

# Get the current date in YYYY-MM-DD format
CURRENT_DATE=$(date +%Y-%m-%d)

# Get the repository root directory
REPO_ROOT=$(git rev-parse --show-toplevel)

# Auto-detect project version using semantic version calculator
detect_project_version() {
  local semver_script="$REPO_ROOT/bin/git.semantic-version.sh"

  # Check if semantic version script exists
  if [[ ! -f "$semver_script" ]]; then
    # Fallback to last git tag if script not found
    local last_tag=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')
    if [[ -n "$last_tag" ]] && [[ "$last_tag" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "$last_tag"
    else
      echo "1.0.0"
    fi
    return
  fi

  # Compute version from conventional commits
  # Strip ANSI color codes before parsing
  local computed_version=$("$semver_script" 2>/dev/null | \
    grep "Final Version:" | \
    sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | \
    sed -E 's/.*Final Version: *([0-9]+\.[0-9]+\.[0-9]+).*/\1/')

  # Return computed version or fallback
  if [[ -n "$computed_version" ]] && [[ "$computed_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "$computed_version"
  else
    # Fallback to last git tag
    local last_tag=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')
    if [[ -n "$last_tag" ]] && [[ "$last_tag" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "$last_tag"
    else
      echo "1.0.0"
    fi
  fi
}

# Detect the current project version
VERSION=$(detect_project_version)

# Path to the COPYRIGHT template file
COPYRIGHT_TEMPLATE="$REPO_ROOT/COPYRIGHT"

# Get staged files from lefthook (uses LEFTHOOK_STAGED_FILES or falls back to git diff)
if [[ -n "${LEFTHOOK_STAGED_FILES}" ]]; then
  readarray -t STAGED_SH_FILES < <(echo "$LEFTHOOK_STAGED_FILES" | grep '\.sh$' || true)
else
  readarray -t STAGED_SH_FILES < <(git diff --cached --name-only --diff-filter=ACMR -- "*.sh")
fi

readonly cl_grey=$(tput setaf 8)
readonly cl_cyan=$(tput setaf 6)
readonly cl_reset=$(tput sgr0)

# Prefer custom GNU tools from bin/gnubin if available, then fallback to Linux aliases
if [[ -d "$REPO_ROOT/bin/gnubin" ]]; then
  export PATH="$REPO_ROOT/bin/gnubin:$PATH"
fi

# Fallback to Linux aliases if custom GNU tools are not available
if [[ "$(uname)" == "Linux" ]]; then
  command -v ggrep >/dev/null 2>&1 || alias ggrep='grep'
  command -v gsed >/dev/null 2>&1 || alias gsed='sed'
fi

# Function to load the copyright template and replace placeholders
get_copyright_template() {
  local resolve=${1:-"true"}
  local version="$VERSION"

  # Try to extract version from the file
  if [[ -f "$1" ]]; then
    local extracted_version=$(ggrep -E "^## Version: [0-9]+\.[0-9]+\.[0-9]+" "$1" | gsed -E 's/^## Version: ([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
    if [[ -n "$extracted_version" ]]; then
      version="$extracted_version"
    fi
  fi

  # Load the template and replace variables
  if [[ -f "$COPYRIGHT_TEMPLATE" ]]; then
    if [[ "$resolve" == "true" ]]; then
      ggrep "## " "$COPYRIGHT_TEMPLATE" | gsed -e "s/{{DATE}}/$CURRENT_DATE/g; s/{{VERSION}}/$version/g"
    else
      ggrep "## " "$COPYRIGHT_TEMPLATE"
    fi
  else
    echo "Error: $COPYRIGHT_TEMPLATE not found" >&2
    exit 1
  fi
}

# Function to verify if the copyright notice in the file is valid
verify_copyright() {
  local file=$1

  # Check if file has a copyright notice with ## prefix
  if ! ggrep -q "^## Copyright" "$file"; then
    return 1 # No copyright found
  fi

  # Get expected copyright content for comparison
  local expected_copyright=$(get_copyright_template false)
  local expected_lines=$(echo "$expected_copyright" | wc -l)

  # Extract actual copyright lines from file
  local actual_copyright=$(ggrep -A $((expected_lines - 1)) "^## Copyright" "$file" | head -n "$expected_lines" | grep "## ")

  # Compare line count first
  if [[ $(echo "$actual_copyright" | wc -l) -ne "$expected_lines" ]]; then
    return 2 # Different number of lines
  fi

  # Check each line for proper format
  for line in $(seq 1 "$expected_lines"); do
    local expected_line=$(echo "$expected_copyright" | gsed -n "${line}p")
    local actual_line=$(echo "$actual_copyright" | gsed -n "${line}p")

    # replace "Key: Value" in template string by "Key: " without Value.
    expected_line=$(echo "$expected_line" | gawk -F: '{print $1 ": "}')
    actual_line=$(echo "$actual_line" | gawk -F: '{print $1 ": "}')

    if ! echo "$actual_line" | ggrep -q "$(echo "$expected_line" | gsed 's/{{VERSION}}/[0-9]\+\.[0-9]\+\.[0-9]\+/g')"; then
      return 3 # Format mismatch
    fi
  done

  return 0 # Copyright is valid
}

# Function to prepare a file with copyright content
prepare_file_with_copyright() {
  local source_file=$1
  local temp_file=$2
  local copyright_content=$(get_copyright_template)

  # copy as is all comments (and shebang) from the begining of the file
  skip_lines=0
  while IFS= read -r line; do
    # process all comments at the begining of the file till empty line or "##"
    if [[ "$line" == "##"* || -z "$line" || "$line" != "#"* ]]; then
      break
    fi
    # on first line do the "write" instead of "append"
    [[ $skip_lines -eq 0 ]] && (echo "$line" >"$temp_file") || (echo "$line" >>"$temp_file")
    ((skip_lines++))
  done <"$source_file"

  # Write the copyright content after the shebang
  echo "" >>"$temp_file"
  echo "$copyright_content" >>"$temp_file"
  echo "" >>"$temp_file"

  # Append the rest of the original file (excluding the processed lines)
  tail -n +$((skip_lines + 1)) "$source_file" >>"$temp_file"
}

# Check if any .sh files are staged
if [[ ${#STAGED_SH_FILES[@]} -eq 0 ]]; then
  exit 0
fi

# Show detected version
echo "${cl_grey}Copyright hook using version: ${cl_cyan}${VERSION}${cl_reset}"

# Flag to track if we should abort the commit
ABORT_COMMIT=0

# Arrays to store files with issues
declare -a INVALID_COPYRIGHT_FILES=()
declare -a OLD_FORMAT_FILES=()

# Process all files
for FILE in "${STAGED_SH_FILES[@]}"; do
  # Skip if file doesn't exist
  [[ ! -f "$FILE" ]] && continue

  # Never mutate test fixtures (keeps specs stable)
  [[ "$FILE" == spec/fixtures/* ]] && continue

  # Verify copyright in file
  verify_copyright "$FILE"
  copyright_status=$?

  # If copyright is valid (return code 0), check/update version
  if [[ $copyright_status -eq 0 ]]; then
    # Extract version from file
    current_file_version=$(ggrep "^## Version: " "$FILE" | gsed 's/^## Version: *//')

    # Check if version exists and is different
    if [[ -n "$current_file_version" && "$current_file_version" != "$VERSION" ]]; then
      # Update version in place
      gsed -i "s/^## Version: .*/## Version: $VERSION/" "$FILE"
      git add "$FILE"
      echo "📝 $FILE - updated version: $current_file_version -> $VERSION"
    else
      echo "✅ $FILE - valid copyright"
    fi
    continue
  fi

  # If return code is not 1, it means copyright exists but is invalid
  if [[ $copyright_status -ne 1 ]]; then
    INVALID_COPYRIGHT_FILES+=("$FILE, code: ${copyright_status}")
    ABORT_COMMIT=1
    continue
  fi

  # Check if file has copyright notice without ## prefix (old format)
  if ggrep -q "Copyright" "$FILE"; then
    OLD_FORMAT_FILES+=("$FILE")
    ABORT_COMMIT=1
    continue
  fi

  # Create a temporary file for the new content
  TEMP_FILE=$(mktemp)

  # Prepare the file with copyright
  prepare_file_with_copyright "$FILE" "$TEMP_FILE"

  # Use GNU mv with backup option
  gmv --backup=numbered --force "$TEMP_FILE" "$FILE"

  # Restage the file
  git add "$FILE"

  # Print success message
  echo "📝 $FILE - added copyright"
done

# Display summary of issues
if [[ ${#INVALID_COPYRIGHT_FILES[@]} -gt 0 ]]; then
  echo "⚠️  Files with non standard copyright (fix manually):"
  for FILE in "${INVALID_COPYRIGHT_FILES[@]}"; do
    echo "   - $FILE"
  done
  echo ""
  echo "Codes:"
  echo "   2 - Different number of lines"
  echo "   3 - Format mismatch"
  echo ""
  echo "Expected format:"
  get_copyright_template
  echo ""
fi

if [[ ${#OLD_FORMAT_FILES[@]} -gt 0 ]]; then
  echo "⚠️  Files with old copyright format (fix manually):"
  for FILE in "${OLD_FORMAT_FILES[@]}"; do
    echo "   - $FILE"
  done
  echo ""
fi

# Abort if any issues were found
if [[ "$ABORT_COMMIT" -eq 1 ]]; then
  echo "Commit aborted. Please fix the copyright issues and try again."
  exit 1
fi

exit 0
