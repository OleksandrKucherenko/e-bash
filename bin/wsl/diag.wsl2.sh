#!/bin/bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# Script to gather and publish current network configuration of the WSL2 instance
# Focuses on networking and Docker IPs, printed directly to terminal

# Define color codes for output
GRAY="$(tput setaf 8)"
NC="$(tput sgr0)"
BOLD="$(tput bold)"
GREEN="$(tput setaf 2)"
YELLOW="$(tput setaf 3)"
BLUE="$(tput setaf 4)"
RED="$(tput setaf 1)"

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
}

# ref1: https://regex101.com/r/uwPxJf/10
function color:ipv6() {
    local line=$1 grep_regex seeds
    local ipv6s ipv4s seeds

    # Combine all IPv6 patterns
    grep_regex=$(ipv6:grep)
    local sed_regex="${grep_regex}"

    # Extract IPv6 addresses
    ipv6s=$(echo "$line" | grep -oPI "${grep_regex}")
    ipv4s=$(echo "$line" | grep -oPI '([0-9]{1,3}\.){3}[0-9]{1,3}') # IPv4 addresses format

    # Break down regex into components for readability
    local marker="\{IPv6\}"
    local sed_replace="s/(${sed_regex})/${GREEN}${marker}${NC}/Ig"

    # Combine all patterns into a single regex
    seeds=$(echo "$line" | sed -E "$sed_replace")

    # iterate on seeds string until we replace all {IPv6} (marker) tags with proper ipv6 addresses
    # ipv6s may contain multiple ipv6 addresses separated by space
    local final="${seeds}"
    for ipv6 in $ipv6s; do
        # Replace only the first occurrence of the marker with the current IPv6 address
        final=$(echo "$final" | sed -E "0,/${marker}/s/${marker}/${ipv6}/")
    done

    echo "$final" | sed -E "s/(([0-9]{1,3}\.){3}[0-9]{1,3})/${YELLOW}\1${NC}/Ig"
}

# Logger function for consistent output formatting
function log() {
    local type="${1:-}"
    local message="${2:-}"
    local nonewline="${3:-}"

    # Pre-process the message to highlight network elements
    message=$(color:ipv6 "$message")

    case "${type}" in
    header)
        echo -e "${BOLD}${message}${NC}"
        ;;
    section)
        echo -e "\n${BOLD}${BLUE}=== ${message} ===${NC}"
        ;;
    success)
        echo -e "${GREEN}${message}${NC}"
        ;;
    info)
        if [ "${nonewline}" = "nonl" ]; then
            echo -n "${message}"
        else
            echo -e "${message}"
        fi
        ;;
    warning)
        echo -e "${YELLOW}${message}${NC}"
        ;;
    error)
        echo -e "${RED}${message}${NC}"
        ;;
    gray)
        [ "${nonewline}" = "nonl" ] && echo -n "${GRAY}${message}${NC}" || echo -e "${GRAY}${message}${NC}"
        #echo -e "${GRAY}${message}${NC}"
        ;;
    separator)
        echo -e "${BOLD}==========================================${NC}"
        ;;
    *)
        echo -e "${message}"
        ;;
    esac
}

# Print all IPs with descriptions
function show_all_ips() {
    log "section" "All IP addresses"
    ALL_IPS=$(hostname -I)
    for ip in ${ALL_IPS}; do
        log "info" "${ip} - " "nonl"

        # Check IP patterns for known network types
        if [[ "${ip}" == "172.17.0.1" ]]; then
            log "info" "Docker default bridge network"
        elif [[ "${ip}" =~ 172\.[0-9]+\.0\.1 ]]; then
            # Try to get Docker network name if available
            if command -v docker &>/dev/null; then
                ip_second_octet=$(echo "${ip}" | cut -d'.' -f2)
                network_name=$(docker network ls --format '{{.ID}}\t{{.Name}}' | grep "${ip_second_octet}" | awk '{print $2}')
                if [[ -n "${network_name}" ]]; then
                    log "info" "Docker network: ${BLUE}${network_name}${NC}"
                else
                    log "info" "Docker custom network bridge"
                fi
            else
                log "info" "Docker custom network bridge"
            fi
        else
            log "info" "Main WSL2 network interface"
        fi
    done
}

# Network interfaces section with color coding for DOWN interfaces
function show_network_interfaces() {
    log "section" "Network Interfaces"
    ip -brief addr show | while read -r line; do
        if echo "${line}" | grep -q "DOWN"; then
            log "gray" "${line}"
        else
            log "info" "${line}"
        fi
    done
}

# Docker network info
function show_docker_info() {
    if command -v docker &>/dev/null; then
        log "section" "Docker Network Information"
        docker network ls

        log "section" "Docker Containers with IPs"
        containers=$(docker ps -q)
        if [[ -n "${containers}" ]]; then
            local output=$(docker ps -q | xargs -r docker inspect --format '{{.Name}} - {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' | sed 's#^/##')
            log "info" "${output}"
        else
            log "warning" "No running containers"
        fi
    else
        log "section" "Docker Not Installed"
    fi
}

# Show listening ports
function show_listening_ports() {
    log "section" "Listening Ports (WSL side)"
    LISTENPORTS=$(ss -tuln 2>&1)
    IFS=$'\n' read -r -d '' -a lines <<<"${LISTENPORTS}"
    for line in "${lines[@]}"; do
        log "info" "${line}"
    done

    log "section" "Listening Ports (Windows side)"
    #powershell.exe "Get-NetTCPConnection -State Listen | Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State" | while read -r line; do
    #    log "info" " |  ${line/$'\t'/    }"
    #done
    cmd.exe /c 'netstat -an | findstr /V /C:"[::]" | findstr LISTENING' | while read -r line; do
        log "info" " |  ${line/$'\t'/    }"
    done
}

# Check WSL generation
wsl_ver="Unknown"
function detect_wsl_version() {
    if [ -f "/proc/version" ]; then
        if grep -qi "microsoft\|WSL" /proc/version; then
            if grep -qi "WSL2" /proc/version; then
                wsl_ver="WSL2"
            else
                wsl_ver="WSL1"
            fi
        fi
    fi
    log "info" "WSL Version: ${wsl_ver}"
}

# Check if the /etc/resolv.conf file exists and show its contents
function show_resolv_conf() {
    if [ -f "/etc/resolv.conf" ]; then
        log "info" "\nGlobal DNS Configuration from /etc/resolv.conf:"

        # Check if /etc/resolv.conf is a symlink (which is common in WSL)
        if [ -L "/etc/resolv.conf" ]; then
            target=$(readlink -f "/etc/resolv.conf")
            log "info" "Note: /etc/resolv.conf is a symlink to ${target}"
        fi

        # Display nameserver entries with highlighting
        cat /etc/resolv.conf | grep -v "^#" | grep -v "^$" | while read -r line; do
            log "info" "$line"
        done
    fi
}

# Check for systemd-resolved (common in Ubuntu)
function show_systemd_resolved() {
    local not_available=false

    if command -v resolvectl &>/dev/null; then
        log "info" "\nNetwork-specific DNS configuration via systemd-resolved:"
        local output=$(resolvectl status 2>/dev/null)
        IFS=$'\n' read -r -d '' -a lines <<<"${output}"
        for line in "${lines[@]}"; do
            log "info" "$line"
        done

        # if lines array is empty, fallback to other methods
        if [ ${#lines[@]} -eq 0 ]; then not_available=true; fi
    else
        not_available=true
    fi

    if [ "$not_available" = true ]; then
        log "gray" "No DNS configuration via systemd-resolved is available"

        # Check for NetworkManager as an alternative
        if command -v nmcli &>/dev/null; then
            log "info" "\nNetworkManager DNS configuration:"
            nmcli dev show | grep -i dns | while read -r line; do
                log info "$line"
            done
        fi

        # Fallback to getting network interfaces and showing any DNS-related info
        log "info" "\nNetwork interfaces with possible DNS info:"
        interfaces=$(ip -o link show | awk -F': ' '{print $2}' | cut -d '@' -f1)

        for interface in $interfaces; do
            # Skip loopback
            if [[ "$interface" == "lo" ]]; then
                continue
            fi

            log "info" "${BOLD}Interface: $interface${NC}" "nonl"

            # Get IP for the interface
            ip_info=$(ip -4 addr show dev "$interface" 2>/dev/null)
            if [[ -n "$ip_info" ]]; then
                ip_addr=$(echo "$ip_info" | grep -oP 'inet\s+\K[\d.]+' | head -1)
                log "info" " - IP: $ip_addr" "nonl"

                # Try to determine DNS servers for this interface
                if [[ -n "$ip_addr" ]]; then
                    if command -v nmcli &>/dev/null; then
                        dns_servers=$(nmcli device show "$interface" 2>/dev/null | grep -i 'DNS' | awk '{print $2}')
                        if [[ -n "$dns_servers" ]]; then
                            log "info" " - DNS Servers:"
                            echo "$dns_servers" | while read -r dns_line; do
                                log "info" " - $dns_line"
                            done
                        fi
                    else
                        log "gray" " - No DNS servers found, fallback to /etc/resolv.conf"
                    fi
                fi
            else
                log "gray" " - No IPv4 address, skipping" "nonl"
                log "info" " - IPv6: $(ip -6 addr show dev "$interface" | grep inet6 | awk '{print $2}')"
            fi
            # log "info" ""
        done
    fi
}

# Check .wslconfig in Windows user profile
function show_wsl_config() {
    log "info" "${BOLD}WSL Configuration Files:${NC}"
    if [ -f "/etc/wsl.conf" ]; then
        log "info" "- WSL DNS settings in /etc/wsl.conf:"
        if grep -qi "\[network\]\|\[dns\]\|generateResolvConf\|generateHosts\|nameserver" "/etc/wsl.conf"; then
            grep -i "\[network\]\|\[dns\]\|generateResolvConf\|generateHosts\|nameserver" "/etc/wsl.conf"
        else
            log "gray" "- No DNS-related entries found in /etc/wsl.conf"
        fi
    else
        log "gray" "/etc/wsl.conf does not exist"
    fi
}

# Check host DNS resolver settings (from Windows)
function show_windows_dns() {
    log "info" "\n${BOLD}Windows Host DNS Influence:${NC}"
    if [[ "$wsl_ver" = "WSL2" ]]; then
        # In WSL2, check if we are using the Windows host resolver
        if grep -q "generateResolvConf=false" "/etc/wsl.conf" 2>/dev/null; then
            log "info" "WSL2 is configured to NOT use the Windows host resolver"
        elif [ -f "/etc/resolv.conf" ] && grep -q "nameserver.*172\..*\..*\..*" "/etc/resolv.conf"; then
            log "info" "WSL2 appears to be using a custom DNS setup (not Windows host resolver)"
        else
            log "info" "WSL2 is likely using the Windows host resolver"

            # Try to get Windows DNS info from /mnt/c if available
            if [ -d "/mnt/c/Windows" ]; then
                log "info" "Attempting to retrieve Windows DNS configuration:"
                if command -v powershell.exe &>/dev/null; then
                    log "gray" "Windows DNS Servers from PowerShell:"
                    powershell.exe "Get-DnsClientServerAddress -AddressFamily IPv4 | Select-Object InterfaceAlias, ServerAddresses" |
                        while read -r line; do
                            # if line contains '{}' skip it
                            if [[ "$line" == *'{}'* ]]; then continue; fi
                            log "info" " |  $line"
                        done
                    log "gray" ""
                else
                    log "gray" "powershell.exe not accessible from WSL"
                fi
            else
                log "gray" "Windows drive not mounted at /mnt/c"
            fi
        fi
    else
        log "gray" "Unsupported WSL version: $wsl_ver"
    fi
}

# Check DNS resolution via nslookup in Ubuntu
function check_dns_resolution() {
    log "info" "${BOLD}DNS Resolution Test:${NC}"
    if command -v nslookup &>/dev/null; then
        log "info" "Testing DNS resolution to 'google.com':"
        nslookup google.com | grep -v "^#" | while read -r line; do
            log "info" " |  ${line/$'\t'/    }"
        done
    else
        log "gray" "nslookup not available"
    fi
}

# Report header
log "separator"
log "header" "WSL2 Network Configuration Report"
log "info" "Generated: $(date)"
log "separator"

detect_wsl_version

# WSL2 IP Addresses section
log "section" "WSL2 IP Addresses"
log "info" "Primary WSL2 IP: $(hostname -I | awk '{print $1}')"
log "info" "Windows Host IP: $(ip route | grep default | awk '{print $3}')"

show_all_ips
show_network_interfaces
show_docker_info
show_listening_ports

# DNS Configuration
log "section" "DNS Configuration"
show_resolv_conf
show_systemd_resolved

# WSL-specific DNS configuration
log "info" "\nWSL-specific DNS configuration:"
show_wsl_config
show_windows_dns
check_dns_resolution

log "gray" ""
log "separator"
log "header" "End of Network Report"
log "separator"
