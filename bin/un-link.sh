#!/bin/bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-04-28
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


# shellcheck disable=SC2155
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../.scripts && pwd)"

# shellcheck disable=SC1090 source=../.scripts/_dependencies.sh
source "${E_BASH}/_dependencies.sh"

dependency pv "1.9.*" "brew install pv"
dependency greadlink "9.4" "brew install coreutils"

# if no input parameter, use current directory as a start point
[[ -z $1 ]] && target="." || target=$1

# find all symlinks in the target directory
echo "Searching..."
links=()
while IFS= read -r -d $'\0' f; do
    links+=("$f")
    echo -n "."
done < <(find "$target" -type l -print0 | pv -t -0 -F "%t %a" | grep -v "node_modules")
echo ""
if [[ ${#links[@]} -eq 0 ]]; then
    echo "No symlinks found in '$target'" && exit 0
fi

for f in "${links[@]}"; do
    # resolve the link
    link_target=$(greadlink --canonicalize-existing --no-newline --verbose "$f")
    [[ $? -ne 0 ]] && continue

    if [[ -d "$link_target" ]]; then # directory
        cmd="rm -f '$f' && cp -r '$link_target' '$f'"
    else # file
        cmd="rm -f '$f' && cp '$link_target' '$f'"
    fi

    echo "$cmd"
    # eval "$cmd"
    [[ $? -ne 0 ]] && echo "WARNING: Problem running '$cmd'" >&2
done

# ref: https://stackoverflow.com/questions/8377312/how-to-convert-symlink-to-regular-file
