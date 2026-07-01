# ============================================================================
# install.ps1 — Windows-side setup
# ============================================================================
# Run from an ELEVATED (Administrator) PowerShell prompt:
#
#     powershell -ExecutionPolicy Bypass -File .\windows\install.ps1
#
# Installs WSL2 + Ubuntu, WezTerm and win32yank, and drops the WezTerm config
# into place. Idempotent: it checks what's already present and skips it, so it's
# safe to re-run. After this finishes, reboot if it asks you to, then open
# WezTerm (which lands you in Ubuntu) and run wsl/install.sh from there.
# ============================================================================

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Skip($msg) { Write-Host "    (skip) $msg" -ForegroundColor DarkGray }
function Write-Done($msg) { Write-Host "    [ok]  $msg" -ForegroundColor Green }

$rebootNeeded = $false

# ----------------------------------------------------------------------------
# Helper: is a winget package installed?
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
# 1. WSL2 + Ubuntu.
#    `wsl --install` handles enabling the required Windows features, installing
#    the WSL2 kernel and pulling Ubuntu. If a distro is already registered we
#    leave it alone (don't clobber an existing Ubuntu).
# ----------------------------------------------------------------------------
Write-Step "Checking WSL / Ubuntu..."

# `wsl -l -q` lists installed distros (one per line). Empty / error => none yet.
$distros = @()
try { $distros = (wsl -l -q) 2>$null | Where-Object { $_ -and $_.Trim() -ne "" } } catch {}

$haveUbuntu = $distros | Where-Object { $_ -match "Ubuntu" }

if ($haveUbuntu) {
    Write-Skip "A WSL distro is already installed: $($haveUbuntu -join ', ')."
    # Make sure WSL2 is the default version for any future installs.
    try { wsl --set-default-version 2 | Out-Null } catch {}
} else {
    Write-Step "Installing WSL2 + Ubuntu (this enables Windows features under the hood)..."
    # --no-launch avoids blocking on the interactive first-run user setup; the
    # distro's initial account creation happens the first time you open it.
    wsl --install -d Ubuntu --no-launch
    Write-Done "WSL2 + Ubuntu install requested."
    $rebootNeeded = $true
}

# ----------------------------------------------------------------------------
# 2 & 3. WezTerm and win32yank via winget.
# ----------------------------------------------------------------------------
Install-WingetPackage "wez.wezterm"        "WezTerm"
Install-WingetPackage "equalsraf.win32yank" "win32yank"

# ----------------------------------------------------------------------------
# 4. Copy the WezTerm config to %USERPROFILE%\.wezterm.lua.
#    Back up any existing config the user already had (once).
# ----------------------------------------------------------------------------
Write-Step "Installing WezTerm config..."
$src = Join-Path $ScriptDir "wezterm.lua"
$dst = Join-Path $env:USERPROFILE ".wezterm.lua"

if (Test-Path $dst) {
    $existing = Get-Content $dst -Raw -ErrorAction SilentlyContinue
    $incoming = Get-Content $src -Raw
    if ($existing -eq $incoming) {
        Write-Skip ".wezterm.lua already up to date."
    } else {
        $backup = "$dst.bak"
        Copy-Item $dst $backup -Force
        Copy-Item $src $dst -Force
        Write-Done "Updated .wezterm.lua (previous version saved to $backup)."
    }
} else {
    Copy-Item $src $dst -Force
    Write-Done "Wrote $dst."
}

# ----------------------------------------------------------------------------
# 5. Next steps.
# ----------------------------------------------------------------------------
Write-Host "`n============================================================" -ForegroundColor Yellow
if ($rebootNeeded) {
    Write-Host " REBOOT REQUIRED" -ForegroundColor Yellow
    Write-Host " WSL was just installed. Restart Windows now, then:" -ForegroundColor Yellow
} else {
    Write-Host " NEXT STEPS" -ForegroundColor Yellow
}
Write-Host @"

  1. (If prompted above) reboot Windows.
  2. Open WezTerm — it drops you straight into Ubuntu (WSL).
     * On first launch Ubuntu will ask you to create a UNIX username/password.
  3. Clone this repo inside WSL (or cd into it if it lives under /mnt/c/...),
     then run the Linux-side installer:

         cd <this-repo>
         bash wsl/install.sh

"@ -ForegroundColor Yellow
Write-Host "============================================================`n" -ForegroundColor Yellow
