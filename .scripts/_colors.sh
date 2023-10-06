#!/usr/bin/env bash
# shellcheck disable=SC2155

# tput calls require TERM to be set
if [[ -z $TERM ]]; then export TERM=xterm-256color; fi

# colors
export cl_reset=$(tput sgr0)

export cl_red=$(tput setaf 1)
export cl_green=$(tput setaf 2)
export cl_yellow=$(tput setaf 3)
export cl_blue=$(tput setaf 4)
export cl_purple=$(tput setaf 5)
export cl_cyan=$(tput setaf 6)
export cl_white=$(tput setaf 7)
export cl_grey=$(tput setaf 8)

export cl_lred=$(tput setaf 9)
export cl_lgreen=$(tput setaf 10)
export cl_lyellow=$(tput setaf 11)
export cl_lblue=$(tput setaf 12)
export cl_lpurple=$(tput setaf 13)
export cl_lcyan=$(tput setaf 14)
export cl_lwhite=$(tput setaf 15)
export cl_black=$(tput setaf 16)
