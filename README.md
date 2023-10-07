# Enhanced BASH Scripts

- [Enhanced BASH Scripts](#enhanced-bash-scripts)
  - [Local Dev Environment - Requirements](#local-dev-environment---requirements)
  - [TDD - Test Driven Development, run tests on file change](#tdd---test-driven-development-run-tests-on-file-change)
  - [Usage](#usage)
    - [Colors](#colors)
    - [Logger](#logger)
    - [Dependencies](#dependencies)
    - [Arguments Parsing](#arguments-parsing)
    - [Common(s) Functions](#commons-functions)
  - [Deploy / GitHub Pages](#deploy--github-pages)

## Roadmap

- [ ] High-level scripts should be in own `bin` OR `scripts` 
- [ ] Git helpers
- [ ] GitLabs helper scripts (work with branches, forks, submodules)
- [ ] Slack notifications helper scripts
- [ ] Telemetry module (report metrics to CI or DataDog)
- [ ] Globals module (declarative way of defining script dependencies to global environment variables)
- [ ] Loggs monitoring documentation (different streams/files/tty for different information: info, debug, telemetry, dependencies)

## Local Dev Environment - Requirements

- DirEnv - https://github.com/direnv/direnv
- ShellFormat - https://github.com/mvdan/sh
- ShellCheck - https://github.com/koalaman/shellcheck
- KCov - https://github.com/SimonKagstrom/kcov
- ShellSpec - https://github.com/shellspec/shellspec

> Note: alternative Unit Test Frameworks, Bats - https://github.com/bats-core/bats-core

```bash
brew install direnv
brew install shellcheck
brew install shfmt
brew install shellspec
brew install kcov
```

## TDD - Test Driven Development, run tests on file change

```bash
# run all unit tests on file change
watchman-make -p 'spec/*_spec.sh' '.scripts/*.sh' --run "shellspec"

# run failed only unit tests on file change
watchman-make -p 'spec/*_spec.sh' '.scripts/*.sh' --run "shellspec --quick"
```

## Usage

### Colors

```bash
source ".scripts/_colors.sh"

echo -e "${cl_red}Hello World${cl_reset}"
```

### Logger

```bash
source ".scripts/_logger.sh"
logger common "$@" # declare echoCommon and printfCommon functions, tag: common
logger debug "$@" # declare echoDebug and printfDebug functions, tag: debug

echo:Common "Hello World" # output "Hello World" only if tag common is enabled

export DEBUG=*          # enable logger output for all tags
export DEBUG=common     # enable logger output for common tag only
export DEBUG=*,-common  # enable logger output for all tags except common

# advanced functions
config:logger:Common "$@" # re-configure logger enable/disable for common tag
```

### Dependencies

```bash
source ".scripts/_dependencies.sh"

dependency bash "5.*.*" "brew install bash"
dependency direnv "2.*.*" "curl -sfL https://direnv.net/install.sh | bash"
dependency shellspec "0.28.*" "brew install shellspec"
optional kcov "42" "brew install kcov"
dependency shellcheck "0.9.*" "curl -sS https://webi.sh/shellcheck | sh"
dependency shfmt "3.*.*" "curl -sS https://webi.sh/shfmt | sh"
dependency watchman "2023.07.*.*" "brew install watchman"
```

### Arguments Parsing

```bash
# pattern: "{argument},-{short},--{alias}={output_variable}:{default_initialize_value}:{reserved_args_quantity}"
# example: "-h,--help=args_help:true:0", on --help or -h set $args_help variable to true, expect no arguments;
# example: "$1,--id=args_id::1", expect first unnamed argument to be assigned to $args_id variable; can be also provided as --id=123
export ARGS_DEFINITION="-h,--help -v,--version=:1.0.0 --debug=DEBUG:*"

# will automatically parse script arguments with definition from $ARGS_DEFINITION global variable
source ".scripts/_arguments.sh"

# check variables that are extracted
echo "Is --help: $help"
echo "Is --version: $version"
echo "Is --debug: $DEBUG"

# advanced run. parse provided arguments with definition from $ARGS_DEFINITION global variable
parse:arguments "$@"
```

### Common(s) Functions

```bash
source ".scripts/_commons.sh"

# Extract parameter from global env variable OR from secret file (file content)


# validate/confirm input parameter by user input
# string
# Yes/No


# track execution time
```

## Deploy / GitHub Pages

```bash
# generate ssh key for gh-pages publishing
# https://github.com/marketplace/actions/github-pages-action#%EF%B8%8F-create-ssh-deploy-key
ssh-keygen -t rsa -b 4096 -C "kucherenko.alex@gmail.com" -f gh-pages -N ""
```
