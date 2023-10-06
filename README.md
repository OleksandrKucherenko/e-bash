# Enhanced BASH Scripts

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

## Usage

```bash
# run unit tests on file change
watchman-make -p 'spec/*_spec.sh' '.scripts/*.sh' --run "shellspec"
```

## Deploy

```bash
# generate ssh key for gh-pages publishing
# https://github.com/marketplace/actions/github-pages-action#%EF%B8%8F-create-ssh-deploy-key
ssh-keygen -t rsa -b 4096 -C "kucherenko.alex@gmail.com" -f gh-pages -N ""
```
