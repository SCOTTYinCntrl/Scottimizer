<#
.SYNOPSIS
    Snapshot Scottimizer's growth metrics from GitHub.

.DESCRIPTION
    Prints stars, release download counts, and 14-day view/clone traffic so you
    can tell which launch channel actually worked. The north-star number is the
    download count of Scottimizer-Advanced.zip on the latest release.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\Get-Metrics.ps1
#>
[CmdletBinding()]
param(
    [string]$Repo = 'SCOTTYinCntrl/Scottimizer'
)

$ErrorActionPreference = 'Stop'

function Section($t) { Write-Host ""; Write-Host "== $t ==" -ForegroundColor Cyan }

Section "repo"
$r = gh repo view $Repo --json name,description,stargazerCount,forkCount,repositoryTopics,updatedAt | ConvertFrom-Json
Write-Host ("  stars      : {0}" -f $r.stargazerCount)
Write-Host ("  forks      : {0}" -f $r.forkCount)
Write-Host ("  topics     : {0}" -f $r.repositoryTopics.Count)
Write-Host ("  updated    : {0}" -f $r.updatedAt)

Section "releases (downloads)"
$rel = gh api "repos/$Repo/releases" | ConvertFrom-Json
foreach ($x in $rel) {
    Write-Host ("  {0}  ({1})" -f $x.tag_name, $x.published_at)
    foreach ($a in $x.assets) {
        Write-Host ("      {0,-32} {1,6} downloads" -f $a.name, $a.download_count)
    }
}

Section "traffic: views (last 14 days)"
try {
    $v = gh api "repos/$Repo/traffic/views" | ConvertFrom-Json
    Write-Host ("  total: {0} views / {1} unique" -f $v.count, $v.uniques)
    foreach ($d in $v.views) { Write-Host ("      {0}  {1,4} views  {2,4} unique" -f $d.timestamp.Substring(0,10), $d.count, $d.uniques) }
} catch { Write-Host "  (traffic API needs push access)" -ForegroundColor DarkYellow }

Section "traffic: clones (last 14 days)"
try {
    $c = gh api "repos/$Repo/traffic/clones" | ConvertFrom-Json
    Write-Host ("  total: {0} clones / {1} unique" -f $c.count, $c.uniques)
} catch { Write-Host "  (traffic API needs push access)" -ForegroundColor DarkYellow }

Section "winget PR"
try {
    $pr = gh pr view 453051 -R microsoft/winget-pkgs --json state,mergeStateStatus,reviewDecision | ConvertFrom-Json
    Write-Host ("  state={0} merge={1} review={2}" -f $pr.state, $pr.mergeStateStatus, $pr.reviewDecision)
} catch { Write-Host "  (could not read PR)" -ForegroundColor DarkYellow }

Write-Host ""
Write-Host "Log these numbers in marketing\launch-runbook.md after each post." -ForegroundColor Green
