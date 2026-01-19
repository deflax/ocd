# Local Isolated Code Runner

Run OpenCode inside a Docker container with sandboxed file access and security hardening.

## Features

- Runs OpenCode in an isolated Docker container
- Mounts your current working directory as `/workspace`
- Persistent home directory and configuration across sessions
- Security hardening (dropped capabilities, no-new-privileges)
- Pre-installed tools: git, ripgrep, fzf, curl, and more

## Quick Start

1. **Build the image:**
   ```bash
   ./build
   ```

2. **Run the container:**
   ```bash
   ./ocd
   ```
   This will start the container with your current directory mounted as the workspace.

## Configuration

- Set your API key via the `OPENCODE_API_KEY` environment variable
- OpenCode config is stored in `config/opencode.json`
- Persistent user data is stored in `data/`

## Directory Structure

```
.
├── build           # Script to build the Docker image
├── ocd             # Script to run the container
├── config/         # OpenCode configuration (mounted to /config)
├── data/           # Persistent home directory (mounted to /home/opencode)
└── Dockerfile      # Container definition
```

## How It Works

The `ocd` script:
- Builds and runs the `ocd:latest` Docker image
- Mounts your current directory to `/workspace` inside the container
- Attaches to an existing container if one is already running
- Applies security restrictions (dropped capabilities, no-new-privileges)

## Model Configuration

To create a custom Ollama model with an increased context window:

```bash
$ ollama run qwen3:8b
>>> /set parameter num_ctx 16384
Set parameter 'num_ctx' to '16384'
>>> /save qwen3:8b-16k
Created new model 'qwen3:8b-16k'
>>> /bye
```
