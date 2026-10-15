# =====================================================================
#  Build-EXE.ps1
#  Builds Scottimizer.Standalone.ps1 and compiles it to Scottimizer.exe
#  using the free ps2exe module (installed on demand).
#
#  Usage:  powershell -NoProfile -ExecutionPolicy Bypass -File Build-EXE.ps1
# =====================================================================
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
if (-not $root) { $root = (Get-Location).Path }

# 1) Merge the modules into one portable script.
& (Join-Path $root 'Build-Single.ps1')

# 2) Make sure the app icon exists (generate it if needed).
$icon = Join-Path $root 'appicon.ico'
if (-not (Test-Path $icon)) {
    Write-Host 'Generating app icon...'
    & (Join-Path $root 'Make-Icon.ps1')
}

# 3) Make sure ps2exe is available.
if (-not (Get-Module -ListAvailable ps2exe)) {
    Write-Host 'Installing ps2exe (first run only)...'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    try { Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue } catch {}
    try { Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force -Confirm:$false | Out-Null } catch {}
    Install-Module ps2exe -Scope CurrentUser -Force -Confirm:$false -AllowClobber
}
Import-Module ps2exe -ErrorAction Stop

# 4) Compile. -STA is required for WPF; -requireAdmin triggers the UAC prompt.
$in  = Join-Path $root 'Scottimizer.Standalone.ps1'
$out = Join-Path $root 'Scottimizer.exe'
if (Test-Path $out) { Remove-Item $out -Force }

Invoke-ps2exe -inputFile $in -outputFile $out -noConsole -STA -requireAdmin `
    -title 'Scottimizer' -product 'Scottimizer' -version '2.1.0.0' `
    -description 'Advanced Windows gaming, privacy and security tuner' -company 'Scottimizer' `
    -iconFile $icon

if (Test-Path $out) {
    Write-Host ("Done: {0}  ({1} KB)" -f $out, [math]::Round((Get-Item $out).Length / 1KB))
} else {
    throw 'Compilation failed - Scottimizer.exe was not produced.'
}
