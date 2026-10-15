# =====================================================================
#  Make-Icon.ps1
#  Draws the Scottimizer app icon: a purple rounded tile with a bold
#  white "S" and a gold lightning bolt, then writes a multi-resolution
#  appicon.ico next to this script. Also drops preview\icon.png (256px)
#  and preview\icon-32.png for quick eyeballing.
#
#  Usage:  powershell -NoProfile -ExecutionPolicy Bypass -File Make-Icon.ps1
# =====================================================================
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = $PSScriptRoot
if (-not $root) { $root = (Get-Location).Path }
$outIco = Join-Path $root 'appicon.ico'
$prevDir = Join-Path $root 'preview'
if (-not (Test-Path $prevDir)) { New-Item -ItemType Directory -Path $prevDir | Out-Null }

# ---- palette (purple) ---------------------------------------------
$cTop   = [System.Drawing.Color]::FromArgb(255, 0x8B, 0x5C, 0xF6)   # purple (bright)
$cBot   = [System.Drawing.Color]::FromArgb(255, 0x4C, 0x1D, 0x95)   # purple (deep)
$white  = [System.Drawing.Color]::White
$gold   = [System.Drawing.Color]::FromArgb(255, 0xFF, 0xCB, 0x45)   # lightning bolt
$goldHi = [System.Drawing.Color]::FromArgb(255, 0xFF, 0xE6, 0x9C)   # bolt highlight
$outline= [System.Drawing.Color]::FromArgb(120, 0x2A, 0x0B, 0x53)   # bolt outline
$shadow = [System.Drawing.Color]::FromArgb(90, 0, 0, 0)

function New-RoundedPath([single]$x, [single]$y, [single]$w, [single]$h, [single]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $p.AddArc($x,           $y,           $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y,           $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d,   0, 90)
    $p.AddArc($x,           $y + $h - $d, $d, $d,  90, 90)
    $p.CloseFigure()
    return $p
}

# Lightning-bolt outline in a 100x100 design space.
$boltPts = @(
    @(58, 4), @(26, 54), @(46, 54), @(38, 96), @(76, 44), @(54, 44)
)

function New-IconBitmap([int]$size) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.Clear([System.Drawing.Color]::Transparent)

    $m = [single]($size * 0.045)
    $r = [single]($size * 0.235)
    $tile = New-RoundedPath $m $m ([single]($size - 2*$m)) ([single]($size - 2*$m)) $r

    # ---- purple gradient background ----
    $p1 = New-Object System.Drawing.PointF(0, 0)
    $p2 = New-Object System.Drawing.PointF($size, $size)
    $grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush($p1, $p2, $cTop, $cBot)
    $g.FillPath($grad, $tile)
    $grad.Dispose()

    # glossy highlight across the top half
    $glossRect = New-Object System.Drawing.RectangleF(0, 0, $size, [single]($size * 0.52))
    $gloss = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $glossRect,
        [System.Drawing.Color]::FromArgb(64, 255, 255, 255),
        [System.Drawing.Color]::FromArgb(0, 255, 255, 255),
        [System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
    $g.SetClip($tile)
    $g.FillRectangle($gloss, $glossRect)
    $g.ResetClip()
    $gloss.Dispose()

    # ---- the "S" ----
    $sFontSize = [single]($size * 0.92)
    try { $font = New-Object System.Drawing.Font('Arial Black', $sFontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel) }
    catch { $font = New-Object System.Drawing.Font('Arial', $sFontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel) }
    $fmt = New-Object System.Drawing.StringFormat
    $fmt.Alignment = [System.Drawing.StringAlignment]::Center
    $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
    # nudge the S up-left so the bolt has room bottom-right
    $sRect = New-Object System.Drawing.RectangleF([single](-$size*0.14), [single](-$size*0.10), [single]$size, [single]$size)

    $shb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(80, 0, 0, 0))
    $sRectSh = New-Object System.Drawing.RectangleF([single]($sRect.X + $size*0.02), [single]($sRect.Y + $size*0.02), $sRect.Width, $sRect.Height)
    $g.DrawString('S', $font, $shb, $sRectSh, $fmt)
    $wb = New-Object System.Drawing.SolidBrush($white)
    $g.DrawString('S', $font, $wb, $sRect, $fmt)
    $wb.Dispose(); $shb.Dispose(); $font.Dispose(); $fmt.Dispose()

    # ---- the lightning bolt (bottom-right, gold) ----
    $angle = 20.0 * [math]::PI / 180.0
    $cos = [math]::Cos($angle); $sin = [math]::Sin($angle)
    $k = $size * 0.56 / 100.0
    $bcx = 51.0; $bcy = 50.0
    $tx = $size * 0.660; $ty = $size * 0.640
    $pts = New-Object 'System.Drawing.PointF[]' ($boltPts.Count)
    for ($i = 0; $i -lt $boltPts.Count; $i++) {
        $dx = ($boltPts[$i][0] - $bcx) * $k
        $dy = ($boltPts[$i][1] - $bcy) * $k
        $rx = $dx * $cos - $dy * $sin
        $ry = $dx * $sin + $dy * $cos
        $pts[$i] = New-Object System.Drawing.PointF([single]($tx + $rx), [single]($ty + $ry))
    }
    $bolt = New-Object System.Drawing.Drawing2D.GraphicsPath
    $bolt.AddPolygon($pts)

    # shadow
    $mSh = New-Object System.Drawing.Drawing2D.Matrix
    $mSh.Translate([single]($size*0.018), [single]($size*0.018))
    $boltSh = $bolt.Clone(); $boltSh.Transform($mSh)
    $shBrush = New-Object System.Drawing.SolidBrush($shadow)
    $g.FillPath($shBrush, $boltSh)
    $shBrush.Dispose(); $boltSh.Dispose(); $mSh.Dispose()

    # outline then fill (with a lighter top-left sheen)
    $penW = [single][math]::Max(1.0, $size * 0.028)
    $pen = New-Object System.Drawing.Pen($outline, $penW)
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $g.DrawPath($pen, $bolt)
    $pen.Dispose()
    $gb = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.PointF(0,0)),
        (New-Object System.Drawing.PointF($size,$size)), $goldHi, $gold)
    $g.FillPath($gb, $bolt)
    $gb.Dispose(); $bolt.Dispose()

    # thin light rim on the tile for definition
    $rimW = [single][math]::Max(1.0, $size / 110.0)
    $rim = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(70, 255, 255, 255), $rimW)
    $g.DrawPath($rim, $tile)
    $rim.Dispose()

    $g.Dispose()
    return $bmp
}

# ---- build image payloads (BMP/DIB for small sizes, PNG for 256) --
#  Explorer is unreliable at rendering PNG-compressed icon entries below
#  256px, so those are written as classic 32bpp BMP (DIB) entries.
function Get-IconDibBytes([System.Drawing.Bitmap]$bmp) {
    $w = $bmp.Width; $h = $bmp.Height
    $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
    $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $stride = [math]::Abs($data.Stride)
        $raw = New-Object byte[] ($stride * $h)
        [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $raw, 0, $raw.Length)
    } finally { $bmp.UnlockBits($data) }

    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)
    $bw.Write([UInt32]40)              # biSize (BITMAPINFOHEADER)
    $bw.Write([Int32]$w)               # biWidth
    $bw.Write([Int32]($h * 2))         # biHeight (colour + AND mask)
    $bw.Write([UInt16]1)               # biPlanes
    $bw.Write([UInt16]32)              # biBitCount
    $bw.Write([UInt32]0)               # biCompression = BI_RGB
    $bw.Write([UInt32]($w * $h * 4))   # biSizeImage
    $bw.Write([Int32]0)                # biXPelsPerMeter
    $bw.Write([Int32]0)                # biYPelsPerMeter
    $bw.Write([UInt32]0)               # biClrUsed
    $bw.Write([UInt32]0)               # biClrImportant
    for ($y = $h - 1; $y -ge 0; $y--) { $bw.Write($raw, $y * $stride, $w * 4) }  # bottom-up BGRA
    $maskRow = [int]([math]::Floor(($w + 31) / 32) * 4)
    $mask = New-Object byte[] ($maskRow * $h)   # all zero = opaque; alpha channel handles edges
    $bw.Write($mask, 0, $mask.Length)
    $bw.Flush()
    return ,$ms.ToArray()
}

$sizes = 16, 24, 32, 48, 64, 128, 256
$payloads = @()
foreach ($sz in $sizes) {
    $bmp = New-IconBitmap $sz
    if ($sz -eq 256) { $bmp.Save((Join-Path $prevDir 'icon.png'), [System.Drawing.Imaging.ImageFormat]::Png) }
    if ($sz -eq 32)  { $bmp.Save((Join-Path $prevDir 'icon-32.png'), [System.Drawing.Imaging.ImageFormat]::Png) }
    if ($sz -ge 256) {
        $ms = New-Object System.IO.MemoryStream
        $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        $payloads += ,@{ Size = $sz; Bytes = [byte[]]$ms.ToArray() }
        $ms.Dispose()
    } else {
        $payloads += ,@{ Size = $sz; Bytes = (Get-IconDibBytes $bmp) }
    }
    $bmp.Dispose()
}

# ---- assemble .ico -------------------------------------------------
$fs = [System.IO.File]::Create($outIco)
$bw = New-Object System.IO.BinaryWriter($fs)
$bw.Write([UInt16]0)                 # reserved
$bw.Write([UInt16]1)                 # type = icon
$bw.Write([UInt16]$payloads.Count)   # image count

$offset = 6 + (16 * $payloads.Count)
foreach ($p in $payloads) {
    $dim = if ($p.Size -ge 256) { 0 } else { $p.Size }
    $bw.Write([byte]$dim)            # width  (0 => 256)
    $bw.Write([byte]$dim)            # height (0 => 256)
    $bw.Write([byte]0)               # palette count
    $bw.Write([byte]0)               # reserved
    $bw.Write([UInt16]1)             # colour planes
    $bw.Write([UInt16]32)            # bits per pixel
    $bw.Write([UInt32]$p.Bytes.Length)
    $bw.Write([UInt32]$offset)
    $offset += $p.Bytes.Length
}
foreach ($p in $payloads) { $bw.Write([byte[]]$p.Bytes, 0, $p.Bytes.Length) }
$bw.Flush(); $bw.Close(); $fs.Close()

Write-Host ("Icon written: {0}  ({1} bytes, {2} sizes)" -f $outIco, (Get-Item $outIco).Length, $payloads.Count)
