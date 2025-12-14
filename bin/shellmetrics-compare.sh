#!/usr/bin/env bash
#
# shellmetrics-compare.sh - Collect and compare shell script metrics
#
# This script collects code metrics for shell scripts using shellmetrics,
# compares them between branches, and generates formatted reports.
#
# Usage:
#   shellmetrics-compare.sh collect <output-file>
#   shellmetrics-compare.sh compare <base-file> <current-file> <output-md>
#

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-14
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


set -euo pipefail

# Ensure shellmetrics is installed
ensure_shellmetrics() {
  if ! command -v shellmetrics &> /dev/null; then
    echo "Installing shellmetrics..."
    curl -fsSL https://raw.githubusercontent.com/shellspec/shellmetrics/master/shellmetrics > "${HOME}/.local/bin/shellmetrics"
    chmod +x "${HOME}/.local/bin/shellmetrics"
    export PATH="${HOME}/.local/bin:${PATH}"
  fi
}

# Collect metrics for all shell scripts in the project
collect_metrics() {
  local output_file="${1:-metrics.csv}"

  echo "Collecting metrics for e-bash shell scripts..."

  # Create temporary file for combined output
  local temp_file
  temp_file=$(mktemp)

  # Collect metrics for .scripts/*.sh
  if [ -d .scripts ]; then
    echo "Analyzing .scripts/*.sh"
    shellmetrics --csv .scripts/*.sh >> "$temp_file" 2>/dev/null || true
  fi

  # Collect metrics for bin/*.sh (and other bin scripts)
  if [ -d bin ]; then
    echo "Analyzing bin/*"
    # shellmetrics handles various shell script types
    find bin -type f -executable | while read -r script; do
      # Check if it's a shell script (has shebang with shell)
      if head -n 1 "$script" 2>/dev/null | grep -qE '^#!.*/(bash|sh|zsh|ksh)'; then
        shellmetrics --csv "$script" >> "$temp_file" 2>/dev/null || true
      fi
    done
  fi

  # Add header if temp file is not empty, otherwise just create an empty CSV with headers
  if [ -s "$temp_file" ]; then
    # Shellmetrics CSV already has headers, just copy it
    cat "$temp_file" > "$output_file"
  else
    # Create empty CSV with headers
    echo "file,func,lineno,lloc,ccn,lines,comment,blank" > "$output_file"
  fi

  rm -f "$temp_file"

  echo "Metrics collected: $(wc -l < "$output_file") entries"
  echo "Saved to: $output_file"
}

# Parse CSV and calculate totals
calculate_totals() {
  local csv_file="$1"

  # Skip header, count unique files and sum metrics
  # CSV columns: file,func,lineno,lloc,ccn,lines,comment,blank
  # We need: files, nloc (lines-comment-blank), lloc, ccn
  awk -F',' '
    NR>1 && $2 !~ /<begin>/ && $2 !~ /<end>/ {
      files[$1] = 1
      lloc += $4
      ccn += $5
      # NLOC = lines - comment - blank (from <begin> and <end> records)
    }
    NR>1 && $2 ~ /<begin>/ {
      nloc += ($6 - $7 - $8)
    }
    END {
      file_count = 0
      for (f in files) file_count++
      printf "%d,%d,%d,%d\n", file_count, nloc, lloc, ccn
    }' "$csv_file"
}

# Parse CSV and get file-level metrics (exclude function-level details)
get_file_metrics() {
  local csv_file="$1"

  # Group by file and sum metrics
  # CSV columns: file,func,lineno,lloc,ccn,lines,comment,blank
  awk -F',' '
    NR>1 && $2 !~ /<begin>/ && $2 !~ /<end>/ {
      file = $1
      gsub(/"/, "", file)  # Remove quotes
      lloc[file] += $4
      ccn[file] += $5
    }
    NR>1 && $2 ~ /<begin>/ {
      file = $1
      gsub(/"/, "", file)
      nloc[file] = $6 - $7 - $8
    }
    END {
      for (f in nloc) {
        printf "%s,%d,%d,%d\n", f, nloc[f], lloc[f], ccn[f]
      }
    }' "$csv_file" | sort
}

# Compare two metric files and generate markdown report
compare_metrics() {
  local base_file="$1"
  local current_file="$2"
  local output_md="${3:-metrics-comparison.md}"

  # Check for missing files and handle gracefully
  if [ ! -f "$base_file" ]; then
    echo "⚠️  Warning: Base metrics file not found: $base_file"
    echo "   Creating empty baseline for comparison"
    # Create temp file if parent directory doesn't exist
    if [ ! -d "$(dirname "$base_file")" ]; then
      base_file=$(mktemp --suffix=-base-metrics.csv 2>/dev/null || echo "/tmp/base-metrics-$$.csv")
    fi
    echo "file,func,lineno,lloc,ccn,lines,comment,blank" > "$base_file" 2>/dev/null || true
  fi

  if [ ! -f "$current_file" ]; then
    echo "⚠️  Warning: Current metrics file not found: $current_file"
    echo "   Creating empty metrics file"
    # Create temp file if parent directory doesn't exist
    if [ ! -d "$(dirname "$current_file")" ]; then
      current_file=$(mktemp --suffix=-current-metrics.csv 2>/dev/null || echo "/tmp/current-metrics-$$.csv")
    fi
    echo "file,func,lineno,lloc,ccn,lines,comment,blank" > "$current_file" 2>/dev/null || true
  fi

  # Calculate totals
  IFS=',' read -r base_files base_nloc base_lloc base_ccn <<< "$(calculate_totals "$base_file")"
  IFS=',' read -r curr_files curr_nloc curr_lloc curr_ccn <<< "$(calculate_totals "$current_file")"

  # Calculate deltas
  local delta_files=$((curr_files - base_files))
  local delta_nloc=$((curr_nloc - base_nloc))
  local delta_lloc=$((curr_lloc - base_lloc))
  local delta_ccn=$((curr_ccn - base_ccn))

  # Calculate average complexity per file
  local base_avg_ccn=0
  local curr_avg_ccn=0
  [ "$base_files" -gt 0 ] && base_avg_ccn=$((base_ccn / base_files))
  [ "$curr_files" -gt 0 ] && curr_avg_ccn=$((curr_ccn / curr_files))
  local delta_avg_ccn=$((curr_avg_ccn - base_avg_ccn))

  # Format delta with sign and emoji
  format_delta() {
    local value=$1
    local reverse=${2:-false}  # For metrics where decrease is good

    if [ "$value" -gt 0 ]; then
      local emoji="📈"
      [ "$reverse" = "true" ] && emoji="⚠️"
      echo "+$value $emoji"
    elif [ "$value" -lt 0 ]; then
      local emoji="📉"
      [ "$reverse" = "true" ] && emoji="✅"
      echo "$value $emoji"
    else
      echo "0 ━"
    fi
  }

  # Generate markdown report
  cat > "$output_md" <<EOF
## 📊 ShellMetrics Code Complexity Report

### Summary
This report shows code complexity metrics for all shell scripts in the repository.

| Metric | Base | Current | Change |
|--------|------|---------|--------|
| **Files Analyzed** | $base_files | $curr_files | $(format_delta $delta_files) |
| **NLOC** (Non-comment Lines) | $base_nloc | $curr_nloc | $(format_delta $delta_nloc) |
| **LLOC** (Logical Lines) | $base_lloc | $curr_lloc | $(format_delta $delta_lloc) |
| **CCN** (Cyclomatic Complexity) | $base_ccn | $curr_ccn | $(format_delta $delta_ccn true) |
| **Avg Complexity/File** | $base_avg_ccn | $curr_avg_ccn | $(format_delta $delta_avg_ccn true) |

### 📈 Metrics Explained
- **NLOC**: Non-comment lines of code (actual executable code)
- **LLOC**: Logical lines of code (meaningful code statements)
- **CCN**: Cyclomatic Complexity Number (code path complexity - lower is better)

EOF

  # Generate per-file comparison
  echo "### 📁 Changes by File" >> "$output_md"
  echo "" >> "$output_md"

  # Get file metrics for both versions
  local base_files_csv
  local curr_files_csv
  base_files_csv=$(mktemp)
  curr_files_csv=$(mktemp)

  get_file_metrics "$base_file" > "$base_files_csv"
  get_file_metrics "$current_file" > "$curr_files_csv"

  # Find files with changes
  local has_changes=false
  local temp_changes
  temp_changes=$(mktemp)

  # Process all unique files
  while read -r file; do
    # Get metrics for this file from both versions
    local base_metrics
    local curr_metrics
    base_metrics=$(grep "^${file}," "$base_files_csv" 2>/dev/null || echo "$file,0,0,0")
    curr_metrics=$(grep "^${file}," "$curr_files_csv" 2>/dev/null || echo "$file,0,0,0")

    read -r _ b_nloc b_lloc b_ccn <<< "${base_metrics//,/ }"
    read -r _ c_nloc c_lloc c_ccn <<< "${curr_metrics//,/ }"

    # Check if there are any changes
    if [ "$b_nloc" != "$c_nloc" ] || [ "$b_lloc" != "$c_lloc" ] || [ "$b_ccn" != "$c_ccn" ]; then
      has_changes=true

      local d_nloc=$((c_nloc - b_nloc))
      local d_lloc=$((c_lloc - b_lloc))
      local d_ccn=$((c_ccn - b_ccn))

      # Format changes
      local nloc_change=""
      local lloc_change=""
      local ccn_change=""

      [ "$d_nloc" -ne 0 ] && nloc_change=" ($([[ $d_nloc -gt 0 ]] && echo "+")$d_nloc)"
      [ "$d_lloc" -ne 0 ] && lloc_change=" ($([[ $d_lloc -gt 0 ]] && echo "+")$d_lloc)"
      [ "$d_ccn" -ne 0 ] && ccn_change=" ($([[ $d_ccn -gt 0 ]] && echo "+")$d_ccn)"

      echo "| \`$file\` | $c_nloc$nloc_change | $c_lloc$lloc_change | $c_ccn$ccn_change |" >> "$temp_changes"
    fi
  done < <({ cut -d',' -f1 "$base_files_csv"; cut -d',' -f1 "$curr_files_csv"; } | sort -u)

  if [ "$has_changes" = "true" ]; then
    echo "| File | NLOC | LLOC | CCN |" >> "$output_md"
    echo "|------|------|------|-----|" >> "$output_md"
    cat "$temp_changes" >> "$output_md"
  else
    echo "No changes detected in tracked files." >> "$output_md"
  fi

  rm -f "$temp_changes"

  echo "" >> "$output_md"
  echo "---" >> "$output_md"
  echo "*Generated by [ShellMetrics](https://github.com/shellspec/shellmetrics)*" >> "$output_md"

  rm -f "$base_files_csv" "$curr_files_csv"

  echo "Comparison report saved to: $output_md"
}

# Main command dispatcher
main() {
  local command="${1:-help}"

  case "$command" in
    collect)
      ensure_shellmetrics
      collect_metrics "${2:-metrics.csv}"
      ;;
    compare)
      compare_metrics "${2:-base-metrics.csv}" "${3:-current-metrics.csv}" "${4:-metrics-comparison.md}"
      ;;
    help|--help|-h)
      cat <<HELP
Usage: shellmetrics-compare.sh <command> [options]

Commands:
  collect <output-file>                      Collect metrics for current branch
  compare <base-file> <current-file> <md>    Compare two metric files

Examples:
  # Collect current metrics
  shellmetrics-compare.sh collect metrics.csv

  # Compare base and current metrics
  shellmetrics-compare.sh compare base.csv current.csv report.md

HELP
      ;;
    *)
      echo "Error: Unknown command '$command'"
      echo "Run 'shellmetrics-compare.sh help' for usage information"
      exit 1
      ;;
  esac
}

# This is the writing style presented by ShellSpec, which is short but unfamiliar.
# Note that it returns the current exit status (could be non-zero).
# DO NOT allow execution of code below this line in shellspec tests
${__SOURCED__:+return}

# Only execute main if script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
