#!/usr/bin/env bash
# ============================================================================
# install.sh — WSL/Ubuntu-side setup (run AFTER windows/install.ps1 + reboot)
# ============================================================================
# Installs the whole Linux-side dev environment: base tools, latest Neovim,
# Typst, tinymist (Typst LSP), clangd (C++ LSP), poppler-utils, then symlinks
# this repo's nvim/ config into place and force-installs all Neovim plugins.
#
# Fully idempotent — safe to re-run. Every step checks whether the thing is
# already present (and recent enough) before doing any work. Nothing here errors
# out just because a tool is already installed.
#
#     bash wsl/install.sh
# ============================================================================

set -euo pipefail

# --- Locate ourselves so the nvim/ symlink points at the repo, wherever it's cloned.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
NVIM_SRC="$REPO_ROOT/nvim"

log()  { printf '    %s\n' "$*"; }
step() { printf '\n\033[36m==> %s\033[0m\n' "$*"; }
skip() { printf '    \033[90m(skip) %s\033[0m\n' "$*"; }
ok()   { printf '    \033[32m[ok]  %s\033[0m\n' "$*"; }
warn() { printf '    \033[33m[warn] %s\033[0m\n' "$*" >&2; }

ARCH="$(uname -m)"

# Friendly (non-fatal) note if we're somehow not on WSL — the clipboard bridge
# needs the Windows side, but the rest still installs fine.
if ! grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
  warn "This doesn't look like WSL. Continuing anyway; the clipboard bridge step may not apply."
fi

# ----------------------------------------------------------------------------
# 1. Base tools via apt. Only install what's actually missing.
# ----------------------------------------------------------------------------
step "Base packages (git, curl, unzip, build-essential, ripgrep, fd-find, clangd, poppler-utils, xz)"

# build-essential -> g++ for CP compiles; ripgrep + fd-find power Telescope/snacks
# pickers in LazyVim; clangd is the C++ LSP; poppler-utils gives pdfinfo, a hard
# dependency of typst-preview.nvim's inline image rendering; xz-utils unpacks the
# Typst tarball.
APT_PKGS=(git curl unzip build-essential ripgrep fd-find clangd poppler-utils xz-utils ca-certificates)

MISSING=()
for pkg in "${APT_PKGS[@]}"; do
  dpkg -s "$pkg" >/dev/null 2>&1 || MISSING+=("$pkg")
done

if [ "${#MISSING[@]}" -gt 0 ]; then
  log "Installing: ${MISSING[*]}"
  sudo apt-get update -y
  sudo apt-get install -y "${MISSING[@]}"
  ok "Base packages installed."
else
  skip "All base packages already present."
fi

# LazyVim expects the fd binary to be called `fd`; Debian/Ubuntu ships it as
# `fdfind`. Add a shim in /usr/local/bin if needed.
if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
  sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
  ok "Linked fdfind -> /usr/local/bin/fd (LazyVim expects 'fd')."
fi

# ----------------------------------------------------------------------------
# 2. Neovim — latest stable.
#    apt's Neovim is routinely too old for LazyVim. AppImage needs FUSE (absent
#    on default WSL) and the unstable PPA can lag, so the most reliable path is
#    the official pre-built tarball from the rolling "stable" release tag. We
#    install it under /opt and symlink the binary onto PATH.
#    Skip if a new-enough Neovim (>= 0.10) is already installed.
# ----------------------------------------------------------------------------
step "Neovim (latest stable)"

nvim_ok=false
if command -v nvim >/dev/null 2>&1; then
  # Parse "NVIM v0.10.2" -> major/minor.
  ver="$(nvim --version | head -n1 | grep -oE 'v[0-9]+\.[0-9]+' | tr -d 'v' || true)"
  major="${ver%%.*}"; minor="${ver##*.}"
  if [ -n "$ver" ] && { [ "$major" -gt 0 ] || [ "$minor" -ge 10 ]; }; then
    nvim_ok=true
    skip "Neovim $ver already installed (>= 0.10)."
  else
    log "Found Neovim $ver — too old for LazyVim, upgrading."
  fi
fi

if [ "$nvim_ok" = false ]; then
  # Release asset name changed over time: newer stable uses
  # nvim-linux-x86_64.tar.gz, older used nvim-linux64.tar.gz. Pick by arch and
  # try the modern name first, falling back to the legacy one.
  case "$ARCH" in
    x86_64)  ASSETS=("nvim-linux-x86_64.tar.gz" "nvim-linux64.tar.gz") ;;
    aarch64) ASSETS=("nvim-linux-arm64.tar.gz") ;;
    *)       ASSETS=("nvim-linux-x86_64.tar.gz") ;;
  esac

  tmp="$(mktemp -d)"
  got=""
  for asset in "${ASSETS[@]}"; do
    url="https://github.com/neovim/neovim/releases/download/stable/${asset}"
    log "Downloading $url"
    if curl -fL --retry 3 -o "$tmp/nvim.tar.gz" "$url"; then
      got="$asset"; break
    fi
  done

  if [ -z "$got" ]; then
    rm -rf "$tmp"
    warn "Could not download a Neovim release asset for $ARCH. Skipping Neovim install."
  else
    tar -xzf "$tmp/nvim.tar.gz" -C "$tmp"
    extracted="$(find "$tmp" -maxdepth 1 -type d -name 'nvim-linux*' | head -n1)"
    sudo rm -rf /opt/nvim
    sudo mv "$extracted" /opt/nvim
    sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
    rm -rf "$tmp"
    ok "Installed $(nvim --version | head -n1) to /opt/nvim."
  fi
fi

# ----------------------------------------------------------------------------
# 3. Typst — pre-built musl binary from the latest GitHub release.
#    Uses the /releases/latest/download/<asset> redirect so we don't need to
#    query the API for a version. Skip if already on PATH.
# ----------------------------------------------------------------------------
step "Typst"

if command -v typst >/dev/null 2>&1; then
  skip "Typst already installed: $(typst --version 2>/dev/null || echo present)."
else
  case "$ARCH" in
    x86_64)  TYPST_ASSET="typst-x86_64-unknown-linux-musl" ;;
    aarch64) TYPST_ASSET="typst-aarch64-unknown-linux-musl" ;;
    *)       TYPST_ASSET="typst-x86_64-unknown-linux-musl" ;;
  esac
  url="https://github.com/typst/typst/releases/latest/download/${TYPST_ASSET}.tar.xz"
  tmp="$(mktemp -d)"
  log "Downloading $url"
  if curl -fL --retry 3 -o "$tmp/typst.tar.xz" "$url"; then
    tar -xJf "$tmp/typst.tar.xz" -C "$tmp"
    bin="$(find "$tmp" -type f -name typst | head -n1)"
    sudo install -m 0755 "$bin" /usr/local/bin/typst
    ok "Installed Typst to /usr/local/bin/typst ($(typst --version 2>/dev/null))."
  else
    warn "Failed to download Typst. Skipping (tinymist/preview still usable if installed separately)."
  fi
  rm -rf "$tmp"
fi

# ----------------------------------------------------------------------------
# 4. tinymist (Typst LSP).
#    Prefer `cargo install --locked tinymist` when Rust is present (builds the
#    exact matching version); otherwise fall back to a prebuilt Linux binary
#    from the latest GitHub release. Best-effort: don't fail the whole script if
#    it doesn't work — Mason inside Neovim can also provide tinymist.
#    Skip if already on PATH.
# ----------------------------------------------------------------------------
step "tinymist (Typst LSP)"

if command -v tinymist >/dev/null 2>&1; then
  skip "tinymist already installed: $(command -v tinymist)."
elif command -v cargo >/dev/null 2>&1; then
  log "cargo found — building tinymist from source (this can take a while)..."
  if cargo install --locked tinymist; then
    ok "tinymist installed via cargo (ensure ~/.cargo/bin is on PATH)."
  else
    warn "cargo install tinymist failed; Neovim's Mason can install it instead."
  fi
else
  log "cargo not found — downloading a prebuilt tinymist binary."
  # Asset naming has varied across releases, so query the API and pick a Linux
  # x64 binary that isn't a .vsix/editor extension.
  case "$ARCH" in
    x86_64)  PAT='linux.*(x64|x86_64|amd64)' ;;
    aarch64) PAT='linux.*(arm64|aarch64)' ;;
    *)       PAT='linux.*(x64|x86_64|amd64)' ;;
  esac
  api="https://api.github.com/repos/Myriad-Dreamin/tinymist/releases/latest"
  dl_url="$(curl -fsSL "$api" 2>/dev/null \
    | grep -oE '"browser_download_url": *"[^"]+"' \
    | sed -E 's/.*"(https[^"]+)"/\1/' \
    | grep -viE '\.(vsix|sha256|json|txt)$' \
    | grep -iE "$PAT" \
    | head -n1 || true)"

  if [ -n "$dl_url" ]; then
    tmp="$(mktemp -d)"
    log "Downloading $dl_url"
    if curl -fL --retry 3 -o "$tmp/tinymist.dl" "$dl_url"; then
      # Asset may be a raw binary or an archive; handle the common cases.
      case "$dl_url" in
        *.tar.gz|*.tgz) tar -xzf "$tmp/tinymist.dl" -C "$tmp" ;;
        *.zip)          unzip -q "$tmp/tinymist.dl" -d "$tmp" ;;
      esac
      bin="$(find "$tmp" -type f -iname 'tinymist*' ! -iname '*.tar*' ! -iname '*.zip' | head -n1)"
      [ -z "$bin" ] && bin="$tmp/tinymist.dl"
      sudo install -m 0755 "$bin" /usr/local/bin/tinymist
      ok "Installed tinymist to /usr/local/bin/tinymist."
    else
      warn "Failed to download tinymist binary; Neovim's Mason can install it instead."
    fi
    rm -rf "$tmp"
  else
    warn "Could not locate a prebuilt tinymist asset; Neovim's Mason can install it instead."
  fi
fi

# ----------------------------------------------------------------------------
# 5 & 6. clangd + poppler-utils were installed with the base apt packages above.
#        (clangd = C++ LSP; poppler-utils = pdfinfo for typst-preview.)
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# 8. Symlink this repo's nvim/ to ~/.config/nvim so repo edits are live.
#    (Numbered per the task; done before the plugin sync so lazy has the config.)
# ----------------------------------------------------------------------------
step "Symlink nvim config -> ~/.config/nvim"

CONFIG_DIR="$HOME/.config"
NVIM_LINK="$CONFIG_DIR/nvim"
mkdir -p "$CONFIG_DIR"

if [ -L "$NVIM_LINK" ] && [ "$(readlink -f "$NVIM_LINK")" = "$(readlink -f "$NVIM_SRC")" ]; then
  skip "~/.config/nvim already points at this repo."
else
  if [ -e "$NVIM_LINK" ] || [ -L "$NVIM_LINK" ]; then
    backup="$NVIM_LINK.bak.$(date +%Y%m%d%H%M%S)"
    mv "$NVIM_LINK" "$backup"
    log "Moved existing ~/.config/nvim to $backup"
  fi
  ln -s "$NVIM_SRC" "$NVIM_LINK"
  ok "Linked $NVIM_SRC -> $NVIM_LINK"
fi

# ----------------------------------------------------------------------------
# 9. Clipboard bridge (win32yank). Best-effort — don't abort the script if the
#    Windows side isn't reachable yet.
# ----------------------------------------------------------------------------
step "Clipboard bridge"
if [ -f "$SCRIPT_DIR/clipboard-bridge.sh" ]; then
  bash "$SCRIPT_DIR/clipboard-bridge.sh" || warn "Clipboard bridge setup did not complete (see messages above)."
else
  warn "clipboard-bridge.sh not found next to install.sh; skipping."
fi

# ----------------------------------------------------------------------------
# 7. Force lazy.nvim to install/sync all plugins non-interactively so the first
#    real launch is instant. lazy.nvim self-bootstraps from init.lua.
# ----------------------------------------------------------------------------
step "Installing Neovim plugins (headless Lazy sync)"
if command -v nvim >/dev/null 2>&1; then
  # +Lazy! sync runs synchronously; then quit. Errors here are usually just
  # Mason tools still downloading — safe to ignore, they finish on first launch.
  nvim --headless "+Lazy! sync" +qa 2>&1 | tail -n 20 || warn "Headless Lazy sync reported issues (often fine — they resolve on first launch)."
  ok "Plugin sync attempted."
else
  warn "nvim not on PATH; open a new shell and run: nvim --headless \"+Lazy! sync\" +qa"
fi

# ----------------------------------------------------------------------------
# Done.
# ----------------------------------------------------------------------------
cat <<'EOF'

============================================================
 Setup complete.

 Open Neovim:   nvim somefile.cpp    (or a .typ file)

 Day-to-day:
   <F5>          build & run the current C++ file
   <F6>          :make the current C++ file
   <leader>tp    start Typst inline preview   (<leader> = space)
   <leader>tq    stop Typst preview
   <leader>c     toggle // comment on line/selection
   y / p         use the Windows clipboard directly (unnamedplus)

 If clipboard or Typst preview misbehave, see the
 Troubleshooting section in README.md.
============================================================
EOF
