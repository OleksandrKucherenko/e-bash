#!/usr/bin/env bash

# ESC[38:5:⟨n⟩m Select foreground color      where n is a number from the table below
# ESC[48:5:⟨n⟩m Select background color
# "\033[38;5;%dm" "\033[48;5;%dm" "\033[0m"

function report:colors() {
    local contrast=0 reset="" nl=""

    reset=$(printf "\033[0m")

    for ((i = 0; i < 256; i++)); do
        local mod8=$(((i + 1) % 8))
        local mod6=$(((i - 15) % 6))
        local c1=$((i > 231 && i < 244))
        local c2=$((i < 17 && i % 8 < 2))
        local c3=$((i > 16 && i < 232))
        local c4=$(((i - 16) % 6 < (i < 100 ? 3 : 2)))
        local c5=$(((i - 16) % 36 < 15))

        # Use conditions to set contrast
        contrast=16 && nl=""
        if [[ $c1 -eq 1 || $c2 -eq 1 ]] || [[ $c3 -eq 1 && $c4 -eq 1 && $c5 -eq 1 ]]; then contrast=7; fi

        if [ $i -lt 16 ] || [ $i -gt 231 ]; then
            [ $mod8 -eq 0 ] && nl=$'\n'
        else
            [ $mod6 -eq 0 ] && nl=$'\n'
        fi

        printf "  \033[48;5;%dm\033[38;5;%dm C %03d %s%s" $i $contrast $i "$reset" "$nl"
    done
}

report:colors

echo ""
echo "Hints:"
echo "  - use command 'tput setab [0-255]' to change background color"
echo "  - use command 'tput setaf [0-255]' to change foreground color"
echo "  - use command 'tput op' to reset colors"
echo ""
