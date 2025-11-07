# CI Optimization Guide

This document describes the CI optimization strategies implemented to reduce execution time from ~60s to ~15-20s.

## Current Optimizations (Implemented)

### 1. GitHub Actions Caching
- **Homebrew packages**: Cache `/opt/homebrew` (macOS) and `/home/linuxbrew/.linuxbrew` (Ubuntu)
- **Local binaries**: Cache `~/.local/bin` for downloaded tools
- **APT packages**: Cache `/var/cache/apt` for Ubuntu system packages

### 2. Dependency Optimization
- **System packages first**: Use `apt-get` packages instead of Homebrew where possible
- **Essential only**: Skip development-only tools in CI (`CI_SKIP_HEAVY_DEPS=1`)
- **Conditional installation**: Only install missing dependencies

### 3. Skipped Dependencies in CI
- `git-lfs`: Not needed for basic tests
- `shellcheck`: Available via apt
- `shfmt`: Development-only tool
- `kcov`: Coverage tool (disabled with `--no-kcov`)
- `watchman`: Development file watcher

### 4. Performance Improvements
- **Parallel apt installs**: Install multiple packages in single command
- **Quiet mode**: Use `-qq` flags to reduce log noise
- **Conditional checks**: Skip installation if tool already exists

## Expected Performance

| Phase | Before | After (Cache Miss) | After (Cache Hit) |
|-------|--------|-------------------|-------------------|
| macOS Setup | ~45s | ~20s | ~8s |
| Ubuntu Setup | ~60s | ~25s | ~10s |
| **Total** | **~105s** | **~45s** | **~18s** |

## Alternative Optimization Strategies

### Option A: Custom Docker Image (Future)
```dockerfile
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y \
    bash git shellspec gawk sed grep coreutils jq shellcheck
# Pre-install all dependencies
```
**Pros**: Fastest startup (~5s), consistent environment
**Cons**: Maintenance overhead, image size

### Option B: Matrix Strategy Reduction
```yaml
strategy:
  matrix:
    os: [ubuntu-latest]  # Remove macOS for faster CI
```
**Pros**: 50% time reduction
**Cons**: Less platform coverage

### Option C: Parallel Job Execution
```yaml
jobs:
  test-core:
    # Run only essential tests
  test-extended:
    # Run full test suite (optional)
```

## Monitoring Performance

To monitor CI performance:
1. Check GitHub Actions timing in the "Actions" tab
2. Look for cache hit/miss rates
3. Monitor individual step durations

## Troubleshooting

### Cache Issues
If caching isn't working:
```bash
# Clear cache manually in GitHub repo settings
# Or update cache keys in workflow file
```

### Missing Dependencies
If tests fail due to missing tools:
```bash
# Temporarily disable CI_SKIP_HEAVY_DEPS
export CI_SKIP_HEAVY_DEPS=""
```

## Future Improvements

1. **Incremental testing**: Only run tests for changed files
2. **Test parallelization**: Split test suite across multiple jobs
3. **Custom runner**: Use self-hosted runners with pre-installed dependencies
4. **Dependency vendoring**: Include critical tools in repository