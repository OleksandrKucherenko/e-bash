#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-04-27
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# set -x

myDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# are we in git repo?
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "Error: Not a git repository. You should be inside git repo folder or it subfolder." && exit 1
fi

# current branch name
git_branch=$(git rev-parse --abbrev-ref HEAD)

# detect the MAIN/MASTER branch name
#git_master_name=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@' | tail -1)
git_master_name=$(git rev-parse --verify master >/dev/null 2>&1 && echo master || echo main)

# total commits in branch
git_commits=$(git rev-list --no-merges --count ${git_master_name}..)

function args:isHelp() {
    local args=("$@") && if [[ "${args[*]}" =~ "--help" ]]; then echo true; else echo false; fi
}

function args:isTree() {
    local args=("$@") && if [[ "${args[*]}" =~ "--tree" ]]; then echo true; else echo false; fi
}

function print_help() {
    echo "Usage: $0 [TOP] [--tree]"
    echo "TOP           : number of commits to show files changed."
    echo "--tree        : show files in tree format."
    echo "--help        : show this help and exit."
}

# array of script arguments cleaned from flags (e.g. --help)
if [ -z "$ARGS_NO_FLAGS" ]; then export ARGS_NO_FLAGS=(); fi
function parse:exclude_flags_from_args() {
    local args=("$@")

    # remove all flags from call
    for i in "${!args[@]}"; do
        if [[ ${args[i]} == --* ]]; then unset 'args[i]'; fi
    done

    # shellcheck disable=SC2207,SC2116
    ARGS_NO_FLAGS=($(echo "${args[*]}"))
}

parse:exclude_flags_from_args "$@" # pre-filter arguments from flags

# for master/main branch show only last 1 commit(s)
[[ "$git_branch" == "${git_master_name}" ]] && git_commits=1

# take first argument as TOP, otherwise fallback to pre-calculated git_commits
TOP=${ARGS_NO_FLAGS[0]:-$git_commits}

if [ "$(args:isHelp "$@")" == "true" ]; then
    print_help
elif [ "$(args:isTree "$@")" == "true" ]; then
    git diff-tree --no-commit-id --name-only -r HEAD "HEAD~$TOP" | "${myDir}/tree.sh"
else
    git diff-tree --no-commit-id --name-only -r HEAD "HEAD~$TOP"
fi
