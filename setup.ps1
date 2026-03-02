# setup.ps1 - Set up CP template vimrc on Windows
# Usage: .\setup.ps1 [-Force]
# Run as: powershell -ExecutionPolicy Bypass -File setup.ps1

param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "=== CP Template Setup for Windows ===" -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VimrcSource = Join-Path $ScriptDir "vimrc"
$HomeVimrc = "$env:USERPROFILE\_vimrc"
$HomeVim = "$env:USERPROFILE\.vim"

# Check if vimrc exists
if (-not (Test-Path $VimrcSource)) {
    Write-Host "ERROR: vimrc not found at $VimrcSource" -ForegroundColor Red
    exit 1
}

# Backup existing .vimrc
if (Test-Path $HomeVimrc -PathType Leaf) {
    if ($Force) {
        $backup = "$HomeVimrc.backup.$(Get-Date -Format 'yyyyMMdd')"
        Copy-Item $HomeVimrc $backup -Force
        Write-Host "Backed up existing .vimrc to $backup" -ForegroundColor Yellow
    } else {
        Write-Host "WARNING: .vimrc already exists. Use -Force to overwrite" -ForegroundColor Yellow
    }
}

# Create symlink or copy
if ($Force -or -not (Test-Path $HomeVimrc)) {
    # Copy instead of symlink for Windows compatibility
    Copy-Item $VimrcSource $HomeVimrc -Force
    Write-Host "Copied vimrc to $HomeVimrc" -ForegroundColor Green
}

# Create vim directories
if (-not (Test-Path $HomeVim)) {
    New-Item -ItemType Directory -Path $HomeVim -Force | Out-Null
}
if (-not (Test-Path "$HomeVim\undodir")) {
    New-Item -ItemType Directory -Path "$HomeVim\undodir" -Force | Out-Null
}
if (-not (Test-Path "$HomeVim\templates")) {
    New-Item -ItemType Directory -Path "$HomeVim\templates" -Force | Out-Null
}
Write-Host "Created vim directories" -ForegroundColor Green

# Copy template file
$TemplateSource = Join-Path $ScriptDir "templates\cpp.template"
if (Test-Path $TemplateSource) {
    Copy-Item $TemplateSource "$HomeVim\templates\cpp.template" -Force
    Write-Host "Copied C++ template" -ForegroundColor Green
} else {
    $FallbackTemplate = Join-Path $ScriptDir "cpptemplate.cpp"
    if (Test-Path $FallbackTemplate) {
        Copy-Item $FallbackTemplate "$HomeVim\templates\cpp.template" -Force
        Write-Host "Copied C++ template" -ForegroundColor Green
    } else {
        Write-Host "WARNING: C++ template not found in repository" -ForegroundColor Yellow
    }
}

# Create a batch file for quick access
$BatchFile = "$env:USERPROFILE\cpt.bat"
@"
@echo off
gvim -u "%USERPROFILE%\_vimrc" %*
"@ | Out-File -FilePath $BatchFile -Encoding ASCII -Force

Write-Host "Created $BatchFile for quick gvim access" -ForegroundColor Green

# Add to PATH if not already there (optional)
Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Green
Write-Host "Run 'gvim' to start with the CP configuration"
Write-Host ""
Write-Host "Useful commands in GVim:" -ForegroundColor Cyan
Write-Host "  :TemplateCPP  - Insert C++ template"
Write-Host "  <F5>         - Compile and run"
Write-Host "  <F6>         - Compile with makeprg"
Write-Host "  <Leader>c   - Toggle comment"
Write-Host "  <Leader>q   - Quick quit"
Write-Host ""
