# =====================================================================
#  tools\Release.ps1
#  One command to cut a Scottimizer release:
#    1. bump the version in Scottimizer.ps1 + this build
#    2. validate every .ps1 parses
#    3. build the standalone script and the .exe (ps2exe, installed on demand)
#    4. package Scottimizer-Advanced.zip + SHA-256
#    5. generate the winget / Scoop / Chocolatey manifests from those assets
#    6. commit, tag, push
#    7. create the GitHub Release and upload the assets
#    8. print the package-manager submission commands for the new version
#
#  Usage:
#    powershell -NoProfile -ExecutionPolicy Bypass -File tools\Release.ps1 -Version 2.1.1
#    powershell ... -File tools\Release.ps1 -Version 2.1.1 -DryRun
#    powershell ... -File tools\Release.ps1 -Version 2.1.1 -SkipBuild      # reuse existing exe
#    powershell ... -File tools\Release.ps1 -Version 2.1.1 -Notes "Fixes ..."
# =====================================================================
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Version,
    [string]$Notes,
    [string]$NotesFile,
    [string]$Repo = 'SCOTTYinCntrl/Scottimizer',
    [switch]$DryRun,
    [switch]$SkipBuild,
    [switch]$SkipExe,
    [switch]$NoPush
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$ver  = $Version.TrimStart('v')
$tag  = "v$ver"

function Step([string]$m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Run([string]$exe, [string[]]$RunArgs) {
    Write-Host ("    {0} {1}" -f $exe, ($RunArgs -join ' ')) -ForegroundColor DarkGray
    if ($DryRun) { return }
    & $exe @RunArgs
    if ($LASTEXITCODE -ne 0) { throw "$exe failed (exit $LASTEXITCODE)" }
}
function Set-VersionString([string]$file, [string]$v) {
    $text = Get-Content -LiteralPath $file -Raw
    $re   = [regex]"(\`$script:Version\s*=\s*')[^']*(')"
    $new  = $re.Replace($text, ('${1}' + $v + '${2}'), 1)
    if ($new -eq $text) { Write-Warning "Could not find `$script:Version in $file"; return }
    if (-not $DryRun) { Set-Content -LiteralPath $file -Value $new -Encoding UTF8 }
    Write-Host "    version -> $v in $(Split-Path $file -Leaf)" -ForegroundColor DarkGray
}

Push-Location $root
try {
    Step "Pre-flight"
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'git is required.' }
    if (git tag -l $tag) { throw "Tag $tag already exists. Bump the version." }
    Write-Host "    repo root : $root"
    Write-Host "    version   : $ver   (tag $tag)"

    Step "Bump version to $ver"
    Set-VersionString (Join-Path $root 'Scottimizer.ps1') $ver

    Step "Validate PowerShell"
    $bad = 0
    foreach ($f in @(Get-ChildItem -Path $root -Recurse -Filter *.ps1 | Where-Object { $_.FullName -notmatch '\\\.git\\' })) {
        $errs = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$errs)
        if ($errs -and $errs.Count) { $bad++; Write-Host "    PARSE FAIL $($f.Name): $($errs[0].Message)" -ForegroundColor Red }
    }
    if ($bad) { throw "$bad file(s) failed to parse - fix before releasing." }
    Write-Host "    all scripts parse."

    if (-not $SkipBuild) {
        Step "Build standalone"
        Run 'powershell.exe' @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $root 'Build-Single.ps1'))
        if (-not $SkipExe) {
            Step "Build .exe (ps2exe)"
            Run 'powershell.exe' @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $root 'Build-EXE.ps1'),'-Version',$ver)
        }
    }

    Step "Package"
    Run 'powershell.exe' @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $root 'tools\Pack-Release.ps1'),'-Version',$ver,'-OutDir','dist')

    Step "Generate package manifests (winget + Scoop + Chocolatey)"
    Run 'powershell.exe' @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $root 'tools\New-PackageManifests.ps1'),'-Version',$ver)

    Step "Commit + tag"
    Run 'git' @('add','-A')
    Run 'git' @('commit','--allow-empty','-m',("Release $tag"))
    Run 'git' @('tag',"$tag")

    if (-not $NoPush) {
        Step "Push"
        Run 'git' @('push','origin','HEAD')
        Run 'git' @('push','origin',$tag)
    } else {
        Write-Host "    (skipped push -NoPush)" -ForegroundColor Yellow
    }

    Step "Create GitHub Release"
    $zip = Join-Path $root 'dist\Scottimizer-Advanced.zip'
    $sha = "$zip.sha256"
    $body = if ($NotesFile -and (Test-Path $NotesFile)) { Get-Content -LiteralPath $NotesFile -Raw }
            elseif ($Notes) { $Notes }
            else { "Scottimizer $ver`n`nSee the repository README for details." }
    $noteFile = Join-Path $root 'dist\RELEASE_NOTES.md'
    if (-not (Test-Path (Join-Path $root 'dist'))) { New-Item -ItemType Directory -Path (Join-Path $root 'dist') -Force | Out-Null }
    Set-Content -LiteralPath $noteFile -Value $body -Encoding UTF8

    if (Get-Command gh -ErrorAction SilentlyContinue) {
        $exists = $false
        if (-not $DryRun) {
            gh release view $tag *> $null
            $exists = ($LASTEXITCODE -eq 0)
        }
        if ($exists) {
            Run 'gh' @('release','upload',$tag,$zip,$sha,'--clobber','-R',$Repo)
        } else {
            Run 'gh' @('release','create',$tag,'--title',"Scottimizer $ver",'--notes-file',$noteFile,$zip,$sha,'-R',$Repo)
        }
    } else {
        Write-Warning 'gh CLI not found - push the tag and the release workflow will build it, or create the release manually.'
    }

    Step "Done"
    Write-Host "    Release: https://github.com/$Repo/releases/tag/$tag" -ForegroundColor Green
    Write-Host "    Package manifests: $root\packaging\" -ForegroundColor Green
    Write-Host "    Submit to package managers:" -ForegroundColor Green
    Write-Host "      powershell -NoProfile -File tools\Submit-Packages.ps1 -Target all" -ForegroundColor Green
    Write-Host "      (winget needs wingetcreate; choco needs choco + `$env:CHOCO_API_KEY)" -ForegroundColor DarkGray
} finally {
    Pop-Location
}
