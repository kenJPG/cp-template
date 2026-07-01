#!/usr/bin/env bash
# ============================================================================
# clipboard-bridge.sh — make the Windows clipboard reachable from WSL
# ============================================================================
# Why this exists: WSL does NOT share a clipboard with Windows natively. Neovim
# inside WSL therefore needs a Windows-side binary to actually write to / read
# from the OS clipboard. win32yank.exe (installed on the Windows side by
# windows/install.ps1) is that binary. Neovim auto-detects a `win32yank.exe` on
# PATH and uses it as its clipboard provider, which is what makes
# `clipboard=unnamedplus` (plain `y`/`p`) talk to the real Windows clipboard.
#
# This script finds win32yank.exe wherever winget put it and symlinks it into
# /usr/local/bin so it resolves from any WSL shell. Idempotent.
# ============================================================================

set -euo pipefail

LINK_TARGET="/usr/local/bin/win32yank.exe"

log()  { printf '    %s\n' "$*"; }
step() { printf '\n==> %s\n' "$*"; }

step "Setting up win32yank clipboard bridge"

# ----------------------------------------------------------------------------
# 0. Already resolvable? (Either we symlinked it before, or Windows PATH interop
#    already exposes it.) Nothing to do.
# ----------------------------------------------------------------------------
if command -v win32yank.exe >/dev/null 2>&1; then
  log "win32yank.exe already on PATH: $(command -v win32yank.exe)"
  exit 0
fi

# ----------------------------------------------------------------------------
# 1. Figure out the Windows username so we can look under the right profile.
#    Prefer asking Windows directly; fall back to scanning /mnt/*/Users.
# ----------------------------------------------------------------------------
WINUSER=""
if command -v cmd.exe >/dev/null 2>&1; then
  # `cmd.exe /c echo %USERNAME%` prints the Windows user; strip the CR.
  WINUSER="$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r\n' || true)"
fi

# ----------------------------------------------------------------------------
# 2. Search the usual winget install locations for win32yank.exe.
#    winget commonly drops a shim under ...\WinGet\Links and the real binary
#    under ...\WinGet\Packages\<pkg>\... — we check both, across any /mnt drive.
# ----------------------------------------------------------------------------
FOUND=""

# Build a list of candidate user profile roots to search.
declare -a ROOTS=()
for drive in /mnt/*; do
  [ -d "$drive/Users" ] || continue
  if [ -n "$WINUSER" ] && [ -d "$drive/Users/$WINUSER" ]; then
    ROOTS+=("$drive/Users/$WINUSER")
  fi
  # Also add every user profile as a fallback (skip system profiles).
  for u in "$drive"/Users/*; do
    [ -d "$u" ] || continue
    case "$(basename "$u")" in
      Public|Default|"Default User"|"All Users") continue ;;
    esac
    ROOTS+=("$u")
  done
done

# Preferred, fast paths first (the winget Links shim), then a deeper search.
for root in "${ROOTS[@]}"; do
  cand="$root/AppData/Local/Microsoft/WinGet/Links/win32yank.exe"
  if [ -x "$cand" ] || [ -f "$cand" ]; then
    FOUND="$cand"; break
  fi
done

if [ -z "$FOUND" ]; then
  for root in "${ROOTS[@]}"; do
    pkgdir="$root/AppData/Local/Microsoft/WinGet/Packages"
    [ -d "$pkgdir" ] || continue
    # -maxdepth keeps this from crawling the entire profile.
    hit="$(find "$pkgdir" -maxdepth 4 -iname 'win32yank.exe' -type f 2>/dev/null | head -n1 || true)"
    if [ -n "$hit" ]; then FOUND="$hit"; break; fi
  done
fi

# ----------------------------------------------------------------------------
# 3. Symlink it into /usr/local/bin so every WSL shell can find it.
# ----------------------------------------------------------------------------
if [ -z "$FOUND" ]; then
  cat >&2 <<'EOF'
    Could not find win32yank.exe under any WinGet install location.
    Make sure windows/install.ps1 ran and installed it
    (winget install --id equalsraf.win32yank), then re-run this script.
    Clipboard sync will not work until win32yank.exe is on PATH.
EOF
  exit 1
fi

log "Found win32yank.exe at: $FOUND"
sudo ln -sf "$FOUND" "$LINK_TARGET"
log "Linked -> $LINK_TARGET"

# Verify Neovim will pick it up.
if command -v win32yank.exe >/dev/null 2>&1; then
  log "OK: win32yank.exe now resolves from PATH."
  log 'Tip: fully restart Neovim after this so it picks up the clipboard provider.'
else
  log "WARNING: $LINK_TARGET created but not on PATH — check that /usr/local/bin is in \$PATH."
fi
