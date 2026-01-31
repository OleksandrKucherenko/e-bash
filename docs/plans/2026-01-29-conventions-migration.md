# Conventions Migration Plan (2026-01-29)

## Goals

- Align all .scripts modules with naming conventions before release
- Remove mixed-case and legacy patterns that break module naming rules
- Standardize internal globals to __UPPER_CASE and unify args helpers

## Naming Decisions Used for This Migration

- Allowed nested patterns: {domain}:{entity}:{verb} and {domain}:{verb}:{entity}
  - Choose the more readable form per function
- Predicates return status (0/1) and do not echo output
- Internal helper functions use _domain:... pattern
- Internal globals use __UPPER_CASE

## Module-by-Module Refactor Plan (.scripts/_*.sh)

### .scripts/_arguments.sh

- No naming changes identified
- If args:has lives here instead of _commons.sh, add:
  - args:has <flag> [args...]

### .scripts/_colors.sh

- No naming changes identified

### .scripts/_commons.sh

- Replace args:isHelp with args:has --help
- Introduce args:has (if not placed in _arguments.sh) and remove args:isHelp
- Refactor helper functions defined inside input:readpwd:
  - home, endline, reprint, add, delete, reset, left, right
  - Move to internal helpers (example names):
    - _input:readpwd:home
    - _input:readpwd:endline
    - _input:readpwd:reprint
    - _input:readpwd:add
    - _input:readpwd:delete
    - _input:readpwd:reset
    - _input:readpwd:left
    - _input:readpwd:right
- Refactor helper functions defined inside input:selector:
  - selections, reprint, reset, left, right, search
  - Move to internal helpers (example names):
    - _input:selector:selections
    - _input:selector:reprint
    - _input:selector:reset
    - _input:selector:left
    - _input:selector:right
    - _input:selector:search
- Rename local variables that use __ prefix (examples: __resultvar, __result) to snake_case
- Optional local casing cleanup (examples): CURPOS, COL, ROW, PWORD

### .scripts/_dependencies.sh

- Remove mixed-case flag helpers:
  - isDebug, isExec, isOptional, isSilent, isNoCache
- Replace with args:has in call sites:
  - args:has --debug "$@"
  - args:has --exec "$@"
  - args:has --optional "$@"
  - args:has --silent "$@"
  - args:has --no-cache "$@"
- Rename isCIAutoInstallEnabled to dependency:ci:autoinstall (predicate)
- Legacy aliases:
  - dependency and optional should become namespaced entrypoints
  - Keep aliases temporarily for compatibility, migrate internal calls to namespaced versions

### .scripts/_dryrun.sh

- Replace dryrun entrypoint with a namespaced function (example: dryrun:run)
- Keep dryrun as a temporary compatibility alias

### .scripts/_gnu.sh

- No naming changes identified

### .scripts/_hooks.sh

- No naming changes identified

### .scripts/_logger.sh

- logger entrypoint is non-namespaced
  - Convert to logger:init (or equivalent) as the primary API
  - Keep logger as a temporary compatibility alias
- Optional local casing cleanup: myPid -> my_pid

### .scripts/_self-update.sh

- self-update entrypoint is non-namespaced
  - Add self-update:run (or self-update:do)
  - Keep self-update as a temporary compatibility alias

### .scripts/_semver.sh

- Rename internal globals to __UPPER_CASE:
  - __semver_parse_result -> __SEMVER_PARSE_RESULT
  - __semver_compare_v1 -> __SEMVER_COMPARE_V1
  - __semver_compare_v2 -> __SEMVER_COMPARE_V2
- Rename temporary internal arrays:
  - __major -> __SEMVER_MAJOR
  - __minor -> __SEMVER_MINOR
  - __patch -> __SEMVER_PATCH
  - __semver_constraints_complex_atom -> __SEMVER_CONSTRAINTS_COMPLEX_ATOM
  - __semver_constraints_v2_version -> __SEMVER_CONSTRAINTS_V2_VERSION
  - __semver_constraints_v2_comp -> __SEMVER_CONSTRAINTS_V2_COMP

### .scripts/_tmux.sh

- No naming changes identified

### .scripts/_traps.sh

- Rename mixed-case and legacy OOP functions to internal helpers:
  - Trap::dispatch -> _trap:dispatch
  - _Trap::normalize_signal -> _trap:signal:normalize
  - _Trap::initialize_signal -> _trap:signal:init
  - _Trap::capture_legacy -> _trap:legacy:capture
  - _Trap::contains -> _trap:handler:contains
  - _Trap::remove_handler -> _trap:handler:remove
  - _Trap::list_all_signals -> _trap:signal:list

## Related Updates Outside .scripts

- specs and helpers referencing _Trap::*:
  - spec/helpers/trap_dispatcher_e2e_minimal.sh
  - spec/fixtures/e-docs/traps_functions.sh
  - spec/e_docs_spec.sh
- demos referencing __semver_*:
  - demos/demo.semver.sh
- dependency flag helper tests:
  - spec/dependencies_spec.sh

## Verification Steps

- Use ctags to list functions and scan for mixed-case in .scripts
- Search for leftover _Trap:: and __semver_ references
- Run ShellSpec after renames

## Notes

- Keep API compatibility by leaving legacy aliases in place during migration
- Prefer updating internal call sites first, then deprecate aliases
