# Custom Ubuntu image with e-bash dependencies pre-installed
FROM ubuntu:22.04

# Set environment variables for non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive
ENV CI=true

# Install system dependencies and tools available via apt
RUN apt-get update -qq && \
    apt-get install -y -qq \
    curl \
    wget \
    build-essential \
    procps \
    file \
    git \
    git-lfs \
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
    lsb-release \
    bash \
    unzip && \
    rm -rf /var/lib/apt/lists/*

# Install direnv
RUN mkdir -p ~/.local/bin && \
    curl -sfL https://direnv.net/install.sh | bash && \
    mv ~/.local/bin/direnv /usr/local/bin/

# Install shfmt (shellcheck already installed via apt)
RUN mkdir -p ~/.local/bin && \
    curl -sS https://webi.sh/shfmt | sh && \
    mv ~/.local/bin/shfmt /usr/local/bin/

# Install shellspec
RUN curl -fsSL https://git.io/shellspec | sh -s -- --yes && \
    ln -sf ~/.local/lib/shellspec/shellspec /usr/local/bin/shellspec

# Install GNU grep and sed (for compatibility with .envrc)
RUN apt-get update -qq && \
    apt-get install -y -qq \
    grep \
    sed && \
    rm -rf /var/lib/apt/lists/*

# Install kcov for coverage (if needed)
RUN apt-get update -qq && \
    apt-get install -y -qq \
    cmake \
    libcurl4-openssl-dev \
    libelf-dev \
    libdw-dev \
    binutils-dev && \
    git clone https://github.com/SimonKagstrom/kcov.git /tmp/kcov && \
    cd /tmp/kcov && \
    mkdir build && cd build && \
    cmake .. && make && make install && \
    cd / && rm -rf /tmp/kcov && \
    rm -rf /var/lib/apt/lists/*

# Install watchman (Facebook's file watching service)
RUN cd /tmp && \
    wget https://github.com/facebook/watchman/releases/download/v2023.11.20.00/watchman-v2023.11.20.00-linux.zip && \
    unzip watchman-v2023.11.20.00-linux.zip && \
    cp watchman-v2023.11.20.00-linux/bin/* /usr/local/bin/ && \
    cp watchman-v2023.11.20.00-linux/lib/* /usr/local/lib/ && \
    rm -rf watchman-*

# Create symbolic links for GNU tools (matching .envrc expectations)
RUN mkdir -p /usr/local/bin/gnu && \
    ln -sf /usr/bin/grep /usr/local/bin/gnu/ggrep && \
    ln -sf /usr/bin/sed /usr/local/bin/gnu/gsed && \
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
RUN echo "=== Verifying installations ===" && \
    bash --version && \
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
    watchman --version && \
    echo "=== All tools verified ==="

# Set default command
CMD ["/bin/bash"]