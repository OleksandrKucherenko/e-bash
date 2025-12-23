# Clavix Instructions

Welcome to Clavix! This directory contains your local Clavix configuration and data.

## Directory Structure

```
.clavix/
├── config.json           # Your Clavix configuration
├── INSTRUCTIONS.md       # This file
├── sessions/             # Conversational mode session files
├── outputs/
│   ├── <project-name>/  # Per-project outputs
│   │   ├── full-prd.md
│   │   ├── quick-prd.md
│   │   ├── tasks.md
│   │   └── .clavix-implement-config.json
│   ├── prompts/         # Saved prompts for re-execution (v4.11 unified)
│   └── archive/         # Archived completed projects
└── templates/           # Custom template overrides (optional)
```

## CLI Commands Reference

### Prompt Improvement (v4.11)
- `clavix improve "<prompt>"` - Smart prompt optimization with auto depth selection
- `clavix improve "<prompt>" --comprehensive` - Force comprehensive depth analysis
- `clavix execute [--latest]` - Execute saved prompts
- `clavix prompts list` - View all saved prompts with status (NEW/EXECUTED/OLD/STALE)
- `clavix prompts clear` - Cleanup prompts (`--executed`, `--stale`, `--standard`, `--comprehensive`, `--all`)

### PRD & Planning
- `clavix prd` - Generate PRD through guided Socratic questions
- `clavix plan` - Transform PRD or session into phase-based `tasks.md`
- `clavix start` - Start conversational mode for requirements gathering
- `clavix summarize [session-id]` - Extract mini-PRD and prompts from conversation

### Implementation
- `clavix implement [--commit-strategy=<type>]` - Execute tasks with optional git auto-commits
- `clavix task-complete <taskId>` - Mark task complete with validation, auto-show next task

### Project Management
- `clavix list [--sessions|--outputs]` - List sessions and/or output projects
- `clavix show [session-id|--output <project>]` - Inspect session or project details
- `clavix archive [project] [--restore]` - Archive completed projects or restore them

### Configuration
- `clavix init` - Initialize Clavix (you just ran this!)
- `clavix config [get|set|edit|reset]` - Manage configuration preferences
- `clavix update [--docs-only|--commands-only]` - Refresh managed docs and slash commands
- `clavix version` - Print installed version

## Slash Commands (AI Agents)

If using Claude Code, Cursor, or Windsurf, the following slash commands are available:

**Note:** Running `clavix init` or `clavix update` will regenerate all slash commands from templates. Any manual edits to generated commands will be lost. If you need custom commands, create new command files instead of modifying generated ones.

**Command format varies by integration:**
- Claude Code, Gemini, Qwen: `/clavix:improve` (colon format)
- Cursor, Droid, Windsurf, etc.: `/clavix-improve` (hyphen format)

### Prompt Improvement (v4.11)
- `improve [prompt]` - Smart optimization with auto depth selection
- `execute` - Execute saved prompts

### PRD & Planning
- `/clavix:prd` - Generate PRD through guided questions
- `/clavix:plan` - Generate task breakdown from PRD
- `/clavix:start` - Start conversational mode
- `/clavix:summarize` - Summarize conversation

### Implementation
- `/clavix:implement` - Execute task workflow with git integration

### Project Management
- `/clavix:archive` - Archive completed projects

## Workflows

### Prompt Lifecycle (v4.11)

1. **Create improved prompt**:
   ```bash
   clavix improve "your prompt here"
   # Clavix auto-selects depth based on quality analysis:
   # - <60% quality: standard depth (basic fixes)
   # - 60-74%: asks user to choose
   # - >=75%: comprehensive depth (polish)
   ```
   - CLI auto-saves to `.clavix/outputs/prompts/`
   - Slash commands require manual save per template instructions

2. **Execute saved prompt**:
   ```bash
   clavix execute --latest  # Most recent prompt
   clavix execute           # Interactive selection
   ```

3. **Manage prompts**:
   ```bash
   clavix prompts list              # View all with status
   clavix prompts clear --executed  # Remove executed prompts
   clavix prompts clear --stale     # Remove stale (30+ days)
   ```

**Prompt Status**:
- `NEW` - Just created, never executed
- `EXECUTED` - Successfully executed at least once
- `OLD` - 7+ days old, not executed
- `STALE` - 30+ days old, not executed

### Implementation Workflow (v1.3+)

1. **Generate PRD**:
   ```bash
   clavix prd
   # Creates: .clavix/outputs/<project>/full-prd.md + quick-prd.md
   ```

2. **Create task breakdown**:
   ```bash
   clavix plan
   # Creates: .clavix/outputs/<project>/tasks.md
   ```

3. **Execute tasks with git integration**:
   ```bash
   # Manual commits (default):
   clavix implement

   # Or with auto-commit strategy:
   clavix implement --commit-strategy=per-phase
   ```

4. **Mark tasks complete**:
   ```bash
   clavix task-complete <taskId>
   # Validates completion, optionally commits, shows next task
   ```

5. **Archive when done**:
   ```bash
   clavix archive my-project
   ```

### Git Auto-Commit Strategies (v2.8.1)

When using `clavix implement --commit-strategy=<type>`:

- `none` (default) - Manual git workflow, full control
- `per-task` - Commit after each completed task (detailed history)
- `per-5-tasks` - Commit every 5 tasks (balanced)
- `per-phase` - Commit when phase completes (milestone-based)

**Recommendation**: Use `none` for most projects. Only enable auto-commits for large implementations with clear phases.

## When to Use Which Mode (v4.11)

- **Improve mode**: Smart prompt optimization with auto depth selection
  - Standard depth: Quick cleanup for simpler prompts
  - Comprehensive depth: Thorough analysis for complex requirements
- **PRD mode**: Strategic planning with architecture, risks, and business impact
- **Conversational mode** (`start`/`summarize`): Natural discussion → extract structured requirements

## Typical Workflows

**Improve a prompt** (v4.11 unified):
```bash
clavix improve "Add user authentication"
clavix execute --latest
```

**Create and execute strategy**:
```bash
clavix prd              # Generate PRD
clavix plan             # Create tasks.md
clavix implement        # Execute with manual commits
```

**Capture conversation**:
```bash
clavix start            # Record conversation
# ... discuss requirements ...
clavix summarize        # Extract mini-PRD + prompt
```

**Stay organized**:
```bash
clavix list             # See all projects
clavix show --output my-project
clavix archive my-project
```

## Customization

Create custom templates in `.clavix/templates/` to override defaults:
- `improve.txt` - Custom improve mode template
- `prd-questions.txt` - Custom PRD questions

Edit configuration:
```bash
clavix config edit      # Opens config.json in $EDITOR
clavix config set key=value
```

## Need Help?

- **Documentation**: https://github.com/ClavixDev/Clavix
- **Issues**: https://github.com/ClavixDev/Clavix/issues
- **Version**: Run `clavix version` to check your installed version
- **Update managed blocks**: Run `clavix update` to refresh documentation
