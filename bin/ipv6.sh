#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-03-26
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"

# shellcheck source=../.scripts/_colors.sh
source "$E_BASH/_colors.sh"

function color_ipv6() {
  local line=$1
  local ipv6s ipv4s

  local ipv6_zone="fe80:(:[0-9a-f]{1,4}){0,7}%[a-z0-9_.-]+"                                            # Link-local IPv6 addresses with zone identifiers
  local ipv4_mapped="::ffff:[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"                            # IPv4-mapped addresses in IPv6 format
  local ipv4_mapped_alt="(0{0,4}:){0,5}ffff:(([0-9]{1,3}\.){3}[0-9]{1,3}|[0-9a-f]{1,4}:[0-9a-f]{1,4})" # Alternative IPv4-mapped notation with optional leading zeros
  local ipv6_full="([0-9a-f]{1,4}:){7}[0-9a-f]{1,4}"                                                   # Standard full IPv6 address
  local ipv6_compressed="([0-9a-f]{1,4}:)*[0-9a-f]{0,4}::[0-9a-f]{0,4}(:[0-9a-f]{1,4})*"               # IPv6 with zero compression (::)
  local ipv6_loopback="(::)"                                                                           # IPv6 loopback (::)

  # Combine all IPv6 patterns
  local ipv6_regex="${ipv6_zone}|${ipv4_mapped}|${ipv4_mapped_alt}|${ipv6_full}|${ipv6_compressed}|${ipv6_loopback}"

  # Extract IPv6 addresses
  ipv6s=$(echo "$line" | grep -oPI "${ipv6_regex}")
  ipv4s=$(echo "$line" | grep -oPI '([0-9]{1,3}\.){3}[0-9]{1,3}')

  echo "${cl_gray}$line${cl_reset}"
  echo "v3: $line" | sed -E 's/(::ffff:[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|(0{0,4}:){0,5}ffff:(([0-9]{1,3}\.){3}[0-9]{1,3}|[0-9a-f]{1,4}:[0-9a-f]{1,4})|(([0-9a-f]{1,4}:){7}[0-9a-f]{1,4}|([0-9a-f]{1,4}:)*[0-9a-f]{0,4}::[0-9a-f]{0,4}(:[0-9a-f]{1,4})*|(::)))/\{IPv6\}/Ig'
  echo "ipv6: ${cl_yellow}${ipv6s/$'\n'/ }${cl_reset}"
  echo "ipv4: ${cl_red}${ipv4s/$'\n'/ }${cl_reset}"
  echo ""
}

# fully expanded
color_ipv6 "test #01: 2001:0db8:0000:0000:0000:0000:0000:0001" # PASSED!
color_ipv6 "test #02: fe80:0000:0000:0000:0202:b3ff:fe1e:8329" # PASSED!

# fully expanded with mask
color_ipv6 "test #03: 2001:0db8:0000:0000:0000:0000:0000:0001/64" # PASSED!

# Leading zero omission
color_ipv6 "test #04: 2001:db8:0:0:0:0:0:1"          # PASSED!
color_ipv6 "test #05: fe80:0:0:0:202:b3ff:fe1e:8329" # PASSED!
color_ipv6 "test #06: fe80::202:b3ff:fe1e:8329/20"   # PASSED!

# Zero compression (::)
color_ipv6 "test #07: 2001:db8::1"              # PASSED!
color_ipv6 "test #08: fe80::202:b3ff:fe1e:8329" # PASSED!
color_ipv6 "test #09: ::1 (loopback)"           # PASSED!
color_ipv6 "test #10: :: (unspecified)"         # PASSED!

# Mixed formats
color_ipv6 "test #11: 2001:0db8::0001"        # PASSED!
color_ipv6 "test #12: 2001:db8:0:0:8d3:0:0:0" # PASSED!
color_ipv6 "test #13: 2001:db8::8d3:0:0:0"    # PASSED!

# IPv4-embedded
color_ipv6 "test #14: ::ffff:192.168.1.1 0:0:0:0:0:ffff:192.168.1.1"                   # PASSED!
color_ipv6 "test #15: 0:0:0:0:0:ffff:c000:280 0000:0000:0000:0000:0000:ffff:c0a8:0101" # PASSED!

# Link-local addresses
color_ipv6 "test #16: fe80::1%eth0 fe80::a1b2:3c4d%en0"          # PASSED, SED - FAILED
color_ipv6 "test #17: fe80::1%1234567890 (same as above in hex)" # PASSED, SED - FAILED

# Multicast
color_ipv6 "test #18: ff00::"  # PASSED!
color_ipv6 "test #19: ff02::1" # PASSED!
color_ipv6 "test #20: ff02::2" # PASSED!

# Documentation/Test ranges
color_ipv6 "test #21: 2001:db8:: (reserved for documentation/examples)" # PASSED!
color_ipv6 "test #22: 2001:db8:1234:ffff:ffff:ffff:ffff:ffff"           # PASSED!
