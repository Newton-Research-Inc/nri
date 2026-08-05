#!/usr/bin/env bash
#
# nri installer — safe to curl | bash, safe to re-run (updates in place):
#
#   curl -fsSL https://raw.githubusercontent.com/Newton-Research-Inc/nri/nri/install.sh | bash
#
# Installs to $XDG_DATA_HOME/nri/repo (default ~/.local/share/nri/repo)
# and symlinks the dispatcher into ~/.local/bin. Pass a name to install
# under a different command name:
#
#   ... | bash -s -- x     # installs as `x`
#
set -euo pipefail

name="${1:-nri}"
repo_url="https://github.com/Newton-Research-Inc/nri.git"
dest="${XDG_DATA_HOME:-$HOME/.local/share}/nri/repo"
bin_dir="$HOME/.local/bin"

say() { printf '\033[36m[nri install]\033[0m %s\n' "$*" >&2; }

command -v git >/dev/null 2>&1 || {
  say "git is required — install it first."
  exit 1
}

if [ -d "$dest/.git" ]; then
  say "updating existing install in $dest"
  git -C "$dest" pull --ff-only
else
  say "cloning into $dest"
  mkdir -p "$(dirname "$dest")"
  git clone --depth 1 "$repo_url" "$dest"
fi

mkdir -p "$bin_dir"
ln -sf "$dest/bin/nri" "$bin_dir/$name"
say "linked: $bin_dir/$name"

rc="$HOME/.bashrc"
case "${SHELL:-}" in */zsh) rc="$HOME/.zshrc" ;; esac

case ":$PATH:" in
  *":$bin_dir:"*) ;;
  *)
    if grep -qF '.local/bin' "$rc" 2>/dev/null; then
      say "NOTE: $bin_dir is in $rc but not active in this shell — restart it or: source $rc"
    elif [ -r /dev/tty ]; then
      printf '\033[36m[nri install]\033[0m add %s to PATH in %s? [Y/n] ' "$bin_dir" "$rc" >&2
      reply=""
      read -r reply </dev/tty || reply="n"
      case "$reply" in
        [nN]*)
          say "skipped — add this to your shell rc yourself:"
          # shellcheck disable=SC2016  # shown literally on purpose
          say '  export PATH="$HOME/.local/bin:$PATH"'
          ;;
        *)
          # shellcheck disable=SC2016  # $HOME kept literal so it survives synced dotfiles
          printf '\n# added by nri installer\nexport PATH="$HOME/.local/bin:$PATH"\n' >>"$rc"
          say "added to $rc — restart your shell or: source $rc"
          ;;
      esac
    else
      say "NOTE: $bin_dir is not on your PATH — add this to your shell rc:"
      # shellcheck disable=SC2016  # shown literally on purpose
      say '  export PATH="$HOME/.local/bin:$PATH"'
    fi
    ;;
esac

# Seed the fully commented config template (uncomment lines to override).
cfg_dir="${TISS_CONFIG:-$HOME/.config/nri}"
if [ ! -f "$cfg_dir/config.sh" ]; then
  mkdir -p "$cfg_dir"
  cp "$dest/etc/config.sh.example" "$cfg_dir/config.sh"
  say "created $cfg_dir/config.sh (all defaults, documented — uncomment to override)"
fi

# Seed the suggested shortcuts set the same way (uncomment to activate).
if [ ! -f "$cfg_dir/shortcuts" ]; then
  mkdir -p "$cfg_dir"
  cp "$dest/etc/shortcuts.example" "$cfg_dir/shortcuts"
  say "created $cfg_dir/shortcuts (muscle-memory names, commented — see: $name shortcuts)"
fi

say "checking your setup..."
"$bin_dir/$name" doctor || true

say "done. next steps:"
say "  $name                          # explore the command tree"
say "  eval \"\$($name init)\"           # rc line: mise/brew activation, shortcut shims"
say "  eval \"\$($name completion zsh)\"   # tab completion (~/.zshrc, after compinit)"
