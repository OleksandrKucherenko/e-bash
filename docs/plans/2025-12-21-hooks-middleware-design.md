# Hooks Middleware Design

Date: 2025-12-21
Status: validated design

## Summary
This design introduces a per-hook middleware abstraction that interprets a contract between hook implementations and the main script. The middleware processes the hook exit code and captured output, and may introduce side effects in the main shell (for example, switching to DRY_RUN). The default middleware preserves existing behavior by relying only on exit codes and replaying output unchanged.

## Architecture
Each hook implementation (hook function, registered function, exec-mode script) is executed through a capture harness. The harness records a unified timeline of stdout/stderr in a global array with per-line prefixes: "1: " for stdout and "2: " for stderr. The array name is derived from the hook name via to:slug and a sequence counter to ensure uniqueness. The capture harness returns the implementation exit code.

The parent shell then invokes the configured middleware with a stable signature:

middleware <hook> <exit_code> <output_var> -- <hook_args...>

The middleware return code becomes the effective exit code for that implementation. This allows custom middleware to alter control flow based on the contract. Source-mode scripts are explicitly excluded; they continue to use the current source + hook:run behavior without capture or middleware.

## Behavioral Notes
- Hook functions and registered functions run in a subshell due to capture, so direct side effects in the parent shell are no longer preserved. Middleware is the supported channel for side effects.
- Source-mode hooks remain the only option for in-shell modifications by hook code.
- Output ordering is best-effort and improved when stdbuf is available; macOS compatibility is required.

## Follow-up Plan
Implementation tasks, test coverage, and demo updates are detailed in:
- docs/HOOKS_MIDDLEWARE.md
