# CI Mode Middleware Demo

This folder contains two CI mode demos:

- `demo.ci-modes.sh` uses source-mode hooks to modify parent state directly.
- `demo.ci-modes-middleware.sh` uses exec-mode hooks plus middleware contracts.

## Middleware Contract

Exec-mode hook scripts emit contract lines on stdout:

- `contract:env:NAME=VALUE`
- `contract:env:NAME+=VALUE` (append)
- `contract:env:NAME^=VALUE` (prepend)
- `contract:env:NAME-=VALUE` (remove segment)
- `contract:route:/path/to/script`
- `contract:exit:CODE`

The middleware registered in `ci-20-compile.sh` (`_hooks:middleware:modes`) parses these
lines and applies side effects in the parent shell (setting env vars, routing to scripts,
or exiting with a specific code).

The mode hooks in `hooks-mw/` translate `HOOKS_FLOW_MODE` into these contract lines.

## Source Mode vs Middleware

- Source mode: hook scripts can modify parent state directly.
- Exec mode: hook scripts are isolated; middleware is the supported channel for side effects.

## Fail-fast and Traps

- The demo treats non-zero hook exit codes as immediate failure in the caller.
- `_hooks.sh` installs an `EXIT` trap (uses `trap:on` from `_traps.sh` when available) so
  `end` hooks still run on failure.
