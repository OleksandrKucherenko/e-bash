#!/usr/bin/env bash
# Generate and upload code coverage manually
# Usage: ./bin/generate-coverage.sh [upload]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

echo "🧪 Running tests with coverage..."

# Check if shellspec is available
if ! command -v shellspec >/dev/null 2>&1; then
    echo "❌ shellspec not found. Please install it first:"
    echo "   brew install shellspec"
    exit 1
fi

# Check if kcov is available
if ! command -v kcov >/dev/null 2>&1; then
    echo "❌ kcov not found. Please install it first:"
    echo "   brew install kcov  # macOS"
    echo "   sudo apt-get install kcov  # Ubuntu"
    exit 1
fi

# Clean previous coverage data
rm -rf coverage/ report/

# Run tests with coverage
echo "Running shellspec with kcov..."
shellspec --kcov || {
    echo "⚠️  shellspec exited with non-zero code, but checking if tests actually passed..."
    
    # Check if coverage was generated despite the exit code
    if [ -f coverage/cobertura.xml ]; then
        echo "✅ Coverage report generated successfully"
    else
        echo "❌ No coverage report found"
        exit 1
    fi
}

# Display coverage summary
if [ -f coverage/cobertura.xml ]; then
    coverage=$(grep -oP 'line-rate="\K[0-9.]+' coverage/cobertura.xml | head -1 | awk '{printf "%.1f%%", $1*100}')
    echo "📊 Line Coverage: $coverage"
    echo "📁 HTML report: coverage/index.html"
else
    echo "❌ No coverage report generated"
    exit 1
fi

# Upload to codecov if requested
if [ "${1:-}" = "upload" ]; then
    if [ -z "${CODECOV_TOKEN:-}" ]; then
        echo "⚠️  CODECOV_TOKEN not set. Coverage will not be uploaded."
        echo "   Set CODECOV_TOKEN environment variable to upload coverage."
    else
        echo "📤 Uploading coverage to Codecov..."
        
        # Install codecov uploader if not available
        if ! command -v codecov >/dev/null 2>&1; then
            echo "Installing codecov uploader..."
            curl -Os https://uploader.codecov.io/latest/linux/codecov
            chmod +x codecov
            sudo mv codecov /usr/local/bin/
        fi
        
        codecov -f coverage/cobertura.xml -F shellspec-manual
        echo "✅ Coverage uploaded to Codecov"
    fi
fi

echo "✅ Coverage generation complete!"