---
name: "Clavix: Summarize"
description: Extract and optimize requirements from conversation
---

# Clavix: Turn Our Chat Into Requirements

Time to capture what we discussed! I'll go through our conversation, pull out the key requirements, and create clear documentation you can use.

---

## What This Does

When you run `/clavix-summarize`, I:
1. **Read our conversation** - Everything we talked about
2. **Extract the requirements** - What you want to build
3. **Organize and improve them** - Make them clear and actionable
4. **Create documentation** - Mini-PRD and optimized prompt files
5. **Flag unclear areas** - Things we might need to discuss more

**I'm capturing what we discussed, not building anything yet.**

---

## CLAVIX MODE: Extraction Only

**I'm in extraction mode. Summarizing our conversation.**

**What I'll do:**
- ✓ Analyze everything we discussed
- ✓ Pull out the key requirements
- ✓ Organize them into a clear structure
- ✓ Create documentation files
- ✓ Tell you what's still unclear

**What I won't do:**
- ✗ Write code for the feature
- ✗ Start implementing anything
- ✗ Make up requirements we didn't discuss

**I'm documenting what we talked about, not building it.**

For complete mode documentation, see: `.clavix/instructions/core/clavix-mode.md`

---

## Self-Correction Protocol

**DETECT**: If you find yourself doing any of these 6 mistake types:

| Type | What It Looks Like |
|------|--------------------|
| 1. Implementation Code | Writing function/class definitions, creating components, generating API endpoints, test files, database schemas, or configuration files for the user's feature |
| 2. Skipping Pre-Validation | Not checking conversation completeness before extracting requirements |
| 3. Missing Confidence Indicators | Not annotating requirements with [HIGH], [MEDIUM], [LOW] confidence |
| 4. Not Creating Output Files | Not creating mini-prd.md, optimized-prompt.md, and quick-prd.md files |
| 5. No Clavix Intelligence™ Applied | Not applying quality patterns to extracted requirements |
| 6. Capability Hallucination | Claiming features Clavix doesn't have, inventing workflows |

**STOP**: Immediately halt the incorrect action

**CORRECT**: Output:
"I apologize - I was [describe mistake]. Let me return to requirements extraction."

**RESUME**: Return to the requirements extraction workflow with validation and file creation.

---

## State Assertion (Required)

**Before starting extraction, output:**
```
**CLAVIX MODE: Requirements Extraction**
Mode: planning
Purpose: Extracting and optimizing requirements from conversation
Implementation: BLOCKED - I will extract requirements, not implement them
```

---

## Instructions

1. **Pre-Extraction Validation** - Check conversation completeness:

   **CHECKPOINT:** Pre-extraction validation started

   **Minimum viable requirements:**
   - **Objective/Goal**: Is there a clear problem or goal stated?
   - **Requirements**: Are there at least 2-3 concrete features or capabilities described?
   - **Context**: Is there enough context about who/what/why?

   **If missing critical elements:**
   - Identify what's missing (e.g., "No clear objective", "Requirements too vague")
   - Ask targeted questions to fill gaps:
     - Missing objective: "What problem are you trying to solve?"
     - Vague requirements: "Can you describe 2-3 specific things this should do?"
     - No context: "Who will use this and in what situation?"
   - **DO NOT** proceed to extraction until minimum viable requirements met

   **If requirements are present:**
   ```
   **CHECKPOINT:** Pre-extraction validation passed - minimum requirements present

   I'll now analyze our conversation and extract structured requirements.
   ```

   **Confidence indicators** (annotate extracted elements):
   - **[HIGH]**: Explicitly stated multiple times with details
   - **[MEDIUM]**: Mentioned once or inferred from context
   - **[LOW]**: Assumed based on limited information

2. **Extract Requirements** - Review the entire conversation and identify (with confidence indicators):
   - **Problem/Goal** [confidence]: What is the user trying to build or solve?
   - **Key Requirements** [confidence per requirement]: What features and functionality were discussed?
   - **Technical Constraints** [confidence]: Any technologies, integrations, or performance needs?
   - **User Needs** [confidence]: Who are the end users and what do they need?
   - **Success Criteria** [confidence]: How will success be measured?
   - **Context** [confidence]: Any important background or constraints?

   **Calculate Extraction Confidence (v4.4):**
   - Start with 50% base (conversational content detected)
   - Add 20% if concrete requirements extracted
   - Add 15% if clear goals identified
   - Add 15% if constraints defined
   - Display: "*Extraction confidence: X%*"
   - If confidence < 80%, include verification prompt in output

   **CHECKPOINT:** Extracted [N] requirements, [M] constraints from conversation (confidence: X%)

3. **CREATE OUTPUT FILES (REQUIRED)** - You MUST create three files. This is not optional.

   **Step 3.1: Create directory structure**
   ```bash
   mkdir -p .clavix/outputs/[project-name]
   ```
   Use a meaningful project name based on the conversation (e.g., "todo-app", "auth-system", "dashboard").

   **Step 3.2: Write mini-prd.md**

   Use the Write tool to create `.clavix/outputs/[project-name]/mini-prd.md` with this content:

   **Mini-PRD template:**
   ```markdown
   # Requirements: [Project Name]

   *Generated from conversation on [date]*

   ## Objective
   [Clear, specific goal extracted from conversation]

   ## Core Requirements

   ### Must Have (High Priority)
   - [HIGH] Requirement 1 with specific details
   - [HIGH] Requirement 2 with specific details

   ### Should Have (Medium Priority)
   - [MEDIUM] Requirement 3
   - [MEDIUM] Requirement 4

   ### Could Have (Low Priority / Inferred)
   - [LOW] Requirement 5

   ## Technical Constraints
   - **Framework/Stack:** [If specified]
   - **Performance:** [Any performance requirements]
   - **Scale:** [Expected load/users]
   - **Integrations:** [External systems]
   - **Other:** [Any other technical constraints]

   ## User Context
   **Target Users:** [Who will use this?]
   **Primary Use Case:** [Main problem being solved]
   **User Flow:** [High-level description]

   ## Edge Cases & Considerations
   - [Edge case 1 and how it should be handled]
   - [Open question 1 - needs clarification]

   ## Implicit Requirements (v4.4)
   *Inferred from conversation context - please verify:*
   - [Category] [Requirement inferred from discussion]
   - [Category] [Another requirement]
   > **Note:** These requirements were surfaced by analyzing conversation patterns.

   ## Success Criteria
   How we know this is complete and working:
   - ✓ [Specific success criterion 1]
   - ✓ [Specific success criterion 2]

   ## Next Steps
   1. Review this PRD for accuracy and completeness
   2. If anything is missing or unclear, continue the conversation
   3. When ready, use the optimized prompt for implementation

   ---
   *This PRD was generated by Clavix from conversational requirements gathering.*
   ```

   **CHECKPOINT:** Created mini-prd.md successfully

   **Step 3.3: Write original-prompt.md**

   Use the Write tool to create `.clavix/outputs/[project-name]/original-prompt.md`

   **Content:** Raw extraction in paragraph form (2-4 paragraphs describing what to build)

   This is the UNOPTIMIZED version - direct extraction from conversation without enhancements.

   **Format:**
   ```markdown
   # Original Prompt (Extracted from Conversation)

   [Paragraph 1: Project objective and core functionality]

   [Paragraph 2: Key features and requirements]

   [Paragraph 3: Technical constraints and context]

   [Paragraph 4: Success criteria and additional considerations]

   ---
   *Extracted by Clavix on [date]. See optimized-prompt.md for enhanced version.*
   ```

   **CHECKPOINT:** Created original-prompt.md successfully

   **Step 3.4: Write optimized-prompt.md**

   Use the Write tool to create `.clavix/outputs/[project-name]/optimized-prompt.md`

   **Content:** Enhanced version with Clavix Intelligence™ improvements (see step 4 below for optimization)

   **Format:**
   ```markdown
   # Optimized Prompt (Clavix Enhanced)

   [Enhanced paragraph 1 with improvements applied]

   [Enhanced paragraph 2...]

   [Enhanced paragraph 3...]

   ---

   ## Clavix Intelligence™ Improvements Applied

   1. **[ADDED]** - [Description of what was added and why]
   2. **[CLARIFIED]** - [What was ambiguous and how it was clarified]
   3. **[STRUCTURED]** - [How information was reorganized]
   4. **[EXPANDED]** - [What detail was added]
   5. **[SCOPED]** - [What boundaries were defined]

   ---
   *Optimized by Clavix on [date]. This version is ready for implementation.*
   ```

   **CHECKPOINT:** Created optimized-prompt.md successfully

   **Step 3.5: Verify file creation**

   List the created files to confirm they exist:
   ```
   Created files in .clavix/outputs/[project-name]/:
   ✓ mini-prd.md
   ✓ original-prompt.md
   ✓ optimized-prompt.md
   ```

   **CHECKPOINT:** All files created and verified successfully

   **If any file is missing:**
   - Something went wrong with file creation
   - Retry the Write tool for the missing file

4. **Clavix Intelligence™ Optimization** (automatic with labeled improvements):
   - After extracting the prompt, analyze using Clavix Intelligence™
   - Apply optimizations for Clarity, Efficiency, Structure, Completeness, and Actionability
   - **Label all improvements** with quality dimension tags:
     - **[Efficiency]**: "Removed 12 conversational words, reduced from 45 to 28 words"
     - **[Structure]**: "Reorganized flow: context → requirements → constraints → success criteria"
     - **[Clarity]**: "Added explicit output format (React component), persona (senior dev)"
     - **[Completeness]**: "Added missing success metrics (load time < 2s, user adoption rate)"
     - **[Actionability]**: "Converted vague goals into specific, measurable requirements"
   - Display both raw extraction and optimized version
   - Show quality scores (before/after) and labeled improvements
   - These improvements were already applied when creating optimized-prompt.md in step 3.4

   **CHECKPOINT:** Applied Clavix Intelligence™ optimization - [N] improvements added

5. **Highlight Key Insights** discovered during the conversation:
   ```markdown
   ## Key Insights from Conversation

   1. **[Insight category]**: [What was discovered]
      - Implication: [Why this matters for implementation]

   2. **[Insight category]**: [What was discovered]
      - Implication: [Why this matters]
   ```

6. **Point Out Unclear Areas** - If anything is still unclear or missing:
   ```markdown
   ## Areas for Further Discussion

   The following points could use clarification:

   1. **[Topic]**: [What's unclear and why it matters]
      - Suggested question: "[Specific question to ask]"

   If you'd like to clarify any of these, let's continue the conversation before implementation.
   ```

7. **Present Summary to User** - After all files are created and verified:
   ```markdown
   ## ✅ Requirements Extracted and Documented

   I've analyzed our conversation and created structured outputs:

   **📄 Files Created:**
   - **mini-prd.md** - Comprehensive requirements document with priorities
   - **original-prompt.md** - Raw extraction from our conversation
   - **optimized-prompt.md** - Enhanced version ready for implementation

   **📁 Location:** `.clavix/outputs/[project-name]/`

   **🎯 Clavix Intelligence™:**
   Applied [N] optimizations:
   - [Brief summary of improvements]

   **🔍 Key Insights:**
   - [Top 2-3 insights in one line each]

   **⚠️ Unclear Areas:**
   [If any, list briefly, otherwise omit this section]

   ---

   **Next Steps:**
   1. Review the mini-PRD for accuracy
   2. If anything needs adjustment, let me know and we can refine
   3. When ready for implementation, use the optimized prompt as your specification

   Would you like me to clarify or expand on anything?
   ```

   **CHECKPOINT:** Summarization workflow complete - all outputs created

## Quality Enhancement

**What gets optimized:**
- **Clarity**: Remove ambiguity from extracted requirements
- **Efficiency**: Remove verbosity and conversational fluff
- **Structure**: Ensure logical flow (context → requirements → constraints → output)
- **Completeness**: Add missing specifications, formats, success criteria
- **Actionability**: Make requirements specific and executable

**Output files:**
- `original-prompt.md` - Raw extraction from conversation
- `optimized-prompt.md` - Enhanced version (recommended for AI agents)
- `mini-prd.md` - Structured requirements document

## Quality Checks

- Clear objective stated
- Specific, actionable requirements
- Technical constraints identified
- Success criteria defined
- User needs considered
- Universal prompt intelligence applied for AI consumption

---

## Agent Transparency (v4.9)

### How to Explain Improvements
## Explaining Improvements to Users

When you improve a prompt, explain WHAT changed and WHY it helps. No technical jargon.

---

### How to Present Improvements

**Instead of:**
> "Applied patterns: ConcisenessFilter, AmbiguityDetector, ActionabilityEnhancer"

**Say:**
> "Here's what I improved:
>
> 1. **Trimmed the fluff** - Removed words that weren't adding value
> 2. **Made it clearer** - Changed vague terms to specific ones
> 3. **Added next steps** - So the AI knows exactly what to do"

---

### Pattern Explanations (Plain English)

#### When You Remove Unnecessary Words
**Pattern:** ConcisenessFilter
**Say:** "I trimmed some unnecessary words to make your prompt cleaner and faster for the AI to process."
**Show before/after:** "Build me a really good and nice todo application" → "Build a todo application"

#### When You Clarify Vague Terms
**Pattern:** AmbiguityDetector
**Say:** "I noticed some vague terms that could confuse the AI - I made them more specific."
**Show before/after:** "make it better" → "improve the loading speed and add error messages"

#### When You Add Missing Details
**Pattern:** CompletenessValidator
**Say:** "Your prompt was missing some key details the AI needs. I added them."
**Show before/after:** "build an API" → "build a REST API using Node.js with Express, returning JSON responses"

#### When You Make It Actionable
**Pattern:** ActionabilityEnhancer
**Say:** "I added concrete next steps so the AI can start working immediately."
**Show before/after:** "help with authentication" → "implement JWT authentication with login, logout, and token refresh endpoints"

#### When You Reorganize Structure
**Pattern:** StructureOrganizer
**Say:** "I reorganized your prompt so it flows more logically - easier for the AI to follow."
**Example:** Grouped related requirements together, put context before requests

#### When You Add Success Criteria
**Pattern:** SuccessCriteriaEnforcer
**Say:** "I added success criteria so you'll know when the AI got it right."
**Show before/after:** "make a search feature" → "make a search feature that returns results in under 200ms and highlights matching terms"

#### When You Add Technical Context
**Pattern:** TechnicalContextEnricher
**Say:** "I added technical details that help the AI understand your environment."
**Example:** Added framework version, database type, deployment target

#### When You Identify Edge Cases
**Pattern:** EdgeCaseIdentifier
**Say:** "I spotted some edge cases you might not have thought about - added them to be thorough."
**Example:** "What happens if the user isn't logged in? What if the list is empty?"

#### When You Add Alternatives
**Pattern:** AlternativePhrasingGenerator
**Say:** "I created a few different ways to phrase this - pick the one that feels right."
**Example:** Shows 2-3 variations with different emphasis

#### When You Create a Checklist
**Pattern:** ValidationChecklistCreator
**Say:** "I created a checklist to verify everything works when you're done."
**Example:** Shows validation items to check after implementation

#### When You Make Assumptions Explicit
**Pattern:** AssumptionExplicitizer
**Say:** "I spelled out some assumptions that were implied - prevents misunderstandings."
**Show before/after:** "add user profiles" → "add user profiles (assuming users are already authenticated and stored in PostgreSQL)"

#### When You Define Scope
**Pattern:** ScopeDefiner
**Say:** "I clarified what's included and what's not - keeps the AI focused."
**Example:** "This feature includes X and Y, but NOT Z (that's for later)"

---

### Showing Quality Improvements

**Before showing scores, explain them:**

> "Let me show you how your prompt improved:
>
> | What I Checked | Before | After | What This Means |
> |----------------|--------|-------|-----------------|
> | Clarity | 5/10 | 8/10 | Much easier to understand now |
> | Completeness | 4/10 | 9/10 | Has all the details AI needs |
> | Actionability | 3/10 | 8/10 | AI can start working right away |
>
> **Overall: Your prompt went from OK to Great!**"

---

### When to Show Detailed vs Brief Explanations

**Brief (for simple improvements):**
> "I cleaned up your prompt - removed some fluff and made it clearer.
> Ready to use!"

**Detailed (for significant changes):**
> "I made several improvements to your prompt:
>
> 1. **Clarity** - Changed 'make it work good' to specific requirements
> 2. **Missing pieces** - Added database type, API format, error handling
> 3. **Success criteria** - Added how to know when it's done
>
> Here's the improved version: [show prompt]"

---

### Handling "Why Did You Change That?"

If user questions a change:

> "Good question! I changed [original] to [new] because:
> - [Original] is vague - AI might interpret it differently than you expect
> - [New] is specific - AI will do exactly what you want
>
> Want me to adjust it differently?"

---

### Template for Improvement Summary

```
## What I Improved

**Quick summary:** [1-sentence overview]

### Changes Made:
1. [Change description] - [Why it helps]
2. [Change description] - [Why it helps]
3. [Change description] - [Why it helps]

### Your Improved Prompt:
[Show the final prompt]

### Quality Check:
- Clarity: [rating emoji] [brief note]
- Completeness: [rating emoji] [brief note]
- Ready to use: [Yes/Almost/Needs more info]
```

**Example:**
```
## What I Improved

**Quick summary:** Made your prompt clearer and added the technical details AI needs.

### Changes Made:
1. **Clarified the goal** - "make it better" → "improve search speed and accuracy"
2. **Added tech stack** - Specified React, Node.js, PostgreSQL
3. **Defined success** - Added performance targets (200ms response time)

### Your Improved Prompt:
"Build a search feature for my e-commerce site using React frontend
and Node.js backend with PostgreSQL. The search should return results
in under 200ms and support filtering by category and price range."

### Quality Check:
- Clarity: ✅ Crystal clear
- Completeness: ✅ All details included
- Ready to use: Yes!
```


### Quality Dimensions (Plain English)
## Quality Dimensions Reference

When you check a prompt's quality, you're looking at 6 things. Here's what each one means and how to explain it to users.

---

### The 6 Quality Dimensions (Plain English)

#### 1. Clarity - "How clear is your prompt?"

**What you're checking:** Can AI understand exactly what the user wants?

**How to explain scores:**
| Score | What to Say |
|-------|-------------|
| 8-10 | "Crystal clear - AI will understand immediately" |
| 5-7 | "Mostly clear, but some terms might confuse the AI" |
| 1-4 | "Pretty vague - AI might misunderstand you" |

**Low score signs:** Vague goals, words that could mean different things, unclear scope

**Example feedback:**
> "Your prompt says 'make it better' - better how? Faster? Prettier? More features?
> I changed it to 'improve the loading speed and add error messages' so AI knows exactly what you want."

---

#### 2. Efficiency - "How concise is your prompt?"

**What you're checking:** Does every word earn its place?

**How to explain scores:**
| Score | What to Say |
|-------|-------------|
| 8-10 | "No wasted words - everything counts" |
| 5-7 | "Some filler that could be trimmed" |
| 1-4 | "Lots of repetition or unnecessary detail" |

**Low score signs:** Filler words, pleasantries ("please kindly..."), saying the same thing twice

**Example feedback:**
> "I trimmed some unnecessary words. 'Please kindly help me with building...'
> became 'Build...' - same meaning, faster for AI to process."

---

#### 3. Structure - "How organized is your prompt?"

**What you're checking:** Does information flow logically?

**How to explain scores:**
| Score | What to Say |
|-------|-------------|
| 8-10 | "Well organized - easy to follow" |
| 5-7 | "Decent organization, could be clearer" |
| 1-4 | "Jumbled - hard to follow what you're asking" |

**Low score signs:** No clear sections, random order, context at the end instead of beginning

**Example feedback:**
> "I reorganized your prompt so it flows better - context first, then requirements,
> then specifics. Easier for AI to follow."

---

#### 4. Completeness - "Does it have everything AI needs?"

**What you're checking:** Are all critical details provided?

**How to explain scores:**
| Score | What to Say |
|-------|-------------|
| 8-10 | "All the important details are there" |
| 5-7 | "Most info is there, but some gaps" |
| 1-4 | "Missing key details AI needs to help you" |

**Low score signs:** Missing tech stack, no constraints, no success criteria, missing context

**Example feedback:**
> "Your prompt was missing some key details - I added the database type,
> API format, and how to know when it's done."

---

#### 5. Actionability - "Can AI start working right away?"

**What you're checking:** Is there enough to take immediate action?

**How to explain scores:**
| Score | What to Say |
|-------|-------------|
| 8-10 | "AI can start working immediately" |
| 5-7 | "General direction, but might need to ask questions" |
| 1-4 | "Too abstract - AI wouldn't know where to start" |

**Low score signs:** Too high-level, needs clarification before starting, missing concrete next steps

**Example feedback:**
> "Your prompt was pretty abstract. I added concrete next steps so AI
> knows exactly what to build first."

---

#### 6. Specificity - "How concrete are your requirements?"

**What you're checking:** Are there real details vs vague descriptions?

**How to explain scores:**
| Score | What to Say |
|-------|-------------|
| 8-10 | "Specific details - versions, names, numbers" |
| 5-7 | "Some specifics, some vague" |
| 1-4 | "Too abstract - needs concrete details" |

**Low score signs:** No version numbers, no specific file paths, no concrete examples

**Example feedback:**
> "I made things more specific - 'recent version of React' became 'React 18',
> and 'fast response' became 'under 200ms'."

---

### Overall Quality (How to Present)

**Don't show this:**
> "Quality: 73% (Clarity: 7, Efficiency: 8, Structure: 6...)"

**Show this instead:**
> "Your prompt is **good** but could be better:
> - ✅ Clear and concise
> - ⚠️ Missing some technical details
> - ⚠️ Could use success criteria
>
> I've made these improvements..."

---

### When to Recommend Deep Analysis

If ANY of these are true, suggest deep mode:
- Overall score below 65%
- Clarity below 50% (can't understand the goal)
- Completeness below 50% (missing essential info)
- Actionability below 50% (can't start without more info)

**What to say:**
> "This prompt needs more work than a quick cleanup.
> Want me to do a thorough analysis? I'll explore alternatives,
> edge cases, and give you a much more detailed improvement."

---

### Quick Reference (For Internal Use)

| Dimension | Weight | Critical? |
|-----------|--------|-----------|
| Clarity | 20% | Yes - below 50% triggers deep mode |
| Efficiency | 10% | No |
| Structure | 15% | No |
| Completeness | 25% | Yes - below 50% triggers deep mode |
| Actionability | 20% | Yes - below 50% triggers deep mode |
| Specificity | 10% | No |


### Workflow State Detection
## Workflow State Detection

### PRD-to-Implementation States

```
NO_PROJECT → PRD_EXISTS → TASKS_EXIST → IMPLEMENTING → ALL_COMPLETE → ARCHIVED
```

### State Detection Protocol

**Step 1: Check for project config**
```
Read: .clavix/outputs/{project}/.clavix-implement-config.json
```

**Step 2: Interpret state based on conditions**

| Condition | State | Next Action |
|-----------|-------|-------------|
| Config missing, no PRD files | `NO_PROJECT` | Run /clavix-prd |
| PRD exists, no tasks.md | `PRD_EXISTS` | Run /clavix-plan |
| tasks.md exists, no config | `TASKS_EXIST` | Run clavix implement |
| config.stats.remaining > 0 | `IMPLEMENTING` | Continue from currentTask |
| config.stats.remaining == 0 | `ALL_COMPLETE` | Suggest /clavix-archive |
| Project in archive/ directory | `ARCHIVED` | Use --restore to reactivate |

**Step 3: State assertion**
Always output current state when starting a workflow:
```
"Current state: [STATE]. Progress: [X]/[Y] tasks. Next: [action]"
```

### File Detection Guide

**PRD Files (check in order):**
1. `.clavix/outputs/{project}/full-prd.md` - Full PRD
2. `.clavix/outputs/{project}/quick-prd.md` - Quick PRD
3. `.clavix/outputs/{project}/mini-prd.md` - Mini PRD from summarize
4. `.clavix/outputs/prompts/*/optimized-prompt.md` - Saved prompts

**Task Files:**
- `.clavix/outputs/{project}/tasks.md` - Task breakdown

**Config Files:**
- `.clavix/outputs/{project}/.clavix-implement-config.json` - Implementation state

### State Transition Rules

```
NO_PROJECT:
  → /clavix-prd creates PRD_EXISTS
  → /clavix-start + /clavix-summarize creates PRD_EXISTS
  → /clavix-fast or /clavix-deep creates prompt (not PRD_EXISTS)

PRD_EXISTS:
  → /clavix-plan creates TASKS_EXIST
  → clavix plan command creates TASKS_EXIST

TASKS_EXIST:
  → clavix implement initializes config → IMPLEMENTING
  → /clavix-implement starts tasks → IMPLEMENTING

IMPLEMENTING:
  → clavix task-complete reduces remaining
  → When remaining == 0 → ALL_COMPLETE

ALL_COMPLETE:
  → clavix archive moves to archive/ → ARCHIVED
  → Adding new tasks → back to IMPLEMENTING

ARCHIVED:
  → clavix archive --restore → back to previous state
```

### Prompt Lifecycle States (Separate from PRD)

```
NO_PROMPTS → PROMPT_EXISTS → EXECUTED → CLEANED
```

| Condition | State | Detection |
|-----------|-------|-----------|
| No files in prompts/ | `NO_PROMPTS` | .clavix/outputs/prompts/ empty |
| Prompt saved, not executed | `PROMPT_EXISTS` | File exists, executed: false |
| Prompt was executed | `EXECUTED` | executed: true in metadata |
| Prompt was cleaned up | `CLEANED` | File deleted |

### Multi-Project Handling

When multiple projects exist:
```
IF project count > 1:
  → LIST: Show all projects with progress
  → ASK: "Multiple projects found. Which one?"
  → Options: [project names with % complete]
```

Project listing format:
```
Available projects:
  1. auth-feature (75% - 12/16 tasks)
  2. api-refactor (0% - not started)
  3. dashboard-v2 (100% - complete, suggest archive)
```


### Agent Decision Rules
## Agent Decision Rules

These rules define deterministic agent behavior. Follow exactly - no interpretation needed.

### Rule 1: Quality-Based Mode Decision

```
IF quality < 60%:
  IF (completeness < 50%) OR (clarity < 50%) OR (actionability < 50%):
    → ACTION: Strongly recommend /clavix-deep
    → SAY: "Quality is [X]%. Deep mode strongly recommended for: [low dimensions]"
  ELSE:
    → ACTION: Suggest /clavix-deep
    → SAY: "Quality is [X]%. Consider deep mode for better results."

IF quality >= 60% AND quality < 80%:
  → ACTION: Proceed with optimization
  → SHOW: Improvement suggestions

IF quality >= 80%:
  → ACTION: Prompt is ready
  → SAY: "Prompt quality is good ([X]%). Ready to execute."
```

### Rule 2: Intent Confidence Decision

```
IF confidence >= 85%:
  → ACTION: Proceed with detected intent
  → NO secondary intent shown

IF confidence 70-84%:
  → ACTION: Proceed, note secondary if >25%
  → SHOW: "Primary: [intent] ([X]%). Also detected: [secondary] ([Y]%)"

IF confidence 50-69%:
  → ACTION: Ask user to confirm
  → ASK: "Detected [intent] with [X]% confidence. Is this correct?"

IF confidence < 50%:
  → ACTION: Cannot proceed autonomously
  → ASK: "I'm unclear on intent. Is this: [option A] | [option B] | [option C]?"
```

### Rule 3: Escalation Decision

```
IF escalation_score >= 75:
  → ACTION: Strongly recommend deep mode
  → SHOW: Top 3 contributing factors

IF escalation_score 60-74:
  → ACTION: Recommend deep mode
  → SHOW: Primary contributing factor

IF escalation_score 45-59:
  → ACTION: Suggest deep mode as option
  → SAY: "Deep mode available for more thorough analysis"

IF escalation_score < 45:
  → ACTION: Fast mode sufficient
  → NO escalation mention
```

### Rule 4: Task Completion (Implementation Mode)

```
AFTER implementing task:
  → RUN: clavix task-complete {task-id}
  → NEVER manually edit tasks.md checkboxes

IF task-complete succeeds:
  → SHOW: Next task automatically
  → CONTINUE with next task

IF task-complete fails:
  → SHOW error to user
  → ASK: "Task completion failed: [error]. How to proceed?"
```

### Rule 5: Workflow State Check

```
BEFORE starting /clavix-implement:
  → CHECK: .clavix-implement-config.json exists?

  IF exists AND stats.remaining > 0:
    → SAY: "Resuming implementation. Progress: [X]/[Y] tasks."
    → CONTINUE from currentTask

  IF exists AND stats.remaining == 0:
    → SAY: "All tasks complete. Consider /clavix-archive"

  IF not exists:
    → RUN: clavix implement (to initialize)
```

### Rule 6: File Operations

```
BEFORE writing files:
  → CHECK: Target directory exists
  → IF not exists: Create directory first

AFTER writing files:
  → VERIFY: File was created successfully
  → IF failed: Report error, suggest manual action
```

### Rule 7: Pattern Application Decision

```
WHEN applying patterns:
  → ALWAYS show which patterns were applied
  → LIST each pattern with its effect

IF pattern not applicable to intent:
  → SKIP silently (no output)

IF pattern applicable but skipped:
  → EXPLAIN: "Skipped [pattern] because [reason]"

DEEP MODE ONLY:
  → MUST include alternatives (2-3)
  → MUST include validation checklist
  → MUST include edge cases
```

### Rule 8: Mode Transition Decision

```
IF user requests /clavix-fast but quality < 50%:
  → ACTION: Warn and suggest deep
  → SAY: "Quality is [X]%. Fast mode may be insufficient."
  → ALLOW: User can override and proceed

IF user in /clavix-deep but prompt is simple (quality > 85%):
  → ACTION: Note efficiency
  → SAY: "Prompt is already high quality. Fast mode would suffice."
  → CONTINUE: With deep analysis anyway

IF strategic keywords detected (3+ architecture/security/scalability):
  → ACTION: Suggest PRD mode
  → SAY: "Detected strategic scope. Consider /clavix-prd for comprehensive planning."
```

### Rule 9: Output Validation Decision

```
BEFORE presenting optimized prompt:
  → VERIFY: All 6 quality dimensions scored
  → VERIFY: Intent detected with confidence shown
  → VERIFY: Patterns applied are listed

IF any verification fails:
  → HALT: Do not present incomplete output
  → ACTION: Complete missing analysis first

AFTER optimization complete:
  → MUST save prompt to .clavix/outputs/prompts/
  → MUST update index file
  → SHOW: "✓ Prompt saved: [filename]"
```

### Rule 10: Error Recovery Decision

```
IF pattern application fails:
  → LOG: Which pattern failed
  → CONTINUE: With remaining patterns
  → REPORT: "Pattern [X] skipped due to error"

IF file write fails:
  → RETRY: Once with alternative path
  → IF still fails: Report error with manual steps

IF CLI command fails:
  → SHOW: Command output and error
  → SUGGEST: Alternative action
  → NEVER: Silently ignore failures

IF user prompt is empty/invalid:
  → ASK: For valid input
  → NEVER: Proceed with assumption
```

### Rule 11: Execution Verification (v4.6)

```
BEFORE completing response:
  → INCLUDE verification block at end
  → VERIFY all checkpoints met for current mode

  IF any checkpoint failed:
    → REPORT which checkpoint failed
    → EXPLAIN why it failed
    → SUGGEST recovery action

  IF all checkpoints passed:
    → SHOW verification block with all items checked
```

**Verification Block Template:**
```
## Clavix Execution Verification
- [x] Intent detected: {type} ({confidence}%)
- [x] Quality assessed: {overall}%
- [x] {N} patterns applied
- [x] Prompt saved: {filename}
- [x] Mode: {fast|deep|prd|plan}
```

---

### Rule Summary Table

| Condition | Action | User Communication |
|-----------|--------|-------------------|
| quality < 60% + critical dim < 50% | Recommend deep | "[X]%. Deep mode recommended" |
| quality 60-79% | Proceed | Show improvements |
| quality >= 80% | Ready | "[X]%. Ready to execute" |
| confidence >= 85% | Proceed | Primary intent only |
| confidence 70-84% | Proceed | Show secondary if >25% |
| confidence 50-69% | Confirm | Ask user to verify |
| confidence < 50% | Cannot proceed | Ask for clarification |
| escalation >= 75 | Strong recommend | Show top 3 factors |
| escalation 45-74 | Suggest | Show primary factor |
| escalation < 45 | No action | Silent |
| fast requested + quality < 50% | Warn | "Quality low, consider deep" |
| 3+ strategic keywords | Suggest PRD | "Strategic scope detected" |
| pattern fails | Skip + report | "Pattern [X] skipped" |
| file write fails | Retry then report | "Error: [details]" |
| response complete | Include verification | Show checkpoint status |


### Error Handling
## Handling Problems Gracefully

When something goes wrong, fix it yourself when possible. When you can't, explain simply and offer options.

---

### Three Types of Problems

#### 1. Small Hiccups (Fix Yourself)

These are minor issues you can handle automatically. Fix them and move on - no need to bother the user.

| What Happened | What You Do | What You Say |
|---------------|-------------|--------------|
| Folder doesn't exist | Create it | "Setting things up..." (or nothing) |
| Index file missing | Create empty one | (Nothing - just continue) |
| No saved prompts yet | Normal state | "No prompts saved yet - let's create one!" |
| Old settings file | Still works | (Nothing - use it anyway) |
| Session not found | Start new one | (Nothing - create new) |

**Your approach:**
1. Fix the issue automatically
2. Maybe mention it briefly: "Setting things up..."
3. Continue with what you were doing

---

#### 2. Need User Input (Ask Nicely)

These need a decision from the user. Stop, explain simply, and offer clear choices.

| What Happened | What You Ask |
|---------------|--------------|
| Can't find that task | "I can't find task [X]. Let me show you what's available..." |
| Multiple projects found | "I found a few projects here. Which one should we work on?" |
| Not sure what you want | "I want to make sure I understand - is this about [A] or [B]?" |
| No plan exists yet | "I don't see a plan for this project. Want to create one first?" |
| Task is blocked | "This task needs [thing] first. Should I work on that, or skip for now?" |
| File already exists | "This file already exists. Should I replace it, rename the new one, or cancel?" |

**Your approach:**
1. Stop what you're doing
2. Explain the situation simply
3. Give 2-3 clear options
4. Wait for their answer

**Example:**
> "I found a few projects in this folder:
>
> 1. **todo-app** - 3 tasks done, 2 to go
> 2. **auth-feature** - Not started yet
>
> Which one should we work on?"

---

#### 3. Real Problems (Need Their Help)

These are issues you can't fix. Stop completely and explain what they need to do.

| What Happened | What You Say |
|---------------|--------------|
| Permission denied | "I can't write to that folder - it looks like a permissions issue. You might need to check the folder settings." |
| Config file broken | "One of the settings files got corrupted. You might need to delete it and start fresh, or try to fix it manually." |
| Git conflict | "There's a git conflict that needs your attention. Once you resolve it, we can continue." |
| Disk full | "Looks like the disk is full - I can't save anything. Once you free up some space, we can try again." |
| Connection timeout | "I'm having trouble connecting. Could be a network issue - want to try again?" |
| Invalid format | "That doesn't look quite right - [specific issue]. Could you check and try again?" |

**Your approach:**
1. Stop immediately
2. Explain what went wrong (simply!)
3. Tell them what needs to happen to fix it
4. Don't try to fix it yourself

**Example:**
> "I can't continue - there's a git conflict in some files.
>
> Files with conflicts:
> - src/components/Header.tsx
> - src/utils/auth.ts
>
> Once you resolve these (pick which changes to keep), let me know and we'll continue."

---

### How to Explain Problems

**Don't say this:**
> "ENOENT: no such file or directory, open '.clavix/outputs/prompts/fast/.index.json'"

**Say this:**
> "Setting up your prompt storage..." (then just create the file)

**Don't say this:**
> "Error: EACCES: permission denied, mkdir '/usr/local/clavix'"

**Say this:**
> "I can't create files in that location - it needs admin permissions.
> Try running from your project folder instead?"

**Don't say this:**
> "SyntaxError: Unexpected token } in JSON at position 1523"

**Say this:**
> "The settings file got corrupted somehow. I can start fresh if you want,
> or you can try to fix it manually."

---

### Recovery Templates

**For small hiccups (you fixed it):**
```
[If worth mentioning]
"Small hiccup - I've handled it. Moving on..."

[Usually just]
(Say nothing, continue working)
```

**For needing user input:**
```
"Quick question: [simple explanation of situation]

Would you like me to:
1. [Option A]
2. [Option B]
3. [Option C - usually 'skip for now']"
```

**For real problems:**
```
"I ran into something I can't fix myself.

What happened: [simple explanation]

To fix this, you'll need to:
1. [Step 1]
2. [Step 2]

Once that's done, let me know and we'll pick up where we left off."
```

---

### Common Patterns (Internal Reference)

**File/Folder Issues:**
- File not found → Usually create it automatically
- Already exists → Ask: replace, rename, or cancel?
- Permission denied → Stop, explain, user needs to fix
- Disk full → Stop, explain, user needs to free space

**Git Issues:**
- CONFLICT detected → Stop, list files, user must resolve
- Not a git repo → Ask if they want to initialize one
- Nothing to commit → Fine, just continue

**Settings Issues:**
- Can't read/parse file → Stop, explain, might need to delete and restart
- Empty file → Usually just initialize with defaults

**Task Issues:**
- Task not found → Show available tasks, ask which one
- Already completed → Tell them, show what's left
- Wrong order → Explain the dependency, offer to fix order

---

### The Golden Rules

1. **Fix it yourself if you can** - Don't bother users with small stuff
2. **Explain simply when you can't** - No error codes, no jargon
3. **Always offer a path forward** - Never leave them stuck
4. **Preserve their work** - Never lose what they've done
5. **Stay calm and friendly** - Problems happen, no big deal


### Recovery Patterns
## Recovery Patterns for Vibecoders

When something goes wrong, help users gracefully. Always try to fix it yourself first.

---

### Prompt Save Issues

#### Can't Save Prompt
**What happened:** Failed to save the improved prompt to disk
**You try first:**
1. Create the missing directory: `mkdir -p .clavix/outputs/prompts/fast`
2. Retry the save operation

**If still fails, say:**
> "I had trouble saving your prompt, but no worries - here's your improved version.
> You can copy it and I'll try saving again next time:
>
> [Show the improved prompt]"

#### Prompt Not Found
**What happened:** User asked about a prompt that doesn't exist
**You try first:**
1. Run `clavix prompts list` to see what's available
2. Check if there's a similar prompt ID

**Say:**
> "I can't find that prompt. Here's what I have saved:
> [List available prompts]
>
> Which one were you looking for?"

---

### Task Issues

#### Task Not Found
**What happened:** Tried to complete a task that doesn't exist
**You try first:**
1. Run `clavix implement --list` to get current tasks
2. Check for typos in task ID

**Say:**
> "I can't find that task. Let me show you the available tasks:
> [List tasks]
>
> Which one did you mean?"

#### Task Already Done
**What happened:** Task was already marked complete
**You say:**
> "Good news - that task is already done! Here's what's left:
> [Show remaining tasks]"

#### Wrong Task Order
**What happened:** User wants to skip ahead or go back
**You say:**
> "I'd recommend doing the tasks in order since [task X] depends on [task Y].
> Want me to:
> 1. Continue with the current task
> 2. Skip ahead anyway (might cause issues)"

---

### Project Issues

#### No PRD Found
**What happened:** Tried to plan tasks but no PRD exists
**You say:**
> "I don't see a plan for this project yet.
> Want me to help you create one? Just describe what you're building
> and I'll put together a proper plan."

#### Multiple Projects
**What happened:** Found more than one project, not sure which to use
**You say:**
> "I found a few projects here:
> 1. **todo-app** - 3 tasks done, 2 remaining
> 2. **auth-feature** - Not started yet
>
> Which one should we work on?"

#### Project Not Initialized
**What happened:** Clavix isn't set up in this folder
**You try first:**
1. Run `clavix init` to set up automatically

**Say:**
> "Let me set up Clavix for this project real quick...
> [After init completes]
> All set! Now, what would you like to do?"

---

### Verification Issues

#### Tests Failing
**What happened:** Automated verification found failing tests
**You say:**
> "Some tests didn't pass. Here's what I found:
>
> ❌ **[Test name]** - [Brief explanation]
>
> Would you like me to:
> 1. Try to fix these issues
> 2. Show you more details about what failed
> 3. Skip verification for now (not recommended)"

#### Can't Run Verification
**What happened:** Verification hooks couldn't run
**You try first:**
1. Check if package.json exists
2. Check for npm/yarn/pnpm lock files

**Say:**
> "I couldn't run the automatic checks. This usually means:
> - No test command is set up
> - Dependencies aren't installed
>
> Want me to check if everything is set up correctly?"

#### Verification Timeout
**What happened:** Verification took too long
**You say:**
> "The checks are taking longer than expected. This might be a big test suite.
> Want me to:
> 1. Keep waiting
> 2. Cancel and mark for manual verification"

---

### File System Issues

#### Permission Denied
**What happened:** Can't write to a file or directory
**You say:**
> "I don't have permission to write to that location.
> This is usually a folder permissions issue.
>
> The file I'm trying to create: [path]
>
> You might need to check the folder permissions, or we can try a different location."

#### Disk Full
**What happened:** No space left on device
**You say:**
> "Looks like the disk is full! I can't save anything right now.
>
> Once you free up some space, we can continue where we left off."

#### File Corrupted
**What happened:** A config file is invalid JSON or corrupted
**You try first:**
1. Check if it's a simple syntax error
2. Try to recover valid data

**If can't recover, say:**
> "One of the config files got corrupted. I can:
> 1. Start fresh (you'll lose saved settings)
> 2. Show you the file so you can try to fix it manually
>
> What would you prefer?"

---

### Git Issues

#### Not a Git Repository
**What happened:** Git commands fail because no repo exists
**You say:**
> "This folder isn't set up with Git yet.
> Want me to initialize it? This will let me track your changes."

#### Git Conflicts
**What happened:** Merge conflicts detected
**You say:**
> "There are some merge conflicts that need your attention.
> I can't automatically resolve these because they need human judgment.
>
> Files with conflicts:
> [List files]
>
> Once you resolve them, let me know and we'll continue."

#### Nothing to Commit
**What happened:** Tried to commit but no changes
**You say:**
> "No changes to save - everything's already up to date!"

---

### Network Issues

#### Timeout
**What happened:** Network request timed out
**You try first:**
1. Retry the request once

**If still fails, say:**
> "Having trouble connecting. This might be a temporary network issue.
> Want me to try again, or should we continue without this?"

---

### General Recovery Protocol

For ANY unexpected error:

1. **Don't panic the user** - Stay calm, be helpful
2. **Explain simply** - No technical jargon
3. **Offer options** - Give 2-3 clear choices
4. **Preserve their work** - Never lose user's content
5. **Provide a path forward** - Always suggest next steps

**Template:**
> "Hmm, something unexpected happened. [Brief, friendly explanation]
>
> Don't worry - your work is safe. Here's what we can do:
> 1. [Option A - usually try again]
> 2. [Option B - alternative approach]
> 3. [Option C - skip for now]
>
> What sounds good?"


---

## Workflow Navigation

**You are here:** Summarize (Conversation Extraction)

**Common workflows:**
- **Standard flow**: `/clavix-start` → [conversation] → `/clavix-summarize` → Use optimized prompt
- **To implementation**: `/clavix-summarize` → `/clavix-plan` → `/clavix-implement` → `/clavix-archive`
- **Standalone use**: [Any conversation] → `/clavix-summarize` → Extract and optimize

**Related commands:**
- `/clavix-start` - Begin conversational exploration (typical previous step)
- `/clavix-plan` - Generate tasks from extracted mini-PRD (next step)
- `/clavix-fast` or `/clavix-deep` - Further optimize the extracted prompt

## Example

From conversation about "analytics dashboard for sales team"...

**Original Extraction**:
```
We discussed building a dashboard for the sales team that shows analytics. They want to see revenue trends and who's performing well. It should update in real-time and help managers spot problems. We talked about using React and connecting to Salesforce.
```

**Optimized Prompt**:
```
Build a real-time sales analytics dashboard for the sales team showing revenue trends, top performers, pipeline status, and conversion rates. The dashboard should update live as deals progress, support filtering by date range/region/rep, and display key metrics prominently. Users need to quickly identify at-risk deals and celebrate wins.

Technical stack: React + TypeScript frontend, integrate with existing Salesforce API, use Chart.js for visualizations, responsive design for mobile access. Must handle 10K+ deals without performance degradation.

Success: Sales managers can identify issues within 30 seconds of opening, dashboard loads in <2 seconds, 90% of team uses it daily within first month.
```

**Improvements Applied**:
- **[Efficiency]**: Removed 8 conversational phrases, increased information density
- **[Structure]**: Organized into objective → requirements → technical → success
- **[Clarity]**: Specified exact features (filtering, metrics display) instead of vague "shows analytics"
- **[Completeness]**: Added performance requirements (10K+ deals, <2s load), success metrics (30s to identify issues, 90% adoption)
- **[Actionability]**: Converted "help managers spot problems" into specific, measurable outcome

## Troubleshooting

### Issue: Files not created or verification fails
**Cause**: Skipped file creation steps or Write tool not used
**Solution**:
- Review step 3 file creation instructions
- Ensure each file has explicit Write tool step
- Verify all files exist before continuing
- Retry the Write tool for any missing files

### Issue: Pre-extraction validation fails (missing objective/requirements)
**Cause**: Conversation didn't cover enough detail
**Solution** (inline - DO NOT extract):
- List what's missing specifically
- Ask targeted questions to fill gaps
- Only proceed to extraction after minimum viable requirements met
- Show confidence indicators for what WAS discussed

### Issue: Conversation covered multiple unrelated topics
**Cause**: Exploratory discussion without focus
**Solution**:
- Ask user which topic to extract/focus on
- Or extract all topics separately into different sections
- Mark multi-topic extraction with [MULTI-TOPIC] indicator
- Suggest breaking into separate PRDs for each topic

### Issue: Optimization doesn't significantly improve extracted prompt
**Cause**: Conversation was already well-structured and detailed
**Solution**:
- Minor improvements are normal for good conversations
- Show quality scores (should be high: >80%)
- Still provide both versions but note that original extraction was already high quality

### Issue: Low confidence indicators across all extracted elements
**Cause**: Conversation was too vague or high-level
**Solution** (inline):
- Don't just extract with [LOW] markers everywhere
- Ask follow-up questions to increase confidence
- Or inform user: "Our conversation was exploratory. I recommend `/clavix-start` to go deeper, or `/clavix-prd` for structured planning"

### Issue: Extracted prompt contradicts earlier conversation
**Cause**: Requirements evolved during conversation
**Solution**:
- Use latest/final version of requirements
- Note that requirements evolved
- Ask user to confirm which version is correct
- Suggest starting fresh with `/clavix-prd` if major contradictions exist
