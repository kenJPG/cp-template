# ============================================================================
# install.ps1 - Windows-native setup
# ============================================================================
# Run from an ELEVATED (Administrator) PowerShell prompt:
#
#     powershell -ExecutionPolicy Bypass -File .\install.ps1
#
# Everything runs natively on Windows -- no WSL, no Linux VM, no second OS to
# maintain. Idempotent: every step checks what's already present and skips it,
# so it's safe to re-run any time (e.g. after `git pull`).
#
# What this installs (all via winget, so nothing here hand-downloads a binary
# from GitHub releases -- one less thing to go stale):
#   - Neovim                (editor; the Windows build also bundles win32yank,
#                             so clipboard integration needs zero extra setup)
#   - Typst                 (the compiler CLI, for manual/final exports)
#   - Tinymist               (Typst LSP: completion, diagnostics, formatting)
#   - clangd                 (C++ LSP, for competitive-programming autocomplete)
#   - WinLibs (GCC/MinGW)   (a REAL g++, not clang -- see note below)
#   - ripgrep, fd           (used by LazyVim's fuzzy pickers)
#
# Why real GCC and not clang/LLVM for compiling: competitive-programming judges
# (Codeforces etc.) run GCC, and contest templates lean on GCC-only features --
# `#include <bits/stdc++.h>` and `#pragma GCC optimize/target` -- that clang
# doesn't support the same way. clangd (LSP) and g++ (compiler) are two
# separate tools here on purpose: clangd for editor diagnostics, real GCC for
# the actual judge-compatible compile.
# ============================================================================

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Skip($msg) { Write-Host "    (skip) $msg" -ForegroundColor DarkGray }
function Write-Done($msg) { Write-Host "    [ok]  $msg" -ForegroundColor Green }

# ----------------------------------------------------------------------------
# Helper: is a winget package installed? Install/upgrade it if not.
# ----------------------------------------------------------------------------
function Test-WingetInstalled($id) {
    $out = winget list --id $id --exact --accept-source-agreements 2>$null | Out-String
    return $out -match [regex]::Escape($id)
}

function Install-WingetPackage($id, $name) {
    if (Test-WingetInstalled $id) {
        Write-Skip "$name already installed ($id)."
        return
    }
    Write-Step "Installing $name ($id)..."
    winget install --id $id --exact --silent `
        --accept-package-agreements --accept-source-agreements
    Write-Done "$name installed."
}

# ----------------------------------------------------------------------------
# 0. Sanity: winget must exist (ships with modern Windows 11; if missing, the
#    user needs App Installer from the Microsoft Store).
# ----------------------------------------------------------------------------
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget not found. Install 'App Installer' from the Microsoft Store, then re-run."
}

# ----------------------------------------------------------------------------
# 1. Toolchain, all via winget.
# ----------------------------------------------------------------------------
Install-WingetPackage "Neovim.Neovim"                     "Neovim"
Install-WingetPackage "Typst.Typst"                        "Typst"
Install-WingetPackage "Myriad-Dreamin.Tinymist"            "Tinymist (Typst LSP)"
Install-WingetPackage "LLVM.clangd"                        "clangd (C++ LSP)"
Install-WingetPackage "BrechtSanders.WinLibs.POSIX.UCRT"   "WinLibs (real GCC/g++)"
Install-WingetPackage "BurntSushi.ripgrep.MSVC"            "ripgrep"
Install-WingetPackage "sharkdp.fd"                         "fd"

# ----------------------------------------------------------------------------
# 2. Symlink nvim/ from this repo to Neovim's Windows config location so edits
#    in the repo take effect live. Requires elevation (already required above)
#    since Windows restricts symlink creation to admins by default.
# ----------------------------------------------------------------------------
Write-Step "Linking Neovim config..."
$nvimConfigDir = Join-Path $env:LOCALAPPDATA "nvim"
$repoNvimDir = Join-Path $ScriptDir "nvim"

$existingConfig = Get-Item $nvimConfigDir -ErrorAction SilentlyContinue
# .Target can come back as an array on some PowerShell versions, so use
# -contains (works for both a bare string and a single-element array) rather
# than -eq, which would silently do the wrong thing against an array.
$alreadyLinked = $existingConfig -and
                 $existingConfig.LinkType -eq "SymbolicLink" -and
                 ($existingConfig.Target -contains $repoNvimDir)

if ($alreadyLinked) {
    Write-Skip "$nvimConfigDir already links to this repo."
} else {
    if (Test-Path $nvimConfigDir) {
        $backup = "$nvimConfigDir.bak-$(Get-Date -Format 'yyyyMMddHHmmss')"
        Write-Step "Existing Neovim config found -- backing up to $backup"
        Move-Item $nvimConfigDir $backup
    }
    New-Item -ItemType SymbolicLink -Path $nvimConfigDir -Target $repoNvimDir | Out-Null
    Write-Done "Linked $nvimConfigDir -> $repoNvimDir"
}

# ----------------------------------------------------------------------------
# 3. Bootstrap plugins non-interactively (lazy.nvim self-installs on first
#    launch once init.lua is in place; this just forces that + a full plugin
#    sync so the very first real launch isn't the one waiting on downloads).
#    A fresh PATH is needed in-process since winget just updated it for this
#    session's parent but not this already-running one.
# ----------------------------------------------------------------------------
Write-Step "Syncing Neovim plugins (first run may take a minute)..."
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path", "User")
nvim --headless "+Lazy! sync" +qa
Write-Done "Plugin sync attempted."

Write-Host "`n============================================================" -ForegroundColor Yellow
Write-Host " Setup complete." -ForegroundColor Yellow
Write-Host " Open a NEW terminal (so PATH changes apply) and run: nvim" -ForegroundColor Yellow
Write-Host "============================================================`n" -ForegroundColor Yellow
