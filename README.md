# Local Isolated Code Runner

```text

                  o
                 / \
          o-----o---o-----o
         /       \ /       \
        o         o         o
                  |               88
                                  88
                                  88
 ,adPPYba,----,adPPYba,---,adPPYb,88
a8"  o  "8a  a8"  o--""  a8"    `Y88
8b   |   d8  8b---|------8b---o---88
"8a,-o-,a8"  "8a,-o-,aa  "8a,-|-,d88
 `"YbbdP"'    `"Ybbd8"'   `"8bbdP"Y8
```

Run OpenCode inside a Docker container with sandboxed file access and security hardening.

## Features

- Runs OpenCode in an isolated Docker container
- Mounts your current working directory at a stable unique path under `/workspaces/...`
- Persistent home directory and configuration across sessions
- Security hardening (dropped capabilities, no-new-privileges)
- Pre-installed tools: git, ripgrep, fzf, curl, Python, BasedPyright, CMake/CTest, Terraform, Terraform LS, full system `ffmpeg`/`ffprobe`, Poppler (`pdftotext`/`pdfinfo`), qpdf, OCRmyPDF, Tesseract English OCR, Playwright MCP with its matching Chromium browser runtime, Playwright's bundled ffmpeg exposed as `playwright-ffmpeg`, Node.js language servers, and more
- [oh-my-opencode-slim](https://github.com/alvinunreal/oh-my-opencode-slim) for lean multi-agent orchestration
- Opt-in internal tmux visualization for Slim background agents
- Web UI mode for browser-based access

## Quick Start

Install Docker and host `jq` first. `./ocd` performs configuration merging and Slim profile generation on the host before Docker starts.

1. **Build the image:** `./build`
2. **Run the container:** `./ocd`
3. **Or start with internal tmux:** `./ocd --ocd-tmux` → opens OpenCode inside a container tmux session
4. **Or start in web mode:** `./ocd --ocd-web` → opens web UI at http://localhost:4096

**Optional:** Symlink to run from anywhere:
```bash
ln -s "$(pwd)/ocd" ~/.local/bin/ocd
```

## PDF And OCR

Use the pre-installed PDF and OCR tools from inside the container:

```bash
pdfinfo document.pdf
pdftotext -layout document.pdf -
ocrmypdf --deskew --rotate-pages scan.pdf searchable.pdf
```

Rebuild with `./build` after the Dockerfile changes so these tools are available in the image.

## OCD Options

Wrapper-owned options use the `--ocd-*` prefix so normal OpenCode flags can pass through without collisions. Run `./ocd --ocd-help` to list the wrapper options. Any unrecognized argument is forwarded to OpenCode; use `--` to forward the remaining arguments literally:

```bash
./ocd -- --help
./ocd --ocd-profile ollama -- --version
./ocd --ocd-profile ollama -- models --refresh
```

Available wrapper options are `--ocd-web`, `--ocd-tmux`, `--ocd-profile <name>`, `--ocd-port <port>`, `--ocd-debug`, and `--ocd-help`.

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
| `config/oh-my-opencode-slim.json` | Slim settings and model presets |
| `config/oh-my-opencode-slim.local.json` | Local Slim overrides (gitignored) |
| `config/.oh-my-opencode-slim.<container>.json` | Per-launch selected/merged Slim config (gitignored, temporary) |
| `config/tui.json` | TUI theme/config mounted into the container |
| `config/tmux.conf` | Internal tmux config mounted as `/home/coder/.tmux.conf` |
| `agents/*.md` | Wrapper-level custom OpenCode agents |
| `data/` | Persistent home directory |

### Local Config Overrides

Create `config/opencode.local.json` to override settings without committing:

```json
{ "provider": { "apiKey": "sk-secret-key" } }
```

On startup, `ocd` recursively merges this on top of `opencode.json` using `jq`. Objects are merged recursively, arrays are appended with duplicate entries skipped, and scalar values from the local file replace base values. The merged result is mounted read-only into the container.

Create `config/oh-my-opencode-slim.local.json` to override Slim settings or add machine-specific presets. Slim objects are merged recursively and arrays are replaced, matching Slim's native project-override behavior; this lets a local file clear or replace agent skills, MCPs, and disabled-agent lists. The launcher merges the local file, validates the preset selected by `--ocd-profile`, and writes a unique temporary config for that container. The selected profile and `--ocd-tmux` mode always win over local `preset` and multiplexer values. The temporary file is removed when the launcher exits, so concurrent containers cannot overwrite each other's selection.

The base `config/opencode.json` also carries shell permissions. Current defaults allow bash commands broadly while denying `git push`, `sudo`, and `su` patterns.

### X11 And Headed Chrome Support

If `/tmp/.X11-unix` exists on the host, it's automatically mounted (read-only) with `DISPLAY` for clipboard sharing and headed browser windows. If `XAUTHORITY` points to an existing host file, the launcher also mounts it read-only so Chrome launched by Playwright can authenticate to the X server.

The container uses `--shm-size=1g` because headed Chromium can hang or render blank surfaces with Docker's small default shared-memory mount. Playwright MCP also runs Chromium with software-only rendering flags so the browser remains observable on the host without passing GPU devices into the container or switching Playwright MCP to headless mode by default.

The image installs `@playwright/mcp` globally and uses that same package to install Playwright's bundled Chromium on all supported architectures, including Apple Silicon Docker Desktop. Keeping the MCP package and browser install source the same avoids browser revision mismatches when `@playwright/mcp@latest` moves ahead of the separately published `playwright` package.

The launcher uses Docker's `--init` shim so orphaned Chrome and crashpad helper processes are reaped when browser sessions exit. This prevents headed browser retries from accumulating zombie processes under the container's PID 1.

Headed Chrome support expects Linux X11, XWayland, or macOS XQuartz. On hosts with stricter X server access control, you may still need to allow the container user through your normal host policy, for example with `xhost` or a valid `XAUTHORITY` file.

On macOS, Docker Desktop cannot use XQuartz's local Unix socket path directly, including launchd socket values like `/var/run/com.apple.launchd.UWiVd5T0qS/org.xquartz:0`. When `ocd` runs on Darwin, it best-effort starts XQuartz if it is installed and, when `xhost` is available, allows only `127.0.0.1` and `localhost`; missing XQuartz or `xhost` does not block startup. When `OCD_DISPLAY` is not set, `ocd` then rewrites an empty, local socket, launchd socket, or `:0`-style `DISPLAY` to `host.docker.internal:0` for the container. Override the value explicitly with `OCD_DISPLAY=... ./ocd` if your XQuartz setup uses a different display endpoint.

The base OpenCode config starts the globally installed `playwright-mcp` binary with `/config/playwright-mcp.json` plus `--isolated`, rather than resolving a fresh package through `npx` at runtime. The launcher also exports `PLAYWRIGHT_MCP_CONFIG=/config/playwright-mcp.json` so plain child `playwright-mcp` launches inherit the same browser flags. The image creates a stable `/usr/local/bin/playwright-chromium` symlink to Playwright's revisioned Chromium install and exports `PLAYWRIGHT_MCP_EXECUTABLE_PATH` so MCP launches do not fall back to a host Chrome channel path. It also exposes Playwright's bundled ffmpeg as `/usr/local/bin/playwright-ffmpeg`; this remains the small Playwright-pinned media helper, while the normal `ffmpeg` and `ffprobe` commands come from Debian's full system package for general media work. The MCP command still unsets `PLAYWRIGHT_MCP_BROWSER` before startup so an inherited host or shell override cannot force the Chrome channel instead of Playwright's bundled Chromium. The config keeps Chromium headed, uses isolated in-memory browser profiles to avoid stale profile locks, suppresses Chromium's unsupported-flag warning with `--test-type` and `--disable-infobars`, forces a software-only rendering path with `--disable-gpu --disable-software-rasterizer`, and disables Chromium's `CDPScreenshotNewSurface` feature. Those rendering flags avoid hangs in screenshots or click-stability checks on some container/X11 compositor combinations. Playwright still injects `--no-sandbox` by default because the wrapper runs Docker with `no-new-privileges`, which prevents Chromium's setuid sandbox from initializing. Rebuild with `./build` after changing the Dockerfile or Playwright MCP package version, and restart `./ocd` after changing this MCP config or launcher environment; running OpenCode sessions keep the already-started MCP server.

### oh-my-opencode-slim

The pinned `oh-my-opencode-slim` plugin provides a focused Orchestrator with Explorer, Oracle, Librarian, Designer, and Fixer specialists. Multi-model Council mode is not configured in OCD's lean default. The image stages Slim's bundled skills under `/config/skills` so they are available on first launch without allowing the plugin to modify the read-only config mount.

Slim's optional behavior is conservative: Companion and Observer are disabled, automatic orchestrator wake is disabled in the committed config, and multiplexer visualization is off unless `--ocd-tmux` is requested. Wrapper generation sets the active Slim preset and multiplexer setting for each launch, so `preset` and `multiplexer` should not be set in the committed base config. Slim still delegates bounded work to background specialists as its core orchestration model.

The image includes `tmux` for opt-in Slim agent visualization. The wrapper mounts `config/tmux.conf` read-only as `/home/coder/.tmux.conf`, so tmux sessions created by OpenCode use the repo config inside the container.

Use `./ocd --ocd-tmux` to start OpenCode inside a visible container-internal tmux session named `opencode`. This also changes the generated Slim multiplexer setting from `none` to `tmux`. Extra OpenCode arguments are forwarded after the workspace path, and `--ocd-profile` selects a preset from the mounted Slim config:

```bash
./ocd --ocd-tmux
./ocd --ocd-tmux --ocd-profile ollama
```

This tmux setup is intentionally internal to the container. It does not share host tmux sockets or sessions, so you can launch `./ocd --ocd-tmux` from a host tmux pane while Slim uses its own separate tmux server inside Docker. `--ocd-tmux` is for the terminal TUI and cannot be combined with `--ocd-web`. Rebuild with `./build` after changing the Dockerfile or tmux package set.

When `--ocd-tmux` is used, the launcher starts OpenCode with `--port` because Slim's tmux pane integration connects to the running OpenCode server. The port defaults to `4096` and can be changed with `--ocd-port`, the same wrapper flag used by web mode.

The launcher pins the container's outer `TERM` to `xterm-256color`; tmux then sets its own terminal type inside the session. This avoids broken rendering when the host uses a terminal name that is not available in Debian terminfo.

For background-agent pane visualization, the launcher also exports the active tmux pane id before starting OpenCode, so Slim can resolve the caller pane and split the correct window.

### Custom Markdown Agents

Define wrapper-level custom OpenCode agents as Markdown files under `agents/`. The `ocd` launcher mounts that directory read-only to `/config/agents`, and `OPENCODE_CONFIG_DIR=/config` lets OpenCode load them alongside the JSON config.

Each file name becomes the agent name. For example, `agents/reviewer.md` creates an agent named `reviewer`:

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

Use project-level `.opencode/agents/*.md` files in the workspace for agents that should live with one project. Use this repo's `agents/*.md` for agents you want available whenever you launch through `ocd`. Avoid naming custom agents the same as built-in agents unless you intentionally want to override them.

This wrapper includes `hallucinator`, a high-temperature primary agent for speculative ideation and playful brainstorming. Use it when you want more creative, less grounded output; switch back to a grounded agent before relying on factual claims or implementation details.

### Model Profiles

Switch models via the wrapper `--ocd-profile` flag:

```bash
./ocd                        # Use default OpenAI models
./ocd --ocd-profile ollama   # Use local Ollama models only
```

**Available profiles:**

| Profile | Description |
|---------|-------------|
| (default) | Uses OpenAI models exclusively, with `gpt-6-astra` at low reasoning effort for Oracle |
| `ollama` | Uses the local Ollama-only preset with the Ollama provider from `config/opencode.json` |

The committed Ollama preset maps all Slim agents to the local `gemma4:26b-16k` model by default.

To create a new profile, add another entry under `presets` in `config/oh-my-opencode-slim.json`. Its key becomes the value accepted by `--ocd-profile`.

### Web Mode

Start OpenCode with a browser-based UI instead of the terminal TUI:

```bash
./ocd --ocd-web                              # Web UI on http://localhost:4096
./ocd --ocd-web --ocd-port 8080              # Custom port
./ocd --ocd-web --ocd-profile ollama         # Combine with model profiles
```

Web mode cannot be combined with `--ocd-tmux`; tmux mode is only for the terminal TUI. Web mode starts with the requested port and automatically increments to the next available port if it is already in use.

**Authentication (optional):** Set `OPENCODE_SERVER_PASSWORD` to require basic auth:
```bash
OPENCODE_SERVER_PASSWORD=secret ./ocd --ocd-web
```
Username defaults to OpenCode's built-in `opencode` value unless `OPENCODE_SERVER_USERNAME` is set.

**Environment variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `OCD_WEB_PORT` | Default web port (overridden by `--ocd-port`) | `4096` |
| `OCD_NO_BANNER` | Suppress the interactive startup banner when set | (unset) |
| `OPENCODE_SERVER_PASSWORD` | Basic auth password | (none — unauthenticated) |
| `OPENCODE_SERVER_USERNAME` | Basic auth username | `opencode` |

### Debugging Container Exits

Use `./ocd --ocd-debug` when OpenCode exits unexpectedly. Debug mode keeps the generated container instead of removing it and prints commands for collecting evidence:

```bash
./ocd --ocd-debug
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
├── config/         # OpenCode and oh-my-opencode-slim configs
│   ├── opencode.json              # Base config (committed)
│   ├── opencode.local.json        # Local overrides (gitignored, optional)
│   ├── opencode.merged.json       # Merged result (gitignored, auto-generated)
│   ├── oh-my-opencode-slim.json        # Slim settings and all model presets (committed)
│   ├── oh-my-opencode-slim.local.json  # Slim local overrides (gitignored, optional)
│   ├── .oh-my-opencode-slim.<container>.json # Per-launch Slim config (gitignored, temporary)
│   └── tmux.conf                   # Internal tmux config mounted to /home/coder/.tmux.conf
├── agents/         # Markdown custom agents mounted to /config/agents
├── data/           # Persistent home (mounted to /home/coder)
└── Dockerfile      # Container definition
```

## How It Works

The `ocd` script:
- Builds/runs `ocd:latest` Docker image
- Generates a unique Docker container name per run so multiple `ocd` containers can run at a time
- Prints an ASCII startup banner for interactive terminals unless `OCD_NO_BANNER` is set
- Prints a startup summary with the selected mode/profile, workspace mapping, mounted configs, display/X11 state, forwarded OpenCode args, and container command
- Mounts the current physical directory to a deterministic `/workspaces/<basename>-<hash>` path and sets it as the container working directory so new TUI sessions scope to the mounted workspace
- Seeds `.git/opencode` with a deterministic `ocd-<hash>` project id for Git repositories that do not have a first commit yet, avoiding OpenCode's shared `global` session scope
- Mounts config files to `/config` (sets `OPENCODE_CONFIG` and `OPENCODE_CONFIG_DIR`, including `tui.json`)
- Mounts `agents` to `/config/agents` so Markdown custom agents are available in every `ocd` session
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

This matches the committed `ollama` preset in `config/oh-my-opencode-slim.json` and the Ollama model entry in `config/opencode.json`.

| Context Size | Use Case |
|--------------|----------|
| 8192 | Small projects, single files |
| 16384 | Most coding tasks |
| 32768 | Large codebases, multi-file refactoring |

Larger contexts need more VRAM (~2-4GB extra for 16K).
