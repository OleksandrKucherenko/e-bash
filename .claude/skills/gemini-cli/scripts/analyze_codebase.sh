#!/bin/bash
# analyze_codebase.sh - Comprehensive codebase analysis using Gemini CLI
# Usage: ./analyze_codebase.sh <project_path> [focus_area]

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-23
## Version: 1.12.6
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


set -e

PROJECT_PATH="${1:-.}"
FOCUS="${2:-}"

if [[ ! -d "$PROJECT_PATH" ]]; then
    echo "Error: Directory '$PROJECT_PATH' does not exist"
    exit 1
fi

cd "$PROJECT_PATH"

# Build the analysis prompt
PROMPT="Analyze this codebase comprehensively.

Provide analysis covering:
1. **Architecture Overview** - High-level structure, patterns used, component relationships
2. **Code Quality** - Naming conventions, documentation, complexity, duplication
3. **Security Assessment** - Potential vulnerabilities, hardcoded secrets, input validation
4. **Performance Concerns** - Bottlenecks, inefficient patterns, resource usage
5. **Testing Coverage** - Test patterns, gaps, quality of existing tests
6. **Dependencies** - Outdated packages, security issues, unnecessary dependencies
7. **Improvement Recommendations** - Prioritized list of actionable improvements"

if [[ -n "$FOCUS" ]]; then
    PROMPT="$PROMPT

**Special Focus**: Pay particular attention to: $FOCUS"
fi

echo "=== Gemini Codebase Analysis ==="
echo "Project: $PROJECT_PATH"
echo "Focus: ${FOCUS:-General analysis}"
echo "================================"
echo ""

gemini "$PROMPT"
