#!/usr/bin/env bash
# Auto-update documentation on commit
# Part of e-bash documentation system

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-25
## Version: 2.7.6
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


# shellcheck disable=SC2155
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Check if e-docs exists
if [[ ! -x "$SCRIPT_DIR/bin/e-docs.sh" ]]; then
  echo "⚠️  e-docs.sh not found, skipping documentation update"
  exit 0
fi

# Check if any .scripts/*.sh files are staged
staged_scripts=$(git diff --cached --name-only | grep '\.scripts/.*\.sh$' || true)

if [[ -n "$staged_scripts" ]]; then
  echo "📚 Updating documentation for modified scripts..."
  
  # Process each staged script
  while IFS= read -r script; do
    if [[ -f "$script" ]]; then
      basename=$(basename "$script" .sh)
      output="docs/public/lib/${basename}.md"
      
      echo "  → $script → $output"
      "$SCRIPT_DIR/bin/e-docs.sh" "$script" > "$output" 2>/dev/null || {
        echo "  ⚠️  Failed to generate docs for $script"
        continue
      }
      
      # Stage the updated docs
      git add "$output" 2>/dev/null || true
    fi
  done <<< "$staged_scripts"
  
  echo "✅ Documentation updated and staged"
fi

exit 0
