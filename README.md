# devenv

Portable terminal/editor setup for SSH hosts.

It installs and links:

- `tmux` config (`~/.tmux.conf`)
- Neovim config (`~/.config/nvim`)
- OpenCode config (`~/.config/opencode`)

## Quick start

### 1) Local repo usage

```sh
./bootstrap.sh
```

### 2) Remote "curl | sh" usage

```sh
curl -fsSL https://raw.githubusercontent.com/Dr0p42/devenv/main/install.sh | sh
```

Optional environment variables:

- `DEVENV_REPO_URL` (default: `https://github.com/Dr0p42/devenv.git`)
- `DEVENV_BRANCH` (default: `main`)
- `DEVENV_HOME` (default: `~/.local/share/devenv`)
- `DEVENV_SKIP_PACKAGES=1` to only link configs

Example:

```sh
curl -fsSL https://raw.githubusercontent.com/Dr0p42/devenv/main/install.sh \
  | DEVENV_BRANCH=main sh
```

## What bootstrap does

1. Detects available package manager.
2. Tries to install base packages (`tmux`, `neovim`, `git`, `curl`, `ripgrep`, `fd-find`).
3. Creates backup copies of existing config files/directories.
4. Installs OpenCode CLI when `brew`, `npm`, or `bun` is available.
5. Symlinks configs from this repository into your home directory.

## Notes

- Existing files are backed up with a `.backup.<timestamp>` suffix.
- If package install permissions are missing, bootstrap continues and only links configs.
- On some distros, `fd-find` binary is named `fdfind`; this setup still works.
