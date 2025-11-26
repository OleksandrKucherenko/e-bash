# Real-World Projects Using BATS

Learn from battle-tested BATS implementations in production systems.

## Tier 1: Critical Infrastructure (10k+ stars)

### rbenv - Ruby Version Manager
**Stars**: 16k+ | **URL**: https://github.com/rbenv/rbenv

The original project BATS was created for. Reference implementation for testing version managers.

**Test Location**: `test/`

**What They Test**:
- Shell initialization and PATH manipulation
- Version switching between Ruby versions
- Shim generation and execution
- Plugin system integration

**Example Pattern**:
```bash
@test "creates shims directory" {
    assert [ ! -d "${RBENV_ROOT}/shims" ]
    run rbenv-init -
    assert_success
    assert [ -d "${RBENV_ROOT}/shims" ]
}
```

---

### Dokku - Docker PaaS
**Stars**: 26k+ | **URL**: https://github.com/dokku/dokku

Heroku-like PaaS testing deployment pipelines.

**Test Location**: `tests/unit/`

**What They Test**:
- Application deployment workflows
- Plugin system functionality
- Nginx configuration generation
- SSL certificate management
- Database linking

**Pattern**: Heavy use of `setup_file()` for Docker container setup.

---

### runc - OCI Container Runtime
**Stars**: 11.5k+ | **URL**: https://github.com/opencontainers/runc

Core container runtime used by Docker and Kubernetes.

**Test Location**: `tests/integration/`

**What They Test**:
- Container lifecycle (create, start, stop, delete)
- Resource constraints (cgroups)
- Security features (seccomp, apparmor)
- Namespace isolation
- Hook execution

**Pattern**: Critical infrastructure testing with extensive mocking.

---

### asdf-vm - Multi-Language Version Manager
**Stars**: 25k+ | **URL**: https://github.com/asdf-vm/asdf

Universal version manager for multiple languages.

**Test Location**: `test/`

**What They Test**:
- Plugin installation and management
- Version switching across languages
- Shell integration (bash, zsh, fish)
- Cache management

---

## Tier 2: Popular Tools (1k-10k stars)

### Dolt - Git for Data
**Stars**: 17k+ | **URL**: https://github.com/dolthub/dolt

SQL database with Git-like version control.

**Test Location**: `integration-tests/bats/`

**What They Test**:
- SQL command integration
- Version control operations (merge, diff, branch)
- Data integrity across operations
- CLI behavior

**Pattern**: Modern BATS usage with complex integration scenarios.

---

### Pi-hole - Network Ad Blocker
**Stars**: 40k+ | **URL**: https://github.com/pi-hole/pi-hole

Network-wide ad blocking.

**Test Location**: `test/`

**What They Test**:
- Installation scripts
- Update mechanisms
- Debugging scripts
- DNS configuration

**Pattern**: Testing shell scripts that run on resource-constrained devices.

---

### git-secrets - AWS Labs
**Stars**: 11k+ | **URL**: https://github.com/awslabs/git-secrets

Prevents committing secrets to repositories.

**Test Location**: `test/`

**What They Test**:
- Git hook integration
- Pattern matching for secrets
- Pre-commit blocking
- Multiple secret patterns

---

### SDKMAN - SDK Manager
**Stars**: 5k+ | **URL**: https://github.com/sdkman/sdkman-cli

Manages multiple SDK versions (Java, Groovy, Scala).

**Test Location**: `src/test/`

**What They Test**:
- Installation and upgrade
- Version switching
- Candidate management
- Offline mode

---

## Tier 3: Learning Resources

### bats-core/bats-core
**URL**: https://github.com/bats-core/bats-core/tree/master/test

BATS testing itself. Excellent reference for advanced patterns.

### alexanderepstein/Bash-Snippets
**Stars**: 10k+ | **URL**: https://github.com/alexanderepstein/Bash-Snippets

Collection of utility scripts with BATS tests for each tool.

### docker-mailserver
**Stars**: 12k+ | **URL**: https://github.com/docker-mailserver/docker-mailserver

Full mail server setup with extensive BATS integration tests.

---

## Common Patterns Across Projects

### CLI Testing Pattern

```bash
@test "shows help with --help" {
    run mycommand --help
    assert_success
    assert_output --partial "Usage:"
}

@test "fails gracefully on invalid args" {
    run mycommand --invalid
    assert_failure
    assert_output --partial "Unknown option"
}
```

### Version Manager Pattern

```bash
@test "switches to specified version" {
    run myenv global 3.2.1
    assert_success
    
    run myenv version
    assert_output "3.2.1"
}

@test "falls back to system version" {
    run myenv global system
    assert_success
    
    run which ruby
    assert_output "/usr/bin/ruby"
}
```

### File System Pattern

```bash
@test "creates configuration directory" {
    run setup_app
    assert_success
    
    assert_dir_exists ~/.myapp
    assert_file_exists ~/.myapp/config
    assert_file_contains ~/.myapp/config "initialized=true"
}
```

### Integration Test Pattern

```bash
setup_file() {
    export CONTAINER_ID=$(docker run -d myapp:test)
    # Wait for container to be ready
    for i in {1..30}; do
        docker exec "$CONTAINER_ID" curl -s localhost:8080/health && break
        sleep 1
    done
}

teardown_file() {
    docker rm -f "$CONTAINER_ID"
}

@test "api responds to requests" {
    run docker exec "$CONTAINER_ID" curl -s localhost:8080/api/status
    assert_success
    assert_output --partial '"status":"ok"'
}
```

### Mock External Service Pattern

```bash
setup() {
    # Create mock API server
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/curl" <<'EOF'
#!/bin/bash
case "$*" in
    *api.example.com*)
        echo '{"version":"1.0"}'
        ;;
    *)
        command curl "$@"
        ;;
esac
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/curl"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "fetches version from API" {
    run check_version
    assert_success
    assert_output "1.0"
}
```

---

## Project Organization Patterns

### Small Project (< 50 tests)

```
test/
├── test_helper.bash
└── test_main.bats
```

### Medium Project (50-200 tests)

```
test/
├── test_helper/
│   ├── bats-support/
│   ├── bats-assert/
│   └── common.bash
├── fixtures/
│   └── sample_data.txt
├── unit/
│   ├── test_parser.bats
│   └── test_validator.bats
└── integration/
    └── test_e2e.bats
```

### Large Project (200+ tests)

```
test/
├── test_helper/
│   ├── bats-support/
│   ├── bats-assert/
│   ├── bats-file/
│   ├── mocks/
│   │   ├── docker.bash
│   │   └── curl.bash
│   └── common-setup.bash
├── fixtures/
│   ├── configs/
│   └── expected/
├── unit/
│   ├── core/
│   └── utils/
├── integration/
│   ├── api/
│   └── cli/
└── e2e/
    └── smoke/
```

---

## Key Takeaways

1. **BATS scales** - Used from small utilities to Docker/Kubernetes infrastructure
2. **Version managers love BATS** - rbenv, nodenv, pyenv, asdf all use it
3. **Integration tests dominate** - Most projects use BATS for integration, not unit tests
4. **Helper libraries essential** - All serious projects use bats-assert and bats-support
5. **Mocking is critical** - Stubbing external commands is universal pattern
6. **setup_file for expensive ops** - Container setup, compilation in file-level hooks
