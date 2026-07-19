# ============================================================================
# bootstrap.ps1 - unprivileged Neovim plugin/parser bootstrap
# ============================================================================
# install.cmd runs this after the elevated machine-setup phase. Keep this script
# unprivileged: Lazy, Mason, and parser code belongs under the user's data dir.
# ============================================================================

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Done($msg) { Write-Host "    [ok]  $msg" -ForegroundColor Green }

function Refresh-Path {
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

function Invoke-NvimChecked($label, $action) {
    $env:CP_TEMPLATE_BOOTSTRAP_ACTION = $action
    & nvim --headless -u $configEntryPoint -l $bootstrapRunner
    if ($LASTEXITCODE -ne 0) {
        throw "$label failed with exit code $LASTEXITCODE."
    }
}

function Restore-LockFile($path, $bytes) {
    [System.IO.File]::WriteAllBytes($path, $bytes)
}

function Set-NeovideConfig {
    $desktop = [System.Environment]::GetFolderPath("Desktop")
    if ([string]::IsNullOrWhiteSpace($desktop)) {
        throw "Windows Desktop directory could not be resolved."
    }

    $configDir = Join-Path $env:APPDATA "neovide"
    $configPath = Join-Path $configDir "config.toml"
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null

    $escapedDesktop = $desktop.Replace('\', '\\').Replace('"', '\"')
    $setting = "chdir = `"$escapedDesktop`""
    $lines = if (Test-Path $configPath) { [System.IO.File]::ReadAllLines($configPath) } else { @() }
    $found = $false
    $updated = foreach ($line in $lines) {
        if ($line -match '^\s*chdir\s*=') {
            $setting
            $found = $true
        } else {
            $line
        }
    }

    if (-not $found) {
        $updated = @($setting) + @($updated)
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($configPath, [string[]]$updated, $utf8NoBom)
    Write-Done "Neovide will start in $desktop."
}

function Set-ClangdConfig {
    $gxx = (Get-Command g++.exe -ErrorAction Stop).Source.Replace('\', '/')
    $yamlGxx = $gxx.Replace("'", "''")
    $configDir = Join-Path $env:LOCALAPPDATA "clangd"
    $configPath = Join-Path $configDir "config.yaml"
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null

    $startMarker = "# >>> cp-template managed clangd config"
    $endMarker = "# <<< cp-template managed clangd config"
    $existing = if (Test-Path $configPath) { [System.IO.File]::ReadAllText($configPath) } else { "" }
    if ($existing.StartsWith("# Managed by cp-template/bootstrap.ps1")) {
        $existing = ""
    } else {
        $pattern = "(?ms)^$([regex]::Escape($startMarker))\r?\n.*?^$([regex]::Escape($endMarker))\r?\n?"
        $existing = [regex]::Replace($existing, $pattern, "").TrimEnd()
    }

    $managed = @(
        $startMarker
        "---"
        "CompileFlags:"
        "  Compiler: '$yamlGxx'"
        "  Add: [-std=gnu++20]"
        "  BuiltinHeaders: Clangd"
        $endMarker
    ) -join [Environment]::NewLine
    $content = if ($existing) { $existing + [Environment]::NewLine + $managed + [Environment]::NewLine } else { $managed + [Environment]::NewLine }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($configPath, $content, $utf8NoBom)
    Write-Done "clangd will query $gxx for MinGW C++ headers."
}

Refresh-Path

$configEntryPoint = Join-Path $env:LOCALAPPDATA "nvim\init.lua"
if (-not (Test-Path $configEntryPoint -PathType Leaf)) {
    throw "Neovim config entry point not found: $configEntryPoint. Run the elevated install phase first."
}

$bootstrapRunner = Join-Path $PSScriptRoot "nvim\lua\config\bootstrap_runner.lua"
if (-not (Test-Path $bootstrapRunner -PathType Leaf)) {
    throw "Bootstrap runner not found: $bootstrapRunner"
}

foreach ($command in @("git.exe", "nvim.exe", "gcc.exe", "g++.exe", "tree-sitter.exe", "stylua.exe")) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "Required bootstrap tool is not on PATH: $command"
    }
}

# tree-sitter defaults to Visual C++ on Windows when no compiler is specified.
# WinLibs is already installed, so make the parser build use that known toolchain.
$env:CC = "gcc"
$env:CXX = "g++"

Write-Step "Configuring Neovide startup behavior..."
Set-NeovideConfig

Write-Step "Aligning clangd with the active g++ toolchain..."
Set-ClangdConfig

$lockPath = Join-Path $PSScriptRoot "nvim\lazy-lock.json"
$lockBytes = [System.IO.File]::ReadAllBytes($lockPath)

try {
    Write-Step "Installing missing Neovim plugins and parsers as the normal user..."
    Invoke-NvimChecked "Neovim plugin installation" "install_missing"
    Restore-LockFile $lockPath $lockBytes
    Write-Done "Missing plugins and parsers installed."

    Write-Step "Restoring every plugin to the committed lockfile..."
    Invoke-NvimChecked "Neovim plugin restore" "restore_and_verify"
    Restore-LockFile $lockPath $lockBytes
    Write-Done "Plugins restored to pinned versions."

    Write-Step "Verifying a clean final Neovim startup..."
    Invoke-NvimChecked "Neovim bootstrap verification" "verify_only"
    Write-Done "Final startup verification completed."
} finally {
    Restore-LockFile $lockPath $lockBytes
}

Write-Host "`n============================================================" -ForegroundColor Yellow
Write-Host " Setup complete." -ForegroundColor Yellow
Write-Host " Launch 'Neovide' from the Start menu (recommended)," -ForegroundColor Yellow
Write-Host " or run 'nvim' from a NEW Windows Terminal window." -ForegroundColor Yellow
Write-Host "============================================================`n" -ForegroundColor Yellow
