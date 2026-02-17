#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

timestamp() {
  date +%Y%m%d%H%M%S
}

log() {
  printf '%s\n' "$*"
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

package_manager() {
  if has_cmd apt-get; then
    printf 'apt'
    return
  fi
  if has_cmd dnf; then
    printf 'dnf'
    return
  fi
  if has_cmd yum; then
    printf 'yum'
    return
  fi
  if has_cmd pacman; then
    printf 'pacman'
    return
  fi
  if has_cmd brew; then
    printf 'brew'
    return
  fi
  printf 'none'
}

can_use_sudo() {
  if [ "$(id -u)" -eq 0 ]; then
    return 0
  fi
  has_cmd sudo
}

install_packages() {
  pm=$(package_manager)

  case "$pm" in
    apt)
      if ! can_use_sudo; then
        log "Skipping apt installs (no root/sudo)"
        return
      fi
      sudo apt-get update
      sudo apt-get install -y tmux neovim git curl ripgrep fd-find
      ;;
    dnf)
      if ! can_use_sudo; then
        log "Skipping dnf installs (no root/sudo)"
        return
      fi
      sudo dnf install -y tmux neovim git curl ripgrep fd-find
      ;;
    yum)
      if ! can_use_sudo; then
        log "Skipping yum installs (no root/sudo)"
        return
      fi
      sudo yum install -y tmux neovim git curl ripgrep fd-find
      ;;
    pacman)
      if ! can_use_sudo; then
        log "Skipping pacman installs (no root/sudo)"
        return
      fi
      sudo pacman -Sy --noconfirm tmux neovim git curl ripgrep fd
      ;;
    brew)
      brew install tmux neovim git curl ripgrep fd || true
      ;;
    none)
      log "No supported package manager found; skipping package install"
      ;;
  esac
}

install_opencode() {
  if has_cmd opencode; then
    log "OpenCode already installed"
    return
  fi

  if has_cmd brew; then
    log "Installing OpenCode via Homebrew"
    brew install opencode && return
  fi

  if has_cmd npm; then
    log "Installing OpenCode via npm"
    npm install -g opencode-ai && return
  fi

  if has_cmd bun; then
    log "Installing OpenCode via bun"
    bun install -g opencode-ai && return
  fi

  log "Could not install OpenCode automatically (missing brew/npm/bun)"
}

backup_target() {
  target=$1
  if [ -e "$target" ] || [ -L "$target" ]; then
    backup_path="${target}.backup.$(timestamp)"
    log "Backing up $target -> $backup_path"
    mv "$target" "$backup_path"
  fi
}

link_path() {
  source_path=$1
  target_path=$2

  mkdir -p "$(dirname "$target_path")"

  if [ -L "$target_path" ]; then
    current_link=$(readlink "$target_path")
    if [ "$current_link" = "$source_path" ]; then
      log "Already linked: $target_path"
      return
    fi
  fi

  backup_target "$target_path"
  ln -s "$source_path" "$target_path"
  log "Linked $target_path -> $source_path"
}

main() {
  if [ "${DEVENV_SKIP_PACKAGES:-0}" = "1" ]; then
    log "Skipping dependency installation (DEVENV_SKIP_PACKAGES=1)"
  else
    log "Installing dependencies where possible"
    install_packages
  fi

  install_opencode

  log "Linking dotfiles"
  link_path "$SCRIPT_DIR/dotfiles/tmux/.tmux.conf" "$HOME/.tmux.conf"
  link_path "$SCRIPT_DIR/dotfiles/nvim" "$HOME/.config/nvim"
  link_path "$SCRIPT_DIR/dotfiles/opencode" "$HOME/.config/opencode"

  log "Done. Restart tmux and Neovim sessions to load new config."
}

main "$@"
