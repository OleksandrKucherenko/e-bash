#!/bin/bash

# if no input parameter, use current directory as a start point
[[ -z $1 ]] && target="." || target=$1

# find all symlinks in the target directory
echo "Searching "
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
