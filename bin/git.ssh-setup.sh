#!/usr/bin/env bash
# shellcheck disable=SC2155,SC1090,SC2034,SC2059

## Git SSH Key Setup Helper
## Configure a per-repo SSH key: generate or paste keys, set permissions, update git config.
##
## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-04-13
## Version: 1.1.0
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
readonly SCRIPT_VERSION="1.1.0"

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
declare help version SECRETS_DIR KEY_NAME KEY_TYPE DRY_RUN FORCE

SECRETS_DIR=${SECRETS_DIR:-.secrets}
KEY_NAME=${KEY_NAME:-id_ed25519}
KEY_TYPE=${KEY_TYPE:-ed25519}
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
## Generate a new SSH key pair
##
## Parameters:
## - key_path - Output path for private key, string, required
## - key_type - Key type (ed25519, rsa, ecdsa), string, required
## - comment - Key comment, string, required
##
## Returns:
## - 0 on success
## - 1 on failure
##
function generate:ssh-key() {
  local key_path="$1" key_type="$2" comment="$3"

  echo:Step "  Generating ${cl_bold}${key_type}${cl_reset} key pair..."

  if [[ "$DRY_RUN" == "true" || "$DRY_RUN" == "1" ]]; then
    echo:Ssh "dry run: ssh-keygen -t ${key_type} -f ${key_path} -N '' -C '${comment}'"
    return 0
  fi

  local keygen_args=(-t "$key_type" -f "$key_path" -N "" -C "$comment" -q)

  # RSA keys default to 4096 bits
  [[ "$key_type" == "rsa" ]] && keygen_args+=(-b 4096)

  if ssh-keygen "${keygen_args[@]}" 2>/dev/null; then
    chmod 600 "$key_path"
    chmod 644 "${key_path}.pub"
    echo:Step "  ${cl_green}✓${cl_reset} Key pair generated"
    return 0
  else
    echo:Step "  ${cl_red}✗${cl_reset} Key generation failed"
    return 1
  fi
}

##
## Show public key and copy to clipboard if available
##
## Parameters:
## - pub_key_content - Public key string, string, required
##
function review:public-key() {
  local pub_key_content="$1"

  echo:Step "  ${cl_bold}Public key${cl_reset} — add this to your git hosting provider:"
  echo ""
  echo "  ${cl_green}${pub_key_content}${cl_reset}"
  echo ""

  # Try to copy to clipboard automatically
  local clipboard_cmd=""
  if command -v xclip >/dev/null 2>&1; then
    clipboard_cmd="xclip -i -selection clipboard"
  elif command -v xsel >/dev/null 2>&1; then
    clipboard_cmd="xsel --clipboard --input"
  elif command -v pbcopy >/dev/null 2>&1; then
    clipboard_cmd="pbcopy"
  fi

  if [[ -n "$clipboard_cmd" ]]; then
    echo "$pub_key_content" | $clipboard_cmd 2>/dev/null
    echo:Step "  ${cl_green}✓${cl_reset} Copied to clipboard"
  else
    echo:Step "  ${cl_grey}Tip: select the key above and copy manually${cl_reset}"
  fi
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
    $(args:i version -a "-v,--version" -d "$SCRIPT_VERSION" -h "Show version and exit." -g global)
    $(args:i DRY_RUN -a "--dry-run" -d "true" -h "Preview changes without writing files." -g global)
    $(args:i FORCE -a "-f,--force" -h "Overwrite existing key files." -g global)
    $(args:i SECRETS_DIR -a "--secrets-dir" -d ".secrets" -q 1 -h "Directory for key storage." -g options)
    $(args:i KEY_NAME -a "--key-name" -d "id_ed25519" -q 1 -h "Key filename." -g options)
    $(args:i KEY_TYPE -a "-t,--key-type" -d "ed25519" -q 1 -h "Key type: ed25519, rsa, ecdsa." -g options)
    $(args:i DEBUG -a "--debug" -d "*" -h "Enable debug logging." -g global)
  "
  eval "$COMPOSER" >/dev/null
  parse:arguments "$@"

  # Quick exits
  if [[ "${help:-}" == "1" ]]; then
    echo "Usage: ${SCRIPT_NAME} [OPTIONS]"
    echo ""
    print:help
    return $EXIT_OK
  elif [[ -n "${version:-}" ]]; then
    echo "${SCRIPT_NAME} ${version}"
    return $EXIT_OK
  fi

  # Apply defaults after parsing
  SECRETS_DIR=${SECRETS_DIR:-.secrets}
  KEY_NAME=${KEY_NAME:-id_ed25519}
  KEY_TYPE=${KEY_TYPE:-ed25519}
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
  # Absolute path with escaping for spaces; -F /dev/null ignores ~/.ssh/config
  local escaped_root
  escaped_root=$(printf "%q" "$git_root")
  local ssh_cmd="ssh -o IdentitiesOnly=yes -i ${escaped_root}/${SECRETS_DIR}/${KEY_NAME} -F /dev/null"

  echo:Step ""
  echo:Step "${cl_bold}Git SSH Key Setup${cl_reset} ${cl_grey}v${SCRIPT_VERSION}${cl_reset}"
  echo:Step "${cl_grey}Repository: ${git_root}${cl_reset}"

  # Show current SSH configuration
  local current_ssh_cmd
  current_ssh_cmd=$(run:git config --local --get core.sshCommand 2>/dev/null || echo "")
  if [[ -n "$current_ssh_cmd" ]]; then
    echo:Step "  ${cl_yellow}Current config:${cl_reset} core.sshCommand = ${current_ssh_cmd}"
  else
    echo:Step "  ${cl_grey}No custom SSH config (using system default)${cl_reset}"
  fi
  [[ -f "$key_path" ]] && echo:Step "  ${cl_yellow}Existing key:${cl_reset} ${key_path}"

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
      dry:git config --local core.sshCommand "$ssh_cmd"
      echo:Step "  ${cl_green}✓${cl_reset} Set core.sshCommand"
      echo:Step ""
      echo:Step "${cl_green}Done.${cl_reset} SSH key already configured."
      return $EXIT_OK
    fi
  fi

  # ── Step 3: Generate or paste private key
  step:header 3 "Private key"

  local private_key="" public_key="" key_generated=false
  local action
  echo:Step "  How would you like to provide the SSH key?"
  echo:Step ""
  echo:Step "    ${cl_bold}g${cl_reset}) ${cl_green}Generate${cl_reset} a new ${KEY_TYPE} key pair"
  echo:Step "    ${cl_bold}p${cl_reset}) ${cl_blue}Paste${cl_reset} an existing private key"
  echo:Step ""
  read -rp "  Choice [g/p]: " action

  case "${action,,}" in
  p | paste)
    # Paste mode: user provides the key via multiline editor
    private_key=$(prompt:private-key) || return $EXIT_CANCELLED
    ;;
  *)
    # Generate mode (default): create key pair with ssh-keygen
    local comment="${GIT_USER}@${GIT_HOST}"
    read -rp "  Key comment [${comment}]: " input_comment
    [[ -n "$input_comment" ]] && comment="$input_comment"

    dry:mkdir -p "$secrets_path"
    generate:ssh-key "$key_path" "$KEY_TYPE" "$comment" || return $EXIT_ERROR
    key_generated=true

    if [[ "$DRY_RUN" != "true" && "$DRY_RUN" != "1" ]]; then
      private_key=$(cat "$key_path")
      public_key=$(cat "$pub_path")
    fi
    ;;
  esac

  # ── Step 4: Public key
  step:header 4 "Public key"

  if [[ "$key_generated" == "true" ]]; then
    if [[ -n "$public_key" ]]; then
      # Show generated public key for review and clipboard copy
      review:public-key "$public_key"
    else
      echo:Ssh "Dry run: public key would be shown here."
    fi
  else
    # Paste mode: optionally paste public key
    echo:Step "  ${cl_grey}(optional)${cl_reset}"
    public_key=$(prompt:public-key) || true
  fi

  # ── Step 5: Write files & configure git
  step:header 5 "Write files & configure git"

  if [[ "$key_generated" != "true" ]]; then
    # Only write files if we didn't generate (keygen already wrote them)
    dry:mkdir -p "$secrets_path"
    echo:Step "  ${cl_green}✓${cl_reset} Created ${SECRETS_DIR}/"

    write:key-file "$key_path" "$private_key" "600" "private key"

    if [[ -n "$public_key" ]]; then
      write:key-file "$pub_path" "$public_key" "644" "public key"
    fi
  else
    echo:Step "  ${cl_green}✓${cl_reset} Key files already written by ssh-keygen"
  fi

  ensure:gitignore "$git_root" "$SECRETS_DIR"

  dry:git config --local core.sshCommand "$ssh_cmd"
  echo:Step "  ${cl_green}✓${cl_reset} Set core.sshCommand"

  # Summary
  echo:Step ""
  echo:Step "${cl_bold}── Summary ──${cl_reset}"
  echo:Step "  Host:    ${GIT_USER}@${GIT_HOST}"
  echo:Step "  Key:     ${SECRETS_DIR}/${KEY_NAME}"
  [[ "$key_generated" == "true" ]] && echo:Step "  Type:    ${KEY_TYPE}"
  echo:Step "  Config:  core.sshCommand = ${ssh_cmd}"
  echo:Step ""

  test:ssh-connection "$ssh_cmd" "$GIT_USER" "$GIT_HOST"

  echo:Step "${cl_green}Done.${cl_reset}"
  echo:Step ""
  echo:Step "${cl_bold}── Rollback ──${cl_reset}"
  echo:Step "  To reset SSH config to system default:"
  echo:Step "    ${cl_grey}\$ git config --local --unset core.sshCommand${cl_reset}"
  echo:Step "  To remove generated key files:"
  echo:Step "    ${cl_grey}\$ rm -rf ${SECRETS_DIR}/${cl_reset}"
  return $EXIT_OK
}

# ── Entry point ──────────────────────────────────────

# Return early if sourced (for unit tests)
${__SOURCED__:+return}

# Initialize loggers after function definitions
logger:init ssh "${cl_grey}[ssh]${cl_reset} " ">&2"
logger:init step " " ">&2"

# Dependency checks (ssh-keygen is part of the same openssh package as ssh)
optional ssh "9.*" "brew install openssh" "-V"

# Dry-run wrappers for state-modifying commands
dryrun git
dryrun mkdir
dryrun chmod
dryrun ssh

# Exit trap
trap on_exit EXIT

main "$@"
exit $?
