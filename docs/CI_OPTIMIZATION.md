# CI Optimization Guide

This document describes the CI optimization strategies implemented to reduce execution time from ~60s to ~5-10s.

## Current Optimizations (Implemented)

### 0. Docker Strategy (Latest - Recommended)
- **Custom Docker Image**: Pre-built Ubuntu image with all dependencies
- **GitHub Container Registry**: Cached and versioned images
- **Instant Setup**: ~5-10s vs ~60s for dependency installation
- **See**: [Docker CI Strategy](DOCKER_CI_STRATEGY.md) for full details

### 1. GitHub Actions Caching
- **Homebrew packages**: Cache `/opt/homebrew` (macOS) and `/home/linuxbrew/.linuxbrew` (Ubuntu)
- **Local binaries**: Cache `~/.local/bin` for downloaded tools
- **APT packages**: Cache `/var/cache/apt` for Ubuntu system packages

### 2. Dependency Optimization
- **System packages first**: Use `apt-get` packages instead of Homebrew where possible
- **Parallel installation**: Install dependencies in background processes
- **Pre-install common libraries**: Install build dependencies that Homebrew packages need
- **Conditional installation**: Only install missing dependencies

### 3. System Package Strategy
- **Ubuntu**: Use `apt-get` for: `gawk`, `sed`, `grep`, `coreutils`, `jq`, `shellcheck`
- **macOS**: Use Homebrew but install in parallel
- **Build dependencies**: Pre-install `gcc`, `make`, `zlib-dev`, `libssl-dev` to speed up Homebrew

### 4. Performance Improvements
- **Parallel installation**: Use background processes (`&`) and `wait`
- **Quiet mode**: Use `-qq` flags to reduce log noise
- **NONINTERACTIVE mode**: Skip Homebrew prompts
- **Pre-install build tools**: Reduce compilation time for Homebrew packages

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