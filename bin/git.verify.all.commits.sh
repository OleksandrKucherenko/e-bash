#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-07-06
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# Verify all commits in repository for Conventional Commits compliance
# This script replaces ci_verify_all_commits.js by using git.conventional.commits.sh

export ARGS_DEFINITION="-h,--help -v,--version=:0.1.0 --debug=DEBUG:* --branch"

# Setup logging (following user's e-bash logging guidelines)
DEBUG=${DEBUG:-"-debug,verify,success,error,warning,info"}
# shellcheck source=../.scripts/_colors.sh
# shellcheck source=../.scripts/_logger.sh
# shellcheck source=../.scripts/_commons.sh
# shellcheck source=../.scripts/_arguments.sh
source "${E_BASH}/_arguments.sh"

# Setup loggers with color-coded prefixes
logger:init verify " "
logger:init success "${cl_green}[Success]${cl_reset} "
logger:init error " "
logger:init warning "${cl_yellow}[Warning]${cl_reset} "
logger:init debug "${cl_gray}[Debug]${cl_reset} "

# Source the conventional commits validation script
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=./git.conventional.commits.sh
source "$SCRIPT_DIR/git.conventional.commits.sh"

#
# Validate if a commit message follows conventional commit patterns
# Arguments:
#   $1: commit hash
# Returns:
#   0 if commit is valid conventional commit, 1 otherwise
#
function validate_commit() {
    local commit_hash="$1"
    local commit_msg

    # Get full commit message
    commit_msg=$(git log -1 --pretty=%B "$commit_hash" 2>/dev/null | head -1 | tr '\n' ' ')

    echo:Debug "Validating commit ${cl_yellow}${commit_hash:0:8}${cl_reset}: ${cl_gray}${commit_msg}${cl_reset}"

    # Check for merge commits (skip validation)
    if [[ "$commit_msg" =~ ^Merge\ (branch|pull\ request) ]]; then
        echo:Debug "Skipping merge commit validation"
        return 0
    fi

    # Check for initial commit (skip validation)
    if [[ "$commit_msg" =~ ^(Initial\ commit|initial\ commit|first\ commit) ]]; then
        echo:Debug "Skipping initial commit validation"
        return 0
    fi

    # Use the conventional:is_valid_commit function for validation
    if conventional:is_valid_commit "$commit_hash"; then
        return 0
    fi

    return 1
}

#
# Main function to verify all commits
#
function main() {
    local commit_hashes failed_commits=() progress_counter=0
    local total_commits failed_count=0

    echo:Verify "🔍 Gathering commit history..."
    if [ -n "$branch" ]; then
        echo:Verify "🔍 Only commits of the current branch $(git branch --show-current) will be checked"
        git_master_name=$(git rev-parse --verify master >/dev/null 2>&1 && echo master || echo main)

        # Get all commit hashes for the current branch only (most recent first)
        if ! commit_hashes=$(git log --format=%H "${git_master_name}.." 2>/dev/null); then
            echo:Error "Failed to get git commit history for branch. Are you in a git repository?"
            exit 1
        fi
    else
        # Get all commit hashes in the repo (most recent first)
        if ! commit_hashes=$(git log --format=%H 2>/dev/null); then
            echo:Error "Failed to get git commit history. Are you in a git repository?"
            exit 1
        fi
    fi

    # Convert to array
    readarray -t commit_array <<<"$commit_hashes"
    total_commits=${#commit_array[@]}

    echo:Verify "🔍 Checking ${cl_yellow}${total_commits}${cl_reset} commits for Conventional Commit compliance..."
    echo

    # Initialize progress indicator
    printf "Progress: "

    # Process each commit
    for commit_hash in "${commit_array[@]}"; do
        [[ -z "$commit_hash" ]] && continue

        local commit_msg
        commit_msg=$(git log -1 --pretty=%B "$commit_hash" 2>/dev/null | head -1 | tr '\n' ' ')

        # Validate commit
        if ! validate_commit "$commit_hash"; then
            failed_commits+=("$commit_hash")
        fi

        # Update progress indicator
        if ((progress_counter % 10 == 0)); then
            # Print the index number every 10 commits
            printf "%d" "$progress_counter"
        else
            # Print a dot for each commit
            printf "."
        fi

        ((progress_counter++))
    done

    # End the progress line
    printf "\n\n"

    failed_count=${#failed_commits[@]}

    if ((failed_count == 0)); then
        echo:Success "✅ All commits pass Conventional Commits check!"
        exit 0
    else
        echo:Error "❌ ${cl_red}${failed_count}${cl_reset} commit(s) failed:"
        echo

        for commit_hash in "${failed_commits[@]}"; do
            local commit_msg commit_author commit_date

            commit_msg=$(git log -1 --pretty=%B "$commit_hash" | head -1)
            commit_author=$(git log -1 --pretty=%an "$commit_hash")
            commit_date=$(git log -1 --pretty=%ad --date=short "$commit_hash")

            echo:Error "🔴 Commit: ${cl_yellow}${commit_hash:0:8}${cl_reset}, Author: ${cl_cyan}${commit_author}${cl_reset}, Date: ${cl_gray}${commit_date}${cl_reset}"
            echo:Error "   Message: \"${cl_red}${commit_msg}${cl_reset}\""
            #echo:Error "   Expected: ${cl_green}type(scope): description${cl_reset} or ${cl_green}type: description${cl_reset}"
            #echo:Error "   Examples: ${cl_green}feat: add new feature${cl_reset}, ${cl_green}fix(auth): resolve login issue${cl_reset}, ${cl_green}docs: update README${cl_reset}"
            echo
        done

        echo:Error "💡 Conventional Commit format: ${cl_green}type(scope): description${cl_reset}"
        echo:Error "   Valid types: ${cl_cyan}feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert${cl_reset}"
        echo:Error "   Use ${cl_yellow}!${cl_reset} for breaking changes: ${cl_green}feat!: breaking change${cl_reset}"
        echo:Error "   Reference: ${cl_blue}https://www.conventionalcommits.org/${cl_reset}"

        exit 1
    fi
}

# Help function
function show_help() {
    {
        echo "${cl_cyan}git.verify.all.commits.sh${cl_reset} - Verify all commits for Conventional Commits compliance"
        echo ""
        echo "${cl_yellow}USAGE:${cl_reset}"
        echo "    $0 [OPTIONS]"
        echo ""
        echo "${cl_yellow}OPTIONS:${cl_reset}"
        echo "    --help, -h     Show this help message"
        echo "    --debug        Enable debug logging"
        echo ""
        echo "${cl_yellow}DESCRIPTION:${cl_reset}"
        echo "    This script validates all commits in the current git repository to ensure"
        echo "    they follow the Conventional Commits specification."
        echo ""
        echo "    It checks each commit message against the pattern:"
        echo "    ${cl_green}type(scope): description${cl_reset}"
        echo ""
        echo "    Valid types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert, wip"
        echo ""
        echo "${cl_yellow}EXAMPLES:${cl_reset}"
        echo "    ${cl_green}feat: add user authentication${cl_reset}"
        echo "    ${cl_green}fix(api): resolve timeout issue${cl_reset}"
        echo "    ${cl_green}docs: update installation guide${cl_reset}"
        echo "    ${cl_green}feat!: breaking API changes${cl_reset}"
        echo ""
        echo "${cl_yellow}EXIT CODES:${cl_reset}"
        echo "    0 - All commits are valid"
        echo "    1 - One or more commits failed validation"
        echo ""
        echo "${cl_yellow}REFERENCE:${cl_reset}"
        echo "    https://www.conventionalcommits.org/"
        echo ""
    } >&1
}

# Parse command line arguments
[ -n "$version" ] && echo "$version" && exit 0
[ -n "$help" ] && show_help && exit 0

# Check if we're in a git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo:Error "Not in a git repository"
    exit 1
fi

# Run main function
main "$@"
