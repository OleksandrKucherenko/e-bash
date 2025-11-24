# Real-World ShellSpec Examples

Learn from production-grade test patterns used in major open source projects.

## Top Projects Using ShellSpec

### 1. ShellSpec Itself
**Use Case**: Framework self-testing
**Key Pattern**: Comprehensive DSL coverage

```bash
Describe 'example block'
  It 'supports basic evaluation'
    When call echo "hello"
    The output should equal "hello"
  End
  
  It 'supports status evaluation'
    When call false
    The status should be failure
  End
End
```

**Lesson**: Test your own features comprehensively.

### 2. jenkins-x/terraform-google-jx
**Use Case**: Infrastructure as Code testing
**Key Pattern**: Binary wrapping, cloud mocking

```bash
Describe 'Kubernetes Service Accounts'
  Mock kubectl
    case "$2" in
      "get") echo "kaniko-sa\ntekton-sa" ;;
      "create") echo "created" ;;
    esac
  End
  
  It 'creates service accounts'
    When call ensure_service_accounts
    The output should include 'kaniko-sa'
  End
End
```

**Lesson**: Mock cloud CLIs extensively.

### 3. snyk/snyk
**Use Case**: Security tool testing
**Key Pattern**: Cross-platform validation

```bash
Describe 'CLI installation'
  Parameters:matrix
    "linux" "x64"
    "darwin" "x64"
  End
  
  It "installs on $1 $2"
    Skip if "[ \"$(uname -s)\" != \"$1\" ]"
    When call install_snyk "$1" "$2"
    The status should be success
  End
End
```

**Lesson**: Use matrix for cross-platform testing.

### 4. ShellMetrics
**Use Case**: Code complexity analysis
**Key Pattern**: Data-driven testing

```bash
Describe 'complexity calculation'
  Parameters
    "simple"  "echo hello"           1
    "if"      "if true; then fi"     2
    "case-3"  "case x in a|b|c esac" 4
  End
  
  It "calculates $1"
    echo "$2" | When call calculate_complexity
    The output should eq "$3"
  End
End
```

**Lesson**: Parameterized tests for algorithms.

### 5. getoptions
**Use Case**: Option parser library
**Key Pattern**: Argument parsing

```bash
Describe 'option parsing'
  It 'parses short options'
    When call parse_options -v -f test.txt
    The variable VERBOSE should eq 1
    The variable FILE should eq "test.txt"
  End
  
  It 'parses long options'
    When call parse_options --verbose --file=test.txt
    The variable VERBOSE should eq 1
  End
End
```

**Lesson**: Test all argument formats.

## Common Patterns

### Pattern 1: Mock Complex Commands

```bash
Mock complex_tool
  case "$1" in
    "list") echo "item1\nitem2" ;;
    "get") echo "{\"id\": \"$2\"}" ;;
    "create") echo "{\"created\": true}" ;;
    *) return 1 ;;
  esac
End
```

### Pattern 2: Environment-Specific Testing

```bash
Describe 'environment-aware'
  Parameters
    "dev" "/tmp/dev"
    "staging" "/tmp/staging"
    "prod" "/opt/prod"
  End
  
  It "deploys to $1"
    export ENVIRONMENT="$1"
    export DEPLOY_PATH="$2"
    When call deploy
    The status should be success
  End
End
```

### Pattern 3: Retry Logic

```bash
Describe 'retry mechanism'
  setup_retry() {
    attempt=0
    flaky_service() {
      attempt=$((attempt + 1))
      [ $attempt -lt 3 ] && return 1
      return 0
    }
  }
  
  BeforeEach 'setup_retry'
  
  It 'retries until success'
    When call retry_with_backoff flaky_service 3
    The status should be success
  End
End
```

### Pattern 4: Configuration Parsing

```bash
Describe 'config parsing'
  BeforeEach 'setup_config'
  
  setup_config() {
    cat > /tmp/test.conf << 'EOF'
database_host=localhost
database_port=5432
EOF
  }
  
  It 'parses config'
    When call load_config /tmp/test.conf
    The variable DATABASE_HOST should eq "localhost"
  End
End
```

## Test Organization

### Mirror Project Structure

```
project/
├── lib/
│   ├── auth.sh
│   └── network.sh
└── spec/
    └── lib/
        ├── auth_spec.sh
        └── network_spec.sh
```

### Shared Test Utilities

```
spec/
├── spec_helper.sh
├── support/
│   ├── mocks.sh
│   └── fixtures.sh
└── lib/
    └── my_module_spec.sh
```

## Coverage Patterns

### High Coverage Projects (>80%)
- ShellSpec: 95%+
- getoptions: 90%+
- readlinkf: 85%+

**Common Practices**:
1. Test every function
2. Cover all branches
3. Test error paths
4. Use coverage in CI
5. Set minimum thresholds

### Example Coverage Config

```bash
# .shellspec
--kcov
--kcov-options "--include-pattern=lib/,bin/"
--kcov-options "--fail-under-percent=80"
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - run: curl -fsSL https://git.io/shellspec | sh -s -- -y
    - run: shellspec --kcov --format junit
```

### GitLab CI

```yaml
test:
  image: shellspec/shellspec:latest
  script:
    - shellspec --kcov --format junit
  artifacts:
    reports:
      junit: report/junit.xml
```

## Key Takeaways

1. **Mock aggressively** - All external dependencies
2. **Test edge cases** - Production handles errors
3. **Use parameters** - Reduce duplication
4. **Cross-platform** - Test multiple shells
5. **CI integration** - Automate testing
6. **Track coverage** - Maintain high standards
7. **Real integration** - Use Docker when needed
8. **Documentation** - Tests as examples
9. **Incremental** - Add tests gradually
10. **Fast feedback** - Keep tests fast

## Resources

- ShellSpec Homepage: https://shellspec.info/
- GitHub: https://github.com/shellspec/shellspec
- Docker Image: https://hub.docker.com/r/shellspec/shellspec
