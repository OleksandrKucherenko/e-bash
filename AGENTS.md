<!-- CLAVIX:START -->
# Clavix Instructions for Generic Agents

This guide is for agents that can only read documentation (no slash-command support). If your platform supports custom slash commands, use those instead.

---

## ⛔ CLAVIX MODE ENFORCEMENT (v4.7)

**CRITICAL: Know which mode you're in and STOP at the right point.**

**OPTIMIZATION workflows** (NO CODE ALLOWED):
- Fast/deep optimization - Prompt improvement only
- Your role: Analyze, optimize, show improved prompt, **STOP**
- ❌ DO NOT implement the prompt's requirements
- ✅ After showing optimized prompt, tell user: "Run `/clavix:execute --latest` to implement"

**PLANNING workflows** (NO CODE ALLOWED):
- Conversational mode, requirement extraction, PRD generation
- Your role: Ask questions, create PRDs/prompts, extract requirements
- ❌ DO NOT implement features during these workflows

**IMPLEMENTATION workflows** (CODE ALLOWED):
- Only after user runs execute/implement commands
- Your role: Write code, execute tasks, implement features
- ✅ DO implement code during these workflows

**If unsure, ASK:** "Should I implement this now, or continue with planning?"

See `.clavix/instructions/core/clavix-mode.md` for complete mode documentation.

---

## 📁 Detailed Workflow Instructions

For complete step-by-step workflows, see `.clavix/instructions/`:

| Workflow                 | Instruction File          | Purpose                                                 |
| ------------------------ | ------------------------- | ------------------------------------------------------- |
| **Conversational Mode**  | `workflows/start.md`      | Natural requirements gathering through discussion       |
| **Extract Requirements** | `workflows/summarize.md`  | Analyze conversation → mini-PRD + optimized prompts     |
| **Quick Optimization**   | `workflows/fast.md`       | Intent detection + quality assessment + smart triage    |
| **Deep Analysis**        | `workflows/deep.md`       | Comprehensive with alternatives, validation, edge cases |
| **PRD Generation**       | `workflows/prd.md`        | Socratic questions → full PRD + quick PRD               |
| **Mode Boundaries**      | `core/clavix-mode.md`     | Planning vs implementation distinction                  |
| **File Operations**      | `core/file-operations.md` | File creation patterns                                  |

**Troubleshooting:**
- `troubleshooting/jumped-to-implementation.md` - If you started coding during planning
- `troubleshooting/skipped-file-creation.md` - If files weren't created
- `troubleshooting/mode-confusion.md` - When unclear about planning vs implementation

---

## 🔍 Workflow Detection Keywords

| Keywords in User Request                            | Recommended Workflow                  | File Reference           |
| --------------------------------------------------- | ------------------------------------- | ------------------------ |
| "improve this prompt", "make it better", "optimize" | Fast mode → Quick optimization        | `workflows/fast.md`      |
| "analyze thoroughly", "edge cases", "alternatives"  | Deep mode → Comprehensive analysis    | `workflows/deep.md`      |
| "create a PRD", "product requirements"              | PRD mode → Socratic questioning       | `workflows/prd.md`       |
| "let's discuss", "not sure what I want"             | Conversational mode → Start gathering | `workflows/start.md`     |
| "summarize our conversation"                        | Extract mode → Analyze thread         | `workflows/summarize.md` |

**When detected:** Reference the corresponding `.clavix/instructions/workflows/{workflow}.md` file.

---

## 📋 CLI Quick Reference

| Command                                       | Purpose                                                                                 |
| --------------------------------------------- | --------------------------------------------------------------------------------------- |
| `clavix init`                                 | Interactive setup with integration selection                                            |
| `clavix fast "<prompt>"`                      | Quick optimization (CLI auto-saves; agent must save manually per template instructions) |
| `clavix deep "<prompt>"`                      | Deep analysis (CLI auto-saves; agent must save manually per template instructions)      |
| `clavix execute [--latest]`                   | Execute saved prompts (interactive or --latest)                                         |
| `clavix prompts list`                         | View saved prompts with status (NEW, EXECUTED, OLD, STALE)                              |
| `clavix prompts clear`                        | Manage cleanup (--executed, --stale, --fast, --deep, --all, --force)                    |
| `clavix prd`                                  | Guided PRD generation → `full-prd.md` + `quick-prd.md`                                  |
| `clavix plan`                                 | Transform PRD → phase-based `tasks.md`                                                  |
| `clavix implement [--commit-strategy=<type>]` | Execute tasks (git strategies: per-task, per-5-tasks, per-phase, none)                  |
| `clavix start`                                | Begin conversational session                                                            |
| `clavix summarize [session-id]`               | Extract PRD from session                                                                |
| `clavix list`                                 | List sessions and outputs                                                               |
| `clavix archive [project]`                    | Archive/restore completed projects                                                      |
| `clavix update`                               | Refresh documentation                                                                   |

**Quick start:**
```bash
npm install -g clavix
clavix init
clavix version
```

---

## 🔄 Standard Workflow

**Clavix follows this progression:**

```
PRD Creation → Task Planning → Implementation → Archive
```

**Detailed steps:**

1. **Planning Phase**
   - Run: User uses conversational mode or direct PRD generation
   - Output: `.clavix/outputs/{project}/full-prd.md` + `quick-prd.md`
   - Mode: PLANNING

2. **Task Preparation**
   - Run: `clavix plan` transforms PRD into curated task list
   - Output: `.clavix/outputs/{project}/tasks.md`
   - Mode: PLANNING (Pre-Implementation)

3. **Implementation Phase**
   - Run: `clavix implement [--commit-strategy=<type>]`
   - Agent executes tasks systematically
   - Mode: IMPLEMENTATION
   - Uses `clavix task-complete <taskId>` to mark progress

4. **Completion**
   - Run: `clavix archive [project]`
   - Archives completed work
   - Mode: Management

**Key principle:** Planning workflows create documents. Implementation workflows write code.

---

## 💡 Best Practices for Generic Agents

1. **Always reference instruction files** - Don't recreate workflow steps inline, point to `.clavix/instructions/workflows/`

2. **Respect mode boundaries** - Planning mode = no code, Implementation mode = write code

3. **Use checkpoints** - Follow the CHECKPOINT pattern from instruction files to track progress

4. **Create files explicitly** - Use Write tool for every file, verify with ls, never skip file creation

5. **Ask when unclear** - If mode is ambiguous, ask: "Should I implement or continue planning?"

6. **Track complexity** - Use conversational mode for complex requirements (15+ exchanges, 5+ features, 3+ topics)

7. **Label improvements** - When optimizing prompts, mark changes with [ADDED], [CLARIFIED], [STRUCTURED], [EXPANDED], [SCOPED]

---

## ⚠️ Common Mistakes

### ❌ Jumping to implementation during planning
**Wrong:** User discusses feature → agent generates code immediately

**Right:** User discusses feature → agent asks questions → creates PRD/prompt → asks if ready to implement

### ❌ Skipping file creation
**Wrong:** Display content in chat, don't write files

**Right:** Create directory → Write files → Verify existence → Display paths

### ❌ Recreating workflow instructions inline
**Wrong:** Copy entire fast mode workflow into response

**Right:** Reference `.clavix/instructions/workflows/fast.md` and follow its steps

### ❌ Not using instruction files
**Wrong:** Make up workflow steps or guess at process

**Right:** Read corresponding `.clavix/instructions/workflows/*.md` file and follow exactly

---

**Artifacts stored under `.clavix/`:**
- `.clavix/outputs/<project>/` - PRDs, tasks, prompts
- `.clavix/sessions/` - Captured conversations
- `.clavix/templates/` - Custom overrides

---

**For complete workflows:** Always reference `.clavix/instructions/workflows/{workflow}.md`

**For troubleshooting:** Check `.clavix/instructions/troubleshooting/`

**For mode clarification:** See `.clavix/instructions/core/clavix-mode.md`

<!-- CLAVIX:END -->

## 🛠️ Bash Scripting Standards

### When implementing logging in bash scripts:
1. ALWAYS declare DEBUG variable BEFORE sourcing the logger: `DEBUG=${DEBUG:-"myapp,-internal"} source "$E_BASH/_logger.sh"`
2. Ensure E_BASH variable is globally available (export or use direnv)
3. Be explicit in DEBUG variable definition - enable all application tags, and disable internal ones that are important for debugging:
   `DEBUG="main,api,db,cache,auth,-loader"`, skip unimportant internal tags like: internal, parser.
4. Register loggers with domain-specific names (api, db, auth, etc.). In complex script use unique names for different loggers.
5. Pass script parameters during logger initialization to support global --debug flag/option for scripts: `logger tag "$@"`
6. Redirect most loggers to STDERR by default: `logger:redirect myapp ">&2"`. Make logger creation and configuration in one line: `logger sample "$@" && logger:prefix sample "${cl_cyan}[Sample]${cl_reset} " && logger:redirect sample ">&2"`
7. Use color-coded prefixes for quick identification:
   - Red for errors: `logger:prefix "error" "${cl_red}[Error]${cl_reset} "`
   - Yellow for warnings: `logger:prefix "warn" "${cl_yellow}[Warning]${cl_reset} "`
   - Gray for debug info: `logger:prefix "debug" "${cl_gray}[Debug]${cl_reset} "`
   - Define one color for each entity print in logs. Highlight filenames/filepath, copy/paste instructions, extracted values, etc. Be consistent in the use of colors during the whole script.
8. Prefer piping with `log:Tag` over direct `echo:Tag` when processing command output
9. For log aggregation across processes, use named pipes or common log files
10. Log use-case flows, not modules itself - prefer to track use scenario, instead of individual components
11. Use consistent success/error (lifecycle) messages:
    - Successful operations should utilize one of the predefined loggers for that: `echo:Success "Operation completed"`
    - Failed operations should utilize one of the predefined loggers for that: `echo:Error "Operation failed: $reason"`
    - Samples of specialized loggers: `echo:Success`, `echo:Error`, `echo:Warning`; User can prefer to use shorter variations of names for specialized lifecycle state of the script;
12. Reserve a debug/trace logger for troubleshooting: log input parameters, execution flow, and intermediate results, example: `echo:Dump "${LINENO}: $@"`; 
    - use `${LINENO}` to track line numbers for identical messages;
    - use `logger:push` and `logger:pop` to save and restore logger state, for recursive operations;
13. Instead of allowing command to print directly to STDOUT/STDERR, use pipe output to `log:Tag` to capture output
    - filter important for script output lines only (grep, awk, sed)
14. To disable colors in log messages, set `TERM=dumb` before sourcing E-BASH scripts
15. Use `log:Tag` pipes to send the same message to multiple loggers when needed
16. Remember that `echo:Tag` and `printf:Tag` are wrappers over built-in commands, supporting all their options
17. Include a session/correlation ID in logs to track related operations: `export __SESSION=$(date +%s%N)` if you expect a heavy usage of the script in multi-process environment (like CI/CD pipelines, cron jobs);
18. Avoid warpping loggers with custom functions

### When implementing BASH script functions:
- use local variables as much as possible;
- pre-declare local variables at the beginning of the function;
- safe space and declare multiple local variables on the same line, but no more than 5 variables per line;
- in commands try to use first expanded version of flags instead of short names, example: instead of `-f` use `--force`
- try to keep nested code to minimum, reduce code complexity:
  - avoid nested if statements
  - avoid nested for loops
  - do quick return from functions at the beginning of the function only

