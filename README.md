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
The image pins OpenCode CLI v2.0.5 and invokes it as `opencode2`.

## Features

- Runs OpenCode in an isolated Docker container
- Mounts your current working directory at a stable unique path under `/workspaces/...`
- Persistent home directory and configuration across sessions
- Security hardening (dropped capabilities, no-new-privileges)
- Pre-installed tools: git, ripgrep, fzf, curl, Python, BasedPyright, CMake/CTest, Terraform, Terraform LS, full system `ffmpeg`/`ffprobe`, Poppler (`pdftotext`/`pdfinfo`), qpdf, OCRmyPDF, Tesseract English OCR, Playwright MCP with its matching Chromium browser runtime, Playwright's bundled ffmpeg exposed as `playwright-ffmpeg`, Node.js language servers, and more
- [oh-my-opencode-slim](https://github.com/alvinunreal/oh-my-opencode-slim) for lean multi-agent orchestration
- Web UI mode for browser-based access

## Quick Start

Install Docker and host `jq` first. `./ocd` performs configuration merging and Slim profile generation on the host before Docker starts.

1. **Build the image:** `./build`
2. **Run the container:** `./ocd`
3. **Or start in web mode:** `./ocd --ocd-web` → starts the web UI at http://localhost:4096

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

Wrapper-owned options use the `--ocd-*` prefix so normal OpenCode flags can pass through without collisions. Run `./ocd --ocd-help` to list the wrapper options. In terminal mode, unrecognized arguments are forwarded to `opencode2 --standalone`; use `--` to forward the remaining arguments literally. `--standalone` guarantees that terminal use starts a container-private server.

```bash
./ocd -- --help
./ocd --ocd-profile ollama -- --version
./ocd --ocd-profile ollama -- models --refresh
```

Available wrapper options are `--ocd-web`, `--ocd-profile <name>`, `--ocd-port <port>`, `--ocd-debug`, and `--ocd-help`.

Web mode always uses `opencode2 serve --hostname 0.0.0.0 --port <port>`; extra OpenCode arguments are not forwarded.

## Cache Cleanup

Use `./clearcache` to remove persistent runtime data when stale package state interferes with OpenCode or application builds. It preserves OpenCode sessions and login state: `data/.local/share/opencode/auth.json`, `opencode.db*`, `snapshot/`, and `storage/session_diff/`. Generated config contents under `data/.config/`, including stale `data/.config/opencode` package files or JSONC files, are removed because wrapper config is mounted from `config/`. Run `./clearcache --dry-run` first to see what would be deleted.

Use `./fixsessions --dry-run` to inspect legacy OpenCode sessions that are still attached to the old shared `global` project. Run `./fixsessions` to move those sessions into per-directory project records so they stop appearing in unrelated workspaces. The repair updates only `data/.local/share/opencode/opencode.db`; it preserves auth and does not delete sessions.

## Configuration

| Path | Description |
|------|-------------|
| `config/opencode.json` | Base config |
| `config/opencode.local.json` | Local overrides (gitignored) |
| `config/opencode.ollama.json` | Ollama Research/Hallucinator/Plan/Build model overlay (committed) |
| `config/opencode.merged.json` | Auto-merged result (gitignored) |
| `config/playwright-mcp.json` | Playwright MCP Chromium launch config mounted into `/config` |
| `config/oh-my-opencode-slim.json` | Slim settings and model presets |
| `config/oh-my-opencode-slim.local.json` | Local Slim overrides (gitignored) |
| `config/.oh-my-opencode-slim.<container>.json` | Per-launch selected/merged Slim config (gitignored, temporary) |
| `config/cli.json` | OpenCode v2 CLI theme/config mounted into the standard global config directory |
| `agents/*.md` | Wrapper-level custom OpenCode agents |
| `data/` | Persistent home directory |

### Local Config Overrides

Create `config/opencode.local.json` to override v2 settings without committing:

```json
{ "providers": { "openai": { "settings": { "apiKey": "sk-secret-key" } } } }
```

On startup, `ocd` recursively merges this on top of `opencode.json` using `jq`. Objects are merged recursively, arrays are appended with duplicate entries skipped, and scalar values from the local file replace base values. For non-Ollama profiles, this base → optional local merge is the complete OpenCode config flow. Existing v1 local overrides must use v2 field names and shapes: `providers` instead of `provider`, `plugins` instead of `plugin`, `agents` instead of `agent`, and ordered `permissions` arrays instead of a `permission` object. Every v2 permission rule is `{ "action": "...", "resource": "...", "effect": "..." }`; rules are last-match-wins. Provider adapters use `package` and `settings`; shell rules use `shell`, and edits use `edit` rather than a separate write rule. Use `"skills": ["/config/skills"]`, `update: "disable"`, and `disabled`, not the v1 skills, update, and agent-disable fields.

When `--ocd-profile ollama` is selected, `ocd` additionally merges the committed `config/opencode.ollama.json` overlay after the base and optional local config: base → optional local → Ollama overlay. The overlay applies exclusively to the Ollama profile and authoritatively sets the `agents.research.model`, `agents.hallucinator.model`, `agents.plan.model`, and `agents.build.model` values, overriding local values for those fields. A generated `opencode.merged.json` is written only when a local config or the Ollama overlay is active; the resulting config is mounted read-only into the container.

Create `config/oh-my-opencode-slim.local.json` to override Slim settings or add machine-specific presets. Slim objects are merged recursively and arrays are replaced, matching Slim's native project-override behavior; this lets a local file clear or replace agent skills, MCPs, and disabled-agent lists. The launcher merges the local file, validates the preset selected by `--ocd-profile`, and writes a unique temporary config for that container. The selected profile always wins over a local `preset` value. The temporary file is removed when the launcher exits, so concurrent containers cannot overwrite each other's selection.

The base `config/opencode.json` carries ordered v2 permission rules. Current defaults allow reads, edits, tools, and shell commands broadly; they ask before external-directory access except for `/config/skills` and `/tmp`, and deny `git push`, `sudo`, and `su` shell patterns. Because v2 uses last-match-wins, broad ask/allow rules appear before their more specific exceptions.

### OpenCode v2 Global Config Discovery

The launcher does not set a global XDG override or private OpenCode config environment variables. It uses v2's standard global discovery under `/home/coder/.config/opencode/` (the container's `~/.config/opencode/`) and mounts these effective assets read-only:

- `opencode.json` — base or generated merged core config
- `oh-my-opencode-slim.json` — the selected, generated Slim config
- `cli.json` — CLI theme configuration
- `opencode-quota/quota-toast.json` — quota plugin sidecar configuration
- `agents/` — wrapper-level Markdown agents

The Playwright MCP launch file remains mounted at `/config/playwright-mcp.json`. Slim's image-staged skills remain at `/config/skills`; the v2 core config explicitly loads that path with `"skills": ["/config/skills"]`.

### Primary Agent

Orchestrator is the default primary agent. Research remains an optional, visible read-only primary agent for research and analysis; Plan and Build are disabled. Invoke the appropriate specialist agent for implementation work.

### X11 And Headed Chrome Support

If `/tmp/.X11-unix` exists on the host, it's automatically mounted (read-only) with `DISPLAY` for clipboard sharing and headed browser windows. If `XAUTHORITY` points to an existing host file, the launcher also mounts it read-only so Chrome launched by Playwright can authenticate to the X server.

The container uses `--shm-size=1g` because headed Chromium can hang or render blank surfaces with Docker's small default shared-memory mount. Playwright MCP also runs Chromium with software-only rendering flags so the browser remains observable on the host without passing GPU devices into the container or switching Playwright MCP to headless mode by default.

The image installs `@playwright/mcp` globally and uses that same package to install Playwright's bundled Chromium on all supported architectures, including Apple Silicon Docker Desktop. Keeping the MCP package and browser install source the same avoids browser revision mismatches when `@playwright/mcp@latest` moves ahead of the separately published `playwright` package.

The launcher uses Docker's `--init` shim so orphaned Chrome and crashpad helper processes are reaped when browser sessions exit. This prevents headed browser retries from accumulating zombie processes under the container's PID 1.

Headed Chrome support expects Linux X11, XWayland, or macOS XQuartz. On hosts with stricter X server access control, you may still need to allow the container user through your normal host policy, for example with `xhost` or a valid `XAUTHORITY` file.

On macOS, Docker Desktop cannot use XQuartz's local Unix socket path directly, including launchd socket values like `/var/run/com.apple.launchd.UWiVd5T0qS/org.xquartz:0`. When `ocd` runs on Darwin, it best-effort starts XQuartz if it is installed and, when `xhost` is available, allows only `127.0.0.1` and `localhost`; missing XQuartz or `xhost` does not block startup. When `OCD_DISPLAY` is not set, `ocd` then rewrites an empty, local socket, launchd socket, or `:0`-style `DISPLAY` to `host.docker.internal:0` for the container. Override the value explicitly with `OCD_DISPLAY=... ./ocd` if your XQuartz setup uses a different display endpoint.

The base OpenCode config starts the globally installed `playwright-mcp` binary with `/config/playwright-mcp.json` plus `--isolated`, rather than resolving a fresh package through `npx` at runtime. The launcher also exports `PLAYWRIGHT_MCP_CONFIG=/config/playwright-mcp.json` so plain child `playwright-mcp` launches inherit the same browser flags. The image creates a stable `/usr/local/bin/playwright-chromium` symlink to Playwright's revisioned Chromium install and exports `PLAYWRIGHT_MCP_EXECUTABLE_PATH` so MCP launches do not fall back to a host Chrome channel path. It also exposes Playwright's bundled ffmpeg as `/usr/local/bin/playwright-ffmpeg`; this remains the small Playwright-pinned media helper, while the normal `ffmpeg` and `ffprobe` commands come from Debian's full system package for general media work. The MCP command still unsets `PLAYWRIGHT_MCP_BROWSER` before startup so an inherited host or shell override cannot force the Chrome channel instead of Playwright's bundled Chromium. The config keeps Chromium headed, uses isolated in-memory browser profiles to avoid stale profile locks, suppresses Chromium's unsupported-flag warning with `--test-type` and `--disable-infobars`, forces a software-only rendering path with `--disable-gpu --disable-software-rasterizer`, and disables Chromium's `CDPScreenshotNewSurface` feature. Those rendering flags avoid hangs in screenshots or click-stability checks on some container/X11 compositor combinations. Playwright still injects `--no-sandbox` by default because the wrapper runs Docker with `no-new-privileges`, which prevents Chromium's setuid sandbox from initializing. Rebuild with `./build` after changing the Dockerfile or Playwright MCP package version, and restart `./ocd` after changing this MCP config or launcher environment; running OpenCode sessions keep the already-started MCP server.

### oh-my-opencode-slim

The pinned `oh-my-opencode-slim` 2.2.20 plugin provides a focused Orchestrator with Explorer, Oracle, Librarian, Designer, and Fixer specialists. Multi-model Council mode is not configured in OCD's lean default. The image stages Slim's bundled skills under `/config/skills`; v2 explicitly loads them with the core `skills` array while keeping the staging directory available without allowing the plugin to modify it.

Slim's optional behavior is conservative: Companion and Observer are disabled and automatic orchestrator wake is disabled in the committed config. Slim still delegates bounded work to background specialists as its core orchestration model.

### Custom Markdown Agents

Define wrapper-level custom OpenCode agents as Markdown files under `agents/`. The `ocd` launcher mounts that directory read-only to `/home/coder/.config/opencode/agents`, where v2 discovers it alongside the global JSON config.

Each file name becomes the agent name. For example, `agents/reviewer.md` creates an agent named `reviewer`:

```markdown
---
description: Reviews changes for bugs and missing tests
mode: subagent
model: openai/gpt-5.5
temperature: 0.1
permissions:
  - action: edit
    resource: "*"
    effect: deny
---
Review the current changes. Focus on correctness, regressions, security issues,
and missing verification. Report findings first, ordered by severity.
```

Use project-level `.opencode/agents/*.md` files in the workspace for agents that should live with one project. Use this repo's `agents/*.md` for agents you want available whenever you launch through `ocd`. Avoid naming custom agents the same as built-in agents unless you intentionally want to override them.

For JSON local overrides, agent definitions belong under the v2 `agents` object; Markdown front matter uses the same v2 `permissions` rule array shown above.

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
| `ollama` | Routes Slim specialists plus Research, Hallucinator, Plan, and Build to local Ollama using the provider from `config/opencode.json` |

The committed Ollama preset and core-agent overlay map all Slim specialists plus OpenCode Research, Hallucinator, Plan, and Build to the local `gemma4:26b-16k` model. The Ollama profile is not an offline or network-isolated mode; the container retains its normal host networking and configured tools/services.

To create a new profile, add another entry under `presets` in `config/oh-my-opencode-slim.json`. Its key becomes the value accepted by `--ocd-profile`.

### Web Mode

Start `opencode2` with a browser-based UI instead of the terminal TUI:

```bash
./ocd --ocd-web                              # Web UI on http://localhost:4096
./ocd --ocd-web --ocd-port 8080              # Custom port
./ocd --ocd-web --ocd-profile ollama         # Combine with model profiles
```

Web mode starts with the requested port and automatically increments to the next available port if it is already in use. `--ocd-port` applies to web mode only.

OpenCode v2's daemon-managed `serve` pairing Basic-auth credential uses the fixed username `opencode`; there is no user-configurable password environment variable. The server binds to `0.0.0.0`, so use it only on trusted networks and do not expose it publicly.

**Environment variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `OCD_WEB_PORT` | Default web port (overridden by `--ocd-port`) | `4096` |
| `OCD_NO_BANNER` | Suppress the interactive startup banner when set | (unset) |

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
│   ├── opencode.ollama.json       # Ollama Research/Hallucinator/Plan/Build model overlay (committed)
│   ├── opencode.merged.json       # Merged result (gitignored, auto-generated)
│   ├── oh-my-opencode-slim.json        # Slim settings and all model presets (committed)
│   ├── oh-my-opencode-slim.local.json  # Slim local overrides (gitignored, optional)
│   ├── .oh-my-opencode-slim.<container>.json # Per-launch Slim config (gitignored, temporary)
│   └── cli.json                    # OpenCode v2 CLI theme config
├── agents/         # Markdown custom agents mounted to ~/.config/opencode/agents
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
- Mounts effective config assets read-only to `~/.config/opencode/` for standard OpenCode v2 discovery: core config, selected Slim config, `cli.json`, quota sidecar, and custom agents
- Keeps Playwright's launch config at `/config/playwright-mcp.json` and Slim's image-staged skills at `/config/skills`
- Clears the image `opencode2` entrypoint at launch, then explicitly runs either `opencode2 --standalone` or `opencode2 serve`
- Applies security restrictions (dropped capabilities, no-new-privileges)

Old sessions are not migrated automatically. If legacy sessions appear across unrelated workspaces, run `./fixsessions --dry-run` and then `./fixsessions` to repair the old shared `global` project records.

## Upgrading To OpenCode v2

After pulling this migration, run `./build` to install the pinned v2.0.5 CLI, then restart `./ocd`; already-running containers keep their old executable and mounted configuration. Rename or migrate any local v1 override fields as described above before restarting. Rebuild again after Dockerfile changes; configuration, CLI theme, agent, or launcher changes require ending and restarting `./ocd` so the new read-only mounts are applied.

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
