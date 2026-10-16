<#
  Update-Badges.ps1
  ----------------------------------------------------------------------------
  Generates shields.io-style SVG badges into docs\assets\badges\ so the landing
  page and README never depend on shields.io (whose shared GitHub token pool is
  frequently rate-limited, producing "Unable to select next GitHub token from
  pool" in place of the badge).

  Badges produced:
    release.svg      latest release tag      (from the GitHub API)
    downloads.svg    total asset downloads   (summed across all releases)
    license.svg      MIT
    platform.svg     Windows 10 | 11
    powershell.svg   5.1
    sponsor.svg      Cash App

  Run this after cutting a release:
      pwsh -File .\Update-Badges.ps1
  or (Windows PowerShell 5.1):
      powershell -ExecutionPolicy Bypass -File .\Update-Badges.ps1

  An optional token (GH_TOKEN / GITHUB_TOKEN env var, or the gh CLI) lifts the
  anonymous API rate limit; it is not required for a normal run.
#>
[CmdletBinding()]
param(
  [string]$Owner    = 'SCOTTYinCntrl',
  [string]$Repo     = 'Scottimizer',
  [string]$OutDir   = '',
  [string]$License  = 'MIT',
  [string]$Platform = 'Windows 10 | 11',
  [string]$PsVersion = '5.1'
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# $PSScriptRoot is not populated inside param() defaults on Windows PowerShell 5.1
if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot 'docs\assets\badges' }

# ---------------------------------------------------------------- helpers ---
function Get-BadgeTextWidth([string]$s) {
  $wide   = 'mMwW'
  $narrow = 'iljtfrI|.,:;!' + [char]39
  $w = 0.0
  foreach ($ch in $s.ToCharArray()) {
    $c = [string]$ch
    if ($c -eq ' ')                                                    { $w += 3.5 }
    elseif ($wide.IndexOf($c, [StringComparison]::Ordinal) -ge 0)      { $w += 9.0 }
    elseif ($narrow.IndexOf($c, [StringComparison]::Ordinal) -ge 0)    { $w += 3.3 }
    elseif ($c -cmatch '[A-Z]')                                        { $w += 7.2 }
    else                                                               { $w += 6.0 }
  }
  return $w
}

function ConvertTo-Xml([string]$s) {
  $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;')
}

function New-BadgeSvg([string]$label, [string]$value, [string]$color) {
  $lw = [int][Math]::Ceiling((Get-BadgeTextWidth $label)) + 10
  $rw = [int][Math]::Ceiling((Get-BadgeTextWidth $value)) + 10
  $w  = $lw + $rw
  $lx = [int]($lw * 5)                       # label centre, scaled x10
  $rx = [int](($lw + $rw / 2) * 10)          # value centre, scaled x10
  $ll = [int](($lw - 10) * 10)               # label textLength, scaled x10
  $rl = [int](($rw - 10) * 10)               # value textLength, scaled x10
  $la = (ConvertTo-Xml $label)
  $va = (ConvertTo-Xml $value)
  @"
<svg xmlns="http://www.w3.org/2000/svg" width="$w" height="20" role="img" aria-label="${la}: ${va}">
  <title>${la}: ${va}</title>
  <linearGradient id="s" x2="0" y2="100%">
    <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
    <stop offset="1" stop-opacity=".1"/>
  </linearGradient>
  <clipPath id="r">
    <rect width="$w" height="20" rx="3" fill="#fff"/>
  </clipPath>
  <g clip-path="url(#r)">
    <rect width="$lw" height="20" fill="#555"/>
    <rect x="$lw" width="$rw" height="20" fill="#$color"/>
    <rect width="$w" height="20" fill="url(#s)"/>
  </g>
  <g fill="#fff" text-anchor="middle" font-family="Verdana,Geneva,DejaVu Sans,sans-serif" text-rendering="geometricPrecision" font-size="110">
    <text aria-hidden="true" x="$lx" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="$ll">$la</text>
    <text x="$lx" y="140" transform="scale(.1)" textLength="$ll">$la</text>
    <text aria-hidden="true" x="$rx" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="$rl">$va</text>
    <text x="$rx" y="140" transform="scale(.1)" textLength="$rl">$va</text>
  </g>
</svg>
"@
}

# ------------------------------------------------------------- get token ---
$token = $env:GH_TOKEN
if (-not $token) { $token = $env:GITHUB_TOKEN }
if (-not $token) {
  try { $token = (& gh auth token 2>$null | Select-Object -First 1) } catch { $token = $null }
}

$headers = @{
  'User-Agent' = 'Scottimizer-badge-updater'
  'Accept'     = 'application/vnd.github+json'
}
if ($token) { $headers['Authorization'] = "Bearer $token" }

# ------------------------------------------------------------ query GitHub --
$api = "https://api.github.com/repos/$Owner/$Repo"
Write-Host "Querying $api ..."
$latest = Invoke-RestMethod -Uri "$api/releases/latest" -Headers $headers -Method Get
$tag = $latest.tag_name
if (-not $tag) { $tag = $latest.name }

$all = Invoke-RestMethod -Uri "$api/releases?per_page=100" -Headers $headers -Method Get
$downloads = 0
foreach ($rel in $all) {
  if ($rel.assets) {
    foreach ($a in $rel.assets) { $downloads += [int]$a.download_count }
  }
}

# --------------------------------------------------------------- generate ---
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

$badges = [ordered]@{
  'release'    = @{ value = $tag;                  color = '8b5cf6' }
  'downloads'  = @{ value = ('{0:N0}' -f $downloads); color = '22d3ee' }
  'license'    = @{ value = $License;              color = '8b5cf6' }
  'platform'   = @{ value = $Platform;             color = '0078D6' }
  'powershell' = @{ value = $PsVersion;            color = '5391FE' }
  'sponsor'    = @{ value = 'Cash App';            color = '00D632' }
}

foreach ($name in $badges.Keys) {
  $svg  = New-BadgeSvg $name $badges[$name].value $badges[$name].color
  $path = Join-Path $OutDir "$name.svg"
  [IO.File]::WriteAllText($path, $svg, (New-Object Text.UTF8Encoding($false)))
  Write-Host ("  wrote {0,-16} {1} = {2}" -f "$name.svg", $name, $badges[$name].value)
}

Write-Host "Done. Badges written to $OutDir"
