# Elegance Scorecard and Metrics

## The Elegance Scorecard (0–5 each)

Score each category from 0 (poor) to 5 (excellent). Track scores over time.

| Category | What "5" looks like | Diagnostic questions |
|----------|---------------------|---------------------|
| Correctness | Clear specs; edge cases handled; tests exist | What can go wrong? Is it tested? |
| Clarity | Reads like prose; names carry meaning | Can a new reader summarize it quickly? |
| Simplicity | Few concepts; minimal moving parts | Can anything be removed without loss? |
| Cohesion | Each unit has one job | Does this unit do more than one "kind" of thing? |
| Coupling | Changes are localized; interfaces are small | Does change ripple widely? |
| Predictability | Principle of least astonishment | Are there hidden side effects / surprising behavior? |
| Efficiency (fit-for-purpose) | Right algorithm/data structures | Is cost proportional to requirements? |
| Idiomatic usage | Fits project norms | Would a fluent developer find it "natural"? |
| Testability | Easy to test core logic | Can you test without complex setup? |

### Interpretation

- **36–45**: Likely elegant and maintainable
- **25–35**: Solid but improvable (usually clarity/simplicity)
- **< 25**: Likely needs refactor or redesign

## Objective Metrics (language-agnostic)

These highlight improvement opportunities:

### Complexity & Readability
- Cyclomatic complexity (branching)
- Cognitive complexity (nested logic, mixed concerns)
- Average function length / file length
- Nesting depth

### Maintainability
- Duplication rate (copy/paste logic)
- Coupling (number of dependencies per module)
- Cohesion (do functions in a module "belong together"?)

### Quality Signals
- Test coverage (especially on core logic)
- Mutation testing score (if available)
- Static analysis / lint issues
- Defect density and bug recurrence

### Performance (when needed)
- Time and memory usage on representative workloads
- Latency percentiles for services
- Allocation rates / hotspot profiling results

## Improvement Opportunities Checklist

When evaluating code, scan for these:

### Clarity Improvements
- Names are ambiguous or inconsistent
- The "why" is missing (tradeoffs/constraints not documented)
- Reader must simulate execution to understand behavior

### Simplicity Improvements
- Too many layers/abstractions for the problem size
- Generalization without a real use case ("future-proofing")
- Over-configuration and feature flags for hypothetical needs

### Structure Improvements
- Mixed concerns (business logic + I/O + formatting + persistence)
- Long functions doing multiple things
- Repeated patterns with slightly different details

### Correctness & Safety Improvements
- Edge cases not handled or undocumented
- Error handling inconsistent or silent
- Implicit assumptions not enforced (missing validation/invariants)

### Changeability Improvements
- Tight coupling to internals
- Hard-coded constants scattered across code
- Modification requires touching many files for one feature

### Performance Improvements
- Inefficient algorithmic choices
- Unnecessary repeated work (recomputing, re-parsing)
- Heavy operations in hot paths without caching or batching (when appropriate)
