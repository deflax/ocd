# Local Isolated Code Runner

Run OpenCode inside a Docker container with sandboxed file access and security hardening.

## Features

- Runs OpenCode in an isolated Docker container
- Mounts your current working directory as `/workspace`
- Persistent home directory and configuration across sessions
- Security hardening (dropped capabilities, no-new-privileges)
- Pre-installed tools: git, ripgrep, fzf, curl, and more
- [Claude Code](https://github.com/anthropics/claude-code) OAuth token support (use your Pro/Max subscription)
- [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode) plugin for multi-agent orchestration

## Quick Start

1. **Build the image:**
   ```bash
   ./build
   ```

2. **Set up Claude authentication (first time only):**
   ```bash
   ./claude-auth setup-token
   ```
   This generates a long-lived OAuth token (~1 year). If the `claude` CLI is installed on your host, it opens a browser for authorization. Otherwise, follow the instructions to install it or run it inside the container. Paste the token when prompted — it's saved to `.claude-token` and injected into every container run.

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

Use your Claude Pro/Max/Team subscription with OpenCode via a long-lived OAuth token.

**Setup (one-time, runs on your host machine):**

```bash
./claude-auth setup-token
```

This runs `claude setup-token` on your host (via local install or `npx`), opens a browser for authorization, and saves the token to `.claude-token`. The `ocd` script passes it into the container as `CLAUDE_CODE_OAUTH_TOKEN`.

You can also set the env var directly:
```bash
export CLAUDE_CODE_OAUTH_TOKEN="sk-ant-oat01-..."
./ocd
```

**Other commands:**

```bash
./claude-auth status   # Check if token exists
./claude-auth logout   # Remove token
```

**How it works:** The `ocd` script reads `.claude-token` (or the `CLAUDE_CODE_OAUTH_TOKEN` env var) and seeds `data/.claude/.credentials.json` before launching the container. Inside the container, the [opencode-claude-auth](https://github.com/griffinmartin/opencode-claude-auth) plugin reads these credentials and injects OAuth Bearer authentication into all Anthropic API requests. The Claude Code CLI (also installed in the image) handles token refresh when needed. The token is valid for ~1 year.

**Alternative — API key auth:** If you have an Anthropic API key and don't need subscription-based OAuth, set `OPENCODE_API_KEY` in your environment.

### oh-my-opencode

The [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode) plugin is pre-installed in the Docker image and provides multi-agent orchestration (Sisyphus, Hephaestus, Oracle, Librarian, etc.), background agents, LSP/AST tools, and the `ultrawork` command.

Agent model assignments are configured in `config/oh-my-opencode.json`. Like the main config, you can create `config/oh-my-opencode.local.json` for personal overrides (gitignored).

### Model Profiles

The `ocd` script supports switching between different oh-my-opencode model configurations using the `--profile` flag:

```bash
./ocd --profile anthropic    # Use Anthropic Claude models
./ocd                        # Use default minimax models
```

**Available profiles:**

| Profile | Description |
|---------|-------------|
| (default) | Uses MiniMax models for most agents |
| `anthropic` | Uses Anthropic Claude models (requires Claude Code OAuth or API key) |

To create a new profile, copy `config/oh-my-opencode.json` to `config/oh-my-opencode.<profile>.json` and modify the model assignments.

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
│   ├── oh-my-opencode.json        # oh-my-opencode default config (committed)
│   ├── oh-my-opencode.anthropic.json # oh-my-opencode Anthropic profile (committed)
│   ├── oh-my-opencode.local.json  # oh-my-opencode local overrides (gitignored, optional)
│   └── oh-my-opencode.merged.json # oh-my-opencode merged result (gitignored, auto-generated)
├── data/           # Persistent home directory (mounted to /home/coder)
│   └── .claude/    # Claude credentials (auto-seeded by ocd, gitignored)
├── .claude-token   # OAuth token file (gitignored, created by claude-auth)
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
