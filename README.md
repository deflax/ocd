# Local Isolated Code Runner

Run OpenCode inside a Docker container with sandboxed file access and security hardening.

## Features

- Runs OpenCode in an isolated Docker container
- Mounts your current working directory as `/workspace`
- Persistent home directory and configuration across sessions
- Security hardening (dropped capabilities, no-new-privileges)
- Pre-installed tools: git, ripgrep, fzf, curl, and more
- [Claude Code CLI](https://github.com/anthropics/claude-code) with OAuth support via [opencode-claude-auth](https://github.com/griffinmartin/opencode-claude-auth)
- [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode) plugin for multi-agent orchestration

## Quick Start

1. **Build the image:**
   ```bash
   ./build
   ```

2. **Set up Claude authentication (first time only):**
   ```bash
   ./claude-auth
   ```
   This starts a temporary container and runs `claude auth login`. It will print a URL — open it in your browser, authorize, and paste the code back into the terminal. Credentials are saved to `data/.claude/.credentials.json` and persist across container restarts.

   See [Claude Code Authentication](#claude-code-authentication) for details.

3. **Run the container:**
   ```bash
   ./ocd
   ```
   This starts a new container for each run with your current directory mounted as the workspace.

4. **Run from any directory (optional):**
   
   Create a symlink to run `ocd` from anywhere:
   ```bash
   ln -s "$(pwd)/ocd" ~/.local/bin/ocd
   ```
   
   Make sure `~/.local/bin` is in your PATH. Then you can run `ocd` from any project directory.

## Configuration

- OpenCode config is stored in `config/opencode.json`
- Persistent user data is stored in `data/`
- Claude authentication is managed via `./claude-auth` (see below)

### Local Config Overrides

To add sensitive or personal settings without committing them to the repo, create a `config/opencode.local.json` file with only the fields you want to override:

```json
{
  "provider": {
    "apiKey": "sk-secret-key"
  }
}
```

On startup, `ocd` will deep merge `opencode.local.json` on top of the base `opencode.json` using `jq`. Nested objects are merged recursively — you only need to specify the fields you want to change. The merged result is written to `config/opencode.merged.json` (gitignored) and mounted read-only into the container.

If no `opencode.local.json` exists, the base `opencode.json` is used as-is.

### X11 Clipboard Support

If `/tmp/.X11-unix` exists on the host, it is automatically mounted into the container (read-only) along with the `DISPLAY` environment variable. This enables X11-based clipboard sharing between the host and container. If the directory doesn't exist (e.g. on Wayland-only or macOS hosts), it is simply skipped.

### Claude Code Authentication

The container includes [Claude Code CLI](https://github.com/anthropics/claude-code) and the [opencode-claude-auth](https://github.com/griffinmartin/opencode-claude-auth) plugin, which lets OpenCode use your Claude subscription (Pro/Team/Enterprise) via OAuth tokens.

**First-time setup:**

```bash
./claude-auth
```

This spins up a temporary container, runs `claude auth login`, and walks you through the OAuth flow:

1. A URL is printed in the terminal
2. Open the URL in your browser and authorize
3. Paste the code back into the terminal
4. Credentials are saved to `data/.claude/.credentials.json`

**Other commands:**

```bash
./claude-auth status   # Check if credentials are valid
./claude-auth logout   # Remove credentials
```

**How it works:** The `opencode-claude-auth` plugin reads OAuth tokens from `~/.claude/.credentials.json` (which maps to `data/.claude/.credentials.json` on the host), injects them into OpenCode's API requests, and auto-refreshes tokens when they near expiry by invoking the `claude` CLI.

**Credential persistence:** Since `data/` is mounted as the container's home directory, credentials survive container restarts. No additional volume mounts are needed.

**Alternative — API key auth:** If you have an Anthropic API key and don't need subscription-based OAuth, set `OPENCODE_API_KEY` in your environment. The plugin becomes a no-op and falls through to standard API key auth.

### oh-my-opencode

The [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode) plugin is pre-installed in the Docker image and provides multi-agent orchestration (Sisyphus, Hephaestus, Oracle, Librarian, etc.), background agents, LSP/AST tools, and the `ultrawork` command.

Agent model assignments are configured in `config/oh-my-opencode.json`. Like the main config, you can create `config/oh-my-opencode.local.json` for personal overrides (gitignored).

## Directory Structure

```
.
├── build           # Script to build the Docker image
├── ocd             # Script to run the container
├── claude-auth     # Script to manage Claude Code authentication
├── clearcache      # Script to clear caches (preserves credentials)
├── config/         # OpenCode configuration
│   ├── opencode.json              # Base config (committed)
│   ├── opencode.local.json        # Local overrides (gitignored, optional)
│   ├── opencode.merged.json       # Merged result (gitignored, auto-generated)
│   ├── oh-my-opencode.json        # oh-my-opencode config (committed)
│   ├── oh-my-opencode.local.json  # oh-my-opencode local overrides (gitignored, optional)
│   └── oh-my-opencode.merged.json # oh-my-opencode merged result (gitignored, auto-generated)
├── data/           # Persistent home directory (mounted to /home/coder)
│   └── .claude/    # Claude Code data (credentials, transcripts)
└── Dockerfile      # Container definition
```

## How It Works

The `ocd` script:
- Builds and runs the `ocd:latest` Docker image
- Generates a unique container name per run (for example `ocd-20260318-120001-12345`)
- Mounts your current directory to `/workspace` inside the container
- Mounts OpenCode and oh-my-opencode config files to `/config` and sets both `OPENCODE_CONFIG` and `OPENCODE_CONFIG_DIR=/config`
- Applies security restrictions (dropped capabilities, no-new-privileges)

## Self-Hosted Model Configuration

When using self-hosted models via Ollama, you may need to increase the context window size. The default context window (typically 2048-4096 tokens) is often too small for coding tasks that require analyzing multiple files or large codebases.

**Creating a model with a larger context window:**

```bash
$ ollama run qwen3:8b
>>> /set parameter num_ctx 16384
Set parameter 'num_ctx' to '16384'
>>> /save qwen3:8b-16k
Created new model 'qwen3:8b-16k'
>>> /bye
```

**Recommended context window sizes:**
- `8192` - Suitable for small projects and single-file tasks
- `16384` - Good balance for most coding tasks
- `32768` - Recommended for larger codebases or multi-file refactoring

**Note:** Larger context windows require more VRAM. A 16K context window typically needs ~2-4GB additional VRAM compared to the default. Monitor your GPU memory usage and adjust accordingly.
