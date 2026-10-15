# =====================================================================
#  tools\Submit-Packages.ps1
#  Submits the generated manifests (tools\New-PackageManifests.ps1) to the
#  package managers. Every target is independent; use -Target all or one.
#
#    winget : wingetcreate submit  (install: winget install Microsoft.WingetCreate)
#    scoop  : publishes bucket\<app>.json to your own Scoop bucket repo via gh
#             (ScoopInstaller\Extras PR instructions are printed too)
#    choco  : choco pack + choco push  (needs choco and $env:CHOCO_API_KEY)
#
#  Usage:
#    powershell -NoProfile -ExecutionPolicy Bypass -File tools\Submit-Packages.ps1 -Target all
#    ... -Target choco
#    ... -Target scoop -CreateBucket          # first time: create the bucket repo
#    ... -Target winget -Version 2.1.2
#    ... -Target all -DryRun
#
#  Nothing is submitted with -DryRun; commands are only printed.
# =====================================================================
[CmdletBinding()]
param(
    [ValidateSet('winget','scoop','choco','all')][string]$Target = 'all',
    [string]$Version,
    [string]$PackageId  = 'SCOTTYinCntrl.Scottimizer',
    [string]$AppId      = 'scottimizer',
    [string]$Repo       = 'SCOTTYinCntrl/Scottimizer',
    [string]$BucketRepo = 'SCOTTYinCntrl/scoop-bucket',
    [string]$OutRoot    = 'packaging',
    [switch]$CreateBucket,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$wroot = Join-Path $root "$OutRoot\winget\$PackageId"

function Step([string]$m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Have([string]$c) { [bool](Get-Command $c -ErrorAction SilentlyContinue) }
function Run([string]$exe, [string[]]$RunArgs) {
    Write-Host ("    {0} {1}" -f $exe, ($RunArgs -join ' ')) -ForegroundColor DarkGray
    if ($DryRun) { return }
    & $exe @RunArgs
    if ($LASTEXITCODE -ne 0) { throw "$exe failed (exit $LASTEXITCODE)" }
}

if (-not (Test-Path -LiteralPath $wroot)) {
    throw "No manifests under $wroot. Run tools\New-PackageManifests.ps1 -Version <v> first."
}

if ($Version) {
    $ver = $Version.TrimStart('v')
} else {
    $ver = (Get-ChildItem -LiteralPath $wroot -Directory |
            Sort-Object { try { [version]$_.Name } catch { [version]'0.0' } } -Descending |
            Select-Object -First 1).Name
}
$tag = "v$ver"
Write-Host "Package : $PackageId $ver" -ForegroundColor White
Write-Host "Target  : $Target$(if ($DryRun) { '  (dry run)' })" -ForegroundColor White

$doWinget = $Target -in @('winget','all')
$doScoop  = $Target -in @('scoop','all')
$doChoco  = $Target -in @('choco','all')

# ---------------------------------------------------------------------
#  winget
# ---------------------------------------------------------------------
if ($doWinget) {
    Step "winget -> microsoft/winget-pkgs"
    $mainYaml = Join-Path $wroot "$ver\$PackageId.yaml"
    if (-not (Test-Path -LiteralPath $mainYaml)) { Write-Warning "Missing $mainYaml - skipping." }
    elseif (Have 'wingetcreate') {
        Run 'wingetcreate' @('submit', $mainYaml)
        if (-not $DryRun) { Write-Host "    PR opened. Track: https://github.com/microsoft/winget-pkgs/pulls" -ForegroundColor Green }
    } else {
        Write-Warning 'wingetcreate not found.'
        Write-Host '    Install it, then re-run:' -ForegroundColor Yellow
        Write-Host '      winget install --id Microsoft.WingetCreate -e' -ForegroundColor Yellow
        Write-Host "      wingetcreate submit `"$mainYaml`"" -ForegroundColor Yellow
        Write-Host '    (or keep the generated files and open the PR yourself)' -ForegroundColor DarkGray
    }
}

# ---------------------------------------------------------------------
#  scoop -> your own bucket (and instructions for ScoopInstaller\Extras)
# ---------------------------------------------------------------------
if ($doScoop) {
    Step "Scoop -> $BucketRepo"
    $json = Join-Path $root "$OutRoot\scoop\$AppId.json"
    if (-not (Test-Path -LiteralPath $json)) { Write-Warning "Missing $json - skipping." }
    elseif (-not (Have 'gh')) { Write-Warning 'gh CLI not found - cannot publish the bucket.' }
    else {
        $exists = $false
        if (-not $DryRun) {
            gh repo view $BucketRepo --json name *> $null
            $exists = ($LASTEXITCODE -eq 0)
        } else { $exists = $true }

        if (-not $exists) {
            if ($CreateBucket) {
                Write-Host "    creating $BucketRepo ..." -ForegroundColor DarkGray
                Run 'gh' @('repo','create',$BucketRepo,'--public','--description','Scoop bucket for Scottimizer','--add-readme')
            } else {
                Write-Warning "Bucket $BucketRepo does not exist. Re-run with -CreateBucket to create it."
            }
        }
        if ($exists -or $CreateBucket) {
            $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("scottimizer-bucket-" + [guid]::NewGuid().ToString('N'))
            if (-not $DryRun) {
                Run 'git' @('clone','--depth','1',"https://github.com/$BucketRepo.git",$tmp)
                $bucket = Join-Path $tmp 'bucket'
                if (-not (Test-Path -LiteralPath $bucket)) { New-Item -ItemType Directory -Path $bucket -Force | Out-Null }
                Copy-Item -LiteralPath $json -Destination (Join-Path $bucket "$AppId.json") -Force
                Push-Location $tmp
                try {
                    Run 'git' @('add','-A')
                    Run 'git' @('commit','-m',"$AppId $ver")
                    Run 'git' @('push','origin','HEAD')
                } finally { Pop-Location }
                Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "    Installed via: scoop bucket add scottimizer https://github.com/$BucketRepo" -ForegroundColor Green
                Write-Host "                   scoop install scottimizer/$AppId" -ForegroundColor Green
            } else {
                Write-Host "    [dry-run] git clone https://github.com/$BucketRepo.git <tmp>; copy bucket\$AppId.json; commit; push" -ForegroundColor DarkGray
            }
        }
        Write-Host '    For the main ScoopInstaller\Extras bucket (bigger reach):' -ForegroundColor Yellow
        Write-Host "      fork https://github.com/ScoopInstaller/Extras, add bucket\$AppId.json, open a PR." -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------------
#  chocolatey
# ---------------------------------------------------------------------
if ($doChoco) {
    Step "Chocolatey -> community.chocolatey.org"
    $cdir = Join-Path $root "$OutRoot\chocolatey"
    $nuspec = Join-Path $cdir "$AppId.nuspec"
    if (-not (Test-Path -LiteralPath $nuspec)) { Write-Warning "Missing $nuspec - skipping." }
    elseif (-not (Have 'choco')) {
        Write-Warning 'choco not found.'
        Write-Host '    Install Chocolatey, then re-run:' -ForegroundColor Yellow
        Write-Host "      choco pack `"$nuspec`" --outputdirectory `"$cdir`"" -ForegroundColor Yellow
        Write-Host "      choco push `"$cdir\$AppId.$ver.nupkg`" --source https://push.chocolatey.org/" -ForegroundColor Yellow
    } else {
        Push-Location $cdir
        try {
            Run 'choco' @('pack', "$AppId.nuspec", '--outputdirectory', $cdir)
        } finally { Pop-Location }
        $nupkg = Join-Path $cdir "$AppId.$ver.nupkg"
        if ($env:CHOCO_API_KEY) {
            Run 'choco' @('push', $nupkg, '--source', 'https://push.chocolatey.org/', '--api-key', $env:CHOCO_API_KEY)
            if (-not $DryRun) { Write-Host '    Pushed - the package enters moderation.' -ForegroundColor Green }
        } else {
            Write-Host "    Built: $nupkg" -ForegroundColor Green
            Write-Warning 'Set $env:CHOCO_API_KEY (from https://community.chocolatey.org/account) to push.'
            Write-Host "      choco push `"$nupkg`" --source https://push.chocolatey.org/ --api-key <key>" -ForegroundColor Yellow
        }
    }
}

Write-Host "`nDone." -ForegroundColor Green
