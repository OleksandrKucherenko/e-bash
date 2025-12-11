#!/bin/bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-10
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


# ++++ 1700771567.209177 [103]: prefix_sub_folder
# ++++ 1700771567.210601 [87]: local tmpFileName=temp.file
# ++++++ 1700771567.213742 [88]: monorepo_root
# ++++++++ 1700771567.217496 [60]: dirname bin/version-up.v2.sh

gawk 'BEGIN {prev_time=0; first_line=1; line_num=0; depth=0; code=""} {
    # Skip lines that do not start with `+`
    if ($0 !~ /^\+/) {
        # uncomment this line to print non-tracing lines
        # print $0
        next
    }

    # Extract timestamp and calculate delta time in ms
    timestamp=($2+0) # force to number

    if (first_line == 0) {
        delta_time=(timestamp-prev_time)*1000
        # is delta time in danger zone?
        if (delta_time >= 10) { color=red } else { color=" " }
        printf("%s%.3fms%s | [%04d] %*s%s\n", color, delta_time, reset, line_num, depth*2, "", code)
    }

    # colors
    red="\033[31m"; reset="\033[0m";

    # Count the depth
    depth=gsub(/\+/, "&")

    # Extract line number, and code (first 100 chars only)
    split($3, arr, "[\\[\\]]")
    line_num=arr[2]
    code=substr($0, length($1 $2 $3)+3, 100)

    # Calculate delta time in ms
    if (first_line) { first_line=0 }   

    # update prev_time for next line
    prev_time=timestamp
    delta_time=0
} END {
    # Print the last line, last command delta_time should be ZERO
    printf(" %s%.3fms%s | [%04d] %*s%s\n", "\033[32m", delta_time, reset, line_num, depth*2, "", code)
}'
