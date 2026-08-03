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

function Get-TemurinJdkHome($major) {
    $root = Join-Path $env:ProgramFiles "Eclipse Adoptium"
    if (-not (Test-Path $root -PathType Container)) {
        throw "Temurin JDK $major is missing. Re-run install.ps1 from an elevated PowerShell."
    }
    $jdkHome = Get-ChildItem $root -Directory -Filter "jdk-$major*" -ErrorAction SilentlyContinue |
        ForEach-Object {
            $match = [regex]::Match($_.Name, '^jdk-(\d+(?:\.\d+){0,3})')
            if ($match.Success) {
                [pscustomobject]@{ Path = $_.FullName; Version = [version]$match.Groups[1].Value }
            }
        } |
        Sort-Object Version -Descending |
        Select-Object -First 1 -ExpandProperty Path
    if (-not $jdkHome) {
        throw "Temurin JDK $major is missing. Re-run install.ps1 from an elevated PowerShell."
    }
    return $jdkHome
}

function Get-PythonHome {
    $root = Join-Path $env:LOCALAPPDATA "Programs\Python"
    $pythonInstallHome = Get-ChildItem $root -Directory -Filter "Python3*" -ErrorAction SilentlyContinue |
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
    if (-not $pythonInstallHome) {
        throw "Python 3 is missing. Re-run install.ps1 from an elevated PowerShell."
    }
    return $pythonInstallHome
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
    $foundChdir = $false
    $updated = foreach ($line in $lines) {
        if ($line -match '^\s*chdir\s*=') {
            $setting
            $foundChdir = $true
        } else {
            $line
        }
    }

    if (-not $foundChdir) {
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

function Copy-ManagedFiles($sourcePaths, $destinationDir) {
    if (-not (Test-Path $destinationDir -PathType Container)) {
        New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    }

    foreach ($sourcePath in $sourcePaths) {
        if (-not (Test-Path $sourcePath)) {
            throw "Managed install source is missing: $sourcePath"
        }
        Copy-Item $sourcePath -Destination $destinationDir -Recurse -Force
    }
}

function Normalize-PathEntry($pathValue) {
    $expanded = [System.Environment]::ExpandEnvironmentVariables($pathValue).Trim()
    if ([string]::IsNullOrWhiteSpace($expanded)) {
        return $null
    }
    return $expanded.TrimEnd('\')
}

function Add-UserPathEntry($entry) {
    $entry = Normalize-PathEntry([System.IO.Path]::GetFullPath($entry))
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $entries = if ([string]::IsNullOrWhiteSpace($userPath)) { @() } else { $userPath -split ';' }
    $alreadyPresent = $false
    foreach ($existing in $entries) {
        $normalizedExisting = Normalize-PathEntry($existing)
        if (-not $normalizedExisting) {
            continue
        }
        if ([System.String]::Equals($normalizedExisting, $entry, [System.StringComparison]::OrdinalIgnoreCase)) {
            $alreadyPresent = $true
            break
        }
    }

    if (-not $alreadyPresent) {
        $updatedEntries = @($entries | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) + $entry
        [System.Environment]::SetEnvironmentVariable("Path", ($updatedEntries -join ';'), "User")
        Write-Done "Added $entry to the current user's PATH."
    } else {
        Write-Done "$entry is already present on the current user's PATH."
    }

    Refresh-Path
    $processEntries = ($env:Path -split ';') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $processHasEntry = $false
    foreach ($existing in $processEntries) {
        $normalizedExisting = Normalize-PathEntry($existing)
        if ($normalizedExisting -and [System.String]::Equals($normalizedExisting, $entry, [System.StringComparison]::OrdinalIgnoreCase)) {
            $processHasEntry = $true
            break
        }
    }
    if (-not $processHasEntry) {
        $env:Path = "$entry;$env:Path"
    }
}

function Install-TemplateCommands {
    $installRoot = Join-Path $env:LOCALAPPDATA "Programs\cp-template"
    $binDir = Join-Path $installRoot "bin"

    if (Test-Path $installRoot) {
        Remove-Item $installRoot -Recurse -Force
    }

    Copy-ManagedFiles @(
        (Join-Path $PSScriptRoot "commands")
    ) $installRoot
    Copy-ManagedFiles @(
        (Join-Path $PSScriptRoot "templates")
    ) $installRoot
    Copy-ManagedFiles @(
        (Join-Path $PSScriptRoot "templatecpp.cmd"),
        (Join-Path $PSScriptRoot "templatejava.cmd"),
        (Join-Path $PSScriptRoot "templatepy.cmd")
    ) $binDir

    Add-UserPathEntry $binDir

    foreach ($command in @("templatecpp.cmd", "templatejava.cmd", "templatepy.cmd")) {
        if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
            throw "Installed template command is not available on PATH: $command"
        }
    }

    Write-Done "Installed template commands under $installRoot. New terminals will pick up PATH automatically."
}

Refresh-Path
$pythonHome = Get-PythonHome
$env:Path = "$pythonHome;$env:Path"

$configEntryPoint = Join-Path $env:LOCALAPPDATA "nvim\init.lua"
if (-not (Test-Path $configEntryPoint -PathType Leaf)) {
    throw "Neovim config entry point not found: $configEntryPoint. Run the elevated install phase first."
}

$bootstrapRunner = Join-Path $PSScriptRoot "nvim\lua\config\bootstrap_runner.lua"
if (-not (Test-Path $bootstrapRunner -PathType Leaf)) {
    throw "Bootstrap runner not found: $bootstrapRunner"
}

foreach ($command in @("git.exe", "nvim.exe", "gcc.exe", "g++.exe", "java.exe", "javac.exe", "python.exe", "tree-sitter.exe", "stylua.exe")) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "Required bootstrap tool is not on PATH: $command"
    }
}

& (Join-Path $pythonHome "python.exe") --version *> $null
if ($LASTEXITCODE -ne 0) {
    throw "python.exe is the Windows Store alias, not a working Python runtime. Re-run install.ps1 from an elevated PowerShell."
}

$jdk17 = Get-TemurinJdkHome 17
$jdk21 = Get-TemurinJdkHome 21
$jdk25 = Get-TemurinJdkHome 25
$env:JAVA_HOME = $jdk21
$env:Path = "$(Join-Path $jdk21 'bin');$env:Path"
Write-Done "Java projects target $jdk17; JDTLS runs on $jdk21; Minecraft 26.x toolchains can use $jdk25."

# tree-sitter defaults to Visual C++ on Windows when no compiler is specified.
# WinLibs is already installed, so make the parser build use that known toolchain.
$env:CC = "gcc"
$env:CXX = "g++"

Write-Step "Configuring Neovide startup behavior..."
Set-NeovideConfig

Write-Step "Aligning clangd with the active g++ toolchain..."
Set-ClangdConfig

Write-Step "Installing templatecpp/templatejava/templatepy for the current user..."
Install-TemplateCommands

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
