# Repository Consistency Cleanup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enforce consistent naming and folder conventions across core, bin, demos, specs, and docs; remove noisy backups/artifacts; clarify doc types and defaults for duplicate scripts.

**Architecture:** Keep reusable core in hidden `.scripts/_{purpose}.sh`; expose entrypoints via `bin/{domain}.{feature}.sh` (feature follows the same naming rules as use-case: words separated by hyphens, 2-5 words, ≤25 chars); demos in `demos/demo.{use-case}.sh`; specs under `spec/` with `{subject_of_test}_{use-case}_spec.sh` (underscore separates subject and use-case), fixtures as `{subject}_{use_case}.*`. Use dots for category splits, hyphens inside multi-word segments, underscores to separate subject from use-case.

**Tech Stack:** Bash scripts, ShellSpec tests, Make, git.

---

### Task 1: Add guardrails for backups and generated outputs

**Files:**
- Modify: `.gitignore`
- Modify: `mise.toml` (add `tasks.clean`)
- Remove: `Makefile` (superseded by mise tasks)

**Steps:**
1. Update `.gitignore` to cover backup patterns (`*.~*~`, `*.sha1` already present), coverage/report outputs, and any new legacy folders (`legacy/` if created).
2. Add `tasks.clean` in `mise.toml` that removes `coverage/`, `report/`, `**/*.~*~`, and optional legacy artifacts; mirror what Makefile did.
3. Remove obsolete `Makefile` (ensure README/docs no longer reference `make` targets).
4. Run `mise run clean` to verify it removes artifacts without errors.

### Task 2: Purge existing backups and generated artifacts

**Files:**
- Remove: all `*.~1~` files in `.scripts/`, `bin/`, `spec/`, `demos/`, `spec/helpers/`, `spec/fixtures/`, `spec/bin/`, `spec/support/`, `spec/helpers/`
- Remove: `coverage/` directory contents
- Remove: `report/results_junit.xml`

**Steps:**
1. Delete listed backup files and generated artifacts (use `rg --files -g'*.~1~'` to enumerate before removal).
2. Re-run `rg --files -g'*.~1~'` to confirm the tree is clean.
3. Run `mise run clean` to ensure no stale files remain.

### Task 3: Normalize bin and demo naming to dot+hyphen scheme

**Files:**
- Keep: `bin/install.e-bash.sh` (must remain unchanged for online installs)
- Rename: `bin/git.conventional-commits.sh` → `bin/git.conventional-commits.sh`
- Rename: `bin/git.sync-by-patches.sh` → `bin/git.sync-by-patches.sh`
- Rename: `bin/git.verify-all-commits.sh` → `bin/git.verify-all-commits.sh`
- Rename: `bin/ci.validate-envrc.sh` → `bin/ci.validate-envrc.sh` (domain `ci`)
- Rename: `bin/shellspec.format.sh` → `bin/shellspec.format.sh`
- Rename: `demos/demo.traps.sh` → `demos/demo.traps.sh`
- Rename: `demos/demo.dryrun-v2.sh` → `demos/demo.dryrun-v2.sh` (hyphen in use-case)
- Rename: `demos/demo.dryrun-modes.sh` → `demos/demo.dryrun-modes.sh`

**Steps:**
0. Verify `bin/install.e-bash.sh` remains unchanged (no rename).
1. Apply renames using `mv` (or `git mv`) exactly as above.
2. Update all references across the repo (docs, README, specs, scripts, demos) to the new names; grep for old names until zero matches.
3. Update Shebang/exec bits if needed (retain executable perms).

### Task 4: Align specs, helpers, and fixtures to naming rules

**Files:**
- Move/rename specs to mirror scripts using subject_usecase underscore split, keeping subfolders:
  - `spec/bin/git.conventional-commits_spec.sh`
  - `spec/bin/git.sync-by-patches_spec.sh`
  - `spec/bin/git.verify-all-commits_spec.sh`
  - `spec/bin/ci.validate-envrc_spec.sh`
  - `spec/bin/shellspec.format_spec.sh`
  - `spec/demos/demo.dryrun-v2_spec.sh`, `spec/demos/demo.dryrun-modes_spec.sh`, `spec/demos/demo.traps_spec.sh`
- Rename helper/fixture backups to match new subjects:
  - `spec/helpers/trap_simple_test.sh` (remove backups)
  - `spec/helpers/trap_dispatcher_e2e_minimal.sh`
  - `spec/fixtures/test_trap_script_a.sh` → `spec/fixtures/traps_script-a_default.sh`
  - `spec/fixtures/test_trap_script_b.sh` → `spec/fixtures/traps_script-b_default.sh`
  - `spec/fixtures/test_trap_lib_db.sh` → `spec/fixtures/traps_lib-db_default.sh`
- Move test-only doc `spec/TRAP_DISPATCHER_TESTING.md` to `docs/work/tests/trap-dispatcher.md`.

**Steps:**
1. Rename/move the spec files and helpers/fixtures per list; ensure subject/use-case separation with underscore, hyphens inside multi-word segments.
2. Update spec contents and any other callers to reference renamed fixtures/helpers/scripts; grep for old names until zero matches.
3. Run `shellspec --quick` to confirm suite executes under new names.

### Task 5: Resolve duplicate versions and declare defaults

**Files:**
- Default version script: keep `bin/version-up.v2.sh`; move legacy v1 to `legacy/bin/version-up.v1.sh`.
- For demos, set `demos/demo.dryrun.sh` as default; move older/alternate to `legacy/demos/demo.dryrun-v1.sh` (or similar) if needed.

**Steps:**
1. Decide defaults (prefer latest stable) and move/rename legacy versions into `legacy/` preserving executable bits.
2. Update docs and README to point to default scripts.
3. Run any affected specs (`spec/version-up_spec.sh`) to ensure references updated.

### Task 6: Split docs into public vs work and standardize naming

**Files:**
- Create dirs: `docs/public/`, `docs/work/`, `docs/images/public/`, `docs/images/work/`, `docs/work/tests/`
- Move public-facing docs (installation, usage, logger, traps, dryrun, shellspec, version-up, roadmap) into `docs/public/` with kebab-case names.
- Move refactoring/notes/research (agents research, versioning diagrams, temp notes) into `docs/work/`; keep images in corresponding images subfolders.
- Add new doc: `docs/public/conventions.md` summarizing folder structure and naming rules.

**Steps:**
1. Create directories above.
2. Move markdown files accordingly; rename to kebab-case (e.g., `versioning-script-logic.excalidraw.md` -> `versioning-script-logic.md` in `docs/work/`).
3. Move images to `docs/images/public/` or `docs/images/work/` with `topic-context-step.png` naming.
4. Update README and in-repo links to new locations.

### Task 7: Document conventions and add guardrails

**Files:**
- Create/modify: `docs/public/conventions.md`
- Modify: `.githook/README.md` (if adding hook instructions)
- Add optional pre-commit hook to block `*.~*~` and enforce naming regex (documented, not necessarily enabled by default).

**Steps:**
1. Write conventions doc covering: core in `.scripts/_{purpose}.sh`, bin/demos/spec naming rules (dot + hyphen + underscore separation), fixture naming, doc split (public vs work), images naming.
2. Optionally add a lightweight pre-commit snippet (or instructions) to fail on backup files and nonconforming names.
3. Cross-link conventions doc from README.

### Verification

- Run `rg --files -g'*.~*~'` → expect no results.
- Run `shellspec --quick` → expect pass.
- Run `mise run clean` → expect no errors and idempotent cleanup.

---

Plan complete and saved. Execution options:
1. Subagent-driven here (use superpowers:subagent-driven-development, with superpowers:executing-plans for task-by-task).
2. Parallel session with executing-plans skill in a clean worktree.
