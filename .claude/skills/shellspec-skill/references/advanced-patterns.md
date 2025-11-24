# Advanced ShellSpec Patterns

This file contains advanced testing patterns for complex scenarios and sophisticated mocking strategies.

## Spy Pattern (Call Tracking)

Track function calls without changing behavior:

```bash
Describe 'spying on function calls'
  call_log=""
  
  git() {
    call_log="${call_log}git $*;"
    echo "Mock git output"
  }
  
  It 'tracks all git operations'
    When call deploy_script
    The variable call_log should include "git commit"
    The variable call_log should include "git push"
  End
End
```

## Advanced Spy with Call Counting

```bash
Describe 'call counting'
  setup_spy() {
    call_count=0
    last_args=""
    
    fetch_data() {
      call_count=$((call_count + 1))
      last_args="$*"
      echo "mock response"
    }
  }
  
  BeforeEach 'setup_spy'
  
  It 'verifies exact call count'
    When call process_multiple_sources
    The variable call_count should eq 3
  End
End
```

## Stateful Mocks

Create mocks that respond differently per call:

```bash
Describe 'stateful mocking'
  setup_stateful_mock() {
    call_number=0
    
    api_call() {
      call_number=$((call_number + 1))
      case $call_number in
        1) echo '{"page": 1, "has_more": true}' ;;
        2) echo '{"page": 2, "has_more": true}' ;;
        3) echo '{"page": 3, "has_more": false}' ;;
        *) echo '{"error": "too many calls"}' ;;
      esac
    }
  }
  
  BeforeEach 'setup_stateful_mock'
  
  It 'handles pagination correctly'
    When call fetch_all_pages
    The variable call_number should eq 3
    The output should include "page: 3"
  End
End
```

## Conditional Mocks Based on Arguments

```bash
Describe 'argument-based mocking'
  Mock curl
    case "$2" in
      *"/users/"*) echo '{"user": "mock"}' ;;
      *"/posts/"*) echo '{"post": "mock"}' ;;
      *) echo '{"error": "unknown"}' >&2; return 1 ;;
    esac
  End
  
  It 'mocks different endpoints'
    When call fetch_user_data
    The output should include "user"
  End
End
```

## Testing Retry Logic

```bash
Describe 'retry mechanism'
  setup_failing_service() {
    attempt=0
    
    unreliable_service() {
      attempt=$((attempt + 1))
      if [ $attempt -lt 3 ]; then
        return 1
      else
        return 0
      fi
    }
  }
  
  BeforeEach 'setup_failing_service'
  
  It 'retries until success'
    When call retry_until_success unreliable_service 3
    The status should be success
    The variable attempt should eq 3
  End
End
```

## Testing File Processing Pipelines

```bash
Describe 'file processing pipeline'
  BeforeEach 'setup_pipeline_env'
  AfterEach 'cleanup_pipeline_env'
  
  setup_pipeline_env() {
    TEST_DIR=$(mktemp -d)
    INPUT_DIR="$TEST_DIR/input"
    mkdir -p "$INPUT_DIR"
    
    for i in {1..5}; do
      echo "data $i" > "$INPUT_DIR/file$i.txt"
    done
  }
  
  cleanup_pipeline_env() {
    rm -rf "$TEST_DIR"
  }
  
  It 'processes all files'
    When call process_directory "$INPUT_DIR"
    The status should be success
  End
End
```

## Matrix Testing

Test across multiple configurations:

```bash
Describe 'cross-platform'
  Parameters:matrix
    bash dash zsh
  End
  
  It "works in $1 shell"
    When run "$1" -c './my_script.sh'
    The status should be success
  End
End
```

## Custom Matchers

```bash
# spec/support/custom_matchers.sh

# Match JSON structure
match_json_structure() {
  local json="$1"
  local expected_keys="$2"
  
  for key in $expected_keys; do
    echo "$json" | grep -q "\"$key\":" || return 1
  done
  return 0
}

# Validate email format
match_email_format() {
  echo "$1" | grep -qE '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$'
}

# Usage in tests
Describe 'custom matchers'
  It 'validates JSON response'
    When call api_call
    The output should satisfy match_json_structure "id name email"
  End
  
  It 'validates email'
    When call get_user_email
    The output should satisfy match_email_format
  End
End
```

## Performance Optimization

### Parallel-Safe Tests

```bash
Describe 'parallel-safe tests'
  BeforeEach 'setup_unique_temp'
  
  setup_unique_temp() {
    # Use process ID and random for uniqueness
    TEMP_FILE="/tmp/test_$$_${RANDOM}.tmp"
    export TEMP_FILE
  }
  
  AfterEach 'cleanup_unique_temp'
  cleanup_unique_temp() {
    rm -f "$TEMP_FILE"
  }
End
```

### Lazy Loading for Heavy Resources

```bash
Describe 'lazy resource loading'
  load_database() {
    if [ -z "$DATABASE_LOADED" ]; then
      setup_test_database
      DATABASE_LOADED=true
    fi
  }
  
  Context 'tests requiring database'
    BeforeAll 'load_database'
    
    It 'uses database efficiently'
      When call query_database
      The status should be success
    End
  End
End
```

## Integration Testing Patterns

### Testing Script Chains

```bash
Describe 'script pipeline'
  It 'executes full pipeline'
    # Step 1: Extract
    When run script ./bin/extract.sh input.csv
    The status should be success
    
    # Step 2: Transform
    When run script ./bin/transform.sh
    The status should be success
    
    # Step 3: Load
    When run script ./bin/load.sh
    The status should be success
  End
End
```

### Testing with Docker

```bash
Describe 'containerized testing'
  Skip if "! command -v docker" "Docker not available"
  
  BeforeAll 'start_container'
  AfterAll 'stop_container'
  
  start_container() {
    CONTAINER_ID=$(docker run -d --rm nginx:alpine)
    sleep 2
  }
  
  stop_container() {
    docker stop "$CONTAINER_ID"
  }
  
  It 'connects to service'
    When run curl -s http://localhost
    The status should be success
  End
End
```

## Best Practices Summary

1. **Mock external dependencies** - Network, time, random
2. **Use spy patterns** - Track calls without breaking functionality
3. **Isolate with temp directories** - Unique paths prevent interference
4. **Leverage parameterized tests** - Reduce duplication
5. **Create custom matchers** - Encapsulate complex assertions
6. **Test error paths** - Error handling is critical
7. **Enable parallel execution** - Ensure tests are isolated
8. **Use matrix testing** - Verify cross-platform compatibility
