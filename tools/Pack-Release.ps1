# =====================================================================
#  tools\Pack-Release.ps1
#  Stages the shippable files and produces the release zip + SHA-256.
#  Used by both tools\Release.ps1 (local) and .github\workflows\release.yml.
#
#  Usage:
#    powershell -NoProfile -ExecutionPolicy Bypass -File tools\Pack-Release.ps1 -Version 2.1.1
# =====================================================================
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Version,
    [string]$OutDir = 'dist'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot          # repo root (this script lives in tools\)
if (-not (Test-Path $root)) { $root = (Get-Location).Path }

# Files that make up the shipped app (order is cosmetic).
$files = @(
    'Scottimizer.exe', 'Scottimizer.bat', 'Scottimizer.ps1',
    'appicon.ico', 'README.md', 'LICENSE',
    'Build-Single.ps1', 'Build-EXE.ps1', 'Build-EXE.bat', 'Make-Icon.ps1'
)

$stage = Join-Path ([System.IO.Path]::GetTempPath()) ("scottimizer-pack-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage -Force | Out-Null

try {
    foreach ($f in $files) {
        $p = Join-Path $root $f
        if (Test-Path -LiteralPath $p) { Copy-Item -LiteralPath $p -Destination $stage -Force }
        else { Write-Warning "Skipping missing file: $f" }
    }
    $src = Join-Path $root 'src'
    if (-not (Test-Path $src)) { throw "Missing src\ folder at $root" }
    Copy-Item -LiteralPath $src -Destination $stage -Recurse -Force

    if (-not (Test-Path (Join-Path $stage 'Scottimizer.exe'))) {
        Write-Warning 'Scottimizer.exe is not present - the zip will ship source only (run Build-EXE.ps1 first).'
    }

    $outPath = Join-Path $root $OutDir
    if (-not (Test-Path $outPath)) { New-Item -ItemType Directory -Path $outPath -Force | Out-Null }
    $zip = Join-Path $outPath 'Scottimizer-Advanced.zip'
    if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }

    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -CompressionLevel Optimal

    $hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLower()
    $sha  = "$zip.sha256"
    "$hash  Scottimizer-Advanced.zip" | Set-Content -LiteralPath $sha -Encoding ASCII

    Write-Host ("Packaged v{0}: {1}  ({2:N0} KB)" -f $Version, $zip, ((Get-Item -LiteralPath $zip).Length / 1KB))
    Write-Host ("SHA256: {0}" -f $hash)
} finally {
    if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue }
}
