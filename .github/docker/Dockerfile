# Custom Ubuntu image with e-bash dependencies pre-installed
FROM ubuntu:22.04

# Set environment variables for non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive
ENV HOMEBREW_NO_AUTO_UPDATE=1
ENV HOMEBREW_NO_INSTALL_CLEANUP=1
ENV HOMEBREW_NO_ENV_HINTS=1
ENV CI=true

# Install system dependencies
RUN apt-get update -qq && \
    apt-get install -y -qq \
    curl \
    build-essential \
    procps \
    file \
    git \
    gawk \
    sed \
    grep \
    coreutils \
    jq \
    shellcheck \
    uuid-runtime \
    libc6-dev \
    gcc \
    g++ \
    make \
    pkg-config \
    zlib1g-dev \
    libssl-dev \
    libffi-dev \
    python3-dev \
    python3-pip \
    ca-certificates \
    gnupg \
    lsb-release && \
    rm -rf /var/lib/apt/lists/*

# Install Homebrew
RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Set up Homebrew environment
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"
ENV HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
ENV HOMEBREW_CELLAR="/home/linuxbrew/.linuxbrew/Cellar"
ENV HOMEBREW_REPOSITORY="/home/linuxbrew/.linuxbrew/Homebrew"

# Install Homebrew dependencies that aren't available via apt or need specific versions
RUN brew install \
    bash \
    git-lfs \
    shellspec \
    grep \
    gnu-sed \
    kcov \
    watchman && \
    brew cleanup

# Install direnv
RUN mkdir -p ~/.local/bin && \
    curl -sfL https://direnv.net/install.sh | bash && \
    mv ~/.local/bin/direnv /usr/local/bin/

# Install shellcheck and shfmt via webi (specific versions)
RUN mkdir -p ~/.local/bin && \
    curl -sS https://webi.sh/shellcheck | sh && \
    curl -sS https://webi.sh/shfmt | sh && \
    mv ~/.local/bin/shellcheck /usr/local/bin/ && \
    mv ~/.local/bin/shfmt /usr/local/bin/

# Create symbolic links for GNU tools (matching .envrc expectations)
RUN mkdir -p /usr/local/bin/gnu && \
    ln -sf /home/linuxbrew/.linuxbrew/bin/ggrep /usr/local/bin/gnu/ggrep && \
    ln -sf /home/linuxbrew/.linuxbrew/bin/gsed /usr/local/bin/gnu/gsed && \
    ln -sf /usr/bin/gawk /usr/local/bin/gnu/gawk && \
    ln -sf /usr/bin/timeout /usr/local/bin/gnu/timeout

# Set up PATH to include all tools
ENV PATH="/usr/local/bin/gnu:/usr/local/bin:$PATH"

# Create a non-root user for GitHub Actions
RUN useradd -m -s /bin/bash runner && \
    echo 'runner ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER runner
WORKDIR /home/runner

# Verify installations
RUN bash --version && \
    git --version && \
    direnv version && \
    shellspec --version && \
    shellcheck --version && \
    shfmt --version && \
    ggrep --version && \
    gsed --version && \
    gawk --version && \
    jq --version && \
    kcov --version && \
    watchman --version

# Set default command
CMD ["/bin/bash"]