# Common Issues Reviewers Find

This document catalogs common issues that reviewers catch during code review. Use this to understand what reviewers are looking for and catch these issues before submitting.

## Most Common Issues (By Frequency)

### 1. Missing Error Handling (40% of PRs)
**What it looks like:**
```javascript
// Bad - no error handling
const user = await db.getUser(id);
return user.email;

// Good - error handling
const user = await db.getUser(id);
if (!user) {
  throw new NotFoundError(`User ${id} not found`);
}
return user.email;
```

**Why it's caught:** Unhandled errors cause crashes or confusing behavior

### 2. No Tests for Edge Cases (35% of PRs)
**What it looks like:**
- Tests only cover happy path
- No tests for null/undefined inputs
- No tests for boundary conditions
- No tests for error conditions

**Why it's caught:** Edge cases are where bugs live

### 3. Hardcoded Values (30% of PRs)
**What it looks like:**
```javascript
// Bad - hardcoded
const timeout = 5000; // What is this?

// Good - named constant
const REQUEST_TIMEOUT_MS = 5000;
```

**Why it's caught:** Magic numbers make code hard to understand and maintain

### 4. Incomplete Documentation (25% of PRs)
**What it looks like:**
- New functions without docstrings
- Parameters not documented
- Return values not specified
- Complex algorithms without comments

**Why it's caught:** Future maintainers can't understand the code

### 5. Security Issues (20% of PRs)
**What it looks like:**
- SQL injection vulnerabilities
- XSS vulnerabilities
- Missing authentication checks
- Sensitive data in logs

**Why it's caught:** Security bugs can be catastrophic

### 6. Performance Issues (15% of PRs)
**What it looks like:**
- N+1 queries
- Missing database indexes
- Inefficient algorithms
- Unnecessary database calls in loops

**Why it's caught:** Performance problems are expensive to fix later

### 7. Style/Formatting (15% of PRs)
**What it looks like:**
- Inconsistent indentation
- Line too long
- Trailing whitespace
- Inconsistent naming

**Why it's caught:** Inconsistent style is distracting and unprofessional

### 8. Commented-Out Code (12% of PRs)
**What it looks like:**
```javascript
// const oldWay = () => { ... };
const newWay = () => { ... };
```

**Why it's caught:** Git history preserves old code. Comments are noise.

### 9. Debugging Statements Left In (10% of PRs)
**What it looks like:**
```javascript
console.log("HERE");
debugger;
console.log(user);
```

**Why it's caught:** Debugging statements should never be committed

### 10. Not Following Conventions (10% of PRs)
**What it looks like:**
- Using different patterns than rest of codebase
- Inconsistent file structure
- Not using existing utilities/helpers

**Why it's caught:** Consistency makes codebases maintainable

## Issues That Cause PR Rejection

These issues typically require complete resubmission:

### Security Vulnerabilities
- Authentication/authorization bypasses
- Injection vulnerabilities (SQL, XSS, command)
- Sensitive data exposure
- Cryptographic issues

### Architectural Concerns
- Tight coupling that should be loose
- Violation of established patterns
- Missing abstraction layers
- Incorrect separation of concerns

### Performance Regressions
- Algorithmic complexity increases (O(n) -> O(n²))
- Database performance degradation
- Memory leaks
- Resource exhaustion

### Testing Gaps
- No tests for new code
- Critical paths untested
- Tests that don't actually test anything
- Brittle tests that will break constantly

### Data Safety Issues
- Potential data loss scenarios
- Missing transaction boundaries
- Race conditions
- Migration issues

## Issues That Cause Quick Fixes

These issues can be fixed with follow-up commits:

- Typos in documentation
- Minor style inconsistencies
- Variable naming improvements
- Missing null checks in non-critical paths
- Additional logging suggestions
- Performance optimizations (non-critical)

## Self-Check Before Submitting

Before submitting your PR, ask yourself:

1. **Will the reviewer understand WHY I made this change without asking me?**
2. **Have I tested the error paths, not just happy paths?**
3. **Would I approve this PR if someone else submitted it?**
4. **What will the reviewer likely ask me to change?**
5. **Am I submitting my best work, or just "good enough"?**

## Common Reviewer Feedback Patterns

### "Can you add tests for...?"
Means: You didn't test edge cases or error conditions
Prevention: Use the testing checklist

### "What happens when...?"
Means: You didn't consider edge cases
Prevention: Use the edge cases checklist

### "Can you explain why...?"
Means: Your code or PR description lacks context
Prevention: Add comments and improve PR description

### "Have you considered...?"
Means: You missed an important consideration
Prevention: Think through implications before coding

### "This looks like... pattern"
Means: You're not following established conventions
Prevention: Review similar code before implementing

## Remember

Every issue a reviewer finds is:
- **Time wasted** in review cycle
- **Time delayed** in getting your code merged
- **Reputation hit** for submitting incomplete work
- **Opportunity cost** of reviewer not reviewing other PRs

Preventing these issues through self-review is faster than fixing them in review cycles.
