# =====================================================================
#  tools\New-PackageManifests.ps1
#  Generates the package-manager files for one release, straight from the
#  release assets (same URL + SHA-256 that Pack-Release.ps1 produced):
#
#    packaging\winget\<PackageId>\<ver>\<PackageId>.yaml
#    packaging\winget\<PackageId>\<ver>\<PackageId>.installer.yaml
#    packaging\winget\<PackageId>\<ver>\<PackageId>.locale.en-US.yaml
#    packaging\scoop\<AppId>.json
#    packaging\chocolatey\<AppId>.nuspec
#    packaging\chocolatey\tools\chocolateyinstall.ps1
#    packaging\chocolatey\tools\chocolateyuninstall.ps1
#
#  The SHA-256 is taken from (in order): -Sha256, dist\<zip>.sha256, or the
#  published release asset. So it works before or after the release exists.
#
#  Usage:
#    powershell -NoProfile -ExecutionPolicy Bypass -File tools\New-PackageManifests.ps1 -Version 2.1.2
#    ... -Version 2.1.2 -Sha256 <64 hex>
#    ... -Version 2.1.2 -DownloadUrl https://example/foo.zip -Sha256 <hex>
#    ... -Version 2.1.2 -DryRun
# =====================================================================
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Version,
    [string]$Repo = 'SCOTTYinCntrl/Scottimizer',
    [string]$PackageId = 'SCOTTYinCntrl.Scottimizer',
    [string]$AppId = 'scottimizer',
    [string]$OutRoot = 'packaging',
    [string]$Sha256,
    [string]$DownloadUrl,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$root    = Split-Path -Parent $PSScriptRoot
$ver     = $Version.TrimStart('v')
$tag     = "v$ver"
$repoUrl = "https://github.com/$Repo"
$rawUrl  = "https://raw.githubusercontent.com/$Repo/main"
$homePage    = 'https://scottyincntrl.github.io/Scottimizer/'
$asset   = 'Scottimizer-Advanced.zip'

if (-not $DownloadUrl) { $DownloadUrl = "$repoUrl/releases/download/$tag/$asset" }

# ---- resolve the SHA-256 -------------------------------------------------
if (-not $Sha256) {
    $local = Join-Path $root "dist\$asset.sha256"
    if (Test-Path -LiteralPath $local) {
        $Sha256 = ((Get-Content -LiteralPath $local -Raw).Trim() -split '\s+')[0]
        Write-Host "SHA-256 : $Sha256  (from dist\)" -ForegroundColor DarkGray
    }
}
if (-not $Sha256) {
    Write-Host "SHA-256 : not found locally, fetching $DownloadUrl.sha256 ..." -ForegroundColor DarkGray
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("scottimizer-sha-" + [guid]::NewGuid().ToString('N'))
    try {
        Invoke-WebRequest -Uri "$DownloadUrl.sha256" -OutFile $tmp -UseBasicParsing
        $Sha256 = ((Get-Content -LiteralPath $tmp -Raw).Trim() -split '\s+')[0]
    } finally { if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue } }
}
if (-not $Sha256 -or $Sha256 -notmatch '^[0-9a-fA-F]{64}$') {
    throw "Could not determine a valid SHA-256 (got '$Sha256'). Publish the release or pass -Sha256."
}
$shaUp    = $Sha256.ToUpperInvariant()
$shaLower = $Sha256.ToLowerInvariant()

Write-Host "Package : $PackageId $ver"
Write-Host "URL     : $DownloadUrl"
Write-Host "SHA-256 : $shaUp"

# ---- metadata (keep ASCII, no double quotes - they go into JSON/XML) ------
$short = 'Advanced Windows gaming, privacy and security tuner.'
$long  = 'Scottimizer is an advanced Windows tuning utility for gaming performance plus privacy and security hardening. It ships 79 tweaks across six categories, a one-click security audit with a 0-100 score and per-item fixes, per-tweak latency benchmarking, exact-state undo, profiles, quick maintenance tools and a fully customisable look. It never disables Windows Defender, the firewall or Windows Update.'

# ---- writer -------------------------------------------------------------
function Write-Utf8NoBom([string]$Path, [string]$Text) {
    $rel = $Path.Substring($root.Length).TrimStart('\')
    if ($DryRun) { Write-Host "  [dry-run] $rel" -ForegroundColor DarkGray; return }
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "  wrote $rel" -ForegroundColor Gray
}
function Fill([string]$tpl) {
    $tpl.Replace('@@ID@@',      $PackageId).
         Replace('@@APPID@@',   $AppId).
         Replace('@@VER@@',     $ver).
         Replace('@@TAG@@',     $tag).
         Replace('@@URL@@',     $DownloadUrl).
         Replace('@@SHAUP@@',   $shaUp).
         Replace('@@SHALO@@',   $shaLower).
         Replace('@@REPOURL@@', $repoUrl).
         Replace('@@RAWURL@@',  $rawUrl).
         Replace('@@HOME@@',    $homePage).
         Replace('@@SHORT@@',   $short).
         Replace('@@LONG@@',    $long)
}

# =====================================================================
#  winget
# =====================================================================
$tplVersion = @'
# yaml-language-server: $schema=https://aka.ms/winget-manifest.version.1.6.0.schema.json
PackageIdentifier: @@ID@@
PackageVersion: @@VER@@
DefaultLocale: en-US
ManifestType: version
ManifestVersion: 1.6.0
'@

$tplInstaller = @'
# yaml-language-server: $schema=https://aka.ms/winget-manifest.installer.1.6.0.schema.json
PackageIdentifier: @@ID@@
PackageVersion: @@VER@@
InstallerType: zip
NestedInstallerType: portable
NestedInstallerFiles:
- RelativeFilePath: Scottimizer.exe
  PortableCommandAlias: scottimizer
Installers:
- Architecture: x64
  InstallerUrl: @@URL@@
  InstallerSha256: @@SHAUP@@
ManifestType: installer
ManifestVersion: 1.6.0
'@

$tplLocale = @'
# yaml-language-server: $schema=https://aka.ms/winget-manifest.defaultLocale.1.6.0.schema.json
PackageIdentifier: @@ID@@
PackageVersion: @@VER@@
PackageLocale: en-US
Publisher: SCOTTYinCntrl
PublisherUrl: https://github.com/SCOTTYinCntrl
PublisherSupportUrl: @@REPOURL@@/issues
PackageName: Scottimizer
PackageUrl: @@HOME@@
License: MIT
LicenseUrl: @@REPOURL@@/blob/main/LICENSE
Copyright: Copyright (c) 2026 SCOTTYinCntrl
ShortDescription: @@SHORT@@
Description: @@LONG@@
Moniker: scottimizer
Tags:
- windows
- optimization
- gaming
- privacy
- security
- tweak
- debloat
- performance
- latency
- system-optimization
ReleaseNotesUrl: @@REPOURL@@/releases/tag/@@TAG@@
ManifestType: defaultLocale
ManifestVersion: 1.6.0
'@

$wdir = Join-Path $root "$OutRoot\winget\$PackageId\$ver"
Write-Utf8NoBom (Join-Path $wdir "$PackageId.yaml")                    (Fill $tplVersion)
Write-Utf8NoBom (Join-Path $wdir "$PackageId.installer.yaml")          (Fill $tplInstaller)
Write-Utf8NoBom (Join-Path $wdir "$PackageId.locale.en-US.yaml")       (Fill $tplLocale)

# =====================================================================
#  Scoop  (bucket manifest)
# =====================================================================
$tplScoop = @'
{
    "version": "@@VER@@",
    "description": "@@SHORT@@ Free and open source (MIT).",
    "homepage": "@@HOME@@",
    "license": "MIT",
    "url": "@@URL@@",
    "hash": "sha256:@@SHALO@@",
    "bin": "Scottimizer.exe",
    "shortcuts": [
        [
            "Scottimizer.exe",
            "Scottimizer"
        ]
    ],
    "checkver": {
        "github": "@@REPOURL@@"
    },
    "autoupdate": {
        "url": "@@REPOURL@@/releases/download/v$version/Scottimizer-Advanced.zip",
        "hash": {
            "url": "@@REPOURL@@/releases/download/v$version/Scottimizer-Advanced.zip.sha256"
        }
    }
}
'@
Write-Utf8NoBom (Join-Path $root "$OutRoot\scoop\$AppId.json") (Fill $tplScoop)

# =====================================================================
#  Chocolatey  (nuspec + install/uninstall scripts)
# =====================================================================
$tplNuspec = @'
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2015/06/nuspec.xsd">
  <metadata>
    <id>@@APPID@@</id>
    <version>@@VER@@</version>
    <title>Scottimizer</title>
    <authors>SCOTTYinCntrl</authors>
    <owners>SCOTTYinCntrl</owners>
    <projectUrl>@@REPOURL@@</projectUrl>
    <packageSourceUrl>@@REPOURL@@</packageSourceUrl>
    <projectSourceUrl>@@REPOURL@@</projectSourceUrl>
    <docsUrl>@@HOME@@</docsUrl>
    <iconUrl>@@RAWURL@@/preview/icon.png</iconUrl>
    <licenseUrl>@@REPOURL@@/blob/main/LICENSE</licenseUrl>
    <requireLicenseAcceptance>false</requireLicenseAcceptance>
    <description>@@LONG@@</description>
    <summary>@@SHORT@@</summary>
    <releaseNotes>@@REPOURL@@/releases/tag/@@TAG@@</releaseNotes>
    <tags>windows tuner gaming privacy security optimization debloat performance admin pwsh</tags>
  </metadata>
  <files>
    <file src="tools\**" target="tools" />
  </files>
</package>
'@

$tplChocoInstall = @'
$ErrorActionPreference = 'Stop'

$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName   = '@@APPID@@'
  unzipLocation = $toolsDir
  url           = '@@URL@@'
  checksum      = '@@SHAUP@@'
  checksumType  = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs

# Scottimizer is a GUI app; expose it on PATH and the Start Menu.
$exe = Join-Path $toolsDir 'Scottimizer.exe'
if (Test-Path -LiteralPath $exe) {
  Install-BinFile -Name 'scottimizer' -Path $exe
  $menu = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'
  if (Test-Path -LiteralPath $menu) {
    Install-ChocolateyShortcut -ShortcutFilePath (Join-Path $menu 'Scottimizer.lnk') `
      -TargetPath $exe -WorkingDirectory $toolsDir -IconLocation $exe
  }
}
'@

$tplChocoUninstall = @'
$ErrorActionPreference = 'Stop'
Uninstall-BinFile -Name 'scottimizer'
'@

$cdir = Join-Path $root "$OutRoot\chocolatey"
Write-Utf8NoBom (Join-Path $cdir "$AppId.nuspec")                 (Fill $tplNuspec)
Write-Utf8NoBom (Join-Path $cdir 'tools\chocolateyinstall.ps1')   (Fill $tplChocoInstall)
Write-Utf8NoBom (Join-Path $cdir 'tools\chocolateyuninstall.ps1') (Fill $tplChocoUninstall)

if ($DryRun) { Write-Host "`n(dry run - nothing written)" -ForegroundColor Yellow }
else { Write-Host "`nPackage manifests written under $OutRoot\" -ForegroundColor Green }
