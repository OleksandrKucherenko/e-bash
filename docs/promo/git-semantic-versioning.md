# Your Team Agreed on Semantic Versioning. Then Nobody Followed It.

Conventional Commits + SemVer sounds great in the meeting. Three sprints later:

```
fix something
update stuff
WIP
asdfgh
merge branch 'feature' into main
```

The version tag? Someone bumped it manually last month. Maybe. The changelog? Doesn't exist.

This is every team that "does semantic versioning" without tooling.

## The Real Problems

**1. Nobody remembers the commit format**

Is it `fix:` or `Fix:`? Does `refactor:` bump the version? What about `chore:`?

**2. Nobody knows what the next version should be**

Last tag is `v1.3.2`. You added a feature and fixed two bugs. Is the next version `v1.4.0`? `v1.3.3`? `v2.0.0`? Did anyone add a `BREAKING CHANGE:` footer?

**3. Nobody audits the history**

100+ commits since the last tag, half of them don't follow the spec. The CI doesn't catch it. The release notes are invented by hand.

## The Fix: Three Scripts, One Workflow

### Step 1: Audit your commit history

```bash
$ git.verify-all-commits.sh
```

Real output from our own repo:

```
 🔍 Gathering commit history...
 🔍 Checking 142 commits for Conventional Commit compliance...

Progress: 0.........10.........20.........30.........40...(truncated)

 ❌ 48 commit(s) failed:

 🔴 Commit: c1ac6546, Author: Oleksandr, Date: 2026-02-23
    Message: "Improve ShellSpec timeout patch robustness and diagnostics (#78)"

 🔴 Commit: 75598254, Author: Oleksandr, Date: 2026-01-28
    Message: "Correct code block formatting in README"

 🔴 Commit: cb10f677, Author: Oleksandr Kucherenko, Date: 2023-10-03
    Message: "imported version-up.sh script"

 💡 Conventional Commit format: type(scope): description
    Valid types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
    Use ! for breaking changes: feat!: breaking change
    Reference: https://www.conventionalcommits.org/

 💡 To fix these commits interactively, run with --patch flag
```

Yes, even our own repo has 48 non-conventional commits (mostly from the early days). The tool found them in seconds. Use `--patch` to fix them interactively.

### Step 2: See what version your commits produce

```bash
$ git.semantic-version.sh --from-first-commit
```

Real output (last 10 of 141 commits):

```
Semantic Version History

| Commit  | Message                                         | Tag    | Version Change   | Diff   |
|---------|-------------------------------------------------|--------|------------------|--------|
| 05c97f4 | fix: strict mode compatibility (set -euo ...)   | -      | 2.7.3 → 2.7.4   | +0.0.1 |
| 475a687 | feat: Add interactive multi-line text editor ... | -      | 2.7.4 → 2.8.0   | +0.1.0 |
| a20f55b | feat: Bash/Zsh completion integration (#73)     | -      | 2.8.0 → 2.9.0   | +0.1.0 |
| 0865f3b | chore: prepare release v2.1.0                   | v2.1.0 | 2.9.0 → 2.1.0   | =2.1.0 |
| 98eed52 | docs: fix 25 broken references across ...        | -      | 2.1.3 → 2.1.4   | +0.0.1 |
| 3dc53e3 | ci: upgrade GitHub Actions to latest versions   | -      | 2.1.6 → 2.1.7   | +0.0.1 |

Summary:
  Total commits processed: 141
  Version changes:
    Major (breaking): 1
    Minor (features): 24
    Patch (fixes):    50
    Tag   (assigned): 5
    None  (ignored):  61

Final Version: 2.1.9
```

The calculator reads your actual commit messages and applies SemVer rules. `feat:` bumps MINOR. `fix:` bumps PATCH. `feat!:` or `BREAKING CHANGE:` bumps MAJOR. Tags override the calculated version.

Options for different scenarios:

```bash
git.semantic-version.sh --from-first-commit       # full history
git.semantic-version.sh --from-last-tag            # fast, for large repos
git.semantic-version.sh --from-branch-start        # for PR reviews
git.semantic-version.sh --from-last-n-versions 5   # last 5 releases
git.semantic-version.sh --add-keyword "infra:patch" # custom keywords
```

### Step 3: Apply the version

```bash
$ version-up.v2.sh --dry-run
```

Real output:

```
Found tag        : v2.1.0 in branch master
Current Revision : 142
Current Branch   : master

Proposed Next Version TAG: v2.2.0

To apply changes manually execute the command(s):

  git tag v2.2.0
  git push origin v2.2.0

File version.properties is successfully created.
```

Full control over the version lifecycle:

```bash
# Stage progression
version-up.v2.sh --alpha           # v2.1.0-alpha
version-up.v2.sh --beta            # v2.1.0-beta
version-up.v2.sh --rc              # v2.1.0-rc
version-up.v2.sh --release         # v2.1.0

# Specific bumps
version-up.v2.sh --major           # v3.0.0
version-up.v2.sh --minor           # v2.2.0
version-up.v2.sh --patch           # v2.1.1

# Combine: minor bump + release candidate
version-up.v2.sh --minor --rc      # v2.2.0-rc

# Git revision as build metadata
version-up.v2.sh --git-revision    # v2.2.0+681df0d

# Apply (creates tag + pushes)
version-up.v2.sh --minor --apply

# Preview without changes
version-up.v2.sh --dry-run
```

## The Full Toolkit

| Script | Purpose |
|--------|---------|
| `git.verify-all-commits.sh` | Audit and fix commit messages |
| `git.semantic-version.sh` | Calculate next version from history |
| `version-up.v2.sh` | Apply version bump with git tags |
| `git.conventional-commits.sh` | Parse and validate individual commits |
| `git.log.sh` | Pretty git log with conventional commit highlighting |
| `git.files.sh` | Show changed files per commit (plain or tree) |

## The Workflow

```
                  ┌─────────────────────────┐
                  │  Developer commits code  │
                  │  using conventional      │
                  │  commit messages         │
                  └───────────┬─────────────┘
                              │
                  ┌───────────▼─────────────┐
                  │  CI runs:               │
                  │  git.verify-all-commits │
                  │  (fails on bad commits) │
                  └───────────┬─────────────┘
                              │
                  ┌───────────▼─────────────┐
                  │  Release time:          │
                  │  git.semantic-version   │
                  │  (calculates v2.2.0)    │
                  └───────────┬─────────────┘
                              │
                  ┌───────────▼─────────────┐
                  │  version-up.v2.sh       │
                  │  --default --apply      │
                  │  (tags + properties)    │
                  └─────────────────────────┘
```

Add the commit verifier to your CI:

```yaml
# .github/workflows/ci.yml
- name: Verify conventional commits
  run: git.verify-all-commits.sh --branch
```

## Install

```bash
# Homebrew (macOS & Linux)
brew tap artfulbits-se/tap
brew install e-bash
e-bash versions

# All git tools are immediately available
git.semantic-version.sh --help
git.verify-all-commits.sh --help
version-up.v2.sh --help
```

## Part of e-bash

These git tools are part of [e-bash](https://github.com/OleksandrKucherenko/e-bash) — a Bash framework with 13 modules, 24 tools, and 200+ tests. Professional-grade logging, argument parsing, shell completion, dependency management, and more.

```bash
brew install artfulbits-se/tap/e-bash
```

---

*MIT Licensed. Works on macOS, Linux, and WSL.*
