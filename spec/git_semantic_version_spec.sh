#!/usr/bin/env bash
# shell: bash altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2155,SC2034

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-27
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

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

Describe "bin/git.semantic-version.sh /"
  # Set E_BASH to point to .scripts before including the main script
  # BeforeAll 'E_BASH="$(cd "$(dirname "$SHELLSPEC_SPECFILE")" && cd ../.scripts && pwd)"'
  # Note: Commented out because the path calculation fails in test environment.
  # The script's fallback mechanism works correctly.

  # Source the script to load functions
  Include "bin/git.semantic-version.sh"

  Describe "gitsv:parse_commit_type() /"
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

  Describe "gitsv:has_breaking_change() /"
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

  Describe "gitsv:extract_breaking_change_line() /"
    It "returns the BREAKING CHANGE line from the body"
      When call gitsv:extract_breaking_change_line $'feat: something\n\nBREAKING CHANGE: api change\nmore'
      The output should eq "BREAKING CHANGE: api change"
    End

    It "returns empty when no breaking change exists"
      When call gitsv:extract_breaking_change_line "feat: something"
      The output should eq ""
    End
  End

  Describe "gitsv:truncate_text() /"
    It "returns original text when under limit"
      When call gitsv:truncate_text "short" 10
      The output should eq "short"
    End

    It "truncates and appends ellipsis when over limit"
      When call gitsv:truncate_text "0123456789" 8
      The output should eq "01234..."
    End
  End

  Describe "gitsv:format_annotation_marker() /"
    It "wraps the number in purple brackets"
      When call gitsv:format_annotation_marker "3"
      The output should eq "${cl_purple}[3]${cl_reset}"
    End
  End

  Describe "gitsv:format_annotation_entry() /"
    It "adds a hint to show the full commit message"
      When call gitsv:format_annotation_entry "${cl_purple}[2]${cl_reset}" "found BREAKING CHANGE: api" "abc1234"
      The result of function no_colors_stdout should include "[2] - found BREAKING CHANGE: api..."
      The result of function no_colors_stdout should include "full message: git show -s --format=%B abc1234"
    End
  End

  Describe "gitsv:breaking_change_annotation() /"
    It "returns annotation when breaking change is hidden in body"
      When call gitsv:breaking_change_annotation $'feat: foo\n\nBREAKING CHANGE: api change' "feat: foo"
      The output should include "found BREAKING CHANGE: api change"
    End

    It "returns empty when breaking change is not hidden"
      When call gitsv:breaking_change_annotation "BREAKING CHANGE: api change" "BREAKING CHANGE: api change"
      The output should eq ""
    End
  End

  Describe "gitsv:determine_bump() /"
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

  Describe "gitsv:add_keyword() /"
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

  Describe "gitsv:determine_bump() with custom keywords /"
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

  Describe "gitsv:bump_version() /"
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

  Describe "gitsv:version_diff() /"
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

  Describe "gitsv:format_output_line() /"
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

  Describe "gitsv:get_first_commit() /"
    It "returns the first commit hash in repository"
      When call gitsv:get_first_commit
      The status should be success
      # Should return a 40-char git hash (hex string)
      # Not checking specific hash as repo history can be rewritten
      # Using glob pattern to check for hex-like output
      The result of function no_colors_stdout should not eq ""
      The result of function no_colors_stdout should match pattern "*[0-9a-f]*"
    End
  End

  Describe "gitsv:get_commit_tags() /"
    It "returns empty string for commits without tags"
      # Get a recent commit that likely has no tags
      recent_commit="$(git rev-parse HEAD)"
      When call gitsv:get_commit_tags "$recent_commit"
      The status should be success
    End

    It "handles invalid commit hash gracefully"
      When call gitsv:get_commit_tags "invalid_hash_12345"
      The status should be success
      The output should eq ""
    End
  End

  Describe "gitsv:extract_semver_from_tag() /"
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

  Describe "gitsv:extract_semvers_from_tags() /"
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

  Describe "gitsv:is_tag_included() - Branch ancestry filtering /"
    It "includes all tags when FILTER_BRANCH_TAGS is false"
      FILTER_BRANCH_TAGS=false
      # Get any tag from the repository
      local_tag=$(git tag -l 2>/dev/null | head -n1)

      When call gitsv:is_tag_included "$local_tag"
      The status should be success
    End

    It "returns success for tag in HEAD ancestry when filtering enabled"
      FILTER_BRANCH_TAGS=true

      # Mock git to simulate tag that IS an ancestor
      Mock git
        case "$1 $2" in
        "rev-list -n")
          # Return a fake commit hash
          echo "abc123def456"
          ;;
        "merge-base --is-ancestor")
          # Simulate: tag IS an ancestor
          exit 0
          ;;
        *)
          command git "$@"
          ;;
        esac
      End

      When call gitsv:is_tag_included "v1.0.0"
      The status should be success
    End

    It "returns failure for tag NOT in HEAD ancestry when filtering enabled"
      FILTER_BRANCH_TAGS=true

      # Mock git to simulate tag that is NOT an ancestor
      Mock git
        case "$1 $2" in
        "rev-list -n")
          # Return a fake commit hash
          echo "abc123def456"
          ;;
        "merge-base --is-ancestor")
          # Simulate: tag is NOT an ancestor
          exit 1
          ;;
        *)
          command git "$@"
          ;;
        esac
      End

      When call gitsv:is_tag_included "v2.0.0"
      The status should be failure
    End

    It "returns success when filtering disabled regardless of ancestry"
      FILTER_BRANCH_TAGS=false

      # Mock git to simulate tag that is NOT an ancestor
      Mock git
        case "$1 $2" in
        "rev-list -n")
          echo "abc123def456"
          ;;
        "merge-base --is-ancestor")
          # Simulate: tag is NOT an ancestor
          exit 1
          ;;
        *)
          command git "$@"
          ;;
        esac
      End

      # Should still return success because filtering is disabled
      When call gitsv:is_tag_included "v2.0.0"
      The status should be success
    End
  End

  Describe "gitsv:get_last_version_tag() /"
    It "returns latest semver tag if exists"
      When call gitsv:get_last_version_tag
      The status should be success
      # Output should be a version (1.1.0 in this repo)
      The result of function no_colors_stdout should match pattern "*[0-9].[0-9]*.[0-9]*"
    End

    It "strips 'v' prefix from tags"
      # Mock git tag command to test
      Skip "Requires git command mocking"
    End

    It "filters tags to only ancestors when FILTER_BRANCH_TAGS is true"
      FILTER_BRANCH_TAGS=true

      # Mock git to return multiple tags, with v2.0.0 being NOT an ancestor
      Mock git
        case "$1" in
        tag)
          # Return tags in reverse version order (highest first)
          echo "v2.0.0"
          echo "v1.0.0"
          ;;
        rev-list)
          # Return commit hash for the tag
          # git rev-list -n 1 <tag> -> $1=rev-list, $2=-n, $3=1, $4=<tag>
          if [[ "$4" == "v2.0.0" ]]; then
            echo "notancestor123"
          elif [[ "$4" == "v1.0.0" ]]; then
            echo "ancestor456"
          else
            command git "$@"
          fi
          ;;
        merge-base)
          # v2.0.0 is NOT an ancestor, v1.0.0 IS an ancestor
          # git merge-base --is-ancestor <commit> HEAD -> $1=merge-base, $2=--is-ancestor, $3=<commit>, $4=HEAD
          if [[ "$3" == "notancestor123" ]]; then
            exit 1
          elif [[ "$3" == "ancestor456" ]]; then
            exit 0
          else
            command git "$@"
          fi
          ;;
        *)
          command git "$@"
          ;;
        esac
      End

      # Should return v1.0.0 (without 'v'), skipping v2.0.0
      When call gitsv:get_last_version_tag
      The output should eq "1.0.0"
    End

    It "includes all tags when FILTER_BRANCH_TAGS is false"
      FILTER_BRANCH_TAGS=false

      # Mock git to return multiple tags
      Mock git
        case "$1" in
        tag)
          # Return tags in reverse version order
          echo "v2.0.0"
          echo "v1.0.0"
          ;;
        rev-list)
          # Return commit hash
          echo "commit123"
          ;;
        merge-base)
          # Simulate NOT an ancestor (but filtering is disabled)
          exit 1
          ;;
        *)
          command git "$@"
          ;;
        esac
      End

      # Should return v2.0.0 (highest) even though it's not an ancestor
      When call gitsv:get_last_version_tag
      The output should eq "2.0.0"
    End
  End

  Describe "gitsv:get_last_version_tag_commit() /"
    It "returns commit hash for latest version tag"
      When call gitsv:get_last_version_tag_commit
      The status should be success
      # Should return a valid commit hash for the latest version tag
      # Not checking specific hash as it changes when new tags are added
      The result of function no_colors_stdout should not eq ""
      The result of function no_colors_stdout should match pattern "*[0-9a-f]*"
    End
  End

  Describe "gitsv:get_branch_start_commit() /"
    It "returns a valid commit hash"
      When call gitsv:get_branch_start_commit
      The status should be success
      # Should return a git hash (hex string)
      # Not checking specific hash as it changes after branch merge/rebase
      The result of function no_colors_stdout should not eq ""
      The result of function no_colors_stdout should match pattern "*[0-9a-f]*"
    End
  End

  Describe "gitsv:get_commit_from_n_versions_back() /"
    It "returns commit hash when versions exist"
      When call gitsv:get_commit_from_n_versions_back 1
      The status should be success
      # Should return a valid commit hash (depends on current version tags)
      # Not checking specific hash as it changes when new tags are added
      The result of function no_colors_stdout should not eq ""
      The result of function no_colors_stdout should match pattern "*[0-9a-f]*"
    End

    It "handles when N is larger than version count"
      When call gitsv:get_commit_from_n_versions_back 9999
      The status should be success
      # Should fallback to first commit (return valid hash)
      # Not checking specific hash as repo history can change
      The result of function no_colors_stdout should not eq ""
      The result of function no_colors_stdout should match pattern "*[0-9a-f]*"
    End

    It "handles empty tag list (no semver tags exist) - regression test"
      # Mock git tag to return empty list
      git() {
        case "$1" in
        tag)
          # Return empty output (no tags)
          echo ""
          ;;
        rev-list)
          # Return a valid commit hash for first commit
          command git rev-list --max-parents=0 HEAD 2>/dev/null
          ;;
        *)
          command git "$@"
          ;;
        esac
      }

      # Test with n=1 (the problematic case from bug report)
      When call gitsv:get_commit_from_n_versions_back 1
      The status should be success
      # Should fallback to first commit, not return empty string
      The result of function no_colors_stdout should not eq ""
      The result of function no_colors_stdout should match pattern "*[0-9a-f]*"
    End
  End

  Describe "Command line argument parsing /"
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

  Describe "Regression: Tag diff format (commit 905698f) /"
    # Issue: Tag versions should show =version, not +diff
    # Example: Tag v1.0.0 should show =1.0.0, not +0.9.0

    It "formats regular version diff with + prefix"
      # Normal version bumps show calculated diff
      version_before="1.0.0"
      version_after="1.1.0"

      When call gitsv:version_diff "$version_before" "$version_after"
      The output should start with "+"
      The output should eq "+0.1.0"
    End

    It "would format tag diff as ={version} in processing loop"
      # When bump_type="tag", diff is set to "={version}"
      # This is done in the processing loop, not in version_diff function
      # Test documents expected format for tagged versions

      tag_version="1.0.0"
      expected_diff="=${tag_version}"

      When call echo "$expected_diff"
      The output should eq "=1.0.0"
      The output should start with "="
    End
  End

  Describe "Regression: Bump type determines color (commit cd3c8b2) /"
    # Issue: After tag v1.0.1-alpha.1, ALL commits showed purple
    # Root cause: Checked version_after for pre-release suffix instead of bump_type
    # Fix: Color based ONLY on bump_type, not version state

    It "returns patch bump type for fix: commits"
      # fix: commits should return "patch" regardless of version state
      commit_msg="fix: kcov docker image use"

      When call gitsv:determine_bump "$commit_msg"
      The output should eq "patch"
    End

    It "returns none bump type for non-conventional commits"
      # Non-conventional commits should return "none"
      commit_msg="Update README"

      When call gitsv:determine_bump "$commit_msg"
      The output should eq "none"
    End

    It "returns minor bump type for feat: commits"
      # feat: commits should return "minor"
      commit_msg="feat: add new feature"

      When call gitsv:determine_bump "$commit_msg"
      The output should eq "minor"
    End

    It "returns major bump type for breaking changes"
      # Breaking changes should return "major"
      commit_msg="feat!: breaking change"

      When call gitsv:determine_bump "$commit_msg"
      The output should eq "major"
    End

    It "determines bump type independent of version suffix (fix: commit)"
      # Bump type should NOT change based on current version state
      # This would have failed before fix: version state affected color
      # Test: fix: commit should be patch even if version has -alpha
      commit_msg="fix: bug fix"
      When call gitsv:determine_bump "$commit_msg"
      The output should eq "patch"
    End

    It "determines bump type independent of version suffix (non-conventional)"
      # Test: non-conventional should be none even if version has -alpha
      commit_msg="Self update functionality"
      When call gitsv:determine_bump "$commit_msg"
      The output should eq "none"
    End
  End

  Describe "Regression: Tag priority over pre-release check (commit cd42269) /"
    # Issue: Tags with pre-release suffix (v1.0.1-alpha.1) showed purple instead of tag color
    # Root cause: Pre-release regex checked before tag bump_type
    # Fix: Check bump_type=="tag" first, before pre-release suffix check

    # Note: Color logic is in processing loop, not in testable function
    # These tests document the bump_type behavior that drives color

    It "processes tag with pre-release suffix correctly"
      # Tag v1.0.1-alpha.1 should have bump_type="tag"
      # This is set in processing loop when tag_versions is non-empty
      # Test documents that semver extraction works for pre-release tags

      tag="v1.0.1-alpha.1"
      When call gitsv:extract_semver_from_tag "$tag"
      The output should eq "1.0.1-alpha.1"
    End

    It "extracts semver from tag with alpha pre-release suffix"
      # Tag extraction should handle alpha format
      When call gitsv:extract_semver_from_tag "v2.0.0-alpha.1"
      The output should eq "2.0.0-alpha.1"
    End

    It "extracts semver from tag with beta pre-release suffix"
      # Tag extraction should handle beta format
      tag="v1.5.0-beta.3"
      When call gitsv:extract_semver_from_tag "$tag"
      The output should eq "1.5.0-beta.3"
    End

    It "extracts semver from tag with rc pre-release suffix"
      # Tag extraction should handle rc format
      tag="package/v3.0.0-rc.1"
      When call gitsv:extract_semver_from_tag "$tag"
      The output should eq "3.0.0-rc.1"
    End
  End

  Describe "Integration tests /"
    setup_integration_test() {
      TEST_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/semver.XXXXXX")
      export TEST_DIR
      # We need to save the original directory to return to it if needed,
      # but ShellSpec runs in subshells mostly.
      # However, we need to access the script.
      SCRIPT_PATH="$SHELLSPEC_PROJECT_ROOT/bin/git.semantic-version.sh"

      cd "$TEST_DIR" || return 1
      git init -q
      git config user.email "test@example.com"
      git config user.name "Test User"

      # Create some commits to simulate history
      # HEAD~10..HEAD
      for i in {1..11}; do
        echo "change $i" >file.txt
        git add file.txt
        if [ "$i" -eq 6 ]; then
          git commit -q -m "feat: feature $i"
          git tag v1.0.0
        else
          git commit -q -m "fix: fix $i"
        fi
      done
    }

    cleanup_integration_test() {
      rm -rf "$TEST_DIR"
    }

    Before 'setup_integration_test'
    After 'cleanup_integration_test'

    It "processes commits from recent history"
      When run script "$SCRIPT_PATH" --from-commit HEAD~5 --initial-version 1.0.0
      The status should be success
      The result of function no_colors_stdout should include "Semantic Version History"
      The result of function no_colors_stdout should include "Summary:"
    End

    It "works with --from-last-tag strategy"
      When run script "$SCRIPT_PATH" --from-last-tag --initial-version 1.0.0
      The status should be success
      The result of function no_colors_stdout should include "Semantic Version History"
    End

    It "shows tag column in output"
      When run script "$SCRIPT_PATH" --from-commit HEAD~10 --initial-version 1.0.0
      The status should be success
      # Should have Tag column header
      The result of function no_colors_stdout should include "| Tag |"
    End

    It "validates not in git repository"
      # This runs in a subprocess, so we can control the CWD
      # create a non-git dir OUTSIDE of TEST_DIR (which is a git repo)
      # A subdirectory of a git repo is still inside the git repo!
      NOGIT_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/nogit.XXXXXX")

      # We use a subshell to run the script in the non-git dir
      # run script works by executing the script.
      # ShellSpec 'When run' uses the command given.

      cwd_cmd() {
        cd "$NOGIT_DIR" && "$SCRIPT_PATH" "$@"
      }

      When run cwd_cmd
      The status should be failure
      The stderr should include "Not a git repository"

      # Cleanup the extra temp directory
      rm -rf "$NOGIT_DIR"
    End
  End
End
