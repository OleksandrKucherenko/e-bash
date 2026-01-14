#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-14
## Version: 2.0.2
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

DEBUG=${DEBUG:-"-ipv6,-regex"}

# Bootstrap: 1) E_BASH discovery (only if not set), 2) gnubin setup (always)
[ "$E_BASH" ] || { _src=${BASH_SOURCE:-$0}; E_BASH=$(cd "${_src%/*}/../.scripts" 2>&- && pwd || echo ~/.e-bash/.scripts); readonly E_BASH; }
. "$E_BASH/_gnu.sh"; PATH="$(cd "$E_BASH/../bin/gnubin" 2>&- && pwd):$PATH"

# shellcheck source=../.scripts/_colors.sh
source "$E_BASH/_colors.sh"
# shellcheck source=../.scripts/_logger.sh
source "$E_BASH/_logger.sh"

# compose logger for debugging
logger ipv6 "$@" && logger:prefix ipv6 "[${cl_gray}ipv6${cl_reset}] " && logger:redirect ipv6 ">&2"

# compose regex for matching ipv6 in GNU grep style, print it to STDOUT
function ipv6:grep() {
  local ipv6_zone="fe80:(:[0-9a-f]{1,4}){0,7}%[a-z0-9_.-]+"                                            # Link-local IPv6 addresses with zone identifiers
  local ipv4_mapped="::ffff:[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"                            # IPv4-mapped addresses in IPv6 format
  local ipv4_mapped_alt="(0{0,4}:){0,5}ffff:(([0-9]{1,3}\.){3}[0-9]{1,3}|[0-9a-f]{1,4}:[0-9a-f]{1,4})" # Alternative IPv4-mapped notation with optional leading zeros
  local ipv6_full="([0-9a-f]{1,4}:){7}[0-9a-f]{1,4}"                                                   # Standard full IPv6 address
  local ipv6_compressed="([0-9a-f]{1,4}:)*[0-9a-f]{0,4}::[0-9a-f]{0,4}(:[0-9a-f]{1,4})*"               # IPv6 with zero compression (::)
  local ipv6_loopback="(::)"                                                                           # IPv6 loopback (::)

  # Combine all IPv6 patterns
  local grep_regex="${ipv6_zone}|${ipv4_mapped}|${ipv4_mapped_alt}|${ipv6_full}|${ipv6_compressed}|${ipv6_loopback}"

  echo "${grep_regex}"

  # debug output
  if type echo:Regex &>/dev/null; then
    echo:Regex "${grep_regex}" >&2
  fi
}

# ref1: https://regex101.com/r/uwPxJf/10
function color:ipv6() {
  local line=$1 grep_regex seeds
  local ipv6s ipv4s seeds

  # Combine all IPv6 patterns
  grep_regex=$(ipv6:grep)
  local sed_regex="${grep_regex}"

  # Extract IPv6 addresses
  ipv6s=$(echo "$line" | ggrep -oPI "${grep_regex}")
  ipv4s=$(echo "$line" | ggrep -oPI '([0-9]{1,3}\.){3}[0-9]{1,3}') # IPv4 addresses format

  echo:Ipv6 "${cl_gray}$line${cl_reset}"

  # Break down regex into components for readability
  local marker="\{IPv6\}"
  local sed_replace="s/(${sed_regex})/${cl_lgreen}${marker}${cl_reset}/Ig"

  # Combine all patterns into a single regex
  seeds=$(echo "$line" | gsed -E "$sed_replace")

  # Use the combined regex in the sed command
  echo:Ipv6 "$seeds"
  echo:Ipv6 "ipv6: ${cl_yellow}${ipv6s/$'\n'/ }${cl_reset}"
  echo:Ipv6 "ipv4: ${cl_red}${ipv4s/$'\n'/ }${cl_reset}"

  # iterate on seeds string until we replace all {IPv6} (marker) tags with proper ipv6 addresses
  # ipv6s may contain multiple ipv6 addresses separated by space
  local final="${seeds}"
  for ipv6 in $ipv6s; do
    # Replace only the first occurrence of the marker with the current IPv6 address
    final=$(echo "$final" | gsed -E "0,/${marker}/s/${marker}/${ipv6}/")
  done
  echo "$final"
}

# convert ipv6 from `2001:0db8:0000:0000:0000:0000:0000:0001` to `2001:db8::1` form.
function ipv6:compress() {
  echo "$1" | gsed -E 's/(0{1,4}:){1,}/::/g; s/:{2,}/::/g; s/:0{1,}/:/g'
}

# convert ipv6 from `2001:db8::1` to `2001:0db8:0000:0000:0000:0000:0000:0001` form.
function ipv6:expand() {
  local line="$1" final grep_regex sections replacer
  grep_regex=$(ipv6:grep)
  local sub=":0000"

  # count how many ':' we have in $line, excluding '::'.
  # example: 2001:db8::1 --> 3 (sub-sections is available)
  # example: 20::1 --> 2 (sub-sections is available)
  # example: 2001:db8::8d3:0:0:0 --> 6 (sub-sections is available)
  sections=$(echo "$line" | gsed -E 's/::/:/g' | tr -cd ':' | wc -c)
  local missing=$((7 - sections))
  echo:Ipv6 "sections: $((sections + 1)), missing: $missing"

  # start from 7 sub-sections and go down to 2, until we catch that grep returns a captured value
  replacer="$(printf "%0.s$sub" $(seq 1 $missing)):"
  local sed_replace="s/::/${replacer}/g"
  final=$(echo "$line" | gsed -E "$sed_replace" | ggrep -oPI "${grep_regex}")

  # now its time to add leading zeros to each sub-section of ipv6
  IFS=':' read -ra parts <<<"$final" && unset IFS
  final=$(printf '0000%s\n' "${parts[@]}" | gsed -E 's/.*([0-9a-f]{4}$)/\1/gi' | tr '\n' ':' | gsed 's/:$//g')
  echo "$final"
}

# This is the writing style presented by ShellSpec, which is short but unfamiliar.
# Note that it returns the current exit status (could be non-zero).
${__SOURCED__:+return}

logger regex "$@"           # declare echo:Regex & printf:Regex functions
logger:redirect regex ">&2" # redirect regex to STDERR
