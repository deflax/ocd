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

# Create 'coder' user with configurable UID/GID to match the host user
RUN addgroup -g ${GID} coder && \
    adduser -D -u ${UID} -G coder -h /home/coder -s /bin/bash coder

USER coder

WORKDIR /workspace
