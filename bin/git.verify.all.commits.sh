#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-07-06
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# Verify all commits in repository for Conventional Commits compliance
# This script replaces ci_verify_all_commits.js by using git.conventional.commits.sh

export ARGS_DEFINITION="-h,--help -v,--version=:0.1.0 --debug=DEBUG:* --branch --patch"

# Setup logging (following user's e-bash logging guidelines)
DEBUG=${DEBUG:-"-debug,verify,success,error,warning,info"}

# shellcheck source=../.scripts/_colors.sh
# shellcheck source=../.scripts/_logger.sh
# shellcheck source=../.scripts/_commons.sh
# shellcheck source=../.scripts/_arguments.sh
source "${E_BASH}/_arguments.sh" 2>/dev/null || true

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
# Check if git has any uncommitted changes
#
function check_working_tree_clean() {
    if ! git diff-index --quiet HEAD --; then
        echo:Error "❌ You have uncommitted changes. Please commit or stash them first."
        echo:Error "   Use 'git status' to see what changes need to be committed."
        exit 1
    fi
}

#
# Create a backup branch before modifying git history
#
function create_backup_branch() {
    local backup_branch="backup-before-rewrite-$(date +%Y%m%d-%H%M%S)"
    echo:Verify "📦 Creating backup branch: ${cl_yellow}${backup_branch}${cl_reset}"
    git branch "$backup_branch"
    echo:Success "✅ Backup created. You can restore with: git checkout ${backup_branch}"
}

#
# Interactively reword a single commit message
#
function reword_commit() {
    local commit_hash="$1"
    local commit_msg
    commit_msg=$(git log -1 --pretty=%B "$commit_hash")

    echo:Verify "🔍 Current commit message:"
    echo:Info "   ${cl_gray}${commit_msg}${cl_reset}"
    echo

    # Show suggested conventional commit format
    echo:Info "💡 Suggested format: ${cl_green}type(scope): description${cl_reset}"
    echo:Info "   Valid types: ${cl_cyan}feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert${cl_reset}"
    echo

    # Get new message from user
    echo:Verify "✏️  Enter new commit message (or press Enter to skip):"
    read -r new_message
    echo

    if [[ -n "$new_message" ]]; then
        # Use git rebase to reword the commit
        echo:Verify "🔄 Rewording commit ${cl_yellow}${commit_hash:0:8}${cl_reset}..."

        # Create a temporary script for git rebase
        local temp_script
        temp_script=$(mktemp)
        echo "#!/bin/bash" >"$temp_script"
        echo "if [ \$GIT_COMMIT = $commit_hash ]; then" >>"$temp_script"
        echo "    echo \"$new_message\"" >>"$temp_script"
        echo "else" >>"$temp_script"
        echo "    cat" >>"$temp_script"
        echo "fi" >>"$temp_script"
        chmod +x "$temp_script"

        # Use filter-repo or filter-branch to reword the commit
        if git filter-branch -f --msg-filter "$temp_script" HEAD~100..HEAD 2>/dev/null; then
            echo:Success "✅ Commit message updated successfully"
        else
            echo:Warning "⚠️  Could not reword commit using filter-branch, trying alternative method..."
            # Alternative: use git commit --amend for the most recent commit
            if [[ "$commit_hash" == "$(git rev-parse HEAD)" ]]; then
                git commit --amend -m "$new_message"
                echo:Success "✅ Latest commit amended successfully"
            else
                echo:Error "❌ Failed to reword commit. This commit is not the latest commit."
                echo:Info "   To reword older commits, consider using: git rebase -i"
            fi
        fi

        rm -f "$temp_script"
    else
        echo:Info "⏭️  Skipped commit ${commit_hash:0:8}"
    fi
}

#
# Interactive patch mode for fixing commits
#
function patch_commits() {
    local failed_commits=("$@")

    if [[ ${#failed_commits[@]} -eq 0 ]]; then
        echo:Success "✅ No commits need fixing!"
        return 0
    fi

    echo:Warning "⚠️  You're about to modify git history. This will change commit hashes!"
    echo:Warning "   Make sure you understand the implications before proceeding."
    echo

    # Show commits that need fixing
    echo:Info "📝 Commits that need fixing:"
    for commit_hash in "${failed_commits[@]}"; do
        local commit_msg commit_author commit_date
        commit_msg=$(git log -1 --pretty=%B "$commit_hash" | head -1)
        commit_author=$(git log -1 --pretty=%an "$commit_hash")
        commit_date=$(git log -1 --pretty=%ad --date=short "$commit_hash")

        echo:Error "   🔴 ${cl_yellow}${commit_hash:0:8}${cl_reset} by ${cl_cyan}${commit_author}${cl_reset} (${cl_gray}${commit_date}${cl_reset})"
        echo:Error "      \"${cl_red}${commit_msg}${cl_reset}\""
        echo
    done

    # Ask for confirmation
    echo:Verify "Do you want to reword these commits? [y/N]:"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo:Info "❌ Patch mode cancelled."
        exit 0
    fi

    # Safety checks
    check_working_tree_clean
    create_backup_branch

    echo
    echo:Verify "🔄 Starting interactive rewording process..."
    echo

    # Process each failed commit
    local fixed_count=0
    local total_count=${#failed_commits[@]}

    for ((i = 0; i < total_count; i++)); do
        local commit_hash="${failed_commits[i]}"
        echo:Progress "Processing commit $((i + 1))/$total_count: ${cl_yellow}${commit_hash:0:8}${cl_reset}"

        reword_commit "$commit_hash"
        echo

        if [[ $? -eq 0 ]]; then
            ((fixed_count++))
        fi
    done

    echo
    echo:Success "🎉 Patch process completed!"
    echo:Info "   Fixed: ${cl_green}${fixed_count}${cl_reset}/${total_count} commits"

    if [[ $fixed_count -gt 0 ]]; then
        echo:Warning "⚠️  Git history has been rewritten. You may need to:"
        echo:Info "   - Force push if working with remote: git push --force-with-lease"
        echo:Info "   - Notify collaborators about the history change"
    fi
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
        echo

        # If patch mode is enabled, run interactive patch process
        if [[ -n "$patch" ]]; then
            patch_commits "${failed_commits[@]}"
        else
            echo:Info "💡 To fix these commits interactively, run with --patch flag"
            exit 1
        fi
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
        echo "    --branch       Only check commits of current branch (from master/main)"
        echo "    --patch        Interactive mode to fix non-conventional commit messages"
        echo ""
        echo "${cl_yellow}DESCRIPTION:${cl_reset}"
        echo "    This script validates all commits in the current git repository to ensure"
        echo "    they follow the Conventional Commits specification."
        echo ""
        echo "    With --patch mode, you can interactively fix non-conventional commit messages"
        echo "    by rewriting git history. This creates a backup branch and allows you to"
        echo "    reword each invalid commit."
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
        echo "${cl_yellow}PATCH MODE WARNINGS:${cl_reset}"
        echo "    ⚠️  --patch mode rewrites git history, changing commit hashes"
        echo "    ⚠️  Always creates backup branch before making changes"
        echo "    ⚠️  Requires force push if working with remote repositories"
        echo "    ⚠️  Notify collaborators before rewriting shared history"
        echo ""
        echo "${cl_yellow}REFERENCE:${cl_reset}"
        echo "    https://www.conventionalcommits.org/"
        echo ""
    } >&1
}

# DEBUG: Temporarily comment out source guard execution for debugging
# if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
#     echo "DEBUG: Script would execute here"
# fi

# This is the writing style presented by ShellSpec, which is short but unfamiliar.
# Note that it returns the current exit status (could be non-zero).
# DO NOT allow execution of code bellow those line in shellspec tests
${__SOURCED__:+return}

# Setup loggers with color-coded prefixes (only if e-bash is available)
logger:init verify " "
logger:init success "${cl_green}[Success]${cl_reset} "
logger:init error " "
logger:init warning "${cl_yellow}[Warning]${cl_reset} "
logger:init debug "${cl_gray}[Debug]${cl_reset} "

# Source guard - only execute when run directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
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
fi
