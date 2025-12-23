# Clavix: Archive Your Completed Work

Done with a project? I'll move it to the archive to keep your workspace tidy. You can always restore it later if needed.

---

## What This Does

When you run `/clavix:archive`, I:
1. **Find your completed projects** - Look for 100% done PRDs
2. **Ask which to archive** - You pick, or I archive all completed ones
3. **Move to archive folder** - Out of the way but not deleted
4. **Track everything** - So you can restore later if needed

**Your work is never deleted, just organized.**

---

## CLAVIX MODE: Archival

**I'm in archival mode. Organizing your completed work.**

**What I'll do:**
- ✓ Find projects ready for archive
- ✓ Show you what's complete (100% tasks done)
- ✓ Move projects to archive when you confirm
- ✓ Track everything so you can restore later

**What I won't do:**
- ✗ Delete anything without explicit confirmation
- ✗ Archive projects you're still working on (unless you use --force)
- ✗ Make decisions for you - you pick what to archive

---

## How I Archive Projects

**I handle all the commands - you just tell me what to do.**

### What I Run (You Don't Need To)

| What You Want | Command I Execute |
|---------------|-------------------|
| Archive completed project | `clavix archive` |
| Archive specific project | `clavix archive [name]` |
| Archive incomplete work | `clavix archive [name] --force` |
| Delete permanently | `clavix archive [name] --delete` |
| See what's archived | `clavix archive --list` |
| Restore from archive | `clavix archive --restore [name]` |

### Before I Archive

I check:
- ✓ Projects exist in `.clavix/outputs/`
- ✓ What you want to do (archive, delete, restore)
- ✓ Project name is correct

### After Archiving

I tell you:
- Where the project went
- How to restore it (unless you deleted it)
- What to do next

### Part B: Understanding Archive Operations

**Archive Modes**:

1. **Interactive Archive Mode**:
   ```bash
   clavix archive
   ```

   CLI behavior:
   - Lists all PRD projects with 100% tasks completed
   - Allows user to select which project to archive
   - Confirms before archiving
   - Moves the project to archive directory

2. **Archive Specific Project**:
   ```bash
   clavix archive [project-name]
   ```

   CLI behavior:
   - Checks task completion status
   - Warns if tasks are incomplete
   - Asks for confirmation
   - Archives the specific project

3. **Force Archive (Incomplete Tasks)**:
   ```bash
   clavix archive [project-name] --force
   ```

   Use when:
   - Project scope changed and some tasks are no longer relevant
   - User wants to archive work-in-progress
   - Tasks are incomplete but project is done

4. **Delete Project (Permanent Removal)**: **DESTRUCTIVE ACTION**
   ```bash
   clavix archive [project-name] --delete
   ```

   **WARNING**: This PERMANENTLY deletes the project. Cannot be restored.

   **When to delete vs archive:**
   - **DELETE**: Failed experiments, duplicate projects, test/demo data, abandoned prototypes with no value
   - **ARCHIVE**: Completed work, incomplete but potentially useful work, anything you might reference later

   **Delete decision tree:**
   ```
   Is this a failed experiment with no learning value? → DELETE
   Is this a duplicate/test project with no unique info? → DELETE
   Might you need to reference this code later? → ARCHIVE
   Could this be useful for learning/reference? → ARCHIVE
   Are you unsure? → ARCHIVE (safe default)
   ```

   **Safety confirmation required:**
   - Shows project details and task status
   - Requires typing project name to confirm
   - Warns about permanent deletion
   - Lists what will be permanently deleted

5. **List Archived Projects**:
   ```bash
   clavix archive --list
   ```

   Shows all projects currently in archive with their task completion status

6. **Restore from Archive**:
   ```bash
   clavix archive --restore [project-name]
   ```

   Moves a project back from archive to active outputs

## When to Archive

**Good times to archive:**
- All implementation tasks are completed (`tasks.md` shows 100%)
- Project has been deployed/shipped to production
- Feature is complete and no more work planned
- User explicitly requests archival
- Old/abandoned projects that won't be continued

**Don't archive when:**
- Tasks are still in progress (unless using --force)
- Project is actively being worked on
- Future enhancements are planned in current tasks

## Archive Behavior

**What gets archived:**
- The entire PRD project folder
- All files: PRD.md, PRD-quick.md, tasks.md, .clavix-implement-config.json
- Complete directory structure preserved

**Where it goes:**
- From: `.clavix/outputs/[project-name]/`
- To: `.clavix/outputs/archive/[project-name]/`

**What changes:**
- Archived projects won't show in `/clavix:plan` searches
- Archived projects won't show in `/clavix:implement` searches
- They're still accessible in archive directory
- Can be restored at any time

## Prompts Are Separate

Fast/deep prompts from `/clavix:fast` and `/clavix:deep` are stored separately in `.clavix/outputs/prompts/`.

**Prompts are NOT archived with PRD projects.**

**Manage prompts separately (CLI commands):**
```bash
clavix prompts list           # View all prompts
clavix prompts clear          # Interactive cleanup
clavix prompts clear --executed  # Remove executed only
clavix prompts clear --stale     # Remove >30 day old
```

**Before archiving, consider cleanup:**
```bash
clavix prompts clear --executed
```

**Prompts lifecycle:**
- Independent from PRD lifecycle
- Managed via CLI commands
- Clear manually when project complete

## Example Workflows

### Workflow 1: Complete Project
```
User: "I've finished implementing the user authentication feature"
You: "Great! Let me help you archive it."

     Run: clavix archive

User selects: user-authentication-system
System shows: All 15 tasks completed (100%)
User confirms: Yes, archive it

Result: Project moved to .clavix/outputs/archive/user-authentication-system/
```

### Workflow 2: Force Archive WIP
```
User: "We're pivoting, I want to archive the old API design even though tasks aren't done"
You: "I'll archive it with --force"

     Run: clavix archive old-api-design --force

System shows: 8 incomplete tasks
User confirms: Yes, archive anyway

Result: Project archived despite incomplete tasks
```

### Workflow 3: Restore Archived Project
```
User: "Actually, we need to revisit that authentication feature"
You: "I'll restore it from the archive"

     Run: clavix archive --restore user-authentication-system

Result: Project moved back to .clavix/outputs/user-authentication-system/
```

### Workflow 4: Delete Failed Experiment
```
User: "I have a test project 'api-experiment-1' that I don't need anymore"
You: "Is this something you might reference later, or can it be permanently deleted?"

User: "It was just a quick test, no value. Delete it."
You: "This will permanently delete the project. I'll run the delete command."

     Run: clavix archive api-experiment-1 --delete

System shows:
  Project: api-experiment-1
  Tasks: 3/5 completed
  Files: full-prd.md, quick-prd.md, tasks.md

  WARNING: This action is PERMANENT and CANNOT be undone.
  Type the project name to confirm deletion: _

User types: api-experiment-1

Result: Project permanently deleted from .clavix/outputs/api-experiment-1/
```

---

## Agent Transparency (v4.9)

### CLI Reference (Commands I Execute)
## CLI Commands Reference (For Agent Execution)

These are commands YOU (the agent) run automatically. Never ask the user to run these - you execute them and report results.

---

### Prompt Management Commands

#### `clavix fast "prompt"`
**What it does:** Quickly improves a prompt and saves it
**When to run:** After user provides a prompt for optimization
**You say:** "Let me improve this prompt for you..."
**Example:**
```bash
clavix fast "build a todo app"
```

#### `clavix deep "prompt"`
**What it does:** Comprehensive prompt analysis with alternatives and edge cases
**When to run:** When prompt needs thorough analysis (complex requirements, low quality score)
**You say:** "This needs a deeper look - let me analyze it thoroughly..."
**Example:**
```bash
clavix deep "create authentication system with OAuth"
```

#### `clavix analyze "prompt"`
**What it does:** Returns structured JSON with intent, quality scores, and escalation recommendation
**When to run:** When you need data-driven decision on which mode to use
**You say:** Nothing - this is for internal decision-making
**Example:**
```bash
clavix analyze "build a login page"
```
**Output:** JSON with `intent`, `confidence`, `quality` (6 dimensions), `escalation` (score + recommendation)
**Flags:**
- `--pretty` - Pretty-print the JSON output

#### `clavix prompts list`
**What it does:** Shows all saved prompts with their status
**When to run:** To verify a prompt was saved, or find prompt IDs
**You say:** "Let me check your saved prompts..."
**Example output:**
```
📋 Saved Prompts (3 total)
  fast-20250126-143022-a3f2  [not executed]  "build a todo app..."
  deep-20250126-150000-b4c3  [executed]      "authentication system..."
```

#### `clavix prompts clear --executed`
**What it does:** Removes prompts that have already been implemented
**When to run:** During cleanup or when user wants to tidy up
**You say:** "Cleaning up executed prompts..."

#### `clavix prompts clear --stale`
**What it does:** Removes prompts older than 30 days
**When to run:** When storage is cluttered with old prompts
**You say:** "Removing old prompts to keep things tidy..."

---

### Implementation Commands

#### `clavix execute --latest`
**What it does:** Retrieves the most recent saved prompt for implementation
**When to run:** When starting implementation workflow
**You say:** "Getting your latest prompt ready for implementation..."
**Flags:**
- `--latest` - Get most recent prompt
- `--fast` - Filter to fast prompts only
- `--deep` - Filter to deep prompts only
- `--id <prompt-id>` - Get specific prompt

#### `clavix implement`
**What it does:** Starts implementation session from task plan
**When to run:** After PRD and tasks exist, ready to build
**You say:** "Starting implementation - let me check your tasks..."
**Flags:**
- `--commit-strategy=per-task` - Commit after each task
- `--commit-strategy=per-phase` - Commit after each phase
- `--list` - Show available tasks

#### `clavix task-complete <task-id>`
**What it does:** Marks a task as done, updates tracking, optionally commits
**When to run:** IMMEDIATELY after finishing each task implementation
**You say:** "Marking that task as complete..."
**CRITICAL:** Never manually edit tasks.md checkboxes - always use this command
**Example:**
```bash
clavix task-complete phase-1-setup-project-1
```
**Flags:**
- `--no-git` - Skip git commit
- `--force` - Complete even if already done

#### `clavix verify --latest`
**What it does:** Runs verification checks against implementation
**When to run:** After implementation, before considering work done
**You say:** "Running verification checks..."
**Flags:**
- `--latest` - Verify most recent executed prompt
- `--id <prompt-id>` - Verify specific prompt
- `--status` - Show verification status only
- `--retry-failed` - Re-run only failed checks
- `--export markdown` - Generate verification report
- `--run-hooks` - Run automated tests (default: true)

---

### Planning Commands

#### `clavix prd`
**What it does:** Launches PRD generation workflow
**When to run:** When user wants to plan a feature/project
**You say:** "Let's plan this out properly..."

#### `clavix plan`
**What it does:** Generates task breakdown from PRD
**When to run:** After PRD exists, ready to create tasks
**You say:** "Creating your implementation tasks..."
**Flags:**
- `--project <name>` - Specify which project
- `--overwrite` - Regenerate existing tasks

---

### Project Management Commands

#### `clavix archive <project-name>`
**What it does:** Archives completed project
**When to run:** When all tasks are done and verified
**You say:** "Archiving this project for your records..."
**Flags:**
- `--force` - Archive even if incomplete
- `--delete` - Permanently delete instead
- `--list` - Show archived projects
- `--restore <name>` - Restore from archive

#### `clavix list`
**What it does:** Shows sessions and outputs
**When to run:** To find projects, check progress
**You say:** "Let me show you what we have..."
**Flags:**
- `--sessions` - List only sessions
- `--outputs` - List only outputs
- `--archived` - Include archived
- `--project <name>` - Filter by project

#### `clavix show --output <project>`
**What it does:** Shows detailed project information
**When to run:** When user asks about a specific project
**You say:** "Here's what's in that project..."

---

### Setup & Configuration Commands

#### `clavix init`
**What it does:** Sets up Clavix in current project
**When to run:** First time using Clavix in a project
**You say:** "Setting up Clavix for this project..."
**Features:**
- Auto-detects tech stack
- Configures integrations
- Creates .clavix/ directory

#### `clavix config get <key>`
**What it does:** Gets a configuration value
**When to run:** To check current settings
**Example:** `clavix config get preferences.verboseLogging`

#### `clavix config set <key> <value>`
**What it does:** Updates a configuration value
**When to run:** When user wants to change settings
**You say:** "Updating that setting..."

#### `clavix update`
**What it does:** Updates slash commands and documentation
**When to run:** After Clavix version update
**You say:** "Updating your Clavix setup..."
**Flags:**
- `--docs-only` - Update only documentation
- `--commands-only` - Update only slash commands

#### `clavix version`
**What it does:** Shows current Clavix version
**When to run:** To check version, troubleshoot issues
**Example output:** `Clavix v4.9.0`

---

### Agent Execution Protocol

**ALWAYS:**
1. Run commands silently (don't show raw command to user)
2. Report results in friendly language
3. Handle errors gracefully (see error-handling.md)
4. Continue workflow after successful commands

**NEVER:**
1. Ask user to run terminal commands
2. Show raw CLI output without explanation
3. Skip verification after implementation
4. Manually edit files that commands should update

**Example Flow:**
```
User: "I'm done with task 1"

Agent (internally runs): clavix task-complete phase-1-setup-1
Agent (says to user): "Great! I've marked that task complete.
                       You're now 1/5 tasks done.
                       Ready to start the next one?"
```


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


### Agent Decision Rules
## Agent Decision Rules

These rules define deterministic agent behavior. Follow exactly - no interpretation needed.

### Rule 1: Quality-Based Mode Decision

```
IF quality < 60%:
  IF (completeness < 50%) OR (clarity < 50%) OR (actionability < 50%):
    → ACTION: Strongly recommend /clavix:deep
    → SAY: "Quality is [X]%. Deep mode strongly recommended for: [low dimensions]"
  ELSE:
    → ACTION: Suggest /clavix:deep
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
BEFORE starting /clavix:implement:
  → CHECK: .clavix-implement-config.json exists?

  IF exists AND stats.remaining > 0:
    → SAY: "Resuming implementation. Progress: [X]/[Y] tasks."
    → CONTINUE from currentTask

  IF exists AND stats.remaining == 0:
    → SAY: "All tasks complete. Consider /clavix:archive"

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
IF user requests /clavix:fast but quality < 50%:
  → ACTION: Warn and suggest deep
  → SAY: "Quality is [X]%. Fast mode may be insufficient."
  → ALLOW: User can override and proceed

IF user in /clavix:deep but prompt is simple (quality > 85%):
  → ACTION: Note efficiency
  → SAY: "Prompt is already high quality. Fast mode would suffice."
  → CONTINUE: With deep analysis anyway

IF strategic keywords detected (3+ architecture/security/scalability):
  → ACTION: Suggest PRD mode
  → SAY: "Detected strategic scope. Consider /clavix:prd for comprehensive planning."
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


## Workflow Navigation

**You are here:** Archive (Project Cleanup)

**Common workflows:**
- **Complete workflow**: `/clavix:implement` → [all tasks done] → `/clavix:archive` → Clean workspace
- **Review and archive**: `/clavix:archive` → [select completed project] → Archive
- **Restore old work**: `/clavix:archive --list` → `/clavix:archive --restore [project]` → Resume

**Related commands:**
- `/clavix:implement` - Complete remaining tasks before archiving
- `/clavix:plan` - Review task completion status
- `/clavix:prd` - Start new project after archiving old one

## Tips

- Archive keeps your active projects list clean and focused
- Archived projects maintain all their data (nothing is deleted)
- Archive is searchable - you can still `grep` or find files in archive/
- Regular archiving improves `/clavix:plan` and `/clavix:implement` performance
- Use `--list` regularly to know what's been archived

## Troubleshooting

### Issue: No projects available to archive
**Cause**: No projects in `.clavix/outputs/` OR all already archived

**Agent recovery**:
1. Check if `.clavix/outputs/` exists: `ls .clavix/outputs/`
2. If directory doesn't exist: "No PRD projects found. Create one with `/clavix:prd`"
3. If empty: Run `clavix archive --list` to show archived projects
4. Communicate: "All projects are already archived" or "No projects exist yet"

### Issue: Trying to archive project with incomplete tasks
**Cause**: User wants to archive but tasks aren't 100% done

**Agent recovery**:
1. CLI will warn about incomplete tasks
2. Ask user: "Project has X incomplete tasks. Do you want to:
   - Complete tasks first with `/clavix:implement`
   - Archive anyway with `--force` (tasks remain incomplete but archived)
   - Cancel archival"
3. If user confirms force: Run `clavix archive [project] --force`
4. If scope changed: Explain `--force` is appropriate

### Issue: Cannot restore archived project (name conflict)
**Cause**: Project with same name already exists in active outputs

**Agent recovery**:
1. CLI will show error: "Project '[name]' already exists in active outputs"
2. Ask user which option:
   - Archive the active project first, then restore old one
   - Keep both (manual rename required)
   - Cancel restoration
3. Execute user's choice

### Issue: Unsure whether to delete or archive
**Cause**: User wants to clean up but uncertain about permanence

**Agent recovery**:
1. Use decision tree to guide user:
   ```
   Ask user questions:
   - "Is this a failed experiment with no learning value?"
   - "Might you need to reference this code later?"
   - "Are you unsure if it's valuable?"
   ```
2. Default recommendation: **ARCHIVE** (safer, reversible)
3. Only suggest DELETE for: duplicates, failed experiments, test data with zero value
4. Remind: "Archive is free, disk space is cheap, regret is expensive"

### Issue: CLI command fails or hangs
**Cause**: File system permissions, missing directory, or process error

**Agent recovery**:
1. Check error output from CLI
2. Common fixes:
   - Check `.clavix/outputs/` exists and is writable
   - Verify project name is correct (no typos)
   - Check if another process is accessing the files
3. Suggest: Run with full project path or retry
4. If persistent: Inform user to check file permissions

### Issue: Accidentally deleted project (used --delete instead of archive)
**Cause**: User error or misunderstanding of --delete flag

**Agent recovery**:
1. Acknowledge: "Project was permanently deleted via `--delete` flag"
2. Check recovery options:
   - "If code was committed to git, we can recover from git history"
   - "Check if you have local backups"
   - "Check if IDE has local history (VS Code, JetBrains)"
3. Prevention: "Going forward, use ARCHIVE by default. Only DELETE when absolutely certain."
4. No recovery possible from Clavix itself

### Issue: Archive directory getting too large
**Cause**: Many archived projects accumulating

**Agent response**:
1. Explain: "Archive is designed to grow - this is normal behavior"
2. Archived projects don't affect active command performance
3. If user truly concerned:
   - Review archive: `clavix archive --list`
   - Identify ancient/irrelevant projects
   - Delete only truly obsolete ones: `clavix archive [old-project] --delete`
   - Or suggest external backup for very old projects

### Issue: Archived project but forgot what it was about
**Cause**: No naming convention or time passed

**Agent recovery**:
1. Read the PRD to remind user:
   ```bash
   cat .clavix/outputs/archive/[project-name]/full-prd.md
   ```
2. Summarize: Problem, Goal, Features from PRD
3. Suggest: Better naming conventions going forward
   - Example: `2024-01-user-auth` (date-feature format)
   - Example: `ecommerce-checkout-v2` (project-component format)