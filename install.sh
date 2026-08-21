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

case ":$PATH:" in
  *":$bin_dir:"*) ;;
  *)
    say "NOTE: $bin_dir is not on your PATH — add this to your shell rc:"
    # shellcheck disable=SC2016  # shown literally on purpose
    say '  export PATH="$HOME/.local/bin:$PATH"'
    ;;
esac

# Seed the fully commented config template (uncomment lines to override).
# The template itself must stay pure documentation (tests/test_config.sh
# asserts sourcing it changes nothing) — an nri-specific active default
# is appended separately, below, after the copy.
cfg_dir="${TISS_CONFIG:-$HOME/.config/nri}"
if [ ! -f "$cfg_dir/config.sh" ]; then
  mkdir -p "$cfg_dir"
  cp "$dest/etc/config.sh.example" "$cfg_dir/config.sh"
  say "created $cfg_dir/config.sh (all defaults, documented — uncomment to override)"
fi

# nri default: pile packages (nri +name) come from the org's dedicated
# distribution repo, not wherever this install happened to be cloned
# from. Idempotent (grep guard, anchored so it doesn't match the
# template's own commented-out doc line for the same var) so re-running
# install.sh never duplicates or clobbers a value you've since changed
# by hand.
if ! grep -qE '^[[:space:]]*cfg[[:space:]]+TISS_TREES_REPO' "$cfg_dir/config.sh" 2>/dev/null; then
  {
    echo ""
    echo "## -- nri defaults -------------------------------------------------------------"
    echo 'cfg TISS_TREES_REPO "https://github.com/Newton-Research-Inc/.tiss.git"'
  } >>"$cfg_dir/config.sh"
  say "set TISS_TREES_REPO default in $cfg_dir/config.sh"
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
