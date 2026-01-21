# Continuous Elegance Improvement

Elegance is not a one-time achievement; it's a continuous practice.

## The Continuous Elegance Loop (CEL)

Repeat this loop in small increments:

### 1. Observe
- Where do bugs cluster?
- Where do reviewers get confused?
- Where do changes take the longest?

### 2. Diagnose
- Is the issue naming? boundaries? duplication? algorithm? error handling?
- Which scorecard categories are low?
- What specific rule is being violated?

### 3. Refactor
- Make one improvement at a time
- Prefer mechanical, behavior-preserving refactors first
- Keep changes small and reversible

### 4. Verify
- Run tests; add tests if the area is brittle
- Benchmark if performance-sensitive
- Confirm no regressions

### 5. Document
- Capture key constraints/tradeoffs in comments or docs (briefly)
- Record "why it is this way," not line-by-line explanations
- Update any affected documentation

## Practical Practices

### Boy Scout Rule (always)

> Leave the code a little better than you found it.

Small improvements compound:
- Rename for clarity
- Extract a function
- Delete dead code
- Add a test around fragile behavior
- Fix a misleading comment
- Remove an unused parameter

### Refactor Behind Tests

- If behavior isn't protected, add tests first (or golden-file snapshots / contract tests)
- Treat refactors without tests as higher-risk and keep them minimal
- Never refactor and change behavior in the same commit

### Keep Interfaces Stable and Small

- A small interface is easier to understand and harder to misuse
- Design APIs around domain concepts, not current implementation
- Prefer narrow, purpose-specific interfaces over broad generic ones
- Changes to interfaces should be deliberate and rare

### Normalize Patterns

- Create "one obvious way" to do common tasks (logging, error handling, validation)
- Consistency is a major contributor to perceived elegance
- Document patterns in a team style guide or examples folder
- When you see a pattern done two ways, consolidate to one

### Use Tooling as Guardrails

| Tool Type | Purpose |
|-----------|---------|
| Formatters | Consistent style |
| Linters/static analysis | Suspicious patterns |
| Complexity thresholds | Prevent gradual decay |
| CI pipelines | Enforce tests and checks |
| Pre-commit hooks | Catch issues early |

## When to Do What

### During Development
- Apply rules while writing (don't defer)
- Run self-review checklist before PR
- Keep commits focused and small

### During Code Review
- Use scorecard to structure feedback
- Focus on the most impactful issues
- Suggest specific improvements, not just "this is bad"

### During Maintenance
- Apply Boy Scout Rule on every touch
- Track areas with repeated issues
- Schedule dedicated refactoring for hot spots

### During Planning
- Estimate refactoring time honestly
- Build improvement into feature work
- Don't let tech debt compound indefinitely

## Prioritizing Improvements

When resources are limited, prioritize:

1. **Safety issues** — bugs, security, data integrity
2. **Frequent pain points** — code touched often that's hard to modify
3. **Clarity for critical paths** — most important business logic
4. **Test coverage** — especially for fragile areas
5. **Consistency** — reducing cognitive load across codebase

Deprioritize:
- Purely aesthetic improvements in stable, rarely-touched code
- Refactors without tests to verify behavior
- Changes near deadlines with high risk
