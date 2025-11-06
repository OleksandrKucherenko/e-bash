#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034

## Unit tests for bin/git.semantic-version.sh
## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-11-06
## Version: 1.0.0
## License: MIT

eval "$(shellspec - -c) exit 1"

# Helper functions to strip ANSI color codes
# $1 = stdout, $2 = stderr, $3 = exit status
no_colors_stderr() { echo -n "$2" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | tr -s ' '; }
no_colors_stdout() { echo -n "$1" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | tr -s ' '; }

# Mock logger to avoid noise in tests
Mock logger:init
  echo "$@" >/dev/null
End

Mock echo:SemVer
  echo "$@" >/dev/null
End

Mock printf:SemVer
  printf "$@" >/dev/null
End

Mock echo:Regex
  echo "$@" >/dev/null
End

Mock printf:Regex
  printf "$@" >/dev/null
End

Describe "git.semantic-version.sh"
  # Set E_BASH to point to .scripts before including the main script
  BeforeAll 'E_BASH="$(cd "$(dirname "$SHELLSPEC_SPECFILE")" && cd ../.scripts && pwd)"'

  # Source the script to load functions
  Include "bin/git.semantic-version.sh"

  Describe "gitsv:parse_commit_type()"
    It "detects feat commit"
      When call gitsv:parse_commit_type "feat: add new feature"
      The output should eq "feat"
    End

    It "detects fix commit"
      When call gitsv:parse_commit_type "fix: resolve bug"
      The output should eq "fix"
    End

    It "detects chore commit"
      When call gitsv:parse_commit_type "chore: update dependencies"
      The output should eq "chore"
    End

    It "detects docs commit"
      When call gitsv:parse_commit_type "docs: update README"
      The output should eq "docs"
    End

    It "detects refactor commit"
      When call gitsv:parse_commit_type "refactor: simplify logic"
      The output should eq "refactor"
    End

    It "detects test commit"
      When call gitsv:parse_commit_type "test: add unit tests"
      The output should eq "test"
    End

    It "detects ci commit"
      When call gitsv:parse_commit_type "ci: update workflow"
      The output should eq "ci"
    End

    It "detects perf commit"
      When call gitsv:parse_commit_type "perf: optimize query"
      The output should eq "perf"
    End

    It "handles commit with scope"
      When call gitsv:parse_commit_type "feat(api): add endpoint"
      The output should eq "feat"
    End

    It "handles non-conventional commit as unknown"
      When call gitsv:parse_commit_type "random commit message"
      The output should eq "unknown"
    End

    It "handles merge commit"
      When call gitsv:parse_commit_type "Merge branch 'main' into dev"
      The output should eq "merge"
    End
  End

  Describe "gitsv:has_breaking_change()"
    It "detects breaking change with !"
      When call gitsv:has_breaking_change "feat!: breaking change"
      The status should be success
    End

    It "detects breaking change with ! and scope"
      When call gitsv:has_breaking_change "feat(api)!: breaking change"
      The status should be success
    End

    It "detects BREAKING CHANGE in body"
      When call gitsv:has_breaking_change "feat: something$(printf '\n\n')BREAKING CHANGE: breaks stuff"
      The status should be success
    End

    It "detects BREAKING-CHANGE in body"
      When call gitsv:has_breaking_change "feat: something$(printf '\n\n')BREAKING-CHANGE: breaks stuff"
      The status should be success
    End

    It "returns false for non-breaking change"
      When call gitsv:has_breaking_change "feat: normal feature"
      The status should be failure
    End
  End

  Describe "gitsv:determine_bump()"
    It "returns major for breaking change"
      When call gitsv:determine_bump "feat!: breaking change"
      The output should eq "major"
    End

    It "returns minor for feat"
      When call gitsv:determine_bump "feat: new feature"
      The output should eq "minor"
    End

    It "returns patch for fix"
      When call gitsv:determine_bump "fix: bug fix"
      The output should eq "patch"
    End

    It "returns patch for chore"
      When call gitsv:determine_bump "chore: update deps"
      The output should eq "patch"
    End

    It "returns patch for docs"
      When call gitsv:determine_bump "docs: update readme"
      The output should eq "patch"
    End

    It "returns patch for refactor"
      When call gitsv:determine_bump "refactor: simplify"
      The output should eq "patch"
    End

    It "returns none for merge"
      When call gitsv:determine_bump "Merge branch 'main'"
      The output should eq "none"
    End

    It "returns none for unknown commit type"
      When call gitsv:determine_bump "random commit"
      The output should eq "none"
    End
  End

  Describe "gitsv:add_keyword()"
    It "adds custom keyword successfully"
      When call gitsv:add_keyword "wip" "patch"
      The status should be success
    End

    It "validates bump type"
      When call gitsv:add_keyword "custom" "invalid"
      The status should be failure
      The result of function no_colors_stderr should include "Invalid bump type"
    End

    It "allows major bump type"
      When call gitsv:add_keyword "test1" "major"
      The status should be success
    End

    It "allows minor bump type"
      When call gitsv:add_keyword "test2" "minor"
      The status should be success
    End

    It "allows patch bump type"
      When call gitsv:add_keyword "test3" "patch"
      The status should be success
    End

    It "allows none bump type"
      When call gitsv:add_keyword "test4" "none"
      The status should be success
    End
  End

  Describe "gitsv:determine_bump() with custom keywords"
    It "respects added wip keyword"
      BeforeCall "gitsv:add_keyword wip patch"
      When call gitsv:determine_bump "wip: work in progress"
      The output should eq "patch"
    End

    It "respects custom keyword with none bump"
      BeforeCall "gitsv:add_keyword experiment none"
      When call gitsv:determine_bump "experiment: trying something"
      The output should eq "none"
    End

    It "respects custom keyword with minor bump"
      BeforeCall "gitsv:add_keyword feature minor"
      When call gitsv:determine_bump "feature: new capability"
      The output should eq "minor"
    End
  End

  Describe "gitsv:bump_version()"
    It "bumps patch version"
      When call gitsv:bump_version "1.2.3" "patch"
      The output should eq "1.2.4"
    End

    It "bumps minor version and resets patch"
      When call gitsv:bump_version "1.2.3" "minor"
      The output should eq "1.3.0"
    End

    It "bumps major version and resets minor and patch"
      When call gitsv:bump_version "1.2.3" "major"
      The output should eq "2.0.0"
    End

    It "returns same version for none bump"
      When call gitsv:bump_version "1.2.3" "none"
      The output should eq "1.2.3"
    End

    It "handles 0.x.x versions correctly for patch"
      When call gitsv:bump_version "0.1.2" "patch"
      The output should eq "0.1.3"
    End

    It "handles 0.x.x versions correctly for minor"
      When call gitsv:bump_version "0.1.2" "minor"
      The output should eq "0.2.0"
    End

    It "handles 0.0.x versions correctly for major"
      When call gitsv:bump_version "0.0.5" "major"
      The output should eq "1.0.0"
    End
  End

  Describe "gitsv:version_diff()"
    It "shows patch diff"
      When call gitsv:version_diff "1.2.3" "1.2.4"
      The output should eq "+0.0.1"
    End

    It "shows minor diff"
      When call gitsv:version_diff "1.2.3" "1.3.0"
      The output should eq "+0.1.0"
    End

    It "shows major diff"
      When call gitsv:version_diff "1.2.3" "2.0.0"
      The output should eq "+1.0.0"
    End

    It "shows only highest level change for complex diff"
      # Our implementation shows highest level change only
      When call gitsv:version_diff "1.2.3" "2.5.7"
      The output should eq "+1.0.0"
    End

    It "shows no diff for same version"
      When call gitsv:version_diff "1.2.3" "1.2.3"
      The output should eq "+0.0.0"
    End
  End

  Describe "gitsv:format_output_line()"
    It "formats output line in markdown format"
      When call gitsv:format_output_line "abc1234" "feat: add feature" "1.2.3" "1.3.0" "+0.1.0" "v1.3.0"
      The output should include "| abc1234 |"
      The output should include "| feat: add feature |"
      The output should include "| v1.3.0 |"
      The output should include "1.2.3 → 1.3.0"
      The output should include "| +0.1.0 |"
    End

    It "handles missing tag parameter with default dash"
      When call gitsv:format_output_line "abc1234" "feat: add feature" "1.2.3" "1.3.0" "+0.1.0"
      The output should include "| - |"
    End

    It "handles long commit messages without truncation"
      msg="feat: this is a very long commit message that should not be truncated in markdown format"
      When call gitsv:format_output_line "abc1234" "$msg" "1.2.3" "1.3.0" "+0.1.0" "-"
      The output should include "$msg"
    End

    It "handles long git tags without truncation"
      long_tag="v1.2.3-alpha-very-long-tag-name"
      When call gitsv:format_output_line "abc1234" "feat: test" "1.2.3" "1.3.0" "+0.1.0" "$long_tag"
      The output should include "$long_tag"
    End
  End

  Describe "gitsv:get_first_commit()"
    It "returns the first commit hash in repository"
      When call gitsv:get_first_commit
      The status should be success
      The result of function no_colors_stdout should include "cacb"
    End
  End

  Describe "gitsv:get_commit_tags()"
    It "returns empty string for commits without tags"
      # Get a recent commit that likely has no tags
      recent_commit=$(git rev-parse HEAD)
      When call gitsv:get_commit_tags "$recent_commit"
      The status should be success
    End

    It "handles invalid commit hash gracefully"
      When call gitsv:get_commit_tags "invalid_hash_12345"
      The status should be success
      The output should eq ""
    End
  End

  Describe "gitsv:extract_semver_from_tag()"
    It "extracts version from tag with v prefix"
      When call gitsv:extract_semver_from_tag "v1.0.0"
      The output should eq "1.0.0"
    End

    It "extracts version from tag without prefix"
      When call gitsv:extract_semver_from_tag "2.3.4"
      The output should eq "2.3.4"
    End

    It "extracts version from tag with path and v prefix"
      When call gitsv:extract_semver_from_tag "package/test/v2.0.1"
      The output should eq "2.0.1"
    End

    It "extracts version with pre-release suffix"
      When call gitsv:extract_semver_from_tag "v1.0.0-alpha"
      The output should eq "1.0.0-alpha"
    End

    It "extracts version with build metadata"
      When call gitsv:extract_semver_from_tag "package/test/v2.0.1-alpha+1"
      The output should eq "2.0.1-alpha+1"
    End

    It "returns empty for non-semver tag"
      When call gitsv:extract_semver_from_tag "release-candidate"
      The output should eq ""
    End

    It "returns empty for invalid version format"
      When call gitsv:extract_semver_from_tag "v1.0"
      The output should eq ""
    End

    It "handles tag with path prefix without v"
      When call gitsv:extract_semver_from_tag "releases/1.2.3"
      The output should eq "1.2.3"
    End

    It "extracts from complex tag with full semver"
      When call gitsv:extract_semver_from_tag "my/package/v1.2.3-rc.1+build.123"
      The output should eq "1.2.3-rc.1+build.123"
    End
  End

  Describe "gitsv:extract_semvers_from_tags()"
    It "extracts single semver from single tag"
      When call gitsv:extract_semvers_from_tags "v1.0.0"
      The output should eq "1.0.0"
    End

    It "extracts multiple semvers from multiple tags"
      When call gitsv:extract_semvers_from_tags "v1.0.0,v2.0.0"
      The output should eq "1.0.0,2.0.0"
    End

    It "filters out non-semver tags"
      When call gitsv:extract_semvers_from_tags "v1.0.0,latest,v2.0.0"
      The output should eq "1.0.0,2.0.0"
    End

    It "returns empty for all non-semver tags"
      When call gitsv:extract_semvers_from_tags "latest,stable,production"
      The output should eq ""
    End

    It "handles mixed prefix formats"
      When call gitsv:extract_semvers_from_tags "v1.0.0,package/v2.0.0,3.0.0"
      The output should eq "1.0.0,2.0.0,3.0.0"
    End
  End

  Describe "gitsv:get_last_version_tag()"
    It "returns latest semver tag if exists"
      When call gitsv:get_last_version_tag
      The status should be success
      # Output should be a version (1.1.0 in this repo)
      The result of function no_colors_stdout should include "1."
    End

    It "strips 'v' prefix from tags"
      # Mock git tag command to test
      Skip "Requires git command mocking"
    End
  End

  Describe "gitsv:get_last_version_tag_commit()"
    It "returns commit hash for latest version tag"
      When call gitsv:get_last_version_tag_commit
      The status should be success
      # Output is a commit hash (40 hex chars)
      The result of function no_colors_stdout should include "8649d55"
    End
  End

  Describe "gitsv:get_branch_start_commit()"
    It "returns a commit hash"
      When call gitsv:get_branch_start_commit
      The status should be success
      # Should return a commit hash
      The result of function no_colors_stdout should include "cacb"
    End
  End

  Describe "gitsv:get_commit_from_n_versions_back()"
    It "returns commit hash when versions exist"
      When call gitsv:get_commit_from_n_versions_back 1
      The status should be success
      # Should return a commit hash
      The result of function no_colors_stdout should include "8649d55"
    End

    It "handles when N is larger than version count"
      When call gitsv:get_commit_from_n_versions_back 9999
      The status should be success
      # Should fallback to first commit
      The result of function no_colors_stdout should include "cacb"
    End
  End

  Describe "Command line argument parsing"
    It "displays help with --help"
      When run script bin/git.semantic-version.sh --help
      The status should be success
      The result of function no_colors_stdout should include "USAGE:"
      The result of function no_colors_stdout should include "OPTIONS:"
      The result of function no_colors_stdout should include "EXAMPLES:"
    End

    It "accepts --initial-version parameter"
      When run script bin/git.semantic-version.sh --initial-version 5.0.0 --help
      The status should be success
      The result of function no_colors_stdout should include "USAGE:"
    End

    It "rejects invalid --initial-version format"
      When run script bin/git.semantic-version.sh --initial-version invalid
      The status should be failure
      The result of function no_colors_stderr should include "Invalid initial version"
    End

    It "accepts --add-keyword parameter"
      When run script bin/git.semantic-version.sh --add-keyword wip:patch --help
      The status should be success
      The result of function no_colors_stdout should include "USAGE:"
    End

    It "rejects invalid --add-keyword format"
      When run script bin/git.semantic-version.sh --add-keyword invalid
      The status should be failure
      The result of function no_colors_stderr should include "Invalid keyword format"
    End

    It "accepts multiple --add-keyword parameters"
      When run script bin/git.semantic-version.sh --add-keyword wip:patch --add-keyword exp:none --help
      The status should be success
      The result of function no_colors_stdout should include "USAGE:"
    End

    It "rejects unknown options"
      When run script bin/git.semantic-version.sh --unknown-option
      The status should be failure
      The result of function no_colors_stderr should include "Unknown option"
    End
  End

  Describe "Integration tests"
    It "processes commits from recent history"
      When run script bin/git.semantic-version.sh --from-commit HEAD~5 --initial-version 1.0.0
      The status should be success
      The result of function no_colors_stdout should include "Semantic Version History"
      The result of function no_colors_stdout should include "Summary:"
    End

    It "works with --from-last-tag strategy"
      When run script bin/git.semantic-version.sh --from-last-tag --initial-version 1.0.0
      The status should be success
      The result of function no_colors_stdout should include "Semantic Version History"
    End

    It "validates not in git repository"
      # This would require running in a non-git directory
      Skip "Requires running outside git repository"
    End
  End
End
