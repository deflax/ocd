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
    python3 \
    python3-pip \
    python3-venv \
    golang-go \
    gcc \
    libc6-dev \
    make \
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

RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g --prefix /usr/local \
    opencode-ai@1.4.3 \
    @anthropic-ai/claude-code@2.1.100 \
    @ast-grep/cli \
    @biomejs/biome \
    @vue/language-server \
    intelephense \
    playwright \
    typescript \
    typescript-language-server

# Install Playwright browsers with system dependencies (supports both amd64 and arm64)
RUN npx playwright install --with-deps chromium \
    && rm -rf /var/lib/apt/lists/*

# Create 'coder' user with configurable UID/GID, handling conflicts
# On macOS, GID 20 (staff) maps to 'dialout' inside Debian — reuse the existing group
RUN set -e; \
    EXISTING_GROUP=$(getent group ${GID} | cut -d: -f1 || echo ""); \
    if [ -z "$EXISTING_GROUP" ]; then \
        groupadd -g ${GID} coder; \
        GROUP_NAME="coder"; \
    else \
        GROUP_NAME="$EXISTING_GROUP"; \
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

RUN python3 -m pip install --break-system-packages --no-cache-dir \
    basedpyright==1.39.0 \
    pytest==9.0.2 \
    pydantic==2.12.5 \
    fastapi==0.135.3

ENV PATH="/home/coder/.local/bin:${PATH}"

USER coder
WORKDIR /workspace
ENTRYPOINT ["opencode"]
