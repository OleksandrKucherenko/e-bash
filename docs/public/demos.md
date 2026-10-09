# Demo catalog

Run these commands with Bash 5 from the repository root. Export
`E_BASH="$PWD/.scripts"` first. Demos bootstrap GNU command aliases themselves;
additional dependencies are called out below. Interactive demos need a terminal.

## Terminal interfaces

| Demo | What to try | Guide or visual |
| --- | --- | --- |
| `bash demos/demo.multi-line.sh box` | Type, edit with arrows, Ctrl+D to save, Esc to cancel | [TUI walkthrough with recordings](tui.md) |
| `bash demos/demo.multi-line.sh stream` | Edit five lines inline below existing output | [Stream recording](../images/public/ui.multi-line-stream.gif) |
| `bash demos/demo.capture-key.sh` | Inspect semantic key tokens; Ctrl+D exits | [Key diagnostic recording](../images/public/ui.capture-key.gif) |
| `bash demos/demo.selector.sh` | Choose a connection from a short menu | [Selector recording](../images/public/ui.selector.gif) |
| `bash demos/demo.readpswd.sh` | Try masked input with a dummy value; the demo prints it afterward | [Password recording](../images/public/ui.ask-for-password.gif) |
| `bash demos/demo.colors.sh` | Inspect your terminal's palette | [Colors recording](../images/public/terminal.colors.gif) |
| `bash demos/demo.emojis.sh` | Check font/terminal emoji rendering | [Emoji recording](../images/public/demo-emoji-support.gif) |

`demo.multi-line-test.sh` is an additional editor exercise; the two modes above
are the starting point. Clipboard integration requires a working desktop
clipboard as described in the [TUI guide](tui.md).

## Library features

| Feature | Demo files in `demos/` | Documentation |
| --- | --- | --- |
| Bootstrap | `demo.bootstrap-minimal.sh`, `demo.bootstrap-educational.sh` | [Installation](installation.md) |
| Logging | `demo.logs.sh`, `demo.debug.sh`, `demo.ecs-json-logging.sh` | [Logger](logger.md) |
| Argument parsing | `demo.args.sh` | [Arguments](arguments.md) |
| Shell completion | `completion/demo.completion.sh`, `completion/demo.curl.sh` | [Completion](completion.md) |
| Dependency checks and cache | `demo.dependencies.sh`, `demo.cache.sh`, `demo.ci.dependencies.sh` | [Dependency API](lib/_dependencies.md) |
| Dry-run and rollback modes | `demo.dryrun.sh`, `demo.dryrun-v2.sh`, `demo.dryrun-modes.sh` | [Dry-run wrapper](dryrun-wrapper.md) |
| Hooks | `demo.hooks.sh`, `demo.hooks-registration.sh`, `demo.hooks-logging.sh`, `demo.hooks-nested.sh` | [Hooks](hooks.md) |
| Traps | `demo.traps.sh` | [Traps](traps.md) |
| Semantic versions and sorting | `demo.semver.sh`, `demo.sorting.sh`, `demo.sorting.v2.sh` | [Semver API](lib/_semver.md) |
| Self-updates | `demo.selfupdate.sh` | [README self-update guide](../../README.md#self-update) |
| Self-healing and environment validation | `demo.self-healing.sh`, `demo.envrc.validator.sh` | [Self-healing scripts](self-healing-scripts.md) |
| CI modes | `ci-mode/demo.ci-modes.sh`, `ci-mode/demo.ci-modes-middleware.sh` | [CI mode guide](../../demos/ci-mode/README.md) |

Read a demo before running it: dependency, dry-run, self-update and self-healing
examples can execute commands, install dependencies or update local files.
`benchmark.colors.sh` and `benchmark.ecs.sh` measure performance rather than
demonstrating an interactive UI.

## Logs and tmux

The [logs tool guide](logs.md) already includes capture and search screenshots.
`demo.logs.capture.sh` demonstrates the tool; `demo.logs.sh` demonstrates the
logger library. They serve different workflows. Search requires `fzf`; separated
capture uses tmux. See the tool guide for prerequisites and shutdown behavior.

The tmux demos need tmux; several explicitly check for version `3.5a`. They
create sessions/panes and FIFOs, and may change mouse settings or clean up panes.
Read their cleanup paths before trying them in a session with existing work.

| Demo | Purpose |
| --- | --- |
| `demo.tmux.progress.sh` | A progress area below a running task |
| `demo.tmux.runner.sh` | A command pane with separate stdout/stderr; T or E layout |
| `demo.tmux.streams.sh` | Run an executable script with command/stdout/stderr panes |
| `demo.tmux.exec.sh` | Interactive command execution with logging and pane layout |

The [tmux API reference](lib/_tmux.md) describes the reusable library functions.
These demos still need verified walkthroughs and actual recordings; they are
not represented by the editor recordings above.

## Tool documentation

| Tool or workflow | Guide |
| --- | --- |
| `bin/logs.sh` | [Capture and fuzzy search](logs.md) |
| `bin/e-docs.sh` | [Documentation generation](e-docs.md) |
| `bin/version-up.v2.sh` | [Versioning](version-up.md), [scenarios](version-up-scenarios.md) |
| `bin/git.semantic-version.sh` | [Semantic Git versioning](../promo/git-semantic-versioning.md) |
| `bin/git.sync-by-patches.sh` | [Git synchronization](git-synchronize.md) |
| `bin/clipboard-image-save.sh` | [Clipboard image saving on WSL](../promo/clipboard-image-save.md) |
| `bin/wsl/xdg-open.sh` | [Opening Windows apps from WSL](../promo/wsl-xdg-open.md) |
| `bin/shellspec.format.sh` | [ShellSpec formatting](shellspec-formatter.md) |
| `bin/profiler/profile.sh`, `bin/profiler/tracing.sh` | [README profiling examples](../../README.md#profile-bash-script-execution) |

For identified gaps and the next documentation work, see the
[documentation audit](../work/documentation-audit.md).
