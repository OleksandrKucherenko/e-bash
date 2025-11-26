#!/bin/bash
# second_opinion.sh - Get Gemini's second opinion on an analysis
# Usage: ./second_opinion.sh <analysis_file> [context_description]
# Or pipe analysis: echo "analysis" | ./second_opinion.sh - [context_description]

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-11-26
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


set -e

ANALYSIS_SOURCE="${1:--}"
CONTEXT="${2:-}"

# Read analysis from file or stdin
if [[ "$ANALYSIS_SOURCE" == "-" ]]; then
    ANALYSIS=$(cat)
elif [[ -f "$ANALYSIS_SOURCE" ]]; then
    ANALYSIS=$(cat "$ANALYSIS_SOURCE")
else
    echo "Error: File '$ANALYSIS_SOURCE' not found"
    echo "Usage: ./second_opinion.sh <analysis_file> [context]"
    echo "   or: echo 'analysis' | ./second_opinion.sh - [context]"
    exit 1
fi

PROMPT="I received this analysis and need your critical second opinion:

---BEGIN ANALYSIS---
$ANALYSIS
---END ANALYSIS---

Please review this analysis critically and provide:

1. **Agreement Points** - What do you agree with and why?
2. **Disagreement Points** - What do you disagree with? Provide alternatives.
3. **Missing Considerations** - What important aspects were overlooked?
4. **Risk Assessment** - Are there risks not addressed in this analysis?
5. **Alternative Approaches** - What other solutions should be considered?
6. **Final Recommendation** - Your overall assessment and suggested next steps."

if [[ -n "$CONTEXT" ]]; then
    PROMPT="Context for this analysis: $CONTEXT

$PROMPT"
fi

echo "=== Gemini Second Opinion ==="
echo "Analyzing provided content..."
echo "=============================="
echo ""

gemini "$PROMPT"
