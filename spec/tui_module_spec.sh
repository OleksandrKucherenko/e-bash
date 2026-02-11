#!/usr/bin/env bash
# shell: bash altsh=shellspec
# shellcheck shell=bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-02-11
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


eval "$(shellspec - -c) exit 1"

Include ".scripts/_tui.sh"

Describe "_tui.sh / module exports /"
  It "exposes cursor helpers"
    When call command -v cursor:position:row

    The status should be success
    The output should include "cursor:position:row"
  End

  It "exposes selector input"
    When call command -v input:selector

    The status should be success
    The output should include "input:selector"
  End

  It "exposes y/n validation"
    When call command -v validate:input:yn

    The status should be success
    The output should include "validate:input:yn"
  End

  It "exposes multiline internals"
    When call _input:ml:stream:fit-height 0

    The status should be success
    The output should eq "1"
  End
End

Describe "_tui.sh / key parser /"
  It "uses shared arrow key bindings"
    When call _tui:key:decode $'\E[A'

    The status should be success
    The output should eq "up"
  End

  It "uses shared home/end key bindings"
    When call _tui:key:decode $'\E[F'

    The status should be success
    The output should eq "end"
  End

  It "normalizes control keys"
    When call _tui:key:decode $'\x04'

    The status should be success
    The output should eq "ctrl_d"
  End

  It "keeps printable payload in normalized event"
    When call _tui:key:decode "x"

    The status should be success
    The output should eq $'char\tx'
  End

  It "splits normalized event into name and payload"
    When call _tui:key:event:data $'paste\tabc'

    The status should be success
    The output should eq "abc"
  End

  It "formats escaped ASCII key sequence"
    When call _tui:key:format:ascii $'\E[A'

    The status should be success
    The output should eq '\e[A'
  End

  It "prints ASCII in key description output"
    When call tui:key:describe $'\E[A'

    The status should be success
    The output should include "ASCII=\\e[A"
  End

  It "formats complex modifier sequence Ctrl+Alt+Shift+PageUp"
    When call _tui:key:format:human $'\E[5;8~'

    The status should be success
    The output should eq "Ctrl+Alt+Shift+PageUp"
  End

  It "maps Shift as a generic modifier (no left/right distinction)"
    When call _tui:key:modifier:name 2

    The status should be success
    The output should eq "Shift"
  End
End

Describe "_tui.sh / box drawing /"
  BeforeEach "_tui:box:reset"

  It "exposes box drawing API"
    When call command -v tui:box:draw

    The status should be success
    The output should include "tui:box:draw"
  End

  It "normalizes style aliases"
    When call _tui:box:style:normalize 3

    The status should be success
    The output should eq "single_h_double_v"
  End

  It "maps style + segment mask to box drawing glyph"
    When call _tui:box:char double 15

    The status should be success
    The output should eq "╬"
  End

  It "renders requested box frame at terminal position"
    When call tui:box:draw -x 2 -y 1 -w 4 -h 3 -s single

    The status should be success
    The stderr should include "[2;3H┌──┐"
    The stderr should include "[3;3H│  │"
    The stderr should include "[4;3H└──┘"
  End

  It "merges overlapping borders into junction symbols"
    tui:box:draw -x 0 -y 0 -w 6 -h 4 -s single >/dev/null 2>&1
    tui:box:draw -x 3 -y 0 -w 6 -h 4 -s single >/dev/null 2>&1

    When call _tui:box:cell:char 0 3

    The status should be success
    The output should eq "┬"
  End

  It "restores previous region after modal close"
    tui:box:draw -x 0 -y 0 -w 6 -h 4 -s single >/dev/null 2>&1
    local before_cell layer_id after_cell
    before_cell=$(_tui:box:cell:char 0 2)
    tui:box:open -x 2 -y 0 -w 5 -h 3 -s double >/dev/null 2>&1
    layer_id="$__TUI_BOX_LAST_LAYER"
    tui:box:close "$layer_id" >/dev/null 2>&1
    after_cell=$(_tui:box:cell:char 0 2)

    When call printf "%s|%s" "$before_cell" "$after_cell"

    The status should be success
    The output should eq "─|─"
  End
End
