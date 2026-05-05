# Local Isolated Code Runner

Run OpenCode inside a Docker container with sandboxed file access and security hardening.

## Features

- Runs OpenCode in an isolated Docker container
- Mounts your current working directory at a stable unique path under `/workspaces/...`
- Persistent home directory and configuration across sessions
- Security hardening (dropped capabilities, no-new-privileges)
- Pre-installed tools: git, ripgrep, fzf, curl, and more
- [Claude Code](https://github.com/anthropics/claude-code) OAuth token support (use your Pro/Max subscription)
- [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) plugin for multi-agent orchestration
- Web UI mode for browser-based access

## Quick Start

1. **Build the image:** `./build`
2. **Set up Claude auth (first time):** `./claude-auth setup-token` → opens browser for authorization, saves token to `.claude-token` (~1 year validity)
3. **Run the container:** `./ocd`
4. **Or start in web mode:** `./ocd --web` → opens web UI at http://localhost:4096

**Optional:** Symlink to run from anywhere:
```bash
ln -s "$(pwd)/ocd" ~/.local/bin/ocd
```

## Configuration

| Path | Description |
|------|-------------|
| `config/opencode.json` | Base config |
| `config/opencode.local.json` | Local overrides (gitignored) |
| `config/opencode.merged.json` | Auto-merged result (gitignored) |
| `config/oh-my-openagent.*.json` | Model profiles (see below) |
| `config/tui.json` | TUI theme/config mounted into the container |
| `data/` | Persistent home directory |

### Local Config Overrides

Create `config/opencode.local.json` to override settings without committing:

```json
{ "provider": { "apiKey": "sk-secret-key" } }
```

On startup, `ocd` recursively merges this on top of `opencode.json` using `jq`. Objects are merged recursively, arrays are appended with duplicate entries skipped, and scalar values from the local file replace base values. The merged result is mounted read-only into the container.

The base `config/opencode.json` also carries shell permissions. Current defaults allow bash commands broadly while denying `git push`, `sudo`, and `su` patterns.

### X11 Clipboard Support

If `/tmp/.X11-unix` exists on the host, it's automatically mounted (read-only) with `DISPLAY` for clipboard sharing. Skipped on Wayland-only or macOS hosts.

### Claude Code Authentication

**Setup:** `./claude-auth setup-token` — opens browser, saves token to `.claude-token`

**Alternative:** Set `CLAUDE_CODE_OAUTH_TOKEN` env var directly:
```bash
export CLAUDE_CODE_OAUTH_TOKEN="sk-ant-oat01-..."
./ocd
```

**Other commands:**
```bash
./claude-auth status   # Check if token exists
./claude-auth logout   # Remove token and seeded container credentials
```

**How it works:** The `ocd` script seeds `data/.claude/.credentials.json` before launch. `./claude-auth logout` removes both `.claude-token` and the seeded credentials file. The [opencode-claude-auth](https://github.com/griffinmartin/opencode-claude-auth) plugin injects OAuth Bearer auth into API requests. Claude Code CLI handles token refresh.

**API key alternative:** Set `OPENCODE_API_KEY` instead.

### oh-my-openagent

Pre-installed plugin providing multi-agent orchestration (Sisyphus, Oracle, Librarian, etc.), background agents, LSP/AST tools, and `ultrawork` command.

### Model Profiles

Switch models via `--profile` flag:

```bash
./ocd                        # Use default OpenAI models
./ocd --profile minimax      # Use MiniMax models
./ocd --profile anthropic    # Use Anthropic Claude models
./ocd --profile ollama       # Use local Ollama models only
```

**Available profiles:**

| Profile | Description |
|---------|-------------|
| (default) | Uses OpenAI models exclusively |
| `minimax` | Uses MiniMax models for most agents (with OpenAI fallbacks) |
| `anthropic` | Uses Anthropic Claude models (requires Claude Code OAuth or API key) |
| `ollama` | Uses the local Ollama-only profile in `config/oh-my-openagent.ollama.json` with the Ollama provider from `config/opencode.json` |

The committed Ollama profile maps all agents/categories to the local `gemma4:26b-16k` model by default.

To create a new profile, copy `config/oh-my-openagent.json` to `config/oh-my-openagent.<profile>.json` and modify the model assignments.

### Web Mode

Start OpenCode with a browser-based UI instead of the terminal TUI:

```bash
./ocd --web                          # Web UI on http://localhost:4096
./ocd --web --port 8080              # Custom port
./ocd --web --profile anthropic      # Combine with model profiles
```

**Port auto-detection:** If the default port is already in use (e.g., another `ocd --web` instance), it automatically finds the next available port and prints which one it chose.

**Authentication (optional):** Set `OPENCODE_SERVER_PASSWORD` to require basic auth:
```bash
OPENCODE_SERVER_PASSWORD=secret ./ocd --web
```
Username defaults to OpenCode's built-in `opencode` value unless `OPENCODE_SERVER_USERNAME` is set.

**Environment variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `OCD_WEB_PORT` | Default web port (overridden by `--port`) | `4096` |
| `OPENCODE_SERVER_PASSWORD` | Basic auth password | (none — unauthenticated) |
| `OPENCODE_SERVER_USERNAME` | Basic auth username | `opencode` |

## Directory Structure

```
.
├── build           # Build the Docker image
├── ocd             # Run the container
├── claude-auth     # Manage Claude auth
├── clearcache      # Clear caches (preserves credentials)
├── config/         # OpenCode and oh-my-openagent configs
│   ├── opencode.json              # Base config (committed)
│   ├── opencode.local.json        # Local overrides (gitignored, optional)
│   ├── opencode.merged.json       # Merged result (gitignored, auto-generated)
│   ├── oh-my-openagent.json        # oh-my-openagent default config — OpenAI only (committed)
│   ├── oh-my-openagent.minimax.json   # oh-my-openagent MiniMax profile (committed)
│   ├── oh-my-openagent.anthropic.json # oh-my-openagent Anthropic profile (committed)
│   ├── oh-my-openagent.ollama.json    # oh-my-openagent Ollama-only profile (committed)
│   ├── oh-my-openagent.local.json  # oh-my-openagent local overrides (gitignored, optional)
│   └── oh-my-openagent.merged.json # oh-my-openagent merged result (gitignored, auto-generated)
├── data/           # Persistent home (mounted to /home/coder)
│   └── .claude/    # Claude credentials (auto-seeded by ocd, removed by claude-auth logout, gitignored)
├── .claude-token   # OAuth token (gitignored, created by claude-auth)
└── Dockerfile      # Container definition
```

## How It Works

The `ocd` script:
- Builds/runs `ocd:latest` Docker image
- Generates unique container name per run
- Mounts the current physical directory to a deterministic `/workspaces/<basename>-<hash>` path so new OpenCode sessions scope correctly with newer session behavior
- Mounts config files to `/config` (sets `OPENCODE_CONFIG` and `OPENCODE_CONFIG_DIR`, including `tui.json`)
- Applies security restrictions (dropped capabilities, no-new-privileges)

Old sessions are not migrated; this only affects new launches.

## Self-Hosted Model Configuration

For Ollama, increase context window size for large codebases and save a larger-context variant of the model you want to use:

```bash
$ ollama run gemma4:26b
>>> /set parameter num_ctx 16384
>>> /save gemma4:26b-16k
>>> /bye
```

This matches the committed local profile in `config/oh-my-openagent.ollama.json` and the Ollama model entry in `config/opencode.json`.

| Context Size | Use Case |
|--------------|----------|
| 8192 | Small projects, single files |
| 16384 | Most coding tasks |
| 32768 | Large codebases, multi-file refactoring |

Larger contexts need more VRAM (~2-4GB extra for 16K).
