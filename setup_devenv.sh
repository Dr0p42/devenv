#!/usr/bin/env bash
# curl -fsSL https://setupdevenv.jublou.fr | bash

set -euo pipefail

if [ -z "${HOME:-}" ] || [ ! -d "$HOME" ]; then
  echo "HOME directory is not available: '${HOME:-}'" >&2
  exit 1
fi

USER_HOME="$HOME"

# Detect distro/package manager
source /etc/os-release
PKG_MGR=""

if command -v dnf >/dev/null 2>&1; then
  PKG_MGR="dnf"
elif command -v apt-get >/dev/null 2>&1; then
  PKG_MGR="apt"
else
  echo "Unsupported system: requires dnf or apt-get" >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# Dependencies
# -----------------------------------------------------------------------------
if [ "$PKG_MGR" = "dnf" ]; then
  sudo dnf install -y curl git tmux fzf gcc gcc-c++ make cmake pkgconf-pkg-config ripgrep
else
  sudo apt-get update
  sudo apt-get install -y curl git tmux fzf build-essential cmake pkg-config ripgrep
fi

# -----------------------------------------------------------------------------
# Fish shell
# -----------------------------------------------------------------------------
# Install EPEL only on RHEL-like 9 (Rocky/Alma/RHEL). Skip on Fedora.
if [ "$PKG_MGR" = "dnf" ] && [ -f /etc/redhat-release ] && grep -qE 'Rocky|AlmaLinux|Red Hat' /etc/redhat-release; then
  if ! rpm -q epel-release >/dev/null 2>&1; then
    sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
  fi
fi

if [ "$PKG_MGR" = "dnf" ]; then
  sudo dnf install -y fish
else
  sudo apt-get install -y fish
fi

# Change login shell (usually requires logout/login to take effect)
if command -v fish >/dev/null 2>&1; then
  sudo chsh -s "$(command -v fish)" "$USER" || true
fi

# Bootstrap fish state (creates ~/.config/fish and friends if missing)
# (Safe to run repeatedly.)
"$(command -v fish)" -c 'exit' || true

# Ensure fish config dirs exist
mkdir -p ~/.config/fish/functions
mkdir -p ~/.config/fish/conf.d

# -----------------------------------------------------------------------------
# Fish function: stm
# -----------------------------------------------------------------------------
cat > ~/.config/fish/functions/stm.fish <<'EOF'
function stm
    set -l session $argv[1]
    set -l cwd (pwd)

    if test -z "$session"
        set session tasks
    end

    if test "$session" = tasks
        mkdir -p "$HOME/dev/tasks"
        set cwd "$HOME/dev/tasks"
    end

    if tmux has-session -t "$session" 2>/dev/null
        if set -q TMUX
            tmux switch-client -t "$session"
        else
            tmux attach-session -t "$session"
        end
        return
    end

    tmux new-session -d -s "$session" -c "$cwd"
    tmux new-window -t "$session:2" -c "$cwd"
    tmux send-keys -t "$session:2" opencode C-m
    tmux new-window -t "$session:3" -c "$cwd"
    tmux new-window -t "$session:4" -c "$cwd"
    tmux select-window -t "$session:1"

    if set -q TMUX
        tmux switch-client -t "$session"
    else
        tmux attach-session -t "$session"
    end
end
EOF

# -----------------------------------------------------------------------------
# Install opencode
# -----------------------------------------------------------------------------
if ! curl -fsSL --retry 5 --retry-delay 2 --retry-connrefused https://opencode.ai/install | bash; then
  echo "Warning: opencode install failed (could not fetch latest version). Continuing..." >&2
fi

# -----------------------------------------------------------------------------
# Neovim (tarball install to /opt)
# -----------------------------------------------------------------------------
tmp_tar="$(mktemp -t nvim-linux-x86_64.XXXXXX.tar.gz)"
curl -fL --retry 5 --retry-delay 2 --retry-connrefused -o "$tmp_tar" https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz

sudo rm -rf /opt/nvim-linux-x86_64
sudo tar -C /opt -xzf "$tmp_tar"
rm -f "$tmp_tar"

# Add neovim to fish via conf.d snippet (fish loads this automatically)
cat > ~/.config/fish/conf.d/nvim.fish <<'EOF'
fish_add_path -g /opt/nvim-linux-x86_64/bin
EOF

# Install neovim.kickstart
if [ ! -d ~/.config/nvim ]; then
  git clone https://github.com/nvim-lua/kickstart.nvim.git ~/.config/nvim
fi


# Patch issue with lua_lp | Issue of kickstart.nvim
NVIM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"

# Patch kickstart: mason-tool-installer expects Mason package name, not lspconfig server name
# Only change the installer list entry; keep lspconfig 'lua_ls' unchanged.
if [ -f "$NVIM_DIR/init.lua" ]; then
  sed -i "s/'lua_ls',[[:space:]]*-- Lua Language server/'lua-language-server', -- Lua Language server/" "$NVIM_DIR/init.lua" || true
fi

# Pre-install plugins + mason tools so first nvim launch is clean
/opt/nvim-linux-x86_64/bin/nvim --headless "+Lazy! sync" "+MasonUpdate" "+qa" || true
/opt/nvim-linux-x86_64/bin/nvim --headless "+Lazy! sync" "+qa" || true

# -----------------------------------------------------------------------------
# Tmux config + TPM
# -----------------------------------------------------------------------------
mkdir -p "$USER_HOME/.tmux/plugins"

if [ ! -d "$USER_HOME/.tmux/plugins/tpm" ]; then
  git clone https://github.com/tmux-plugins/tpm "$USER_HOME/.tmux/plugins/tpm"
fi

TMUX_CONF="$USER_HOME/.tmux.conf"

# Ensure target file can be created before heredoc write.
if ! : > "$TMUX_CONF"; then
  echo "Warning: could not write $TMUX_CONF. Skipping tmux config + TPM setup." >&2
else

cat > "$TMUX_CONF" <<'EOF'
# Start windows and panes at 1, not 0
set -g base-index 1
setw -g pane-base-index 1

# Renumber windows sequentially after closing any of them
set -g renumber-windows on

# Session management improvements
# Use Ctrl-b + s to see session list with better formatting
bind-key s choose-tree -s -O name

# Show only windows from the current session
unbind-key w
bind-key w choose-window
# Keep a global tree view on Shift+W
bind-key W choose-tree -s -O name

# Keep Ctrl-b + 1..9 for default window switching.
# Session switching is available on Ctrl-b + F1..F9.
bind-key F1 switch-client -t 0
bind-key F2 switch-client -t 1
bind-key F3 switch-client -t 2
bind-key F4 switch-client -t 3
bind-key F5 switch-client -t 4
bind-key F6 switch-client -t 5
bind-key F7 switch-client -t 6
bind-key F8 switch-client -t 7
bind-key F9 switch-client -t 8

# AZERTY-friendly prefix bindings (same targets as 1..4)
bind-key '&' select-window -t 1
bind-key 'é' select-window -t 2
bind-key '"' select-window -t 3
bind-key "'" select-window -t 4

# Quick window switching without prefix
bind -n M-1 select-window -t 1
bind -n M-2 select-window -t 2
bind -n M-3 select-window -t 3
bind -n M-4 select-window -t 4
bind -n M-h previous-window
bind -n M-l next-window

# Quick session creation with meaningful names + 4-window workspace
bind-key C-n command-prompt -p "New session name:" "new-session -d -s %1 -c #{pane_current_path} \; send-keys -t %1:1 'nvim .' C-m \; new-window -t %1:2 -c #{pane_current_path} \; send-keys -t %1:2 opencode C-m \; new-window -t %1:3 -c #{pane_current_path} \; new-window -t %1:4 -c #{pane_current_path} \; switch-client -t %1 \; select-window -t %1:1"

# Automatically switch to next available session when closing the current session
set-hook -g session-closed 'run-shell "tmux switch-client -n"'

# Disable auto layout hook (hook context is unreliable for target expansion)
set-hook -gu session-created
set-hook -gu after-new-session

#set -g mouse on

# List of plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'sainnhe/tmux-fzf'

# Keep plugin launcher on Shift+F, and use prefix+f for direct session switching
set-environment -g TMUX_FZF_LAUNCH_KEY "F"
bind-key f run-shell -b "~/.tmux/plugins/tmux-fzf/scripts/session.sh switch"

# Initialize TMUX plugin manager (keep this line at the very bottom of tmux.conf)
run '~/.tmux/plugins/tpm/tpm'
EOF

# --- TPM: auto-install plugins non-interactively ---
# Start a temporary tmux server/session so TPM can run
tmux start-server

# Create a throwaway session (detached)
tmux new-session -d -s __tpm__ || true

# Source the config (so TPM sees the @plugin lines)
tmux source-file "$TMUX_CONF"

# Install plugins (clones them into ~/.tmux/plugins)
"$USER_HOME/.tmux/plugins/tpm/bin/install_plugins" || true

# (Optional) Update plugins
# ~/.tmux/plugins/tpm/bin/update_plugins all || true

# Cleanup
tmux kill-session -t __tpm__ 2>/dev/null || true
fi

echo "Done. Note: you may need to log out and back in for the fish login shell change to take effect."
