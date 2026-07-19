$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$runner = Join-Path $repoRoot "nvim\lua\config\bootstrap_runner.lua"

$env:CP_TEMPLATE_BOOTSTRAP_ACTION = "missing_action"
& nvim --headless -l $runner

if ($LASTEXITCODE -eq 0) {
    throw "bootstrap runner returned success for an invalid action"
}

Write-Host "tests/bootstrap_failure.ps1: ok"
