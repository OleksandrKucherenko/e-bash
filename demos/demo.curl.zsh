#compdef demo-curl demo.curl.sh demos/demo.curl.sh ./demos/demo.curl.sh

# Zsh completion for demo.curl.sh
# Usage (zsh):
#   autoload -Uz compinit && compinit
#   source demos/demo.curl.zsh

__demo_curl_loaded=""
__demo_curl_flags=()
__demo_curl_value_flags=()
__demo_curl_commands=()
__demo_curl_request_enum=()
__demo_curl_source_file="${${(%):-%N}:A}"
__demo_curl_script_dir="${__demo_curl_source_file:h}"

__demo_curl_resolve_data_file() {
  local command_word="${1:-}" command_path="" data_file=""

  if [[ -n "$command_word" ]]; then
    if [[ "$command_word" == */* ]] && [[ -f "$command_word" ]]; then
      command_path="${command_word:A}"
    elif (( ${+commands[$command_word]} )); then
      command_path="${commands[$command_word]}"
    fi
  fi

  [[ -f "$command_path" ]] && {
    echo "$command_path"
    return 0
  }

  data_file="${__demo_curl_script_dir}/demo.curl.sh"
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
        __demo_curl_flags=(${(s: :)${data_line#FLAGS=}})
        ;;
      VALUE_FLAGS=*)
        __demo_curl_value_flags=(${(s: :)${data_line#VALUE_FLAGS=}})
        ;;
      COMMANDS=*)
        __demo_curl_commands=(${(s: :)${data_line#COMMANDS=}})
        ;;
      REQUEST_ENUM=*)
        __demo_curl_request_enum=(${(s: :)${data_line#REQUEST_ENUM=}})
        ;;
    esac
  done < <("$data_file" --completion-data)

  __demo_curl_loaded=1
}

_demo_curl_complete() {
  local cur="" prev="" command_word=""

  setopt local_options no_aliases

  cur="${words[CURRENT]}"
  prev="${words[CURRENT-1]}"

  command_word="${words[1]}"
  __demo_curl_load_data "$command_word" || return 0

  if [[ " ${__demo_curl_value_flags[*]} " == *" ${prev} "* ]]; then
    if [[ "$prev" == "--request" || "$prev" == "-X" ]]; then
      compadd -- "${__demo_curl_request_enum[@]}"
      return 0
    fi
    _files
    return 0
  fi

  if [[ "$cur" == -* ]]; then
    compadd -- "${__demo_curl_flags[@]}"
    return 0
  fi

  if [[ $CURRENT -eq 2 ]]; then
    compadd -- "${__demo_curl_commands[@]}"
  fi
}

_demo_curl_register() {
  local script_path="${__demo_curl_script_dir}/demo.curl.sh"
  local -a names=(
    demo-curl
    demo.curl.sh
    demos/demo.curl.sh
    ./demos/demo.curl.sh
    "${script_path}"
  )
  compdef _demo_curl_complete "${names[@]}"
}

(( $+functions[compdef] )) && _demo_curl_register
