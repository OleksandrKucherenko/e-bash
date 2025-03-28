#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-03-27
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# fail if any error is encountered
set -e

# Configuration.
REMOTE_NAME="e-bash"
REMOTE_URL="https://github.com/OleksandrKucherenko/e-bash.git"
REMOTE_INSTALL_SH="https://raw.githubusercontent.com/OleksandrKucherenko/e-bash/master/bin/install.e-bash.sh"
TEMP_BRANCH="e-bash-temp"
SCRIPTS_BRANCH="e-bash-scripts"
SCRIPTS_DIR=".scripts"
SCRIPTS_PREV_VERSION=".e-bash-previous-version"
DEFAULT_BRANCH="main"
INSTALL_SCRIPT="bin/install.e-bash.sh"

# Colors for better readability. should we use tput instead?
RED=$(tput setaf 1)    # red
GREEN=$(tput setaf 2)  # green
YELLOW=$(tput setaf 3) # yellow
BLUE=$(tput setaf 4)   # blue
PURPLE=$(tput setaf 5) # purple
CYAN=$(tput setaf 6)   # cyan
GRAY=$(tput setaf 8)   # dark gray
NC=$(tput sgr0)        # No Color
ITALIC=$(tput sitm)
NOI=$(tput ritm)

# Global flags.
DRY_RUN=false
FORCE=false # Not Implemented! But Reserved.

## Usage information, print to STDOUT
function show_usage() {
  echo -e "${BLUE}E-Bash Scripts Installer${NC}"
  echo ""
  echo -e "Usage: $0 [command] [version] [--dry-run]"
  echo ""
  echo -e "Options:"
  echo -e "  ${YELLOW}--dry-run${NC}  - Run in dry run mode (no changes)"
  echo ""
  echo -e "Commands:"
  echo -e "  ${GREEN}install${NC}   - Install e-bash scripts (default if not already installed)"
  echo -e "  ${YELLOW}upgrade${NC}   - Upgrade existing e-bash scripts"
  echo -e "  ${RED}rollback${NC}  - Rollback to previous version"
  echo -e "  ${BLUE}versions${NC}  - List available remote versions"
  echo -e "  ${RED}uninstall${NC} - Uninstall e-bash scripts (manual instructions)"
  echo ""
  echo -e "Version:"
  echo -e "  ${PURPLE}master${NC}   - Latest version from master branch (default), alias to: latest"
  echo -e "  ${PURPLE}v1.2.3${NC}   - Specific tagged version"
  echo ""
  echo -e "Examples:"
  echo -e "  $0                      ${GRAY}# Install latest version${NC}"
  echo -e "  $0 install v1.0.0       ${GRAY}# Install specific version${NC}"
  echo -e "  $0 upgrade              ${GRAY}# Upgrade to latest version${NC}"
  echo -e "  $0 upgrade v2.0.0       ${GRAY}# Upgrade to specific version${NC}"
  echo -e "  $0 rollback             ${GRAY}# Rollback to previous version${NC}"
  echo -e "  $0 versions             ${GRAY}# List available versions${NC}"
  exit 0
}

## Print manual instructions how to uninstall e-bash scripts
function show_manual_uninstall() {
  local exit_code=${1:-0}

  echo -e "${BLUE}Manual Uninstall Guide:${NC}"
  echo ""
  echo -e "To uninstall e-bash scripts, run the following commands one-by-one:"
  echo ""
  echo -e "  rm -rf ${SCRIPTS_DIR}                          ${GRAY}# remove .scripts dir${NC}"
  echo -e "  rm -rf ${SCRIPTS_PREV_VERSION}          ${GRAY}# remove .e-bash-previous-version${NC}"
  echo -e "  git branch -D ${SCRIPTS_BRANCH} ${TEMP_BRANCH} ${GRAY}# remove local branches${NC}"
  echo -e "  git remote remove ${REMOTE_NAME}                 ${GRAY}# remove e-bash remote${NC}"
  echo -e "  rm -rf ${INSTALL_SCRIPT}             ${GRAY}# remove installation script${NC}"
  echo "${GRAY}${ITALIC}" # run git gc, maybe?
  echo "Please check ${YELLOW}README.md${GRAY} for e-bash additional instructions that you may want to remove."
  echo "Please check ${YELLOW}.envrc${GRAY} file for E_BASH variable that you may want to remove."
  echo "${NOI}${NC}"

  exit "${exit_code}"
}

## Try to determine the main branch name, with fallbacks for new repos. Result to STDOUT.
function current_branch() {
  local branch="${DEFAULT_BRANCH}"

  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo -e "${YELLOW}Regular folder detected...${NC}" >&2
  elif git rev-parse --quiet --verify HEAD >/dev/null 2>&1; then
    echo -e "${YELLOW}Repository with commits detected...${NC}" >&2
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  else
    echo -e "${YELLOW}New repository with no commits detected...${NC}" >&2

    # Check if there's a default branch configured
    if git config init.defaultBranch >/dev/null 2>&1; then
      branch=$(git config init.defaultBranch)
    fi
  fi

  echo "$branch"
}

## Check if git is available. Exit on error.
function check_prerequisites() {
  # if git is not available, exit with error
  if ! command -v git &>/dev/null; then
    echo -e "${RED}Error: git is not installed or not in PATH${NC}"
    exit 1
  fi

  # Ensure we're in a git repository
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    exit 1
  fi

  # ensure that we are executed on top of git repository without unstaged/uncommited changes
  # user should have guaranty to track installation changes and rollback on git level if needed
  if ! git diff --staged --quiet; then
    echo -e "${RED}Error: Unstaged or uncommited changes detected${NC}"
    echo -e "${YELLOW}Please commit or stash your changes before running this script${NC}"
    echo ""
    echo "Unstaged changes:"
    git diff --staged --name-only | awk '{print "  " $0}'
    echo ""
    echo "Hints:"
    echo "  git add . && git stash      ${GRAY}# stash changes${NC}"
    echo "  git reset --hard            ${GRAY}# reset to last commit${NC}"
    echo "  git checkout -- .           ${GRAY}# discard changes${NC}"
    echo "  git clean -fd               ${GRAY}# remove untracked files${NC}"
    echo "  git status                  ${GRAY}# check status${NC}"
    echo "  git stash pop               ${GRAY}# pop last stash changes${NC}"
    exit 1
  fi

  # Get untracked directories with trailing slashes
  local untracked_dirs=()
  readarray -t untracked_dirs < <(git ls-files --others --directory --exclude-standard | grep '/$' | grep -v '^$')

  # If there are untracked directories, warn the user and exit
  if [ ${#untracked_dirs[@]} -gt 0 ]; then
    echo ""
    echo -e "${RED}Error: Detected untracked directories that would be lost during install operations:${NC}"
    echo "${CYAN}" "${untracked_dirs[@]}" "${NC}"
    echo ""
    echo -e "${YELLOW}Please create .gitkeep files in directories that you want to keep or delete them.${NC}"
    echo -e "${YELLOW}If you select .gitkeep, dont forget to commit those files and run install script again.${NC}"
    echo -e "\nHints:"
    echo -e "  touch <directory>/.gitkeep      ${GRAY}# Create .gitkeep file${NC}"
    echo -e "  git add <directory>/.gitkeep    ${GRAY}# Stage the file${NC}"
    echo -e "  git commit -m \"Add .gitkeep\"    ${GRAY}# Commit the file${NC}"
    echo ""
    echo "OR remove the directory:"
    echo -e "  rm -rf <directory>              ${GRAY}# Remove directory${NC}"
    echo ""
    exit 1
  fi

  # check it .scripts destination folder exists, warning user about possible merge conflict
  if [ -d "$SCRIPTS_DIR" ]; then
    echo -e "${RED}Warning: found destination folder ${YELLOW}.scripts${RED}. It may cause merge conflicts.${NC}"
  fi
}

## Check if e-bash scripts are already installed. Retrun codes: 0 - true, 1 - false
function is_installed() {
  if [ -d "$SCRIPTS_DIR" ] && [ -f "$SCRIPTS_DIR/_colors.sh" ]; then
    return 0 # true
  else
    return 1 # false
  fi
}

## Save the current commit hash for potential rollback
function save_current_version() {
  if is_installed; then
    git rev-parse HEAD >"${SCRIPTS_PREV_VERSION}"
    echo -e "${BLUE}Saved current version for potential rollback${NC}"
  fi
}

## Check if repository remote exists, add if missing. Exit code.
function configure_remote() {
  local remote_exists
  remote_exists=$(git remote | grep -q "$REMOTE_NAME" && echo "true" || echo "false")

  if [ "$remote_exists" = "true" ]; then
    echo -e "${BLUE}Remote $REMOTE_NAME already exists. Fetching latest changes...${NC}"
    execute_git fetch "$REMOTE_NAME"
    return 0
  fi

  echo -e "${BLUE}Adding remote repository...${NC}"
  execute_git remote add --fetch "$REMOTE_NAME" "$REMOTE_URL"
  return 0
}

## Clean up existing temporary branches. Exit code.
function clean_temp_branches() {
  execute_git branch -D "$TEMP_BRANCH" 2>/dev/null || true
  execute_git branch -D "$SCRIPTS_BRANCH" 2>/dev/null || true
}

## Create temporary branch based on version. Exit code.
function create_temp_branch() {
  local version="$1"

  if [ "$version" = "master" ]; then
    execute_git checkout --quiet --force -b "$TEMP_BRANCH" "$REMOTE_NAME/master"
    return 0
  fi

  # FIXME: potentially we can have git error message that we can loose some files

  execute_git checkout --quiet -b "$TEMP_BRANCH" "$version"
  return 0
}

## Configure branches to be local-only. Exit code.
function configure_local_branches() {
  execute_git config branch."$TEMP_BRANCH".remote ""
  execute_git config branch."$SCRIPTS_BRANCH".remote ""

  echo -e "${GREEN}Created local branch '$SCRIPTS_BRANCH' with the scripts content${NC}"
  echo -e "${BLUE}Configured e-bash temporary branches to remain local only${NC}"
}

## Return to original branch if possible. Exit code.
function return_to_original_branch() {
  local has_commits
  has_commits=$(git rev-parse --quiet --verify HEAD >/dev/null 2>&1 && echo "true" || echo "false")

  if [ "$has_commits" = "true" ]; then
    execute_git checkout --quiet "$MAIN_BRANCH"
    return 0
  fi

  echo -e "${YELLOW}No commits found. Staying in current state.${NC}"
  : # No-op command
  return 0
}

## Setup the remote repository. Exit code.
function setup_remote() {
  local version="$1"

  # Configure the remote repository
  configure_remote

  # Setup temporary branch
  echo -e "${BLUE}Setting up temporary e-bash-temp branch...${NC}"
  clean_temp_branches
  create_temp_branch "$version"

  # Split the scripts subtree
  echo -e "${BLUE}Extracting scripts...${NC}"

  # we do not need any output from this command
  SILENT_GIT=true execute_git subtree split --quiet -P "$SCRIPTS_DIR" -b "$SCRIPTS_BRANCH"

  # Configure branches to remain local and not be pushed to remote
  configure_local_branches

  # Return to original branch
  return_to_original_branch
}

## Display installation success message
function display_installation_success() {
  echo -e "${GREEN}Installation complete!${NC}"
  echo -e "The e-bash scripts are now available in the ${CYAN}$SCRIPTS_DIR${NC} directory"
}

## Add e-bash scripts as a git subtree. Exit code.
function add_scripts_subtree() {
  echo -e "${BLUE}Adding scripts to your repository...${NC}"
  # FIXME: subtree add will fail if there are conflicts with existing files
  execute_git subtree add --prefix "$SCRIPTS_DIR" "$SCRIPTS_BRANCH" --squash
  return $?
}

## Install e-bash scripts. Exit code.
function install_scripts() {
  local version="${1:-master}"
  local install_status=0

  # FIXME: should we resolve alias `latest` to point to `master`?

  echo -e "${GREEN}Installing e-bash scripts (version: $version)...${NC}"

  # Setup remote and branches
  setup_remote "$version"

  # Add subtree
  add_scripts_subtree
  install_status=$?

  # Only continue if the subtree operation was successful
  if [ $install_status -eq 0 ]; then
    display_installation_success

    # Run post-installation steps
    post_installation_steps
  else
    echo -e "${RED}Installation failed. Please check the error messages above.${NC}"
    return 1
  fi

  return 0
}

## Perform the subtree merge operation for upgrade. Exit code.
function perform_subtree_merge() {
  echo -e "${BLUE}Pulling latest scripts and merge...${NC}"

  # FIXME: Subtree merge might fail if there are conflicts with local changes

  # For git subtree pull, we need to reference the local branch
  # This is not a remote pull, but rather merging from the local branch
  set +e
  execute_git subtree merge --prefix="$SCRIPTS_DIR" "$SCRIPTS_BRANCH" --squash
  result=$?
  set -e

  if [ "$result" -ne 0 ]; then
    echo -e "${RED}Error: Merge problems detected. Please uninstall manually and repeat the installation.${NC}"
    echo ""
    echo "${BLUE}Resolve Conflict by Aborting GIT Merge:${NC}"
    echo ""
    echo "  git merge --abort ${GRAY}# abort the merge operation${NC}"
    echo ""

    show_manual_uninstall $result # abort execution with custom exit code
  fi

  return $result
}

## Display the result of the subtree merge operation. Exit code.
function display_merge_result() {
  local result=$1

  if [ "$result" -eq 0 ]; then
    echo -e "${GREEN}Subtree merge successful${NC}"
    return 0
  fi

  echo -e "${RED}Subtree merge failed with exit code: $result${NC}"
  echo -e "${YELLOW}Debugging Git Branches:${NC}"
  execute_git branch

  return 1
}

## Display upgrade completion message
function display_upgrade_success() {
  echo -e "${GREEN}Upgrade complete!${NC}"
  echo -e "The e-bash scripts have been upgraded in the ${CYAN}$SCRIPTS_DIR${NC} directory"
  echo -e ""
}

## Upgrade e-bash scripts. Exit code.
function upgrade_scripts() {
  local version="${1:-master}"
  local merge_result=0

  # FIXME: should we resolve alias `latest` to point to `master`?

  echo -e "${YELLOW}=== UPGRADE STARTED (version: $version) ===${NC}"

  # Save current version for potential rollback
  save_current_version

  # Setup remote and branches
  setup_remote "$version"

  # Perform the subtree merge
  perform_subtree_merge
  merge_result=$?

  # Display the result
  display_merge_result "$merge_result"

  # If successful, show completion message
  if [ "$merge_result" -eq 0 ]; then
    display_upgrade_success
    echo -e "${YELLOW}If you need to rollback to the previous version, run:${NC}"
    echo -e "  $0 rollback"
  else
    echo -e "${YELLOW}Upgrade encountered issues. You may want to try again or rollback.${NC}"
    return 1
  fi

  # Run post-installation steps
  post_installation_steps

  return 0
}

## Append e-bash configuration to .envrc file. Exit code.
function update_envrc_configuration() {
  # Check if our configuration is already in .envrc
  if grep -q "export E_BASH=" ".envrc"; then
    echo -e "${YELLOW}e-bash configuration already exists in .envrc${NC}"
    return 0
  fi

  echo -e "${BLUE}Updating .envrc with e-bash configuration...${NC}"

  # Append our configuration to .envrc
  {
    echo ""
    echo "#"
    echo "# Add scripts to PATH for simpler run"
    echo "#"
    echo "PATH_add \"\$PWD/.scripts\""
    echo "#"
    echo "# Make global variable for all scripts, declare before any source ..."
    echo "#"
    echo "export E_BASH=\"\$(pwd)/.scripts\""
    echo "#"
    echo "# Set up Linux-specific aliases for GNU tools"
    echo "#"
    echo "if [[ \"\$(uname -s)\" == \"Linux\" ]]; then"
    # FIXME: This source command assumes the script exists but doesn't check.
    #   We rely on sequence of actions, assuming that its a post-installation step.
    echo "  source \"\$PWD/.scripts/_setup_gnu_symbolic_links.sh\""
    # `bin` folder may not exist, but _setup_gnu_symbolic_links.sh will create it
    echo "  PATH_add \"\$PWD/bin/gnubin\""
    echo "fi"
  } >>".envrc"

  echo -e "${GREEN}Updated .envrc file with e-bash configuration${NC}"
  echo -e "${YELLOW}Run 'direnv allow' to apply the changes${NC}"
  return 0
}

## Download installation script to bin directory. Exit code.
function copy_installer_to_bin() {
  # Check if we can download the script
  local has_curl
  local has_wget

  has_curl="$(command -v curl &>/dev/null && echo "true" || echo "false")"
  has_wget="$(command -v wget &>/dev/null && echo "true" || echo "false")"

  echo -e "${BLUE}Downloading installation script...${NC}"

  set -x
  # detect are we a file or in pipe execution
  local isPipe="$([[ ! -t 1 ]] && echo "true" || echo "false")"
  local fallback=0

  if [ "$has_curl" = "true" ]; then
    # --fail --silent --show-error --location
    curl -fsSL "$REMOTE_INSTALL_SH" -o "bin/install.e-bash.sh"
    result=$?
    if [ "$result" -ne 0 ]; then
      echo -e "${RED}Error: Failed to download script CURL${NC}"
      rm -rf "bin/install.e-bash.sh" # delete, it will contain error message instead of script
      fallback=1
    fi # try-fallback instead
  elif [ "$has_wget" = "true" ]; then
    wget -q -O "bin/install.e-bash.sh" "$REMOTE_INSTALL_SH"
    result=$?
    if [ "$result" -ne 0 ]; then
      echo -e "${RED}Error: Failed to download script WGET${NC}"
      fallback=1
    fi # try-fallback instead
  else
    echo -e "${RED}Error: Neither curl nor wget found to download the script${NC}"
    echo -e "${YELLOW}Download manually by url: $REMOTE_INSTALL_SH${NC}"
    return 1
  fi

  if [ "$fallback" -eq 1 ] && [ "$isPipe" = "false" ]; then
    echo -e "${YELLOW}Failed to download script, copying self instead${NC}"
    # we can copy itself to the bin directory
    cp "$0" "bin/install.e-bash.sh"
  fi

  # Set executable attribute if file exists
  [ -f "bin/install.e-bash.sh" ] && chmod +x "bin/install.e-bash.sh"

  echo -e "${GREEN}Placed installation script to bin/install.e-bash.sh${NC}"
  set +x
  return 0
}

## Perform post-installation customizations
function post_installation_steps() {
  echo -e "${BLUE}Performing post-installation steps...${NC}"

  # Check for .envrc file and update it if found
  if [ -f ".envrc" ]; then
    echo -e "${BLUE}Detected .envrc file. Adding e-bash configuration...${NC}"
    update_envrc_configuration
  fi

  # Check for bin directory and copy installer script
  if [ -d "bin" ]; then
    echo -e "${BLUE}Detected bin directory. Copying installation script...${NC}"
    copy_installer_to_bin
  fi
}

## Compose README.md file with e-bash installation instructions
function compose_readme() {
  {
    echo "# E-bash Scripts"
    echo ""
    echo "This repository includes e-bash scripts for automation and productivity."
    echo ""
    echo "## Installation"
    echo ""
    echo "To install or upgrade e-bash scripts, use the following commands:"
    echo -e "\n\`\`\`bash"
    echo "# Install latest version"
    echo "curl -sSL \"${REMOTE_INSTALL_SH}\" | bash -s -- install"
    echo -e "\n# Install specific version"
    echo "curl -sSL \"${REMOTE_INSTALL_SH}\" | bash -s -- install v1.0.0"
    echo -e "\n# Upgrade to latest version"
    echo "curl -sSL \"${REMOTE_INSTALL_SH}\" | bash -s -- upgrade"
    echo -e "\n# Rollback to previous version"
    echo "curl -sSL \"${REMOTE_INSTALL_SH}\" | bash -s -- rollback"
    echo -e "\`\`\`"
  } >README.md
}

## Initialize empty repository
function initialize_empty_repository() {
  # Check if repository is empty and initialize if needed
  if ! git rev-parse --quiet --verify HEAD >/dev/null 2>&1; then
    echo -e "${YELLOW}Empty repository detected. Creating initial commit...${NC}" >&2

    # Create README.md if it doesn't exist
    if [ ! -f "README.md" ]; then compose_readme; fi

    # Initialize the repository with the README
    SILENT_GIT=true execute_git add README.md

    # FIXME: Git commit will fail if user.name and user.email are not configured
    SILENT_GIT=true execute_git commit -m "Initial commit before installing e-bash scripts"

    # Update MAIN_BRANCH after initial commit
    MAIN_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
  fi
}

## Check if a previous version exists for rollback. Exit code.
function check_previous_version_exists() {
  if [ ! -f "${SCRIPTS_PREV_VERSION}" ]; then
    echo -e "${RED}Error: No previous version found to rollback to${NC}"
    return 1
  fi

  return 0
}

## Get the previous version from the version file. Result to STDOUT.
function get_previous_version() {
  # shellcheck disable=SC2155
  local previous_version=$(cat "${SCRIPTS_PREV_VERSION}")

  # FIXME: Should validate that previous_version is a valid commit hash/tag
  echo -e "${BLUE}Found previous version: $previous_version${NC}" >&2

  echo "$previous_version"
}

## Perform the actual rollback operation. Exit code.
function perform_rollback() {
  local previous_version=$1

  echo -e "${RED}Rolling back to previous version: $previous_version${NC}"
  # FIXME: Checkout will fail if the commit no longer exists (e.g., after garbage collection)
  execute_git checkout "$previous_version" -- "$SCRIPTS_DIR"

  return $?
}

## Display rollback completion message
function display_rollback_success() {
  echo -e "${GREEN}Rollback complete!${NC}"
  echo -e "The e-bash scripts have been restored to the previous version"
}

## Clean up after successful rollback
function cleanup_after_rollback() {
  # Remove the previous version file after rollback
  rm "${SCRIPTS_PREV_VERSION}" || true
}

## Get current version of installed e-bash
function get_installed_version() {
  local current_version="none"
  local branch_hash=""

  # Check if utility branches exist for version detection
  if ! git rev-parse --verify "$SCRIPTS_BRANCH" >/dev/null 2>&1; then
    # Branches don't exist, use fallback methods
    if [ -d "$SCRIPTS_DIR/.git" ]; then
      # shellcheck disable=SC2164
      cd "$SCRIPTS_DIR"
      current_version=$(git describe --tags 2>/dev/null || echo "unknown")
      cd - >/dev/null
      return 0
    elif [ -f "$SCRIPTS_PREV_VERSION" ]; then
      local hash
      hash=$(cat "$SCRIPTS_PREV_VERSION")
      current_version=$(git describe --tags "$hash" 2>/dev/null || echo "unknown")
      return 0
    fi
    echo "$current_version"
    return 0
  fi

  # Scripts branch exists, get its hash
  branch_hash=$(git rev-parse "$SCRIPTS_BRANCH")

  # Check if temp branch exists
  if git rev-parse --verify "$TEMP_BRANCH" >/dev/null 2>&1; then
    local temp_branch_version
    temp_branch_version=$(git describe --tags --exact-match "$TEMP_BRANCH" 2>/dev/null || echo "")

    if [ -n "$temp_branch_version" ]; then
      # Successfully found tag from temp branch
      echo "$temp_branch_version"
      return 0
    fi
  fi

  # Try direct tag detection
  local direct_tag_version
  direct_tag_version=$(git describe --tags --exact-match "$branch_hash" 2>/dev/null || echo "")

  if [ -n "$direct_tag_version" ]; then
    echo "$direct_tag_version"
    return 0
  fi

  # If still no tag found, check if it's from master
  local remote_master_hash
  remote_master_hash=$(git ls-remote "$REMOTE_NAME" master | cut -f1)

  if git rev-parse --verify "$TEMP_BRANCH" >/dev/null 2>&1; then
    local temp_hash
    local master_status="up to date"

    temp_hash=$(git rev-parse "$TEMP_BRANCH")

    # Compare current hash with remote master hash
    if [ -n "$temp_hash" ] && [ -n "$remote_master_hash" ]; then
      [ "$temp_hash" != "$remote_master_hash" ] && master_status="updates available"
    fi

    echo "master ($master_status)"
    return 0
  fi

  echo "master"
  return 0
}

## Display version with status indicators
function display_version() {
  local version="$1"
  local current_version="$2"
  local latest_version="$3"

  local status=""
  [ "$version" = "$current_version" ] && status+=" ${GREEN}[CURRENT]${NC}"
  [ "$version" = "$latest_version" ] && status+=" ${YELLOW}[LATEST]${NC}"

  echo -e "${PURPLE}$version${NC}${status}"
}

## Validate version
function validate_version() {
  local version=$1
  # FIXME: This doesn't handle the case where version is 'master' or other branch name
  if ! git ls-remote --tags $REMOTE_URL | grep -q "refs/tags/$version"; then
    echo -e "${RED}Error: Version $version does not exist in remote${NC}"
    exit 1
  fi
}

## Updated git command execution
function execute_git_v1() {
  if [ "$DRY_RUN" = true ]; then
    echo -e "${CYAN}dry run: git $*${NC}"
  else
    echo -e "${CYAN}execute: git $*${NC}" >&2
    # FIXME: Should provide more context on failure, perhaps capturing stderr
    git "$@" || return 1
  fi
}

## Updated git command execution
SILENT_GIT=false
function execute_git_v2() {
  if [ "$DRY_RUN" = true ]; then
    echo -e "${CYAN}dry run: git $*${NC}" >&2
    return 0
  fi

  # is immediate exit on error is enabled? remember the state
  local immediate_exit_on_error
  [[ $- == *e* ]] && immediate_exit_on_error=true || immediate_exit_on_error=false
  set +e # disable immediate exit on error

  echo -n -e "${CYAN}execute: git $*" >&2
  local output result
  output=$(git "$@" 2>&1)
  result=$?
  echo -e " code: ${YELLOW}$result${NC}" >&2
  [ -n "$output" ] && [ "$SILENT_GIT" = false ] && echo -e "$output" >&2

  [ "$immediate_exit_on_error" = "true" ] && set -e # recover state
  return $result
}

## Execute git command of selected dry_run wrapper version
function execute_git() { execute_git_v2 "$@"; }

## Install e-bash scripts
function repo_install() {
  local version="${1:-master}"

  check_prerequisites

  # Initialize empty repository if needed before installation
  initialize_empty_repository

  if is_installed; then
    echo -e "${YELLOW}e-bash scripts already installed. Use 'upgrade' to update.${NC}"
    echo -e "Run: $0 upgrade [$version]"
    exit 0
  fi

  install_scripts "$version"
}

## Upgrade existing installation
function repo_upgrade() {
  local version="${1:-master}"

  check_prerequisites

  # Initialize empty repository if needed before upgrade
  initialize_empty_repository

  if ! is_installed; then
    echo -e "${YELLOW}e-bash scripts not installed. Installing instead.${NC}"
    install_scripts "$version"
  else
    upgrade_scripts "$version"
  fi

}

## Rollback to previous version
function repo_rollback() {
  local previous_version=""
  local rollback_status=0

  check_prerequisites

  echo -e "${RED}=== operation: ROLLBACK ===${NC}"

  # Check if previous version exists
  check_previous_version_exists
  if [ $? -ne 0 ]; then return 1; fi

  # Get the previous version
  previous_version=$(get_previous_version)

  # Perform the rollback
  perform_rollback "$previous_version"
  rollback_status=$?

  # If rollback was successful, show success message and clean up
  if [ $rollback_status -eq 0 ]; then
    display_rollback_success
    cleanup_after_rollback
  else
    echo -e "${RED}Rollback failed with exit code: $rollback_status${NC}"
    return 1
  fi

  return 0
}

## List available version tags
function repo_versions() {
  echo -e "${BLUE}Fetching available versions from remote repository...${NC}"

  # Fetch tags from remote repository
  local has_remote has_git_repo
  has_git_repo=$(git rev-parse --is-inside-work-tree 2>/dev/null && echo "true" || echo "false")
  has_remote=$(git remote | grep -q "$REMOTE_NAME" && echo "true" || echo "false")

  if [ "$has_git_repo" = "false" ]; then
    echo -e "${YELLOW}Not a git repository. remote request...${NC}"
  elif [ "$has_remote" = "true" ]; then
    execute_git fetch "$REMOTE_NAME" --tags
  else
    execute_git remote add --fetch "$REMOTE_NAME" "$REMOTE_URL"
  fi

  # Determine current version if installed
  local current_version="none"
  if is_installed; then
    current_version=$(get_installed_version)
  fi

  # Get all tags from remote
  local all_remote_tags
  all_remote_tags=$(git ls-remote --tags "$REMOTE_URL" | grep -o 'refs/tags/v[0-9]\+\.[0-9]\+\.[0-9]\+.*$' | sed 's|refs/tags/||')

  # Separate stable and non-stable version tags
  local stable_tags
  local non_stable_tags
  stable_tags=$(echo "$all_remote_tags" | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' || echo "")
  non_stable_tags=$(echo "$all_remote_tags" | grep -v -E '^v[0-9]+\.[0-9]+\.[0-9]+$' || echo "")

  # Identify latest stable version
  local latest_version
  latest_version=$(echo "$stable_tags" | sort -V | tail -n 1)

  # List versions matching v{semver} pattern (e.g., v1.0.0)
  echo ""
  echo -e "${GREEN}Available stable versions:${NC}"

  # Check if current version is master and display with indicators
  local is_master=false
  local master_status=""

  [[ "$current_version" == master* ]] && is_master=true
  [ "$is_master" = true ] && master_status=" ${GREEN}[CURRENT]${NC}"

  # Display master branch with appropriate status
  echo -e "${PURPLE}master${NC} - Development version (alias to: latest)${master_status}"

  # Display all stable versions with highlights
  if [ -n "$stable_tags" ]; then
    echo "$stable_tags" | sort -V | while read -r version; do
      display_version "$version" "$current_version" "$latest_version"
    done
  else
    echo -e "${YELLOW}No stable version tags found${NC}"
  fi

  # Display non-stable versions (pre-releases, etc.)
  if [ -n "$non_stable_tags" ]; then
    echo ""
    echo -e "${BLUE}Non-stable versions (pre-releases, development versions):${NC}"
    echo "$non_stable_tags" | sort -V | while read -r version; do
      display_version "$version" "$current_version" ""
    done
  fi
}

## Main function
function main() {
  local args="$*"
  # if $args are empty, print <empty>
  [ -z "$args" ] && args="<empty>"
  echo -e "${PURPLE}installer: e-bash scripts, arguments: ${YELLOW}$args${NC}" >&2

  local command="${1:-auto}"
  local version="${2:-master}"

  # Process version to handle aliases like 'latest' -> 'master'
  [ "$version" = "latest" ] && version="master"

  # If command is "auto", determine whether to install or upgrade
  if [ "$command" == "auto" ]; then
    if is_installed; then
      command="upgrade"
      echo -e "${YELLOW}Auto-detected: e-bash scripts already installed. Switching to 'upgrade' mode.${NC}"
    else
      command="install"
      echo -e "${GREEN}Auto-detected: e-bash scripts not installed. Switching to 'install' mode.${NC}"
    fi
  fi

  # Main repository branch
  # FIXME: This assumes current_branch will succeed, but there's no error handling if it fails
  MAIN_BRANCH=$(current_branch)

  case "$command" in
  "install")
    repo_install "$version"
    ;;
  "upgrade")
    repo_upgrade "$version"
    ;;
  "rollback")
    repo_rollback
    ;;
  "versions")
    repo_versions
    ;;
  "uninstall")
    show_manual_uninstall
    ;;
  "help" | "-h" | "--help")
    show_usage
    ;;
  *)
    echo -e "${RED}Unknown command: $command${NC}"
    show_usage
    exit 1
    ;;
  esac
}

ARGS=()

# Pre-parse arguments for special flags before main processing.
function preparse_args() {
  local args=("$@")

  for i in "${!args[@]}"; do
    key="${args[i]}"

    if [[ "$key" == "--dry-run" ]]; then
      DRY_RUN=true && unset 'args[i]'
    elif [[ "$key" == "--force" || "$key" == "-f" ]]; then
      FORCE=true && unset 'args[i]'
    fi
  done

  # Report flags
  [ "$DRY_RUN" = true ] && echo "dry run mode ON: $DRY_RUN" >&2
  [ "$FORCE" = true ] && echo "forced override: $FORCE" >&2

  # Return remaining arguments
  # shellcheck disable=SC2206
  ARGS=(${args[@]})
}

# Process special flags
preparse_args "$@"

# Execute main function with all passed arguments
main "${ARGS[@]}"

# [TEST SCENARIOS](../docs/installation.md)
# [UNIT TESTS](../spec/installation_spec.sh)
