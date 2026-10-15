# =====================================================================
#  tools\Update-Winget.ps1
#  Points the winget package at a new release and opens the PR for you.
#  Uses Microsoft's wingetcreate (installed on demand).
#
#  Usage:
#    powershell -NoProfile -ExecutionPolicy Bypass -File tools\Update-Winget.ps1 -Version 2.1.1
#    powershell ... -Version 2.1.1 -DryRun
#
#  First run only: wingetcreate will ask you to sign in to GitHub the first
#  time it submits a PR unless a token is supplied.
# =====================================================================
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Version,
    [string]$PackageId = 'SCOTTYinCntrl.Scottimizer',
    [string]$Repo = 'SCOTTYinCntrl/Scottimizer',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$ver = $Version.TrimStart('v')
$tag = "v$ver"
$url = "https://github.com/$Repo/releases/download/$tag/Scottimizer-Advanced.zip"

Write-Host "Package : $PackageId"
Write-Host "Version : $ver"
Write-Host "URL     : $url"

if ($DryRun) { Write-Host '(dry run - nothing submitted)'; return }

if (-not (Get-Command wingetcreate -ErrorAction SilentlyContinue)) {
    Write-Host 'Installing wingetcreate (first run only)...'
    winget install --id Microsoft.WingetCreate --accept-source-agreements --accept-package-agreements --silent
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('Path','User')
}

Write-Host "Submitting update for $PackageId $ver ..."
wingetcreate update $PackageId --version $ver --urls $url --submit
if ($LASTEXITCODE -ne 0) { throw "wingetcreate failed (exit $LASTEXITCODE)" }
Write-Host 'Submitted. Watch the PR at https://github.com/microsoft/winget-pkgs/pulls' -ForegroundColor Green
