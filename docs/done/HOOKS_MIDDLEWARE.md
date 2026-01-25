# Hooks Middleware Plan

Status: draft for review

## Goal

Introduce a per-hook middleware abstraction that can interpret a contract between hook implementations and the main script. Middleware should process the hook exit code and captured output, and may introduce side effects in the main shell (for example, switch the main script to DRY_RUN mode). The default middleware must preserve current behavior: only exit codes matter, stdout/stderr are replayed as-is.

## Non-goals

- No middleware for sourced hooks (HOOKS_EXEC_MODE=source, or source-mode via hooks:exec:mode). Sourced hooks keep current behavior.
- No global middleware config; configuration is per-hook only.
- No change to hook declaration/registration semantics beyond middleware routing.

## Terminology

- Contract: The protocol between hook and main script. In this plan, the default contract is only exit codes. Custom middleware may parse contract lines from output to influence control flow.

## API Changes

- New per-hook API:
  - `hooks:middleware <hook> <function>`
    - Registers a middleware function for a hook.
    - Validates function exists.
  - `hooks:middleware <hook>` reset to default middleware (optional but useful for tests/demos)
- New default middleware should support a stable signature that includes:
  - hook name (last executed hook), exit_code, output_var, and hook args after `--`
  - Uses only exit_code, ignores output content, and replays captured lines unchanged.
  - Returns exit_code so existing call sites keep their behavior.

## Output Capture Contract

- Each implementation (hook function, registered function, exec-mode script) is executed through a capture harness.
- The harness produces a single timeline array with prefixed lines:
  - "1: " for stdout
  - "2: " for stderr
- A unique, global array name is used to store the capture, generated via `to:slug`:
  - Example name: `__<hook_slug>_<seq>`
- The array name is passed to middleware so it can parse and act on contract lines.

## Execution Flow (Updated)

0. Principle: each hook is treated as an atomic operation. It should only be interrupted by user signals (Ctrl+C/Ctrl+Z) or explicit middleware decisions. This is a guideline, not a hard enforcement.
1. Resolve which middleware applies to the hook:
   - If a per-hook middleware is set, use it.
   - Else use default inner middleware.
2. For each hook implementation (function, registered function, exec-mode script):
   - Run via capture harness.
   - Call middleware in the parent shell:
     - `{any_function_name_user_selected} <exit_code> <last_executed_hook_name> <output_var> -- <hook_args...>`
   - The middleware return code becomes the effective exit code for that implementation.
3. For sourced scripts:
   - Skip capture and middleware (sourced scripts has direct access to the main process global variables).
   - Keep existing source + hook:run behavior unchanged.
4. `hooks:do` respects the middleware exit code; middleware may stop/break/exit the main script as part of the contract.

## Capture Harness (macOS + Linux)

- Primary approach: process substitution to prefix each stream and then collect combined output into an array.
- Timeline precision is best-effort when stdout/stderr are buffered by the implementation.

## Compatibility Notes

- Hook functions and registered functions will run in a subshell due to capture; their direct side effects in the parent shell will no longer persist. Middleware is the supported channel for side effects.
- Sourced hooks remain the only option for direct in-shell modification by hook code.

## Prerequisite Tasks (must be completed before middleware work)

1. Unify registered functions and scripts into a single alphabetically ordered sequence (currently separate phases). See TODO in `.scripts/_hooks.sh`.
2. Downgrade the "No implementations found" warning to INFO (it is expected in most usages). See TODO in `.scripts/_hooks.sh`.

## Test Plan (ShellSpec)

Add or extend tests in spec/hooks_spec.sh:
- Default middleware preserves existing stdout/stderr and exit code behavior.
- Custom middleware can alter exit code and introduce side effects in parent shell.
- Source-mode scripts bypass middleware and preserve existing behavior.
- Per-hook middleware applies to functions, registered functions, and exec-mode scripts.

## Documentation Updates

Update docs/public/hooks.md:
- Add "Hooks Middleware (Contract)" section describing:
  - New per-hook API
  - Default contract (exit code only)
  - Output capture format ("1: "/"2: ")
  - Source-mode exception
  - Subshell side-effect note for function/registered implementations

## Demo Plan (demos/ci-mode)

Create a new demo folder with a simple main script and hook scripts to illustrate contract-driven modes:
- Modes: dry, ok, error, skip, timeout, test
- Custom middleware parses contract lines and sets variables or controls flow in the main script.
- Default middleware example shows legacy behavior with no contract parsing.

## Open Questions

- None at this time. All design decisions aligned with current requirements.
