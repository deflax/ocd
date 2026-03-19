# Dockerfile for custom OpenCode Isolated Runner
FROM ghcr.io/anomalyco/opencode:latest
LABEL maintainer="Local Code Runner"
LABEL description="Isolated environment for OpenCode"

# Build arguments for user/group IDs (default to 1000)
ARG UID=1000
ARG GID=1000

USER root

# Install core tools
RUN apk add --no-cache \
    ca-certificates \
    curl \
    git \
    bash \
    openssh-client \
    ripgrep \
    unzip \
    fzf \
    iputils-ping \
    procps \
    xdg-utils \
    xclip \
    wl-clipboard \
    # Python
    python3 \
    py3-pip \
    py3-virtualenv \
    # Node.js
    nodejs \
    npm \
    # Go
    go \
    # Build toolchain
    gcc \
    musl-dev \
    make \
    # CLI essentials
    jq \
    yq \
    tree \
    file \
    zip \
    diffutils \
    fd \
    patch \
    tar \
    # glibc compat layer (needed for ast-grep CLI which has no musl binary)
    gcompat \
    gzip \
    && rm -rf /var/cache/apk/*

# Create 'coder' user with configurable UID/GID, handling conflicts
RUN set -e; \
    # Check if GID already exists
    EXISTING_GROUP=$(getent group ${GID} | cut -d: -f1 || echo ""); \
    if [ -z "$EXISTING_GROUP" ]; then \
        # GID is free, create new group
        addgroup -g ${GID} coder; \
        GROUP_NAME="coder"; \
    else \
        # GID exists, check if it's already 'coder'
        if [ "$EXISTING_GROUP" = "coder" ]; then \
            GROUP_NAME="coder"; \
        else \
            # Use existing group and add coder as secondary group
            echo "GID ${GID} exists as '$EXISTING_GROUP', creating coder group with auto GID"; \
            addgroup coder; \
            GROUP_NAME="coder"; \
        fi; \
    fi; \
    # Check if UID already exists
    EXISTING_USER=$(getent passwd ${UID} | cut -d: -f1 || echo ""); \
    if [ -z "$EXISTING_USER" ]; then \
        # UID is free, create new user
        adduser -D -u ${UID} -G ${GROUP_NAME} -h /home/coder -s /bin/bash coder; \
    else \
        # UID exists
        if [ "$EXISTING_USER" = "coder" ]; then \
            echo "User 'coder' already exists with UID ${UID}"; \
        else \
            echo "UID ${UID} exists as '$EXISTING_USER', creating coder with auto UID"; \
            adduser -D -G ${GROUP_NAME} -h /home/coder -s /bin/bash coder; \
        fi; \
    fi; \
    # If we used an existing system group, add coder to it
    if [ -n "$EXISTING_GROUP" ] && [ "$EXISTING_GROUP" != "coder" ]; then \
        addgroup coder ${EXISTING_GROUP}; \
    fi

# Install oh-my-opencode plugin globally
# --ignore-scripts: @ast-grep/cli postinstall fails on Alpine/musl (no musl binary published)
RUN npm install -g oh-my-opencode@latest --ignore-scripts

# Install language servers
RUN npm install -g @vue/language-server @biomejs/biome

RUN python3 -m pip install --break-system-packages --no-cache-dir \
    basedpyright \
    pytest \
    pydantic \
    fastapi

ENV PATH="/home/coder/.local/bin:${PATH}"

# Install ast-grep CLI manually from GitHub releases (glibc binary via gcompat)
ARG AST_GREP_VERSION=0.41.0
RUN set -e; \
    ARCH="$(uname -m)"; \
    case "$ARCH" in \
        x86_64) TARGET="x86_64-unknown-linux-gnu" ;; \
        aarch64) TARGET="aarch64-unknown-linux-gnu" ;; \
        *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/ast-grep/ast-grep/releases/download/${AST_GREP_VERSION}/app-${TARGET}.zip" -o /tmp/ast-grep.zip && \
    unzip -o /tmp/ast-grep.zip -d /tmp/ast-grep && \
    install -m 755 "$(find /tmp/ast-grep -name 'sg' -type f | head -1)" /usr/local/bin/sg && \
    ln -sf /usr/local/bin/sg /usr/local/bin/ast-grep && \
    rm -rf /tmp/ast-grep /tmp/ast-grep.zip

USER coder
WORKDIR /workspace
