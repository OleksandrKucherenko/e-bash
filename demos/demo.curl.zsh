#compdef demo-curl

# Zsh completion for demo.curl.sh
# Usage (zsh):
#   fpath=("${0:A:h}" $fpath)
#   autoload -U compinit && compinit

__demo_curl_loaded=""
__demo_curl_flags=()
__demo_curl_value_flags=()
__demo_curl_commands=()
__demo_curl_request_enum=()

__demo_curl_load_data() {
  local data_line="" data_file="" script_dir=""

  [[ -n "$__demo_curl_loaded" ]] && return 0

  script_dir="${0:A:h}"
  data_file="${script_dir}/demo.curl.sh"

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
  local cur="" prev=""

  setopt local_options no_aliases

  cur="${words[CURRENT]}"
  prev="${words[CURRENT-1]}"

  __demo_curl_load_data

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

compdef _demo_curl_complete demo-curl
