#!/usr/bin/env bash
# shellcheck disable=SC2155,SC1090,SC2034,SC2059

## Git SSH Key Setup Helper
## Configure a per-repo SSH key: paste keys, set permissions, update git config.
##
## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-04-13
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# Setup terminal
if [[ -z $TERM ]]; then export TERM=xterm-256color; fi

# Skip automatic argument parsing during module loading
export SKIP_ARGS_PARSING=1

# Bootstrap: 1) E_BASH discovery (only if not set), 2) gnubin setup (always)
[ "$E_BASH" ] || { _src=${BASH_SOURCE:-$0}; E_BASH=$(cd "${_src%/*}/../.scripts" 2>&- && pwd || echo ~/.e-bash/.scripts); readonly E_BASH; }
. "$E_BASH/_gnu.sh"; PATH="$(cd "$E_BASH/../bin/gnubin" 2>&- && pwd):$PATH"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_VERSION="1.0.0"

# Import e-bash modules
# shellcheck source=../.scripts/_colors.sh
source "$E_BASH/_colors.sh"
# shellcheck source=../.scripts/_logger.sh
source "$E_BASH/_logger.sh"
# shellcheck source=../.scripts/_commons.sh
source "$E_BASH/_commons.sh"
# shellcheck source=../.scripts/_dependencies.sh
source "$E_BASH/_dependencies.sh"
# shellcheck source=../.scripts/_dryrun.sh
source "$E_BASH/_dryrun.sh"
# shellcheck source=../.scripts/_arguments.sh
source "$E_BASH/_arguments.sh"

# Exit codes
readonly EXIT_OK=0
readonly EXIT_ERROR=1
readonly EXIT_CANCELLED=2

# Defaults
declare help SECRETS_DIR KEY_NAME DRY_RUN FORCE

SECRETS_DIR=${SECRETS_DIR:-.secrets}
KEY_NAME=${KEY_NAME:-id_ed25519}
DRY_RUN=${DRY_RUN:-false}
FORCE=${FORCE:-false}
DEBUG=${DEBUG:-"ssh,step,-common,-loader,-parser,-tui"}

# Step counter
TOTAL_STEPS=5

# ── Functions ────────────────────────────────────────

##
## Print step header with counter
##
function step:header() {
  local step=$1 label=$2
  echo:Step ""
  echo:Step "${cl_blue}[${step}/${TOTAL_STEPS}]${cl_reset} ${cl_bold}${label}${cl_reset}"
}

##
## Detect git host and user from origin remote URL
##
## Globals:
## - mutate/publish: GIT_HOST, GIT_USER
##
function detect:remote() {
  GIT_HOST="github.com"
  GIT_USER="git"

  local origin_url
  origin_url=$(run:git remote get-url origin 2>/dev/null || echo "")
  [[ -z "$origin_url" ]] && return 1

  if [[ "$origin_url" =~ ^[a-z]+@([^:]+): ]]; then
    GIT_HOST="${BASH_REMATCH[1]}"
    GIT_USER="${origin_url%%@*}"
  elif [[ "$origin_url" =~ ^ssh://([^@]+)@([^/]+) ]]; then
    GIT_USER="${BASH_REMATCH[1]}"
    GIT_HOST="${BASH_REMATCH[2]}"
  fi

  echo:Ssh "Detected from origin: ${cl_bold}${GIT_USER}@${GIT_HOST}${cl_reset}"
  return 0
}

##
## Prompt user for git host and user, with auto-detected defaults
##
## Globals:
## - mutate/publish: GIT_HOST, GIT_USER
##
function prompt:remote() {
  local input_host input_user

  read -rp "  Git host [${GIT_HOST}]: " input_host
  [[ -n "$input_host" ]] && GIT_HOST="$input_host"

  read -rp "  Git user [${GIT_USER}]: " input_user
  [[ -n "$input_user" ]] && GIT_USER="$input_user"

  echo:Step "  ${cl_green}✓${cl_reset} Host: ${GIT_USER}@${GIT_HOST}"
}

##
## Prompt user for SSH private key via multiline editor
##
## Returns:
## - 0 on success (key captured)
## - 1 on cancel or empty
## - Echoes captured key to stdout
##
function prompt:private-key() {
  echo:Step "  Paste your SSH private key below (Ctrl+D to save, Esc to cancel):"
  echo ""

  local key
  key=$(input:multi-line -m stream -h 8 --no-status)
  local exit_code=$?

  if [[ $exit_code -ne 0 ]] || [[ -z "$key" ]]; then
    echo ""
    echo:Step "  ${cl_red}✗${cl_reset} No private key provided."
    return 1
  fi

  # Validate PEM format
  if [[ ! "$key" =~ ^-----BEGIN ]]; then
    echo:Step "  ${cl_yellow}!${cl_reset} Key doesn't start with '-----BEGIN'. Might not be a valid PEM key."
    local proceed
    read -rp "  Continue anyway? [y/N]: " proceed
    [[ "$proceed" =~ ^[Yy] ]] || return 1
  fi

  echo ""
  local lines
  lines=$(echo "$key" | wc -l | tr -d ' ')
  echo:Step "  ${cl_green}✓${cl_reset} Private key received (${lines} lines)"
  echo "$key"
  return 0
}

##
## Prompt user for SSH public key via multiline editor (optional)
##
## Returns:
## - 0 on success (key captured)
## - 1 on skip/cancel
## - Echoes captured key to stdout
##
function prompt:public-key() {
  echo:Step "  Paste public key below, or press Esc to skip:"
  echo ""

  local key
  key=$(input:multi-line -m stream -h 3 --no-status)
  local exit_code=$?

  echo ""
  if [[ $exit_code -ne 0 ]] || [[ -z "$key" ]]; then
    echo:Ssh "Skipped public key."
    return 1
  fi

  echo:Step "  ${cl_green}✓${cl_reset} Public key received"
  echo "$key"
  return 0
}

##
## Write key file with specified permissions
##
## Parameters:
## - file_path - Destination path, string, required
## - content - Key content, string, required
## - mode - File permissions, string, required (e.g. "600")
## - label - Display label, string, required
##
function write:key-file() {
  local file_path="$1" content="$2" mode="$3" label="$4"

  if [[ "$DRY_RUN" == "true" || "$DRY_RUN" == "1" ]]; then
    local lines
    lines=$(echo "$content" | wc -l | tr -d ' ')
    echo:Ssh "dry run: write ${file_path} (${lines} lines, mode ${mode})"
  else
    printf "%s\n" "$content" >"$file_path"
    dry:chmod "$mode" "$file_path"
  fi
  echo:Step "  ${cl_green}✓${cl_reset} Wrote ${label} (mode ${mode})"
}

##
## Ensure .gitignore contains the secrets directory
##
## Parameters:
## - git_root - Repository root path, string, required
## - secrets_dir - Secrets directory name, string, required
##
function ensure:gitignore() {
  local git_root="$1" secrets_dir="$2"
  local gitignore="${git_root}/.gitignore"

  if [[ -f "$gitignore" ]]; then
    if grep -qF "${secrets_dir}" "$gitignore" 2>/dev/null; then
      echo:Ssh "${secrets_dir}/ already in .gitignore"
      return 0
    fi
    if [[ "$DRY_RUN" != "true" && "$DRY_RUN" != "1" ]]; then
      echo "${secrets_dir}/" >>"$gitignore"
    fi
    echo:Step "  ${cl_green}✓${cl_reset} Added ${secrets_dir}/ to .gitignore"
  else
    if [[ "$DRY_RUN" != "true" && "$DRY_RUN" != "1" ]]; then
      echo "${secrets_dir}/" >"$gitignore"
    fi
    echo:Step "  ${cl_green}✓${cl_reset} Created .gitignore with ${secrets_dir}/"
  fi
}

##
## Test SSH connection to the configured host
##
## Parameters:
## - ssh_cmd - SSH command with key, string, required
## - git_user - Git username, string, required
## - git_host - Git hostname, string, required
##
function test:ssh-connection() {
  local ssh_cmd="$1" git_user="$2" git_host="$3"

  local test_ssh
  read -rp "Test SSH connection to ${git_host}? [Y/n]: " test_ssh
  [[ "$test_ssh" =~ ^[Nn] ]] && return 0

  echo ""
  echo:Step "  Testing: ssh -T ${git_user}@${git_host} ..."
  GIT_SSH_COMMAND="$ssh_cmd" run:ssh -T -o StrictHostKeyChecking=accept-new "${git_user}@${git_host}" 2>&1 | sed 's/^/  /'
  echo ""
}

##
## Exit trap: print exit code
##
function on_exit() {
  local exit_code=$?
  local color="${cl_green}"
  [[ $exit_code -ne 0 ]] && color="${cl_red}"
  echo:Ssh "${cl_grey}exit code: ${color}${exit_code}${cl_reset}"
  return $exit_code
}

# ── Main ─────────────────────────────────────────────

function main() {
  # Argument definition (modern COMPOSER pattern)
  export COMPOSER="
    $(args:i help -a "-h,--help" -h "Show help and exit." -g global)
    $(args:i DRY_RUN -a "--dry-run" -d "true" -h "Preview changes without writing files." -g global)
    $(args:i FORCE -a "-f,--force" -h "Overwrite existing key files." -g global)
    $(args:i SECRETS_DIR -a "--secrets-dir" -d ".secrets" -q 1 -h "Directory for key storage." -g options)
    $(args:i KEY_NAME -a "--key-name" -d "id_ed25519" -q 1 -h "Key filename." -g options)
    $(args:i DEBUG -a "--debug" -d "*" -h "Enable debug logging." -g global)
  "
  eval "$COMPOSER" >/dev/null
  parse:arguments "$@"

  # Quick exits
  if [[ "${help:-}" == "1" ]]; then
    print:help
    return $EXIT_OK
  fi

  # Apply defaults after parsing
  SECRETS_DIR=${SECRETS_DIR:-.secrets}
  KEY_NAME=${KEY_NAME:-id_ed25519}
  DRY_RUN=${DRY_RUN:-false}

  # Detect git root
  local git_root
  git_root=$(run:git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$git_root" ]]; then
    echo:Ssh "${cl_red}Not inside a git repository.${cl_reset}"
    return $EXIT_ERROR
  fi

  # Derived paths
  local secrets_path="${git_root}/${SECRETS_DIR}"
  local key_path="${secrets_path}/${KEY_NAME}"
  local pub_path="${key_path}.pub"
  local ssh_cmd="ssh -i ${SECRETS_DIR}/${KEY_NAME} -o IdentitiesOnly=yes"

  echo:Step ""
  echo:Step "${cl_bold}Git SSH Key Setup${cl_reset} ${cl_grey}v${SCRIPT_VERSION}${cl_reset}"
  echo:Step "${cl_grey}Repository: ${git_root}${cl_reset}"

  # ── Step 1: Git host & user
  step:header 1 "Git remote configuration"
  detect:remote
  prompt:remote

  # ── Step 2: Key storage
  step:header 2 "Key storage"
  echo:Ssh "Private: ${SECRETS_DIR}/${KEY_NAME}"
  echo:Ssh "Public:  ${SECRETS_DIR}/${KEY_NAME}.pub"

  # Check existing key
  if [[ -f "$key_path" ]] && [[ "${FORCE}" != "true" && "${FORCE}" != "1" ]]; then
    echo:Step "  ${cl_yellow}!${cl_reset} Private key already exists: ${key_path}"
    local overwrite
    read -rp "  Overwrite? [y/N]: " overwrite
    if [[ ! "$overwrite" =~ ^[Yy] ]]; then
      echo:Ssh "Keeping existing key. Skipping to git config."
      step:header 5 "Git SSH configuration"
      dry:git config core.sshCommand "$ssh_cmd"
      echo:Step "  ${cl_green}✓${cl_reset} Set core.sshCommand"
      echo:Step ""
      echo:Step "${cl_green}Done.${cl_reset} SSH key already configured."
      return $EXIT_OK
    fi
  fi

  # ── Step 3: Paste private key
  step:header 3 "Private key"
  local private_key
  private_key=$(prompt:private-key) || return $EXIT_CANCELLED

  # ── Step 4: Paste public key (optional)
  step:header 4 "Public key (optional)"
  local public_key=""
  public_key=$(prompt:public-key) || true

  # ── Step 5: Write files & configure git
  step:header 5 "Write files & configure git"

  dry:mkdir -p "$secrets_path"
  echo:Step "  ${cl_green}✓${cl_reset} Created ${SECRETS_DIR}/"

  write:key-file "$key_path" "$private_key" "600" "private key"

  if [[ -n "$public_key" ]]; then
    write:key-file "$pub_path" "$public_key" "644" "public key"
  fi

  ensure:gitignore "$git_root" "$SECRETS_DIR"

  dry:git config core.sshCommand "$ssh_cmd"
  echo:Step "  ${cl_green}✓${cl_reset} Set core.sshCommand"

  # Summary
  echo:Step ""
  echo:Step "${cl_bold}── Summary ──${cl_reset}"
  echo:Step "  Host:    ${GIT_USER}@${GIT_HOST}"
  echo:Step "  Key:     ${SECRETS_DIR}/${KEY_NAME}"
  echo:Step "  Config:  core.sshCommand = ${ssh_cmd}"
  echo:Step ""

  test:ssh-connection "$ssh_cmd" "$GIT_USER" "$GIT_HOST"

  echo:Step "${cl_green}Done.${cl_reset}"
  return $EXIT_OK
}

# ── Entry point ──────────────────────────────────────

# Return early if sourced (for unit tests)
${__SOURCED__:+return}

# Initialize loggers after function definitions
logger:init ssh "${cl_grey}[ssh]${cl_reset} " ">&2"
logger:init step " " ">&2"

# Dependency checks
dependency git "2.*.*"
optional ssh "9.*" "brew install openssh" "-V" "[0-9]+\.[0-9]+"

# Dry-run wrappers for state-modifying commands
dryrun git
dryrun mkdir
dryrun chmod
dryrun ssh

# Exit trap
trap on_exit EXIT

main "$@"
exit $?
