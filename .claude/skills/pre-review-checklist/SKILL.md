---
name: pre-review-checklist
description: Use before submitting code for review to catch common issues, reduce review cycles, and maintain code quality standards.
---

# Pre-Review Checklist

This skill provides a comprehensive checklist for self-review before requesting code review. Using this checklist helps catch issues early, reduces review cycles, and demonstrates respect for reviewers' time.

## When to Use This Skill

Use this checklist when:
- About to submit a pull request for code review
- Ready to mark a PR as "ready for review"
- Completed a feature and want to ensure quality before requesting review
- Working under time pressure and tempted to skip self-review
- Feeling exhausted after long coding sessions

## Core Philosophy

**Self-review is not optional** - it's part of the development process. The time you invest in self-review saves multiple reviewers' time and reduces back-and-forth in PR comments.

**Pressure doesn't exempt you** - in fact, pressure makes self-review MORE important because:
- Mistakes increase when tired/rushed
- Review cycles take longer than doing it right the first time
- Your reputation for quality affects future PR prioritization

## The Checklist

### Phase 1: Functional Completeness

#### 1.1 Feature Completeness
- [ ] All acceptance criteria met
- [ ] All happy path scenarios work
- [ ] Edge cases identified and handled
- [ ] Error cases handled appropriately
- [ ] No placeholder code or TODOs left in implementation

#### 1.2 Testing Coverage
- [ ] Unit tests written for new functions
- [ ] Integration tests cover user flows
- [ ] Edge cases tested
- [ ] Error conditions tested
- [ ] Tests pass locally (not just CI)
- [ ] Test coverage not decreased (if applicable)

### Phase 2: Code Quality

#### 2.1 Code Structure
- [ ] Functions are small and focused (< 50 lines typically)
- [ ] No code duplication (DRY principle)
- [ ] Appropriate abstractions (not over- or under-engineered)
- [ ] Clear separation of concerns
- [ ] Consistent naming conventions followed

#### 2.2 Code Style
- [ ] Follows project style guide
- [ ] No commented-out code
- [ ] No debugging statements (console.log, debugger, etc.)
- [ ] Meaningful variable/function names
- [ ] Proper indentation and formatting

#### 2.3 Complexity Management
- [ ] Cyclomatic complexity reasonable
- [ ] Nesting level <= 4 (ideally <= 3)
- [ ] Guard clauses used to reduce nesting
- [ ] Complex logic has comments explaining WHY

### Phase 3: Security & Safety

#### 3.1 Security Checks
- [ ] No hardcoded credentials/secrets
- [ ] Input validation on all user inputs
- [ ] Output encoding to prevent injection attacks
- [ ] Proper authentication/authorization checks
- [ ] Sensitive data not logged
- [ ] No SQL/command injection vulnerabilities

#### 3.2 Data Safety
- [ ] No data loss scenarios
- [ ] Proper transaction handling
- [ ] Appropriate data validation
- [ ] Backup/rollback considerations
- [ ] No race conditions in concurrent scenarios

### Phase 4: Performance & Scalability

#### 4.1 Performance Considerations
- [ ] No N+1 query problems
- [ ] Appropriate database indexes
- [ ] No inefficient loops/algorithms
- [ ] Caching considered where appropriate
- [ ] Large datasets handled efficiently

#### 4.2 Resource Management
- [ ] Connections properly closed
- [ ] Memory leaks avoided
- [ ] File handles released
- [ ] Temporary files cleaned up
- [ ] Timeouts set on external calls

### Phase 5: Error Handling

#### 5.1 Error Scenarios
- [ ] All error paths tested
- [ ] Error messages are user-friendly
- [ ] Errors logged appropriately
- [ ] No silent failures
- [ ] Graceful degradation where possible

#### 5.2 Observability
- [ ] Key operations logged
- [ ] Metrics added where appropriate
- [ ] Distributed tracing considered
- [ ] Debugging information available

### Phase 6: Documentation

#### 6.1 Code Documentation
- [ ] Complex functions have docstrings
- [ ] Non-obvious code has comments explaining WHY
- [ ] Public API documented
- [ ] Parameter types and returns documented

#### 6.2 Change Documentation
- [ ] PR description clearly describes WHAT changed
- [ ] PR description explains WHY change was needed
- [ ] Breaking changes noted
- [ ] Migration steps provided if needed
- [ ] Related issues referenced

### Phase 7: Integration & Compatibility

#### 7.1 Integration Points
- [ ] API contracts honored
- [ ] Database migrations included
- [ ] Configuration changes documented
- [ ] Environment variables defined

#### 7.2 Compatibility
- [ ] Backwards compatibility considered
- [ ] Works on all supported platforms/versions
- [ ] Browser compatibility (if frontend)
- [ ] Database version compatibility

### Phase 8: Review Readiness

#### 8.1 PR Quality
- [ ] PR title is clear and concise
- [ ] PR description provides context
- [ ] Changes are focused (not too broad)
- [ ] No unrelated changes included
- [ ] Commits are clean and logical

#### 8.2 Self-Validation
- [ ] Diff reviewed line by line
- [ ] Actually tested the changes (not just assumed)
- [ ] Screenshots/screenscords included for UI changes
- [ ] Manual testing completed
- [ ] Ready to answer reviewer questions

## Quick Checklist (Pressure Mode)

When under severe time pressure, at minimum complete:

**CRITICAL (5 minutes):**
- [ ] Code actually runs locally
- [ ] Basic happy path works
- [ ] No obvious bugs in diff
- [ ] No credentials/secrets accidentally included
- [ ] PR description explains what and why

**IMPORTANT (if 10 more minutes available):**
- [ ] Edge cases considered
- [ ] Error paths tested
- [ ] No commented-out debug code
- [ ] Tests pass locally
- [ ] Diff self-reviewed

## Anti-Patterns to Avoid

### The "I'll Fix It In Comment" Trap
Don't submit known issues with "I know this is wrong, will fix" comments. Fix it first, then submit.

### The "Reviewer Will Catch It" Trap
Reviewers are not responsible for catching everything. Submitting unreviewed code wastes everyone's time.

### The "Time Pressure" Trap
"I'm in a rush" is not a valid reason to skip review. Rushed code has MORE bugs, not less.

### The "It's Just a Small Change" Trap
Small changes can have big impacts. The checklist applies regardless of change size.

### The "I'm Too Tired" Trap
Fatigue leads to mistakes. If too tired to review, you're too tired to submit. Sleep first.

## Common Rationalizations (And Why They're Wrong)

**"The tests will catch it"**
Tests don't catch everything. They don't catch UX issues, performance problems, security gaps, or architectural concerns.

**"Sarah reviews everything carefully anyway"**
This is disrespectful of Sarah's time. Also, if you consistently submit low-quality PRs, Sarah will stop reviewing your code quickly.

**"I can always push a follow-up commit"**
Every follow-up commit creates notification noise and extends review time. Multiple small fixes look like you didn't care enough to do it right.

**"It works on my machine"**
Local testing is necessary but not sufficient. The checklist ensures you've considered beyond just "it runs."

**"I spent 4 hours on this, I just want to be done"**
Sunk cost fallacy. Spending 4 hours doesn't justify skipping the 10-minute review that would make it quality work.

## Pressure Resistance Strategies

### When Feeling Rushed
1. **STOP** - Take 3 deep breaths
2. **REMIND** - "Rushing now will cost more time later"
3. **MINIMUM** - At least do the Quick Checklist
4. **SUBMIT** - Only after minimum checklist complete

### When Feeling Tired
1. **ACKNOWLEDGE** - "My brain is not at 100%"
2. **ADJUST** - Use written checklist (don't rely on memory)
3. **EXTEND** - Give yourself more time than usual
4. **DEFER** - Consider sleeping and reviewing in morning if very tired

### When Feeling Resistance
1. **IDENTIFY** - "I don't want to do this because..."
2. **CHALLENGE** - "Is my reason actually valid?"
3. **REFRAME** - "This 10 minutes saves 60 minutes of review time"
4. **EXECUTE** - Just start with first item

## How to Use This Checklist

### Before Every PR Submission
1. Copy checklist to temporary location
2. Check off items as you verify them
3. Don't submit until all items checked
4. Keep notes on what you found/fixed

### During Development
1. Keep checklist items in mind while coding
2. Address checklist items as you go
3. Makes final review faster

### For Critical Changes
1. Use full checklist (not quick version)
2. Have peer do pre-PR review
3. Consider QA review before submission
4. Add extra testing focus

## Measuring Your Effectiveness

Track these metrics:
- PR cycles before approval (goal: 1-2)
- Reviewer comments per PR (goal: < 5 non-nitpick comments)
- Bugs found in review vs. production (goal: catch in review)
- Time from PR submission to merge (goal: decrease with quality)

## References

- `references/common-review-issues.md` - Common issues reviewers find
- `references/pressure-scenarios.md` - Real-world pressure scenarios and responses
- `references/checklist-anti-patterns.md` - Detailed anti-patterns to avoid

## Remember

**The checklist doesn't slow you down - it speeds you up** by preventing:
- Multiple review cycles
- Embarrassing mistakes
- Reputation damage
- Production bugs
- Wasted reviewer time

**10 minutes of self-review prevents 60 minutes of back-and-forth.**
