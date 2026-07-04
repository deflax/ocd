# Local Isolated Code Runner

Run OpenCode inside a Docker container with sandboxed file access and security hardening.

## Features

- Runs OpenCode in an isolated Docker container
- Mounts your current working directory at a stable unique path under `/workspaces/...`
- Persistent home directory and configuration across sessions
- Security hardening (dropped capabilities, no-new-privileges)
- Pre-installed tools: git, ripgrep, fzf, curl, Python, BasedPyright, CMake/CTest, Terraform, Terraform LS, full system `ffmpeg`/`ffprobe`, Playwright MCP with its matching Chromium browser runtime, Playwright's bundled ffmpeg exposed as `playwright-ffmpeg`, Node.js language servers, and more
- [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) plugin for multi-agent orchestration
- Internal tmux support for oh-my-openagent team-mode/hyperplan workflows
- Web UI mode for browser-based access

## Quick Start

1. **Build the image:** `./build`
2. **Run the container:** `./ocd`
3. **Or start with internal tmux:** `./ocd --tmux` → opens OpenCode inside a container tmux session
4. **Or start in web mode:** `./ocd --web` → opens web UI at http://localhost:4096

**Optional:** Symlink to run from anywhere:
```bash
ln -s "$(pwd)/ocd" ~/.local/bin/ocd
```

## Cache Cleanup

Use `./clearcache` to remove persistent runtime data when stale package state interferes with OpenCode or application builds. It preserves OpenCode sessions and login state: `data/.local/share/opencode/auth.json`, `opencode.db*`, `snapshot/`, and `storage/session_diff/`. Generated config contents under `data/.config/`, including stale `data/.config/opencode` package files or JSONC files, are removed because wrapper config is mounted from `config/`. Run `./clearcache --dry-run` first to see what would be deleted.

Use `./fixsessions --dry-run` to inspect legacy OpenCode sessions that are still attached to the old shared `global` project. Run `./fixsessions` to move those sessions into per-directory project records so they stop appearing in unrelated workspaces. The repair updates only `data/.local/share/opencode/opencode.db`; it preserves auth and does not delete sessions.

## Configuration

| Path | Description |
|------|-------------|
| `config/opencode.json` | Base config |
| `config/opencode.local.json` | Local overrides (gitignored) |
| `config/opencode.merged.json` | Auto-merged result (gitignored) |
| `config/playwright-mcp.json` | Playwright MCP Chromium launch config mounted into `/config` |
| `config/oh-my-openagent.*.json` | Model profiles (see below) |
| `config/tui.json` | TUI theme/config mounted into the container |
| `config/tmux.conf` | Internal tmux config mounted as `/home/coder/.tmux.conf` |
| `config/agents/*.md` | Wrapper-level custom OpenCode agents |
| `data/` | Persistent home directory |

### Local Config Overrides

Create `config/opencode.local.json` to override settings without committing:

```json
{ "provider": { "apiKey": "sk-secret-key" } }
```

On startup, `ocd` recursively merges this on top of `opencode.json` using `jq`. Objects are merged recursively, arrays are appended with duplicate entries skipped, and scalar values from the local file replace base values. The merged result is mounted read-only into the container.

The base `config/opencode.json` also carries shell permissions. Current defaults allow bash commands broadly while denying `git push`, `sudo`, and `su` patterns.

### X11 And Headed Chrome Support

If `/tmp/.X11-unix` exists on the host, it's automatically mounted (read-only) with `DISPLAY` for clipboard sharing and headed browser windows. If `XAUTHORITY` points to an existing host file, the launcher also mounts it read-only so Chrome launched by Playwright can authenticate to the X server.

The container uses `--shm-size=1g` because headed Chromium can hang or render blank surfaces with Docker's small default shared-memory mount. Playwright MCP also runs Chromium with software-only rendering flags so the browser remains observable on the host without passing GPU devices into the container or switching Playwright MCP to headless mode by default.

The image installs `@playwright/mcp` globally and uses that same package to install Playwright's bundled Chromium on all supported architectures, including Apple Silicon Docker Desktop. Keeping the MCP package and browser install source the same avoids browser revision mismatches when `@playwright/mcp@latest` moves ahead of the separately published `playwright` package.

The launcher uses Docker's `--init` shim so orphaned Chrome and crashpad helper processes are reaped when browser sessions exit. This prevents headed browser retries from accumulating zombie processes under the container's PID 1.

Headed Chrome support expects Linux X11, XWayland, or macOS XQuartz. On hosts with stricter X server access control, you may still need to allow the container user through your normal host policy, for example with `xhost` or a valid `XAUTHORITY` file.

On macOS, Docker Desktop cannot use XQuartz's local Unix socket path directly, including launchd socket values like `/var/run/com.apple.launchd.UWiVd5T0qS/org.xquartz:0`. When `ocd` runs on Darwin, it best-effort starts XQuartz if it is installed and, when `xhost` is available, allows only `127.0.0.1` and `localhost`; missing XQuartz or `xhost` does not block startup. When `OCD_DISPLAY` is not set, `ocd` then rewrites an empty, local socket, launchd socket, or `:0`-style `DISPLAY` to `host.docker.internal:0` for the container. Override the value explicitly with `OCD_DISPLAY=... ./ocd` if your XQuartz setup uses a different display endpoint.

The base OpenCode config starts the globally installed `playwright-mcp` binary with `/config/playwright-mcp.json` plus `--isolated`, rather than resolving a fresh package through `npx` at runtime. The launcher also exports `PLAYWRIGHT_MCP_CONFIG=/config/playwright-mcp.json` so plain child `playwright-mcp` launches inherit the same browser flags. The image creates a stable `/usr/local/bin/playwright-chromium` symlink to Playwright's revisioned Chromium install and exports `PLAYWRIGHT_MCP_EXECUTABLE_PATH` so MCP launches do not fall back to a host Chrome channel path. It also exposes Playwright's bundled ffmpeg as `/usr/local/bin/playwright-ffmpeg`; this remains the small Playwright-pinned media helper, while the normal `ffmpeg` and `ffprobe` commands come from Debian's full system package for general media work. The MCP command still unsets `PLAYWRIGHT_MCP_BROWSER` before startup so an inherited host or shell override cannot force the Chrome channel instead of Playwright's bundled Chromium. The config keeps Chromium headed, uses isolated in-memory browser profiles to avoid stale profile locks, suppresses Chromium's unsupported-flag warning with `--test-type` and `--disable-infobars`, forces a software-only rendering path with `--disable-gpu --disable-software-rasterizer`, and disables Chromium's `CDPScreenshotNewSurface` feature. Those rendering flags avoid hangs in screenshots or click-stability checks on some container/X11 compositor combinations. Playwright still injects `--no-sandbox` by default because the wrapper runs Docker with `no-new-privileges`, which prevents Chromium's setuid sandbox from initializing. Rebuild with `./build` after changing the Dockerfile or Playwright MCP package version, and restart `./ocd` after changing this MCP config or launcher environment; running OpenCode sessions keep the already-started MCP server.

### oh-my-openagent

Pre-installed plugin providing multi-agent orchestration (Sisyphus, Oracle, Librarian, etc.), background agents, LSP/AST tools, and `ultrawork` command.

The image includes `tmux` for oh-my-openagent team-mode/hyperplan workflows. Team-mode and top-level `tmux.enabled` integration are enabled in the committed model profiles. The wrapper mounts `config/tmux.conf` read-only as `/home/coder/.tmux.conf`, so tmux sessions created by OpenCode use the repo config inside the container.

Use `./ocd --tmux` to start OpenCode inside a visible container-internal tmux session named `opencode`. Extra OpenCode arguments are forwarded after the workspace path, and `--profile` still selects the mounted oh-my-openagent profile:

```bash
./ocd --tmux
./ocd --tmux --profile minimax
```

This tmux setup is intentionally internal to the container. It does not share host tmux sockets or sessions, so you can launch `./ocd --tmux` from a host tmux pane while oh-my-openagent uses its own separate tmux server inside Docker. `--tmux` is for the terminal TUI and cannot be combined with `--web`. Rebuild with `./build` after changing the Dockerfile or tmux package set.

When `--tmux` is used, the launcher starts OpenCode with `--port` because oh-my-openagent tmux pane spawning requires an OpenCode server port. The port defaults to `4096` and can be changed with `--port`, the same flag used by web mode.

The launcher pins the container's outer `TERM` to `xterm-256color`; tmux then sets its own terminal type inside the session. This avoids broken rendering when the host uses a terminal name that is not available in Debian terminfo.

For team-mode pane visualization, the launcher also exports the active tmux pane id before starting OpenCode, so oh-my-openagent can resolve the caller pane and split the correct window.

### Custom Markdown Agents

Define wrapper-level custom OpenCode agents as Markdown files under `config/agents/`. The `ocd` launcher mounts that directory read-only to `/config/agents`, and `OPENCODE_CONFIG_DIR=/config` lets OpenCode load them alongside the JSON config.

Each file name becomes the agent name. For example, `config/agents/reviewer.md` creates an agent named `reviewer`:

```markdown
---
description: Reviews changes for bugs and missing tests
mode: subagent
model: openai/gpt-5.5
temperature: 0.1
permission:
  edit: deny
---
Review the current changes. Focus on correctness, regressions, security issues,
and missing verification. Report findings first, ordered by severity.
```

Use project-level `.opencode/agents/*.md` files in the workspace for agents that should live with one project. Use this repo's `config/agents/*.md` for agents you want available whenever you launch through `ocd`. Avoid naming custom agents the same as built-in agents unless you intentionally want to override them.

This wrapper includes `hallucinator`, a high-temperature primary agent for speculative ideation and playful brainstorming. Use it when you want more creative, less grounded output; switch back to a grounded agent before relying on factual claims or implementation details.

### Model Profiles

Switch models via `--profile` flag:

```bash
./ocd                        # Use default OpenAI models
./ocd --profile minimax      # Use MiniMax models
./ocd --profile ollama       # Use local Ollama models only
```

**Available profiles:**

| Profile | Description |
|---------|-------------|
| (default) | Uses OpenAI models exclusively |
| `minimax` | Uses MiniMax models for most agents (with OpenAI fallbacks) |
| `ollama` | Uses the local Ollama-only profile in `config/oh-my-openagent.ollama.json` with the Ollama provider from `config/opencode.json` |

The committed Ollama profile maps all agents/categories to the local `gemma4:26b-16k` model by default.

To create a new profile, copy `config/oh-my-openagent.json` to `config/oh-my-openagent.<profile>.json` and modify the model assignments.

### Web Mode

Start OpenCode with a browser-based UI instead of the terminal TUI:

```bash
./ocd --web                          # Web UI on http://localhost:4096
./ocd --web --port 8080              # Custom port
./ocd --web --profile minimax        # Combine with model profiles
```

Web mode cannot be combined with `--tmux`; tmux mode is only for the terminal TUI. Web mode starts with the requested port and automatically increments to the next available port if it is already in use.

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

### Debugging Container Exits

Use `./ocd --debug` when OpenCode exits unexpectedly. Debug mode keeps the generated container instead of removing it and prints commands for collecting evidence:

```bash
./ocd --debug
# The launcher prints the generated container name:
docker logs <container-name>
docker inspect <container-name>
docker rm <container-name>
```

Remove the preserved debug container with the printed `docker rm` command when you no longer need it.

## Directory Structure

```
.
├── build           # Build the Docker image
├── ocd             # Run the container
├── clearcache      # Clear caches
├── fixsessions     # Repair legacy OpenCode session project scoping
├── config/         # OpenCode and oh-my-openagent configs
│   ├── opencode.json              # Base config (committed)
│   ├── opencode.local.json        # Local overrides (gitignored, optional)
│   ├── opencode.merged.json       # Merged result (gitignored, auto-generated)
│   ├── oh-my-openagent.json        # oh-my-openagent default config — OpenAI only (committed)
│   ├── oh-my-openagent.minimax.json   # oh-my-openagent MiniMax profile (committed)
│   ├── oh-my-openagent.ollama.json    # oh-my-openagent Ollama-only profile (committed)
│   ├── oh-my-openagent.local.json  # oh-my-openagent local overrides (gitignored, optional)
│   ├── oh-my-openagent.merged.json # oh-my-openagent merged result (gitignored, auto-generated)
│   ├── tmux.conf                   # Internal tmux config mounted to /home/coder/.tmux.conf
│   └── agents/                     # Markdown custom agents mounted to /config/agents
├── data/           # Persistent home (mounted to /home/coder)
└── Dockerfile      # Container definition
```

## How It Works

The `ocd` script:
- Builds/runs `ocd:latest` Docker image
- Generates a unique Docker container name per run so multiple `ocd` containers can run at a time
- Mounts the current physical directory to a deterministic `/workspaces/<basename>-<hash>` path and passes that path to `opencode` so new TUI sessions scope to the mounted workspace
- Seeds `.git/opencode` with a deterministic `ocd-<hash>` project id for Git repositories that do not have a first commit yet, avoiding OpenCode's shared `global` session scope
- Mounts config files to `/config` (sets `OPENCODE_CONFIG` and `OPENCODE_CONFIG_DIR`, including `tui.json`)
- Mounts `config/agents` to `/config/agents` so Markdown custom agents are available in every `ocd` session
- Mounts `config/tmux.conf` to `/home/coder/.tmux.conf` for container-internal tmux sessions
- Clears the image `opencode` entrypoint at launch, then explicitly runs either `opencode`, `opencode web`, or `tmux`
- Applies security restrictions (dropped capabilities, no-new-privileges)

Old sessions are not migrated automatically. If legacy sessions appear across unrelated workspaces, run `./fixsessions --dry-run` and then `./fixsessions` to repair the old shared `global` project records.

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
