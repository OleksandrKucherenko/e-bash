#!/usr/bin/env bash
# shellcheck disable=SC2154

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-03-16
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# include other scripts
# shellcheck disable=SC1090 source=../.scripts/_dependencies.sh
source "$E_BASH/_dependencies.sh"
# shellcheck disable=SC1090 source=../.scripts/_commons.sh
source "$E_BASH/_commons.sh"

NO_DESCRIPTION="no description found"

function validate_dependencies() {
  dependency bash "[45].*.*" "brew install bash"
  dependency ggrep "3.*" "brew install grep"
  dependency gsed "4.*" "brew install gnu-sed"
}

function print_warning() {
  echo "${cl_yellow}Warning${cl_reset}:" "Please fix all variables descriptions:" "${cl_grey}/* ${cl_red}${NO_DESCRIPTION}${cl_grey} */${cl_reset}"
  echo "Follow the declaration pattern:"
  echo "  #"
  echo "  # {description}"
  echo "  #"
  echo "  export VARIABLE={secret}"
  echo ""
  echo "Note: more than three comment lines upfront the variable declaration will be ignored."
}

function parse_file() {
  local file=${1:-".envrc"}
  export isWarning=false

  mapfile -t array < <(cat "${file}")

  # get list of exports from direnv file
  for ((i = 0; i < ${#array[@]}; i++)); do
    line=${array[$i]}
    if [[ $line == export\ * ]]; then
      variable=$(echo "${line}" | ggrep -oP "export [^=]*" | gsed "s#export \(.*\)#\1#")
      comment1=$(echo "${array[$((i - 3))]}" | ggrep "^#" | gsed "s/#/¶/g")
      comment2=$(echo "${array[$((i - 2))]}" | ggrep "^#" | gsed "s/#/¶/g")
      comment3=$(echo "${array[$((i - 1))]}" | ggrep "^#" | gsed "s/#/¶/g")
      comment="${cl_red}${NO_DESCRIPTION}${cl_grey}"

      if [[ ${#comment3} -gt 0 && ${#comment2} -gt 0 && ${#comment1} -gt 0 ]]; then
        comment="$comment1$comment2$comment3"
      elif [[ ${#comment3} -gt 0 && ${#comment2} -gt 0 ]]; then
        comment="$comment2$comment3"
      elif [[ ${#comment3} -gt 0 ]]; then
        comment=$comment3
      else
        isWarning=true
      fi

      description=$(echo "${comment}" | gsed "s/¶¶//g;s/¶$//g;s/^¶//g;s/^ //g;s/ $//g;s/¶//g;")

      echo "${variable} - ${cl_grey}/* ${description} */${cl_reset}"
    fi
  done
}

function main() {
  validate_dependencies

  # separator
  echo ""

  # global variables: isWarning published
  parse_file ".envrc"

  # separator
  echo ""

  # print warning if no description found for at least one variable
  if $isWarning; then
    print_warning
  fi

  echo "All Done!"
}

main "$@"
