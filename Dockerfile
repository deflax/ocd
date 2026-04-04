# Dockerfile for custom OpenCode Isolated Runner
FROM debian:trixie-slim
LABEL maintainer="Local Code Runner"
LABEL description="Isolated environment for OpenCode"

# Build arguments for user/group IDs (default to 1000)
ARG UID=1000
ARG GID=1000

USER root

# Install core tools
RUN apt-get update && apt-get install -y --no-install-recommends \
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
    python3-pip \
    python3-venv \
    # Node.js
    nodejs \
    npm \
    # Go
    golang-go \
    # Build toolchain
    gcc \
    libc6-dev \
    make \
    # CLI essentials
    jq \
    yq \
    tree \
    file \
    zip \
    diffutils \
    fd-find \
    patch \
    tar \
    gzip \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd

ENV OPENCODE_INSTALL_DIR=/usr/local/bin
RUN curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path \
    && command -v opencode >/dev/null

# Create 'coder' user with configurable UID/GID, handling conflicts
RUN set -e; \
    EXISTING_GROUP=$(getent group ${GID} | cut -d: -f1 || echo ""); \
    if [ -z "$EXISTING_GROUP" ]; then \
        groupadd -g ${GID} coder; \
        GROUP_NAME="coder"; \
    else \
        if [ "$EXISTING_GROUP" = "coder" ]; then \
            GROUP_NAME="coder"; \
        else \
            echo "GID ${GID} already exists as '$EXISTING_GROUP'; refusing to create mismatched primary group for coder" >&2; \
            exit 1; \
        fi; \
    fi; \
    EXISTING_USER=$(getent passwd ${UID} | cut -d: -f1 || echo ""); \
    if [ -z "$EXISTING_USER" ]; then \
        useradd -m -u ${UID} -g ${GROUP_NAME} -s /bin/bash coder; \
    else \
        if [ "$EXISTING_USER" = "coder" ]; then \
            echo "User 'coder' already exists with UID ${UID}"; \
        else \
            echo "UID ${UID} already exists as '$EXISTING_USER'; refusing to create coder with a different UID" >&2; \
            exit 1; \
        fi; \
    fi

# Install oh-my-opencode plugin globally
RUN npm install -g oh-my-opencode@latest --ignore-scripts

# Install Claude Code CLI and opencode-claude-auth plugin
RUN npm install -g @anthropic-ai/claude-code opencode-claude-auth

# Install language servers
RUN npm install -g @vue/language-server @biomejs/biome

RUN python3 -m pip install --break-system-packages --no-cache-dir \
    basedpyright \
    pytest \
    pydantic \
    fastapi

ENV PATH="/home/coder/.local/bin:${PATH}"

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
ENTRYPOINT ["opencode"]
