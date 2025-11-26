# CI/CD Integration Patterns

Complete guide for integrating BATS into continuous integration pipelines.

## GitHub Actions

### Basic Workflow

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive  # Important for BATS submodules
      
      - name: Run BATS tests
        run: ./test/bats/bin/bats test/
```

### With JUnit Reporting

```yaml
name: Tests with Reporting

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      
      - name: Run BATS tests
        run: |
          mkdir -p reports
          ./test/bats/bin/bats --formatter junit --output ./reports test/
        continue-on-error: true
      
      - name: Publish Test Results
        uses: EnricoMi/publish-unit-test-result-action@v2
        if: always()
        with:
          files: reports/*.xml
```

### Multi-Version Testing (Matrix)

```yaml
name: Multi-Version Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        bash-version: ['4.4', '5.0', '5.1', '5.2']
    
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      
      - name: Run tests in Bash ${{ matrix.bash-version }}
        run: |
          docker run --rm -v "$(pwd):/code" bash:${{ matrix.bash-version }} \
            bash -c "cd /code && ./test/bats/bin/bats test/"
```

### With Code Coverage (kcov)

```yaml
name: Tests with Coverage

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      
      - name: Install kcov
        run: |
          sudo apt-get update
          sudo apt-get install -y kcov
      
      - name: Run tests with coverage
        run: |
          mkdir -p coverage
          kcov --include-path=./src coverage/ ./test/bats/bin/bats test/
      
      - name: Upload to Codecov
        uses: codecov/codecov-action@v3
        with:
          directory: ./coverage
```

### Using BATS Action

```yaml
name: Tests with BATS Action

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup BATS
        uses: bats-core/bats-action@1.5.4
        with:
          support-path: test/test_helper/bats-support
          assert-path: test/test_helper/bats-assert
          file-path: test/test_helper/bats-file
      
      - name: Run tests
        run: bats test/
```

---

## GitLab CI

### Basic Configuration

```yaml
# .gitlab-ci.yml
stages:
  - test

test:
  stage: test
  image: bats/bats:latest
  script:
    - bats test/
```

### With JUnit Reports

```yaml
test:
  stage: test
  image: bats/bats:latest
  script:
    - mkdir -p reports
    - bats --formatter junit --output reports/ test/
  artifacts:
    reports:
      junit: reports/*.xml
    when: always
```

### With Coverage

```yaml
test-coverage:
  stage: test
  image: kcov/kcov:latest
  before_script:
    - apt-get update && apt-get install -y bats
  script:
    - kcov --include-path=$(pwd)/src coverage/ bats test/
  coverage: '/Coverage: \d+\.\d+%/'
  artifacts:
    paths:
      - coverage/
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura.xml
```

### Multi-Stage Pipeline

```yaml
stages:
  - lint
  - unit-test
  - integration-test
  - deploy

lint:
  stage: lint
  script:
    - shellcheck src/**/*.sh

unit-test:
  stage: unit-test
  script:
    - bats --filter-tags unit test/

integration-test:
  stage: integration-test
  services:
    - postgres:latest
    - redis:latest
  script:
    - bats --filter-tags integration test/
```

---

## Jenkins

### Pipeline Script

```groovy
pipeline {
    agent any
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'git submodule update --init --recursive'
            }
        }
        
        stage('Test') {
            steps {
                sh './test/bats/bin/bats --formatter junit --output reports test/'
            }
            post {
                always {
                    junit 'reports/*.xml'
                }
            }
        }
    }
}
```

### Parallel Test Execution

```groovy
pipeline {
    agent any
    
    stages {
        stage('Test') {
            parallel {
                stage('Unit Tests') {
                    steps {
                        sh 'bats --filter-tags unit test/'
                    }
                }
                stage('Integration Tests') {
                    steps {
                        sh 'bats --filter-tags integration test/'
                    }
                }
            }
        }
    }
}
```

---

## CircleCI

```yaml
# .circleci/config.yml
version: 2.1

jobs:
  test:
    docker:
      - image: bats/bats:latest
    steps:
      - checkout
      - run:
          name: Run tests
          command: |
            mkdir -p test-results
            bats --formatter junit --output test-results test/
      - store_test_results:
          path: test-results

workflows:
  main:
    jobs:
      - test
```

---

## Azure Pipelines

```yaml
# azure-pipelines.yml
trigger:
  - main

pool:
  vmImage: 'ubuntu-latest'

steps:
  - checkout: self
    submodules: recursive

  - script: |
      ./test/bats/bin/bats --formatter junit --output $(Build.ArtifactStagingDirectory) test/
    displayName: 'Run BATS tests'
    continueOnError: true

  - task: PublishTestResults@2
    inputs:
      testResultsFormat: 'JUnit'
      testResultsFiles: '$(Build.ArtifactStagingDirectory)/*.xml'
    condition: always()
```

---

## Docker-Based Testing

### Dockerfile for Tests

```dockerfile
FROM bats/bats:latest

# Install helper libraries
RUN git clone --depth 1 https://github.com/bats-core/bats-support /opt/bats-support && \
    git clone --depth 1 https://github.com/bats-core/bats-assert /opt/bats-assert && \
    git clone --depth 1 https://github.com/bats-core/bats-file /opt/bats-file

WORKDIR /code

CMD ["bats", "/code/test"]
```

### Docker Compose for Complex Tests

```yaml
# docker-compose.test.yml
version: '3.8'

services:
  test:
    build:
      context: .
      dockerfile: Dockerfile.test
    volumes:
      - .:/code:ro
    depends_on:
      - db
      - redis
    environment:
      - DATABASE_URL=postgres://test:test@db:5432/test
      - REDIS_URL=redis://redis:6379

  db:
    image: postgres:15
    environment:
      POSTGRES_USER: test
      POSTGRES_PASSWORD: test
      POSTGRES_DB: test

  redis:
    image: redis:7
```

Run with: `docker-compose -f docker-compose.test.yml run --rm test`

---

## Makefile Integration

```makefile
.PHONY: test test-unit test-integration test-coverage test-watch

BATS := ./test/bats/bin/bats
BATS_FLAGS := --timing

test: test-unit test-integration

test-unit:
	@echo "Running unit tests..."
	$(BATS) $(BATS_FLAGS) --filter-tags unit test/

test-integration:
	@echo "Running integration tests..."
	$(BATS) $(BATS_FLAGS) --filter-tags integration test/

test-coverage:
	@mkdir -p coverage
	kcov --include-path=src/ coverage/ $(BATS) test/
	@echo "Coverage report: coverage/index.html"

test-parallel:
	$(BATS) $(BATS_FLAGS) --jobs $(shell nproc) test/

test-watch:
	@echo "Watching for changes..."
	@while true; do \
		find src/ test/ -name '*.sh' -o -name '*.bats' | \
		entr -d make test; \
	done

test-ci:
	$(BATS) --formatter junit --output reports/ test/
```

---

## Best Practices

### 1. Fail Fast in CI

```yaml
- name: Run tests
  run: bats --abort test/  # Stop on first failure
```

### 2. Parallel Execution

```yaml
- name: Run tests in parallel
  run: bats --jobs $(nproc) test/
```

### 3. Test Timeouts

```yaml
- name: Run tests with timeout
  run: |
    export BATS_TEST_TIMEOUT=30
    bats test/
  timeout-minutes: 10
```

### 4. Retry Flaky Tests

```yaml
- name: Run tests with retry
  uses: nick-fields/retry@v2
  with:
    max_attempts: 3
    command: bats --filter-tags '!slow' test/
```

### 5. Cache Dependencies

```yaml
- name: Cache BATS libraries
  uses: actions/cache@v3
  with:
    path: test/test_helper
    key: bats-libs-${{ hashFiles('.gitmodules') }}
```

### 6. Conditional Test Execution

```yaml
- name: Run integration tests
  if: github.event_name == 'push' && github.ref == 'refs/heads/main'
  run: bats --filter-tags integration test/
```

---

## Flaky Test Detection

```bash
#!/bin/bash
# detect-flaky.sh - Run in CI to identify flaky tests

RUNS=10
declare -A failures

for i in $(seq 1 $RUNS); do
    echo "Run $i/$RUNS"
    bats --formatter tap test/ 2>/dev/null | grep "^not ok" | while read -r line; do
        test_name=$(echo "$line" | sed 's/^not ok [0-9]* //')
        ((failures["$test_name"]++))
    done
done

echo "=== Flaky Tests ==="
for test in "${!failures[@]}"; do
    rate=$((failures[$test] * 100 / RUNS))
    if [ $rate -gt 0 ] && [ $rate -lt 100 ]; then
        echo "FLAKY ($rate%): $test"
    fi
done
```

---

## Output Formats Summary

| Format | Use Case | Command |
|--------|----------|---------|
| Pretty | Local development | `bats test/` (default in terminal) |
| TAP | Simple CI logs | `bats --tap test/` |
| TAP13 | Extended TAP | `bats --formatter tap13 test/` |
| JUnit | CI dashboards | `bats --formatter junit --output ./reports test/` |

---

## Troubleshooting CI Issues

| Problem | Solution |
|---------|----------|
| Submodules not initialized | Add `submodules: recursive` to checkout |
| Tests pass locally, fail in CI | Check for hardcoded paths, missing dependencies |
| JUnit reports empty | Ensure `--output` directory exists |
| Tests hang in CI | Add `BATS_TEST_TIMEOUT` environment variable |
| Parallel tests fail | Check for shared state, use `$BATS_TEST_TMPDIR` |
