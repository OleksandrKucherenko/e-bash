#!/usr/bin/env bash
# shellcheck disable=SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-07-06
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# Set TERM if not defined (required for tput commands)
if [[ -z $TERM ]]; then export TERM=xterm-256color; fi

# fail if any error is encountered
set -e
shopt -s extdebug # enable extended debugging

# Configuration.
readonly REMOTE_NAME="e-bash"
readonly REMOTE_MASTER="master"
readonly REMOTE_URL="https://github.com/OleksandrKucherenko/e-bash.git"
readonly REMOTE_INSTALL_SH="https://raw.githubusercontent.com/OleksandrKucherenko/e-bash/master/bin/install.e-bash.sh"
readonly TEMP_BRANCH="e-bash-temp"
readonly SCRIPTS_BRANCH="e-bash-scripts"
readonly SCRIPTS_DIR=".scripts"
readonly SCRIPTS_PREV_VERSION=".e-bash-previous-version"
readonly DEFAULT_BRANCH="main"
readonly INSTALL_SCRIPT="bin/install.e-bash.sh"
readonly __WORKTREES=".versions"
readonly __REPO_V1="v1.0.0"
readonly __GLOBAL_DIR=".e-bash"
readonly GLOBAL_INSTALL_DIR="${HOME}/${__GLOBAL_DIR}"

# Colors for better readability. Suppress stderr for test environments
readonly RED=$(tput setaf 1 2>/dev/null || echo "")    # red
readonly GREEN=$(tput setaf 2 2>/dev/null || echo "")  # green
readonly YELLOW=$(tput setaf 3 2>/dev/null || echo "") # yellow
readonly BLUE=$(tput setaf 4 2>/dev/null || echo "")   # blue
readonly PURPLE=$(tput setaf 5 2>/dev/null || echo "") # purple
readonly CYAN=$(tput setaf 6 2>/dev/null || echo "")   # cyan
readonly GRAY=$(tput setaf 8 2>/dev/null || echo "")   # dark gray
readonly NC=$(tput sgr0 2>/dev/null || echo "")        # No Color
readonly ITALIC=$(tput sitm 2>/dev/null || echo "")    # Italic Style
readonly NOI=$(tput ritm 2>/dev/null || echo "")       # No Italic Style

# Global flags.
DRY_RUN=false       # Run in dry run mode (no changes)
FORCE=false         # If true, forcibly overwrite existing .scripts with auto-backup (numbered .scripts.~N~) for global install/upgrade.
GLOBAL=false        # Global installation (to HOME directory)
CREATE_SYMLINK=true # Create symlink to global e-bash scripts
CONFIRM=false       # Confirm destructive operations (like uninstall)
# SILENT flag removed - script should be polished by default
ARGS=()             # Clean argument after preparse_args

# Helpers
readonly EXIT_OK=0
readonly EXIT_NO=1

# Trap to capture exit/interrupt and print exit code
function on_exit() {
  local exit_code=$?

  local CLR="${GREEN}"
  [ $exit_code -ne 0 ] && CLR="${RED}"

  echo -e "\n${GRAY}${ITALIC}exit code:${NOI} ${CLR}$exit_code${NC}" >&2
  return $exit_code
}

function on_interrupt() {
  # TODO (olku): reserve for rollback on interrupt

  echo -e "\n${GRAY}Script interrupted!${NC}" >&2
  exit ${EXIT_NO}
}

# Register trap for normal exit and interrupt
trap on_exit EXIT
trap on_interrupt INT TERM

__FUNC_STACK="" # CSV list of functions

function on_entry() {
  local current_func="${FUNCNAME[1]}"
  local last_on_stack="${__FUNC_STACK##*,}"
  local indent_level=$(echo "$__FUNC_STACK" | tr -cd ',' | wc -c)
  local indent=$(printf '%*s' "$indent_level" '' | tr ' ' '  ')

  # if we got "<<" exit from nested function, then print current new level
  if [[ "$last_on_stack" == "<<" ]]; then
    __FUNC_STACK=${__FUNC_STACK%,*}
    #indent=$(printf '%*s' "$((indent_level - 1))" '' | tr ' ' '  ')
    #echo -e "${indent}${GRAY}-- ${BLUE}$current_func${NC}" >&2
  elif [[ "$current_func" != "on_entry" &&
    "$current_func" != "on_return" &&
    "$current_func" != "$last_on_stack" ]]; then
    echo -e "${indent}${GRAY}>> ${BLUE}$current_func${NC}" >&2
    __FUNC_STACK="$__FUNC_STACK,$current_func"
  fi
}

function on_return() {
  local current_func="${FUNCNAME[1]}"

  __FUNC_STACK=${__FUNC_STACK%,*}
  local indent_level=$(echo "$__FUNC_STACK" | tr -cd ',' | wc -c)
  local indent=$(printf '%*s' "$indent_level" '' | tr ' ' '  ')
  echo -e "${indent}${GRAY}<< ${BLUE}$current_func${NC}" >&2

  __FUNC_STACK="${__FUNC_STACK},<<"
}

[ -n "$DEBUG" ] && trap on_entry DEBUG && trap on_return RETURN

## Usage information, print to STDOUT
function print_usage() {
  local exit_code=${1:-0}

  echo -e "${BLUE}e-Bash Scripts Installer${NC}"
  echo ""
  echo -e "Usage: $0 [options] [command] [version]"
  echo ""
  echo -e "Options:"
  echo -e "  ${YELLOW}--dry-run${NC}             - Run in dry run mode (no changes)"
  echo -e "  ${YELLOW}--global${NC}              - Install scripts to user's '${HOME}' directory instead of current repository"
  echo -e "  ${YELLOW}--[no-]create-symlink${NC} - Create symlink to global e-bash scripts (default: true)"
  echo -e "  ${YELLOW}--force${NC}               - Force overwrite of existing scripts with auto-backup (numbered .scripts.~N~) for global install/upgrade."
  echo ""
  echo -e "Commands:"
  echo -e "  ${GREEN}install${NC}   - Install e-bash scripts (default if not already installed)"
  echo -e "  ${BLUE}upgrade${NC}   - Upgrade existing e-bash scripts"
  echo -e "  ${RED}rollback${NC}  - Rollback to previous version"
  echo -e "  ${RED}uninstall${NC} - Uninstall e-bash scripts (manual instructions)"
  echo -e "  ${PURPLE}versions${NC}  - List available local and remote versions"
  echo -e "  ${GRAY}help${NC}      - Show this help message"
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
  echo -e "  $0 help                 ${GRAY}# Show this help message${NC}"
  echo -e "  $0 --global install     ${GRAY}# Install to user's HOME directory${NC}"

  exit "${exit_code}"
}

## Automated uninstall e-bash scripts
function repo_uninstall() {
  # Temporarily disable exit on error for uninstall to be more robust
  set +e

  echo -e "${RED}=== operation: UNINSTALL ===${NC}"

  # Require --confirm flag for safety
  if [ "$CONFIRM" != true ]; then
    echo -e "${YELLOW}This will remove all e-bash files from your repository${NC}"
    echo -e "${YELLOW}Use --confirm to proceed with uninstall${NC}"
    echo ""
    echo -e "${GRAY}Example:${NC}"
    echo -e "  $0 uninstall --confirm"
    echo ""
    return 1
  fi

  # Handle global uninstall (only remove symlink)
  if [ "$GLOBAL" = true ]; then
    echo -e "${BLUE}Uninstalling global e-bash link from current project...${NC}"

    # Check if symlink exists
    if [ ! -L "${SCRIPTS_DIR}" ]; then
      echo -e "${RED}Error: No .scripts symlink found in current directory${NC}"
      echo -e "${GRAY}Nothing to uninstall${NC}"
      return 1
    fi

    # Remove symlink
    if [ "$DRY_RUN" = true ]; then
      echo -e "${CYAN}dry run: rm -f ${SCRIPTS_DIR}${NC}"
    else
      rm -f "${SCRIPTS_DIR}"
      echo -e "${GREEN}Removed .scripts symlink${NC}"
    fi

    echo -e "${GREEN}Uninstall complete!${NC}"
    echo -e "${GRAY}Note: Global installation in ${YELLOW}${GLOBAL_INSTALL_DIR}${GRAY} was not removed${NC}"
    return 0
  fi

  # Local uninstall
  echo -e "${BLUE}Uninstalling e-bash scripts from current repository...${NC}"

  # Check if e-bash is installed
  if ! is_ebash_installed; then
    echo -e "${RED}Error: e-bash is not installed in this repository${NC}"
    echo -e "${GRAY}Nothing to uninstall${NC}"
    return 1
  fi

  local uninstall_steps=0

  # Remove .scripts directory
  if [ -d "${SCRIPTS_DIR}" ] || [ -L "${SCRIPTS_DIR}" ]; then
    if [ "$DRY_RUN" = true ]; then
      echo -e "${CYAN}dry run: rm -rf ${SCRIPTS_DIR}${NC}"
    else
      rm -rf "${SCRIPTS_DIR}"
      echo -e "${GREEN}Removed ${SCRIPTS_DIR} directory${NC}"
    fi
    ((uninstall_steps++))
  fi

  # Remove previous version file
  if [ -f "${SCRIPTS_PREV_VERSION}" ]; then
    if [ "$DRY_RUN" = true ]; then
      echo -e "${CYAN}dry run: rm -f ${SCRIPTS_PREV_VERSION}${NC}"
    else
      rm -f "${SCRIPTS_PREV_VERSION}"
      echo -e "${GREEN}Removed ${SCRIPTS_PREV_VERSION} file${NC}"
    fi
    ((uninstall_steps++))
  fi

  # Remove e-bash branches
  if git rev-parse --verify "${SCRIPTS_BRANCH}" >/dev/null 2>&1; then
    if [ "$DRY_RUN" = true ]; then
      echo -e "${CYAN}dry run: git branch -D ${SCRIPTS_BRANCH}${NC}"
    else
      git branch -D "${SCRIPTS_BRANCH}" >/dev/null 2>&1 || true
      echo -e "${GREEN}Removed ${SCRIPTS_BRANCH} branch${NC}"
    fi
    ((uninstall_steps++))
  fi

  if git rev-parse --verify "${TEMP_BRANCH}" >/dev/null 2>&1; then
    if [ "$DRY_RUN" = true ]; then
      echo -e "${CYAN}dry run: git branch -D ${TEMP_BRANCH}${NC}"
    else
      git branch -D "${TEMP_BRANCH}" >/dev/null 2>&1 || true
      echo -e "${GREEN}Removed ${TEMP_BRANCH} branch${NC}"
    fi
    ((uninstall_steps++))
  fi

  # Remove e-bash remote
  if git remote | grep -q "^${REMOTE_NAME}$"; then
    if [ "$DRY_RUN" = true ]; then
      echo -e "${CYAN}dry run: git remote remove ${REMOTE_NAME}${NC}"
    else
      git remote remove "${REMOTE_NAME}"
      echo -e "${GREEN}Removed ${REMOTE_NAME} remote${NC}"
    fi
    ((uninstall_steps++))
  fi

  # Remove installation script from bin if it exists
  if [ -f "${INSTALL_SCRIPT}" ]; then
    if [ "$DRY_RUN" = true ]; then
      echo -e "${CYAN}dry run: rm -f ${INSTALL_SCRIPT}${NC}"
    else
      rm -f "${INSTALL_SCRIPT}"
      echo -e "${GREEN}Removed ${INSTALL_SCRIPT}${NC}"
    fi
    ((uninstall_steps++))
  fi

  # Clean .envrc if it exists
  if [ -f ".envrc" ]; then
    if grep -q "E_BASH\|PATH_add.*${SCRIPTS_DIR}" ".envrc"; then
      if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}dry run: clean .envrc configuration${NC}"
      else
        # Remove E_BASH related lines
        sed -i.bak '/E_BASH/d; /PATH_add.*\.scripts/d; /_setup_gnu_symbolic_links/d' ".envrc"
        rm -f ".envrc.bak"
        echo -e "${GREEN}Cleaned .envrc configuration${NC}"
      fi
      ((uninstall_steps++))
    fi
  fi

  # Clean .mise.toml if it exists
  if [ -f ".mise.toml" ]; then
    if grep -q "E_BASH" ".mise.toml"; then
      if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}dry run: clean .mise.toml configuration${NC}"
      else
        # Remove E_BASH related lines and the comment
        # Handles both [env] and [[env]] sections
        sed -i.bak '/# e-bash scripts configuration/d; /E_BASH.*\.scripts/d; /_.path.*\.scripts/d' ".mise.toml"

        # Remove empty [[env]] or [env] sections and trailing blank lines
        # Loop to handle multiple trailing empty sections at EOF
        # Note: sed with N command fails at EOF, so we use a loop with simpler patterns
        while [ -f ".mise.toml" ]; do
          local last_line=$(tail -n 1 ".mise.toml")
          if [ "$last_line" = "[[env]]" ] || [ "$last_line" = "[env]" ] || [ "$last_line" = "" ]; then
            sed -i.bak2 '${/^\[\[*env\]\]*$/d}; ${/^$/d}' ".mise.toml"
          else
            break
          fi
        done

        rm -f ".mise.toml.bak" ".mise.toml.bak2"
        echo -e "${GREEN}Cleaned .mise.toml configuration${NC}"
      fi
      ((uninstall_steps++))
    fi
  fi

  if [ $uninstall_steps -eq 0 ]; then
    echo -e "${YELLOW}No e-bash files found to remove${NC}"
  else
    echo -e "${GREEN}Uninstall complete!${NC}"
    echo -e "${GRAY}Removed $uninstall_steps e-bash component(s)${NC}"
  fi

  # Note about shell RC files
  echo ""
  echo -e "${GRAY}Note: Shell RC files were not modified${NC}"
  echo -e "${GRAY}You may have E_BASH exports that are still in use by other projects${NC}"

  # Re-enable exit on error
  set -e
  return 0
}

## Print manual instructions how to uninstall e-bash scripts
function print_manual_uninstall() {
  local exit_code=${1:-0}

  echo -e "${BLUE}Manual Uninstall Guide:${NC}"
  echo ""
  echo -e "To uninstall e-bash scripts, run the following commands one-by-one:"
  echo ""
  echo -e "  rm -rf ${SCRIPTS_DIR}                          ${GRAY}# remove ${SCRIPTS_DIR} dir${NC}"
  echo -e "  rm -rf ${SCRIPTS_PREV_VERSION}          ${GRAY}# remove ${SCRIPTS_PREV_VERSION}${NC}"
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
    echo -e "${GRAY}detected:${NC} we are in a regular folder." >&2
  elif git rev-parse --quiet --verify HEAD >/dev/null 2>&1; then
    echo -e "${GRAY}detected:${NC} repository with commits." >&2
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  else
    echo -e "${GRAY}detected:${NC} new repository with NO commits." >&2

    # Check if there's a default branch configured
    if git config init.defaultBranch >/dev/null 2>&1; then
      branch=$(git config init.defaultBranch)
    fi
  fi

  echo "$branch"
}

## Check if git is available. Exit on error.
function check_prerequisites() {
  # If git is not available, exit with error
  if ! command -v git &>/dev/null; then
    echo -e "${RED}Error: git is not installed or not in PATH${NC}" >&2
    exit 1
  fi

  # Check write permissions in current directory
  if ! check_write_permissions "."; then
    echo -e "${RED}Cannot proceed without write permissions${NC}" >&2
    exit 1
  fi

  # is any broken symlinks exist
  if [ -L "$SCRIPTS_DIR" ] && [ ! -f "$SCRIPTS_DIR/_colors.sh" ]; then
    # show user the resolution of the symbolic link
    # shellcheck disable=SC2012
    symlink=$(ls -la "${SCRIPTS_DIR}" | awk -F ' -> ' '{print $2}')
    echo -e "${GRAY}detected:${NC} broken symlink: ${YELLOW}${SCRIPTS_DIR}${NC} -> ${RED}${symlink}${NC}" >&2
    echo -e "${YELLOW}Warning: Found broken symlink to e-bash scripts directory${NC}" >&2
    echo "" >&2
    echo -e "${GRAY}Hints:${NC}" >&2
    echo -e "  rm -rf ${SCRIPTS_DIR}${NC}          ${GRAY}# remove the broken symlink${NC}" >&2
    echo -e "  mv ${SCRIPTS_DIR} ${SCRIPTS_DIR}.old${NC} ${GRAY}# rename the directory${NC}" >&2
    echo "" >&2
  fi

  # Different behavior based on --global flag
  if [ "$GLOBAL" = true ]; then
    echo -e "${BLUE}Checking prerequisites for home installation in ${YELLOW}${GLOBAL_INSTALL_DIR}${NC}" >&2

    # For global installations, we don't need to be in a git repository
    # We'll clone directly to the HOME directory later
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
      echo -e "${GRAY}Installation inside regular folder: ${YELLOW}${PWD}${NC}" >&2
    else
      # If in a git repo and using --global, warn that we're still installing to HOME
      echo -e "${GRAY}Note: Using --global will install to ${YELLOW}${GLOBAL_INSTALL_DIR}${NC}" >&2
      echo -e "${YELLOW}The current repository will NOT be modified${NC}" >&2
    fi

    # Check if global install directory exists but is not a git repo
    if [ -d "${GLOBAL_INSTALL_DIR}" ] && ! git -C "${GLOBAL_INSTALL_DIR}" rev-parse --is-inside-work-tree &>/dev/null; then
      echo -e "${RED}Error: ${GLOBAL_INSTALL_DIR} exists but is not a git repository.${NC}" >&2
      exit 1
    fi

    # If a local .scripts directory exists and --global is requested, handle conflict
    if [ -d "${SCRIPTS_DIR}" ] && [ ! -L "${SCRIPTS_DIR}" ]; then
      if [ "$FORCE" = true ]; then
        # Find next available numbered backup .scripts.~N~
        local n=1
        while [ -e ".scripts.~${n}~" ]; do
          n=$((n + 1))
        done
        echo -e "${YELLOW}--force specified: Backing up existing ${SCRIPTS_DIR} to .scripts.~${n}~${NC}"
        mv "${SCRIPTS_DIR}" ".scripts.~${n}~"
      else
        echo -e "${RED}Conflict: Local ${SCRIPTS_DIR} directory exists.${NC}"
        echo -e "To proceed with global installation, either rename your .scripts directory (e.g., to .scripts.old) and re-run this script, or use the --force flag to overwrite it (a numbered backup will be created)."
        exit 1
      fi
    fi

    return 0 # Skip other checks for global installation
  fi

  # Standard local installation checks (only when not in global mode)

  # Ensure we're in a git repository for local installations
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo -e "${RED}Error: Installation is NOT possible. Not a git repository folder: ${YELLOW}${PWD}${NC}" >&2
    echo "" >&2
    echo -e "${GRAY}Hints:${NC}" >&2
    echo -e "  You can install to \$HOME directory instead, add ${GRAY}--global${NC} option${NC}" >&2
    echo -e "  Or you can create empty git repository: ${GRAY}git init${NC}" >&2
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
    echo -e "${RED}Warning: found destination folder ${YELLOW}${SCRIPTS_DIR}${RED}. It may cause merge conflicts.${NC}"
  fi
}

## Check if e-bash scripts are already installed. Return codes: 0 - true, 1 - false
function is_ebash_installed() {
  local context="${PWD}/"
  if [ "$GLOBAL" = true ]; then
    context="${GLOBAL_INSTALL_DIR}/"
  fi

  # For local installations, check if .scripts directory exists and has _colors.sh
  if { [ -d "${context}${SCRIPTS_DIR}" ] || [ -L "${context}${SCRIPTS_DIR}" ]; } && [ -f "${context}${SCRIPTS_DIR}/_colors.sh" ]; then
    # echo -e "${GRAY}detected:${NC} e-bash scripts are already installed in ${YELLOW}${SCRIPTS_DIR}${NC}" >&2
    return 0 # true
  else
    return 1 # false
  fi
}

## Check if directory has write permissions
function check_write_permissions() {
  local test_dir="${1:-.}"

  # First check if directory exists and is writable
  if [ ! -w "$test_dir" ]; then
    echo -e "${RED}Error: Insufficient permissions to write to directory${NC}" >&2
    echo -e "${GRAY}Directory: $(cd "$test_dir" 2>/dev/null && pwd || echo "$test_dir")${NC}" >&2
    echo -e "${YELLOW}Please check directory permissions and try again${NC}" >&2
    echo -e "${GRAY}Hint: chmod +w .${NC}" >&2
    return 1
  fi

  # Also test if we can actually create a file
  local test_file="${test_dir}/.e-bash-permission-test-$$"
  if ! touch "$test_file" 2>/dev/null; then
    echo -e "${RED}Error: Insufficient permissions to write to directory${NC}" >&2
    echo -e "${GRAY}Directory: $(cd "$test_dir" 2>/dev/null && pwd || echo "$test_dir")${NC}" >&2
    echo -e "${YELLOW}Please check directory permissions and try again${NC}" >&2
    return 1
  fi

  # Clean up test file
  rm -f "$test_file" 2>/dev/null
  return 0
}

## Save the current commit hash for potential rollback
function save_current_version() {
  if is_ebash_installed; then
    git rev-parse HEAD >"${SCRIPTS_PREV_VERSION}"
    echo -e "${BLUE}Saved current version for potential rollback to ${YELLOW}${SCRIPTS_PREV_VERSION}${NC}"
  fi
}

## Check if repository remote exists, add if missing. Exit code.
function configure_remote() {
  local remote_exists
  remote_exists=$(git remote | grep -q "$REMOTE_NAME" && echo "true" || echo "false")

  if [ "$remote_exists" = "true" ]; then
    echo -e "${BLUE}Remote $REMOTE_NAME already exists. Fetching latest changes...${NC}"
    exec:git fetch "$REMOTE_NAME"
    return 0
  fi

  echo -e "${BLUE}Adding remote repository...${NC}"
  exec:git remote add --fetch "$REMOTE_NAME" "$REMOTE_URL"
  return 0
}

## Clean up existing temporary branches. Exit code.
function clean_temp_branches() {
  exec:git branch -D "$TEMP_BRANCH" 2>/dev/null || true
  exec:git branch -D "$SCRIPTS_BRANCH" 2>/dev/null || true
}

## Create temporary branch based on version. Exit code.
function create_temp_branch() {
  local version="$1"

  if [ "$version" = "$REMOTE_MASTER" ]; then
    exec:git checkout --quiet --force -b "$TEMP_BRANCH" "$REMOTE_NAME/$REMOTE_MASTER"
    return 0
  fi

  # FIXME: potentially we can have git error message that we can loose some files

  exec:git checkout --quiet -b "$TEMP_BRANCH" "$version"
  return 0
}

## Configure branches to be local-only. Exit code.
function configure_local_branches() {
  exec:git config branch."$TEMP_BRANCH".remote ""
  exec:git config branch."$SCRIPTS_BRANCH".remote ""

  echo -e "${GREEN}Created local branch '$SCRIPTS_BRANCH' with the scripts content${NC}"
  echo -e "${BLUE}Configured e-bash temporary branches to remain local only${NC}"
}

## Return to original branch if possible. Exit code.
function return_to_original_branch() {
  local has_commits
  has_commits=$(git rev-parse --quiet --verify HEAD >/dev/null 2>&1 && echo "true" || echo "false")

  if [ "$has_commits" = "true" ]; then
    exec:git checkout --quiet "$MAIN_BRANCH"
    return 0
  fi

  echo -e "${YELLOW}No commits found. Staying in current state.${NC}"
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
  SILENT_GIT=true exec:git subtree split -q -P "$SCRIPTS_DIR" -b "$SCRIPTS_BRANCH"

  # Configure branches to remain local and not be pushed to remote
  configure_local_branches

  # Return to original branch
  return_to_original_branch
}

## Display installation success message
function display_installation_success() {
  echo -e "${GREEN}Installation complete!${NC}"
  echo -e "The e-bash scripts are now available in the ${YELLOW}$SCRIPTS_DIR${NC} directory"
}

## Add e-bash scripts as a git subtree. Exit code.
function add_scripts_subtree() {
  if [ "$GLOBAL" = true ]; then
    # For global installation, we just clone the repository
    echo -e "${BLUE}Cloning e-bash repository to: ${YELLOW}${GLOBAL_INSTALL_DIR}${NC}"

    # Create the directory if it doesn't exist
    mkdir -p "${GLOBAL_INSTALL_DIR}"

    # Check if directory already has git repository
    if [ -d "${GLOBAL_INSTALL_DIR}/.git" ]; then
      echo -e "${GRAY}Git repository already exists in ${YELLOW}${GLOBAL_INSTALL_DIR}${GRAY}, updating...${NC}"

      pushd "${GLOBAL_INSTALL_DIR}" >/dev/null || exit 1
      echo -e "${CYAN}pwd: ${PWD}${NC}" >&2 # current directory changed

      exec:git pull origin master

      popd >/dev/null || exit 1
      echo -e "${CYAN}pwd: ${PWD}${NC}" >&2 # current directory changed
    else
      # Clone the repository
      exec:git clone "${REMOTE_URL}" "${GLOBAL_INSTALL_DIR}"
    fi

    return $?
  else
    # For local installation, use git subtree
    echo -e "${BLUE}Adding e-bash scripts as a git subtree...${NC}"
    exec:git subtree add --prefix "${SCRIPTS_DIR}" "${SCRIPTS_BRANCH}" --squash
    return $?
  fi
}

## Configure global installation, "$HOME/.e-bash"
function initialize_global_repo() {
  echo -e "${BLUE}Preparing e-Bash HOME installation...${NC}"

  # create .e-bash folder if it does not exist
  mkdir -p "${GLOBAL_INSTALL_DIR}"

  pushd "${GLOBAL_INSTALL_DIR}" &>/dev/null || exit 1
  echo -e "${CYAN}pwd: ${PWD}${NC}" >&2 # current directory changed

  # create git repo if it's not initialized yet
  if [[ ! -d "${GLOBAL_INSTALL_DIR}/.git" ]]; then
    exec:git init -b "${REMOTE_MASTER}" "${GLOBAL_INSTALL_DIR}"
  fi

  # register git remote if it's not registered yet, on purpose use name different from origin
  if ! (exec:git remote -v 2>/dev/null | grep "${REMOTE_NAME}"); then
    exec:git remote add "${REMOTE_NAME}" "${REMOTE_URL}"
    exec:git remote set-url --push "${REMOTE_NAME}" no_push
  fi

  # assumptions:
  # - repo stay on master branch
  # - repo not modified by user directly

  # fetch latest changes
  exec:git fetch --all

  echo -e "${BLUE}Checkout of e-bash ${PURPLE}${REMOTE_MASTER}${BLUE} branch${NC}" # latest
  exec:git checkout "${REMOTE_MASTER}"
  exec:git reset --hard "${REMOTE_NAME}/${REMOTE_MASTER}"

  # exclude VERSIONS_DIR folder from git, by updating .gitignore file (if needed)
  if ! grep "${__WORKTREES}/" .gitignore &>/dev/null; then
    if [ "$DRY_RUN" = true ]; then
      echo -e "${CYAN}dry run: modify .gitignore file to exclude ${__WORKTREES}/ sub-folder${NC}"
    else
      {
        echo ""
        echo "# exclude $__WORKTREES worktree folder from git"
        echo "$__WORKTREES/"
      } >>.gitignore
    fi
  fi

  echo -e "${BLUE}Checkout ${PURPLE}${__REPO_V1}${BLUE} first known stable version...${NC}"

  # extract version 1.0.0
  local tag_or_branch="${__REPO_V1}"
  local worktree="./${__WORKTREES}/${tag_or_branch}"
  exec:git worktree add --checkout "$worktree" "${tag_or_branch}"

  popd &>/dev/null || exit 1
  echo -e "${CYAN}pwd: ${PWD}${NC}" >&2 # current directory changed
}

## Creat a symbolic link to the .scripts folder
function create_symlink() {
  local version="${1:-master}"
  local versionedDir="${GLOBAL_INSTALL_DIR}/${__WORKTREES}/${version}"

  # Create the .scripts directory symlink in the current directory if requested
  echo -e "${BLUE}Creating symlink to global e-bash scripts version ${PURPLE}${version}${BLUE}...${NC}"

  # if requested a DRY_RUN then print the LN command without executing it
  if [ "$DRY_RUN" = true ]; then
    echo -e "${CYAN}dry run: ln -sf ${GLOBAL_INSTALL_DIR}/${SCRIPTS_DIR} ${SCRIPTS_DIR}${NC}"
    return 0
  fi

  # FIXME: only GNU LN supports --backup option, that allows to create a backup of symlink.
  #  macos version of LN does not support this option.

  local source_path
  if [ "$version" = "master" ]; then
    source_path=$(realpath "${GLOBAL_INSTALL_DIR}/${SCRIPTS_DIR}")
  else
    source_path=$(realpath "${versionedDir}/${SCRIPTS_DIR}")
  fi

  # delete old symlink if exists
  [ -L "${SCRIPTS_DIR}" ] && rm -f "${SCRIPTS_DIR}"

  # WARNING: LN for macos and linux are different, macos has limited support
  # MacOS: usage: ln [-s [-F] | -L | -P] [-f | -i] [-hnv] source_file [target_file]
  # MacOS: https://ss64.com/mac/ln.html
  # Linux: https://www.gnu.org/software/coreutils/manual/html_node/ln-invocation.html#ln-invocation
  ln -s -f "${source_path}" "${SCRIPTS_DIR}"

  # shellcheck disable=SC2012
  symlink=$(ls -la "${SCRIPTS_DIR}" | awk -F ' -> ' '{print $2}')

  # verify that we did not create a broken symlink
  if [ -L "$SCRIPTS_DIR" ] && [ ! -f "$SCRIPTS_DIR/_colors.sh" ]; then
    echo -e "${GRAY}detected:${NC} broken symlink: ${YELLOW}${SCRIPTS_DIR}${NC} -> ${RED}${symlink}${NC}" >&2
  else
    echo -e "${GREEN}Symlink created: ${YELLOW}${SCRIPTS_DIR}${NC} -> ${PURPLE}${symlink}${NC}"
  fi
}

## Make a symbolic link to global e-bash .scripts folder
function bind_ebash_global_version() {
  local version="${1:-master}"
  local worktree="./${__WORKTREES}/${version}"
  local versionedDir="${GLOBAL_INSTALL_DIR}/${__WORKTREES}/${version}"

  # jump to e-bash home dir to make a worktree extraction
  pushd "${GLOBAL_INSTALL_DIR}" &>/dev/null || exit 1
  echo -e "${CYAN}pwd: ${PWD}${NC}" >&2 # current directory changed

  # if version already pre-exists, then skip worktree add operation
  if [ "$version" = "master" ] || [ -d "$worktree" ]; then
    echo -e "${GRAY}Skipping worktree creation for ${PURPLE}${version}${GRAY} branch${NC}"
  else
    exec:git worktree add --checkout "$worktree" "$version"
  fi

  popd &>/dev/null || exit 1
  echo -e "${CYAN}pwd: ${PWD}${NC}" >&2 # current directory changed

  # create a symbolic link to the .scripts folder if allowed
  if [ "$CREATE_SYMLINK" = true ]; then
    create_symlink "$version"
  else
    echo -e "${GRAY}Skipping symlink creation for ${PURPLE}${version}${GRAY} branch${NC}" >&2
  fi
}

## Install e-bash scripts. Exit code.
function install_scripts() {
  local version="${1:-master}"

  echo -e "${BLUE}Installing e-bash scripts (version: ${PURPLE}${version}${BLUE})${NC}"

  if [ "$GLOBAL" = true ]; then # Global Installation
    # For global installation, we've already cloned the repository
    initialize_global_repo
    echo -e "${GREEN}e-Bash scripts installed globally to ${GLOBAL_INSTALL_DIR}${NC}"

    # if we have version that is matching a specific version, bind it
    bind_ebash_global_version "$version"

    # Perform post-installation steps for global install
    post_installation_steps_global "$version" # global changes
    post_installation_steps                   # local changes

    echo ""
    echo -e "${GRAY}Note:${NC} You may need to restart your shell or run '${GRAY}source ~/.${SHELL##*/}rc${NC}' to apply the changes"
    echo ""

  else # Local Installation
    setup_remote "$version"

    # Validate version
    if ! validate_version "$version"; then
      echo -e "${RED}Error: Invalid version '$version'${NC}"
      return 1
    fi

    # Add scripts as a subtree
    if ! add_scripts_subtree; then
      echo -e "${RED}Failed to add e-bash scripts as subtree${NC}"
      return 1
    fi

    # Post-installation customization
    post_installation_steps
  fi

  display_installation_success
  return 0
}

## Perform post-installation customizations
function post_installation_steps() {
  echo -e "${BLUE}Performing post-installation steps: [integrate with DIRENV/MISE], [copy installer to bin]${NC}"

  # Check for .envrc file and update it if found
  if [ -f ".envrc" ] && [ "$DRY_RUN" == false ]; then
    update_envrc_configuration
  else
    local prefix=""
    [ "$DRY_RUN" == true ] && prefix="${CYAN}dry run: ${NC}"
    echo -e "${prefix}${GRAY}Skipping DIRENV integration. No ${YELLOW}${PWD}/.envrc${GRAY} file.${NC}" >&2
  fi

  # Check for .mise.toml file and update it if found
  if [ -f ".mise.toml" ] && [ "$DRY_RUN" == false ]; then
    update_mise_configuration
  else
    local prefix=""
    [ "$DRY_RUN" == true ] && prefix="${CYAN}dry run: ${NC}"
    echo -e "${prefix}${GRAY}Skipping MISE integration. No ${YELLOW}${PWD}/.mise.toml${GRAY} file.${NC}" >&2
  fi

  # Check for bin directory and copy installer script
  if [ -d "bin" ] && [ "$DRY_RUN" == false ]; then
    copy_installer_to_bin
  else
    local prefix=""
    [ "$DRY_RUN" == true ] && prefix="${CYAN}dry run: ${NC}"
    echo -e "${prefix}${GRAY}Skipping installer script copy. No ${YELLOW}${PWD}/bin${GRAY} directory.${NC}" >&2
  fi
}

## Perform post-installation customizations for global install
function post_installation_steps_global() {
  local version="$1"

  echo -e "${BLUE}Performing post-installation steps for global installation: [global export E_BASH]${NC}"

  # Add global e-bash directory to PATH if needed
  local shell="${SHELL##*/}"
  local shellrc="${HOME}/.${shell}rc"

  # For 'master' version, use direct path; for tagged versions, use versioned path
  local ver_dir
  if [ "$version" = "master" ]; then
    ver_dir="\${HOME}/${__GLOBAL_DIR}"
  else
    ver_dir="\${HOME}/${__GLOBAL_DIR}/${__WORKTREES}/${version}"
  fi

  # Configure E_BASH environment variable
  local env_line="export E_BASH=\"${ver_dir}/${SCRIPTS_DIR}\""

  # Add to .bashrc if it exists
  if [ -f "$shellrc" ] && [ "$DRY_RUN" == false ]; then
    if ! grep -q "export E_BASH=" "$shellrc"; then
      echo -e "${BLUE}Adding E_BASH environment variable to ${shellrc}...${NC}"
      {
        echo ""
        echo "# e-Bash scripts configuration"
        echo "$env_line"
      } >>"$shellrc"
      echo -e "${GREEN}E_BASH points to ${YELLOW}${ver_dir}/${SCRIPTS_DIR}${NC}"
    else
      echo -e "${GRAY}Skipping E_BASH export, export already exists in ${YELLOW}${shellrc}${NC}"
      local found_line=$(grep "export E_BASH=" "$shellrc" | head -1)

      if [ "${found_line}" != "${env_line}" ]; then
        echo -e "${GRAY}You can add/edit manually: ${YELLOW}${env_line}${NC}"
        echo -n "Found: " >&2
        grep "export E_BASH=" "$shellrc" >&2
      fi
    fi
  else
    local prefix=""
    [ "$DRY_RUN" == true ] && prefix="${CYAN}dry run: ${NC}"
    echo -e "${prefix}${GRAY}Skipping E_BASH export configuration. No ${YELLOW}${shellrc}${GRAY} file.${NC}" >&2
  fi
}

## Append e-bash configuration to .envrc file. Exit code.
function update_envrc_configuration() {
  # Check if our configuration is already in .envrc
  if grep -q "export E_BASH=" ".envrc"; then
    echo -e "${GRAY}Skipping DIRENV integration. Configuration already exists in ${YELLOW}${PWD}/.envrc${NC}"
    return 0
  fi

  # Append our configuration to .envrc
  {
    echo ""
    echo "#"
    echo "# Add scripts to PATH for simpler run"
    echo "#"
    echo "PATH_add \"\$PWD/${SCRIPTS_DIR}\""
    echo "#"
    echo "# Make global variable for all scripts, declare before any source ..."
    echo "#"
    echo "export E_BASH=\"\$(pwd)/${SCRIPTS_DIR}\""
    echo "#"
    echo "# Set up Linux-specific aliases for GNU tools"
    echo "#"
    echo "if [[ \"\$(uname -s)\" == \"Linux\" ]]; then"
    # FIXME: This source command assumes the script exists but doesn't check.
    #   We rely on sequence of actions, assuming that its a post-installation step.
    echo "  source \"\$PWD/${SCRIPTS_DIR}/_setup_gnu_symbolic_links.sh\""
    # `bin` folder may not exist, but _setup_gnu_symbolic_links.sh will create it
    echo "  PATH_add \"\$PWD/bin/gnubin\""
    echo "fi"
  } >>".envrc"

  echo -e "${GREEN}Added e-bash configuration to ${YELLOW}${PWD}/.envrc${NC}"
  echo -e "${YELLOW}Run 'direnv allow' to apply the changes${NC}"
  return 0
}

## Append e-bash configuration to mise.toml file. Exit code.
function update_mise_configuration() {
  # Helper: Read value from [env] or [[env]] section
  get_mise_env_value() {
    local key="$1"
    # Check both [env] and [[env]] sections
    # Fixed regex: \]* at end (not \]\]) to match both [env] and [[env]]
    sed -n '/^\[\[*env\]\]*$/,/^\[/p' ".mise.toml" | \
      grep "^${key}[[:space:]]*=" | \
      head -1 | \
      cut -d'=' -f2- | \
      sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
  }

  # Check if E_BASH is already configured in any [env] or [[env]] section
  if [ -f ".mise.toml" ]; then
    local existing_value=$(get_mise_env_value "E_BASH")
    if [ -n "$existing_value" ]; then
      echo -e "${GRAY}Skipping MISE integration. E_BASH already configured in ${YELLOW}${PWD}/.mise.toml${NC}"
      return 0
    fi
  fi

  # Determine the type of env section that exists
  local has_env_table=false       # [env] - single table
  local has_env_array=false       # [[env]] - array of tables

  if [ -f ".mise.toml" ]; then
    grep -q "^\\[env\\]" ".mise.toml" && has_env_table=true
    grep -q "^\\[\\[env\\]\\]" ".mise.toml" && has_env_array=true
  fi

  # Append configuration based on existing structure
  if [ "$has_env_array" = true ]; then
    # Append new [[env]] array entry to end of file
    {
      echo ""
      echo "# e-bash scripts configuration"
      echo "[[env]]"
      echo "E_BASH = \"{{config_root}}/${SCRIPTS_DIR}\""
      echo "_.path = [\"{{config_root}}/${SCRIPTS_DIR}\", \"{{config_root}}/bin\"]"
    } >>".mise.toml"
    echo -e "${GREEN}Added e-bash configuration as new [[env]] entry in ${YELLOW}${PWD}/.mise.toml${NC}"
  elif [ "$has_env_table" = true ]; then
    # Insert into existing [env] section (before next section or EOF)
    # Find the line number where [env] section ends
    local env_end=$(awk '/^\[env\]/{start=NR; next} start && /^\[/{print NR-1; found=1; exit} END{if(start && !found) print NR}' ".mise.toml")

    # Create temp file with insertion
    {
      head -n "$env_end" ".mise.toml"
      echo "# e-bash scripts configuration"
      echo "E_BASH = \"{{config_root}}/${SCRIPTS_DIR}\""
      echo "_.path = [\"{{config_root}}/${SCRIPTS_DIR}\", \"{{config_root}}/bin\"]"
      tail -n +$((env_end + 1)) ".mise.toml"
    } > ".mise.toml.tmp"

    mv ".mise.toml.tmp" ".mise.toml"
    echo -e "${GREEN}Added e-bash configuration to existing [env] section in ${YELLOW}${PWD}/.mise.toml${NC}"
  else
    # Create new [env] table (prefer single table for simplicity)
    {
      echo ""
      echo "# e-bash scripts configuration"
      echo "[env]"
      echo "E_BASH = \"{{config_root}}/${SCRIPTS_DIR}\""
      echo "_.path = [\"{{config_root}}/${SCRIPTS_DIR}\", \"{{config_root}}/bin\"]"
    } >>".mise.toml"
    echo -e "${GREEN}Added e-bash configuration to ${YELLOW}${PWD}/.mise.toml${NC}"
  fi

  echo -e "${YELLOW}Run 'mise trust' to apply the changes${NC}"
  return 0
}

## Download installation script to bin directory. Exit code.
function copy_installer_to_bin() {
  # Check if we can download the script
  local has_curl
  local has_wget

  has_curl="$(command -v curl &>/dev/null && echo "true" || echo "false")"
  has_wget="$(command -v wget &>/dev/null && echo "true" || echo "false")"

  echo -e "${BLUE}Downloading installation script: ${YELLOW}${REMOTE_INSTALL_SH}${NC}"

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
    echo -e "${GRAY}Failed to download script, copying self instead${NC}"
    # we can copy itself to the bin directory
    cp "$0" "bin/install.e-bash.sh"
  fi

  # Set executable attribute if file exists
  [ -f "bin/install.e-bash.sh" ] && chmod +x "bin/install.e-bash.sh"

  echo -e "${GREEN}Placed installation script to ${YELLOW}${PWD}/bin/install.e-bash.sh${NC}"
  return 0
}

## Perform the subtree merge operation for upgrade. Exit code.
function perform_subtree_merge() {
  echo -e "${BLUE}Pulling latest scripts and merge...${NC}"

  # FIXME: Subtree merge might fail if there are conflicts with local changes

  # For git subtree pull, we need to reference the local branch
  # This is not a remote pull, but rather merging from the local branch
  set +e
  exec:git subtree merge --prefix="$SCRIPTS_DIR" "$SCRIPTS_BRANCH" --squash
  result=$?
  set -e

  if [ "$result" -ne 0 ]; then
    echo -e "${RED}Error: Merge problems detected. Please uninstall manually and repeat the installation.${NC}"
    echo ""
    echo "${BLUE}Resolve Conflict by Aborting GIT Merge:${NC}"
    echo ""
    echo "  git merge --abort ${GRAY}# abort the merge operation${NC}"
    echo ""

    print_manual_uninstall $result # abort execution with custom exit code
  fi

  return $result
}

## Compose README.md file with e-bash installation instructions
function compose_readme() {
  {
    echo "# e-Bash Scripts"
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

## Check and configure git user settings for commit
function ensure_git_user_config() {
  local user_name user_email

  # Check if git user.name is configured
  user_name=$(git config user.name 2>/dev/null || true)
  user_email=$(git config user.email 2>/dev/null || true)

  if [ -z "$user_name" ] || [ -z "$user_email" ]; then
    echo -e "${YELLOW}Git user configuration missing. Setting temporary config for initial commit...${NC}" >&2
    echo -e "${YELLOW}Git user: ${user_name:-"<empty>"}, email: ${user_email:-"<empty>"}${NC}" >&2

    # Set temporary local git config for this repository only
    if [ -z "$user_name" ]; then
      exec:git config user.name "e-Bash Installer" || return 1
    fi

    if [ -z "$user_email" ]; then
      exec:git config user.email "installer@e-bash.local" || return 1
    fi

    echo -e "${YELLOW}Note: These settings are local to this repository only.${NC}" >&2
    echo -e "${YELLOW}To configure global git settings, run:${NC}" >&2
    echo -e "${CYAN}  git config --global user.name \"Your Name\"${NC}" >&2
    echo -e "${CYAN}  git config --global user.email \"your.email@example.com\"${NC}" >&2
  fi

  return 0
}

## Initialize empty repository
function initialize_empty_repository() {
  # for global installation we skip initialization of repository in current dir
  if [ "$GLOBAL" = true ]; then return 0; fi

  # Check if repository is already initialized
  if git rev-parse --quiet --verify HEAD &>/dev/null; then return 0; fi

  echo -e "${YELLOW}Empty repository detected. Creating initial commit...${NC}" >&2

  # Create README.md if it doesn't exist
  if [ ! -f "README.md" ]; then compose_readme; fi

  # Initialize the repository with the README
  SILENT_GIT=true exec:git add README.md

  # Ensure git user configuration is available for commit
  if ! ensure_git_user_config; then
    echo -e "${RED}Failed to configure git user settings${NC}" >&2
    return 1
  fi

  # Create the initial commit
  SILENT_GIT=true exec:git commit -m "Initial commit before installing e-bash scripts"
  local commit_result=$?

  if [ $commit_result -ne 0 ]; then
    echo -e "${RED}Failed to create initial commit (exit code: $commit_result)${NC}" >&2
    return $commit_result
  fi

  # Update MAIN_BRANCH after initial commit
  MAIN_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
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
  exec:git branch

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

  if [ "$GLOBAL" = true ]; then
    echo -e "${BLUE}Upgrading global e-bash installation to version: ${PURPLE}${version}${NC}"

    # Ensure global directory exists and is initialized
    if [ ! -d "${GLOBAL_INSTALL_DIR}/.git" ]; then
      echo -e "${RED}Error: Global e-bash installation not found at ${GLOBAL_INSTALL_DIR}${NC}"
      echo -e "${YELLOW}Run: $0 install ${version} --global${NC}"
      exit $EXIT_NO
    fi

    # Update the global repository
    pushd "${GLOBAL_INSTALL_DIR}" &>/dev/null || exit 1
    echo -e "${CYAN}pwd: ${PWD}${NC}" >&2

    # Fetch latest changes from remote
    exec:git fetch --all

    # Update master branch to latest
    exec:git checkout "${REMOTE_MASTER}"
    exec:git reset --hard "${REMOTE_NAME}/${REMOTE_MASTER}"

    popd &>/dev/null || exit 1
    echo -e "${CYAN}pwd: ${PWD}${NC}" >&2

    # Bind the requested version (creates worktree and symlink)
    bind_ebash_global_version "$version"

    echo -e "${GREEN}Global e-bash upgrade complete!${NC}"
    echo -e "The e-bash scripts have been upgraded to version ${PURPLE}${version}${NC}"
    #echo -e "Symlink updated: ${CYAN}${SCRIPTS_DIR}${NC} -> ${CYAN}${GLOBAL_INSTALL_DIR}/${__WORKTREES}/${version}${NC}"
  else
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
  fi

  # Run post-installation steps
  post_installation_steps

  return 0
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

  # Validate that previous_version is not empty and has valid format
  if [ -z "$previous_version" ] || [ "${#previous_version}" -lt 6 ]; then
    echo -e "${RED}Error: Previous version file is empty or invalid${NC}" >&2
    echo -e "${GRAY}File: ${SCRIPTS_PREV_VERSION}${NC}" >&2
    return 1
  fi

  # Validate format: should be alphanumeric with optional dots, dashes, underscores (for tags/hashes)
  if ! [[ "$previous_version" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo -e "${RED}Error: Previous version file is empty or invalid${NC}" >&2
    echo -e "${GRAY}Invalid format: ${previous_version}${NC}" >&2
    return 1
  fi

  # Validate that the commit/tag exists in git
  if ! git rev-parse --verify "${previous_version}^{commit}" >/dev/null 2>&1; then
    echo -e "${RED}Error: Previous version commit no longer exists${NC}" >&2
    echo -e "${GRAY}Version: ${previous_version}${NC}" >&2
    echo -e "${YELLOW}The commit may have been garbage collected or the repository history was rewritten${NC}" >&2
    return 1
  fi

  echo -e "${BLUE}Found previous version: $previous_version${NC}" >&2
  echo "$previous_version"
}

## Perform the actual rollback operation. Exit code.
function perform_rollback() {
  local previous_version=$1

  echo -e "${RED}Rolling back to previous version: $previous_version${NC}"
  # FIXME: Checkout will fail if the commit no longer exists (e.g., after garbage collection)
  exec:git checkout "$previous_version" -- "$SCRIPTS_DIR"

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

## Get current version of installed e-bash (symbolic link or git branch)
function get_installed_version() {
  local current_version="none"
  local branch_hash="" hash

  # Check if the .scripts directory is a symbolic link
  if [ -L "$SCRIPTS_DIR" ]; then
    resolved_symlink="$(readlink -f "$SCRIPTS_DIR")"

    # if resolved_symlink contains '.versions' and '.scripts' - then specific version installed,
    # otherwise we have a 'master' binded to the .scripts

    if [[ "$resolved_symlink" == *"${__WORKTREES}"* && "$resolved_symlink" == *"${SCRIPTS_DIR}"* ]]; then
      # Extract version from the resolved symlink
      current_version="$(echo "$resolved_symlink" | sed -E 's/\/.scripts$//g; s/^.*\/.versions\///g')"
    else
      current_version="${REMOTE_MASTER}"
    fi

    echo "$current_version"
    return 0
  fi

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

  # NOTE: 'master' is the only one allowed branch name
  if [ "$version" = "$REMOTE_MASTER" ]; then
    if ! exec:git ls-remote --heads $REMOTE_URL 2>&1 | grep -q "$REMOTE_MASTER"; then
      echo -e "${RED}Error: Version ${PURPLE}$version${RED} does not exist in remote${NC}"
      return 1
    fi

    return 0
  fi

  if ! exec:git ls-remote --tags $REMOTE_URL 2>&1 | grep -q "refs/tags/$version"; then
    echo -e "${RED}Error: Version ${PURPLE}$version${RED} does not exist in remote${NC}"
    return 1
  fi

  return 0
}

## Updated git command execution
SILENT_GIT=false
function exec:git() {
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
  echo -e " / code: ${YELLOW}$result${NC}" >&2
  [ -n "$output" ] && [ "$SILENT_GIT" = false ] && echo -e "$output" >&2

  [ "$immediate_exit_on_error" = "true" ] && set -e # recover state
  return $result
}

## Install e-bash scripts
function repo_install() {
  local version="${1:-master}"

  check_prerequisites

  # Initialize empty repository if needed before installation
  initialize_empty_repository

  if is_ebash_installed; then
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

  if ! is_ebash_installed; then
    echo -e "${YELLOW}e-bash scripts not installed. Installing instead.${NC}"
    install_scripts "$version"
  else
    upgrade_scripts "$version"
  fi

}

## Rollback to previous version
function repo_rollback() {
  local target_version="${1:-}"
  local previous_version=""
  local rollback_status=0

  check_prerequisites

  echo -e "${RED}=== operation: ROLLBACK ===${NC}"

  # Handle global rollback differently
  if [ "$GLOBAL" = true ]; then
    echo -e "${BLUE}Rolling back global e-bash installation...${NC}"

    # Check if global installation exists
    if [ ! -d "${GLOBAL_INSTALL_DIR}/.git" ]; then
      echo -e "${RED}Error: Global e-bash installation not found at ${GLOBAL_INSTALL_DIR}${NC}"
      echo -e "${YELLOW}Run: $0 install --global${NC}"
      return 1
    fi

    # Require version to be specified for global rollback
    if [ -z "$target_version" ] || [ "$target_version" = "master" ]; then
      # If no version specified, try to use master as default
      if [ -z "$target_version" ]; then
        echo -e "${YELLOW}No version specified. Using 'master' as default.${NC}"
        target_version="master"
      fi
    fi

    # Validate version exists
    if [ "$target_version" != "master" ]; then
      # Check if worktree exists for tagged version
      if [ ! -d "${GLOBAL_INSTALL_DIR}/${__WORKTREES}/${target_version}" ]; then
        # Try to create it
        pushd "${GLOBAL_INSTALL_DIR}" &>/dev/null || return 1

        # Check if tag exists in git
        if ! git rev-parse --verify "${target_version}" >/dev/null 2>&1; then
          popd &>/dev/null
          echo -e "${RED}Error: Version ${target_version} not found in global installation${NC}"
          echo -e "${YELLOW}Run: $0 versions --global to see available versions${NC}"
          return 1
        fi

        popd &>/dev/null
      fi
    fi

    # Perform rollback by updating symlink
    echo -e "${BLUE}Switching to version: ${PURPLE}${target_version}${NC}"
    bind_ebash_global_version "$target_version"

    echo -e "${GREEN}Rollback complete!${NC}"
    echo -e "The e-bash scripts have been rolled back to version ${PURPLE}${target_version}${NC}"
    return 0
  fi

  # Local rollback (existing logic)

  # Check if previous version exists
  check_previous_version_exists
  if [ $? -ne 0 ]; then return 1; fi

  # Get the previous version (with validation)
  previous_version=$(get_previous_version)
  if [ $? -ne 0 ]; then
    echo -e "${RED}Cannot proceed with rollback${NC}"
    return 1
  fi

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
  echo -e "${BLUE}Show available versions...${NC}"

  local has_remote has_git_repo has_global_install reason=""
  local current_version="none" local_status
  local global_versions="none" global_installed=false
  local all_remote_tags
  local stable_tags non_stable_tags
  local latest_version
  local is_master=false
  local master_status=""

  # Fetch tags from remote repository
  has_git_repo=$(git rev-parse --is-inside-work-tree 2>/dev/null && echo "true" || echo "false")
  has_remote=$(git remote 2>/dev/null | grep -q "$REMOTE_NAME" && echo "true" || echo "false")
  has_global_install=$([ -d "$GLOBAL_INSTALL_DIR/.git" ] && echo "true" || echo "false")

  if [ "$has_git_repo" = "false" ]; then
    reason=", not a git repository"
  elif [ "$has_remote" = "true" ]; then
    echo -e "${GRAY}detected:${NC} repository with e-bash remotes, updating remote tags..."
    # Fetch tags, but don't fail if there are conflicts
    exec:git fetch "$REMOTE_NAME" --tags || true
  fi

  # Determine current version if installed
  if is_ebash_installed; then
    local_status=$([ -L "$SCRIPTS_DIR" ] && echo " ${CYAN}[symlink]${NC}" || echo "")
    current_version=$(get_installed_version)
  fi

  # Check for global installation, and extract globally available versions
  if [ "$has_global_install" = "true" ]; then
    global_installed=true
    # Switch to global directory to get available versions
    pushd "${GLOBAL_INSTALL_DIR}" >/dev/null || exit 1

    # we have MASTER as root of the dir and extracted versions inside `.versions` folder
    # MASTER - can be outdated, so we need to detect it state properly
    # First number: commits in remote not in local (if > 0, branch is outdated)
    # Second number: commits in local not in remote (if > 0, branch is behind)
    # shellcheck disable=SC1083
    master_version_state=$(git fetch &&
      git rev-list --count --left-right @{upstream}...HEAD |
      awk '{if($1>0) print "outdated by "$1" commit(s)"; else print "up-to-date"}')

    master_version="master ${GRAY}($master_version_state)${PURPLE}"
    global_versions="${PURPLE}${master_version}\n$(ls .versions)${NC}"
    popd >/dev/null || exit 1
  fi

  # Get all tags from remote
  all_remote_tags=$(git ls-remote --tags "$REMOTE_URL" |
    grep -o 'refs/tags/v[0-9]\+\.[0-9]\+\.[0-9]\+.*$' |
    sed 's|refs/tags/||')

  # Separate stable and non-stable version tags
  stable_tags=$(echo "$all_remote_tags" | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' || echo "")
  non_stable_tags=$(echo "$all_remote_tags" | grep -v -E '^v[0-9]+\.[0-9]+\.[0-9]+$' || echo "")

  # Identify latest stable version
  latest_version=$(echo "$stable_tags" | sort -V | tail -n 1)

  # First display information about home installation
  echo ""
  echo -e "${GREEN}Installed in \$HOME directory (${YELLOW}${GLOBAL_INSTALL_DIR}${GREEN}):${NC}"
  if [ "$global_installed" = true ]; then
    echo -e "$global_versions"
  else
    echo -e "${YELLOW}Not installed in home directory${NC}"
  fi

  # Now display information about local installation
  echo ""
  echo -e "${GREEN}Installed in current repository (${YELLOW}${PWD}${GREEN}):${NC}"
  if is_ebash_installed; then
    echo -e "${PURPLE}${current_version}${local_status}${NC}"
  else
    echo -e "${YELLOW}Not installed in current repository${reason}${NC}"
  fi

  # List versions matching v{semver} pattern (e.g., v1.0.0)
  echo ""
  echo -e "${GREEN}Available remote stable versions (${YELLOW}${REMOTE_URL}${GREEN}):${NC}"

  # Check if current version is master and display with indicators
  [[ "$current_version" == master* ]] && is_master=true
  [ "$is_master" = true ] && master_status=" ${GREEN}[CURRENT]${NC}"

  # Display master branch with appropriate status
  echo -e "${PURPLE}master${NC} - Development version (alias: ${PURPLE}latest${NC})${master_status}"

  # Display all stable versions with highlights
  if [ -n "$stable_tags" ]; then
    echo "$stable_tags" | sort -V | while read -r version; do
      local version_status=""
      [ "$version" = "$current_version" ] && version_status=" ${GREEN}[CURRENT]${NC}"
      [ "$version" = "$latest_version" ] && version_status="${version_status} ${YELLOW}[LAST]${NC}"

      echo -e "${PURPLE}${version}${NC}${version_status}"
    done
  else
    echo -e "${YELLOW}No stable version tags found${NC}"
  fi

  # Display non-stable versions (pre-releases, etc.)
  if [ -z "$non_stable_tags" ]; then return 0; fi

  echo ""
  echo -e "${GREEN}Available remote non-stable versions (pre-releases, development):${NC}"
  echo "$non_stable_tags" | sort -V | while read -r version; do
    local version_status=""
    [ "$version" = "$current_version" ] && version_status=" ${GREEN}[CURRENT]${NC}"

    echo -e "${PURPLE}${version}${NC}${version_status}"
  done
}

## Main function
function main_ebash() {
  local args="$*"
  # if $args are empty, print <empty>
  [ -z "$args" ] && args="<empty>"
  
  local command="${1:-auto}"
  local version="${2:-master}"
  
  # Always show the main installer message
  echo -e "${PURPLE}installer: e-bash scripts, arguments: ${GRAY}$args${NC}" >&2

  # Process version to handle aliases like 'latest' -> 'master'
  [ "$version" = "latest" ] && version="master"

  # If command is "auto", determine whether to install or upgrade
  if [ "$command" == "auto" ]; then
    if is_ebash_installed; then
      command="upgrade"
      echo -e "${GRAY}detected:${NC} e-bash scripts already installed. Switching to '${BLUE}upgrade${NC}' mode." >&2
    else
      command="install"
      echo -e "${GRAY}detected:${NC} e-bash scripts not installed (or broken). Switching to '${GREEN}install${NC}' mode." >&2
    fi
  fi

  [ "$DRY_RUN" = true ] && echo -e "${GRAY}Dry Run mode. No changes will be applied.${NC}"

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
    repo_rollback "$version"
    ;;
  "versions")
    repo_versions
    ;;
  "uninstall")
    repo_uninstall
    ;;
  "help" | "-h" | "--help")
    print_usage $EXIT_OK
    ;;
  *)
    echo -e "${RED}Unknown command: $command${NC}"
    print_usage $EXIT_NO
    ;;
  esac
}

## Pre-parse arguments for special flags before main processing.
function preparse_args() {
  local args=("$@")

  for i in "${!args[@]}"; do
    key="${args[i]}"

    if [[ "$key" == "--dry-run" ]]; then
      DRY_RUN=true && unset 'args[i]'
    elif [[ "$key" == "--force" || "$key" == "-f" ]]; then
      FORCE=true && unset 'args[i]'
    elif [[ "$key" == "--global" ]]; then
      GLOBAL=true && unset 'args[i]'
    elif [[ "$key" == "--create-symlink" ]]; then
      CREATE_SYMLINK=true && unset 'args[i]'
    elif [[ "$key" == "--no-create-symlink" ]]; then
      CREATE_SYMLINK=false && unset 'args[i]'
    elif [[ "$key" == "--confirm" ]]; then
      CONFIRM=true && unset 'args[i]'
    elif [[ "$key" == "--silent" ]]; then
      # --silent flag is deprecated - script is polished by default
      unset 'args[i]'
    elif [[ "$key" == "--help" ]]; then
      print_usage $EXIT_OK
    fi
  done

  # if DEBUG variable set, print diagnostic report
  if [ -n "$DEBUG" ]; then
    [ "$DRY_RUN" = true ] && echo -e "${GRAY}dry run mode ON    : ${DRY_RUN}${NC}" >&2
    [ "$FORCE" = true ] && echo -e "${GRAY}forced override    : ${FORCE}${NC}" >&2
    [ "$GLOBAL" = true ] && echo -e "${GRAY}global installation: ${GLOBAL}${NC}" >&2
    [ "$CREATE_SYMLINK" = true ] && echo -e "${GRAY}create symlink     : ${CREATE_SYMLINK}${NC}" >&2
  fi

  # Return remaining arguments
  # shellcheck disable=SC2206
  ARGS=(${args[@]})
}

# Process special flags
preparse_args "$@"

# Execute main function with all passed arguments
main_ebash "${ARGS[@]}"

# [TEST SCENARIOS](../docs/installation.md)
# [UNIT TESTS](../spec/installation_spec.sh)
