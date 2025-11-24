Here’s a self-contained “ShellSpec + TDD for Bash” guide you can drop into a repo as `TESTING.md` (or similar).

---

# Testing Bash with ShellSpec – TDD-oriented Guide

> Based on ShellSpec docs & DeepWiki, plus real projects using it. ([ShellSpec][1])

---

## 1. Project + Test Structure

### 1.1. Recommended layout

ShellSpec’s own docs and discussions show a canonical layout with a `.shellspec` file at the project root and a `spec/` directory for tests. ([GitHub][2])

```text
<PROJECT_ROOT>/
  .shellspec              # project config (required)
  .shellspec-local        # developer overrides (ignored in VCS)
  report/                 # JUnit etc. (ignored in VCS)
  coverage/               # coverage reports (ignored in VCS)
  bin/                    # CLI entrypoints
    your_script.sh
  lib/                    # libraries (unit-testable)
    your_lib.sh
  spec/
    spec_helper.sh        # shared setup/matchers
    your_lib_spec.sh
    your_script_spec.sh
```

Generate the base structure:

```bash
shellspec --init
```

This creates `.shellspec` and `spec/spec_helper.sh`. ([Asciinema][3])

### 1.2. Anatomy of a spec

A minimal TDD-friendly spec for a library function:

```sh
# spec/hello_spec.sh
#shellcheck shell=sh
Describe 'hello.sh'
  Include lib/hello.sh

  It 'says hello'
    When call hello "ShellSpec"
    The output should equal 'Hello ShellSpec!'
    The status should be success
  End
End
```

* `Describe` / `It` is your BDD scaffold.
* `Include` loads functions so you can call them directly. ([DeepWiki][4])
* `When call` runs a function in the current shell (allows variable assertions & coverage). ([GitHub][5])

#### Good TDD habits

1. **Red** – write a failing `It` that describes behaviour.
2. **Green** – implement the smallest change in `lib/*.sh`.
3. **Refactor** – clean code & tests keeping behaviour specs as documentation.

**Rule of thumb:**
Each `It` should verify exactly one behaviour; if you assert too many things, split into multiple examples.

---

## 2. Isolating Scripts from Dependencies

The core TDD idea: your unit under test shouldn’t call the real network, real filesystem, or real external services. You isolate these with design + ShellSpec features.

### 2.1. Make scripts testable

**Pattern 1 – “library + thin CLI”**

```sh
# lib/download.sh
download_file() {
  curl -fsSL "$1" -o "$2"
}

# bin/download
#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/../lib/download.sh"

main() {
  download_file "$1" "$2"
}

if [ "${BASH_SOURCE[0]-$0}" = "$0" ]; then
  main "$@"
fi
```

You test `download_file` via `Include lib/download.sh` and `When call download_file ...`. The CLI wrapper just wires arguments and parsing.

**Pattern 2 – test external script via `When run`**

ShellSpec has different run modes:

* `When call func` – same shell, coverage enabled.
* `When run script path/to/script.sh` – run script in the same shell, coverage still possible.
* `When run command curl ...` – treated as external command, not covered by kcov. ([GitHub][5])

Use `When run script` for integration-ish tests of complete scripts, but keep heavy dependencies mocked.

### 2.2. Controlling environment

Use hooks instead of top-level `export` in `Describe`. Hooks are covered in ShellSpec’s hooks docs and discussions. ([DeepWiki][6])

```sh
Describe 'uses AWS_PROFILE'
  BeforeEach 'AWS_PROFILE=test-profile'

  It 'calls aws with the right profile'
    When call my_aws_wrapper
    The stderr should include 'test-profile'
  End
End
```

* `BeforeEach` / `BeforeAll` create a consistent environment; avoid random `export` at top level.

---

## 3. Mocking & “Spying” on Calls

ShellSpec provides **command-based mocks** and **intercepts**; it doesn’t yet have a full first-class spy API (there is an open discussion about spy/double helpers). ([GitHub][7])

### 3.1. Command-based mocks

From the references, `Mock` defines a replacement for an external command in the scope of a Describe/It. ([GitHub][5])

```sh
Describe 'download_file'
  Include lib/download.sh

  # Mock external curl
  Mock curl
    # $1.. are arguments
    echo "MOCK curl $*"
    return 0
  End

  It 'calls curl with URL and destination'
    When call download_file "https://example.com" "/tmp/file"
    The output should include 'MOCK curl https://example.com -o /tmp/file'
  End
End
```

Conceptually:

* `Mock name` creates a shell function that shadows the real command while the example runs.
* Inside the mock, you can:

  * Return successful/failure statuses.
  * Print controlled stdout/stderr.
  * Log arguments for later assertions (see “poor man’s spy” below).

### 3.2. Function mocking via `Intercept` + `run source`

From the docs: `When run source script.sh` runs the script using `. script.sh`, and allows `Intercept` to hook internal functions. ([GitHub][5])

Example pattern (simplified):

```sh
Describe 'script with internal logger'
  # Suppose script.sh defines logger() and main()

  Intercept logger
    # Intercepted body replaces the original `logger` during this example
    echo "MOCK_LOG: $*"
  End

  It 'logs something'
    When run source bin/script.sh arg1
    The output should include 'MOCK_LOG:'
  End
End
```

Use this when your script defines functions internally and you don’t want to modify the original script for testing.

### 3.3. DIY “spies”

Since there is no official spy feature yet, use a shared variable or temp file:

```sh
Describe 'download_file logging'
  Include lib/download.sh

  LOG_FILE=''
  BeforeEach 'LOG_FILE=$(mktemp)'

  Mock curl
    printf 'curl %s %s\n' "$1" "$2" >>"$LOG_FILE"
    return 0
  End

  It 'calls curl once'
    When call download_file "https://example.com" "/tmp/file"
    The status should be success

    # Check "spy" data
    When run cat "$LOG_FILE"
    The lines of output should equal 1
    The output should include 'curl https://example.com /tmp/file'
  End
End
```

---

## 4. Capturing stdout / stderr & Handling Color

ShellSpec has built-in **subjects** for stdout, stderr and exit status. ([GitHub][5])

Common subjects:

* `The output` – stdout of the last `When ...`. ([DeepWiki][4])
* `The stderr` (aka “error subject”) – stderr of the last run. ([GitHub][8])
* `The status` – exit code of the last run. ([DeepWiki][4])

With matchers (e.g. `equal`, `include`, `match pattern`): ([GitHub][5])

```sh
It 'prints help to stdout'
  When run script bin/mytool --help
  The status should be success
  The output should include 'Usage: mytool'
End

It 'reports errors on stderr'
  When run script bin/mytool --bad-flag
  The status should be failure
  The stderr should include 'Unknown option'
End
```

### 4.1. Ignoring ANSI color codes

Issue #278 shows that straight `equal` comparisons fail when ANSI sequences are present; the suggested solution is a **custom matcher** that strips control codes before comparison. ([GitHub][9])

Example custom matcher (simplified):

```sh
# spec/support/match_colored_text.sh
#shellcheck shell=sh

match_colored_text() {
  pattern=$1
  sanitized=$(
    # Strip ANSI escapes and backspace tricks
    perl -pe 's/\e\[[0-9;]*[mK]//g; 1 while s/[^\b][\b]//g;' 2>/dev/null
  )
  printf '%s\n' "$sanitized" | grep -q -- "$pattern"
}

# in spec_helper.sh
spec_helper_configure() {
  import 'support/match_colored_text'
}
```

Usage:

```sh
It 'prints OPTIONS section, ignoring colors'
  When run script bin/mytool --help
  The output should satisfy match_colored_text "OPTIONS:"
End
```

Alternative strategies:

* Make your script disable colors when `NO_COLOR` or a custom `MYTOOL_NO_COLOR=1` is set, and set that in tests.
* Only check for substrings using `include` or `match pattern` instead of `equal`.

---

## 5. Temporary Test Environments & Context

### 5.1. Using ShellSpec temp dirs

ShellSpec uses a temporary directory for its internal work; there is a `--tmpdir` CLI option to override the default `/tmp`. ([GitHub][10])

In `.shellspec`:

```text
--tmpdir tmp/shellspec
--default-path "spec"
--format documentation
--color
--output junit
```

* The `Configuration` docs describe how `.shellspec` sets default command-line options for all runs. ([DeepWiki][11])

You can also rely on `SHELLSPEC_TMPDIR` / `SHELLSPEC_TMPBASE` environment variables in your own helpers if needed. ([GitHub][5])

### 5.2. Creating per-test temp dirs

Use hooks to isolate filesystem state:

```sh
Describe 'working with temp files'
  TmpDir=""

  BeforeEach '
    TmpDir=$(mktemp -d "${SHELLSPEC_TMPDIR:-/tmp}/mytool.XXXXXX")
  '

  AfterEach '
    rm -rf "${TmpDir:-}"
  '

  It 'writes output file'
    When call my_function "$TmpDir/output.txt"
    The path "$TmpDir/output.txt" should be file
  End
End
```

* Hooks and their lifecycle are detailed in the Hooks documentation. ([DeepWiki][6])

### 5.3. Scenario / context setup with Hooks + Data / Parameters

To express contexts, combine `Context` / nested `Describe` with hooks and `Parameters`/`Data` helpers. ([GitHub][5])

```sh
Describe 'URL validator'

  Parameters:matrix
    %data "valid  https://example.com 0"
    %data "invalid ftp://example.com  1"
  End

  It "returns expected status for $1 URLs"
    When run script bin/validate_url "$2"
    The status should equal "$3"
  End
End
```

---

## 6. Code Coverage

ShellSpec integrates with **kcov**; the official Docker image includes kcov out of the box. ([Docker Hub][12])

Basic CLI:

```bash
shellspec --kcov
```

From the demo script in ShellSpec’s repo: coverage with JUnit output: ([GitHub][13])

```sh
# contrib/demo.sh (simplified)
shellspec --kcov --output junit
cat report/results_junit.xml
```

Notes:

* Coverage is collected for code executed in the same shell (`call`, `run script`, `run source`).
* `When run command some_external` is treated as an external process and is **not covered**. ([GitHub][5])
* Keep your business logic in functions/libraries and test via `call` or `run script` for better coverage.

Typical `.shellspec` defaults:

```text
--kcov
--kcov-dir coverage
--pattern "**/*_spec.sh"
```

---

## 7. JUnit Reports for CI

ShellSpec supports multiple output formats; JUnit XML is enabled via `--output junit`. ([DeepWiki][14])

Example:

```bash
shellspec --kcov --output junit --reportdir report
# Produces something like:
#   report/results_junit.xml
```

* Recent releases populate `<system-out>` / `<system-err>` in the XML. ([GitHub][15])

Config in `.shellspec`:

```text
--output junit
--reportdir report
```

In CI (GitHub Actions / GitLab / Azure Pipelines etc.), point your JUnit parser to `report/results_junit.xml`.

There’s ongoing design around controlling how much output is embedded via the `Logging` DSL (to avoid giant XML files). ([GitHub][16])

---

## 8. Running a Single Test / Focus Mode / Parameters

ShellSpec has powerful filtering & range selection. ([DeepWiki][14])

### 8.1. By file

```bash
shellspec spec/hello_spec.sh
```

### 8.2. By line or ID range

You can append ranges to the filename: ([ko1nksm's blog][17])

```bash
shellspec spec/hello_spec.sh:10          # examples including line 10
shellspec spec/hello_spec.sh:10:20       # examples including lines 10 and 20
shellspec spec/hello_spec.sh:@1-3        # first 3 example groups/examples
shellspec spec/hello_spec.sh:@1-5:@1-6   # specific IDs inside first group
```

### 8.3. By filters / tags / examples

CLI options (documented under “Command Line Options”) include: ([DeepWiki][14])

* `--example` – filter by example description.
* `--tag` / `--focus` – run only examples with given tags.

Pattern:

```sh
It 'does something #slow'
  ...
End
```

```bash
shellspec --tag slow       # run only slow tests
shellspec --focus          # run examples tagged as focus (depending on config)
```

(Exact tag semantics depend on your `.shellspec` and ShellSpec version, but the general mechanism is there in the option system.)

### 8.4. Same example, many parameters

See `Parameters`, `Parameters:matrix`, and `Parameters:dynamic`. ([GitHub][5])

Example:

```sh
Describe 'add()'

  Include lib/math.sh

  Parameters
    %data "1 2 3"
    %data "2 3 5"
    %data "5 8 13"
  End

  It "adds $1 + $2 = $3"
    When call add "$1" "$2"
    The output should equal "$3"
  End
End
```

---

## 9. Things to Avoid (Tests & Scripts)

Based on ShellSpec debugging/compatibility docs and issue discussions. ([DeepWiki][18])

### 9.1. In tests

* **Heavy logic in `Describe`/`Context` bodies**

  * Prefer hooks (`BeforeAll`, `BeforeEach`) and helpers instead of ad-hoc shell code sprinkled inside descriptors.
* **Global mutable state across examples**

  * Avoid unscoped globals; always reset state in hooks or via parameters.
* **Modifying shell options dangerously**

  * `set -e`, `set -u`, `set -o pipefail` inside specs can interact badly with ShellSpec’s own shell pipeline. If you really need them, enable inside the code under test or within controlled blocks.
* **Changing `IFS`, `PATH`, `CDPATH` globally**

  * If you must tweak them (e.g., for parsing tests), do it inside an example or hook and restore afterward.
* **Relying on shell-specific features in tests**

  * ShellSpec is designed to run across POSIX shells; using bash-only arrays/associative arrays inside tests can break compatibility. Use plain POSIX syntax where possible. ([Qiita][19])
* **Dynamic test generation with side-effects that depend on iteration order**

  * The `Parameters:dynamic` helper is powerful but can lead to “expected 0 examples, but only ran X examples” if you mutate variables incorrectly. ([GitHub][20])

### 9.2. In scripts under test

* **Work at import-time**

  * Don’t perform actions just from `. lib/script.sh`; keep side-effects inside a `main` or explicitly called function. This makes `Include` safe.
* **Nested `source` patterns with complex global state**

  * Issues reported when nested sources manipulate ShellSpec’s internal variable stacks. Keep shared functionality in simple libraries and avoid clever runtime metaprogramming. ([GitHub][21])
* **Depending on interactive features** (e.g. `read` from TTY, prompts)

  * Wrap interactive behaviour behind functions so you can mock them or feed data via stdin.

---

## 10. Example Open-Source Projects Using ShellSpec

Here are 10 repos that integrate ShellSpec and are useful as real-world references (layout, CI, coverage, mocks):

1. **shellspec/shellspec** – the framework itself

   * Extensive `spec/` folder, `.shellspec` config, demo scripts (`contrib/demo.sh` shows coverage + JUnit). ([GitHub][22])

2. **shellspec/shellbench** – POSIX shell benchmark tool

   * Uses `.shellspec` and `spec/` to test CLI behaviour. ([Allure][23])

3. **shellspec/shellmetrics** – cyclomatic complexity analyzer

   * Good example of a non-trivial shell app tested via ShellSpec: `.shellspec`, `spec/`, CI badges. ([GitHub][24])

4. **shellspec/openwrt-docker** – Docker images for OpenWrt

   * Uses ShellSpec to validate image behaviour and scripts (check `spec/` and `.shellspec`). ([GitHub][25])

5. **Azure/AgentBaker** – Kubernetes agent node provisioning

   * `spec/` directory with ShellSpec tests; README shows use of the ShellSpec Docker image:
     `docker run -t -v "$PWD:/src" shellspec-docker --shell bash spec/...` ([GitHub][26])

6. **shellspec/shellspec Docker image**

   * Not a project per se, but its Dockerfile and README show how to integrate ShellSpec + kcov in CI. ([Docker Hub][12])

7. **shellspec/examples** (inside the main repo)

   * Compact example specs, including custom matchers (`support/custom_matcher`) and specs using them. ([GitHub][27])

8. **martinburger/bash-common-helpers**

   * Library of reusable helpers with specs under `spec/` and `spec_helper.sh`. Shows a small library-style project using ShellSpec. ([GitHub][28])

9. **shellspec-sample (MCMicS/shellspec-sample)**

   * Minimal sample repo demonstrating `.shellspec`, `spec/` directory and CI; good training material for new team members. ([GitHub][29])

10. **shellspec/shellmetrics test harness**

    * The `test.sh` + `spec/` combination in `shellmetrics` demonstrates how to wire ShellSpec into automation scripts. ([GitHub][24])

You can clone a couple of these and walk through:

* How they structure specs per module.
* How they configure `.shellspec` for coverage and JUnit.
* How they perform command-based mocking and parameterized tests.

---

## 11. Quick “Checklists” for Your Team

### 11.1. When adding a new Bash feature

1. Add/extend a spec:

   * New `Describe` for module or `Context` in existing file.
   * Use `Parameters` for input variations.
2. Mock external dependencies with `Mock` or `Intercept`.
3. Use `When call` and `The output / The status` assertions.
4. Run focused tests: `shellspec spec/foo_spec.sh:LINE` or `--example`.
5. Ensure coverage stays high: run `shellspec --kcov` and inspect `coverage/`.

### 11.2. When tests become flaky or weird

* Check for:

  * Global variables leaking between examples.
  * Misused `Parameters:dynamic`. ([GitHub][20])
  * Shell-specific features (zsh arrays, etc.) in tests conflicting with POSIX shells. ([DeepWiki][30])
* Use debugging tools: `--xtrace`, `%logger`, `Dump` as recommended in “Debugging and Troubleshooting”. ([DeepWiki][18])

---

[1]: https://shellspec.info/?utm_source=chatgpt.com "ShellSpec | BDD unit testing framework for shell scripts (bash, ksh ..."
[2]: https://github.com/shellspec/shellspec/issues/353?utm_source=chatgpt.com "Template Repository · Issue #353 · shellspec/shellspec · GitHub"
[3]: https://asciinema.org/a/241934?utm_source=chatgpt.com "shellspec - BDD for shell script [0.11.0] - asciinema"
[4]: https://deepwiki.com/shellspec/shellspec/1.2-quickstart-tutorial?utm_source=chatgpt.com "Quickstart Tutorial | shellspec/shellspec | DeepWiki"
[5]: https://github.com/shellspec/shellspec/blob/master/docs/references.md?utm_source=chatgpt.com "shellspec/docs/references.md at master - GitHub"
[6]: https://deepwiki.com/shellspec/shellspec/3.3-hooks?utm_source=chatgpt.com "Hooks | shellspec/shellspec | DeepWiki"
[7]: https://github.com/shellspec/shellspec/issues/80?utm_source=chatgpt.com "Some mocking helper (Spy, Double, etc) · Issue #80 · shellspec ..."
[8]: https://github.com/shellspec/shellspec/discussions/230?utm_source=chatgpt.com "The stderr should include \"a specific word in the error\" · shellspec ..."
[9]: https://github.com/shellspec/shellspec/issues/278?utm_source=chatgpt.com "Support for testing colored strings · Issue #278 · shellspec ... - GitHub"
[10]: https://github.com/shellspec/shellspec/issues/108?utm_source=chatgpt.com "Add --tmpdir option · Issue #108 · shellspec/shellspec · GitHub"
[11]: https://deepwiki.com/shellspec/shellspec/5.2-configuration?utm_source=chatgpt.com "Configuration | shellspec/shellspec | DeepWiki"
[12]: https://hub.docker.com/r/shellspec/shellspec?utm_source=chatgpt.com "shellspec/shellspec - Docker Image | Docker Hub"
[13]: https://github.com/shellspec/shellspec/blob/master/contrib/demo.sh?utm_source=chatgpt.com "shellspec/demo.sh at master · shellspec/shellspec · GitHub"
[14]: https://deepwiki.com/shellspec/shellspec/5.1-command-line-options?utm_source=chatgpt.com "Command Line Options | shellspec/shellspec | DeepWiki"
[15]: https://github.com/shellspec/shellspec/releases?utm_source=chatgpt.com "Releases · shellspec/shellspec - GitHub"
[16]: https://github.com/shellspec/shellspec/issues/184?utm_source=chatgpt.com "Exclude stdout and stderr in the JUnit XML output - GitHub"
[17]: https://ko1nksm.hatenablog.com/?utm_source=chatgpt.com "ko1nksm's blog"
[18]: https://deepwiki.com/shellspec/shellspec/7.4-debugging-and-troubleshooting?utm_source=chatgpt.com "Debugging and Troubleshooting | shellspec/shellspec | DeepWiki"
[19]: https://qiita.com/ko1nksm/items/2f01ff4f50e957ebf1de?utm_source=chatgpt.com "ShellSpec - シェルスクリプト用のフル機能のBDDユニットテストフレームワーク #Bash - Qiita"
[20]: https://github.com/shellspec/shellspec/issues/259?utm_source=chatgpt.com "Shellspec Reporting Failure when all test passed- script uses ... - GitHub"
[21]: https://github.com/shellspec/shellspec/issues/306?utm_source=chatgpt.com "Nested source commands inside scripts under testing #306 - GitHub"
[22]: https://github.com/shellspec/shellspec?utm_source=chatgpt.com "ShellSpec: full-featured BDD unit testing framework - GitHub"
[23]: https://www.allure.com/best-mineral-sunscreen?utm_source=chatgpt.com "7 Actually Invisible Mineral Sunscreens? Go On… | Allure"
[24]: https://github.com/shellspec/shellmetrics "GitHub - shellspec/shellmetrics: Cyclomatic Complexity Analyzer for bash, mksh, zsh and POSIX shells"
[25]: https://github.com/shellspec/openwrt-docker?utm_source=chatgpt.com "GitHub - shellspec/openwrt-docker: Docker images for OpenWrt"
[26]: https://github.com/Azure/AgentBaker/blob/master/spec/README.md?utm_source=chatgpt.com "AgentBaker/spec/README.md at master - GitHub"
[27]: https://github.com/shellspec/shellspec/blob/master/examples/spec/spec_helper.sh?utm_source=chatgpt.com "shellspec/examples/spec/spec_helper.sh at master - GitHub"
[28]: https://github.com/martinburger/bash-common-helpers/blob/master/spec/spec_helper.sh?utm_source=chatgpt.com "GitHub"
[29]: https://github.com/MCMicS/shellspec-sample/blob/master/.shellspec?utm_source=chatgpt.com "GitHub"
[30]: https://deepwiki.com/shellspec/shellspec/7.3-shell-compatibility?utm_source=chatgpt.com "Shell Compatibility | shellspec/shellspec | DeepWiki"

---

# ShellSpec Unit Test Troubleshooting: Best Practices

## Best Practices
- Enable `--xtrace` or `--xtrace-only` for evaluation traces.
- Use `Dump` after `When` to inspect stdout/stderr/status.
- Log with `%logger` directive to file.
- Run `--syntax-check` for specfile errors.
- `--translate` to view expanded spec.
- `--profile` to find slow tests.
- `--quick` reruns failures only.
- Random order (`--random`) to detect dependencies.

## Run One Test Only
- `shellspec spec/file_spec.sh` (specific file).
- `shellspec spec/file_spec.sh:line` (line/group).
- `shellspec spec/file_spec.sh:@1-5` (range).
- `--example "name"` (matching pattern).
- `--tag TAG` (tagged examples).
- `--focus` with `fDescribe`/`fIt` prefixes.

## Isolate Failed Spec Scope
- `--xtrace` traces execution to check spec syntax vs. script changes.
- `Dump` post-evaluation reveals output mismatches.
- `--dry-run` previews without running.
- Compare `--translate` output: syntax issues show in expansion; script changes fail on `Include`/`When call`.
- `--quick` isolates to recent failures; `--random` checks order dependency.
- Use `__SOURCED__` guard in scripts to prevent direct exec during sourcing.

## Prepare Scripts for Testing
- Isolate problematic lines into functions for `When call`.
- Use `Include script.sh` to load; guard with `if [ -n "${__SOURCED__+set}" ]; then return; fi` to skip main on source.
- Place functions before main; mock deps with `Mock`/`Intercept`.
- For single-file: Wrap main in function, test via `When run source`.
- Embed code in specs with `%=` (echo) or `%text` (multiline).
- Enable sandbox (`--sandbox`) for isolation; no special instructions—focus on modular functions.