# Function Doc Generation from `##` Comments

The `.scripts/*.sh` files now use `##` as a doc-only prefix for function comments and module notes. This makes it easy to extract API documentation without mixing in implementation-only notes.

## Extraction approach

A simple pipeline can:

1. Find all library scripts.
2. Extract contiguous `##` blocks that are immediately followed by `function ...()`.
3. Render them into Markdown (or feed them into a site generator).

### Example: produce a single Markdown page

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

{
  echo "# e-bash function reference"
  echo

  for file in $(rg --files -g '.scripts/*.sh' | sort); do
    echo "## ${file}"

    awk '
      /^## / { block = block $0 "\n"; next }
      /^function[[:space:]]+/ {
        if (block != "") {
          name = $2
          sub(/\(\).*/, "", name)
          printf("### `%s`\n\n", name)
          printf("%s\n", block)
          block = ""
        }
      }
      { block = "" }
    ' "$file"

    echo
  done
} > docs/public/functions.generated.md
```

## Rendering ideas

- Commit the generated Markdown and publish it via your existing docs pipeline.
- Or, convert it to JSON and render a searchable HTML page.
- You can also link each function back to demos in `demos/` and real scripts in `bin/`.

## Conventions to keep

For best results, keep doc blocks compact and structured:

- `## <name>: <purpose>`
- `## Side effects: ...`
- `## Usage: ...`

Module-level notes at the end of the file can also use `##` so they appear in generated documentation.
