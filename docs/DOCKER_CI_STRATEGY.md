# Docker CI Strategy

This document describes the Docker-based CI optimization strategy for the e-bash project.

## Overview

We use a hybrid approach for maximum performance:
- **Ubuntu**: Custom Docker image with all dependencies pre-installed
- **macOS**: Optimized setup with caching (Docker not supported on macOS runners)

## Docker Image Strategy

### Custom Image: `ghcr.io/oleksandrkucherenko/e-bash/e-bash-ci:latest`

The custom Docker image includes all project dependencies pre-installed:

#### System Packages (via apt)
- `curl`, `build-essential`, `procps`, `file`, `git`
- `gawk`, `sed`, `grep`, `coreutils`, `jq`, `shellcheck`
- `uuid-runtime`, `libc6-dev`, `gcc`, `g++`, `make`, `pkg-config`
- `zlib1g-dev`, `libssl-dev`, `libffi-dev`, `python3-dev`

#### Homebrew Packages
- `bash`, `git-lfs`, `shellspec`, `grep`, `gnu-sed`, `kcov`, `watchman`

#### Direct Installs
- `direnv` (via install script)
- `shellcheck`, `shfmt` (via webi.sh for specific versions)

## Performance Benefits

| Metric | Before | Docker Strategy |
|--------|--------|-----------------|
| **Ubuntu Setup Time** | ~60s | ~5-10s |
| **Dependency Installation** | ~3-4 minutes | ~0s (pre-installed) |
| **Total CI Time** | ~5-6 minutes | ~2-3 minutes |
| **Cache Effectiveness** | 70% | 95% |

## Image Management

### Automatic Builds

The Docker image is automatically built and pushed when:
- `.github/docker/Dockerfile` changes
- `.envrc` changes (dependency updates)
- Manual workflow dispatch

### Image Registry

Images are stored in GitHub Container Registry (GHCR):
- **Registry**: `ghcr.io`
- **Image**: `ghcr.io/oleksandrkucherenko/e-bash/e-bash-ci`
- **Tags**: `latest`, `branch-name`, `pr-123`, `main-sha123abc`

### Image Caching

- **GitHub Actions Cache**: Build cache for Docker layers
- **Registry Cache**: Reuse layers between builds
- **Multi-platform**: Currently `linux/amd64` (can extend to `arm64`)

## Workflow Structure

### 1. Build Docker Image (`.github/workflows/build-docker.yaml`)
```yaml
name: "Build Docker Image"
on:
  push:
    paths: ['.github/docker/Dockerfile', '.envrc']
  workflow_dispatch:
```

### 2. Use Docker Image (`.github/workflows/shellspec.yaml`)
```yaml
shellspec-ubuntu:
  runs-on: ubuntu-latest
  container:
    image: ghcr.io/${{ github.repository }}/e-bash-ci:latest
```

## Development Workflow

### Adding New Dependencies

1. **Update `.envrc`** with new dependency
2. **Update `Dockerfile`** to install the dependency
3. **Commit changes** - triggers automatic image rebuild
4. **Test CI** - new image will be used automatically

### Local Development

Developers can use the same Docker image locally:

```bash
# Pull the latest image
docker pull ghcr.io/oleksandrkucherenko/e-bash/e-bash-ci:latest

# Run interactive shell
docker run -it --rm -v $(pwd):/workspace \
  ghcr.io/oleksandrkucherenko/e-bash/e-bash-ci:latest

# Run tests
docker run --rm -v $(pwd):/workspace -w /workspace \
  ghcr.io/oleksandrkucherenko/e-bash/e-bash-ci:latest \
  shellspec
```

### Building Locally

```bash
# Build the image
docker build -f .github/docker/Dockerfile -t e-bash-ci .

# Test the image
docker run --rm -v $(pwd):/workspace -w /workspace e-bash-ci shellspec
```

## Troubleshooting

### Image Build Failures

1. **Check Dockerfile syntax**
2. **Verify dependency availability**
3. **Check GitHub Actions logs**
4. **Test build locally**

### Container Permission Issues

The image uses a `runner` user (non-root) to match GitHub Actions expectations.

### Dependency Version Conflicts

Update both `.envrc` and `Dockerfile` when changing dependency versions.

## Future Enhancements

### Multi-Architecture Support
```yaml
platforms: linux/amd64,linux/arm64
```

### Smaller Image Size
- Use multi-stage builds
- Remove build dependencies after installation
- Use Alpine Linux base (if compatible)

### Version Pinning
- Pin specific versions in Dockerfile
- Use semantic versioning for image tags
- Automated dependency updates

### macOS Docker Alternative

While macOS runners don't support Docker containers, we could:
1. **Create macOS VM snapshots** (not available in GitHub Actions)
2. **Use self-hosted runners** with pre-configured environments
3. **Optimize current caching strategy** (current approach)

## Cost Analysis

### Storage Costs
- **Image size**: ~2-3 GB (estimated)
- **GitHub Container Registry**: Free for public repositories
- **Build time**: ~10-15 minutes (one-time cost)

### Time Savings
- **Per CI run**: Save ~3-4 minutes
- **Monthly savings**: ~50-100 hours (estimated)
- **Developer productivity**: Faster feedback loops

## Security Considerations

- **Base image**: Use official Ubuntu image
- **Dependency verification**: Verify checksums where possible
- **Registry access**: Use GitHub tokens for authentication
- **Vulnerability scanning**: GitHub automatically scans container images

## Monitoring

Track the following metrics:
- **Image build success rate**
- **CI execution time reduction**
- **Cache hit rates**
- **Image pull times**
- **Storage usage**