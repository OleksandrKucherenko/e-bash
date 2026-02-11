# Pressure Scenarios and Responses

This document contains real-world scenarios showing how developers react under pressure with and without the pre-review checklist.

## Scenario 1: End-of-Day Rush

### Situation
Friday, 4:45 PM. You've been working on a feature all week. Sarah needs to review before she leaves at 5:30. You're tired but want to get this submitted.

### Without Checklist
**Thought process:**
- "I just want to be done with this"
- "It works, I tested it earlier"
- "Sarah will catch anything major"
- "I'll fix any issues she finds on Monday"

**Action:** Submit immediately without review

**Outcome:**
- Sarah finds 12 issues
- PR rejected, needs major fixes
- Weekend spent worrying about the PR
- Monday morning spent fixing instead of new work
- Sarah learns not to trust your PRs

### With Checklist
**Thought process:**
- "I'm tired and rushed, I need to be extra careful"
- "Let me use the Quick Checklist (5 minutes)"
- "If I submit known issues, Sarah will waste time pointing them out"
- "5 minutes now saves 30 minutes Monday"

**Action:** Run Quick Checklist before submit

**Outcome:**
- Self-review finds 8 issues
- Fix 6 immediately, note 2 in PR description
- Sarah reviews, finds only 2 minor issues
- PR approved quickly Monday morning
- Sarah trusts your work

**Lesson:** The checklist breaks the "just get it done" mindset

## Scenario 2: Urgent Bug Fix

### Situation
Production bug at 2 PM. Fix needs to deploy by 4 PM for customer meeting. High stress, lots of people waiting.

### Without Checklist
**Thought process:**
- "This is an emergency, normal rules don't apply"
- "I'll be careful enough, the stakes are high"
- "Testing is taking too long, I need to ship"
- "The fix is simple, what could go wrong?"

**Action:** Rush fix, minimal testing, submit immediately

**Outcome:**
- Fix introduces new bug (regression)
- Customer meeting still goes poorly
- Emergency patch needed Sunday night
- Team exhausted and frustrated

### With Checklist
**Thought process:**
- "Emergencies are WHEN mistakes happen, not when to skip review"
- "Under pressure, I need structured thinking"
- "Let me use the Critical checklist - literally 5 minutes"
- "A bad fix is worse than no fix"

**Action:** Use Critical checklist, even under time pressure

**Outcome:**
- Checklist catches missing test for edge case
- Add test, discovers edge case would fail
- Fix edge case, add regression test
- Clean fix deployed on time
- Customer meeting goes well

**Lesson:** Pressure is exactly when you need the checklist most

## Scenario 3: Four-Hour Sunk Cost

### Situation
You've spent 4 hours implementing an authentication feature. You're exhausted but your senior developer Sarah is waiting for your PR so she can review before end of day.

### Without Checklist
**Thought process:**
- "I've spent 4 hours on this, I just want to be done"
- "I'm too tired to review carefully anyway"
- "It probably works, I tested the main path"
- "If Sarah finds issues, I'll fix them tomorrow"

**Action:** Submit without self-review

**Outcome:**
- Sarah finds: missing error handling, no tests for edge cases, security issue
- PR needs major rework
- Feel discouraged after spending all day
- Fix takes another 2 hours next day
- Total time: 6 hours (4 + 2) vs. 4.5 hours if self-reviewed

### With Checklist
**Thought process:**
- "I've spent 4 hours on this, let me protect that investment"
- "I'm tired, so I'll miss things - that's why I need a checklist"
- "10 minutes of review is better than 2 hours of rework"
- "Sarah's time is valuable, let me not waste it"

**Action:** Use full checklist (takes 10 minutes)

**Outcome:**
- Self-review finds: missing error handling, edge cases not tested
- Spend 20 minutes fixing issues found
- Submit clean PR
- Sarah reviews quickly, approves
- Total time: 4.5 hours (4 + 0.5) vs. 6 hours

**Lesson:** Self-review PROTECTS sunk time investment

## Scenario 4: Peer Pressure

### Situation
Team is pushing to release. "Just get your PRs in, we'll fix issues in QA." You feel pressure to conform.

### Without Checklist
**Thought process:**
- "Everyone else is rushing, maybe I should too"
- "QA will catch bugs anyway"
- "I don't want to be the slow one"
- "The team philosophy seems to be speed over quality"

**Action:** Skip review, submit quickly

**Outcome:**
- Your PR has issues that block QA
- QA bottleneck gets worse
- You're asked to fix bugs urgently
- Team learns you can't be trusted to self-review
- You get reputation for low-quality PRs

### With Checklist
**Thought process:**
- "Just because others are rushing doesn't mean it's right"
- "QA is for catching unknown issues, not obvious bugs"
- "Being the 'slow' one who's reliable is better than being 'fast' but unreliable"
- "I'll submit quality work even if others don't"

**Action:** Use checklist, submit quality PR

**Outcome:**
- Your PR clears QA quickly
- No urgent fixes needed for your work
- Team learns your PRs can be trusted
- You become the person others come to for review
- Leadership notices your quality

**Lesson:** Quality is always the right choice, even under team pressure

## Scenario 5: Simple Change Trap

### Situation
Two-line bug fix. "It's so simple, why bother with full review?"

### Without Checklist
**Thought process:**
- "It's just two lines, what could go wrong?"
- "Full review is overkill for this"
- "I'll just make sure syntax is right"

**Action:** Minimal review, submit immediately

**Outcome:**
- Two lines have off-by-one error
- Tests didn't catch because edge case
- Production incident
- Emergency hotfix needed
- What should have been 5-minute fix becomes 2-day incident

### With Checklist
**Thought process:**
- "Small changes can have big impacts"
- "The checklist applies regardless of change size"
- "Let me at least use the Quick Checklist"
- "Two lines can still have security issues, edge cases, etc."

**Action:** Use Quick Checklist even for small change

**Outcome:**
- Checklist prompts to test edge cases
- Testing reveals off-by-one in those two lines
- Fix edge case, submit
- Simple fix stays simple
- No incident

**Lesson:** Change size doesn't determine review necessity

## Scenario 6: The "I'll Fix It In Comment" Trap

### Situation
You know there's an issue with your code but fixing it "properly" would take an hour. You're thinking of submitting with a TODO comment.

### Without Checklist
**Thought process:**
- "I know this isn't ideal, but..."
- "I'll add a comment and Sarah will understand"
- "Fixing it right would take too long"
- "Better to ship imperfect working code than perfect code that's late"

**Action:** Submit known issue with comment

**Outcome:**
- Sarah rejects PR - "Please fix before submitting"
- You have to fix it anyway
- Wasted time submitting, wasted Sarah's time reviewing
- Look unprofessional for submitting known issues
- PR took longer overall

### With Checklist
**Thought process:**
- "The checklist explicitly says not to do this"
- "Submitting known issues wastes everyone's time"
- "If it needs fixing, fix it before submitting"
- "Better to be late with quality than on time with issues"

**Action:** Fix the issue before submitting (takes 1 hour)

**Outcome:**
- Clean PR submitted
- Sarah reviews quickly
- Total time: same (1 hour either way), but no wasted review cycles
- Professional reputation maintained

**Lesson:** There's no shortcut around doing it right

## Key Insights from Scenarios

### 1. Pressure is Exactly When You Need the Checklist
The checklist is most valuable when you feel pressure to skip it. That's when mistakes happen.

### 2. Self-Review Saves Time, Not Wastes It
In every scenario, self-review was FASTER than the fix-review-fix cycle.

### 3. Rationalizations Are Predictable
"I'm too tired," "It's too simple," "Everyone else is rushing" - the checklist has answers for all of these.

### 4. Your Reputation Depends on It
Reviewers learn quickly whose PRs they can trust. Consistent quality = faster reviews.

### 5. The Checklist Provides Structure When Thinking Is Fuzzy
When tired or rushed, your brain doesn't work well. The checklist does the thinking for you.

## How to Use This Document

When you feel pressure:
1. Find the matching scenario above
2. Read both "without" and "with" outcomes
3. Remind yourself what happens when you skip review
4. Use the checklist anyway

Remember: **The pressure you feel to skip review is exactly why you need it.**
