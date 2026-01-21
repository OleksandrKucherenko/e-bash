# Anti-Patterns That Kill Elegance

## What to Avoid

These patterns destroy elegance:

| Anti-pattern | Why it's harmful |
|--------------|------------------|
| **Clever one-liners** | Compress meaning; require mental decoding |
| **Unnecessary abstraction** | "Factory factory," generic frameworks for simple tasks |
| **Premature optimization** | Complicates logic without measured need |
| **Deep nesting** | Long "railroad track" code paths hide intent |
| **Hidden state** | Globals, implicit context, mutable shared state |
| **Leaky abstractions** | Helpers requiring callers to know internal quirks |
| **Shotgun surgery** | Small change causes many edits |
| **Inconsistent error handling** | Some errors thrown, some returned, some ignored |
| **Magic values** | Unclear constants without named definitions |
| **Temporal coupling** | Must call A then B then C with no enforced contract |
| **Overloaded functions** | Different behaviors depending on subtle flags |

## Smells of "Smart Code" Masquerading as Elegance

Warning signs that code is clever, not elegant:

- Code relies on language tricks, operator precedence, or obscure features
- The solution is impressively short but takes effort to verify
- The author can't explain it simply without re-reading it
- Tests are missing because "it's obvious"
- You need to know multiple non-obvious facts to understand the code
- The logic would break if any assumption changes

## Quick Test: Is This Elegant or Just Clever?

Ask these questions:

1. **Can a new team member understand this in 30 seconds?**
   - Yes → Likely elegant
   - No → Probably too clever

2. **Would you be comfortable debugging this at 2am?**
   - Yes → Likely elegant
   - No → Too complex

3. **Does the cleverness remove real complexity or just hide it?**
   - Removes → Elegant
   - Hides → Clever

4. **If you delete this and rewrite, would you write it the same way?**
   - Yes → Likely elegant
   - No → Probably clever workaround

## Examples of Elegant vs Clever

### Clever (avoid)
```
// Swap without temp variable
a ^= b ^= a ^= b;
```

### Elegant (prefer)
```
// Swap values
[a, b] = [b, a];  // or use a temp variable
```

### Clever (avoid)
```
// Get user or throw
const user = users.find(u => u.id === id) || (() => { throw new Error('Not found'); })();
```

### Elegant (prefer)
```
const user = users.find(u => u.id === id);
if (!user) {
  throw new Error(`User not found: ${id}`);
}
```

## The Elegance Litmus Test

Before committing code, ask:

> "If I showed this to a colleague with 6 months less experience, would they understand it immediately, or would they need me to explain it?"

If explanation is needed, simplify.
