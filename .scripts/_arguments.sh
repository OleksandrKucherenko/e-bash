#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034,SC2059,SC2154

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-12
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# shellcheck disable=SC2155
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1090 source=_logger.sh
source "$E_BASH/_logger.sh"

# shellcheck disable=SC1090 source=_commons.sh
source "$E_BASH/_commons.sh"

# array of script arguments cleaned from flags (e.g. --help)
[ -z "$ARGS_NO_FLAGS" ] && export ARGS_NO_FLAGS=()
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

# pattern: "{\$argument_index}[,-{short},--{alias}-]=[output]:[init_value]:[args_quantity]"
[ -z "$ARGS_DEFINITION" ] && export ARGS_DEFINITION="-h,--help -v,--version=:1.0.0 --debug=DEBUG:*"

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

  # Remove Windows line endings, replace newlines with spaces, convert multiple spaces to single space
  local preParsed="$(echo -n -e "$ARGS_DEFINITION" | tr -d '\r' | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g') "

  # extract definition of each argument, separated by space, remove last empty element
  readarray -td ' ' definitions <<<"$preParsed" && unset 'definitions[-1]'
  echo:Common "${cl_grey}Extracted: ${definitions[*]}${cl_reset}" >&2

  # build lookup map of arguments, extract the longest name of each argument
  declare -A -g lookup_arguments && lookup_arguments=() # key-to-index_of_definition. e.g. -c -> 0, --cookies -> 0
  declare -A -g index_to_outputs && index_to_outputs=() # index-to-variable_name, e.g. -c,--cookies -> 0=cookies
  declare -A -g index_to_args_qt && index_to_args_qt=() # index-to-argument_quantity, e.g. -c,--cookies -> 0="0"
  declare -A -g index_to_default && index_to_default=() # index-to-argument_default, e.g. -c,--cookies -> 0="", -c=:default:1 -> 0="default"
  declare -A -g index_to_keys && index_to_keys=()       # index-to-keys_definition

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
      index_to_keys[$i]=$(echo "${keys[*]}" | awk -F= '{print $1}')
    done
  done

}

# pattern: "\${argument_index},-{short},--{alias}={output}:{init_value}:{args_quantity}"
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
      echo:Common "[L1] export ${index_to_outputs[$tmp_index]}='$tmpValue'"
      eval "export ${index_to_outputs[$tmp_index]}='$tmpValue'"
    fi

    # process flags
    if [ ${lookup_arguments[$argument]+_} ]; then
      last_processed=$argument
      local tmp_index=${lookup_arguments[$argument]}
      local expected=${index_to_args_qt[$tmp_index]}

      # assign default value to the output variable first
      echo:Common "[L2] export ${index_to_outputs[$tmp_index]}='${index_to_default[$tmp_index]}'"
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
          echo:Common "[L3] export ${index_to_outputs[$tmp_index]}='$value'"
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

          echo:Common "[L4] export ${index_to_outputs[$tmp_index]}='$argument'"
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
    echo:Parser "${cl_grey}extracted: $variable=$var_ref${cl_reset}"
  done
}

# for argument to description mapping
[ -z "$args_to_description" ] && declare -A -g args_to_description=()

# argument to group name mapping
[ -z "$args_to_group" ] && declare -A -g args_to_group=()
[ -z "$group_to_order" ] && declare -A -g group_to_order=()

# argument to environment variable mapping
[ -z "$args_to_envs" ] && declare -A -g args_to_envs=()

# argument to default value mapping
[ -z "$args_to_defaults" ] && declare -A -g args_to_defaults=()

# compose argument description
function args:d() {
  local flag=$1
  local description=$2
  local group=${3:-"common"}
  local known_order=${group_to_order["$group"]}
  local order=${4:-${known_order:-100}}

  args_to_description["$flag"]="${description}"
  args_to_group["$flag"]="${group}"
  group_to_order["$group"]="${order}"

  printf:Parser "%12s -> %s ${cl_grey}group:%s order:%s${cl_reset}\n" "$flag" "$description" "$group" "$order"

  if [[ ! -t 1 ]]; then echo "$flag"; fi # print flag for pipes
}

# compose argument 'variable' mapping, function can be used in pipeline
function args:e() {
  local flag=$1
  local env=$2

  # extract from STDIN provided value
  [[ ! -t 0 ]] && {
    env="$flag"
    read -r -t 0.1 flag
  }

  # update mapping
  args_to_envs["$flag"]="${env}"

  echo:Parser "$flag -> env:$env"

  # echo flag only if we in pipeline mode
  if [[ ! -t 1 ]]; then echo "$flag"; fi # print flag for pipes
}

# compose argument "defaults" mapping, function can be used in pipeline
function args:v() {
  local flag=$1
  local defaults=$2

  # extract from STDIN provided value
  [[ ! -t 0 ]] && {
    defaults="$flag"
    read -r -t 0.1 flag
  }

  # update mapping
  args_to_defaults["$flag"]="${defaults}"

  echo:Parser "$flag -> defaults:$defaults"

  # echo flag only if we in pipeline mode
  if [[ ! -t 1 ]]; then echo "$flag"; fi # print flag for pipes
}

# Compose argument definition string by pattern: "{\$argument_index}[,-{short},--{alias}-]=[output]:[init_value]:[args_quantity]"
function args:i() {
  local output="" description="" aliases=()
  local init_value="" args_quantity="" group="common"

  # Parse positional output
  output="$1" && shift

  # Manual option parsing: support both short and long flags, always treat next positional as value
  while [[ $# -gt 0 ]]; do
    # TODO (olku): we can more options, for example automatic negation parameter registration
    # `--test=test:1` -> `--no-test=test:0`
    case $1 in
    -g | --group)
      shift
      group="$1"
      shift
      ;;
    -h | --help)
      shift
      description="$1"
      shift
      ;;
    -a | --alias)
      shift
      # Split CSV into multiple aliases
      IFS=',' read -ra alias_arr <<<"$1"
      for alias in "${alias_arr[@]}"; do
        alias="${alias## }"
        alias="${alias%% }"
        aliases+=("$alias")
      done
      shift
      ;;
    -q | --quantity)
      shift
      args_quantity="$1"
      shift
      ;;
    -d | --default)
      shift
      init_value="$1"
      shift
      ;;
    --*)
      echo "Error: Unknown option: $1" >&2
      shift
      ;;
    -*)
      echo "Error: Unknown option: $1" >&2
      shift
      ;;
    *)
      # Unexpected positional, ignore
      shift
      ;;
    esac
  done

  local short="" alias_str="" separator="" positional=""

  # Extract short flag if present in aliases
  for alias in "${aliases[@]}"; do
    if [[ $alias == -? ]]; then short="${alias:1}"; fi
    if [[ $alias == "\$"* ]]; then positional="${alias}"; fi
  done

  # Compose alias string
  for alias in "${aliases[@]}"; do
    if [[ $alias == --* ]]; then
      alias_str+="${separator}${alias}"
      separator=","
    elif [[ $alias == -? ]]; then
      : # already handled as short
    fi
  done
  alias_str="${alias_str%,}"

  # Compose the result pattern
  local result="${positional}"
  [[ -n $short ]] && result+="$([ ! -z "$result" ] && echo ",")-$short"
  [[ -n $alias_str ]] && result+="$([ ! -z "$result" ] && echo ",")${alias_str}"
  result+="=${output}:"
  [[ -n $init_value ]] && result+="${init_value}:" || result+=":"
  [[ -n $args_quantity ]] && result+="${args_quantity}"

  # Optionally, register description mapping if provided (use first alias or short flag)
  if [[ -n $description ]]; then
    local desc_flag=""
    if [[ ${#aliases[@]} -gt 0 ]]; then
      desc_flag="${aliases[0]}"
    elif [[ -n $short ]]; then
      desc_flag="-$short"
    fi
    if [[ -n $desc_flag ]]; then
      # shellcheck disable=SC2294
      echo "args:d \"${desc_flag}\" \"${description}\" \"${group}\""
      #args:d "${desc_flag}" "${description}" "${group}"
    fi
  fi

  # print result with trimming trailing colons at the end of line
  echo "export ARGS_DEFINITION+=\" $(echo "$result" | sed 's/:\{1,\}$//g') \""
}

# print help for ARGS_DEFINITION parameters
function print:help() {
  # collect unique group names
  local groups=() group=""
  for group in "${args_to_group[@]}"; do
    # shellcheck disable=SC2199,SC2076
    [[ ! " ${groups[@]} " =~ " ${group} " ]] && groups+=("$group")
  done

  # get length of the $groups array
  local groups_length=${#groups[@]}

  # sort groups by order stored in group_to_order array
  # create "group:order" pairs first
  local unsorted_groups=()
  for group in "${groups[@]}"; do
    unsorted_groups+=("$group:${group_to_order[$group]}")
  done
  echo:Parser "unsorted groups: ${unsorted_groups[*]}"

  # sort groups by order
  # shellcheck disable=SC2207
  local sorted_groups=($(printf '%s\n' "${unsorted_groups[@]}" | sort -k2,2n -k1,1 -t: | awk -F: '{print $1}'))
  echo:Parser "sorted groups: ${sorted_groups[*]}"
  groups=("${sorted_groups[@]}")

  # print help for each group
  for group in "${groups[@]}"; do
    # print group name only if have multiple groups
    [ "$groups_length" -gt 1 ] && echo "group: ${cl_lwhite}$group${cl_reset}"

    # find all flags that belongs to the group
    local one_group=() flag=""
    for flag in "${!args_to_group[@]}"; do
      [ "${args_to_group[$flag]}" == "$group" ] && one_group+=("$flag")
    done

    # get max length of aliases inside one group
    local max_length=0
    for flag in "${one_group[@]}"; do
      local aliases="${index_to_keys[${lookup_arguments[$flag]}]}"
      aliases="${aliases// /, }"
      local length=${#aliases}
      [ "$length" -gt "$max_length" ] && max_length="$length"
    done

    # make separator of max_length
    local separator="   " # 3 spaces at least
    for ((i = 0; i < max_length; i++)); do
      separator+=" "
    done

    # sort flags inside one_group alphabetically
    # shellcheck disable=SC2207
    IFS=$'\n' one_group=($(sort <<<"${one_group[*]}")) && unset IFS

    # print each flag description
    for flag in "${one_group[@]}"; do
      # get aliases for flag
      # lookup_arguments (resolve flag to index), index_to_keys (resolve index to keys)
      # replace " " by ", " in aliases
      local aliases="${index_to_keys[${lookup_arguments[$flag]}]}"
      aliases="${aliases// /, }"

      local length=${#aliases}
      local padding="${separator:$((length - 1))}"
      local description="${args_to_description[$flag]:-""}"
      local env="${args_to_envs[$flag]:-""}"
      local defaults="${args_to_defaults[$flag]:-""}"
      local divider=", "
      local open="(" close=")"

      [ -n "$env" ] && env="env: $env"
      [ -n "$defaults" ] && defaults="default: $defaults"
      [[ -z "$env" ]] || [[ -z "$defaults" ]] && divider="" && open="" && close=""

      printf "  %s%s%s %s\n" "${cl_cyan}${aliases}${cl_reset}" "${padding}" \
        "${cl_white}${description}${cl_reset}" \
        "${cl_grey}${open}${env}${divider}${defaults}${close}${cl_reset}"
    done

    echo ""
  done
}

# This is the writing style presented by ShellSpec, which is short but unfamiliar.
# Note that it returns the current exit status (could be non-zero).
# DO NOT allow execution of code bellow those line in shellspec tests
${__SOURCED__:+return}

logger common "$@" # register own logger
logger:init parser "${cl_blue}[parser]${cl_reset} "

logger loader "$@" # initialize logger
echo:Loader "loaded: ${cl_grey}${BASH_SOURCE[0]}${cl_reset}"

parse:exclude_flags_from_args "$@"                  # pre-filter arguments from flags
[ -z "$SKIP_ARGS_PARSING" ] && parse:arguments "$@" # parse arguments and assign them to output variables
