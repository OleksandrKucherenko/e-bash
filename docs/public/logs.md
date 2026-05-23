# e-bash logs.sh Documentation

`logs.sh` runs several long-running commands at once, tags every output line
with the service it came from, saves each service's logs to its own file plus
one consolidated file, and streams a live, color-per-service, keyword-
highlighted, JSON-aware view to your terminal. A `search` subcommand fuzzy-finds
through a recorded run with `fzf`, previewing the focused line as pretty JSON
when applicable.

<!-- TOC -->

- [Quick Start Guide](#quick-start-guide)
- [Overview](#overview)
- [Features and Capabilities](#features-and-capabilities)
  - [Tagging and fan-out to files](#tagging-and-fan-out-to-files)
  - [Live views: joined and separated](#live-views-joined-and-separated)
  - [Keyword highlighting](#keyword-highlighting)
  - [JSON formatting](#json-formatting)
  - [Registering services from a config file](#registering-services-from-a-config-file)
  - [Fuzzy search](#fuzzy-search)
- [Reference](#reference)
  - [Subcommands](#subcommands)
  - [capture options](#capture-options)
  - [search options](#search-options)
  - [Environment variables](#environment-variables)
  - [Output layout](#output-layout)
  - [Key functions](#key-functions)
- [Examples](#examples)
- [Limitations and notes](#limitations-and-notes)

<!-- /TOC -->

## Quick Start Guide

```bash
# Watch two services together (interleaved, tag-colored, Ctrl-C to stop).
# Services are positional "tag=command" specs, passed after "--":
bin/logs.sh capture -- \
  "api=node server.js" \
  "db=docker logs -f my-db"

# Logs are written under ./.logs/<UTC-timestamp>/ :
#   api.log   db.log   all.log   manifest.env   (+ ./.logs/latest -> newest run)

# Later, fuzzy-search the most recent run:
bin/logs.sh search --grep error
```

Requirements: `bash` 4+, coreutils (`tee`, `mkfifo`, `setsid`, `stdbuf`).
`jq` is optional (enables JSON formatting); `fzf` is required for `search`;
`tmux` is optional (enables the separated live view).

## Overview

Each registered service is a `tag=command` pair, given as a positional argument
after `--`. `logs.sh capture` launches every
command in parallel, merges its stdout and stderr, and prefixes each line with
the tag. Lines are written **raw** (no colors) to two places at once:

- `<tag>.log` — that one service's stream, exactly as emitted.
- `all.log` — every service combined, each line prefixed with its tag.

Coloring, keyword highlighting and JSON pretty-printing happen **only on the
terminal**, never in the files, so the files stay clean and greppable while the
live view is readable. Each service runs in its own process group, so one
service crashing leaves the others running, and Ctrl-C tears the whole tree
down cleanly.

## Features and Capabilities

### Tagging and fan-out to files

Every line is prefixed with its service tag in `all.log`; the per-service file
keeps the original line untouched. Appends use `O_APPEND`, so concurrent
services never interleave a single (sub-`PIPE_BUF`) line in `all.log`.

```bash
bin/logs.sh capture -- "web=./serve" "worker=./work"
# all.log:        web GET /            worker job 17 done
# web.log:        GET /
# worker.log:     job 17 done
```

### Live views: joined and separated

- **joined** (default): one interleaved, tag-colored stream.
- **separated** (`--separated`): one `tmux` pane per service when `tmux` is
  available on a terminal; otherwise it prints `tail -F` hints (the per-service
  files always exist, so you can watch any single service with
  `tail -F .logs/latest/<tag>.log`).
- **none** (`--no-view`): capture to files only, no terminal output.

### Keyword highlighting

Configurable `keyword:color` pairs are highlighted on the terminal only. The
default is `ERROR:lred,FATAL:lred,FAIL:lred,WARN:yellow,WARNING:yellow`.

```bash
bin/logs.sh capture --highlight "TODO:cyan,DEPRECATED:yellow" -- "app=./app"
```

Colors are e-bash `cl_*` names without the `cl_` prefix (e.g. `red`, `yellow`,
`cyan`). Highlighting is disabled automatically when `NO_COLOR` is set or
`TERM=dumb`.

### JSON formatting

When `jq` is installed and a line is a valid JSON object/array, the live view
shows it colorized (compact in the joined view, fully pretty in the search
preview). Non-JSON lines pass through unchanged. The files always keep the raw
line, so a JSON-emitting service produces a JSON-Lines `<tag>.log` you can query
with `jq` afterwards.

### Registering services

Services are positional `tag=command` arguments passed **after `--`**:

```bash
bin/logs.sh capture --separated -- "api=node server.js" "db=docker logs -f db"
```

> Pass services after `--`. This is `_arguments.sh`'s documented *end-of-options*
> behavior — everything after `--` is treated as positional (see
> [arguments.md](arguments.md)) — and `logs.sh` reads those specs from
> `ARGS_UNPARSED`.

### Registering services from a config file

Beyond the positional specs, services can be declared in a file of
`tag=command` lines. With `--config FILE` it is read explicitly; otherwise the
nearest `.logs-services` file found by walking up to the git root is used if
present. Positional specs win over config entries with the same tag.

```ini
# .logs-services
api=node server.js
db=docker logs -f my-db
# comments and blank lines are ignored
```

### Fuzzy search

`logs.sh search` feeds a recorded run into `fzf`. The list shows a scannable
line per record; the preview pane shows the focused line pretty-printed (JSON
via `jq -C`, otherwise highlighted text). Pre-filter by service with `--tag`,
seed the query with `--grep`, or pick a run with `--run`.

## Reference

### Subcommands

| Command | Purpose |
|---|---|
| `logs.sh capture [options]` | Run services in parallel and tail their logs. |
| `logs.sh search [options]`  | Fuzzy-search a recorded run with `fzf`. |
| `logs.sh --help` / `--version` | Top-level help / version. |

### capture options

Services are positional `tag=command` arguments after `--` (not a flag); `tag`
is `[A-Za-z0-9._-]`.

| Flag | Description |
|---|---|
| `-c, --config FILE` | Load services from FILE. Without it, the nearest `.logs-services` up to the git root is used. |
| `-o, --out DIR` | Base directory for runs (default: `./.logs`). |
| `--joined` | Interleaved colored stream (default). |
| `--separated` | One `tmux` pane per service (falls back to file hints). |
| `--no-view` | Capture to files only. |
| `--timestamps` | Prepend a UTC timestamp to every captured line. |
| `--highlight PAIRS` | Keyword colors, e.g. `"ERROR:lred,WARN:yellow"`. |
| `-h, --help` | Show capture help. |

### search options

| Flag | Description |
|---|---|
| `--run DIR` | Search this run (default: newest under the base). |
| `--base DIR` | Base directory holding runs (default: `./.logs`). |
| `--tag TAG` | Search a single service's file instead of `all.log`. |
| `-g, --grep TEXT` | Seed the `fzf` query. |
| `-h, --help` | Show search help. |

### Environment variables

| Variable | Purpose | Default |
|---|---|---|
| `LOGS_BASE_DIR` | Base directory for runs (same as `--out`). | `./.logs` |
| `LOGS_CONFIG_NAME` | Config file name discovered up to the git root. | `.logs-services` |
| `LOGS_HIGHLIGHT` | Keyword:color pairs (same as `--highlight`). | `ERROR:lred,FATAL:lred,FAIL:lred,WARN:yellow,WARNING:yellow` |
| `LOGS_TIMESTAMPS` | Non-empty enables per-line timestamps (same as `--timestamps`). | unset |
| `DEBUG` | e-bash logger tags; `logs` shows the tool's own status. | `logs` |
| `NO_COLOR` / `TERM=dumb` | Disable all coloring/highlighting. | unset |

### Output layout

```
./.logs/
  <UTC-timestamp>/          # e.g. 2026-05-23T16-58-04Z
    <tag>.log               # raw per-service stream
    all.log                 # consolidated, each line prefixed "<tag> "
    manifest.env            # tag=command map, start time, tool version
  latest -> <UTC-timestamp> # symlink to the newest run
```

### Key functions

These live in `bin/logs.sh` and are unit-tested via ShellSpec (`spec/bin/logs_spec.sh`):

| Function | Purpose |
|---|---|
| `logs:run_dir` | Create and echo a fresh `<base>/<timestamp>/`. |
| `logs:latest_run [base]` | Echo the newest run directory. |
| `logs:search:feed src [tag]` | Emit `visible<TAB>raw` lines for `fzf`. |
| `logs:search:preview line...` | Pretty-print one selected line for the preview pane. |
| `_logs:parse_service spec t c` | Split `tag=command` (first `=` wins) via namerefs. |
| `_logs:is_json str` | Succeed when `str` is JSON (gated on `jq`). |
| `_logs:reader tag per all` | Drain a worker's FIFO: raw → per-tag, tagged → consolidated. |
| `_logs:worker tag dir all cmd` | Launch one service (FIFO + reader + detached producer). |
| `_logs:colorize` | Render consolidated `<tag> <body>` lines to the terminal. |
| `_logs:cleanup` | Kill the recorded process groups and drop FIFOs. |

## Examples

```bash
# A web app, its worker, and a tailed container, with custom highlights:
bin/logs.sh capture --highlight "ERROR:lred,WARN:yellow,SLOW:purple" -- \
  "web=npm run dev" \
  "worker=npm run worker" \
  "db=docker logs -f pg"

# Capture silently to a chosen directory with timestamps, then search later:
bin/logs.sh capture --no-view --timestamps --out /tmp/run -- "job=./batch.sh"
bin/logs.sh search --base /tmp/run --grep failed

# Separated tmux view (one pane per service):
bin/logs.sh capture --separated -- "a=./a" "b=./b"

# Search only the api service in a specific run:
bin/logs.sh search --run .logs/2026-05-23T16-58-04Z --tag api
```

## Limitations and notes

- **Child buffering**: `logs.sh` line-buffers children with `stdbuf -oL -eL`,
  which only affects programs that use libc stdio buffering. Statically-linked
  Go/Rust binaries that self-buffer may appear in bursts; run them with their
  own unbuffered/flush option if needed.
- **`all.log` atomicity**: concurrent appends are interleave-safe only for lines
  below `PIPE_BUF` (4 KiB on Linux). The single-writer `<tag>.log` is the clean
  source of truth for ordering of very long lines.
- **Process groups**: cleanup kills each service's process group. A service that
  re-detaches itself (its own `setsid`/daemonization) escapes that group, like
  any supervisor.
- **`jq` / `fzf` / `tmux`** are optional/required as noted above; capture works
  without `jq` (no JSON formatting) and without `tmux` (no separated view).
  `search` requires `fzf`.
- The default run directory `./.logs/` matches the repo-wide `*.log` gitignore;
  add `/.logs/` to `.gitignore` if you also want `manifest.env` ignored.
```
