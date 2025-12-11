#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-10
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

DEBUG=${DEBUG:-"-ipv6,-regex"}

# shellcheck disable=SC2155 # evaluate E_BASH from project structure if it's not set
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../.scripts && pwd)"

# shellcheck source=../bin/ipv6.sh
source "$E_BASH/../bin/ipv6.sh"

# fully expanded
color:ipv6 "test #01: 2001:0db8:0000:0000:0000:0000:0000:0001" # PASSED!
color:ipv6 "test #02: fe80:0000:0000:0000:0202:b3ff:fe1e:8329" # PASSED!

# fully expanded with mask
color:ipv6 "test #03: 2001:0db8:0000:0000:0000:0000:0000:0001/64" # PASSED!

# Leading zero omission
color:ipv6 "test #04: 2001:db8:0:0:0:0:0:1"          # PASSED!
color:ipv6 "test #05: fe80:0:0:0:202:b3ff:fe1e:8329" # PASSED!
color:ipv6 "test #06: fe80::202:b3ff:fe1e:8329/20"   # PASSED!

# Zero compression (::)
color:ipv6 "test #07: 2001:db8::1"              # PASSED!
color:ipv6 "test #08: fe80::202:b3ff:fe1e:8329" # PASSED!
color:ipv6 "test #09: ::1 (loopback)"           # PASSED!
color:ipv6 "test #10: :: (unspecified)"         # PASSED!

# Mixed formats
color:ipv6 "test #11: 2001:0db8::0001"        # PASSED!
color:ipv6 "test #12: 2001:db8:0:0:8d3:0:0:0" # PASSED!
color:ipv6 "test #13: 2001:db8::8d3:0:0:0"    # PASSED!

# IPv4-embedded
color:ipv6 "test #14: ::ffff:192.168.1.1 vs 0:0:0:0:0:ffff:192.168.1.1"                   # PASSED!
color:ipv6 "test #15: 0:0:0:0:0:ffff:c000:280 vs 0000:0000:0000:0000:0000:ffff:c0a8:0101" # PASSED!

# Link-local addresses
color:ipv6 "test #16: fe80::1%eth0 and fe80::a1b2:3c4d%en0"      # PASSED!
color:ipv6 "test #17: fe80::1%1234567890 (same as above in hex)" # PASSED!

# Multicast
color:ipv6 "test #18: ff00::"  # PASSED!
color:ipv6 "test #19: ff02::1" # PASSED!
color:ipv6 "test #20: ff02::2" # PASSED!

# Documentation/Test ranges
color:ipv6 "test #21: 2001:db8:: (reserved for documentation/examples)" # PASSED!
color:ipv6 "test #22: 2001:db8:1234:ffff:ffff:ffff:ffff:ffff"           # PASSED!

# expected: 2001:db8::1
ipv6:compress "2001:0db8:0000:0000:0000:0000:0000:0001"

ipv6:expand "2001:db8::1"
ipv6:expand "20::1"
ipv6:expand "2001:db8::8d3:0:0:0"
