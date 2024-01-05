#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034,SC2059,SC2154

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2023-10-18
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# one time initialization, CUID
[[ "${clr0ljyne0004og38nhbnvpal}" == "yes" ]] && return 0 || export clr0ljyne0004og38nhbnvpal="yes"

# shellcheck disable=SC1090 source=_logger.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_logger.sh"

# shellcheck disable=SC1090 source=_commons.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_commons.sh"

# array of script arguments cleaned from flags (e.g. --help)
if [ -z "$ARGS_NO_FLAGS" ]; then export ARGS_NO_FLAGS=(); fi
function parse:exclude_flags_from_args() {
  local args=("$@")

  # remove all flags from call
  for i in "${!args[@]}"; do
    if [[ ${args[i]} == --* ]]; then unset 'args[i]'; fi
  done

  echo:Common "${cl_grey}Filtered args:" "$@" "~>" "${args[*]}" "${cl_reset}" >&2

  # shellcheck disable=SC2207,SC2116
  ARGS_NO_FLAGS=($(echo "${args[*]}"))
}

if [ -z "$ARGS_DEFINITION" ]; then export ARGS_DEFINITION="-h,--help -v,--version=:1.0.0 --debug=DEBUG:*"; fi

# Utility function, that extract output definition for parse:arguments function
function parse:extract_output_definition() {
  local definition=$1

  # extract output variable name, examples:
  local name=${definition%%=*}
  local name_as_value=${name//-/}
  local output=$(echo "$2" | awk -v def="$definition" -F'=' '{ if ($2) {print $2} else {print def} }')
  local variable=""
  local default="1"
  local args_qt="0"

  # extract variable name
  if [[ "$output" == "$definition" ]]; then # simplest: --cookies
    variable=$name_as_value
  elif [[ "$output" == *:* ]]; then # extended: --cookies=first:*, --cookies=first:default:1, --cookies=::1, --cookies=:, --cookies=first:
    local tmp=${output%%:*} && variable=${tmp:-"$name_as_value"}
  else
    variable=$output # extended: --cookies=first
  fi

  # extract default value
  if [[ "$output" == *:* ]]; then default=${output#*:} && default=${default%:*}; fi

  # extract arguments quantity
  if [[ "$output" == *:*:* ]]; then args_qt=${output##*:}; fi

  # indexed arguments should expect only one parameter/argument
  if [[ "$args_qt" -gt 1 ]] && [[ "$1" == "\$"* ]]; then
    echo "Warning. Indexed variable '$1' should not be used for multiple arguments." >&2
  fi
  echo:Common "${cl_grey}$1 '$2' ~> $variable|$default|$args_qt${cl_reset}" >&2

  echo "$variable|$default|$args_qt"
}

# parse ARGS_DEFINITION string to global arrays: lookup_arguments, index_to_outputs, index_to_args_qt, index_to_default
function parse:mapping() {
  local args=("$@")

  # TODO (olku): trim whitespaces in $ARGS_DEFINITION, no spaces in beginning or end, no double spaces
  echo:Common "${cl_grey}Definition: $ARGS_DEFINITION${cl_reset}" >&2

  # extract definition of each argument, separated by space, remove last empty element
  readarray -td ' ' definitions <<<"$ARGS_DEFINITION " && unset 'definitions[-1]'

  # build lookup map of arguments, extract the longest name of each argument
  declare -A -g lookup_arguments && lookup_arguments=() # key-to-index_of_definition. e.g. -c -> 0, --cookies -> 0
  declare -A -g index_to_outputs && index_to_outputs=() # index-to-variable_name, e.g. -c,--cookies -> 0=cookies
  declare -A -g index_to_args_qt && index_to_args_qt=() # index-to-argument_quantity, e.g. -c,--cookies -> 0="0"
  declare -A -g index_to_default && index_to_default=() # index-to-argument_default, e.g. -c,--cookies -> 0="", -c=:default:1 -> 0="default"

  # build parameters mapping
  for i in "${!definitions[@]}"; do
    # TODO (olku): validate the pattern format, otherwise throw an error
    # shellcheck disable=SC2206
    local keys=(${definitions[i]//,/ })
    for key in "${keys[@]}"; do
      local name=${key%%=*} # extract clean key name, e.g. --cookies=first -> --cookies
      local helper=$(parse:extract_output_definition "$key" "${definitions[i]}")

      # do the mapping
      lookup_arguments[$name]=$i
      index_to_outputs[$i]=$(echo "$helper" | awk -F'|' '{print $1}')
      index_to_args_qt[$i]=$(echo "$helper" | awk -F'|' '{print $3}')
      index_to_default[$i]=$(echo "$helper" | awk -F'|' '{print $2}')
    done
  done

}

# pattern: "{argument},-{short},--{alias}={output}:{init_value}:{args_quantity}"
function parse:arguments() {
  local args=("$@")

  parse:mapping "$@"

  local index=1             # indexed input arguments without pre-flag
  local skip_next_counter=0 # how many argument to skip from processing
  local skip_aggregated=""  # all skipped arguments placed into one array
  local last_processed=""   # last processed argument
  local separator=""        # separator between aggregated arguments

  # parse the script arguments and resolve them to output variables
  for i in "${!args[@]}"; do
    local argument=${args[i]}
    local value=""
    local by_index="\$$index"

    # extract key and value from argument, if used format `--key=value`
    # shellcheck disable=SC2206
    if [[ "$argument" == *=* ]]; then local tmp=(${argument//=/ }) && value=${tmp[1]:-"<empty>"} && argument=${tmp[0]}; fi

    # accumulate arguments that reserved by last processed argument
    if [ "$skip_next_counter" -gt 0 ]; then
      skip_next_counter=$((skip_next_counter - 1))
      skip_aggregated="${skip_aggregated}${separator}${argument}"
      separator=" "
      continue
    fi

    # if skipped aggregated var contains value assign it to the last processed argument
    if [ ${#skip_aggregated} -gt 0 ]; then
      local tmpValue="$skip_aggregated" && skip_aggregated="" && separator=""

      # assign aggregated value to output variable
      local tmp_index=${lookup_arguments[$last_processed]}
      echo:Common "[$LINENO] export ${index_to_outputs[$tmp_index]}='$tmpValue'"
      eval "export ${index_to_outputs[$tmp_index]}='$tmpValue'"
    fi

    # process flags
    if [ ${lookup_arguments[$argument]+_} ]; then
      last_processed=$argument
      local tmp_index=${lookup_arguments[$argument]}
      local expected=${index_to_args_qt[$tmp_index]}

      # assign default value to the output variable first
      echo:Common "[$LINENO] export ${index_to_outputs[$tmp_index]}='${index_to_default[$tmp_index]}'"
      eval "export ${index_to_outputs[$tmp_index]}='${index_to_default[$tmp_index]}'"

      # if expected more arguments than provided, configure skip_next_counter
      if [ "$expected" -gt 0 ]; then
        skip_next_counter=$expected
        skip_aggregated="$value" # assign current value to the skip_aggregated
        if [ -n "$value" ]; then skip_next_counter=$((skip_next_counter - 1)) && separator=" "; fi
        # TODO: we have DEFAULT value for the argument, but we can't use it, because we need
        #   to check next argument, and if its a 'flag' apply DEFAULTS, otherwise use the
        #   provided argument
        continue
      else
        # default value is re-assigned by provided value
        if [ -n "$value" ]; then
          echo:Common "[$LINENO] export ${index_to_outputs[$tmp_index]}='$value'"
          eval "export ${index_to_outputs[$tmp_index]}='$value'"
        fi
      fi
    else
      # process plain unnamed arguments
      case $argument in
      -*) echo:Common "${cl_grey}ignored: $argument ($value)${cl_reset}" >&2 ;;
      *)
        if [ ${lookup_arguments[$by_index]+_} ]; then
          last_processed=$by_index
          local tmp_index=${lookup_arguments[$by_index]}

          echo:Common "[$LINENO] export ${index_to_outputs[$tmp_index]}='$argument'"
          eval "export ${index_to_outputs[$tmp_index]}='$argument'"
        else
          echo:Common "${cl_grey}ignored: $argument [$by_index] vs $last_processed:$skip_next_counter:$skip_aggregated:$value ${cl_reset}" >&2
        fi
        index=$((index + 1))
        ;;
      esac
    fi
  done

  if [ "$skip_next_counter" -gt 0 ]; then
    echo "Error. Too little arguments provided"
    exit 1
  fi

  # if aggregated var contains something
  if [ ${#skip_aggregated} -gt 0 ]; then
    local value="$skip_aggregated" && skip_aggregated="" && separator=""
    local tmp_index=${lookup_arguments[$last_processed]}
    echo:Common "[$LINENO] export ${index_to_outputs[$tmp_index]}='$value'"
    eval "export ${index_to_outputs[$tmp_index]}='$value'"
  fi

  # debug output
  echo:Common "definition to output index:"
  printf:Common '%s\n' "${!definitions[@]}" "${definitions[@]}" | pr -2t
  echo:Common "'index', 'output variable name', 'args quantity', 'defaults':"
  printf:Common '\"%s\"\n' "${!index_to_outputs[@]}" "${index_to_outputs[@]}" "${index_to_args_qt[@]}" "${index_to_default[@]}" | pr -4t | sort
  for variable in "${index_to_outputs[@]}"; do
    declare -n var_ref=$variable
    echo:Common "${cl_grey}extracted: $variable=$var_ref${cl_reset}"
  done
}

# global associative array for flag-to-description mapping
if [ -z "$args_to_description" ]; then declare -A -g args_to_description=(); fi
if [ -z "$args_to_group" ]; then declare -A -g args_to_group=(); fi

function parse:descr() {
  local flag=$1
  local description=$2
  local group=${3:-"common"}
  local order=${4:-100}

  args_to_description[flag]="${description}"
  args_to_group[flag]="${group}"
}

# print help for ARGS_DEFINITION parameters
function print:help() {
  # if multiple groups defined in $args_to_group then print each group separately
  if [ ${#args_to_group[@]} -gt 1 ]; then
    : # TODO (olku): implement me, compose HELP documentation from definitions
  fi

  # print help for each argument
}

# This is the writing style presented by ShellSpec, which is short but unfamiliar.
# Note that it returns the current exit status (could be non-zero).
# DO NOT allow execution of code bellow those line in shellspec tests
${__SOURCED__:+return}

logger common "$@" # register own logger

logger loader "$@" # initialize logger
echo:Loader "loaded: ${cl_grey}${BASH_SOURCE[0]}${cl_reset}"

parse:exclude_flags_from_args "$@" # pre-filter arguments from flags
parse:arguments "$@"               # parse arguments and assign them to output variables

# common descriptions for arguments
parse:descr "-h" "Print utility help"
parse:descr "--debug" "Force debug output of the tool"
parse:descr "-v" "Display tool version and exit"
