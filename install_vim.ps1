# install_vim.ps1 - Install Vim on Windows
# Usage: .\install_vim.ps1
# Run as: powershell -ExecutionPolicy Bypass -File install_vim.ps1

$ErrorActionPreference = "Stop"

Write-Host "=== Installing Vim on Windows ===" -ForegroundColor Cyan

$vimPaths = @(
    "C:\Program Files\Vim\vim90\vim.exe",
    "C:\Program Files (x86)\Vim\vim90\vim.exe",
    "C:\Program Files\Vim\vim64\vim.exe",
    "$env:LOCALAPPDATA\Programs\Vim\vim.exe"
)

function Resolve-VimPath {
    $cmd = Get-Command vim -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($candidate in $vimPaths) {
        if (Test-Path $candidate) { return $candidate }
    }
    return $null
}

$vimPath = Resolve-VimPath

if ($vimPath) {
    $version = & $vimPath --version | Select-Object -First 1
    Write-Host "Vim already installed: $version" -ForegroundColor Green
    Write-Host "Path: $vimPath" -ForegroundColor Gray
} else {
    Write-Host "Vim not found. Installing..." -ForegroundColor Yellow
    
    # Try winget first (Windows 10/11)
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        Write-Host "Using winget to install Vim..." -ForegroundColor Cyan
        winget install Vim.Vim --accept-package-agreements --accept-source-agreements -h
    } else {
        # Fallback: Download and install manually
        Write-Host "winget not available. Downloading Vim..." -ForegroundColor Yellow
        
        $vimUrl = "https://github.com/vim/vim-win32-installer/releases/download/v9.1.0012/gvim_9.1.0012_x64.exe"
        $tempFile = "$env:TEMP\gvim_installer.exe"
        
        Write-Host "Downloading from $vimUrl..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $vimUrl -OutFile $tempFile -UseBasicParsing
        
        Write-Host "Installing..." -ForegroundColor Cyan
        Start-Process -FilePath $tempFile -ArgumentList "/S" -Wait
        
        # Cleanup
        Remove-Item $tempFile -Force
        
        Write-Host "Vim installed. You may need to restart your terminal." -ForegroundColor Green
    }
}

# Verify installation
$resolved = Resolve-VimPath
if ($resolved) {
    $version = & $resolved --version | Select-Object -First 1
    Write-Host ""
    Write-Host "=== Vim Installed Successfully ===" -ForegroundColor Green
    Write-Host $version
} else {
    Write-Host "ERROR: Vim installation failed. Please install manually from https://www.vim.org/download.php" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Run '.\setup.ps1' to set up the vimrc configuration" -ForegroundColor Cyan
