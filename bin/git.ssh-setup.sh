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

if [[ -z $TERM ]]; then export TERM=xterm-256color; fi

export SKIP_ARGS_PARSING=1

# Bootstrap
[ "$E_BASH" ] || { _src=${BASH_SOURCE:-$0}; E_BASH=$(cd "${_src%/*}/../.scripts" 2>&- && pwd || echo ~/.e-bash/.scripts); readonly E_BASH; }
. "$E_BASH/_gnu.sh"; PATH="$(cd "$E_BASH/../bin/gnubin" 2>&- && pwd):$PATH"

# Import
source "$E_BASH/_colors.sh"
source "$E_BASH/_logger.sh"
source "$E_BASH/_commons.sh"

logger ssh "$@" && logger:prefix ssh " ${cl_grey}[ssh]${cl_reset} " && logger:redirect ssh ">&2"

readonly SSH_SCRIPT_VERSION="1.0.0"

# --- Defaults ---
SECRETS_DIR=".secrets"
KEY_NAME="id_ed25519"
GIT_HOST="github.com"
GIT_USER="git"

# --- Argument parsing ---
DRY_RUN=false
FORCE=false
while [[ "$#" -gt 0 ]]; do
  case $1 in
  --dry-run) DRY_RUN=true ;;
  --force) FORCE=true ;;
  --secrets-dir)
    SECRETS_DIR="$2"
    shift
    ;;
  --key-name)
    KEY_NAME="$2"
    shift
    ;;
  --help | -h)
    echo "Usage: git.ssh-setup.sh [OPTIONS]"
    echo ""
    echo "Configure a per-repo SSH key for git operations."
    echo ""
    echo "Options:"
    echo "  --dry-run          Show what would be done without making changes"
    echo "  --force            Overwrite existing key files"
    echo "  --secrets-dir DIR  Directory for key storage (default: .secrets)"
    echo "  --key-name NAME    Key filename (default: id_ed25519)"
    echo "  --help, -h         Show this help"
    echo ""
    echo "Version: $SSH_SCRIPT_VERSION"
    exit 0
    ;;
  esac
  shift
done

# --- Helpers ---

print_step() {
  local step=$1 total=$2 label=$3
  printf "\n${cl_blue}[%d/%d]${cl_reset} ${cl_bold}%s${cl_reset}\n" "$step" "$total" "$label"
}

print_info() {
  printf "  ${cl_grey}%s${cl_reset}\n" "$@"
}

print_ok() {
  printf "  ${cl_green}✓${cl_reset} %s\n" "$1"
}

print_warn() {
  printf "  ${cl_yellow}!${cl_reset} %s\n" "$1"
}

print_err() {
  printf "  ${cl_red}✗${cl_reset} %s\n" "$1" >&2
}

# --- Detect git root ---
git_root=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$git_root" ]]; then
  print_err "Not inside a git repository."
  exit 1
fi

echo ""
echo "${cl_bold}Git SSH Key Setup${cl_reset} ${cl_grey}v${SSH_SCRIPT_VERSION}${cl_reset}"
echo "${cl_grey}Repository: ${git_root}${cl_reset}"

total_steps=5

# ─────────────────────────────────────────────
# Step 1: Git host & user
# ─────────────────────────────────────────────
print_step 1 $total_steps "Git remote configuration"

# Try to auto-detect from origin remote
origin_url=$(git remote get-url origin 2>/dev/null || echo "")
if [[ -n "$origin_url" ]]; then
  # Parse host from ssh://git@host/... or git@host:...
  if [[ "$origin_url" =~ ^[a-z]+@([^:]+): ]]; then
    GIT_HOST="${BASH_REMATCH[1]}"
    GIT_USER="${origin_url%%@*}"
  elif [[ "$origin_url" =~ ^ssh://([^@]+)@([^/]+) ]]; then
    GIT_USER="${BASH_REMATCH[1]}"
    GIT_HOST="${BASH_REMATCH[2]}"
  fi
  print_info "Detected from origin: ${cl_bold}${GIT_USER}@${GIT_HOST}${cl_reset}"
fi

read -rp "  Git host [${GIT_HOST}]: " input_host
[[ -n "$input_host" ]] && GIT_HOST="$input_host"

read -rp "  Git user [${GIT_USER}]: " input_user
[[ -n "$input_user" ]] && GIT_USER="$input_user"

print_ok "Host: ${GIT_USER}@${GIT_HOST}"

# ─────────────────────────────────────────────
# Step 2: Key storage
# ─────────────────────────────────────────────
print_step 2 $total_steps "Key storage"

secrets_path="${git_root}/${SECRETS_DIR}"
key_path="${secrets_path}/${KEY_NAME}"
pub_path="${key_path}.pub"

print_info "Keys will be stored in: ${cl_bold}${SECRETS_DIR}/${cl_reset}"
print_info "  Private: ${SECRETS_DIR}/${KEY_NAME}"
print_info "  Public:  ${SECRETS_DIR}/${KEY_NAME}.pub"

if [[ -f "$key_path" ]] && [[ "$FORCE" != "true" ]]; then
  print_warn "Private key already exists: ${key_path}"
  read -rp "  Overwrite? [y/N]: " overwrite
  if [[ ! "$overwrite" =~ ^[Yy] ]]; then
    print_info "Keeping existing key. Skipping to git config."

    # Jump to step 5
    print_step 5 $total_steps "Git SSH configuration"

    ssh_cmd="ssh -i ${SECRETS_DIR}/${KEY_NAME} -o IdentitiesOnly=yes"
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "  Would run: git config core.sshCommand \"$ssh_cmd\""
    else
      git config core.sshCommand "$ssh_cmd"
      print_ok "Set core.sshCommand"
    fi

    echo ""
    echo "${cl_green}Done.${cl_reset} SSH key already configured."
    exit 0
  fi
fi

# ─────────────────────────────────────────────
# Step 3: Paste private key
# ─────────────────────────────────────────────
print_step 3 $total_steps "Private key"
echo "  Paste your SSH private key below (Ctrl+D to save, Esc to cancel):"
echo ""

private_key=$(input:multi-line -m stream -h 8 --no-status)
pk_exit=$?

if [[ $pk_exit -ne 0 ]] || [[ -z "$private_key" ]]; then
  echo ""
  print_err "No private key provided. Aborting."
  exit 1
fi

# Validate: must start with -----BEGIN
if [[ ! "$private_key" =~ ^-----BEGIN ]]; then
  print_warn "Key doesn't start with '-----BEGIN'. Might not be a valid PEM key."
  read -rp "  Continue anyway? [y/N]: " proceed
  if [[ ! "$proceed" =~ ^[Yy] ]]; then
    print_err "Aborted."
    exit 1
  fi
fi

echo ""
# Count lines for feedback
pk_lines=$(echo "$private_key" | wc -l | tr -d ' ')
print_ok "Private key received (${pk_lines} lines)"

# ─────────────────────────────────────────────
# Step 4: Paste public key (optional)
# ─────────────────────────────────────────────
print_step 4 $total_steps "Public key (optional)"
echo "  Paste public key below, or press Esc to skip:"
echo ""

public_key=$(input:multi-line -m stream -h 3 --no-status)
pub_exit=$?

echo ""
if [[ $pub_exit -ne 0 ]] || [[ -z "$public_key" ]]; then
  print_info "Skipped public key."
  public_key=""
else
  print_ok "Public key received"
fi

# ─────────────────────────────────────────────
# Step 5: Write files & configure git
# ─────────────────────────────────────────────
print_step 5 $total_steps "Write files & configure git"

if [[ "$DRY_RUN" == "true" ]]; then
  echo "  ${cl_yellow}[DRY RUN]${cl_reset} Would create:"
  echo "    mkdir -p ${secrets_path}"
  echo "    write ${key_path} (${pk_lines} lines, mode 600)"
  [[ -n "$public_key" ]] && echo "    write ${pub_path} (mode 644)"
  echo "    git config core.sshCommand \"ssh -i ${SECRETS_DIR}/${KEY_NAME} -o IdentitiesOnly=yes\""

  # Check .gitignore
  if [[ -f "${git_root}/.gitignore" ]]; then
    if ! grep -qF "${SECRETS_DIR}" "${git_root}/.gitignore" 2>/dev/null; then
      echo "    append '${SECRETS_DIR}/' to .gitignore"
    fi
  else
    echo "    create .gitignore with '${SECRETS_DIR}/'"
  fi

  echo ""
  echo "${cl_green}Dry run complete.${cl_reset} No changes made."
  exit 0
fi

# Create secrets directory
mkdir -p "$secrets_path"
print_ok "Created ${SECRETS_DIR}/"

# Write private key (strict permissions)
printf "%s\n" "$private_key" >"$key_path"
chmod 600 "$key_path"
print_ok "Wrote private key (mode 600)"

# Write public key if provided
if [[ -n "$public_key" ]]; then
  printf "%s\n" "$public_key" >"$pub_path"
  chmod 644 "$pub_path"
  print_ok "Wrote public key (mode 644)"
fi

# Ensure .gitignore excludes secrets
if [[ -f "${git_root}/.gitignore" ]]; then
  if ! grep -qF "${SECRETS_DIR}" "${git_root}/.gitignore" 2>/dev/null; then
    echo "${SECRETS_DIR}/" >>"${git_root}/.gitignore"
    print_ok "Added ${SECRETS_DIR}/ to .gitignore"
  else
    print_info "${SECRETS_DIR}/ already in .gitignore"
  fi
else
  echo "${SECRETS_DIR}/" >"${git_root}/.gitignore"
  print_ok "Created .gitignore with ${SECRETS_DIR}/"
fi

# Configure git to use the key
ssh_cmd="ssh -i ${SECRETS_DIR}/${KEY_NAME} -o IdentitiesOnly=yes"
git config core.sshCommand "$ssh_cmd"
print_ok "Set core.sshCommand"

# Summary
echo ""
echo "${cl_bold}── Summary ──${cl_reset}"
echo "  Host:    ${GIT_USER}@${GIT_HOST}"
echo "  Key:     ${SECRETS_DIR}/${KEY_NAME}"
echo "  Config:  core.sshCommand = ${ssh_cmd}"
echo ""

# Verify SSH connection
read -rp "Test SSH connection to ${GIT_HOST}? [Y/n]: " test_ssh
if [[ ! "$test_ssh" =~ ^[Nn] ]]; then
  echo ""
  echo "  Testing: ssh -T ${GIT_USER}@${GIT_HOST} ..."
  # Use the configured key
  GIT_SSH_COMMAND="$ssh_cmd" ssh -T -o StrictHostKeyChecking=accept-new "${GIT_USER}@${GIT_HOST}" 2>&1 | sed 's/^/  /'
  echo ""
fi

echo "${cl_green}Done.${cl_reset}"
