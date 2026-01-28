#!/usr/bin/env bash
# shell: bash altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-27
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

Mock logger
  echo "$@"
End

Mock logger:init
  echo "$@"
End

Mock config:logger:Dependencies
  echo "$@"
End

Mock printf:Dependencies
  printf "$@"
End

Mock echo:Dependencies
  echo "$@"
End

Mock echo:Install
  echo "$@"
End

Include ".scripts/_dependencies.sh"

Describe "_dependencies.sh /"
  # Remove colors in output before each function call (skip readonly YEP and BAD)
  BeforeCall "unset cl_red cl_green cl_blue cl_purple cl_yellow cl_reset cl_grey"

  # Ensure CI variables are clean at the START of each test (before test setup)
  # This runs before any test code, allowing tests to explicitly set CI if needed
  BeforeEach "unset CI CI_E_BASH_INSTALL_DEPENDENCIES"

  Describe "Dependency /"
    It "Dependency OK on \`dependency bash \"5.*.*\" \"brew install bash\" --version\`"
      When call dependency bash "5.*.*" "brew install bash" --version

      The status should be success
      The output should include "Dependency [OK]: \`bash\` - version: 5."
      The error should include ""

      # Dump
    End

    It "Custom version request flag on \`dependency bash \"5.*.*\" \"brew install bash\" --version\`"
      When call dependency bash "5.*.*" "brew install bash" --help

      The status should be success
      The output should include "Dependency [OK]: \`bash\` - version: 5."
      The output should include 'bash home page: <http://www.gnu.org/software/bash>'
      The error should include ""

      # Dump
    End

    It "Range of version on \`dependency bash \"[45].*.*\" \"brew install bash\" --version\`"
      When call dependency bash "[45].*.*" "brew install bash" --version

      The status should be success
      The output should include "Dependency [OK]: \`bash\` - version:"
      The error should include ""

      # Dump
    End

    It "Customized version pattern on \`dependency bash \"[1-5].*.*(1)-release\" \"brew install bash\" --version\`"
      When call dependency bash "[1-5].*.*(1)-release" "brew install bash" --version

      The status should be success
      The output should include "Dependency [OK]: \`bash\` - version: 5."
      The error should include ""

      # Dump
    End

    It "Wrong Version on \`dependency bash \"99.*.*\" \"brew install bash\"\`"
      When call dependency bash "99.*.*" "brew install bash"

      The status should be failure
      The output should include "Error: dependency version \`bash\` is wrong."
      The output should include "Hint. To install tool use the command below:"
      The output should include "\$>  brew install bash"
      The error should include ""

      # Dump
    End

    It "Do Exec on wrong version on \`dependency bash \"99.*.*\" \"echo 'executted'\" --version --exec\`"
      # Note: --exec can be only after $4 parameter
      When call dependency bash "99.*.*" "echo 'executed' >&2;" --version --exec

      The status should be success
      The output should include "Error: dependency version \`bash\` is wrong."
      The output should include "Expected : \`99.*.*\`"
      The output should include "Executing: echo 'executed' >&2;"
      The error should include "executed"

      # Dump
    End

    It "Not Found on \`dependency not_exist_tool \"1.0.0\"\`"
      When call dependency not_exist_tool "1.*.*"

      The status should eq 1
      The output should include "Error: dependency \`not_exist_tool\` not found."
      The output should include "No details. Please google it."
      The error should include ""

      # Dump
    End
  End

  Describe "Optional /"
    BeforeEach '_cache:clear'

    It "Optional OK on \`optional bash \"5.*.*\" \"brew install bash\" --version --debug\`"
      When call optional bash "5.*.*" "brew install bash" --version --debug

      The status should be success
      The output should include "Optional   [OK]: \`bash\` - version: 5."
      The error should include ""

      # Dump
    End

    It "Wrong Version on \`optional bash \"99.*.*\" \"brew install bash\" --version\`"
      When call optional bash "99.*.*" "brew install bash" --version

      The status should be success
      The output should include "Optional   [NO]: \`bash\` - wrong version! Try: brew install bash"
      The error should include ""

      # Dump
    End

    It "Not Found on \`optional not_exist_tool \"1.0.0\"\`"
      When call optional not_exist_tool "1.*.*"

      The status should eq 0
      The output should include "Optional   [NO]: \`not_exist_tool\` - not found! Try: No details. Please google it."
      The error should include ""

      # Dump
    End

  End

  Describe "Utilities /"
    It "isDebug returns true when --debug flag is provided"
      When call isDebug --debug
      The status should be success
      The output should eq true
      The error should eq ''
      # Dump
    End

    It "isExec returns true when --exec flag is provided"
      When call isExec --exec
      The status should be success
      The output should eq true
      The error should eq ''
      # Dump
    End

    It "isOptional returns true when --optional flag is provided"
      When call isOptional --optional
      The status should be success
      The output should eq true
      The error should eq ''
      # Dump
    End

    It "isSilent returns true when --silent flag is provided"
      When call isSilent --silent
      The status should be success
      The output should eq true
      The error should eq ''
      # Dump
    End

    It "isCIAutoInstallEnabled returns true when CI=1 and CI_E_BASH_INSTALL_DEPENDENCIES=1"
      export CI=1
      export CI_E_BASH_INSTALL_DEPENDENCIES=1
      When call isCIAutoInstallEnabled
      The status should be success
      The output should eq true
      The error should eq ''
      unset CI CI_E_BASH_INSTALL_DEPENDENCIES
      # Dump
    End

    It "isCIAutoInstallEnabled returns true when CI=true and CI_E_BASH_INSTALL_DEPENDENCIES=true"
      export CI=true
      export CI_E_BASH_INSTALL_DEPENDENCIES=true
      When call isCIAutoInstallEnabled
      The status should be success
      The output should eq true
      The error should eq ''
      unset CI CI_E_BASH_INSTALL_DEPENDENCIES
      # Dump
    End

    It "isCIAutoInstallEnabled returns true when CI=yes and CI_E_BASH_INSTALL_DEPENDENCIES=yes"
      export CI=yes
      export CI_E_BASH_INSTALL_DEPENDENCIES=yes
      When call isCIAutoInstallEnabled
      The status should be success
      The output should eq true
      The error should eq ''
      unset CI CI_E_BASH_INSTALL_DEPENDENCIES
      # Dump
    End

    It "isCIAutoInstallEnabled returns true with case-insensitive TRUE"
      export CI=1
      export CI_E_BASH_INSTALL_DEPENDENCIES=TRUE
      When call isCIAutoInstallEnabled
      The status should be success
      The output should eq true
      The error should eq ''
      unset CI CI_E_BASH_INSTALL_DEPENDENCIES
      # Dump
    End

    It "isCIAutoInstallEnabled returns true with case-insensitive YES"
      export CI=1
      export CI_E_BASH_INSTALL_DEPENDENCIES=YES
      When call isCIAutoInstallEnabled
      The status should be success
      The output should eq true
      The error should eq ''
      unset CI CI_E_BASH_INSTALL_DEPENDENCIES
      # Dump
    End

    It "isCIAutoInstallEnabled returns true with mixed case True"
      export CI=1
      export CI_E_BASH_INSTALL_DEPENDENCIES=True
      When call isCIAutoInstallEnabled
      The status should be success
      The output should eq true
      The error should eq ''
      unset CI CI_E_BASH_INSTALL_DEPENDENCIES
      # Dump
    End

    It "isCIAutoInstallEnabled returns true with mixed case YeS"
      export CI=1
      export CI_E_BASH_INSTALL_DEPENDENCIES=YeS
      When call isCIAutoInstallEnabled
      The status should be success
      The output should eq true
      The error should eq ''
      unset CI CI_E_BASH_INSTALL_DEPENDENCIES
      # Dump
    End

    It "isCIAutoInstallEnabled returns false when CI_E_BASH_INSTALL_DEPENDENCIES is unset"
      # BeforeCall ensures CI is unset
      When call isCIAutoInstallEnabled
      The status should be success
      The output should eq false
      The error should eq ''
      # Dump
    End

    It "isCIAutoInstallEnabled returns false when CI is not set but CI_E_BASH_INSTALL_DEPENDENCIES=1"
      # BeforeCall ensures CI is unset, only set the install flag
      export CI_E_BASH_INSTALL_DEPENDENCIES=1
      When call isCIAutoInstallEnabled
      The status should be success
      The output should eq false
      The error should eq ''
      unset CI_E_BASH_INSTALL_DEPENDENCIES
      # Dump
    End

    It "isCIAutoInstallEnabled returns false when CI=1 but CI_E_BASH_INSTALL_DEPENDENCIES has invalid value"
      export CI=1
      export CI_E_BASH_INSTALL_DEPENDENCIES=invalid
      When call isCIAutoInstallEnabled
      The status should be success
      The output should eq false
      The error should eq ''
      unset CI CI_E_BASH_INSTALL_DEPENDENCIES
      # Dump
    End
  End

  Describe "CI Auto-Install Mode /"
    BeforeEach '_cache:clear'

    It "CI mode enabled with CI=1 and CI_E_BASH_INSTALL_DEPENDENCIES=1 should auto-install missing tool"
      export CI=1
      export CI_E_BASH_INSTALL_DEPENDENCIES=1
      When call dependency not_exist_tool "1.*.*" "echo 'auto-installed tool' >&2"

      The status should be success
      The output should include "auto-installing missing dependency"
      The error should include "auto-installed tool"

      unset CI CI_E_BASH_INSTALL_DEPENDENCIES
      # Dump
    End

    It "CI mode enabled with CI=true and CI_E_BASH_INSTALL_DEPENDENCIES=true should auto-install missing tool"
      export CI=true
      export CI_E_BASH_INSTALL_DEPENDENCIES=true
      When call dependency not_exist_tool "1.*.*" "echo 'auto-installed tool' >&2"

      The status should be success
      The output should include "auto-installing missing dependency"
      The error should include "auto-installed tool"

      unset CI CI_E_BASH_INSTALL_DEPENDENCIES
      # Dump
    End

    It "CI mode enabled with CI=yes and CI_E_BASH_INSTALL_DEPENDENCIES=yes should auto-install missing tool"
      export CI=yes
      export CI_E_BASH_INSTALL_DEPENDENCIES=yes
      When call dependency not_exist_tool "1.*.*" "echo 'auto-installed tool' >&2"

      The status should be success
      The output should include "auto-installing missing dependency"
      The error should include "auto-installed tool"

      unset CI CI_E_BASH_INSTALL_DEPENDENCIES
      # Dump
    End

    It "CI mode enabled should auto-install tool with wrong version"
      export CI=1
      export CI_E_BASH_INSTALL_DEPENDENCIES=1
      When call dependency bash "99.*.*" "echo 'auto-upgraded bash' >&2"

      The status should be success
      The output should include "auto-installing dependency with wrong version"
      The error should include "auto-upgraded bash"

      unset CI CI_E_BASH_INSTALL_DEPENDENCIES
      # Dump
    End

    It "CI mode disabled should not auto-install (default behavior)"
      # BeforeCall ensures CI and CI_E_BASH_INSTALL_DEPENDENCIES are unset
      When call dependency not_exist_tool "1.*.*" "echo 'should not execute' >&2"

      The status should be failure
      The output should include "Error: dependency \`not_exist_tool\` not found."
      The error should not include "should not execute"

      # Dump
    End

    It "CI mode with invalid value should not auto-install"
      export CI=1
      export CI_E_BASH_INSTALL_DEPENDENCIES=invalid
      When call dependency not_exist_tool "1.*.*" "echo 'should not execute' >&2"

      The status should be failure
      The output should include "Error: dependency \`not_exist_tool\` not found."
      The error should not include "should not execute"

      unset CI CI_E_BASH_INSTALL_DEPENDENCIES
      # Dump
    End

    It "CI_E_BASH_INSTALL_DEPENDENCIES=1 without CI should not auto-install"
      # BeforeCall ensures CI is unset, only set the install flag
      export CI_E_BASH_INSTALL_DEPENDENCIES=1
      When call dependency not_exist_tool "1.*.*" "echo 'should not execute' >&2"

      The status should be failure
      The output should include "Error: dependency \`not_exist_tool\` not found."
      The error should not include "should not execute"

      unset CI_E_BASH_INSTALL_DEPENDENCIES
      # Dump
    End

    It "CI mode should skip optional dependencies (not auto-install)"
      export CI=1
      export CI_E_BASH_INSTALL_DEPENDENCIES=1
      When call optional not_exist_tool "1.*.*" "echo 'should not auto-install optional' >&2"

      The status should be success
      The output should include "Optional   [NO]: \`not_exist_tool\` - not found!"
      The error should not include "should not auto-install optional"

      unset CI CI_E_BASH_INSTALL_DEPENDENCIES
      # Dump
    End

    It "CI mode should skip optional dependencies with wrong version"
      export CI=1
      export CI_E_BASH_INSTALL_DEPENDENCIES=1
      When call optional bash "99.*.*" "echo 'should not auto-install optional' >&2"

      The status should be success
      The output should include "Optional   [NO]: \`bash\` - wrong version!"
      The error should not include "should not auto-install optional"

      unset CI CI_E_BASH_INSTALL_DEPENDENCIES
      # Dump
    End

    It "CI mode should still auto-install required dependencies"
      export CI=1
      export CI_E_BASH_INSTALL_DEPENDENCIES=1
      When call dependency not_exist_required "1.*.*" "echo 'auto-installed required' >&2"

      The status should be success
      The output should include "auto-installing missing dependency"
      The error should include "auto-installed required"

      unset CI CI_E_BASH_INSTALL_DEPENDENCIES
      # Dump
    End

    It "CI mode should work with case-insensitive TRUE value"
      export CI=1
      export CI_E_BASH_INSTALL_DEPENDENCIES=TRUE
      When call dependency not_exist_tool "1.*.*" "echo 'auto-installed with TRUE' >&2"

      The status should be success
      The output should include "auto-installing missing dependency"
      The error should include "auto-installed with TRUE"

      unset CI CI_E_BASH_INSTALL_DEPENDENCIES
      # Dump
    End
  End

  Describe "dependency:dealias /"
    BeforeEach 'unset SKIP_DEALIAS'

    It "resolves 'golang' alias to 'go'"
      When call dependency:dealias "golang"
      The output should eq "go"
      The error should eq ''
    End

    It "resolves 'nodejs' alias to 'node'"
      When call dependency:dealias "nodejs"
      The output should eq "node"
      The error should eq ''
    End

    It "resolves 'homebrew' alias to 'brew'"
      When call dependency:dealias "homebrew"
      The output should eq "brew"
      The error should eq ''
    End

    It "resolves 'rust' alias to 'rustc'"
      When call dependency:dealias "rust"
      The output should eq "rustc"
      The error should eq ''
    End

    It "resolves 'jre' alias to 'java'"
      When call dependency:dealias "jre"
      The output should eq "java"
      The error should eq ''
    End

    It "resolves 'jdk' alias to 'javac'"
      When call dependency:dealias "jdk"
      The output should eq "javac"
      The error should eq ''
    End

    It "resolves 'awsebcli' alias to 'eb'"
      When call dependency:dealias "awsebcli"
      The output should eq "eb"
      The error should eq ''
    End

    It "resolves 'awscli' alias to 'aws'"
      When call dependency:dealias "awscli"
      The output should eq "aws"
      The error should eq ''
    End

    It "resolves 'postgresql' alias to 'psql'"
      When call dependency:dealias "postgresql"
      The output should eq "psql"
      The error should eq ''
    End

    It "resolves 'mongodb' alias to 'mongo'"
      When call dependency:dealias "mongodb"
      The output should eq "mongo"
      The error should eq ''
    End

    It "resolves 'openssh' alias to 'ssh'"
      When call dependency:dealias "openssh"
      The output should eq "ssh"
      The error should eq ''
    End

    It "resolves 'goreplay' alias to 'gor'"
      When call dependency:dealias "goreplay"
      The output should eq "gor"
      The error should eq ''
    End

    It "resolves 'httpie' alias to 'http'"
      When call dependency:dealias "httpie"
      The output should eq "http"
      The error should eq ''
    End

    It "passes through unknown aliases as-is"
      When call dependency:dealias "unknown_tool"
      The output should eq "unknown_tool"
      The error should eq ''
    End

    It "passes through canonical names as-is"
      When call dependency:dealias "bash"
      The output should eq "bash"
      The error should eq ''
    End

    It "passes through 'go' as-is (already canonical)"
      When call dependency:dealias "go"
      The output should eq "go"
      The error should eq ''
    End

    It "bypasses alias resolution when SKIP_DEALIAS=1"
      export SKIP_DEALIAS=1
      When call dependency:dealias "golang"
      The output should eq "golang"
      The error should eq ''
      unset SKIP_DEALIAS
    End
  End

  Describe "dependency:known:flags /"
    It "returns '-version' for java"
      When call dependency:known:flags "java" ""
      The output should eq "-version"
      The error should eq ''
    End

    It "returns '-version' for javac"
      When call dependency:known:flags "javac" ""
      The output should eq "-version"
      The error should eq ''
    End

    It "returns '-version' for scala"
      When call dependency:known:flags "scala" ""
      The output should eq "-version"
      The error should eq ''
    End

    It "returns '-version' for kotlin"
      When call dependency:known:flags "kotlin" ""
      The output should eq "-version"
      The error should eq ''
    End

    It "returns '-version' for ant"
      When call dependency:known:flags "ant" ""
      The output should eq "-version"
      The error should eq ''
    End

    It "returns 'version' (no dash) for go"
      When call dependency:known:flags "go" ""
      The output should eq "version"
      The error should eq ''
    End

    It "returns '-VV' for tmux"
      When call dependency:known:flags "tmux" ""
      The output should eq "-VV"
      The error should eq ''
    End

    It "returns '-V' for ab"
      When call dependency:known:flags "ab" ""
      The output should eq "-V"
      The error should eq ''
    End

    It "returns '-V' for unrar"
      When call dependency:known:flags "unrar" ""
      The output should eq "-V"
      The error should eq ''
    End

    It "returns '-V' for composer"
      When call dependency:known:flags "composer" ""
      The output should eq "-V"
      The error should eq ''
    End

    It "returns '-V' for ssh"
      When call dependency:known:flags "ssh" ""
      The output should eq "-V"
      The error should eq ''
    End

    It "returns '-v' for screen"
      When call dependency:known:flags "screen" ""
      The output should eq "-v"
      The error should eq ''
    End

    It "returns '-v' for unzip"
      When call dependency:known:flags "unzip" ""
      The output should eq "-v"
      The error should eq ''
    End

    It "defaults to '--version' for unknown tools"
      When call dependency:known:flags "unknown_tool" ""
      The output should eq "--version"
      The error should eq ''
    End

    It "defaults to '--version' for bash"
      When call dependency:known:flags "bash" ""
      The output should eq "--version"
      The error should eq ''
    End

    It "defaults to '--version' for git"
      When call dependency:known:flags "git" ""
      The output should eq "--version"
      The error should eq ''
    End

    It "defaults to '--version' for node"
      When call dependency:known:flags "node" ""
      The output should eq "--version"
      The error should eq ''
    End

    It "respects user-provided flag override"
      When call dependency:known:flags "java" "--custom-flag"
      The output should eq "--custom-flag"
      The error should eq ''
    End

    It "uses user-provided flag even for tools with exceptions"
      When call dependency:known:flags "go" "--my-version"
      The output should eq "--my-version"
      The error should eq ''
    End

    It "returns user flag when provided (not default)"
      When call dependency:known:flags "unknown" "--flag"
      The output should eq "--flag"
      The error should eq ''
    End
  End

  Describe "Integration: Alias + Version Flag /"
    It "works with bash (uses default --version flag)"
      When call dependency bash "5.*.*" "brew install bash"
      The status should be success
      The output should include "Dependency [OK]: \`bash\` - version:"
      The error should include ""
    End

    It "works with git (uses default --version flag)"
      When call dependency git "2.*.*" "brew install git"
      The status should be success
      The output should include "Dependency [OK]: \`git\` - version:"
      The error should include ""
    End

    It "works with alias 'jre' which resolves to 'java' with '-version' flag"
      When call dependency jre ".*.*" "brew install java"
      The status should be success
      The output should include "Dependency [OK]: \`jre\` - version:"
      The error should include ""
    End

    It "works with alias 'openssh' which resolves to 'ssh' with '-V' flag"
      When call dependency openssh ".*.*" "brew install openssh"
      The status should be success
      The output should include "Dependency [OK]: \`openssh\` - version:"
      The error should include ""
    End
  End

  Describe "Cache Functions /"
    BeforeEach '_cache:clear'

    It "_cache:key generates path-based keys"
      When call _cache:key "/usr/bin/bash" "5.*.*" "--version"
      The output should eq "/usr/bin/bash:5.*.*:--version"
      The error should eq ''
    End

    It "_cache:key supports multiple paths for same tool"
      # Simulates brew vs OS versions
      key1=$(_cache:key "/usr/bin/bash" "3.*.*" "--version")
      key2=$(_cache:key "/opt/homebrew/bin/bash" "5.*.*" "--version")
      When call test "$key1" != "$key2"
      The status should be success
    End

    It "_cache:set and _cache:get work together"
      _cache:set "/usr/bin/test:1.0:--version" 0 "1.0.0" "/usr/bin/test"
      When call _cache:get "/usr/bin/test:1.0:--version"
      The status should be success
      The variable __DEPS_CACHE_STATUS should eq "0"
      The variable __DEPS_CACHE_VERSION should eq "1.0.0"
      The variable __DEPS_CACHE_PATH should eq "/usr/bin/test"
    End

    It "_cache:get returns failure for missing key"
      When call _cache:get "/nonexistent/path:1.0:--version"
      The status should be failure
    End

    It "_cache:clear removes all cached entries"
      _cache:set "/bin/key1:1.0:--version" 0 "1.0.0" "/bin/key1"
      _cache:set "/bin/key2:2.0:--version" 0 "2.0.0" "/bin/key2"
      _cache:clear
      When call _cache:get "/bin/key1:1.0:--version"
      The status should be failure
    End

    It "isNoCache returns true when --no-cache flag is provided"
      When call isNoCache --no-cache
      The status should be success
      The output should eq true
      The error should eq ''
    End

    It "isNoCache returns false when --no-cache flag is not provided"
      When call isNoCache --debug --optional
      The status should be success
      The output should eq false
      The error should eq ''
    End
  End

  Describe "Short Form (Existence Check) /"
    It "dependency:exists returns success for installed tool"
      When call dependency:exists bash
      The status should be success
    End

    It "dependency:exists returns failure for non-existent tool"
      When call dependency:exists nonexistent_tool_xyz
      The status should be failure
    End

    It "dependency:exists resolves aliases"
      is_go_not_installed() { ! command -v go >/dev/null 2>&1; }
      Skip if "go is not installed" is_go_not_installed
      When call dependency:exists golang
      The status should be success
    End

    It "dependency with empty version pattern checks existence only"
      When call dependency bash "" ""
      The status should be success
      The output should include "Dependency [OK]: \`bash\` - found"
      The error should eq ''
    End

    It "dependency with empty version pattern fails for missing tool"
      When call dependency nonexistent_tool_xyz "" ""
      The status should be failure
      The output should include "Dependency [NO]: \`nonexistent_tool_xyz\` - not found"
      The error should eq ''
    End

    It "dependency with --silent suppresses output for short form"
      When call dependency bash "" "" --silent
      The status should be success
      The output should eq ''
      The error should eq ''
    End
  End

  Describe "Cache Integration /"
    BeforeEach '_cache:clear'

    It "caches successful dependency verification"
      # First call - should verify and cache (silently)
      dependency bash "5.*.*" "brew install bash" >/dev/null 2>&1
      # Second call - should use cache
      When call dependency bash "5.*.*" "brew install bash"
      The status should be success
      The output should include "(cached)"
    End

    It "cache is bypassed with --no-cache flag"
      # First call - should verify and cache (silently)
      dependency bash "5.*.*" "brew install bash" >/dev/null 2>&1
      # Second call with --no-cache - should NOT show cached
      When call dependency bash "5.*.*" "brew install bash" --version --no-cache
      The status should be success
      The output should not include "(cached)"
    End

    It "caches failure for missing tool"
      # Call dependency in subshell to avoid test abort on failure (silently)
      (dependency nonexistent_tool_abc "1.*.*" >/dev/null 2>&1 || true)
      # Reload cache from disk (subshell wrote to file but parent needs to reload)
      _cache:load
      # Verify cache was set with failure
      When call _cache:get "nonexistent_tool_abc:1.*.*:--version"
      The status should be success
      The variable __DEPS_CACHE_STATUS should eq "1"
    End
  End
End
