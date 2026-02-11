#!/usr/bin/env bash
# shell: bash altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016,SC2288,SC2155,SC2329

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-02-11
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

Include ".scripts/_tui.sh"

Describe "_tui.sh / input:multi-line /"
  # remove colors in output
  BeforeCall "unset cl_red cl_green cl_blue cl_purple cl_yellow cl_reset cl_grey cl_selected"
  BeforeCall 'export DEBUG="*"'

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
      __ML_ROW=0

      _input:ml:delete-char

      The variable __ML_LINES[0] should eq "Hello"
      The variable __ML_COL should eq 0
    End

    It "joins with previous line when at column 0"
      __ML_LINES=("Hello" "World")
      __ML_ROW=1
      __ML_COL=0

      _input:ml:delete-char

      The variable __ML_LINES[0] should eq "HelloWorld"
      The variable __ML_ROW should eq 0
      The variable __ML_COL should eq 5
    End

    It "joins preserving content from both lines"
      __ML_LINES=("abc" "def" "ghi")
      __ML_ROW=1
      __ML_COL=0

      _input:ml:delete-char

      The variable __ML_LINES[0] should eq "abcdef"
      The variable __ML_LINES[1] should eq "ghi"
      The variable __ML_ROW should eq 0
      The variable __ML_COL should eq 3
    End
  End

  Describe "_input:ml:delete-word /"
    setup() {
      _input:ml:init 80 24
    }
    Before setup

    It "deletes word backward"
      __ML_LINES[0]="Hello World"
      __ML_COL=11

      _input:ml:delete-word

      The variable __ML_LINES[0] should eq "Hello "
      The variable __ML_COL should eq 6
    End

    It "deletes trailing spaces then word"
      __ML_LINES[0]="Hello   "
      __ML_COL=8

      _input:ml:delete-word

      The variable __ML_LINES[0] should eq ""
      The variable __ML_COL should eq 0
    End

    It "does nothing at beginning of line"
      __ML_LINES[0]="Hello"
      __ML_COL=0

      _input:ml:delete-word

      The variable __ML_LINES[0] should eq "Hello"
      The variable __ML_COL should eq 0
    End
  End

  Describe "_input:ml:insert-newline /"
    setup() {
      _input:ml:init 80 24
    }
    Before setup

    It "splits line at cursor position"
      __ML_LINES[0]="HelloWorld"
      __ML_COL=5

      _input:ml:insert-newline

      The variable __ML_LINES[0] should eq "Hello"
      The variable __ML_LINES[1] should eq "World"
      The variable __ML_ROW should eq 1
      The variable __ML_COL should eq 0
    End

    It "creates new empty line when cursor at end"
      __ML_LINES[0]="Hello"
      __ML_COL=5

      _input:ml:insert-newline

      The variable __ML_LINES[0] should eq "Hello"
      The variable __ML_LINES[1] should eq ""
      The variable __ML_ROW should eq 1
      The variable __ML_COL should eq 0
    End

    It "pushes existing line content to new line when cursor at beginning"
      __ML_LINES[0]="Hello"
      __ML_COL=0

      _input:ml:insert-newline

      The variable __ML_LINES[0] should eq ""
      The variable __ML_LINES[1] should eq "Hello"
      The variable __ML_ROW should eq 1
      The variable __ML_COL should eq 0
    End

    It "inserts newline between existing lines"
      __ML_LINES=("Line1" "Line2" "Line3")
      __ML_ROW=1
      __ML_COL=3

      _input:ml:insert-newline

      The variable __ML_LINES[0] should eq "Line1"
      The variable __ML_LINES[1] should eq "Lin"
      The variable __ML_LINES[2] should eq "e2"
      The variable __ML_LINES[3] should eq "Line3"
      The variable __ML_ROW should eq 2
      The variable __ML_COL should eq 0
    End
  End

  Describe "_input:ml:move-up /"
    setup() {
      _input:ml:init 80 24
    }
    Before setup

    It "moves cursor up one row"
      __ML_LINES=("Line1" "Line2")
      __ML_ROW=1
      __ML_COL=3

      _input:ml:move-up

      The variable __ML_ROW should eq 0
      The variable __ML_COL should eq 3
    End

    It "does not move above first line"
      __ML_LINES=("Line1" "Line2")
      __ML_ROW=0
      __ML_COL=3

      _input:ml:move-up

      The variable __ML_ROW should eq 0
    End

    It "clamps col to shorter line length"
      __ML_LINES=("Hi" "Hello")
      __ML_ROW=1
      __ML_COL=5

      _input:ml:move-up

      The variable __ML_ROW should eq 0
      The variable __ML_COL should eq 2
    End
  End

  Describe "_input:ml:move-down /"
    setup() {
      _input:ml:init 80 24
    }
    Before setup

    It "moves cursor down one row"
      __ML_LINES=("Line1" "Line2")
      __ML_ROW=0
      __ML_COL=3

      _input:ml:move-down

      The variable __ML_ROW should eq 1
      The variable __ML_COL should eq 3
    End

    It "does not move below last line"
      __ML_LINES=("Line1" "Line2")
      __ML_ROW=1
      __ML_COL=3

      _input:ml:move-down

      The variable __ML_ROW should eq 1
    End

    It "clamps col to shorter line length"
      __ML_LINES=("Hello" "Hi")
      __ML_ROW=0
      __ML_COL=5

      _input:ml:move-down

      The variable __ML_ROW should eq 1
      The variable __ML_COL should eq 2
    End
  End

  Describe "_input:ml:move-left /"
    setup() {
      _input:ml:init 80 24
    }
    Before setup

    It "moves cursor left"
      __ML_LINES[0]="Hello"
      __ML_COL=3

      _input:ml:move-left

      The variable __ML_COL should eq 2
    End

    It "does not move left past column 0"
      __ML_LINES[0]="Hello"
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

    It "moves cursor right"
      __ML_LINES[0]="Hello"
      __ML_COL=2

      _input:ml:move-right

      The variable __ML_COL should eq 3
    End

    It "does not move past end of line"
      __ML_LINES[0]="Hello"
      __ML_COL=5

      _input:ml:move-right

      The variable __ML_COL should eq 5
    End
  End

  Describe "_input:ml:move-home /"
    setup() {
      _input:ml:init 80 24
    }
    Before setup

    It "moves cursor to beginning of line"
      __ML_LINES[0]="Hello World"
      __ML_COL=7

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
      __ML_LINES[0]="Hello World"
      __ML_COL=2

      _input:ml:move-end

      The variable __ML_COL should eq 11
    End
  End

  Describe "_input:ml:scroll /"
    setup() {
      _input:ml:init 80 5
    }
    Before setup

    It "scrolls down when cursor below visible area"
      __ML_LINES=("L1" "L2" "L3" "L4" "L5" "L6" "L7")
      __ML_ROW=6

      _input:ml:scroll

      The variable __ML_SCROLL should eq 2
    End

    It "scrolls up when cursor above visible area"
      __ML_LINES=("L1" "L2" "L3" "L4" "L5" "L6" "L7")
      __ML_SCROLL=4
      __ML_ROW=2

      _input:ml:scroll

      The variable __ML_SCROLL should eq 2
    End

    It "does not scroll when cursor is visible"
      __ML_LINES=("L1" "L2" "L3" "L4" "L5")
      __ML_SCROLL=0
      __ML_ROW=3

      _input:ml:scroll

      The variable __ML_SCROLL should eq 0
    End
  End

  Describe "_input:ml:get-content /"
    setup() {
      _input:ml:init 80 24
    }
    Before setup

    It "returns single line content"
      __ML_LINES=("Hello World")

      When call _input:ml:get-content

      The output should eq "Hello World"
    End

    It "returns multi-line content with newlines"
      __ML_LINES=("Line 1" "Line 2" "Line 3")

      When call _input:ml:get-content

      The line 1 of output should eq "Line 1"
      The line 2 of output should eq "Line 2"
      The line 3 of output should eq "Line 3"
    End

    It "returns empty string for empty buffer"
      __ML_LINES=("")

      When call _input:ml:get-content

      The output should eq ""
    End
  End

  Describe "_input:ml:insert-tab /"
    setup() {
      _input:ml:init 80 24
    }
    Before setup

    It "inserts two spaces at cursor position"
      __ML_LINES[0]="Hello"
      __ML_COL=5

      _input:ml:insert-tab

      The variable __ML_LINES[0] should eq "Hello  "
      The variable __ML_COL should eq 7
    End
  End

  Describe "_input:ml:paste /"
    setup() {
      _input:ml:init 80 24
    }
    Before setup

    It "inserts single line of text at cursor"
      __ML_LINES[0]=""
      __ML_COL=0

      _input:ml:paste "Hello World"

      The variable __ML_LINES[0] should eq "Hello World"
      The variable __ML_COL should eq 11
    End

    It "inserts multi-line pasted text"
      __ML_LINES[0]=""
      __ML_COL=0

      # Simulate paste with newlines using printf
      local text
      text=$(printf "Line1\nLine2\nLine3")
      _input:ml:paste "$text"

      The variable __ML_LINES[0] should eq "Line1"
      The variable __ML_LINES[1] should eq "Line2"
      The variable __ML_LINES[2] should eq "Line3"
      The variable __ML_ROW should eq 2
      The variable __ML_COL should eq 5
    End

    It "inserts text in the middle of existing content"
      __ML_LINES[0]="HelloWorld"
      __ML_COL=5

      _input:ml:paste " Beautiful "

      The variable __ML_LINES[0] should eq "Hello Beautiful World"
      The variable __ML_COL should eq 16
    End
  End

  Describe "_input:ml:delete-line /"
    setup() {
      _input:ml:init 80 24
    }
    Before setup

    It "deletes current line content (Ctrl+U)"
      __ML_LINES=("Hello" "World")
      __ML_ROW=0
      __ML_COL=3

      _input:ml:delete-line

      The variable __ML_LINES[0] should eq ""
      The variable __ML_LINES[1] should eq "World"
      The variable __ML_COL should eq 0
    End
  End

  Describe "_input:ml:stream:fit-height /"
    It "keeps requested stream height"
      When call _input:ml:stream:fit-height 10

      The status should be success
      The output should eq "10"
    End

    It "normalizes non-positive height to one line"
      When call _input:ml:stream:fit-height 0

      The status should be success
      The output should eq "1"
    End
  End

  Describe "_input:ml:stream:cursor /"
    It "falls back to 1;1 when cursor position is unavailable"
      When call _input:ml:stream:cursor 0

      The status should be success
      The output should eq "1;1"
    End
  End

  Describe "_input:ml:stream:allocate /"
    It "returns the same row when no overflow is needed"
      When call _input:ml:stream:allocate 7 3 24

      The status should be success
      The output should eq "7"
    End

    It "scrolls terminal with new lines when stream would overflow bottom"
      When call _input:ml:stream:allocate 24 5 24

      The status should be success
      The output should eq "20"
    End
  End

  Describe "_input:ml:stream:restore /"
    It "moves cursor to reusable output row"
      When call _input:ml:stream:restore 7 1

      The status should be success
      The stderr should include "[7;1H"
    End
  End

  Describe "_input:ml:restore-screen /"
    setup() {
      _input:ml:init 5 2
    }
    Before setup

    It "restores stream mode by moving cursor to reusable output row"
      _input:ml:stream:restore() { printf "<stream:%s:%s>" "$1" "$2" >&2; }
      When call _input:ml:restore-screen 1 2 "stream" 9 4

      The status should be success
      The stderr should include "[?2004l"
      The stderr should include "[?7h"
      The stderr should include "<stream:9:4>"
    End

    It "clears modal area on box restore"
      When call _input:ml:restore-screen 0 0 "box" 0 0

      The status should be success
      The stderr should include "[?2004l"
      The stderr should include "[?7h"
      The stderr should include "[1;1H"
      The stderr should include "[2;1H"
    End
  End

  Describe "_input:ml:render /"
    setup() {
      _input:ml:init 5 2
      __ML_LINES=("line1" "line2")
    }
    Before setup

    It "disables and restores line wrapping while rendering"
      When call _input:ml:render 0 0

      The status should be success
      The stderr should include "[?7l"
      The stderr should include "[?7h"
    End
  End

  Describe "integration: multiple operations /"
    setup() {
      _input:ml:init 80 24
    }
    Before setup

    It "builds content through sequence of operations"
      # Type "Hello"
      _input:ml:insert-char "H"
      _input:ml:insert-char "e"
      _input:ml:insert-char "l"
      _input:ml:insert-char "l"
      _input:ml:insert-char "o"

      # Press Enter
      _input:ml:insert-newline

      # Type "World"
      _input:ml:insert-char "W"
      _input:ml:insert-char "o"
      _input:ml:insert-char "r"
      _input:ml:insert-char "l"
      _input:ml:insert-char "d"

      When call _input:ml:get-content

      The line 1 of output should eq "Hello"
      The line 2 of output should eq "World"
    End

    It "handles backspace across line boundary"
      __ML_LINES=("Hello" "World")
      __ML_ROW=1
      __ML_COL=0

      # Backspace at start of line 2 joins with line 1
      _input:ml:delete-char

      The variable __ML_LINES[0] should eq "HelloWorld"
      The variable __ML_ROW should eq 0
      The variable __ML_COL should eq 5
    End

    It "handles up arrow with column clamping"
      __ML_LINES=("Hi" "Hello World")
      __ML_ROW=1
      __ML_COL=11

      _input:ml:move-up

      The variable __ML_ROW should eq 0
      The variable __ML_COL should eq 2
    End
  End
End
