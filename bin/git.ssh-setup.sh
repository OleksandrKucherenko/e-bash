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

# Configure logging: tag "ssh" with prefix, redirect to stderr
logger ssh "$@" && logger:prefix ssh " ${cl_grey}[ssh]${cl_reset} " && logger:redirect ssh ">&2"
# Step logger for user-facing progress
logger step "$@" && logger:prefix step " " && logger:redirect step ">&2"

# Dependency checks
dependency git "2.*.*"
optional ssh "1:*" "brew install openssh"

# Argument definition using e-bash pattern
export ARGS_DEFINITION="-h,--help --dry-run=DRY_RUN --force=FORCE --secrets-dir=SECRETS_DIR:.secrets --key-name=KEY_NAME:id_ed25519 --debug=DEBUG"
source "$E_BASH/_arguments.sh"

# Exit codes
readonly EXIT_OK=0
readonly EXIT_ERROR=1
readonly EXIT_CANCELLED=2

# ── Detect git root ──────────────────────────────────

git_root=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$git_root" ]]; then
  echo:Ssh "Not inside a git repository." >&2
  exit $EXIT_ERROR
fi

echo:Step ""
echo:Step "${cl_bold}Git SSH Key Setup${cl_reset} ${cl_grey}v${SCRIPT_VERSION}${cl_reset}"
echo:Step "${cl_grey}Repository: ${git_root}${cl_reset}"

# Derived paths
secrets_path="${git_root}/${SECRETS_DIR}"
key_path="${secrets_path}/${KEY_NAME}"
pub_path="${key_path}.pub"

total_steps=5

# ── Step 1: Git host & user ─────────────────────────

echo:Step ""
echo:Step "${cl_blue}[1/${total_steps}]${cl_reset} ${cl_bold}Git remote configuration${cl_reset}"

GIT_HOST="github.com"
GIT_USER="git"

# Auto-detect from origin remote
origin_url=$(git remote get-url origin 2>/dev/null || echo "")
if [[ -n "$origin_url" ]]; then
  if [[ "$origin_url" =~ ^[a-z]+@([^:]+): ]]; then
    GIT_HOST="${BASH_REMATCH[1]}"
    GIT_USER="${origin_url%%@*}"
  elif [[ "$origin_url" =~ ^ssh://([^@]+)@([^/]+) ]]; then
    GIT_USER="${BASH_REMATCH[1]}"
    GIT_HOST="${BASH_REMATCH[2]}"
  fi
  echo:Ssh "Detected from origin: ${GIT_USER}@${GIT_HOST}"
fi

read -rp "  Git host [${GIT_HOST}]: " input_host
[[ -n "$input_host" ]] && GIT_HOST="$input_host"

read -rp "  Git user [${GIT_USER}]: " input_user
[[ -n "$input_user" ]] && GIT_USER="$input_user"

echo:Step "  ${cl_green}✓${cl_reset} Host: ${GIT_USER}@${GIT_HOST}"

# ── Step 2: Key storage ─────────────────────────────

echo:Step ""
echo:Step "${cl_blue}[2/${total_steps}]${cl_reset} ${cl_bold}Key storage${cl_reset}"

echo:Ssh "Keys: ${SECRETS_DIR}/${KEY_NAME} / ${SECRETS_DIR}/${KEY_NAME}.pub"

if [[ -f "$key_path" ]] && [[ "${FORCE:-}" != "1" ]]; then
  echo:Step "  ${cl_yellow}!${cl_reset} Private key already exists: ${key_path}"
  read -rp "  Overwrite? [y/N]: " overwrite
  if [[ ! "$overwrite" =~ ^[Yy] ]]; then
    echo:Ssh "Keeping existing key. Skipping to git config."

    echo:Step ""
    echo:Step "${cl_blue}[5/${total_steps}]${cl_reset} ${cl_bold}Git SSH configuration${cl_reset}"
    ssh_cmd="ssh -i ${SECRETS_DIR}/${KEY_NAME} -o IdentitiesOnly=yes"

    if [[ "${DRY_RUN:-}" == "1" ]]; then
      echo:Step "  Would run: git config core.sshCommand \"$ssh_cmd\""
    else
      git config core.sshCommand "$ssh_cmd"
      echo:Step "  ${cl_green}✓${cl_reset} Set core.sshCommand"
    fi

    echo:Step ""
    echo:Step "${cl_green}Done.${cl_reset} SSH key already configured."
    exit $EXIT_OK
  fi
fi

# ── Step 3: Paste private key ────────────────────────

echo:Step ""
echo:Step "${cl_blue}[3/${total_steps}]${cl_reset} ${cl_bold}Private key${cl_reset}"
echo:Step "  Paste your SSH private key below (Ctrl+D to save, Esc to cancel):"
echo ""

private_key=$(input:multi-line -m stream -h 8 --no-status)
pk_exit=$?

if [[ $pk_exit -ne 0 ]] || [[ -z "$private_key" ]]; then
  echo ""
  echo:Step "  ${cl_red}✗${cl_reset} No private key provided. Aborting."
  exit $EXIT_CANCELLED
fi

# Validate PEM format
if [[ ! "$private_key" =~ ^-----BEGIN ]]; then
  echo:Step "  ${cl_yellow}!${cl_reset} Key doesn't start with '-----BEGIN'. Might not be a valid PEM key."
  read -rp "  Continue anyway? [y/N]: " proceed
  if [[ ! "$proceed" =~ ^[Yy] ]]; then
    exit $EXIT_CANCELLED
  fi
fi

echo ""
pk_lines=$(echo "$private_key" | wc -l | tr -d ' ')
echo:Step "  ${cl_green}✓${cl_reset} Private key received (${pk_lines} lines)"

# ── Step 4: Paste public key (optional) ──────────────

echo:Step ""
echo:Step "${cl_blue}[4/${total_steps}]${cl_reset} ${cl_bold}Public key (optional)${cl_reset}"
echo:Step "  Paste public key below, or press Esc to skip:"
echo ""

public_key=$(input:multi-line -m stream -h 3 --no-status)
pub_exit=$?

echo ""
if [[ $pub_exit -ne 0 ]] || [[ -z "$public_key" ]]; then
  echo:Ssh "Skipped public key."
  public_key=""
else
  echo:Step "  ${cl_green}✓${cl_reset} Public key received"
fi

# ── Step 5: Write files & configure git ──────────────

echo:Step ""
echo:Step "${cl_blue}[5/${total_steps}]${cl_reset} ${cl_bold}Write files & configure git${cl_reset}"

ssh_cmd="ssh -i ${SECRETS_DIR}/${KEY_NAME} -o IdentitiesOnly=yes"

if [[ "${DRY_RUN:-}" == "1" ]]; then
  echo:Step "  ${cl_yellow}[DRY RUN]${cl_reset} Would create:"
  echo:Step "    mkdir -p ${secrets_path}"
  echo:Step "    write ${key_path} (${pk_lines} lines, mode 600)"
  [[ -n "$public_key" ]] && echo:Step "    write ${pub_path} (mode 644)"
  echo:Step "    git config core.sshCommand \"${ssh_cmd}\""
  if [[ -f "${git_root}/.gitignore" ]]; then
    grep -qF "${SECRETS_DIR}" "${git_root}/.gitignore" 2>/dev/null || echo:Step "    append '${SECRETS_DIR}/' to .gitignore"
  else
    echo:Step "    create .gitignore with '${SECRETS_DIR}/'"
  fi
  echo:Step ""
  echo:Step "${cl_green}Dry run complete.${cl_reset} No changes made."
  exit $EXIT_OK
fi

# Create secrets directory
mkdir -p "$secrets_path"
echo:Step "  ${cl_green}✓${cl_reset} Created ${SECRETS_DIR}/"

# Write private key (strict permissions)
printf "%s\n" "$private_key" >"$key_path"
chmod 600 "$key_path"
echo:Step "  ${cl_green}✓${cl_reset} Wrote private key (mode 600)"

# Write public key if provided
if [[ -n "$public_key" ]]; then
  printf "%s\n" "$public_key" >"$pub_path"
  chmod 644 "$pub_path"
  echo:Step "  ${cl_green}✓${cl_reset} Wrote public key (mode 644)"
fi

# Ensure .gitignore excludes secrets
if [[ -f "${git_root}/.gitignore" ]]; then
  if ! grep -qF "${SECRETS_DIR}" "${git_root}/.gitignore" 2>/dev/null; then
    echo "${SECRETS_DIR}/" >>"${git_root}/.gitignore"
    echo:Step "  ${cl_green}✓${cl_reset} Added ${SECRETS_DIR}/ to .gitignore"
  else
    echo:Ssh "${SECRETS_DIR}/ already in .gitignore"
  fi
else
  echo "${SECRETS_DIR}/" >"${git_root}/.gitignore"
  echo:Step "  ${cl_green}✓${cl_reset} Created .gitignore with ${SECRETS_DIR}/"
fi

# Configure git to use the key
git config core.sshCommand "$ssh_cmd"
echo:Step "  ${cl_green}✓${cl_reset} Set core.sshCommand"

# Summary
echo:Step ""
echo:Step "${cl_bold}── Summary ──${cl_reset}"
echo:Step "  Host:    ${GIT_USER}@${GIT_HOST}"
echo:Step "  Key:     ${SECRETS_DIR}/${KEY_NAME}"
echo:Step "  Config:  core.sshCommand = ${ssh_cmd}"
echo:Step ""

# Verify SSH connection
read -rp "Test SSH connection to ${GIT_HOST}? [Y/n]: " test_ssh
if [[ ! "$test_ssh" =~ ^[Nn] ]]; then
  echo ""
  echo:Step "  Testing: ssh -T ${GIT_USER}@${GIT_HOST} ..."
  GIT_SSH_COMMAND="$ssh_cmd" ssh -T -o StrictHostKeyChecking=accept-new "${GIT_USER}@${GIT_HOST}" 2>&1 | sed 's/^/  /'
  echo ""
fi

echo:Step "${cl_green}Done.${cl_reset}"
