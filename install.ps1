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
#   - Git                   (needed for cloning and for lazy.nvim bootstrap)
#   - Neovim                (editor; the Windows build also bundles win32yank,
#                             so clipboard integration needs zero extra setup)
#   - Neovide               (GUI frontend for Neovim -- the recommended way to
#                             launch. Running the TUI inside legacy cmd/conhost
#                             is glitchy: no Nerd Font glyphs, flaky terminal
#                             input. Neovide is the modern GVim equivalent.)
#   - JetBrainsMono Nerd Font (LazyVim's UI icons need a Nerd Font or they
#                             render as ?-in-diamond boxes)
#   - Typst                 (the compiler CLI, for manual/final exports)
#   - Tinymist               (Typst LSP: completion, diagnostics, formatting)
#   - clangd                 (C++ LSP, for competitive-programming autocomplete)
#   - WinLibs (GCC/MinGW)   (a REAL g++, not clang -- see note below)
#   - Temurin JDK 17         (generic Java project compiler/runtime target)
#   - Temurin JDK 21         (runtime required by the current Java language server)
#   - Temurin JDK 25         (current Minecraft 26.x mod toolchains)
#   - Python 3.13            (Python runtime; editor tooling is isolated by Mason)
#   - tree-sitter CLI       (parser compiler used by nvim-treesitter)
#   - StyLua                (formatter used for this Neovim config)
#   - ripgrep, fd           (used by LazyVim's fuzzy pickers)
#
# Why real GCC and not clang/LLVM for compiling: competitive-programming judges
# (Codeforces etc.) run GCC, and contest templates lean on GCC-only features --
# `#include <bits/stdc++.h>` and `#pragma GCC optimize/target` -- that clang
# doesn't support the same way. clangd (LSP) and g++ (compiler) remain separate
# tools, but bootstrap.ps1 makes clangd query the active g++ for the same MinGW
# standard-library headers used by judge-compatible builds.
# ============================================================================

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Skip($msg) { Write-Host "    (skip) $msg" -ForegroundColor DarkGray }
function Write-Done($msg) { Write-Host "    [ok]  $msg" -ForegroundColor Green }

function Refresh-Path {
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

function Invoke-NativeChecked($label, $command, $arguments) {
    & $command @arguments
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "$label failed with exit code $exitCode."
    }
}

function Get-TrustedWingetPath {
    $package = Get-AppxPackage -Name "Microsoft.DesktopAppInstaller" -AllUsers |
        Sort-Object Version -Descending |
        Select-Object -First 1
    if (-not $package) {
        throw "Windows Package Manager is missing. Install 'App Installer' from the Microsoft Store, then re-run."
    }

    $windowsAppsRoot = [System.IO.Path]::GetFullPath((Join-Path $env:ProgramFiles "WindowsApps")).TrimEnd('\') + '\'
    $wingetPath = [System.IO.Path]::GetFullPath((Join-Path $package.InstallLocation "winget.exe"))
    if (-not $wingetPath.StartsWith($windowsAppsRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing unexpected winget path outside protected WindowsApps: $wingetPath"
    }
    if (-not (Test-Path $wingetPath -PathType Leaf)) {
        throw "Windows Package Manager executable not found in App Installer: $wingetPath"
    }

    $signature = Get-AuthenticodeSignature $wingetPath
    if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
        throw "Refusing winget with invalid Authenticode signature at $wingetPath (status: $($signature.Status))."
    }
    return $wingetPath
}

# ----------------------------------------------------------------------------
# Helper: is a winget package installed? Install it if not.
# ----------------------------------------------------------------------------
function Test-WingetInstalled($id) {
    & $script:WingetPath list --id $id --exact --accept-source-agreements *> $null
    switch ([int]$LASTEXITCODE) {
        0 { return $true }
        -1978335212 { return $false } # APPINSTALLER_CLI_ERROR_NO_APPLICATIONS_FOUND
        default { throw "winget list failed for $id with exit code $LASTEXITCODE." }
    }
}

function Install-WingetPackage($id, $name) {
    if (Test-WingetInstalled $id) {
        Write-Skip "$name already installed ($id)."
        return
    }
    Write-Step "Installing $name ($id)..."
    Invoke-NativeChecked "winget install for $name" $script:WingetPath @(
        "install", "--id", $id, "--exact", "--silent",
        "--accept-package-agreements", "--accept-source-agreements"
    )
    Write-Done "$name installed."
}

function Get-TemurinJdkHome($major) {
    $root = Join-Path $env:ProgramFiles "Eclipse Adoptium"
    if (-not (Test-Path $root -PathType Container)) {
        return $null
    }
    return Get-ChildItem $root -Directory -Filter "jdk-$major*" -ErrorAction SilentlyContinue |
        ForEach-Object {
            $match = [regex]::Match($_.Name, '^jdk-(\d+(?:\.\d+){0,3})')
            if ($match.Success) {
                [pscustomobject]@{ Path = $_.FullName; Version = [version]$match.Groups[1].Value }
            }
        } |
        Sort-Object Version -Descending |
        Select-Object -First 1 -ExpandProperty Path
}

function Get-PythonHome {
    $root = Join-Path $env:LOCALAPPDATA "Programs\Python"
    return Get-ChildItem $root -Directory -Filter "Python3*" -ErrorAction SilentlyContinue |
        ForEach-Object {
            $match = [regex]::Match($_.Name, '^Python(\d)(\d+)$')
            if ($match.Success -and (Test-Path (Join-Path $_.FullName "python.exe") -PathType Leaf)) {
                [pscustomobject]@{
                    Path = $_.FullName
                    Version = [version]("$($match.Groups[1].Value).$($match.Groups[2].Value)")
                }
            }
        } |
        Sort-Object Version -Descending |
        Select-Object -First 1 -ExpandProperty Path
}

function Get-MissingTools {
    $checks = @(
        @{ Name = "git";      Command = "git.exe" },
        @{ Name = "nvim";     Command = "nvim.exe" },
        @{ Name = "neovide";  Command = "neovide.exe" },
        @{ Name = "gcc";      Command = "gcc.exe" },
        @{ Name = "g++";      Command = "g++.exe" },
        @{ Name = "clangd";   Command = "clangd.exe" },
        @{ Name = "java";     Command = "java.exe" },
        @{ Name = "javac";    Command = "javac.exe" },
        @{ Name = "python";   Command = "python.exe" },
        @{ Name = "typst";    Command = "typst.exe" },
        @{ Name = "tinymist"; Command = "tinymist.exe" },
        @{ Name = "tree-sitter"; Command = "tree-sitter.exe" },
        @{ Name = "stylua";   Command = "stylua.exe" },
        @{ Name = "rg";       Command = "rg.exe" },
        @{ Name = "fd";       Command = "fd.exe" },
        @{ Name = "curl";     Command = "curl.exe" }
    )

    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($check in $checks) {
        if (-not (Get-Command $check.Command -ErrorAction SilentlyContinue)) {
            $missing.Add($check.Name)
        }
    }

    $pythonHome = Get-PythonHome
    if ($pythonHome) {
        & (Join-Path $pythonHome "python.exe") --version *> $null
        if ($LASTEXITCODE -ne 0) {
            $missing.Add("Python 3.13 runtime")
        }
    } else {
        $missing.Add("Python 3.13 runtime")
    }

    if (-not (Get-TemurinJdkHome 17)) {
        $missing.Add("Temurin JDK 17")
    }
    if (-not (Get-TemurinJdkHome 21)) {
        $missing.Add("Temurin JDK 21")
    }
    if (-not (Get-TemurinJdkHome 25)) {
        $missing.Add("Temurin JDK 25")
    }

    return $missing
}

# ----------------------------------------------------------------------------
# 0. Sanity: winget must exist (ships with modern Windows 11; if missing, the
#    user needs App Installer from the Microsoft Store).
# ----------------------------------------------------------------------------
$script:WingetPath = Get-TrustedWingetPath
Write-Done "Using trusted Windows Package Manager at $script:WingetPath."

# ----------------------------------------------------------------------------
# 1. Toolchain, all via winget.
# ----------------------------------------------------------------------------
Install-WingetPackage "Neovim.Neovim"                     "Neovim"
Install-WingetPackage "Neovide.Neovide"                    "Neovide (GUI for Neovim)"
Install-WingetPackage "Git.Git"                            "Git"
Install-WingetPackage "DEVCOM.JetBrainsMonoNerdFont"       "JetBrainsMono Nerd Font"
Install-WingetPackage "Typst.Typst"                        "Typst"
Install-WingetPackage "Myriad-Dreamin.Tinymist"            "Tinymist (Typst LSP)"
Install-WingetPackage "LLVM.clangd"                        "clangd (C++ LSP)"
Install-WingetPackage "BrechtSanders.WinLibs.POSIX.UCRT"   "WinLibs (real GCC/g++)"
Install-WingetPackage "EclipseAdoptium.Temurin.17.JDK"     "Temurin JDK 17 (Java project runtime)"
Install-WingetPackage "EclipseAdoptium.Temurin.21.JDK"     "Temurin JDK 21 (Java language-server runtime)"
Install-WingetPackage "EclipseAdoptium.Temurin.25.JDK"     "Temurin JDK 25 (current Minecraft mod runtime/toolchain)"
Install-WingetPackage "Python.Python.3.13"                  "Python 3.13"
Install-WingetPackage "tree-sitter.tree-sitter-cli"        "tree-sitter CLI"
Install-WingetPackage "JohnnyMorganz.StyLua"               "StyLua"
Install-WingetPackage "BurntSushi.ripgrep.MSVC"            "ripgrep"
Install-WingetPackage "sharkdp.fd"                         "fd"

Write-Step "Refreshing PATH and validating required tools..."
Refresh-Path
$missingTools = Get-MissingTools
if ($missingTools.Count -gt 0) {
    throw "Missing required tools after installation: $($missingTools -join ', '). Open a new elevated PowerShell, confirm the winget installs above succeeded, and re-run install.ps1."
}
Write-Done "All required tools are on PATH."

# ----------------------------------------------------------------------------
# 2. Symlink nvim/ from this repo to Neovim's Windows config location so edits
#    in the repo take effect live. Requires elevation (already required above)
#    since Windows restricts symlink creation to admins by default.
# ----------------------------------------------------------------------------
Write-Step "Linking Neovim config..."
$nvimConfigDir = Join-Path $env:LOCALAPPDATA "nvim"
$repoNvimDir = Join-Path $ScriptDir "nvim"

$localAppDataRoot = [System.IO.Path]::GetFullPath($env:LOCALAPPDATA).TrimEnd('\')
$nvimConfigDir = [System.IO.Path]::GetFullPath($nvimConfigDir)
$repoNvimDir = [System.IO.Path]::GetFullPath($repoNvimDir)

if (-not [System.IO.Path]::GetDirectoryName($nvimConfigDir).Equals(
        $localAppDataRoot,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
    throw "Refusing to modify unexpected config path: $nvimConfigDir"
}

if (-not (Test-Path $repoNvimDir -PathType Container)) {
    throw "Repository Neovim config not found: $repoNvimDir"
}

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
        if (($existingConfig.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Refusing to replace unexpected symlink/junction at $nvimConfigDir. Remove it manually after verifying its target, then re-run."
        }
        $backup = "$nvimConfigDir.bak-$(Get-Date -Format 'yyyyMMddHHmmss')"
        Write-Step "Existing Neovim config found -- backing up to $backup"
        Move-Item $nvimConfigDir $backup
    }
    New-Item -ItemType SymbolicLink -Path $nvimConfigDir -Target $repoNvimDir | Out-Null
    Write-Done "Linked $nvimConfigDir -> $repoNvimDir"
}

Write-Host "`n============================================================" -ForegroundColor Yellow
Write-Host " Administrator phase complete." -ForegroundColor Yellow
Write-Host " Returning to the normal user for plugin bootstrap..." -ForegroundColor Yellow
Write-Host "============================================================`n" -ForegroundColor Yellow
