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

```bash
# These are all wrong (but they're in your repo right now)
git log --oneline | head -5
# a3f2d1e updated readme
# 9c1b4a7 fixed bug
# 2e5f8c3 WIP: trying something
# 7a9d0e2 Merge branch 'dev'
# 1b3c5d4 stuff
```

**2. Nobody knows what the next version should be**

- Last tag is `v1.3.2`. You added a feature and fixed two bugs.
- Is the next version `v1.4.0`? `v1.3.3`? `v2.0.0`?
- Did anyone add a `BREAKING CHANGE:` footer? Who checks?

**3. Nobody audits the history**

100+ commits since the last tag, half of them don't follow the spec. The CI doesn't catch it. The release notes are invented by hand.

## The Fix: Three Scripts, One Workflow

### Step 1: Audit your commit history

```bash
git.verify-all-commits.sh
```

```
Checking 247 commits for Conventional Commits compliance...

  ✓ 198 valid commits
  ✗ 49 non-conventional commits

  Line 23:  "updated readme"          → should be: "docs: update readme"
  Line 47:  "fixed login bug"         → should be: "fix: resolve login error"
  Line 89:  "WIP"                     → should be: "wip: work in progress"
  ...

Result: 80.2% compliant (49 commits need fixing)
```

Want to fix them interactively?

```bash
git.verify-all-commits.sh --patch
```

Walks you through each invalid commit and lets you reword it — safely, with a backup branch.

### Step 2: See what version your commits produce

```bash
git.semantic-version.sh
```

```
Analyzing commit history from v1.3.2...

  feat: add user dashboard          → MINOR bump
  fix: resolve login timeout        → PATCH bump
  fix: handle empty email field     → PATCH bump
  docs: update API reference        → no bump
  feat!: redesign auth flow         → MAJOR bump (breaking)

Calculated version: v1.3.2 → v2.0.0
  MAJOR: 1 breaking change
  MINOR: 2 features (reset by major)
  PATCH: 2 fixes (reset by major)
```

The calculator reads your actual commit messages and applies SemVer rules. No guessing.

Options for different scenarios:

```bash
# Full history from first commit
git.semantic-version.sh --from-first-commit

# Only since last tag (fast, for large repos)
git.semantic-version.sh --from-last-tag

# Since current branch diverged (for PR reviews)
git.semantic-version.sh --from-branch-start

# Custom keywords for your team
git.semantic-version.sh --add-keyword "infra:patch"
```

### Step 3: Apply the version

```bash
# Preview what would happen
version-up.v2.sh --dry-run

# Apply: creates tag, updates version.properties
version-up.v2.sh --minor --apply

# Or let it decide based on commits
version-up.v2.sh --default --apply
```

Full control over the version lifecycle:

```bash
# Stage progression
version-up.v2.sh --alpha           # v1.4.0-alpha
version-up.v2.sh --beta            # v1.4.0-beta
version-up.v2.sh --rc              # v1.4.0-rc
version-up.v2.sh --release         # v1.4.0

# Specific bumps
version-up.v2.sh --major           # v2.0.0
version-up.v2.sh --minor           # v1.4.0
version-up.v2.sh --patch           # v1.3.3
version-up.v2.sh --revision        # v1.3.2.1

# Git revision as build metadata
version-up.v2.sh --git-revision    # v1.4.0+a3f2d1e

# Custom pre-release and build
version-up.v2.sh --pre-release rc.3 --build 2026.04.14
# → v1.4.0-rc.3+2026.04.14
```

## The Full Toolkit

| Script | Purpose |
|--------|---------|
| `git.verify-all-commits.sh` | Audit and fix commit messages |
| `git.semantic-version.sh` | Calculate next version from history |
| `version-up.v2.sh` | Apply version bump with git tags |
| `git.conventional-commits.sh` | Parse and validate individual commits |
| `git.log.sh` | Pretty git log with conventional commit highlighting |
| `git.graph.sh` | Branch visualization |
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
                  │  (calculates v2.1.0)    │
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

Add the pre-commit hook to enforce locally:

```bash
# .lefthook/pre-commit/conventional-commits.sh
git.conventional-commits.sh "$(git log -1 --format=%s)"
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
