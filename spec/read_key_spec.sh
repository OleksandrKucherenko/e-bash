#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2154

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-02-11
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

Describe "_commons.sh"
  # Source commons in a way that skips interactive initialization
  setup() {
    export __SOURCED__=1
    export E_BASH="${E_BASH:-$(cd "${SHELLSPEC_SPECDIR}/../.scripts" && pwd)}"
    source "$E_BASH/_commons.sh"
  }
  Before setup

  Describe "_input:read-key /"

    # Helper: feed bytes to _input:read-key via stdin
    # Usage: result=$(feed_key $'\x1b' '[' 'A')
    feed_key() {
      printf '%s' "$@" | _input:read-key
    }

    Describe "printable characters /"
      It "reads lowercase letter 'a'"
        When call feed_key "a"
        The output should eq "char:a"
      End

      It "reads uppercase letter 'Z'"
        When call feed_key "Z"
        The output should eq "char:Z"
      End

      It "reads digit '5'"
        When call feed_key "5"
        The output should eq "char:5"
      End

      It "reads special character '!'"
        When call feed_key "!"
        The output should eq "char:!"
      End

      It "reads space character"
        When call feed_key " "
        The output should eq "char: "
      End
    End

    Describe "control characters /"
      It "reads Enter (0x0a LF)"
        When call feed_key $'\x0a'
        The output should eq "enter"
      End

      It "reads Enter (0x0d CR)"
        When call feed_key $'\x0d'
        The output should eq "enter"
      End

      It "reads empty input as enter"
        When call feed_key ""
        The output should eq "enter"
      End

      It "reads Tab (0x09)"
        When call feed_key $'\x09'
        The output should eq "tab"
      End

      It "reads Backspace (0x7f DEL)"
        When call feed_key $'\x7f'
        The output should eq "backspace"
      End

      It "reads Backspace (0x08 BS)"
        When call feed_key $'\x08'
        The output should eq "backspace"
      End

      It "reads Ctrl+D (0x04)"
        When call feed_key $'\x04'
        The output should eq "ctrl-d"
      End

      It "reads Ctrl+U (0x15)"
        When call feed_key $'\x15'
        The output should eq "ctrl-u"
      End

      It "reads Ctrl+W (0x17)"
        When call feed_key $'\x17'
        The output should eq "ctrl-w"
      End

      It "reads Ctrl+V (0x16)"
        When call feed_key $'\x16'
        The output should eq "ctrl-v"
      End

      It "reads Ctrl+E (0x05)"
        When call feed_key $'\x05'
        The output should eq "ctrl-e"
      End

      It "reads Ctrl+A (0x01)"
        When call feed_key $'\x01'
        The output should eq "ctrl-a"
      End

      It "reads Ctrl+C (0x03)"
        When call feed_key $'\x03'
        The output should eq "ctrl-c"
      End

      It "reads Ctrl+Z (0x1a)"
        When call feed_key $'\x1a'
        The output should eq "ctrl-z"
      End

      # NUL (0x00) cannot survive through bash pipes/printf - it becomes empty.
      # In a real terminal with stty raw, NUL is delivered correctly.
      # We test the code path indirectly through the "00" case branch.
      It "reads NUL as enter (bash pipe limitation)"
        When call feed_key $'\x00'
        The output should eq "enter"
      End

      It "reads Ctrl+K (0x0b)"
        When call feed_key $'\x0b'
        The output should eq "ctrl-k"
      End

      It "reads Ctrl+L (0x0c)"
        When call feed_key $'\x0c'
        The output should eq "ctrl-l"
      End

      It "reads Ctrl+S (0x13)"
        When call feed_key $'\x13'
        The output should eq "ctrl-s"
      End
    End

    Describe "CSI arrow keys /"
      It "reads Up arrow (ESC [ A)"
        When call feed_key $'\x1b' "[A"
        The output should eq "up"
      End

      It "reads Down arrow (ESC [ B)"
        When call feed_key $'\x1b' "[B"
        The output should eq "down"
      End

      It "reads Right arrow (ESC [ C)"
        When call feed_key $'\x1b' "[C"
        The output should eq "right"
      End

      It "reads Left arrow (ESC [ D)"
        When call feed_key $'\x1b' "[D"
        The output should eq "left"
      End

      It "reads Home (ESC [ H)"
        When call feed_key $'\x1b' "[H"
        The output should eq "home"
      End

      It "reads End (ESC [ F)"
        When call feed_key $'\x1b' "[F"
        The output should eq "end"
      End
    End

    Describe "CSI tilde keys /"
      It "reads Page Up (ESC [ 5 ~)"
        When call feed_key $'\x1b' "[5~"
        The output should eq "page-up"
      End

      It "reads Page Down (ESC [ 6 ~)"
        When call feed_key $'\x1b' "[6~"
        The output should eq "page-down"
      End

      It "reads Insert (ESC [ 2 ~)"
        When call feed_key $'\x1b' "[2~"
        The output should eq "insert"
      End

      It "reads Delete (ESC [ 3 ~)"
        When call feed_key $'\x1b' "[3~"
        The output should eq "delete"
      End

      It "reads F5 (ESC [ 15 ~)"
        When call feed_key $'\x1b' "[15~"
        The output should eq "f5"
      End

      It "reads F12 (ESC [ 24 ~)"
        When call feed_key $'\x1b' "[24~"
        The output should eq "f12"
      End
    End

    Describe "CSI with modifiers /"
      It "reads Ctrl+Up (ESC [ 1;5 A)"
        When call feed_key $'\x1b' "[1;5A"
        The output should eq "ctrl-up"
      End

      It "reads Shift+Down (ESC [ 1;2 B)"
        When call feed_key $'\x1b' "[1;2B"
        The output should eq "shift-down"
      End

      It "reads Alt+Right (ESC [ 1;3 C)"
        When call feed_key $'\x1b' "[1;3C"
        The output should eq "alt-right"
      End

      It "reads Ctrl+Shift+Left (ESC [ 1;6 D)"
        When call feed_key $'\x1b' "[1;6D"
        The output should eq "ctrl-shift-left"
      End

      It "reads Ctrl+Alt+Up (ESC [ 1;7 A)"
        When call feed_key $'\x1b' "[1;7A"
        The output should eq "ctrl-alt-up"
      End

      It "reads Shift+Page Up (ESC [ 5;2 ~)"
        When call feed_key $'\x1b' "[5;2~"
        The output should eq "shift-page-up"
      End

      It "reads Ctrl+Page Down (ESC [ 6;5 ~)"
        When call feed_key $'\x1b' "[6;5~"
        The output should eq "ctrl-page-down"
      End

      It "reads Shift+F5 (ESC [ 15;2 ~)"
        When call feed_key $'\x1b' "[15;2~"
        The output should eq "shift-f5"
      End

      It "reads Ctrl+Home (ESC [ 1;5 H)"
        When call feed_key $'\x1b' "[1;5H"
        The output should eq "ctrl-home"
      End

      It "reads Ctrl+Alt+Shift+Delete (ESC [ 3;8 ~)"
        When call feed_key $'\x1b' "[3;8~"
        The output should eq "ctrl-alt-shift-delete"
      End
    End

    Describe "SS3 sequences /"
      It "reads SS3 Up (ESC O A)"
        When call feed_key $'\x1b' "OA"
        The output should eq "up"
      End

      It "reads SS3 F1 (ESC O P)"
        When call feed_key $'\x1b' "OP"
        The output should eq "f1"
      End

      It "reads SS3 F4 (ESC O S)"
        When call feed_key $'\x1b' "OS"
        The output should eq "f4"
      End
    End

    Describe "Alt+key combinations /"
      It "reads Alt+a (ESC a)"
        When call feed_key $'\x1b' "a"
        The output should eq "alt-a"
      End

      It "reads Alt+x (ESC x)"
        When call feed_key $'\x1b' "x"
        The output should eq "alt-x"
      End
    End

    Describe "--raw mode /"
      # --raw sets global vars; must run in current shell (not subshell/pipe)

      It "sets __INPUT_RAW_BYTES for printable char"
        _input:read-key --raw <<< "a" >/dev/null

        The variable __INPUT_RAW_BYTES should eq "61"
      End

      It "sets __INPUT_RAW_BYTES for Ctrl+D"
        _input:read-key --raw < <(printf '\x04') >/dev/null

        The variable __INPUT_RAW_BYTES should eq "04"
      End

      It "sets __INPUT_RAW_BYTES for arrow key"
        _input:read-key --raw < <(printf '\x1b[A') >/dev/null

        The variable __INPUT_RAW_BYTES should eq "1b5b41"
      End

      It "sets __INPUT_RAW_BYTES for Ctrl+Up"
        _input:read-key --raw < <(printf '\x1b[1;5A') >/dev/null

        The variable __INPUT_RAW_BYTES should eq "1b5b313b3541"
      End
    End

    Describe "bracketed paste /"
      It "detects single-line bracketed paste"
        When call feed_key $'\x1b' "[200~Hello World" $'\x1b' "[201~"
        The output should eq "paste:Hello World"
      End

      It "detects multi-line bracketed paste"
        feed_multiline_paste() {
          printf '%s' $'\x1b[200~'"Line1
Line2
Line3"$'\x1b[201~' | _input:read-key
        }
        When call feed_multiline_paste
        The line 1 of output should eq "paste:Line1"
        The line 2 of output should eq "Line2"
        The line 3 of output should eq "Line3"
      End

      It "detects empty bracketed paste"
        When call feed_key $'\x1b' "[200~" $'\x1b' "[201~"
        The output should eq "paste:"
      End
    End

    Describe "token consistency /"
      # Verify the tokens match what input:multi-line and others expect
      It "all ctrl keys return ctrl-{letter} format"
        local results=""
        for byte in 01 02 03 04 05 06 07 0b 0c 0e 0f 10 11 12 13 14 15 16 17 18 19 1a; do
          local result
          result=$(printf "\\x${byte}" | _input:read-key)
          # All should start with "ctrl-"
          [[ "$result" == ctrl-* ]] || results+="$byte:$result "
        done
        The variable results should eq ""
      End

      It "backspace variants both return 'backspace'"
        local r1 r2
        r1=$(printf '\x7f' | _input:read-key)
        r2=$(printf '\x08' | _input:read-key)
        The variable r1 should eq "backspace"
        The variable r2 should eq "backspace"
      End

      It "enter variants all return 'enter'"
        local r1 r2 r3
        r1=$(printf '\x0a' | _input:read-key)
        r2=$(printf '\x0d' | _input:read-key)
        r3=$(printf '' | _input:read-key)
        The variable r1 should eq "enter"
        The variable r2 should eq "enter"
        The variable r3 should eq "enter"
      End
    End

  End

  Describe "_input:_raw helper /"
    setup() {
      export __SOURCED__=1
      export E_BASH="${E_BASH:-$(cd "${SHELLSPEC_SPECDIR}/../.scripts" && pwd)}"
      source "$E_BASH/_commons.sh"
    }
    Before setup

    It "sets globals when use_raw is true"
      _input:_raw "true" "41" "A"

      The variable __INPUT_RAW_BYTES should eq "41"
      The variable __INPUT_RAW_CHARS should eq "A"
    End

    It "does nothing when use_raw is false"
      __INPUT_RAW_BYTES="unchanged"
      _input:_raw "false" "41" "A"

      The variable __INPUT_RAW_BYTES should eq "unchanged"
    End
  End
End
