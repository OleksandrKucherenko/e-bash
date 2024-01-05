#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034,SC2059

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2023-10-18
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# one time initialization, CUID
[[ "${clr0li2550002og38iiryffm8}" == "yes" ]] && return 0 || export clr0li2550002og38iiryffm8="yes"

# declare global associative array
if [[ -z $TAGS ]]; then declare -g -A TAGS; fi
if [[ -z $TAGS_PREFIX ]]; then declare -g -A TAGS_PREFIX; fi
if [[ -z $TAGS_STACK ]]; then declare -g TAGS_STACK="0"; fi

#
# Create a dynamic functions with a Tag name as a suffix
#
function logger:compose() {
  local tag=${1}
  local suffix=$2

  cat <<EOF
    #
    # begin
    #
    function echo:${suffix}() {
      [[ "\${TAGS[$tag]}" == "1" ]] && (builtin echo -n "\${TAGS_PREFIX[$tag]}"; builtin echo "\$@";)
    }

    function printf:${suffix}() {
      [[ "\${TAGS[$tag]}" == "1" ]] && builtin printf "%s%s" "\${TAGS_PREFIX[$tag]}" "\$(builtin printf "\$@")"
    }

    function config:logger:${suffix}() {
      local args=("\$@")
      IFS="," read -r -a tags <<<\$(echo "\$DEBUG")
      [[ "\${args[*]}" =~ "--debug" ]] && TAGS+=([$tag]=1)
      [[ "\${tags[*]}" =~ "$tag" ]] && TAGS+=([$tag]=1)
      [[ "\${tags[*]}" =~ "*" ]] && TAGS+=([$tag]=1)
      [[ "\${tags[*]}" =~ "-$tag" ]] && TAGS+=([$tag]=0)
      #builtin echo "done! \${!TAGS[@]} \${TAGS[@]}"
    }
    # alternative names
    alias configDebug${suffix}=config:logger:${suffix}
    alias echo${suffix}=echo:${suffix}
    alias printf${suffix}=printf:${suffix}
    #
    # end
    #
EOF
}

#
# Register debug logger functions that are controlled by DEBUG= environment variable
#
function logger() {
  #
  # Usage:
  #   source "$SCRIPT_DIR/commons.sh" && logger tag "$@"
  #   echoTag "print only if DEBUG=tag is set"
  #   printfTag "print only if DEBUG=tag is set %s" "something"
  #
  local tag=${1}
  local suffix=${1^}
  # local suffix=$(echo "$1" | sed -e "s/\b\(.\)/\u\1/g")

  # check if logger already exists, then skip
  if type "echo:${suffix}" &>/dev/null; then return 0; fi

  # keep it disabled by default
  TAGS+=([$tag]=0)

  # declare logger functions
  # source /dev/stdin <<EOF
  eval "$(logger:compose "$tag" "$suffix")"

  # configure logger
  # shellcheck disable=SC2294
  eval "config:logger:${suffix}" "$@" 2>/dev/null

  # dump created loggers
  # shellcheck disable=SC2154
  [[ "$tag" != "common" ]] && (
    # ignore output error
    eval "echo:Common \"Logger tags  :\" \"\${!TAGS[@]}\" \"|\" \"\${TAGS[@]}\" " 2>/dev/null | tee >(cat >&2)
  )

  return 0 # force exit code success
}

# save current $TAGS state
# bashsupport disable=BP2001
function logger:push() {
  TAGS_STACK=$((TAGS_STACK + 1))
  local new_stack="__TAGS_STACK_$TAGS_STACK"
  declare -g -A "$new_stack"

  # shellcheck disable=SC1087
  for key in "${!TAGS[@]}"; do
    eval "$new_stack[\"$key\"]=\"${TAGS[$key]}\""
  done
}

# recover previous $TAGS state
function logger:pop() {
  local stacked="__TAGS_STACK_$TAGS_STACK"
  TAGS_STACK=$((TAGS_STACK - 1))

  unset TAGS && declare -g -A TAGS

  # shellcheck disable=SC1087
  eval "for key in \"\${!$stacked[@]}\"; do eval \"TAGS[\\\"\$key\\\"]=\\\${$stacked[\\\"\$key\\\"]}\"; done"

  unset "$stacked"
}

# This is the writing style presented by ShellSpec, which is short but unfamiliar.
# Note that it returns the current exit status (could be non-zero).
${__SOURCED__:+return}

logger loader "$@" # initialize logger
echo:Loader "loaded: ${cl_grey}${BASH_SOURCE[0]}${cl_reset}"
