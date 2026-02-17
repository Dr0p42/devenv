#!/usr/bin/env sh
set -eu

REPO_URL="${DEVENV_REPO_URL:-https://github.com/Dr0p42/devenv.git}"
BRANCH="${DEVENV_BRANCH:-main}"
TARGET_DIR="${DEVENV_HOME:-$HOME/.local/share/devenv}"

log() {
  printf '%s\n' "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "Missing required command: $1"
    exit 1
  fi
}

clone_or_update_repo() {
  parent_dir=$(dirname "$TARGET_DIR")
  mkdir -p "$parent_dir"

  if [ -d "$TARGET_DIR/.git" ]; then
    log "Updating existing repo at $TARGET_DIR"
    git -C "$TARGET_DIR" fetch --all --prune
    git -C "$TARGET_DIR" checkout "$BRANCH"
    git -C "$TARGET_DIR" pull --ff-only origin "$BRANCH"
  else
    log "Cloning $REPO_URL into $TARGET_DIR"
    if git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$TARGET_DIR"; then
      :
    else
      log "Shallow clone failed, retrying full clone"
      rm -rf "$TARGET_DIR"
      git clone "$REPO_URL" "$TARGET_DIR"
      git -C "$TARGET_DIR" checkout "$BRANCH"
    fi
  fi
}

main() {
  require_cmd git
  require_cmd sh

  clone_or_update_repo

  log "Running bootstrap"
  sh "$TARGET_DIR/bootstrap.sh"
}

main "$@"
