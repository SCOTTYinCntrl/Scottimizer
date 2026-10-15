<#
.SYNOPSIS
    Renders the Scottimizer short-form promo video (1080x1920 @ 30fps).

.DESCRIPTION
    Deterministic GDI+ (System.Drawing) frame renderer - every pixel is drawn by
    this script, so nothing depends on a GUI, a screen recorder or a codec.

    Writes JPEG frames to <OutDir>\frames, then encodes with ffmpeg to
    <OutDir>\Scottimizer-promo-1080x1920.mp4

    The video is intentionally SILENT (a silent AAC track is muxed for
    compatibility) so each platform's own trending audio can be layered on
    in-app, which materially helps distribution.

.PARAMETER OutDir
    Where frames and the finished MP4 go. Defaults to a Desktop folder.

.PARAMETER ShotsDir
    Folder with the UI screenshots (shot-*.png). Defaults to ..\preview

.PARAMETER Fps
    Frame rate. Default 30.

.PARAMETER NoEncode
    Render frames only; skip the ffmpeg step.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\Build-PromoVideo.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\Build-PromoVideo.ps1 -NoEncode
#>
[CmdletBinding()]
param(
    [string] $OutDir = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Scottimizer-Video'),
    [string] $ShotsDir,
    [int]    $Fps = 30,
    [switch] $NoEncode
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$W = 1080
$H = 1920

if (-not $ShotsDir) { $ShotsDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'preview' }
if (-not (Test-Path $ShotsDir)) { throw "Screenshots folder not found: $ShotsDir" }

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$framesDir = Join-Path $OutDir 'frames'
New-Item -ItemType Directory -Force -Path $framesDir | Out-Null
Get-ChildItem $framesDir -Filter '*.jpg' -ErrorAction SilentlyContinue | Remove-Item -Force

# ------------------------------------------------------------------ colours
$BG1    = [System.Drawing.Color]::FromArgb(255,   8,   8,  16)
$BG2    = [System.Drawing.Color]::FromArgb(255,  20,  15,  38)
$VIOLET = [System.Drawing.Color]::FromArgb(255, 139,  92, 246)
$CYAN   = [System.Drawing.Color]::FromArgb(255,  34, 211, 238)
$WHITE  = [System.Drawing.Color]::FromArgb(255, 245, 245, 250)
$MUTED  = [System.Drawing.Color]::FromArgb(255, 154, 154, 176)

function FA($colour, [int]$a) {
    if ($a -lt 0) { $a = 0 } elseif ($a -gt 255) { $a = 255 }
    return [System.Drawing.Color]::FromArgb($a, $colour.R, $colour.G, $colour.B)
}

# -------------------------------------------------------------------- fonts
function Import-Family([string]$Path) {
    if (-not (Test-Path $Path)) { throw "Font not found: $Path" }
    $col = [System.Drawing.Text.PrivateFontCollection]::new()
    $col.AddFontFile($Path)
    return [pscustomobject]@{ Collection = $col; Family = $col.Families[0] }
}

$FACE = @{
    black = Import-Family 'C:\Windows\Fonts\seguibl.ttf'
    bold  = Import-Family 'C:\Windows\Fonts\segoeuib.ttf'
    mono  = Import-Family 'C:\Windows\Fonts\consolab.ttf'
}

$fontCache = @{}
function Get-Font([string]$which, [int]$px) {
    $key = "$which|$px"
    if (-not $script:fontCache.ContainsKey($key)) {
        $fam = $script:FACE[$which].Family
        $script:fontCache[$key] = [System.Drawing.Font]::new($fam, [float]$px, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    }
    return $script:fontCache[$key]
}

$measureBmp = [System.Drawing.Bitmap]::new(8, 8)
$measureG   = [System.Drawing.Graphics]::FromImage($measureBmp)

function Measure-Block([string]$Text, $Font) {
    $w = 0.0; $h = 0.0
    foreach ($line in ($Text -split "`n")) {
        $sz = $script:measureG.MeasureString($line, $Font)
        if ($sz.Width -gt $w) { $w = $sz.Width }
        $h += $sz.Height
    }
    return [pscustomobject]@{ Width = $w; Height = $h }
}

function Fit-Font([string]$which, [string]$Text, [double]$MaxW, [int]$StartPx, [int]$MinPx) {
    $px = $StartPx
    while ($px -gt $MinPx) {
        $f = Get-Font $which $px
        if ((Measure-Block $Text $f).Width -le $MaxW) { break }
        $px -= 2
    }
    return $px
}

# ------------------------------------------------------------------ drawing
function Draw-Block($G, [string]$Text, $Font, [System.Drawing.Color]$Ink, [double]$X, [double]$Y, [double]$Wo, [double]$Ho) {
    if ([string]::IsNullOrEmpty($Text)) { return }
    $rect = [System.Drawing.RectangleF]::new([float]$X, [float]$Y, [float]$Wo, [float]$Ho)
    $sf = [System.Drawing.StringFormat]::new()
    $sf.Alignment     = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $sf.FormatFlags   = [System.Drawing.StringFormatFlags]::NoClip
    $br = [System.Drawing.SolidBrush]::new($Ink)
    $G.DrawString($Text, $Font, $br, $rect, $sf)
    $br.Dispose()
    $sf.Dispose()
}

function New-RoundPath([double]$X, [double]$Y, [double]$Wo, [double]$Ho, [double]$R) {
    $p = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $d = $R * 2
    $p.AddArc([float]$X,                [float]$Y,                [float]$d, [float]$d, 180, 90)
    $p.AddArc([float]($X + $Wo - $d),   [float]$Y,                [float]$d, [float]$d, 270, 90)
    $p.AddArc([float]($X + $Wo - $d),   [float]($Y + $Ho - $d),   [float]$d, [float]$d,   0, 90)
    $p.AddArc([float]$X,                [float]($Y + $Ho - $d),   [float]$d, [float]$d,  90, 90)
    $p.CloseFigure()
    return $p
}

function Ease-Out([double]$p) {
    if ($p -ge 1) { return 1.0 }
    if ($p -le 0) { return 0.0 }
    return 1.0 - [math]::Pow(1.0 - $p, 3.0)
}

function Add-Glow($G, [double]$Cx, [double]$Cy, [double]$Size, [int]$Alpha, [System.Drawing.Color]$Colour) {
    $r = $Size / 2.0
    $x = $Cx - $r
    $y = $Cy - $r
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $path.AddEllipse([float]$x, [float]$y, [float]$Size, [float]$Size)
    $pgb = [System.Drawing.Drawing2D.PathGradientBrush]::new($path)
    $pgb.CenterColor    = [System.Drawing.Color]::FromArgb($Alpha, $Colour)
    $pgb.SurroundColors = @([System.Drawing.Color]::FromArgb(0, $Colour))
    $G.FillEllipse($pgb, [float]$x, [float]$y, [float]$Size, [float]$Size)
    $pgb.Dispose()
    $path.Dispose()
}

# ------------------------------------------------------------------- scenes
# 22.0s total. Hook first so the thumbnail IS the hook, then proof, then CTA.
$scenes = @(
    @{ kind = 'hook'; dur = 3.0
       tag  = 'WINDOWS 10 / 11'
       big  = "Tweak tools`ncan't show proof."
       acc  = 'So I built one that does.' },

    @{ kind = 'shot'; dur = 4.2
       tag  = '01 / BENCHMARKS'
       head = 'Ping, before & after.'
       shot = 'shot-benchmarks.png'
       cap  = 'Every tweak, measured.' },

    @{ kind = 'shot'; dur = 4.0
       tag  = '02 / SECURITY'
       head = 'A 0-100 audit.'
       shot = 'shot-audit.png'
       cap  = 'Weak spots, fixed in one click.' },

    @{ kind = 'shot'; dur = 4.0
       tag  = '03 / UNDO'
       head = 'And a real undo.'
       shot = 'shot-dashboard.png'
       cap  = 'Every change, reversible.' },

    @{ kind = 'shot'; dur = 3.2
       tag  = '04 / WHEREVER YOU TUNE'
       head = '79 tweaks. 6 categories.'
       shot = 'shot-gaming.png'
       cap  = "Gaming / Network / Security`nPrivacy / Debloat / Storage" },

    @{ kind = 'cta'; dur = 3.6
       tag  = ''
       big  = "Free. Open source.`nNo ads. No telemetry."
       url  = 'scottyincntrl.github.io/Scottimizer'
       foot = 'Windows 10 / 11 - open source (MIT)' }
)

# ----------------------------------------------------------------- preflight
$shots = @{}
Get-ChildItem (Join-Path $ShotsDir 'shot-*.png') | ForEach-Object {
    $shots[$_.Name] = [System.Drawing.Image]::FromFile($_.FullName)
}
if ($shots.Count -eq 0) { throw "No shot-*.png in $ShotsDir" }

$CARDW = 960
$CARDX = [int](($W - $CARDW) / 2)
$CARDY = 560

foreach ($s in $scenes) {
    switch ($s.kind) {
        'hook' {
            $s.bigPx = Fit-Font 'black' $s.big 940 104 64
            $s.accPx = Fit-Font 'bold'  $s.acc 940  56 34
        }
        'shot' {
            $s.headPx = Fit-Font 'black' $s.head 920 92 54
            $s.capPx  = Fit-Font 'bold'  $s.cap  940 46 26
            $img = $shots[$s.shot]
            if (-not $img) { throw "Missing screenshot: $($s.shot)" }
            $s.cardH = [int][math]::Round($CARDW * $img.Height / $img.Width)
        }
        'cta' {
            $s.bigPx  = Fit-Font 'black' $s.big  920 84 52
            $s.urlPx  = Fit-Font 'mono'  $s.url  780 44 24
            $s.footPx = Fit-Font 'bold'  $s.foot 900 40 26
        }
    }
}

$t = 0.0
foreach ($s in $scenes) { $s.start = $t; $t += $s.dur }
$TOTAL = $t
$totalFrames = [int][math]::Round($TOTAL * $Fps)

Write-Output ("Rendering {0} frames ({1:N1}s @ {2}fps) -> {3}" -f $totalFrames, $TOTAL, $Fps, $framesDir)

# ---------------------------------------------------------------- backdrop
$bg = [System.Drawing.Bitmap]::new($W, $H)
$bgG = [System.Drawing.Graphics]::FromImage($bg)
$bgG.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$bgRect = [System.Drawing.Rectangle]::new(0, 0, $W, $H)
$bgGrad = [System.Drawing.Drawing2D.LinearGradientBrush]::new($bgRect, $BG1, $BG2, 90)
$bgG.FillRectangle($bgGrad, $bgRect)
$bgGrad.Dispose()
Add-Glow $bgG 300  360 1600 80 $VIOLET
Add-Glow $bgG 820 1560 1800 70 $CYAN
$bgG.Dispose()

# ------------------------------------------------------------------ canvas
$canvas = [System.Drawing.Bitmap]::new($W, $H)
$g = [System.Drawing.Graphics]::FromImage($canvas)
$g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
$g.TextRenderingHint  = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

$fBrand = Get-Font 'mono' 34
$BRAND  = FA $MUTED 110

$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$encParams = [System.Drawing.Imaging.EncoderParameters]::new(1)
$encParams.Param[0] = [System.Drawing.Imaging.EncoderParameter]::new([System.Drawing.Imaging.Encoder]::Quality, [long]92)

# ---------------------------------------------------------------- render
$sw = [System.Diagnostics.Stopwatch]::StartNew()
for ($f = 0; $f -lt $totalFrames; $f++) {

    $now = $f / [double]$Fps

    $cur = $scenes[$scenes.Count - 1]
    $idx = $scenes.Count - 1
    for ($i = 0; $i -lt $scenes.Count; $i++) {
        if ($now -ge $scenes[$i].start -and $now -lt ($scenes[$i].start + $scenes[$i].dur)) {
            $cur = $scenes[$i]; $idx = $i; break
        }
    }
    $tl = $now - $cur.start

    if ($idx -eq 0) {
        $alpha = 255
        $dy = 0.0
    } else {
        $e = Ease-Out ([math]::Min(1.0, $tl / 0.22))
        $alpha = [int][math]::Round(255 * $e)
        $dy = (1.0 - $e) * 34.0
    }

    $g.DrawImageUnscaled($bg, 0, 0)

    switch ($cur.kind) {

        'hook' {
            Draw-Block $g $cur.tag  (Get-Font 'mono' 38)               $CYAN  70  382 940 50
            Draw-Block $g $cur.big  (Get-Font 'black' $cur.bigPx)      $WHITE 70  470 940 500
            $ap = [math]::Max(0.0, [math]::Min(1.0, ($tl - 0.35) / 0.45))
            $ae = Ease-Out $ap
            $accInk = FA $CYAN ([int][math]::Round(255 * $ae))
            $accY = 1015 + ((1.0 - $ae) * 26.0)
            Draw-Block $g $cur.acc (Get-Font 'bold' $cur.accPx) $accInk 70 $accY 940 90
        }

        'shot' {
            $inkTag  = FA $CYAN  $alpha
            $inkHead = FA $WHITE $alpha
            $inkCap  = FA $MUTED $alpha

            Draw-Block $g $cur.tag  (Get-Font 'mono' 38)               $inkTag  70 (150 + $dy) 940 50
            Draw-Block $g $cur.head (Get-Font 'black' $cur.headPx)     $inkHead 70 (240 + $dy) 940 170

            $ch = [int]$cur.cardH
            $zoom = 1.0 + (0.055 * ($tl / $cur.dur))
            $dw = $CARDW * $zoom
            $dh = $ch * $zoom
            $dx = $CARDX - (($dw - $CARDW) / 2.0)
            $dyy = ($CARDY + $dy) - (($dh - $ch) / 2.0)

            $path = New-RoundPath $CARDX ($CARDY + $dy) $CARDW $ch 22
            $g.SetClip($path)
            $g.DrawImage($shots[$cur.shot], [float]$dx, [float]$dyy, [float]$dw, [float]$dh)
            $g.ResetClip()
            $pen = [System.Drawing.Pen]::new((FA $VIOLET $alpha), 2.0)
            $g.DrawPath($pen, $path)
            $pen.Dispose()
            $path.Dispose()

            $capY = $CARDY + $ch + 46 + $dy
            Draw-Block $g $cur.cap (Get-Font 'bold' $cur.capPx) $inkCap 70 $capY 940 150
        }

        'cta' {
            $ink  = FA $WHITE $alpha
            $cy   = FA $CYAN  $alpha
            $mu   = FA $MUTED $alpha

            Draw-Block $g $cur.big (Get-Font 'black' $cur.bigPx) $ink 70 (540 + $dy) 940 300

            $pw = 880
            $ph = 118
            $ppx = ($W - $pw) / 2.0
            $ppy = 985 + $dy
            $pill = New-RoundPath $ppx $ppy $pw $ph 59
            $pen = [System.Drawing.Pen]::new($cy, 3.0)
            $g.DrawPath($pen, $pill)
            $pen.Dispose()
            $pill.Dispose()
            Draw-Block $g $cur.url (Get-Font 'mono' $cur.urlPx) $cy $ppx ($ppy + 4) $pw ($ph - 8)

            Draw-Block $g $cur.foot (Get-Font 'bold' $cur.footPx) $mu 70 (1170 + $dy) 940 60
        }
    }

    Draw-Block $g 'SCOTTIMIZER' $fBrand $BRAND 0 1798 1080 40

    $progW = [int][math]::Ceiling($W * (($f + 1) / [double]$totalFrames))
    $pgBrush = [System.Drawing.SolidBrush]::new($VIOLET)
    $g.FillRectangle($pgBrush, 0, 0, $progW, 6)
    $pgBrush.Dispose()

    $outFile = Join-Path $framesDir ('f{0:d5}.jpg' -f $f)
    $canvas.Save($outFile, $jpegCodec, $encParams)

    if ($f % 120 -eq 0) {
        Write-Output ("  frame {0}/{1}  elapsed {2:N0}s" -f $f, $totalFrames, $sw.Elapsed.TotalSeconds)
    }
}
$sw.Stop()
Write-Output ("Frames rendered in {0:N0}s" -f $sw.Elapsed.TotalSeconds)

$g.Dispose()
$canvas.Dispose()
$bg.Dispose()
foreach ($k in @($shots.Keys)) { $shots[$k].Dispose() }

# ----------------------------------------------------------------- encode
if ($NoEncode) {
    Write-Output "Skipped encode (-NoEncode)."
    return
}

$ff = (Get-Command ffmpeg -ErrorAction SilentlyContinue).Source
if (-not $ff) {
    $cand = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages') -Recurse -Filter ffmpeg.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cand) { $ff = $cand.FullName }
}
if (-not $ff) { throw "ffmpeg not found. 'winget install Gyan.FFmpeg', or re-run with -NoEncode." }

$mp4     = Join-Path $OutDir 'Scottimizer-promo-1080x1920.mp4'
$pattern = Join-Path $framesDir 'f%05d.jpg'

& $ff -y -hide_banner -loglevel error `
    -framerate $Fps -i $pattern `
    -f lavfi -i 'anullsrc=channel_layout=stereo:sample_rate=44100' `
    -shortest `
    -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -profile:v high -level 4.0 `
    -c:a aac -b:a 128k `
    -movflags +faststart `
    $mp4

if ($LASTEXITCODE -ne 0) { throw "ffmpeg exited with code $LASTEXITCODE" }
Write-Output "Wrote $mp4"
