#!/usr/bin/env bash
# shellcheck disable=SC2155

# Lefthook hook to update "Last revisit" date in modified files
# Ported from .githook/pre-commit-copyright-last-revisit

set -e

# Get current date in YYYY-MM-DD format
CURRENT_DATE=$(date +%Y-%m-%d)

# Get the repository root directory
REPO_ROOT=$(git rev-parse --show-toplevel)

readonly cl_grey=$(tput setaf 8)
readonly cl_reset=$(tput sgr0)

# Get staged files from lefthook (uses LEFTHOOK_STAGED_FILES or falls back to git diff)
if [[ -n "${LEFTHOOK_STAGED_FILES}" ]]; then
  readarray -t STAGED_FILES < <(echo "$LEFTHOOK_STAGED_FILES" | grep '\.sh$' || true)
else
  readarray -t STAGED_FILES < <(git diff --cached --name-only --diff-filter=ACMR -- "*.sh")
fi

# Prefer custom GNU tools from bin/gnubin if available, then fallback to Linux aliases
if [[ -d "$REPO_ROOT/bin/gnubin" ]]; then
  export PATH="$REPO_ROOT/bin/gnubin:$PATH"
fi

# Fallback to Linux aliases if custom GNU tools are not available
if [[ "$(uname)" == "Linux" ]]; then
  command -v ggrep >/dev/null 2>&1 || alias ggrep='grep'
  command -v gsed >/dev/null 2>&1 || alias gsed='sed'
fi

# Check if the array is empty
if [[ ${#STAGED_FILES[@]} -eq 0 ]]; then
  exit 0
fi

# Process all files
for FILE in "${STAGED_FILES[@]}"; do
  # Skip if file doesn't exist
  [ ! -f "$FILE" ] && continue

  # Never mutate test fixtures (keeps specs stable)
  [[ "$FILE" == spec/fixtures/* ]] && continue

  # Check if file contains "## Last revisit:" line
  if ggrep -q "## Last revisit:" "$FILE"; then
    # Update the "## Last revisit:" line with current date
    MAX_BACKUP=$(find . -type f -name "$FILE.~*~" 2>/dev/null | gsed -E 's/.*~([0-9]+)~.*/\1/' | sort -n | tail -1)

    # increase backup number
    MAX_BACKUP=$((MAX_BACKUP + 1))

    # do the modification
    gsed --in-place=".~$MAX_BACKUP~" "s/## Last revisit: [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}/## Last revisit: $CURRENT_DATE/g" "$FILE"

    # Re-stage the file if it was modified
    git add "$FILE"
    echo "✅ Updated 'Last revisit' date in $FILE"
  fi
done

exit 0
