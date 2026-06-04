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
    tmux \
    ncurses-term \
    iputils-ping \
    procps \
    xdg-utils \
    xclip \
    wl-clipboard \
    python3 \
    python-is-python3 \
    python3-pip \
    python3-venv \
    golang-go \
    gcc \
    libc6-dev \
    make \
    cmake \
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
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd

RUN python3 -m pip install --break-system-packages --no-cache-dir \
    basedpyright

RUN command -v python \
    && python --version \
    && command -v basedpyright-langserver

RUN set -e; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
        amd64) hashicorp_arch="amd64" ;; \
        arm64) hashicorp_arch="arm64" ;; \
        *) echo "Unsupported architecture for Terraform tools: $arch" >&2; exit 1 ;; \
    esac; \
    terraform_version="$(curl -fsSL https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r .current_version)"; \
    terraform_ls_version="$(curl -fsSL https://api.github.com/repos/hashicorp/terraform-ls/releases/latest | jq -r '.tag_name | ltrimstr("v")')"; \
    tmpdir="$(mktemp -d)"; \
    curl -fsSL "https://releases.hashicorp.com/terraform/${terraform_version}/terraform_${terraform_version}_linux_${hashicorp_arch}.zip" -o "$tmpdir/terraform.zip"; \
    unzip -q "$tmpdir/terraform.zip" -d "$tmpdir/terraform"; \
    install -m 0755 "$tmpdir/terraform/terraform" /usr/local/bin/terraform; \
    curl -fsSL "https://releases.hashicorp.com/terraform-ls/${terraform_ls_version}/terraform-ls_${terraform_ls_version}_linux_${hashicorp_arch}.zip" -o "$tmpdir/terraform-ls.zip"; \
    unzip -q "$tmpdir/terraform-ls.zip" -d "$tmpdir/terraform-ls"; \
    install -m 0755 "$tmpdir/terraform-ls/terraform-ls" /usr/local/bin/terraform-ls; \
    rm -rf "$tmpdir"; \
    terraform version; \
    terraform-ls version

RUN apt install -y \
    python3-pytest \
    python3-pydantic \
    python3-fastapi

RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
    && apt-get install -y --no-install-recommends nodejs

#ENV BUN_INSTALL="/usr/local/bun"
#ENV PATH="${BUN_INSTALL}/bin:${PATH}"
#RUN curl -fsSL https://bun.com/install | bash \
#    && bun --version \
#    && bunx --version

RUN npm install -g --prefix /usr/local \
    opencode-ai@1.15.13 \
    @ast-grep/cli@latest \
    @biomejs/biome@latest \
    @vue/language-server@latest \
    intelephense@latest \
    playwright@latest \
    typescript@latest \
    typescript-language-server@latest

ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

# Install Playwright browsers with system dependencies (supports both amd64 and arm64)
RUN mkdir -p "${PLAYWRIGHT_BROWSERS_PATH}" \
    && npx playwright install --with-deps chromium \
    && chmod -R a+rX "${PLAYWRIGHT_BROWSERS_PATH}"

RUN rm -rf /var/lib/apt/lists/*

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

ENV PATH="/home/coder/.local/bin:${PATH}"

USER coder
WORKDIR /workspace
ENTRYPOINT ["opencode"]
