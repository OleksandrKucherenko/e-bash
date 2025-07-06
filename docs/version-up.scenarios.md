# Version-Up Script Scenarios

<!-- TOC -->

- [Version-Up Script Scenarios](#version-up-script-scenarios)
  - [Critical Path](#critical-path)
    - [Single Repo](#single-repo)
      - [test-000: Show help message - PASSED!](#test-000-show-help-message---passed)
      - [test-001: Show script version - PASSED!](#test-001-show-script-version---passed)
      - [test-002: No existing tags - PASSED!](#test-002-no-existing-tags---passed)
      - [test-003: Propose next release version tag - PASSED!](#test-003-propose-next-release-version-tag---passed)
      - [test-004: Re-publish existing version tag - PASSED!](#test-004-re-publish-existing-version-tag---passed)
      - [test-005: Propose patch segment increase on branched version tag - PASSED!](#test-005-propose-patch-segment-increase-on-branched-version-tag---passed)
      - [test-006: Migration of existing repo to version-up script - PASSED! covered by test-003](#test-006-migration-of-existing-repo-to-version-up-script---passed-covered-by-test-003)
    - [Monorepo](#monorepo)
      - [test-020: Monorepo default prefix detection - PASSED!](#test-020-monorepo-default-prefix-detection---passed)
      - [test-021: Monorepo root prefix strategy - PASSED!](#test-021-monorepo-root-prefix-strategy---passed)
      - [test-022: Monorepo sub-folder prefix strategy - PASSED!](#test-022-monorepo-sub-folder-prefix-strategy---passed)
      - [test-023: Monorepo custom prefix string - PASSED!](#test-023-monorepo-custom-prefix-string---passed)
      - [test-024: Monorepo has multiple version.properties files](#test-024-monorepo-has-multiple-versionproperties-files)
      - [test-025: Monorepo with multiple version tag prefixes without clear winner](#test-025-monorepo-with-multiple-version-tag-prefixes-without-clear-winner)
  - [Corner Cases](#corner-cases)
    - [test-050: Dry-run prevents actual changes](#test-050-dry-run-prevents-actual-changes)
    - [test-051: Tag conflict error on apply](#test-051-tag-conflict-error-on-apply)
    - [test-052: Invalid prefix strategy](#test-052-invalid-prefix-strategy)
    - [test-053: Existing version.properties reuse with --stay](#test-053-existing-versionproperties-reuse-with---stay)
    - [test-054: Running outside a git repository](#test-054-running-outside-a-git-repository)
    - [test-055: Corrupted version.properties](#test-055-corrupted-versionproperties)

<!-- /TOC -->

## Critical Path

### Single Repo

#### test-000: Show help message - PASSED!

```gherkin
Scenario: Show help message
  When I run the script with `--help`
  Then the usage information should be displayed
  And the exit code should be 0
```

#### test-001: Show script version - PASSED!

```gherkin
Scenario: Show script version
  When I run the script with `--version`
  Then the script version should be "2.0.0"
  And the exit code should be 0
```

#### test-002: No existing tags - PASSED!

```gherkin
Scenario: No existing tags
  Given a new git repository just initialized from scratch
  When I run the script
  Then it should say `Empty repository without commits. Nothing to do.`
  And exit code should be 0
```

```gherkin
Scenario: No existing tags
  Given a new git repository just initialized from scratch
  And one commit exists
  When I run the script
  Then it should propose version `0.1.0-alpha`
  And proposed strategy should be `increment MINOR of the latest 0.0.1-alpha`
  And exit code should be 0
```

#### test-003: Propose next release version tag - PASSED!

```gherkin
Scenario Outline: Propose next release version tag
  Given the repository has an existing tag `<init_tag>`
  When I run the script with `<flag>`
  Then it should propose version `<expected_version>`
  And should detect prefix `v` from `<init_tag>`
  And exit code should be 0

Examples:
  | init_tag | flag        | expected_version  |
  | v1.2.3   |             | v1.2.4            |
  | v1.2.3   | --major     | v2.0.0            |
  | v1.2.3   | --minor     | v1.3.0            |
  | v1.2.3   | --patch     | v1.2.4            |
  | v1.2.3   | --default   | v1.2.4            |
  | v1.2.3   | --alpha     | v1.2.3-alpha      |
  | v1.2.3   | --beta      | v1.2.3-beta       |
  | v1.2.3   | --rc        | v1.2.3-rc         |
  | v1.2.3   | --revision  | v1.2.3+1          |
```

#### test-004: Re-publish existing version tag - PASSED!

```gherkin
Scenario: Re-publish existing version tag
  Given a repository at tag `v2.0.0` on a branch named `v2.0.0`
  When I run the script without any flags
  Then it should reuse version `2.0.0`
  And exit code should be 0
```

#### test-005: Propose patch segment increase on branched version tag - PASSED!

```gherkin
Scenario: Propose patch segment increase on branched version tag
  Given the repository has an existing tags `v1.1.0` and `v1.2.0`
  And we create a branch from `v1.1.0`
  And we add a commit to the branch
  When I run the script without parameters
  And proposed version should be `v1.1.1`
  And exit code should be 0
```

> Note: script choose different strategies for MAIN and BRANCH state of repository.

> Note: if branch name matches SEMVER pattern, script will use "increment last found non-zero version part" strategy.

> Note: if branch name does not match SEMVER pattern, script will use "increment MINOR of the latest tag" strategy.

#### test-006: Migration of existing repo to version-up script - PASSED! (covered by test-003)

```gherkin
Scenario: Migration of existing repo to version-up script
  Given a repository with existing git tags following semver (e.g. v1.0.0, v1.1.0, v2.0.0)
  And no `version.properties` file exists
  When I add the version-up script to the repository
  And I run the script without any flags
  Then it should detect the latest tag `v2.0.0`
  And propose the next version (e.g. `v2.1.0`)
  And create a `version.properties` file with the detected version
  And exit code should be 0
```

> Note: default strategy is a MINOR version bump.

### Monorepo

#### test-020: Monorepo default prefix detection - PASSED!

```gherkin
Scenario: Monorepo default prefix detection
  Given a monorepo with sub-folders `packages/foo` and `packages/bar`
  And tags `packages/foo/v1.0.0` and `packages/bar/v1.1.0` exist
  And current directory is `packages/foo`
  When I run the script without a prefix flag
  Then it should auto-detect prefix `packages/foo`
  And propose version `packages/foo/v1.0.1`
  And exit code should be 0
```

#### test-021: Monorepo root prefix strategy - PASSED!

```gherkin
Scenario: Monorepo root prefix strategy
  Given a monorepo with tags `v1.0.0` at root and sub-folder `packages/foo`
  And tag `packages/foo/v2.0.0` exists
  And current directory is `packages/foo`
  When I run the script with `--prefix root`
  Then it should use no prefix
  And propose version `v1.1.0`
  And exit code should be 0
```

> Note: expected that script will detect commonly used prefix `v` from tags `v1.0.0` and apply it for future version `v1.1.0`.

#### test-022: Monorepo sub-folder prefix strategy - PASSED!

```gherkin
Scenario: Monorepo sub-folder prefix strategy
  Given a monorepo with tags `packages/foo/v1.2.3` and sub-folders `packages/foo`
  And current directory is `packages/foo`
  When I run the script with `--prefix sub-folder`
  Then it should use prefix `packages/foo`
  And propose version `packages/foo/v1.3.0`
  And exit code should be 0
```

> Note: expected version will be `packages/foo/v1.3.0` - will be MINOR increment due to MASTER branch strategy applying.

#### test-023: Monorepo custom prefix string - PASSED!

```gherkin
Scenario: Monorepo custom prefix string
  Given a monorepo with tags `custom/v0.9.0` and any folder structure
  When I run the script with `--prefix custom`
  Then it should use prefix `custom`
  And propose version `custom/v0.10.0`
  And exit code should be 0
```

#### test-024: Monorepo has multiple version.properties files

```gherkin
Scenario: Monorepo has multiple version.properties files
  And version.properties placed on project root
  And version.properties placed in sub-folder
  Given a monorepo with tags `v1.0.0` and `v1.1.0`
  And multiple `version.properties` files exist
  When I run the script from sub-folder
  Then it should take prefix configuration from merge of settings from version.properties files
  And exit code should be non-zero
```

> Note: expected .env (dotenv) behavior in applying the settings (if variable defined it cannot be changed)

> Note: each sub-folder may define own tag and prefix rules in `version.properties` file

#### test-025: Monorepo with multiple version tag prefixes without clear winner

```gherkin
Scenario: Monorepo with multiple version tag prefixes without clear winner
  Given a monorepo with tags `package/1.1.0` and `v1.1.0`
  When I run the script from sub-folder
  Then it should display an error about multiple version tag prefixes
  And should provide instructions how to fix it by additional flag providing
  And exit code should be non-zero
```

> Note: we have two tags with different prefixes: `package/` and `v` and they both have the same number of usages, so script cannot auto-detect the correct prefix based on usage statistics. That should cause error.

## Corner Cases

### test-050: Dry-run prevents actual changes

```gherkin
Scenario: Dry-run does not apply changes
  Given the repository has an existing tag `1.0.0`
  When I run the script with `--patch --apply --dry-run`
  Then no commits or tags should be created
  And git commands should be printed on screen
  And exit code should be 0
```

### test-051: Tag conflict error on apply

```gherkin
Scenario: Tag conflict error on apply
  Given the repository has an existing tags `v1.0.1` and `v1.0.2`
  And we create a branch from `v1.0.1`
  And we add a commit to the branch
  When I run the script with `--patch --apply`
  Then it should display an error about tag conflict
  And exit code should be non-zero
```

### test-052: Invalid prefix strategy

```gherkin
Scenario: Invalid prefix parameter
  Given a repository initialized in a scratch directory
  When I run the script with `--prefix invalid:name`
  Then it should display an error about invalid prefix
  And exit code should be non-zero
```

Specifically, a tag name cannot contain:

1. ASCII control characters (characters with ASCII codes below 32, like newlines, tabs, etc.)
2. Space characters ( )
3. Tilde (~)
4. Caret (^)
5. Colon (:)
6. Question mark (?)
7. Asterisk (\*)
8. Open or close square brackets ([ and ])
9. Backslash (\)
10. Double dots (..) — a tag cannot have .. inside
11. Leading or trailing slashes — e.g., /tagname, tagname/
12. Consecutive slashes — e.g., tag//name

### test-053: Existing version.properties reuse with --stay

```gherkin
Scenario: Reuse version from version.properties with --stay
  Given the repository has a file `version.properties` containing `version=3.1.4`
  When I run the script with `--stay`
  Then it should reuse version `3.1.4` in its output
  And exit code should be 0
```

### test-054: Running outside a git repository

```gherkin
Scenario: Error when not in a git repository
  Given no git repository initialized in the directory
  When I run the script
  Then it should display an error about missing .git
  And exit code should be non-zero
```

### test-055: Corrupted version.properties

```gherkin
Scenario: Error when version.properties is in unknown format
  Given the repository has a file `version.properties` containing invalid version
  When I run the script
  Then it should display an error about invalid version
  And provide manual backup instructions to user
  And exit code should be non-zero
```
