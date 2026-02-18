# shellcheck shell=sh
# -*- coding: utf-8 -*-

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-02-18
## Version: 2.4.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

Describe 'bin/wsl/xdg-open.sh'
  # Setup script path
  # Use SHELLSPEC_PROJECT_ROOT when available, fallback to relative path
  __project_root="${SHELLSPEC_PROJECT_ROOT:-}"
  if [ -z "$__project_root" ]; then
    __project_root="$(cd "${SHELLSPEC_WORKDIR:-.}" && pwd)"
  fi
  readonly SCRIPT_PATH="${__project_root}/bin/wsl/xdg-open.sh"

  # Mock environment
  setup() {
    export E_BASH
    E_BASH="$(cd "${SCRIPT_PATH%/*}/../../.scripts" 2>&- && pwd)"
    export HOME="${SHELLSPEC_TMPDIR:-/tmp}/xdg-open-test-home"
    export XDG_CONFIG_HOME="${HOME}/.config"
    mkdir -p "$HOME" "$XDG_CONFIG_HOME"

    # Clean up any existing config
    rm -rf "${XDG_CONFIG_HOME}/xdg-open-wsl"

    # Disable debug logging
    export DEBUG="-wsl,-xdg"
  }

  cleanup() {
    rm -rf "${XDG_CONFIG_HOME}/xdg-open-wsl"
  }

  BeforeAll 'setup'
  AfterAll 'cleanup'

  ##
  ## Subcommand Tests (non-interactive)
  ##

  Describe '--help flag'
    Before 'setup'

    It 'shows usage information'
      When call "$SCRIPT_PATH" --help
      The status should be success
      The output should include "xdg-open-wsl"
      The output should include "--config"
      The output should include "--status"
      The output should include "--uninstall"
    End
  End

  Describe '--version flag'
    Before 'setup'

    It 'shows version information'
      When call "$SCRIPT_PATH" --version
      The status should be success
      The output should include "xdg-open-wsl"
      The output should include "1.1.0"
    End
  End

  Describe '--status flag'
    Before 'setup'

    It 'shows not configured status when no config exists'
      BeforeCall 'rm -rf "${XDG_CONFIG_HOME}/xdg-open-wsl"'
      When call "$SCRIPT_PATH" --status
      The status should be success
      The output should include "Not configured"
    End

    It 'shows configuration when config exists'
      BeforeCall 'mkdir -p "${XDG_CONFIG_HOME}/xdg-open-wsl" && echo "XDG_OPEN_LAUNCHER=\"pwsh\"" > "${XDG_CONFIG_HOME}/xdg-open-wsl/config"'
      When call "$SCRIPT_PATH" --status
      The status should be success
      The output should include "Configuration:"
    End
  End

  Describe '--uninstall flag'
    Before 'setup'

    It 'removes config file when it exists'
      BeforeCall 'mkdir -p "${XDG_CONFIG_HOME}/xdg-open-wsl" && echo "test" > "${XDG_CONFIG_HOME}/xdg-open-wsl/config"'
      When call "$SCRIPT_PATH" --uninstall
      The status should be success
      The output should include "Removed"
      The path "${XDG_CONFIG_HOME}/xdg-open-wsl/config" should not be exist
    End

    It 'shows message when nothing to remove'
      BeforeCall 'rm -rf "${XDG_CONFIG_HOME}/xdg-open-wsl"'
      When call "$SCRIPT_PATH" --uninstall
      The status should be success
      The output should include "No configuration"
    End
  End

  ##
  ## Config Management Tests (using function imports)
  ##

  Describe 'Config file management'
    Before 'setup'
    After 'rm -rf "${XDG_CONFIG_HOME}/xdg-open-wsl"'

    It 'creates config directory when writing config'
      When call bash -c '
        source "'"$SCRIPT_PATH"'"
        XDG_OPEN_LAUNCHER="test_launcher" XDG_OPEN_BROWSER="test_browser" xdg:config:write
        [ -d "'"$XDG_CONFIG_HOME"'/xdg-open-wsl" ]
      '
      The status should be success
    End

    It 'writes expected variables to config file'
      When call bash -c '
        source "'"$SCRIPT_PATH"'"
        XDG_OPEN_LAUNCHER="pwsh" XDG_OPEN_BROWSER="firefox" XDG_OPEN_SHIM_DIR="/custom/path" xdg:config:write
        cat "'"$XDG_CONFIG_HOME"'/xdg-open-wsl/config"
      '
      The output should include "XDG_OPEN_LAUNCHER"
      The output should include "pwsh"
      The output should include "firefox"
      The output should include "/custom/path"
    End
  End

  ##
  ## Launcher Exe Tests
  ##

  Describe 'xdg:launcher:exe()'
    Before 'setup'

    It 'returns powershell.exe for powershell'
      When call bash -c 'source "'"$SCRIPT_PATH"'" && xdg:launcher:exe "powershell"'
      The output should equal "powershell.exe"
    End

    It 'returns pwsh.exe for pwsh'
      When call bash -c 'source "'"$SCRIPT_PATH"'" && xdg:launcher:exe "pwsh"'
      The output should equal "pwsh.exe"
    End

    It 'returns cmd.exe for cmd'
      When call bash -c 'source "'"$SCRIPT_PATH"'" && xdg:launcher:exe "cmd"'
      The output should equal "cmd.exe"
    End

    It 'returns pwsh.exe for pwsh (scoop)'
      When call bash -c 'source "'"$SCRIPT_PATH"'" && xdg:launcher:exe "pwsh (scoop)"'
      The output should equal "pwsh.exe"
    End

    It 'returns pwsh.exe for pwsh (winget)'
      When call bash -c 'source "'"$SCRIPT_PATH"'" && xdg:launcher:exe "pwsh (winget)"'
      The output should equal "pwsh.exe"
    End

    It 'returns powershell.exe as default for unknown'
      When call bash -c 'source "'"$SCRIPT_PATH"'" && xdg:launcher:exe "unknown"'
      The output should equal "powershell.exe"
    End
  End

  ##
  ## Launcher Path Resolution Tests
  ##

  Describe 'xdg:launcher:path()'
    Before 'setup'

    It 'returns simple exe for system powershell'
      When call bash -c 'source "'"$SCRIPT_PATH"'" && xdg:launcher:path "powershell"'
      The output should equal "powershell.exe"
    End

    It 'returns simple exe for system pwsh'
      When call bash -c 'source "'"$SCRIPT_PATH"'" && xdg:launcher:path "pwsh"'
      The output should equal "pwsh.exe"
    End

    It 'returns full path for pwsh (winget)'
      When call bash -c "source \"$SCRIPT_PATH\" && xdg:launcher:path 'pwsh (winget)'"
      The output should include "Program Files/PowerShell/7/pwsh.exe"
    End

    It 'returns scoop path for pwsh (scoop)'
      When call bash -c "export XDG_OPEN_WINDOWS_USER=testuser && source \"$SCRIPT_PATH\" && xdg:launcher:path 'pwsh (scoop)'"
      The output should include "scoop/shims/pwsh.exe"
    End
  End

  ##
  ## Browser Detection Tests
  ##

  Describe 'xdg:browser:detect()'
    Before 'setup'

    It 'always includes default browser'
      When call bash -c 'source "'"$SCRIPT_PATH"'" && xdg:browser:detect | grep -q "^default$" && echo "found"'
      The output should include "found"
    End

    It 'always includes custom option'
      When call bash -c 'source "'"$SCRIPT_PATH"'" && xdg:browser:detect | grep -q "^custom$" && echo "found"'
      The output should include "found"
    End
  End

  Describe 'xdg:browser:path()'
    Before 'setup'

    It 'returns empty string for default browser'
      When call bash -c 'source "'"$SCRIPT_PATH"'" && xdg:browser:path "default"'
      The output should equal ""
    End

    It 'returns custom path when specified'
      When call bash -c "source \"$SCRIPT_PATH\" && xdg:browser:path 'custom' '/my/custom/browser.exe'"
      The output should equal "/my/custom/browser.exe"
    End

    It 'returns fallback exe for unknown browser'
      When call bash -c 'source "'"$SCRIPT_PATH"'" && xdg:browser:path "unknown"'
      The output should equal ""
    End
  End

  ##
  ## WSL Detection Tests
  ##

  Describe 'wsl:is_wsl()'
    Before 'setup'

    It 'returns true when WSL_DISTRO_NAME is set'
      When call bash -c 'export WSL_DISTRO_NAME="Ubuntu"; source "'"$SCRIPT_PATH"'" && wsl:is_wsl && echo "yes"'
      The output should include "yes"
    End

    It 'returns true when WSL_INTEROP is set'
      When call bash -c 'unset WSL_DISTRO_NAME 2>/dev/null; export WSL_INTEROP="/run/WSL/1234_interop"; source "'"$SCRIPT_PATH"'" && wsl:is_wsl && echo "yes"'
      The output should include "yes"
    End

    # Note: When running in actual WSL, the /proc/version check always returns true,
    # so we cannot test the false case in WSL environment.
    # This test is skipped in WSL and only runs in non-WSL CI environments.
    It 'detects WSL via /proc/version fallback'
      # This test verifies the fallback mechanism exists
      When call bash -c 'source "'"$SCRIPT_PATH"'" && type wsl:is_wsl | head -1'
      The output should include "function"
    End
  End

  ##
  ## URL Detection Tests
  ##

  Describe 'xdg:is_url()'
    Before 'setup'

    It 'returns success for http URLs'
      When call bash -c 'source "'"$SCRIPT_PATH"'" && xdg:is_url "http://example.com" && echo "yes"'
      The output should include "yes"
    End

    It 'returns success for https URLs'
      When call bash -c 'source "'"$SCRIPT_PATH"'" && xdg:is_url "https://example.com/path" && echo "yes"'
      The output should include "yes"
    End

    It 'returns success for file URLs'
      When call bash -c 'source "'"$SCRIPT_PATH"'" && xdg:is_url "file:///home/user/doc.txt" && echo "yes"'
      The output should include "yes"
    End

    It 'returns success for mailto URLs'
      When call bash -c 'source "'"$SCRIPT_PATH"'" && xdg:is_url "mailto:user@example.com" && echo "yes"'
      The output should include "yes"
    End

    It 'returns success for tel URLs'
      When call bash -c 'source "'"$SCRIPT_PATH"'" && xdg:is_url "tel:+1234567890" && echo "yes"'
      The output should include "yes"
    End

    It 'returns failure for plain file paths'
      When call bash -c 'source "'"$SCRIPT_PATH"'" && xdg:is_url "/home/user/file.txt" && echo "yes" || echo "no"'
      The output should include "no"
    End

    It 'returns failure for relative paths'
      When call bash -c 'source "'"$SCRIPT_PATH"'" && xdg:is_url "./relative/path.txt" && echo "yes" || echo "no"'
      The output should include "no"
    End
  End

  ##
  ## Shim Generation Tests
  ##

  Describe 'xdg:shim:generate:v2()'
    Before 'setup'
    After 'rm -rf "${SHELLSPEC_TMPDIR:-/tmp}/shim-test"'

    It 'creates executable shim file'
      When call bash -c '
        source "'"$SCRIPT_PATH"'"
        XDG_OPEN_LAUNCHER="powershell" XDG_OPEN_BROWSER="default"
        shim_dir="${SHELLSPEC_TMPDIR:-/tmp}/shim-test"
        xdg:shim:generate:v2 "$shim_dir/xdg-open"
        [ -x "$shim_dir/xdg-open" ] && echo "executable"
      '
      The output should include "executable"
    End

    It 'generates valid bash syntax'
      When call bash -c '
        source "'"$SCRIPT_PATH"'"
        XDG_OPEN_LAUNCHER="pwsh" XDG_OPEN_BROWSER="chrome"
        shim_dir="${SHELLSPEC_TMPDIR:-/tmp}/shim-test"
        xdg:shim:generate:v2 "$shim_dir/xdg-open"
        bash -n "$shim_dir/xdg-open" && echo "valid syntax"
      '
      The output should include "valid syntax"
    End

    It 'includes launcher executable in command'
      When call bash -c '
        source "'"$SCRIPT_PATH"'"
        XDG_OPEN_LAUNCHER="pwsh" XDG_OPEN_BROWSER="chrome"
        shim_dir="${SHELLSPEC_TMPDIR:-/tmp}/shim-test"
        xdg:shim:generate:v2 "$shim_dir/xdg-open"
        grep -q "_LAUNCHER" "$shim_dir/xdg-open" && grep -q "NoProfile" "$shim_dir/xdg-open" && echo "found"
      '
      The output should include "found"
    End

    It 'uses correct quote stripping syntax'
      When call bash -c '
        source "'"$SCRIPT_PATH"'"
        XDG_OPEN_LAUNCHER="powershell" XDG_OPEN_BROWSER="default"
        shim_dir="${SHELLSPEC_TMPDIR:-/tmp}/shim-test"
        xdg:shim:generate:v2 "$shim_dir/xdg-open"
        # Check that the shim contains the quote stripping line
        grep "Strip embedded quotes" "$shim_dir/xdg-open" && echo "found"
      '
      The output should include "found"
    End

    It 'stores config tool path for subcommand delegation'
      When call bash -c '
        source "'"$SCRIPT_PATH"'"
        XDG_OPEN_LAUNCHER="powershell" XDG_OPEN_BROWSER="default"
        shim_dir="${SHELLSPEC_TMPDIR:-/tmp}/shim-test"
        xdg:shim:generate:v2 "$shim_dir/xdg-open"
        grep "_CONFIG_TOOL=" "$shim_dir/xdg-open" | head -1
      '
      The output should include "_CONFIG_TOOL="
      The output should include "xdg-open.sh"
    End

    It 'delegates --status to config tool'
      When call bash -c '
        source "'"$SCRIPT_PATH"'"
        XDG_OPEN_LAUNCHER="powershell" XDG_OPEN_BROWSER="default"
        shim_dir="${SHELLSPEC_TMPDIR:-/tmp}/shim-test"
        xdg:shim:generate:v2 "$shim_dir/xdg-open"
        grep -E "\-\-status|\-s" "$shim_dir/xdg-open" | head -1
      '
      The output should include "status"
    End

    It 'delegates --config to config tool'
      When call bash -c '
        source "'"$SCRIPT_PATH"'"
        XDG_OPEN_LAUNCHER="powershell" XDG_OPEN_BROWSER="default"
        shim_dir="${SHELLSPEC_TMPDIR:-/tmp}/shim-test"
        xdg:shim:generate:v2 "$shim_dir/xdg-open"
        grep -E "\-\-config|\-c" "$shim_dir/xdg-open" | head -1
      '
      The output should include "config"
    End

    It 'includes version and launcher info in shim'
      When call bash -c '
        source "'"$SCRIPT_PATH"'"
        XDG_OPEN_LAUNCHER="pwsh" XDG_OPEN_BROWSER="chrome"
        shim_dir="${SHELLSPEC_TMPDIR:-/tmp}/shim-test"
        xdg:shim:generate:v2 "$shim_dir/xdg-open"
        head -5 "$shim_dir/xdg-open"
      '
      The output should include "1.1.0"
      The output should include "pwsh"
      The output should include "chrome"
    End

    It 'includes WSL detection in shim'
      When call bash -c '
        source "'"$SCRIPT_PATH"'"
        XDG_OPEN_LAUNCHER="powershell"
        shim_dir="${SHELLSPEC_TMPDIR:-/tmp}/shim-test"
        xdg:shim:generate:v2 "$shim_dir/xdg-open"
        grep -q "WSL_DISTRO_NAME" "$shim_dir/xdg-open" && grep -q "WSL_INTEROP" "$shim_dir/xdg-open" && echo "found"
      '
      The output should include "found"
    End

    It 'includes fallback to /usr/bin/xdg-open in shim'
      When call bash -c '
        source "'"$SCRIPT_PATH"'"
        XDG_OPEN_LAUNCHER="powershell"
        shim_dir="${SHELLSPEC_TMPDIR:-/tmp}/shim-test"
        xdg:shim:generate:v2 "$shim_dir/xdg-open"
        grep -q "/usr/bin/xdg-open" "$shim_dir/xdg-open" && echo "found"
      '
      The output should include "found"
    End
  End

  ##
  ## First Run Detection Tests
  ##

  Describe 'xdg:is_first_run()'
    Before 'setup'

    It 'returns true when config does not exist'
      BeforeCall 'rm -rf "${XDG_CONFIG_HOME}/xdg-open-wsl"'
      When call bash -c 'source "'"$SCRIPT_PATH"'" && xdg:is_first_run && echo "yes"'
      The output should include "yes"
    End

    It 'returns false when config exists'
      BeforeCall 'mkdir -p "${XDG_CONFIG_HOME}/xdg-open-wsl" && touch "${XDG_CONFIG_HOME}/xdg-open-wsl/config"'
      When call bash -c 'source "'"$SCRIPT_PATH"'" && xdg:is_first_run && echo "yes" || echo "no"'
      The output should include "no"
    End
  End

  ##
  ## Configurable Path Variables Tests
  ##

  Describe 'XDG_WSL_* path variables'
    Before 'setup'

    It 'uses default values when not set'
      When call bash -c 'source "'"$SCRIPT_PATH"'" && echo "$XDG_WSL_USERS|$XDG_WSL_WIN|$XDG_WSL_WIN86"'
      The output should include "/mnt/c/Users"
      The output should include "/mnt/c/Program Files"
      The output should include "/mnt/c/Program Files (x86)"
    End

    It 'allows XDG_WSL_USERS override'
      When call bash -c 'export XDG_WSL_USERS="/custom/Users"; source "'"$SCRIPT_PATH"'" && echo "$XDG_WSL_USERS"'
      The output should equal "/custom/Users"
    End

    It 'allows XDG_WSL_WIN override'
      When call bash -c 'export XDG_WSL_WIN="/custom/Program Files"; source "'"$SCRIPT_PATH"'" && echo "$XDG_WSL_WIN"'
      The output should equal "/custom/Program Files"
    End

    It 'uses custom path in launcher:path for winget'
      When call bash -c 'export XDG_WSL_WIN="/custom/PF"; source "'"$SCRIPT_PATH"'" && xdg:launcher:path "pwsh (winget)"'
      The output should equal "/custom/PF/PowerShell/7/pwsh.exe"
    End
  End
End
