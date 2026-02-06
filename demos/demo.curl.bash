#!/usr/bin/env bash

# Bash completion for demo.curl.sh
# Usage (bash):
#   source demos/demo.curl.bash
#   complete -p demo-curl

__demo_curl_loaded=""
__demo_curl_flags=()
__demo_curl_value_flags=()
__demo_curl_commands=()
__demo_curl_request_enum=()

__demo_curl_load_data() {
  local data_line="" data_file="" script_dir=""

  [[ -n "$__demo_curl_loaded" ]] && return 0

  script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>&- && pwd)
  data_file="${script_dir}/demo.curl.sh"

  while IFS= read -r data_line; do
    case "$data_line" in
      FLAGS=*)
        IFS=' ' read -r -a __demo_curl_flags <<< "${data_line#FLAGS=}"
        ;;
      VALUE_FLAGS=*)
        IFS=' ' read -r -a __demo_curl_value_flags <<< "${data_line#VALUE_FLAGS=}"
        ;;
      COMMANDS=*)
        IFS=' ' read -r -a __demo_curl_commands <<< "${data_line#COMMANDS=}"
        ;;
      REQUEST_ENUM=*)
        IFS=' ' read -r -a __demo_curl_request_enum <<< "${data_line#REQUEST_ENUM=}"
        ;;
    esac
  done < <("$data_file" --completion-data)

  __demo_curl_loaded=1
}

_demo_curl_complete() {
  local cur="" prev="" words=() cword=0

  if declare -F _init_completion >/dev/null 2>&1; then
    _init_completion -n : || return
  else
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    words=("${COMP_WORDS[@]}")
    cword=$COMP_CWORD
  fi

  __demo_curl_load_data

  if [[ " ${__demo_curl_value_flags[*]} " == *" ${prev} "* ]]; then
    if [[ "$prev" == "--request" || "$prev" == "-X" ]]; then
      COMPREPLY=( $(compgen -W "${__demo_curl_request_enum[*]}" -- "$cur") )
      return 0
    fi
    COMPREPLY=( $(compgen -f -- "$cur") )
    return 0
  fi

  if [[ "$cur" == -* ]]; then
    COMPREPLY=( $(compgen -W "${__demo_curl_flags[*]}" -- "$cur") )
    return 0
  fi

  if [[ ${COMP_CWORD} -eq 1 ]]; then
    COMPREPLY=( $(compgen -W "${__demo_curl_commands[*]}" -- "$cur") )
  fi
}

complete -F _demo_curl_complete demo-curl
