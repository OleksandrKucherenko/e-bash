#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-11-07
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# Docker development helper script for e-bash project

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly IMAGE_NAME="ghcr.io/oleksandrkucherenko/e-bash/e-bash-ci:latest"
readonly LOCAL_IMAGE_NAME="e-bash-ci"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

usage() {
    cat << EOF
Docker Development Helper for e-bash

Usage: $0 <command> [options]

Commands:
    build           Build the Docker image locally
    pull            Pull the latest image from registry
    shell           Start interactive shell in container
    test            Run shellspec tests in container
    verify          Verify all dependencies in container
    clean           Remove local Docker images
    help            Show this help message

Examples:
    $0 build                    # Build image locally
    $0 shell                    # Interactive development
    $0 test                     # Run tests
    $0 test --example "test-051" # Run specific test

Environment Variables:
    DOCKER_IMAGE    Override default image name
    NO_PULL         Skip pulling latest image (use local)

EOF
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed or not in PATH"
        exit 1
    fi
}

build_image() {
    log "Building Docker image locally..."
    cd "$PROJECT_ROOT"
    
    docker build \
        -f .github/docker/Dockerfile \
        -t "$LOCAL_IMAGE_NAME" \
        .
    
    log "Image built successfully: $LOCAL_IMAGE_NAME"
}

pull_image() {
    log "Pulling latest image from registry..."
    
    if docker pull "$IMAGE_NAME"; then
        log "Image pulled successfully"
    else
        warn "Failed to pull image from registry"
        warn "You may need to authenticate with: docker login ghcr.io"
        return 1
    fi
}

get_image() {
    local image_to_use="$IMAGE_NAME"
    
    if [[ "${NO_PULL:-}" == "1" ]]; then
        image_to_use="$LOCAL_IMAGE_NAME"
        log "Using local image: $image_to_use"
    else
        if ! pull_image; then
            warn "Falling back to local image"
            image_to_use="$LOCAL_IMAGE_NAME"
        fi
    fi
    
    echo "$image_to_use"
}

run_shell() {
    local image
    image=$(get_image)
    
    log "Starting interactive shell..."
    log "Project mounted at: /workspace"
    
    docker run -it --rm \
        -v "$PROJECT_ROOT:/workspace" \
        -w /workspace \
        "$image" \
        /bin/bash
}

run_tests() {
    local image
    image=$(get_image)
    
    log "Running shellspec tests..."
    
    # Pass through any additional arguments to shellspec
    docker run --rm \
        -v "$PROJECT_ROOT:/workspace" \
        -w /workspace \
        "$image" \
        shellspec "$@"
}

verify_dependencies() {
    local image
    image=$(get_image)
    
    log "Verifying dependencies in container..."
    
    docker run --rm \
        -v "$PROJECT_ROOT:/workspace" \
        -w /workspace \
        "$image" \
        bash -c '
            echo "=== Dependency Verification ==="
            echo "Bash: $(bash --version | head -1)"
            echo "Git: $(git --version)"
            echo "Direnv: $(direnv version)"
            echo "Shellspec: $(shellspec --version)"
            echo "Shellcheck: $(shellcheck --version | head -1)"
            echo "Shfmt: $(shfmt --version)"
            echo "GNU Grep: $(ggrep --version | head -1)"
            echo "GNU Sed: $(gsed --version | head -1)"
            echo "GNU Awk: $(gawk --version | head -1)"
            echo "JQ: $(jq --version)"
            echo "Kcov: $(kcov --version | head -1)"
            echo "Watchman: $(watchman --version)"
            echo "=== All dependencies verified ==="
        '
}

clean_images() {
    log "Cleaning up Docker images..."
    
    # Remove local images
    docker rmi "$LOCAL_IMAGE_NAME" 2>/dev/null || true
    docker rmi "$IMAGE_NAME" 2>/dev/null || true
    
    # Clean up dangling images
    docker image prune -f
    
    log "Cleanup completed"
}

main() {
    check_docker
    
    case "${1:-help}" in
        build)
            build_image
            ;;
        pull)
            pull_image
            ;;
        shell)
            run_shell
            ;;
        test)
            shift
            run_tests "$@"
            ;;
        verify)
            verify_dependencies
            ;;
        clean)
            clean_images
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            error "Unknown command: $1"
            usage
            exit 1
            ;;
    esac
}

main "$@"