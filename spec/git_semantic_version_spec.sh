#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034

## Unit tests for bin/git.semantic-version.sh
## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-11-06
## Version: 1.0.0
## License: MIT

eval "$(shellspec - -c) exit 1"

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

# Set E_BASH path
E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"

Describe "git.semantic-version.sh"

  # Source the script to load functions
  Include "$E_BASH/bin/git.semantic-version.sh"

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

    It "returns patch for unknown commit type"
      When call gitsv:determine_bump "random commit"
      The output should eq "patch"
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
    End

    It "allows all valid bump types"
      When call gitsv:add_keyword "test1" "major"
      The status should be success
      When call gitsv:add_keyword "test2" "minor"
      The status should be success
      When call gitsv:add_keyword "test3" "patch"
      The status should be success
      When call gitsv:add_keyword "test4" "none"
      The status should be success
    End
  End

  Describe "gitsv:determine_bump() with custom keywords"
    It "respects added wip keyword"
      # Add wip keyword first
      gitsv:add_keyword "wip" "patch"
      When call gitsv:determine_bump "wip: work in progress"
      The output should eq "patch"
    End

    It "respects custom keyword with none bump"
      gitsv:add_keyword "experiment" "none"
      When call gitsv:determine_bump "experiment: trying something"
      The output should eq "none"
    End

    It "respects custom keyword with minor bump"
      gitsv:add_keyword "feature" "minor"
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
    It "formats output line correctly"
      When call gitsv:format_output_line "abc1234" "feat: add feature" "1.2.3" "1.3.0" "+0.1.0"
      The output should include "abc1234"
      The output should include "feat: add feature"
      The output should include "1.2.3"
      The output should include "1.3.0"
      The output should include "+0.1.0"
    End

    It "truncates long commit messages"
      local msg="feat: this is a very long commit message that should be truncated to fit in the output"
      When call gitsv:format_output_line "abc1234" "$msg" "1.2.3" "1.3.0" "+0.1.0"
      The output should include "..."
    End
  End

  Describe "gitsv:get_first_commit()"
    It "returns the first commit hash in repository"
      When call gitsv:get_first_commit
      The status should be success
      The output should not be blank
      # Should be a valid commit hash (40 chars or 7+ chars for short)
      The length of output should be greater than 6
    End
  End

  Describe "gitsv:get_last_version_tag()"
    It "returns latest semver tag if exists"
      # This test depends on actual repo tags
      When call gitsv:get_last_version_tag
      The status should be success
      # Output might be empty if no tags, or a version string
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
      # Output might be empty or a commit hash
    End
  End

  Describe "gitsv:get_branch_start_commit()"
    It "returns a commit hash"
      When call gitsv:get_branch_start_commit
      The status should be success
      # Should return a commit hash
      The output should not be blank
    End
  End

  Describe "gitsv:get_commit_from_n_versions_back()"
    It "returns commit hash when versions exist"
      # Test with N=1
      When call gitsv:get_commit_from_n_versions_back 1
      The status should be success
    End

    It "handles when N is larger than version count"
      # Test with very large N
      When call gitsv:get_commit_from_n_versions_back 9999
      The status should be success
      # Should fallback to first commit
      The output should not be blank
    End
  End

  Describe "Command line argument parsing"
    It "displays help with --help"
      When run script bin/git.semantic-version.sh --help
      The status should be success
      The output should include "USAGE:"
      The output should include "OPTIONS:"
      The output should include "EXAMPLES:"
    End

    It "accepts --initial-version parameter"
      When run script bin/git.semantic-version.sh --initial-version 5.0.0 --from-commit HEAD --help
      The status should be success
    End

    It "rejects invalid --initial-version format"
      When run script bin/git.semantic-version.sh --initial-version invalid
      The status should be failure
      The error should include "Invalid initial version"
    End

    It "accepts --add-keyword parameter"
      When run script bin/git.semantic-version.sh --add-keyword wip:patch --from-commit HEAD --help
      The status should be success
    End

    It "rejects invalid --add-keyword format"
      When run script bin/git.semantic-version.sh --add-keyword invalid
      The status should be failure
      The error should include "Invalid keyword format"
    End

    It "accepts multiple --add-keyword parameters"
      When run script bin/git.semantic-version.sh --add-keyword wip:patch --add-keyword exp:none --help
      The status should be success
    End

    It "rejects unknown options"
      When run script bin/git.semantic-version.sh --unknown-option
      The status should be failure
      The error should include "Unknown option"
    End
  End

  Describe "Integration tests"
    It "processes commits from HEAD commit"
      # Test with just the last commit
      local commit_hash=$(git rev-parse HEAD)
      When run script bin/git.semantic-version.sh --from-commit "$commit_hash" --initial-version 1.0.0
      The status should be success
      The output should include "Semantic Version History"
      The output should include "Final Version:"
    End

    It "respects custom keywords in processing"
      local commit_hash=$(git log --oneline -20 | grep "wip:" | head -1 | cut -d' ' -f1)
      # Skip if no wip commits found
      Skip if "no wip commits found" [ -z "$commit_hash" ]

      When run script bin/git.semantic-version.sh --add-keyword wip:patch --from-commit "${commit_hash}^" --initial-version 1.0.0
      The status should be success
      The output should include "wip:"
    End

    It "validates not in git repository"
      # This would require running in a non-git directory
      Skip "Requires running outside git repository"
    End
  End
End
