#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034,SC2059

# declare global associative array
if [[ -z $TAGS ]]; then declare -g -A TAGS; fi
if [[ -z $TAGS_PREFIX ]]; then declare -g -A TAGS_PREFIX; fi

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
      [[ "\${TAGS[$tag]}" == "1" ]] && builtin echo "\${TAGS_PREFIX[$tag]}\$@"
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

# This is the writing style presented by ShellSpec, which is short but unfamiliar.
# Note that it returns the current exit status (could be non-zero).
${__SOURCED__:+return}
