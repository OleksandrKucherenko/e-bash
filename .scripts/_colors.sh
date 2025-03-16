#!/usr/bin/env bash
# shellcheck disable=SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-03-16
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# shellcheck disable=SC2015 # one time initialization, CUID
#[[ "${clr19adx10008og3819x1ipfv}" == "yes" ]] && return 0 || export clr19adx10008og3819x1ipfv="yes"

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
export cl_gray=$cl_grey # alias to the same color

export cl_lred=$(tput setaf 9)
export cl_lgreen=$(tput setaf 10)
export cl_lyellow=$(tput setaf 11)
export cl_lblue=$(tput setaf 12)
export cl_lpurple=$(tput setaf 13)
export cl_lcyan=$(tput setaf 14)
export cl_lwhite=$(tput setaf 15)
export cl_black=$(tput setaf 16)

export cl_selected=$(tput setab 241 && tput setaf 15)

# unset colors, to prevent coloring in the output
function cl:unset() {
  unset cl_reset cl_selected
  unset cl_red cl_green cl_yellow cl_blue cl_purple cl_cyan cl_white cl_grey cl_gray cl_black
  unset cl_lred cl_lgreen cl_lyellow cl_lblue cl_lpurple cl_lcyan cl_lwhite
}
