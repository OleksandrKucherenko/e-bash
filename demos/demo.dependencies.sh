#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034,SC2059

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2024-01-02
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

export DEBUG=dependencies

# include other scripts: _colors, _logger, _commons, _dependencies, _arguments
scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.scripts" && pwd)"
# shellcheck disable=SC1090 source=../.scripts/_dependencies.sh
source "$scripts_dir/_dependencies.sh"

## Tests:
#dependency bash "5.0.18(1)-release" "brew install bash" "--version"
#dependency bash "5.0.[0-9]{2}(1)-release" "brew install bash" "--version"
#dependency bash "5.0.*(1)-release" "brew install bash" "--version"
#dependency bash "5.*.*(1)-release" "brew install bash" "--version"
#dependency bash "5.*.*" "brew install bash" "--version" --debug # print debug info
#dependency bash "5.*.*" "brew install bash" "--version" 0 # ignore $5 parameter
#dependency git "2.*.*" "brew install git" "--version"
#dependency bazelisk "4.*.*" "brew install bazel" "--version"
#dependency yq "4.13.2" "brew install yq" "-V"
#dependency jq "1.6" "brew install jq"
#dependency bash "[45].*.*" "brew install bash" # allow 4.xx and 5.xx versions
#dependency go "1.17.*" "brew install go" "version"
#dependency buildozer "redacted" "go get github.com/bazelbuild/buildtools/buildozer" "-version" 1
#dependency buildozer "redacted" "go get github.com/bazelbuild/buildtools/buildozer"
#dependency go "1.17.*" "brew install go && (echo 'export GOPATH=\$HOME/go; export PATH=\$GOPATH/bin:\$PATH;' >> ~/.zshrc)" "version"
#dependency go "2.17.*" "echo 'export GOPATH=\$HOME/go; export PATH=\$GOPATH/bin:\$PATH;'" "version" --exec
#dependency go "2.17.*" "echo 'export GOPATH=\$HOME/go; export PATH=\$GOPATH/bin:\$PATH;' >> ~/.zshrc" "version" --debug
