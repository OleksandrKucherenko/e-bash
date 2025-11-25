#!/usr/bin/env bash
# Generates release notes for GitHub releases
# Usage: generate-release-notes.sh <version> <tag> <commit_sha> <checksum> <archive_name>

set -euo pipefail

VERSION="${1:-}"
TAG="${2:-}"
COMMIT_SHA="${3:-}"
CHECKSUM="${4:-}"
ARCHIVE_NAME="${5:-}"

if [ -z "$VERSION" ] || [ -z "$TAG" ] || [ -z "$COMMIT_SHA" ] || [ -z "$CHECKSUM" ] || [ -z "$ARCHIVE_NAME" ]; then
  echo "❌ ERROR: Usage: $0 <version> <tag> <commit_sha> <checksum> <archive_name>"
  exit 1
fi

OUTPUT_FILE="release_notes.md"

# Create release notes
cat > "$OUTPUT_FILE" << EOF
## e-bash ${VERSION}

Distribution package for e-bash version ${VERSION}.

**Commit:** \`${COMMIT_SHA:0:7}\` ([view full commit](https://github.com/OleksandrKucherenko/e-bash/commit/${COMMIT_SHA}))

### 🔐 Integrity Verification

\`\`\`bash
# SHA256 Checksum
${CHECKSUM}  ${ARCHIVE_NAME}

# Verify after download
echo "${CHECKSUM}  ${ARCHIVE_NAME}" | sha256sum -c
\`\`\`

### 📦 Installation

\`\`\`bash
# Download and extract
wget https://github.com/OleksandrKucherenko/e-bash/releases/download/${TAG}/e-bash.${VERSION}.zip
unzip e-bash.${VERSION}.zip -d e-bash

# Or use the quick install script
curl -sSL https://git.new/e-bash | bash -s --
\`\`\`

### 📂 Package Contents

- \`.scripts/\` - Core library functions (16 modules)
- \`bin/\` - Standalone tools and scripts (11 executables)
- \`docs/\` - Comprehensive documentation
- \`demos/\` - Demo scripts showing usage patterns
- \`README.md\` - Project documentation
- \`LICENSE\` - MIT License

### 🔗 Resources

- **Repository:** https://github.com/OleksandrKucherenko/e-bash
- **Documentation:** https://github.com/OleksandrKucherenko/e-bash/tree/master/docs
- **Issues:** https://github.com/OleksandrKucherenko/e-bash/issues

---

For detailed changelog, see [CHANGELOG.md](https://github.com/OleksandrKucherenko/e-bash/blob/master/CHANGELOG.md)
EOF

echo "✅ Release notes generated: $OUTPUT_FILE"

# Show the generated notes
cat "$OUTPUT_FILE"
