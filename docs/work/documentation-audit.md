# Documentation and demo audit

This audit compares the current `.scripts/`, `demos/`, `bin/`, README,
`docs/public/`, `docs/promo/` and `docs/images/public/` inventory. “Weak” means a
reader must infer usage from source, a generated API page, or migration notes;
it does not mean the feature is broken. Visuals are prioritized for interactive
or colored output, rather than requiring a video for every function.

## Highest-priority gaps

| Feature | Evidence before this improvement | User impact | Next action / progress |
| --- | --- | --- | --- |
| Multi-line editor | README examples and `_tui` API; no editor image or recording among public assets | Cannot see box versus stream mode, save/cancel flow, or status bar | Added [walkthrough](../public/tui.md), two GIFs, stills and replayable recordings |
| Key capture | Demo exists, but no dedicated walkthrough or visual | Users cannot connect key tokens to `ML_KEY_*`; some examples place the variable outside command substitution | Added diagnostic recording and correct scoped keybinding example; documented the empty raw-byte columns found during capture |
| Tmux progress and command runners | Four demos and generated `_tmux` API; examples scattered in the migration guide; no public tmux image/recording | Pane layout, prerequisites and cleanup behavior are hard to discover | Added [demo catalog](../public/demos.md); next: validate each demo in a disposable tmux server, then record progress and stdout/stderr layouts |
| `npm.versions.sh` | Inline help and interactive source, no dedicated guide or public visual | Registry/version selection and unpublish actions are not explained as a complete workflow | Add a guide using a fixture or disposable package, separate read-only browsing from unpublish, then record the selection UI |
| `git.graph.sh` | Inline usage, no dedicated walkthrough or graph visual in public assets | Graph flags and expected output are hard to discover | Add a read-only sample repository and captured graph output |
| `tree.sh` and IPv6 coloring | Source and IPv6 demo/migration mentions; no dedicated guides or matching visuals | Readers must discover input/output conventions in scripts | Add piped-input examples with expected colored/plain output; do not reuse the `git.files.sh` screenshot as evidence for a different tool |
| `vhd.sh`, Git SSH setup, `un-link.sh`, WSL diagnostics | Primarily source/help rather than public task guides | Platform assumptions and file/configuration changes are unclear | Document prerequisites, exact effects, recovery and representative help/output; capture only on the supported platform |

## Library coverage

| Module | Existing user documentation | Assessment |
| --- | --- | --- |
| `_arguments.sh` | Arguments and completion guides, API, demos | Good task coverage; add a completion screencast after verifying both shells |
| `_colors.sh` | README and palette GIF, API | Visual coverage exists |
| `_commons.sh` | Extensive commons guide and API | Useful but contains TUI material now owned by `_tui.sh`; reduce duplication after the new guide settles |
| `_dependencies.sh` | API, dependency/cache/CI demos, installation and self-healing mentions | Needs a task guide for version constraints, cache controls and CI install mode; no TUI video required |
| `_dryrun.sh` | Dedicated guide, API, multiple demos | Good written coverage; normal/dry/undo side-by-side output would help |
| `_gnu.sh` | API and setup mentions | Needs clear Linux/macOS alias explanation and when bootstrap creates `bin/gnubin`; no TUI video required |
| `_hooks.sh` | Dedicated guide, API, four demos and CI mode guide | Good written coverage |
| `_logger.sh` | Dedicated guide, API, logger/debug/ECS demos, debug GIF | Visual coverage exists; keep logger and multi-service logs tool distinct |
| `_self-update.sh` | README, API and self-update demo | Add a standalone workflow guide with update, bind and rollback examples and file effects |
| `_semver.sh` | README, generated API, semver/sorting demos | Add a concise range/sorting cookbook; Git versioning documentation covers a different task |
| `_tmux.sh` | API and migration examples | High priority: standalone guide and actual pane recordings |
| `_traps.sh` | Dedicated guide, API and demo | Good written coverage |
| `_tui.sh` | API, README and duplicated commons sections; selector/password GIFs | Editor/key diagnostic coverage added; terminal/clipboard requirements and cancellation now explicit |

## Existing visuals to retain

Selector, password input, colors, emoji rendering, debug logging, bootstrap,
Git log output, Git changed-file tree and profiling already have public GIFs or
images. `logs.sh` has both capture and search screenshots in its dedicated
guide; it needs README discovery more than another static screenshot.
Clipboard-image saving and WSL app launching have promotional walkthroughs,
but text mockups are not recordings of those platform integrations.

## Changes made in this pass

- Added the TUI guide and linked it from the README and commons documentation.
- Recorded the existing editor demos in box and stream modes, including saving
  and the returned text; recorded the existing key diagnostic.
- Added a demo catalog connecting library features and tools to their guides.
- Added README discovery for the logs tool and its existing screenshots.
- Corrected the custom-save-key example to set the semantic token inside the
  editor's command substitution, and documented the selection-mode key.
- Added [recording instructions](../tools/README.md) and a reproducible capture
  helper. No library behavior or demo implementation changed.

## Follow-up order

1. Validate tmux demo startup/cleanup in an isolated server and publish real
   progress and runner recordings. Do not advertise unverified examples as working.
2. Document npm version management with a safe fixture-driven demonstration.
3. Add read-only graph/tree/IPv6 examples and images.
4. Write dependency/cache and self-update task guides, then deduplicate the
   commons/TUI material and improve API option tables at their source.
5. Validate WSL/VHD/SSH workflows on their supported platforms before recording
   them. Their screenshots cannot be produced faithfully in this Linux terminal.

This pass validates the recorded TUI flows and their existing tests. It does
not establish readiness of every cataloged demo or platform-specific tool.
