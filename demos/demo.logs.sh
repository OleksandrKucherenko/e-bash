#!/usr/bin/env bash
# shellcheck disable=SC2034

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2024-01-02
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

DEBUG=demo,loader # enable debug mode

# shellcheck source=../.scripts/_colors.sh
# include other scripts: _colors, _logger, _commons, _dependencies, _arguments
scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../.scripts"
# shellcheck disable=SC1090 source=../.scripts/_commons.sh
source "$scripts_dir/_logger.sh"

# define prefixes for pipe's steps
red=" ${cl_red}#${cl_reset} "
green=" ${cl_green}|${cl_reset} "
yellow=" ${cl_yellow}\$${cl_reset} "

# type logger
logger demo "$@" # register echo:Demo and printf:Demo functions

## regular usage
echo:Demo "sample-01: Echo. Hello, world!"
printf:Demo "sample-02: PrintF. My Name is: %s %s\n" "Demo" "Normal"

## custom prefix
TAGS_PREFIX["demo"]="${cl_blue}[demo]${cl_reset} " # set prefix for echo:Demo and printf:Demo functions
echo:Demo "sample-03: Echo. Hello, world with the nice prefix!"
printf:Demo "sample-04: PrintF. My Name is: %s %s\n" "Prefixed" "Demo"

## custom prefix and pipe prefix mixed, both printed
echo "sample-05: Pipe. With one line, with [demo] prefix" | log:Demo "$yellow"

# reset prefix
unset "TAGS_PREFIX[\"demo\"]"
# or like this
TAGS_PREFIX["demo"]="" 

## pipe
echo "sample-06: pipe with one line, no prefix" | log:Demo
echo "sample-07: pipe with one line and ${cl_red}'  #'${cl_reset} prefix" | log:Demo "$red"

echo "--- piped multiline ---"
{ echo "sample-08: line1"; echo "line2"; echo "line3"; } | log:Demo "$green"
echo "---"

## pipe middle step, sample-09
echo "--- piped, in a middle ---"
find . -type f -maxdepth 1 -name ".shell*" | log:Demo "$green" | tee
echo "---"

## no pipe, use as echo command, sample-10
log:Demo "  >" "regular log:Demo usage as echo command" "test"

## triple <<< operator
log:Demo "$yellow" <<< "sample-11: triple triangle brackets operator"

## redirect
echo "sample-12: redirect to stdin, demo 1" > >(log:Demo) # redirect stdout to pipe
echo "sample-13: redirect all streams, demo 2" &> >(log:Demo) # redirect stdout and stderr to pipe
{ echo "sample-14: stderror" >&2; } 2> >(log:Demo "$red") # redirect stderr to pipe

## shows the multi-streaming nature of the {} scope
{ echo "stdin2"; echo "stderror2" >&2; } &> >(log:Loader "$green")
{ echo "stdin3"; echo "stderror3" >&2; } 1> >(log:Loader "$yellow") 2> >(log:Loader "$red")

## named pipe
FIFO=$(log:Demo) # get named pipe path/name
echo:Demo "named_pipe: $FIFO"
# critical to add "&" to run in background, otherwise we will freeze on writing to named pipe
echo "named pipe demo, background process (line: $LINENO)" > "$FIFO" & # write to named pipe

## test GLOBAL redirects

# redirect all output to /dev/null
logger:redirect demo "> /dev/null"
echo "--- /dev/null ---"
echo:Demo "This message will be redirected to /dev/null" # nothing will be printed
echo "---"

# use stderr for output
logger:redirect demo ">&2"
echo:Demo "This message will be redirected to stderr" 2> >(log:Loader "$red")

# use stdout for output
logger:redirect demo ">&1"
echo:Demo "This message will be redirected to stdout" 1> >(log:Loader "$yellow")

# use file for output
logger:redirect demo "> /tmp/demo.log"
echo:Demo "This message will be redirected to /tmp/demo.log"
echo "--- /tmp/demo.log ---"
cat /tmp/demo.log && rm /tmp/demo.log
echo "---"

# redirect to TTY, defined in $__TTY
logger:redirect demo "> $__TTY"
echo:Demo "This message will be redirected to TTY"

# redirect to named pipe
logger:redirect loader "> $FIFO &" # critical to add "&" to run in background
TAGS_PREFIX["demo"]="${cl_blue}[pipe]${cl_reset} "
echo:Loader "This message will be redirected to named pipe (line: $LINENO)"
echo "--- dump named pipe: $FIFO ---"
cat "$FIFO" # read from named pipe
echo "---"

logger:redirect demo # reset redirect
logger:redirect loader # reset redirect
unset TAGS_PREFIX["demo"]
echo:Demo "This message will be redirected to default output"

echo ""
echo "All done!"
echo ""

SLEEP=5
echo "Sleeping for ${SLEEP} seconds..." && sleep ${SLEEP}
