# Dockerfile for custom OpenCode Isolated Runner
FROM ghcr.io/anomalyco/opencode:latest
LABEL maintainer="Local Code Runner"
LABEL description="Isolated environment for OpenCode"

# Build arguments for user/group IDs (default to 1000)
ARG UID=1000
ARG GID=1000

USER root

# Install additional tools
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
    && rm -rf /var/lib/apt/lists/*

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

USER coder
WORKDIR /workspace
