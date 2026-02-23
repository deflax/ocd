#!/usr/bin/env bash

set -euo pipefail

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$SCRIPT_DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"

CACHE_ROOT="${SCRIPT_DIR}/data/.cache"
DRY_RUN=false

usage() {
  cat <<'EOF'
Usage: ./clearcache.sh [--dry-run]

Clears OpenCode/oh-my-opencode cache files only.
Preserves provider/auth/config files under data/.config and data/.

Options:
  --dry-run   Show what would be removed
  -h, --help  Show help
EOF
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n\n' "$arg" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ ! -d "$CACHE_ROOT" ]; then
  printf 'No cache directory found: %s\n' "$CACHE_ROOT"
  exit 0
fi

declare -a TARGETS=(
  "$CACHE_ROOT/opencode/models.json"
  "$CACHE_ROOT/opencode/version"
  "$CACHE_ROOT/opencode/tmp"
  "$CACHE_ROOT/opencode/.tmp"
  "$CACHE_ROOT/oh-my-opencode/connected-providers.json"
  "$CACHE_ROOT/oh-my-opencode/provider-models.json"
  "$CACHE_ROOT/oh-my-opencode/tmp"
  "$CACHE_ROOT/oh-my-opencode/.tmp"
)

removed=0
for target in "${TARGETS[@]}"; do
  if [ -e "$target" ]; then
    if [ "$DRY_RUN" = true ]; then
      printf '[dry-run] remove %s\n' "$target"
    else
      rm -rf "$target"
      printf 'removed %s\n' "$target"
    fi
    removed=$((removed + 1))
  fi
done

if [ "$removed" -eq 0 ]; then
  printf 'No matching cache artifacts found.\n'
else
  if [ "$DRY_RUN" = true ]; then
    printf '[dry-run] total candidates: %d\n' "$removed"
  else
    printf 'Done. Removed %d cache artifact(s).\n' "$removed"
  fi
fi
