# AGENTS.md

## Overview

This repository is a small Bash-and-config wrapper for running OpenCode inside a hardened Docker container.

- Primary purpose: build and launch an isolated OpenCode environment against the caller's current directory mounted as `/workspace`.
- Dominant implementation languages: Bash for behavior, JSON for configuration, Dockerfile for runtime image definition.
- There is no `src/` tree, root `package.json`, or local app/test suite in this repo.

## Repository shape

Top-level files are the product surface:

- `build` — builds Docker image `ocd:latest` using host UID/GID.
- `ocd` — main launcher; parses flags, merges configs, runs Docker.
- `clearcache` — removes selected caches under `data/` without deleting core config/credentials.
- `Dockerfile` — container definition and preinstalled tools.
- `README.md` — user-facing architecture and usage guide; keep it aligned with behavior changes.
- `config/` — committed base configs and model-profile variants.
- `data/` — persistent runtime home mounted into the container; mostly ignored and treated as state, not source.

## Key runtime model

`./ocd` is the orchestration center.

- Mounts host current directory to `/workspace`.
- Mounts repo `data/` to `/home/coder`.
- Mounts merged or base configs read-only into `/config`.
- Always uses `--network host` for Docker, partly for local Ollama compatibility.
- Applies hardening: `no-new-privileges`, drops all caps, re-adds only `CHOWN`, `SETUID`, `SETGID`.

## Important config files

- `config/opencode.json`
  - OpenCode schema config.
  - Defines permissions, plugin list, and local Ollama provider (`http://localhost:11434/v1`).
- `config/oh-my-openagent.json`
  - Default agent/category routing profile.
- `config/oh-my-openagent.minimax.json`
- `config/oh-my-openagent.ollama.json`
  - Same overall schema as the default profile; mostly model and concurrency differences.
- `config/tui.json`
  - Small TUI theme config; not part of the merge flow.

## Config layering rules

Two local override flows matter:

1. `config/opencode.json` + optional `config/opencode.local.json` → generated `config/opencode.merged.json`
2. selected `config/oh-my-openagent*.json` + optional `config/oh-my-openagent.local.json` → generated `config/oh-my-openagent.merged.json`

The merge implementation is `jq -s '.[0] * .[1]'`.

Critical implication:

- objects are merged recursively
- arrays are replaced wholesale, not appended

If you change config-merging behavior or document local overrides, mention this explicitly.

## Shell conventions

Root scripts follow a consistent style:

- shebang: `#!/usr/bin/env bash`
- strict mode: `set -e` or `set -euo pipefail`
- symlink-safe script directory resolution via `BASH_SOURCE[0]` loop in `ocd` and `clearcache`
- uppercase variable names for config/env (`SCRIPT_DIR`, `WEB_PORT`, `IMAGE_NAME`)
- small helper functions like `usage()`
- manual argument parsing with `case`

When editing or adding scripts, match that style instead of introducing a different CLI framework.

## Commands agents will actually use

Primary workflows:

```bash
./build
./ocd
./ocd --web
./ocd --web --port 8080
./ocd --profile minimax
./ocd --profile ollama
./clearcache
./clearcache --dry-run
```

There is no repo-local lint/test command suite to update.

## Safe editing guidance

When making changes, usually inspect these files together:

- behavior change in container startup or mounting → `ocd`, `README.md`
- cache cleanup changes → `clearcache`, `README.md` if user-visible
- image/tooling changes → `Dockerfile`, `README.md`
- profile/model routing changes → matching `config/oh-my-openagent*.json`, possibly `README.md`
- permission/plugin/provider changes → `config/opencode.json`, possibly profile docs in `README.md`

## Repo-specific gotchas

- `config/*.local.json` and generated `*.merged.json` are gitignored and may contain secrets or machine-specific state.
- `data/` is intentionally ignored except tracked placeholders; do not treat it as stable source.
- Web mode is unauthenticated unless `OPENCODE_SERVER_PASSWORD` is set.
- Web mode starts with the requested port and auto-increments to the next available port if it is already in use.
- X11 clipboard mounting is conditional on `/tmp/.X11-unix`; do not assume GUI support is always available.

## External references that match this repo

These are the main upstream systems this repo configures around:

- OpenCode docs: `https://opencode.ai/docs/config/`
- OpenCode plugins docs: `https://opencode.ai/docs/plugins/`
- OpenCode source/docs: `https://github.com/anomalyco/opencode`
- oh-my-openagent: `https://github.com/code-yeongyu/oh-my-openagent`
- Ollama docs / OpenAI compatibility: `https://docs.ollama.com/`

## Current repo facts verified during exploration

- Git remote: `git@github.com:deflax/ocd.git`
- Default branch checked out during exploration: `main`
- Explored commit: `0f2894a`

## Working assumptions for future agents

- Treat this as an operational infra/tooling repo, not an application repo.
- Prefer small, surgical edits; most changes should touch one script and possibly one doc/config file.
- If behavior changes, update `README.md` in the same pass.
- If adding a new model profile, mirror the existing `oh-my-openagent.<profile>.json` structure rather than inventing a new schema shape.
