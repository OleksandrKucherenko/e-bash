#!/usr/bin/env bash
# shell: bash altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016,SC2288,SC2155,SC2329

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-02-12
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

Mock logger
  echo "$@"
End

Mock echo:Common
  echo "$@"
End

Mock echo:Loader
  :
End

Mock echo:Tui
  :
End

Mock logger:redirect
  :
End

Include ".scripts/_tui.sh"

Describe "_tui.sh / Module Loading"
  It "defines cursor:position function"
    When call type cursor:position
    The output should include "cursor:position is a function"
  End

  It "defines cursor:position:row function"
    When call type cursor:position:row
    The output should include "cursor:position:row is a function"
  End

  It "defines cursor:position:col function"
    When call type cursor:position:col
    The output should include "cursor:position:col is a function"
  End

  It "defines input:readpwd function"
    When call type input:readpwd
    The output should include "input:readpwd is a function"
  End

  It "defines input:multi-line function"
    When call type input:multi-line
    The output should include "input:multi-line is a function"
  End

  It "defines input:selector function"
    When call type input:selector
    The output should include "input:selector is a function"
  End

  It "defines validate:input function"
    When call type validate:input
    The output should include "validate:input is a function"
  End

  It "defines validate:input:masked function"
    When call type validate:input:masked
    The output should include "validate:input:masked is a function"
  End

  It "defines validate:input:yn function"
    When call type validate:input:yn
    The output should include "validate:input:yn is a function"
  End

  It "defines confirm:by:input function"
    When call type confirm:by:input
    The output should include "confirm:by:input is a function"
  End

  It "defines _input:read-key function"
    When call type _input:read-key
    The output should include "_input:read-key is a function"
  End

  It "defines _input:capture-key function"
    When call type _input:capture-key
    The output should include "_input:capture-key is a function"
  End
End

Describe "_tui.sh / Global Data Tables"
  It "defines __INPUT_MODIFIER_NAMES associative array"
    The variable __INPUT_MODIFIER_NAMES[5] should eq "ctrl"
  End

  It "defines __INPUT_CSI_KEYS associative array"
    The variable __INPUT_CSI_KEYS[A] should eq "up"
  End

  It "defines __INPUT_CSI_TILDE_KEYS associative array"
    The variable __INPUT_CSI_TILDE_KEYS[5] should eq "page-up"
  End

  It "defines multi-line editor state variables"
    The variable __ML_WIDTH should be present
    The variable __ML_HEIGHT should be present
    The variable __ML_ROW should be present
    The variable __ML_COL should be present
  End
End

Describe "_tui.sh / input:multi-line /"
  # remove colors in output
  Before "unset cl_red cl_green cl_blue cl_purple cl_yellow cl_reset cl_grey cl_selected"
  Before 'export DEBUG="*"'

  Describe "_input:ml:init /"
    It "initializes state with default dimensions"
      _input:ml:init 80 24

      The variable __ML_WIDTH should eq 80
      The variable __ML_HEIGHT should eq 24
      The variable __ML_ROW should eq 0
      The variable __ML_COL should eq 0
      The variable __ML_SCROLL should eq 0
    End

    It "initializes lines array with single empty line"
      _input:ml:init 40 10

      The variable __ML_LINES[0] should eq ""
    End
  End

  Describe "_input:ml:insert-char /"
    setup() {
      _input:ml:init 80 24
    }
    Before setup

    It "inserts character at beginning of empty line"
      _input:ml:insert-char "a"

      The variable __ML_LINES[0] should eq "a"
      The variable __ML_COL should eq 1
    End

    It "inserts multiple characters sequentially"
      _input:ml:insert-char "H"
      _input:ml:insert-char "i"

      The variable __ML_LINES[0] should eq "Hi"
      The variable __ML_COL should eq 2
    End

    It "inserts character in the middle of a line"
      __ML_LINES[0]="Hllo"
      __ML_COL=1

      _input:ml:insert-char "e"

      The variable __ML_LINES[0] should eq "Hello"
      The variable __ML_COL should eq 2
    End

    It "inserts character at the end of a line"
      __ML_LINES[0]="Hello"
      __ML_COL=5

      _input:ml:insert-char "!"

      The variable __ML_LINES[0] should eq "Hello!"
      The variable __ML_COL should eq 6
    End
  End

  Describe "_input:ml:delete-char /"
    setup() {
      _input:ml:init 80 24
    }
    Before setup

    It "deletes character before cursor (backspace)"
      __ML_LINES[0]="Hello"
      __ML_COL=5

      _input:ml:delete-char

      The variable __ML_LINES[0] should eq "Hell"
      The variable __ML_COL should eq 4
    End

    It "deletes character in the middle"
      __ML_LINES[0]="Hello"
      __ML_COL=3

      _input:ml:delete-char

      The variable __ML_LINES[0] should eq "Helo"
      The variable __ML_COL should eq 2
    End

    It "does nothing at beginning of first line"
      __ML_LINES[0]="Hello"
      __ML_COL=0

      _input:ml:delete-char

      The variable __ML_LINES[0] should eq "Hello"
      The variable __ML_COL should eq 0
    End

    It "joins with previous line when at column 0"
      __ML_LINES=("First" "Second")
      __ML_ROW=1
      __ML_COL=0

      _input:ml:delete-char

      The variable __ML_LINES[0] should eq "FirstSecond"
      The variable __ML_ROW should eq 0
      The variable __ML_COL should eq 5
    End
  End

  Describe "_input:ml:delete-char-forward /"
    setup() {
      _input:ml:init 80 24
    }
    Before setup

    It "deletes character at cursor position"
      __ML_LINES[0]="Hello World"
      __ML_COL=5

      _input:ml:delete-char-forward

      The variable __ML_LINES[0] should eq "HelloWorld"
      The variable __ML_COL should eq 5
    End

    It "joins with next line at end of line"
      __ML_LINES=("Hello" "World")
      __ML_COL=5

      _input:ml:delete-char-forward

      The variable __ML_LINES[0] should eq "HelloWorld"
    End

    It "does nothing at end of last line"
      __ML_LINES=("Hello")
      __ML_COL=5

      _input:ml:delete-char-forward

      The variable __ML_LINES[0] should eq "Hello"
      The variable __ML_COL should eq 5
    End

    It "deletes selection when active"
      __ML_LINES=("Hello World")
      __ML_SEL_ACTIVE=true
      __ML_SEL_ANCHOR_ROW=0
      __ML_SEL_ANCHOR_COL=0
      __ML_ROW=0
      __ML_COL=5

      _input:ml:delete-char-forward

      The variable __ML_LINES[0] should eq " World"
      The variable __ML_SEL_ACTIVE should eq "false"
    End
  End

  Describe "_input:ml:delete-word /"
    setup() {
      _input:ml:init 80 24
    }
    Before setup

    It "deletes word backward"
      __ML_LINES[0]="hello world"
      __ML_COL=11

      _input:ml:delete-word

      The variable __ML_LINES[0] should eq "hello "
      The variable __ML_COL should eq 6
    End

    It "deletes trailing spaces then word"
      __ML_LINES[0]="hello world   "
      __ML_COL=14

      _input:ml:delete-word

      The variable __ML_LINES[0] should eq "hello "
      The variable __ML_COL should eq 6
    End

    It "does nothing at beginning of line"
      __ML_LINES[0]="hello world"
      __ML_COL=0

      _input:ml:delete-word

      The variable __ML_LINES[0] should eq "hello world"
      The variable __ML_COL should eq 0
    End
  End

  Describe "_input:ml:insert-newline /"
    setup() {
      _input:ml:init 80 24
    }
    Before setup

    It "splits line at cursor position"
      __ML_LINES[0]="hello world"
      __ML_COL=5

      _input:ml:insert-newline

      The variable __ML_LINES[0] should eq "hello"
      The variable __ML_LINES[1] should eq " world"
      The variable __ML_ROW should eq 1
      The variable __ML_COL should eq 0
    End

    It "creates new empty line when cursor at end"
      __ML_LINES[0]="hello"
      __ML_COL=5

      _input:ml:insert-newline

      The variable __ML_LINES[0] should eq "hello"
      The variable __ML_LINES[1] should eq ""
    End

    It "pushes existing line content to new line when cursor at beginning"
      __ML_LINES[0]="hello"
      __ML_COL=0

      _input:ml:insert-newline

      The variable __ML_LINES[0] should eq ""
      The variable __ML_LINES[1] should eq "hello"
    End
  End

  Describe "_input:ml:move-up /"
    setup() {
      _input:ml:init 80 24
    }
    Before setup

    It "moves cursor up one line"
      __ML_LINES=("line1" "line2" "line3")
      __ML_ROW=2
      __ML_COL=3

      _input:ml:move-up

      The variable __ML_ROW should eq 1
    End

    It "does nothing at top line"
      __ML_LINES=("line1" "line2" "line3")
      __ML_ROW=0
      __ML_COL=3

      _input:ml:move-up

      The variable __ML_ROW should eq 0
    End

    It "clamps column to target line length"
      # Move from longer line to shorter line - column should clamp
      __ML_LINES=("hi" "hello")  # line 0 is "hi" (2 chars), line 1 is "hello" (5 chars)
      __ML_ROW=1
      __ML_COL=5

      _input:ml:move-up

      The variable __ML_ROW should eq 0
      The variable __ML_COL should eq 2  # clamped to length of "hi"
    End
  End

  Describe "_input:ml:move-down /"
    setup() {
      _input:ml:init 80 24
    }
    Before setup

    It "moves cursor down one line"
      __ML_LINES=("line1" "line2" "line3")
      __ML_ROW=0
      __ML_COL=3

      _input:ml:move-down

      The variable __ML_ROW should eq 1
    End

    It "does nothing at last line"
      __ML_LINES=("line1" "line2" "line3")
      __ML_ROW=2
      __ML_COL=3

      _input:ml:move-down

      The variable __ML_ROW should eq 2
    End
  End

  Describe "_input:ml:move-left /"
    setup() {
      _input:ml:init 80 24
    }
    Before setup

    It "moves cursor left one column"
      __ML_LINES[0]="hello"
      __ML_COL=3

      _input:ml:move-left

      The variable __ML_COL should eq 2
    End

    It "does nothing at column 0"
      __ML_LINES[0]="hello"
      __ML_COL=0

      _input:ml:move-left

      The variable __ML_COL should eq 0
    End
  End

  Describe "_input:ml:move-right /"
    setup() {
      _input:ml:init 80 24
    }
    Before setup

    It "moves cursor right one column"
      __ML_LINES[0]="hello"
      __ML_COL=2

      _input:ml:move-right

      The variable __ML_COL should eq 3
    End

    It "does nothing at end of line"
      __ML_LINES[0]="hello"
      __ML_COL=5

      _input:ml:move-right

      The variable __ML_COL should eq 5
    End
  End

  Describe "_input:ml:move-home /"
    It "moves cursor to beginning of line"
      __ML_COL=5

      _input:ml:move-home

      The variable __ML_COL should eq 0
    End
  End

  Describe "_input:ml:move-end /"
    setup() {
      _input:ml:init 80 24
    }
    Before setup

    It "moves cursor to end of line"
      __ML_LINES[0]="hello"
      __ML_COL=0

      _input:ml:move-end

      The variable __ML_COL should eq 5
    End
  End

  Describe "_input:ml:scroll /"
    setup() {
      _input:ml:init 80 10
      __ML_STATUS_BAR=true
    }
    Before setup

    It "scrolls down when cursor moves below visible area"
      __ML_ROW=15

      _input:ml:scroll

      The variable __ML_SCROLL should eq 7
    End

    It "scrolls up when cursor moves above visible area"
      __ML_ROW=3
      __ML_SCROLL=5

      _input:ml:scroll

      The variable __ML_SCROLL should eq 3
    End

    It "keeps scroll at 0 when cursor in visible area"
      __ML_ROW=5
      __ML_SCROLL=0

      _input:ml:scroll

      The variable __ML_SCROLL should eq 0
    End
  End

  Describe "_input:ml:get-content /"
    setup() {
      _input:ml:init 80 24
      __ML_LINES=("line1" "line2" "line3")
    }
    Before setup

    It "returns all lines joined by newlines"
      When call _input:ml:get-content

      The output should include "line1"
      The output should include "line2"
      The output should include "line3"
    End
  End

  Describe "_input:ml:stream:fit-height /"
    It "returns valid height for positive input"
      When call _input:ml:stream:fit-height 10

      The output should eq 10
    End

    It "returns 1 for zero input"
      When call _input:ml:stream:fit-height 0

      The output should eq 1
    End

    It "returns 1 for negative input"
      When call _input:ml:stream:fit-height -5

      The output should eq 1
    End

    It "handles non-numeric input"
      When call _input:ml:stream:fit-height "invalid"

      The output should eq 1
    End
  End

  Describe "_input:ml:stream:allocate /"
    It "returns adjusted row when no overflow"
      When call _input:ml:stream:allocate 5 10 24

      The output should eq 5
    End

    It "scrolls terminal when overflow occurs"
      # When cursor at row 20 with 10 lines and terminal height 24
      # overflow = 20 + 10 - 24 - 1 = 5
      # adjusted = 20 - 5 = 15
      When call _input:ml:stream:allocate 20 10 24

      The output should eq 15
    End

    It "handles edge case at terminal bottom"
      When call _input:ml:stream:allocate 14 10 24

      The output should eq 14
    End
  End

  Describe "_input:ml:stream:restore /"
    It "outputs cursor positioning escape sequence"
      When call _input:ml:stream:restore 10 5

      The stderr should eq $'\033[10;5H'
    End

    It "handles default column"
      When call _input:ml:stream:restore 5

      The stderr should eq $'\033[5;1H'
    End

    It "clamps invalid values to 1"
      When call _input:ml:stream:restore 0 0

      The stderr should eq $'\033[1;1H'
    End
  End

  Describe "_input:ml:delete-line /"
    setup() {
      _input:ml:init 80 24
    }
    Before setup

    It "clears current line content"
      __ML_LINES[0]="hello world"
      __ML_COL=5

      _input:ml:delete-line

      The variable __ML_LINES[0] should eq ""
      The variable __ML_COL should eq 0
    End
  End

  Describe "_input:ml:insert-tab /"
    setup() {
      _input:ml:init 80 24
    }
    Before setup

    It "inserts two spaces for tab"
      __ML_LINES[0]="hello"
      __ML_COL=0

      _input:ml:insert-tab

      The variable __ML_LINES[0] should eq "  hello"
      The variable __ML_COL should eq 2
    End
  End

  Describe "_input:ml:paste /"
    setup() {
      _input:ml:init 80 24
    }
    Before setup

    It "pastes single-line text at cursor position"
      __ML_LINES[0]="start end"
      __ML_COL=5

      _input:ml:paste "INSERTED"

      The variable __ML_LINES[0] should eq "startINSERTED end"
      The variable __ML_COL should eq 13
    End

    It "pastes multi-line text"
      __ML_LINES[0]="start"
      __ML_COL=5

      _input:ml:paste $'A\nB'

      The variable __ML_LINES[0] should eq "startA"
      The variable __ML_LINES[1] should eq "B"
    End
  End

  Describe "_input:ml:sel-start /"
    setup() {
      _input:ml:init 80 24
    }
    Before setup

    It "activates selection and sets anchor to cursor position"
      __ML_ROW=2
      __ML_COL=5

      _input:ml:sel-start

      The variable __ML_SEL_ACTIVE should eq "true"
      The variable __ML_SEL_ANCHOR_ROW should eq 2
      The variable __ML_SEL_ANCHOR_COL should eq 5
    End

    It "does not move anchor when called again"
      __ML_ROW=2
      __ML_COL=5
      _input:ml:sel-start

      __ML_ROW=3
      __ML_COL=10
      _input:ml:sel-start

      The variable __ML_SEL_ANCHOR_ROW should eq 2
      The variable __ML_SEL_ANCHOR_COL should eq 5
    End
  End

  Describe "_input:ml:sel-clear /"
    setup() {
      _input:ml:init 80 24
    }
    Before setup

    It "deactivates selection"
      __ML_SEL_ACTIVE=true
      __ML_SEL_ANCHOR_ROW=1
      __ML_SEL_ANCHOR_COL=3

      _input:ml:sel-clear

      The variable __ML_SEL_ACTIVE should eq "false"
    End
  End

  Describe "_input:ml:sel-bounds /"
    setup() {
      _input:ml:init 80 24
    }
    Before setup

    It "returns anchor;cursor when anchor is before cursor"
      __ML_SEL_ANCHOR_ROW=1
      __ML_SEL_ANCHOR_COL=3
      __ML_ROW=2
      __ML_COL=7

      When call _input:ml:sel-bounds
      The output should eq "1;3;2;7"
    End

    It "returns cursor;anchor when cursor is before anchor"
      __ML_SEL_ANCHOR_ROW=3
      __ML_SEL_ANCHOR_COL=10
      __ML_ROW=1
      __ML_COL=2

      When call _input:ml:sel-bounds
      The output should eq "1;2;3;10"
    End

    It "returns correct order on same line"
      __ML_SEL_ANCHOR_ROW=0
      __ML_SEL_ANCHOR_COL=8
      __ML_ROW=0
      __ML_COL=3

      When call _input:ml:sel-bounds
      The output should eq "0;3;0;8"
    End
  End

  Describe "_input:ml:sel-get-text /"
    setup() {
      _input:ml:init 80 24
      __ML_LINES=("Hello World" "Second line" "Third line")
    }
    Before setup

    It "returns empty when no selection"
      When call _input:ml:sel-get-text
      The output should eq ""
    End

    It "returns selected text on single line"
      __ML_SEL_ACTIVE=true
      __ML_SEL_ANCHOR_ROW=0
      __ML_SEL_ANCHOR_COL=6
      __ML_ROW=0
      __ML_COL=11

      When call _input:ml:sel-get-text
      The output should eq "World"
    End

    It "returns selected text across multiple lines"
      __ML_SEL_ACTIVE=true
      __ML_SEL_ANCHOR_ROW=0
      __ML_SEL_ANCHOR_COL=6
      __ML_ROW=1
      __ML_COL=6

      When call _input:ml:sel-get-text
      The output should eq "World
Second"
    End
  End

  Describe "_input:ml:sel-delete /"
    setup() {
      _input:ml:init 80 24
      __ML_LINES=("Hello World" "Second line" "Third line")
    }
    Before setup

    It "returns 1 when no selection is active"
      When call _input:ml:sel-delete
      The status should eq 1
    End

    It "deletes selected text within single line"
      __ML_SEL_ACTIVE=true
      __ML_SEL_ANCHOR_ROW=0
      __ML_SEL_ANCHOR_COL=5
      __ML_ROW=0
      __ML_COL=11

      _input:ml:sel-delete

      The variable __ML_LINES[0] should eq "Hello"
      The variable __ML_ROW should eq 0
      The variable __ML_COL should eq 5
      The variable __ML_SEL_ACTIVE should eq "false"
    End

    It "deletes selected text across multiple lines"
      __ML_SEL_ACTIVE=true
      __ML_SEL_ANCHOR_ROW=0
      __ML_SEL_ANCHOR_COL=5
      __ML_ROW=2
      __ML_COL=5

      _input:ml:sel-delete

      The variable __ML_LINES[0] should eq "Hello line"
      The variable __ML_ROW should eq 0
      The variable __ML_COL should eq 5
      The variable __ML_SEL_ACTIVE should eq "false"
    End

    It "sets modified flag"
      __ML_SEL_ACTIVE=true
      __ML_SEL_ANCHOR_ROW=0
      __ML_SEL_ANCHOR_COL=0
      __ML_ROW=0
      __ML_COL=5

      _input:ml:sel-delete

      The variable __ML_MODIFIED should eq "true"
    End
  End

  Describe "_input:ml:sel-all /"
    setup() {
      _input:ml:init 80 24
      __ML_LINES=("Hello" "World" "Test")
    }
    Before setup

    It "selects entire buffer"
      _input:ml:sel-all

      The variable __ML_SEL_ACTIVE should eq "true"
      The variable __ML_SEL_ANCHOR_ROW should eq 0
      The variable __ML_SEL_ANCHOR_COL should eq 0
      The variable __ML_ROW should eq 2
      The variable __ML_COL should eq 4
    End
  End

  Describe "selection + editing integration /"
    setup() {
      _input:ml:init 80 24
      __ML_LINES=("Hello World")
    }
    Before setup

    It "insert-char replaces active selection"
      __ML_SEL_ACTIVE=true
      __ML_SEL_ANCHOR_ROW=0
      __ML_SEL_ANCHOR_COL=0
      __ML_ROW=0
      __ML_COL=5

      _input:ml:insert-char "X"

      The variable __ML_LINES[0] should eq "X World"
      The variable __ML_COL should eq 1
      The variable __ML_SEL_ACTIVE should eq "false"
    End

    It "delete-char deletes active selection"
      __ML_SEL_ACTIVE=true
      __ML_SEL_ANCHOR_ROW=0
      __ML_SEL_ANCHOR_COL=0
      __ML_ROW=0
      __ML_COL=5

      _input:ml:delete-char

      The variable __ML_LINES[0] should eq " World"
      The variable __ML_COL should eq 0
      The variable __ML_SEL_ACTIVE should eq "false"
    End

    It "insert-newline replaces selection with newline"
      __ML_SEL_ACTIVE=true
      __ML_SEL_ANCHOR_ROW=0
      __ML_SEL_ANCHOR_COL=5
      __ML_ROW=0
      __ML_COL=11

      _input:ml:insert-newline

      The variable __ML_LINES[0] should eq "Hello"
      The variable __ML_LINES[1] should eq ""
      The variable __ML_ROW should eq 1
      The variable __ML_COL should eq 0
    End
  End
End

Describe "_tui.sh / _input:read-key /"
  # Helper: feed bytes to _input:read-key via stdin
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
  End

  Describe "control characters /"
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

    It "reads Ctrl+C (0x03)"
      When call feed_key $'\x03'
      The output should eq "ctrl-c"
    End
  End

  Describe "arrow keys /"
    It "reads up arrow"
      When call feed_key $'\x1b[A'
      The output should eq "up"
    End

    It "reads down arrow"
      When call feed_key $'\x1b[B'
      The output should eq "down"
    End

    It "reads right arrow"
      When call feed_key $'\x1b[C'
      The output should eq "right"
    End

    It "reads left arrow"
      When call feed_key $'\x1b[D'
      The output should eq "left"
    End
  End

  Describe "escape key /"
    It "reads bare escape"
      When call feed_key $'\x1b'
      The output should eq "escape"
    End
  End

  Describe "modified keys /"
    It "reads Ctrl+Up"
      When call feed_key $'\x1b[1;5A'
      The output should eq "ctrl-up"
    End

    It "reads Ctrl+Down"
      When call feed_key $'\x1b[1;5B'
      The output should eq "ctrl-down"
    End

    It "reads Shift+Up"
      When call feed_key $'\x1b[1;2A'
      The output should eq "shift-up"
    End

    It "reads Alt+Up"
      When call feed_key $'\x1b[1;3A'
      The output should eq "alt-up"
    End
  End
End

Describe "_tui.sh / _input:_raw helper /"
  It "sets globals when use_raw is true"
    _input:_raw "true" "1b" $'\x1b'

    The variable __INPUT_RAW_BYTES should eq "1b"
    The variable __INPUT_RAW_CHARS should eq $'\x1b'
  End

  It "does nothing when use_raw is false"
    unset __INPUT_RAW_BYTES
    _input:_raw "false" "1b" $'\x1b'

    The variable __INPUT_RAW_BYTES should be undefined
  End
End

Describe "_tui.sh / confirm:by:input /"
  # Remove colors for consistent output testing
  Before "unset cl_red cl_green cl_blue cl_purple cl_yellow cl_reset cl_grey cl_selected"

  It "uses top priority value when provided"
    preserve() { %preserve result:RESULT; }
    AfterCall preserve

    When call confirm:by:input "Prompt:" "result" "fallback" "top_value" "" "" ""

    The variable RESULT should eq "top_value"
    The output should include "Prompt:"
    The output should include "top_value"
  End

  It "uses second priority value when top is empty"
    preserve() { %preserve result:RESULT; }
    AfterCall preserve

    When call confirm:by:input "Prompt:" "result" "fallback" "" "second_value" "" ""

    The variable RESULT should eq "second_value"
    The output should include "second_value"
  End

  It "uses third priority (fallback) when top and second are empty"
    preserve() { %preserve result:RESULT; }
    AfterCall preserve

    When call confirm:by:input "Prompt:" "result" "fallback" "" "" "third_value" ""

    The variable RESULT should eq "fallback"
    The output should include "fallback"
  End
End

Describe "_tui.sh / Backward Compatibility /"
  It "provides TUI functions from _tui.sh include"
    When call type cursor:position
    The output should include "cursor:position is a function"
  End

  It "provides validate:input from _tui.sh include"
    When call type validate:input
    The output should include "validate:input is a function"
  End

  It "provides input:multi-line from _tui.sh include"
    When call type input:multi-line
    The output should include "input:multi-line is a function"
  End
End
