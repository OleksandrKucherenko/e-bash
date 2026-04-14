# Building Complex CLI Tools with e-bash

A strategy guide for building AWS CLI-grade command-line tools using `_arguments.sh`.

Reference: [AWS CLI](https://docs.aws.amazon.com/cli/latest/reference/) — 400+ services, thousands of commands, complex argument types.

## Command Hierarchy

AWS CLI uses a 3-level hierarchy:

```
aws [global-options] <service> <action> [command-options]
```

**e-bash implementation:** use scoped parsing with 2-3 phases.

```bash
#!/usr/bin/env bash

export SKIP_ARGS_PARSING=1
source "$E_BASH/_arguments.sh"

# ── Phase 1: Global options + service extraction ──────────────
GLOBAL_SCOPE="--debug --profile=profile::1 --region=region::1 --output=output:json:1 \$1=service::1"
ARGS_DEFINITION="$GLOBAL_SCOPE"
parse:arguments "$@"

args:t "--output" "enum:json,text,table,yaml"
args:t "--region" "pattern:^[a-z]{2}-[a-z]+-[0-9]+$"
args:validate || exit 1

local -a remaining=("${ARGS_UNPARSED[@]}")

# ── Phase 2: Service → action routing ─────────────────────────
case "$service" in
  s3)    source "$SCRIPT_DIR/commands/s3.sh"    "${remaining[@]}" ;;
  ec2)   source "$SCRIPT_DIR/commands/ec2.sh"   "${remaining[@]}" ;;
  iam)   source "$SCRIPT_DIR/commands/iam.sh"   "${remaining[@]}" ;;
  *)     echo "Unknown service: $service" >&2; exit 1 ;;
esac
```

Each service script extracts the action and re-parses:

```bash
# commands/s3.sh — receives remaining args after global parse

ACTION_SCOPE="\$1=action::1"
args:scope ACTION_SCOPE "$@"

case "$action" in
  cp)   source "$SCRIPT_DIR/commands/s3/cp.sh"   "${ARGS_UNPARSED[@]}" ;;
  ls)   source "$SCRIPT_DIR/commands/s3/ls.sh"   "${ARGS_UNPARSED[@]}" ;;
  sync) source "$SCRIPT_DIR/commands/s3/sync.sh" "${ARGS_UNPARSED[@]}" ;;
esac
```

Each action script defines its own flags:

```bash
# commands/s3/cp.sh — receives remaining args after service+action parse

CP_SCOPE="\$1=source::1 \$2=destination::1 --recursive --quiet --dryrun"
CP_SCOPE+=" --storage-class=storage_class:STANDARD:1"
CP_SCOPE+=" --acl=acl::1 --sse=sse::1 --content-type=content_type::1"

args:scope CP_SCOPE "$@"

args:t "--storage-class" "enum:STANDARD,REDUCED_REDUNDANCY,STANDARD_IA,ONEZONE_IA,INTELLIGENT_TIERING,GLACIER,DEEP_ARCHIVE,GLACIER_IR"
args:t "--acl" "enum:private,public-read,public-read-write,authenticated-read,bucket-owner-read,bucket-owner-full-control"
args:validate || exit 1
```

## Pattern Mapping: AWS CLI → e-bash

### Fully Supported (native)

| AWS Pattern | Example | ARGS_DEFINITION | Validation |
|-------------|---------|-----------------|------------|
| Boolean flag | `--debug` | `--debug` | — |
| Negation flag | `--no-verify-ssl` | `--no-verify-ssl=verify_ssl:false` | — |
| Toggle pair | `--dry-run \| --no-dry-run` | `--dry-run=dryrun:true --no-dry-run=dryrun:false` | — |
| String option | `--region us-east-1` | `--region=region::1` | `args:t "--region" "pattern:..."` |
| Integer option | `--timeout 300` | `--timeout=timeout::1` | `args:t "--timeout" "int:1:3600"` |
| Enum option | `--output json` | `--output=output:json:1` | `args:t "--output" "enum:json,text,table"` |
| Default value | `--output json` (default) | `--output=output:json:1` | pre-filled automatically |
| Positional args | `<source> <dest>` | `\$1=source::1 \$2=dest::1` | — |
| End-of-options | `--` | native `--` support | — |
| 3-level hierarchy | `aws s3 cp` | scoped parsing (3 phases) | — |

### Supported with Workarounds

| AWS Pattern | Example | Workaround |
|-------------|---------|------------|
| Fixed-count list | `--instance-ids id1 id2` | `--instance-ids=ids::2` (space-joined string, user splits) |
| Variable-count list | `--layers arn1 arn2 arn3` | User pre-scans `$@` and counts args, or uses ARGS_UNPARSED |
| Repeatable flag | `--include "*.jpg" --include "*.png"` | Last wins. User collects before parsing: `for a in "$@"; do [[ "$a" == --include=* ]] && includes+=("${a#*=}"); done` |
| Mutually exclusive | `--json \| --yaml` | Both map to same variable: `--json=input_format:json --yaml=input_format:yaml` |
| Required flag check | `--analyzer-arn` (required) | `args:validate` + `args:t "--analyzer-arn" "string:1:"` (min length 1) |

### User-Side Processing (parser delivers raw string)

These patterns are **not parsed** by `_arguments.sh` — the parser captures the raw value as a string, and user code processes it further.

| AWS Pattern | Example | User Processing |
|-------------|---------|-----------------|
| Structure shorthand | `--placement AZ=us-east-1a` | `IFS=',' read -ra pairs <<< "$placement"; for p in "${pairs[@]}"; do k="${p%%=*}"; v="${p#*=}"; done` |
| Nested structure | `--ebs Ebs={VolumeSize=100}` | Parse with nested `{...}` handler or require JSON |
| Map | `--metadata K1=V1,K2=V2` | Same comma-split logic as structures |
| JSON value | `--filters '[{...}]'` | `echo "$filters" \| jq ...` |
| `file://` reference | `--policy file://p.json` | `[[ "$policy" == file://* ]] && policy=$(cat "${policy#file://}")` |
| JMESPath query | `--query 'expr'` | Forward to `jq` or Python |

### Recommended Helper Functions

For user-side processing, provide these reusable helpers in your CLI tool:

```bash
# Parse shorthand structure: "Key1=Val1,Key2=Val2" → associative array
function parse:shorthand() {
  local -n _map="$1"; local input="$2"
  IFS=',' read -ra pairs <<< "$input"
  for pair in "${pairs[@]}"; do
    _map["${pair%%=*}"]="${pair#*=}"
  done
}

# Resolve file:// references
function resolve:file_ref() {
  local value="$1"
  if [[ "$value" == file://* ]]; then
    cat "${value#file://}"
  elif [[ "$value" == fileb://* ]]; then
    base64 < "${value#fileb://}"
  else
    echo "$value"
  fi
}

# Collect repeatable flags from raw args (before parsing)
function collect:repeated() {
  local flag="$1"; shift
  local -n _arr="$2"; shift
  for arg in "$@"; do
    if [[ "$arg" == "${flag}="* ]]; then
      _arr+=("${arg#*=}")
    fi
  done
}
```

Usage:

```bash
# Structure shorthand
declare -A placement=()
parse:shorthand placement "$placement_raw"
echo "${placement[AvailabilityZone]}"  # us-east-1a

# File reference
policy=$(resolve:file_ref "$policy_document")

# Repeatable flags (collect BEFORE parsing)
declare -a includes=()
collect:repeated "--include" includes "$@"
```

## Project Structure

For a large CLI tool, organize by service:

```
mytool/
├── bin/mytool.sh                    # Entry point: global opts + service routing
├── commands/
│   ├── s3.sh                        # Service: action routing
│   ├── s3/
│   │   ├── cp.sh                    # Action: s3 cp implementation
│   │   ├── ls.sh
│   │   └── sync.sh
│   ├── ec2.sh
│   ├── ec2/
│   │   ├── describe-instances.sh
│   │   └── run-instances.sh
│   └── iam.sh
├── lib/
│   ├── helpers.sh                   # parse:shorthand, resolve:file_ref, etc.
│   └── validators.sh                # Custom validation rules
└── completions/
    ├── mytool.bash                  # Generated via args:completion
    └── _mytool                      # Generated via args:completion zsh
```

## Complete Example: Mini AWS-Style CLI

```bash
#!/usr/bin/env bash
# bin/mytool.sh

export SKIP_ARGS_PARSING=1
source "$E_BASH/_arguments.sh"

# ── Global scope ──────────────────────────────────────────────
ARGS_DEFINITION="--debug --profile=profile:default:1 --region=region:us-east-1:1"
ARGS_DEFINITION+=" --output=output:json:1 --no-verify-ssl=verify_ssl:false"
ARGS_DEFINITION+=" \$1=service::1 \$2=action::1"

parse:arguments "$@"

args:t "--output" "enum:json,text,table,yaml"
args:t "--region" "pattern:^[a-z]{2}-[a-z]+-[0-9]+$"
args:validate || exit 1

# ── Route to service/action ───────────────────────────────────
case "${service:-}" in
  ""|help)
    echo "Usage: mytool [global-options] <service> <action> [options]"
    echo "Services: s3, ec2, iam"
    exit 0
    ;;
esac

# ── Action-specific parsing ───────────────────────────────────
case "$service:$action" in
  s3:cp)
    S3CP_SCOPE="\$1=source::1 \$2=dest::1 --recursive --quiet --dryrun"
    S3CP_SCOPE+=" --storage-class=storage_class:STANDARD:1"
    args:scope S3CP_SCOPE "${ARGS_UNPARSED[@]}"
    args:t "--storage-class" "enum:STANDARD,REDUCED_REDUNDANCY,STANDARD_IA"
    args:validate || exit 1

    echo "Copying $source → $dest (region=$region, storage=$storage_class)"
    ;;

  ec2:describe-instances)
    EC2DI_SCOPE="--instance-ids=instance_ids::1 --filters=filters::1"
    EC2DI_SCOPE+=" --max-items=max_items::1"
    args:scope EC2DI_SCOPE "${ARGS_UNPARSED[@]}"
    args:t "--max-items" "int:1:1000"
    args:validate || exit 1

    echo "Describing instances (region=$region, ids=$instance_ids)"
    ;;

  *)
    echo "Unknown command: $service $action" >&2
    exit 1
    ;;
esac
```

## Feature Support Summary

| Category | AWS Patterns | e-bash Support |
|----------|-------------|----------------|
| **Command hierarchy** | 3-level (aws → service → action) | Scoped parsing (native) |
| **Boolean flags** | `--debug`, `--no-flag`, toggle pairs | Native |
| **Value options** | String, integer, enum with defaults | Native + `args:t` validation |
| **Positional args** | `<source> <dest>` | Native (`$1`, `$2`) |
| **End-of-options** | `--` sentinel | Native |
| **Fixed-count lists** | `--ids id1 id2` (known count) | `args_qt > 1` |
| **Variable lists** | `--ids id1 id2 id3...` | User pre-collection |
| **Repeatable flags** | `--include x --include y` | User pre-collection |
| **Shorthand structures** | `Key=Val,Key2=Val2` | Raw string → user parses |
| **JSON values** | `'[{...}]'` | Raw string → user parses with jq |
| **File references** | `file://path` | Raw string → user resolves |
| **Shell completion** | Bash/Zsh auto-complete | `args:completion` (native) |
| **Help generation** | `--help` with grouped flags | `print:help` (native) |

**Bottom line:** e-bash handles ~80% of AWS CLI patterns natively. The remaining ~20% (complex types, variable-length lists, repeatable flags) require lightweight user-side helpers that receive raw strings from the parser.
