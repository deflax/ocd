# Dockerfile for custom OpenCode Isolated Runner
FROM ghcr.io/anomalyco/opencode:latest

LABEL maintainer="Local Code Runner"
LABEL description="Isolated environment for OpenCode"

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

# Create 'coder' user with UID=1000 to match the host user
RUN addgroup -g 1000 coder && \
    adduser -D -u 1000 -G coder -h /home/coder -s /bin/bash coder

USER coder

WORKDIR /workspace
