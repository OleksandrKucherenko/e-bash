#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-02-07
## Version: 2.5.3
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

export DEBUG=${DEBUG:-"demo-curl,-loader,-parser,-common"}

# Bootstrap: 1) E_BASH discovery (only if not set), 2) gnubin setup (always)
[ "$E_BASH" ] || {
  _src=${BASH_SOURCE:-$0}
  E_BASH=$(cd "${_src%/*}/../.scripts" 2>&- && pwd || echo ~/.e-bash/.scripts)
  readonly E_BASH
}

export SKIP_ARGS_PARSING=1

# shellcheck disable=SC1090 source=../.scripts/_arguments.sh
source "$E_BASH/_arguments.sh"

# pre-declare variables to make shellcheck happy
declare help request header data url verbose args_command

ARGS_DEFINITION=""
ARGS_DEFINITION+=" -h,--help"
ARGS_DEFINITION+=" -X,--request=request::1"
ARGS_DEFINITION+=" -H,--header=header::1"
ARGS_DEFINITION+=" -d,--data=data::1"
ARGS_DEFINITION+=" --url=url::1"
ARGS_DEFINITION+=" -v,--verbose"
ARGS_DEFINITION+=" \$1,<command>=args_command:dummy:1"

function demo:completion:emit() {
  local args_qt="" flag="" idx="" keys="" key="" saved_ifs="$IFS"
  local -a flags=() value_flags=() commands=() request_enum=()

  parse:mapping

  for flag in "${!lookup_arguments[@]}"; do
    [[ "$flag" == \$* ]] && continue
    [[ "$flag" == \<* ]] && continue
    flags+=("$flag")
  done

  for idx in "${!index_to_args_qt[@]}"; do
    args_qt="${index_to_args_qt[$idx]}"
    [[ "$args_qt" -gt 0 ]] || continue
    keys="${index_to_keys[$idx]}"
    for key in $keys; do
      [[ "$key" == \$* ]] && continue
      [[ "$key" == \<* ]] && continue
      value_flags+=("$key")
    done
  done

  IFS=$'\n' flags=($(printf '%s\n' "${flags[@]}" | sort -u))
  IFS=$'\n' value_flags=($(printf '%s\n' "${value_flags[@]}" | sort -u))

  commands=(get post head put delete)
  request_enum=(GET POST PUT DELETE HEAD)

  IFS=' '
  echo "FLAGS=${flags[*]}"
  echo "VALUE_FLAGS=${value_flags[*]}"
  echo "COMMANDS=${commands[*]}"
  echo "REQUEST_ENUM=${request_enum[*]}"
  IFS="$saved_ifs"
}

function demo:completion:resolve_shell() {
  local requested="${1:-}" shell_name=""

  [[ -n "$requested" ]] || requested="${SHELL:-}"
  shell_name="$(basename "${requested}")"
  shell_name="${shell_name#-}"

  case "${shell_name}" in
  bash | zsh)
    echo "${shell_name}"
    return 0
    ;;
  *)
    echo "Error: unsupported shell '${requested}'. Use bash or zsh." >&2
    return 1
    ;;
  esac
}

function demo:completion:install() {
  local requested="${1:-}" shell_name="" script_dir="" source_file=""
  local dir="" file="" home_dir="" fallback_dir="" fallback_file=""

  shell_name="$(demo:completion:resolve_shell "${requested}")" || return 1
  script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>&- && pwd) || return 1

  case "${shell_name}" in
  bash)
    source_file="${script_dir}/demo.curl.bash"
    ;;
  zsh)
    source_file="${script_dir}/demo.curl.zsh"
    ;;
  esac

  [[ -f "${source_file}" ]] || {
    echo "Error: completion source not found: ${source_file}" >&2
    return 1
  }

  dir="$(_args:completion:dir "${shell_name}")" || return 1
  [[ -d "${dir}" ]] || mkdir -p "${dir}" || {
    echo "Error: cannot create completion directory: ${dir}" >&2
    return 1
  }

  case "${shell_name}" in
  bash)
    file="${dir}/demo.curl.sh"
    ;;
  zsh)
    file="${dir}/_demo_curl_complete"
    ;;
  esac

  if ! cp "${source_file}" "${file}" 2>/dev/null; then
    case "${shell_name}" in
    bash)
      fallback_dir="${BASH_COMPLETION_USER_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion}/completions"
      fallback_file="${fallback_dir}/demo.curl.sh"
      ;;
    zsh)
      fallback_dir="${HOME%/}/.zsh/completions"
      fallback_file="${fallback_dir}/_demo_curl_complete"
      ;;
    esac

    [[ -d "${fallback_dir}" ]] || mkdir -p "${fallback_dir}" || {
      echo "Error: cannot create fallback completion directory: ${fallback_dir}" >&2
      return 1
    }

    cp "${source_file}" "${fallback_file}" 2>/dev/null || {
      echo "Error: cannot install completion to ${file} or fallback ${fallback_file}" >&2
      return 1
    }

    dir="${fallback_dir}"
    file="${fallback_file}"
  fi

  echo "Completion installed: ${file}"

  if [[ "${shell_name}" == "zsh" ]]; then
    home_dir="${HOME%/}"
    if [[ "${dir}" == "${home_dir}/.zsh/completions" ]]; then
      echo "Activation: add this to ~/.zshrc"
      echo "  fpath=(\"${home_dir}/.zsh/completions\" \$fpath)"
    fi
    echo "Activation: reload completion cache"
    echo "  autoload -Uz compinit && rm -f ~/.zcompdump && compinit -i"
    echo "Test:"
    echo "  demos/demo.curl.sh --<TAB>"
  else
    echo "Activation (current bash session):"
    echo "  source \"${file}\""
    echo "Test:"
    echo "  demos/demo.curl.sh --<TAB>"
  fi
}

if [[ "$1" == "--completion-data" ]]; then
  demo:completion:emit
  exit 0
fi

if [[ "$1" == "--completion-install" ]]; then
  demo:completion:install "$2"
  exit $?
fi

parse:arguments "$@"

# register commands and flags for help output
args:d "\$1" "HTTP subcommand (get/post/head/put/delete)." "commands" 1

args:d "-h" "Show help and exit." "global"
args:d "-X" "HTTP method (overrides subcommand)." "global"
args:d "-H" "Add request header." "global"
args:d "-d" "Request body data." "global"
args:d "--url" "Request URL (optional if positional URL used)." "global"
args:d "-v" "Enable verbose output." "global"

args:v "-X" "GET"

if [[ "$help" == "1" ]]; then
  echo "demo.curl.sh - mock curl-like CLI for completion testing"
  echo ""
  echo "Usage: demos/demo.curl.sh [global flags] <command> [flags]"
  echo "       demos/demo.curl.sh --completion-install [bash|zsh]"
  echo ""
  print:help
  exit 0
fi

cat <<OUTPUT
Demo curl-like command
  command: ${args_command}
  request: ${request}
  header:  ${header}
  data:    ${data}
  url:     ${url}
  verbose: ${verbose}
OUTPUT

cat <<'SAMPLES'
Samples:
  demos/demo.curl.sh get --url https://example.test
  demos/demo.curl.sh post -X POST -d '{"a":1}' --url https://example.test
  demos/demo.curl.sh head -H 'Accept: */*' --url https://example.test

Completion data:
  demos/demo.curl.sh --completion-data

Completion install:
  demos/demo.curl.sh --completion-install zsh
  demos/demo.curl.sh --completion-install bash
SAMPLES
