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

__demo_curl_resolve_data_file() {
  local command_word="${1:-}" data_file="" command_path="" script_dir=""

  script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>&- && pwd)

  if [[ -n "$command_word" ]]; then
    if [[ "$command_word" == */* ]] && [[ -f "$command_word" ]]; then
      command_path=$(cd "$(dirname "$command_word")" 2>&- && pwd)/$(basename "$command_word")
    elif command -v "$command_word" >/dev/null 2>&1; then
      command_path="$(command -v "$command_word")"
    fi
  fi

  [[ -f "$command_path" ]] && {
    echo "$command_path"
    return 0
  }

  data_file="${script_dir}/demo.curl.sh"
  [[ -f "$data_file" ]] && {
    echo "$data_file"
    return 0
  }

  return 1
}

__demo_curl_load_data() {
  local data_line="" data_file="" command_word="${1:-}"

  [[ -n "$__demo_curl_loaded" ]] && return 0

  data_file="$(__demo_curl_resolve_data_file "$command_word")" || return 1

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
  local cur="" prev="" words=() cword=0 command_word=""

  if declare -F _init_completion >/dev/null 2>&1; then
    _init_completion -n : || return
  else
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    words=("${COMP_WORDS[@]}")
    cword=$COMP_CWORD
  fi

  command_word="${COMP_WORDS[0]}"
  __demo_curl_load_data "$command_word" || return 0

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

_demo_curl_register() {
  local names=(
    demo-curl
    demo.curl.sh
    demos/demo.curl.sh
    ./demos/demo.curl.sh
  )
  local one=""

  for one in "${names[@]}"; do
    complete -F _demo_curl_complete "$one"
  done
}

_demo_curl_register
