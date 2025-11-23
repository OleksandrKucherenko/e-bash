# ShellSpec Unit Testing Guide for Bash Scripts: TDD Best Practices

ShellSpec enables BDD-style TDD for Bash/POSIX shells. Follow RED-GREEN-REFACTOR: Write failing test, make it pass, refactor. Use sandbox mode for isolation. Structure tests in `spec/`; source scripts via `Include`.

## Test Structure
Organize in `spec/` with `_spec.sh` files. Use nested blocks for hierarchy.

```
<project-root>
├─ .shellspec  # Mandatory config
├─ bin/        # Scripts
│  └─ script.sh
└─ spec/
   ├─ spec_helper.sh  # Global setup
   └─ bin/
      └─ script_spec.sh
```

Example (`spec/bin/script_spec.sh`):
```
Include bin/script.sh  # Load SUT

Describe 'script'
  Context 'addition'
    It 'adds numbers'
      When call add 2 3
      The output should eq 5
    End
  End
End
```
Run: `shellspec`.

## Isolating Scripts from Dependencies
Use `--sandbox` to empty `PATH` (except internals). Mock externals or use `@command` wrappers (`shellspec --gen-bin`).

Example:
```
Describe 'isolated'
  It 'uses mocked dep'
    Mock ls { echo "file"; }
    When call list_files
    The output should eq "file"
  End
End
```
Hooks (`BeforeEach`/`AfterEach`) ensure per-test isolation.

## Mocking and Spying Calls
- **Function Mock**: Redefine in block (auto-unmocks on exit).
  ```
  Describe 'func mock'
    date() { echo "2023-01-01"; }
    It 'mocks date'
      When call get_date
      The output should eq "2023-01-01"
    End
  End
  ```
- **Command Mock**: Use `Mock` block for externals.
  ```
  Mock curl
    echo '{"status": 200}'; return 0
  End
  It 'mocks API'
    When call fetch_data
    The status should eq 0
  End
  ```
- **Spy**: Use interceptors (`Intercept func`) to count/modify calls; requires script changes (e.g., `func() { __func__ "$@"; }`).

## Capturing Stdout/Stderr; Comparing Without Colors
`When call` captures stdout/stderr/status. Comparisons ignore ANSI colors by default.

Example:
```
It 'captures output'
  When call echo "Hello" >&2  # Stderr
  The error should eq "Hello"
  The output should eq ""
End

It 'compares stdout'
  When call printf "\e[31mRed\e[0m"
  The output should eq "Red"  # Colors stripped
End
```
Use `include`, `match`, `end with` for flexible checks.

## Temporary Test Environment and Contexts
- **Temp Dir**: `--tmpdir /path` (default: `/tmp`); `--keep-tmpdir` preserves.
- **Contexts**: `Context` blocks for scenarios; auto-cleanup.
- **Hooks**: Setup/teardown.
  ```
  Describe 'temp env'
    BeforeEach
      Tempfile() { mktemp; }  # Custom temp
    End
    Context 'file ops'
      It 'creates temp'
        When call create_temp
        The stdout should include "/tmp/"
      End
    End
  End
  ```
Use `--execdir @specfile` for per-file dirs.

## Capturing Code Coverage
Requires kcov (v38+). Run: `shellspec --kcov`.

- Measures sourced scripts/functions.
- Outputs: HTML, cobertura.xml in `coverage/`.
- Options: `--kcov-options "--include-pattern=*.sh"`.
Limitations: Ignores externals; Bash/Zsh/Ksh only.

## Capturing JUnit Reports
Run: `shellspec --output j` (or `--format junit`).

Generates XML in `report/` for CI (e.g., Jenkins). Includes tests, failures, time.

## Running One Test: Focus Mode, Parameters
- **One Test**: `shellspec spec/file_spec.sh:line` or `--example "name"`.
- **Focus**: Prefix `fDescribe`/`fIt`; run `--focus`.
- **Quick**: `--quick` reruns failures only.
- **Parameterized**:
  ```
  Describe 'params'
    Parameters
      '1+1=2' 1 1 2
      '2+2=4' 2 2 4
    End
    It '#$1 #$2 = #$3'
      When call add $2 $3
      The output should eq $4
    End
  End
  ```
Matrix/dynamic variants for combos/generation.

## Avoid in Tests/Scripts; Potential Problems
- **Avoid**: Unmocked externals in sandbox (crashes); shell-specific code (breaks POSIX); global vars (leak state); `$LINENO` (use ShellSpec's reporting).
- **Pitfalls**: Hooks with stderr (false fails); command mocks slower than func; interceptors need code mods; coverage misses `eval`/externals. Use POSIX syntax; test in subshells.

## Top 10 Open Source Projects with ShellSpec Integration
Examples for training; examined READMEs/source for test setups.

| # | Project | Description | Integration Example |
|---|---------|-------------|---------------------|
| 1 | [shellspec/shellspec](https://github.com/shellspec/shellspec)  | Framework itself | `examples/spec/` with mocks, params; coverage via kcov. |
| 2 | [snyk/cli](https://github.com/snyk/cli)  | Vulnerability scanner CLI | Smoke tests in `test/smoke/`; Docker-Alpine runs; ShellCheck integration. |
| 3 | [shinokada/shellscript-starter](https://github.com/shinokada/shellscript-starter)  | Bash starter kit | `spec/bash_helpers_spec.sh`; runs with `-s /usr/bin/env bash`. |
| 4 | [ggicci/droplets](https://github.com/ggicci/droplets)  | Shell modules | Uses v0.28.1; tests in `test/` with BDD examples. |
| 5 | [jenkins-x/terraform-google-jx](https://github.com/jenkins-x/terraform-google-jx)  | Jenkins X on GCP | ShellSpec in CI for infra scripts; parallel exec. |
| 6 | [snyk/snyk](https://github.com/snyk/snyk)  | Dependency scanner | Unit tests for shell components; JUnit reports in CI. |
| 7 | [poikilotherm/asdf-shellspec](https://github.com/poikilotherm/asdf-shellspec)  | ASDF plugin | Tests plugin install; simple specfiles for versioning. |
| 8 | [tracykteal/shell](https://github.com/tracykteal/shell)  | Shell tutorial | Basic tests for commands; uses `Describe` for basics. |
| 9 | [rcgsheffield/linux-shell](https://github.com/rcgsheffield/linux-shell)  | Linux shell guide | Example specs for pwd/ls; isolation focus. |
| 10 | [mvdan/sh](https://github.com/mvdan/sh)  | Shell parser | Tests formatter; integrates with ShellSpec DSL. |

---

Here are **best-practice troubleshooting techniques** for unit testing with ShellSpec + Bash, plus how to *run a single test only*, *isolate scope of a failing spec*, and *prepare your scripts for testability*. I include what ShellSpec itself recommends and how you can structure your workflow to distinguish “broken test definition” vs “broken code under test”.

---

## 1. Common Troubleshooting Practices

### 1.1 Structured debugging workflow

According to the “Debugging and Troubleshooting” guide, you should follow a layered approach:

1. **Syntax-check** your spec files, to ensure the DSL is parsed correctly. ([DeepWiki][1])
2. **Inspect translated code** (see how ShellSpec expands your DSL) using `--translate` to see the generated shell script. ([DeepWiki][1])
3. **Enable tracing / verbose output** to see what is being executed. Use options like `--xtrace` or `--xtrace-only`, or `%logger` inside specs. ([DeepWiki][1])
4. **Isolate environment** issues: faulty hooks, path problems, shell compatibility quirks. The docs list common scenarios (unsupported shell, sandbox path issues, etc.) ([DeepWiki][1])
5. **Focus on one failing test** (see next section) and evaluate whether failure is due to the spec or the code under test.

### 1.2 Things to inspect when a spec fails

* Did the spec actually call the code under test (function or script) the way you intended?
* Are the `When …` evaluation keywords correct (`When call`, `When run`, `When run script`, etc)? Using the wrong one may change behavior. ([DeepWiki][2])
* Are mocks/intercepts interfering with the code under test? Maybe your mock captured too much or too little, or you forgot to restore environment/state after each example.
* Is the code under test (or its dependencies) using environment or global state that the spec didn’t reset? Tests must isolate state changes.
* Does the shell you’re using support all the features you expect? Shell compatibility issues are common. ([DeepWiki][3])
* Are you inadvertently relying on external commands or real side-effects? For a unit test you ideally want to mock/spy external dependencies.

### 1.3 Flakiness / scope creep

* If tests sometimes pass, sometimes fail: check for shared mutable state, race conditions (especially if using `--jobs` parallel mode) or resource conflicts (e.g., same temp file path). ([DeepWiki][4])
* Use `--jobs 0` (i.e., run sequentially) to help isolate concurrency issues. ([DeepWiki][1])
* Use `--quick`, `--repair`, `--next-failure` to run only failing examples quickly and iterate in the TDD cycle. ([DeepWiki][1])

---

## 2. Running a Single Test / Focus Mode / Isolating Scope

### 2.1 Run a single file or a single example

ShellSpec’s CLI supports fine-grained filters. From the CLI docs: ([GitHub][5])

* By file:

  ```bash
  shellspec spec/my_feature_spec.sh
  ```
* By line number / range:

  ```bash
  shellspec spec/my_feature_spec.sh:10          # example around line 10
  shellspec spec/my_feature_spec.sh:10:20       # examples in lines 10-20
  ```
* By example ID:

  ```bash
  shellspec spec/my_feature_spec.sh:@1-3       # first 3 examples
  ```
* By name, tag or focus:

  * Tag an example:

    ```sh
    It 'does X #slow'
      …
    End
    ```

    Then filter with:

    ```bash
    shellspec --tag slow
    ```
  * Use `fIt`, `fDescribe`, `fContext` to mark focused tests:

    ```sh
    fIt 'some behaviour' …
    ```

    then run tests with:

    ```bash
    shellspec --focus
    ```

### 2.2 Isolating failure scope: test vs code

When a test fails, you want to know: is the *spec* broken (i.e., wrong expectation or setup) or is the *script code under test* broken? Suggested approach:

1. **Focus only that one failing example** using one of the filters above.
2. Temporarily **comment out or skip other examples** so you don’t get noise.
3. Use `--xtrace` or `%logger` inside that example to see the exact execution.
4. Inspect the output/state/exit status via `Dump` to verify what the spec is seeing.

   ```sh
   When call my_function arg1
   Dump
   The output should equal 'expected'
   ```

   `Dump` will display stdout, stderr, status for manual inspection. ([DeepWiki][1])
5. Simplify the example: if you suspect the code under test is broken, write a minimal spec that isolates just the function or behaviour (remove mocking, reduce dependencies) and see if it still fails. If yes → likely code under test. If no → likely spec setup/expectation wrong.
6. If you suspect the spec’s mock or setup is wrong, try *not mocking* that part (or mocking differently) and run again to see whether the failure changes.

### 2.3 Use of `--syntax-check` and `--translate`

* `--syntax-check spec/my_spec.sh` checks only the spec syntax, no examples run. Good to verify your DSL is correct. ([DeepWiki][1])
* `--translate spec/my_spec.sh` shows how ShellSpec expands your spec into actual shell code. Use to debug unexpected behaviour (e.g., variable scoping, subshell vs current shell). ([DeepWiki][1])

---

## 3. How to Prepare Scripts for Testing / Structuring Code for Testability

### 3.1 Keep side-effects out of the global scope

A frequent issue: script defines variables, runs commands on load, so when you `Include` or `run source`, you trigger side-effects. Best practice:

* Write scripts so that only definitions (functions, variables) exist at the top level.
* Side-effects (I/O, external calls, argument parsing) are inside a `main()` or similar function, and guarded by:

  ```bash
  if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
  fi
  ```

  This way, when `Include`d by ShellSpec, the side-effects don’t execute, only your functions are loaded. This makes test isolation much cleaner.

### 3.2 Isolate “problematic lines” into small functions

If you have complex code (e.g., external command invocation, parsing, network I/O), you should:

* Extract that piece into its own well‐named function so you can `Include` and test it in isolation.
  Example: instead of:

  ```bash
  # my_script.sh
  foo() {
    grep … | awk … | curl …
  }
  ```

  Do:

  ```bash
  _invoke_curl() { curl "$@"; }
  foo() {
    _invoke_curl "$URL"
    …
  }
  ```

* In your spec you can mock `_invoke_curl` (or the external command) so your unit tests don’t hit the network.

* This makes the spec reflect the behaviour of the function logic rather than the external dependencies.

### 3.3 Use ShellSpec’s `Include` and `Mock`/`Intercept` appropriately

* Use `Include lib/my_lib.sh` in your spec to load only the code you want to test.

* For external commands, use `Mock command` inside your spec to provide controlled behaviour. Example:

  ```sh
  Mock curl
    echo "MOCK curl $*"
    return 0
  End
  ```

* For functions within the script that you want to intercept, you can use `Intercept`. Example:

  ```sh
  Intercept logger
    echo "LOG: $*"
  End
  ```

### 3.4 Design for testability

* Make your functions return status codes and output instead of directly exiting the shell or printing formatted stuff (though printing is okay if you assert on output).
* Avoid un‐testable behaviour (dialogs, interactive prompts) in core logic. If you have to do interactive I/O, factor the I/O side out so you can test logic separately.
* Make environment/configuration injectable: e.g., let the function read `$CONFIG_PATH` or `$TMPDIR` rather than hard-coding `/tmp`. In your spec set a controlled environment via `BeforeEach`.

### 3.5 Use a clean and isolated temporary environment in tests

* In your spec `BeforeEach`, set up a dedicated temp directory, e.g.,

  ```sh
  TmpDir="$(mktemp -d "${SHELLSPEC_TMPDIR:-/tmp}/myscript.XXXXXX")"
  export TMPDIR="${TmpDir}"
  ```

  And in `AfterEach`, delete it.
* Ensure each example cleans up or uses unique file names to avoid interference between tests.

---

## 4. Summary Table

| Problem                                       | Quick fix / best practice                                                                                  |
| --------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| Spec failing but you’re not sure why          | Use `--syntax-check`, `--translate`, `--xtrace`, `Dump` to inspect. Focus one example.                     |
| Many failing tests after a code change        | Run just the changed spec file(s) with line filters or tags.                                               |
| Flaky test                                    | Run sequentially (no parallel), ensure unique temp paths, no shared state, reset mocks.                    |
| Code under test triggers side-effects on load | Extract logic into functions and guard top-level execution.                                                |
| External dependency slows or breaks tests     | Mock external commands and test internal logic only.                                                       |
| Hard to run a single test                     | Use line filters (`file.sh:LINE`), example ID filters (`:@1-3`), tags (`--tag`), focus (`fIt`, `--focus`). |

---

[1]: https://deepwiki.com/shellspec/shellspec/7.4-debugging-and-troubleshooting?utm_source=chatgpt.com "Debugging and Troubleshooting | shellspec/shellspec | DeepWiki"
[2]: https://deepwiki.com/shellspec/shellspec/4-test-writing-guide?utm_source=chatgpt.com "Test Writing Guide | shellspec/shellspec | DeepWiki"
[3]: https://deepwiki.com/shellspec/shellspec/7.3-shell-compatibility?utm_source=chatgpt.com "Shell Compatibility | shellspec/shellspec | DeepWiki"
[4]: https://deepwiki.com/shellspec/shellspec/7-advanced-topics?utm_source=chatgpt.com "Advanced Topics | shellspec/shellspec | DeepWiki"
[5]: https://github.com/shellspec/shellspec/blob/master/docs/cli.md?utm_source=chatgpt.com "shellspec/docs/cli.md at master · shellspec/shellspec · GitHub"
