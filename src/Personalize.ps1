# =====================================================================
#  Scottimizer 2  -  Personalize
#  Settings persistence, customisable background (colour / gradient /
#  photo), accent-colour theming and the Appearance page.
#  Dot-sourced by Scottimizer.ps1 (after Ui.ps1).
# =====================================================================

# ---------------------------------------------------------------------
#  Colour helpers
# ---------------------------------------------------------------------
function Parse-Color([string]$hex) {
    if (-not $hex) { $hex = '#7C5CFF' }
    $h = ([string]$hex).Trim().TrimStart('#')
    if ($h.Length -eq 8) { $h = $h.Substring(2) }   # drop alpha
    if ($h.Length -ne 6 -or ($h -notmatch '^[0-9a-fA-F]{6}$')) { $h = '7C5CFF' }
    return [System.Windows.Media.Color]::FromRgb(
        [Convert]::ToInt32($h.Substring(0,2),16),
        [Convert]::ToInt32($h.Substring(2,2),16),
        [Convert]::ToInt32($h.Substring(4,2),16))
}

function Color-ToHsl($c) {
    $r = $c.R / 255.0; $g = $c.G / 255.0; $b = $c.B / 255.0
    $max = [math]::Max($r, [math]::Max($g, $b))
    $min = [math]::Min($r, [math]::Min($g, $b))
    $l = ($max + $min) / 2.0
    $h = 0.0; $s = 0.0
    if ($max -ne $min) {
        $d = $max - $min
        if ($l -gt 0.5) { $s = $d / (2.0 - $max - $min) } else { $s = $d / ($max + $min) }
        if ($max -eq $r)      { $h = ($g - $b) / $d + $(if ($g -lt $b) { 6 } else { 0 }) }
        elseif ($max -eq $g)  { $h = ($b - $r) / $d + 2 }
        else                  { $h = ($r - $g) / $d + 4 }
        $h = $h / 6.0
    }
    return @($h, $s, $l)
}

function Hue2Rgb($p, $q, $t) {
    if ($t -lt 0) { $t += 1.0 }
    if ($t -gt 1) { $t -= 1.0 }
    if ($t -lt (1.0/6.0)) { return $p + ($q - $p) * 6.0 * $t }
    if ($t -lt (1.0/2.0)) { return $q }
    if ($t -lt (2.0/3.0)) { return $p + ($q - $p) * ((2.0/3.0) - $t) * 6.0 }
    return $p
}

function Hsl-ToColor($h, $s, $l) {
    if ($s -eq 0) { $r = $l; $g = $l; $b = $l }
    else {
        $q = if ($l -lt 0.5) { $l * (1.0 + $s) } else { $l + $s - $l * $s }
        $p = 2.0 * $l - $q
        $r = Hue2Rgb $p $q ($h + 1.0/3.0)
        $g = Hue2Rgb $p $q $h
        $b = Hue2Rgb $p $q ($h - 1.0/3.0)
    }
    return [System.Windows.Media.Color]::FromRgb(
        [byte][math]::Round($r * 255), [byte][math]::Round($g * 255), [byte][math]::Round($b * 255))
}

function New-GradientBrush([string]$c1, [string]$c2, [string]$dir = 'diag') {
    $g = New-Object System.Windows.Media.LinearGradientBrush
    switch ($dir) {
        'vert'  { $g.StartPoint = New-Object System.Windows.Point(0,0); $g.EndPoint = New-Object System.Windows.Point(0,1) }
        'horiz' { $g.StartPoint = New-Object System.Windows.Point(0,0); $g.EndPoint = New-Object System.Windows.Point(1,0) }
        default { $g.StartPoint = New-Object System.Windows.Point(0,0); $g.EndPoint = New-Object System.Windows.Point(0.6,1) }
    }
    $s1 = New-Object System.Windows.Media.GradientStop; $s1.Color = (Parse-Color $c1); $s1.Offset = 0.0
    $s2 = New-Object System.Windows.Media.GradientStop; $s2.Color = (Parse-Color $c2); $s2.Offset = 1.0
    [void]$g.GradientStops.Add($s1); [void]$g.GradientStops.Add($s2)
    $g.Freeze()
    return $g
}

# ---------------------------------------------------------------------
#  Presets
# ---------------------------------------------------------------------
$script:BgGradients = @(
    [pscustomobject]@{ Name='Midnight'; C1='#101A2E'; C2='#0A0E16' }
    [pscustomobject]@{ Name='Nebula';   C1='#1E1240'; C2='#0B0E1A' }
    [pscustomobject]@{ Name='Ocean';    C1='#08303A'; C2='#08131A' }
    [pscustomobject]@{ Name='Forest';   C1='#0C2A1E'; C2='#0A1410' }
    [pscustomobject]@{ Name='Ember';    C1='#2A1218'; C2='#120A0C' }
    [pscustomobject]@{ Name='Grape';    C1='#241436'; C2='#0D0A18' }
    [pscustomobject]@{ Name='Carbon';   C1='#181B22'; C2='#0B0D11' }
    [pscustomobject]@{ Name='Slate';    C1='#1A2432'; C2='#0C1119' }
)
$script:BgSolids = @('#0A0E16','#0E1420','#111827','#0C1A16','#12100E','#1A1024','#101820','#000000')
$script:AccentPresets = @('#7C5CFF','#4F8CFF','#22D3EE','#34D399','#FBBF24','#FB923C','#F472B6','#F87171')

# ---------------------------------------------------------------------
#  Settings persistence
# ---------------------------------------------------------------------
function Get-DefaultSettings {
    [pscustomobject]@{
        Accent      = '#7C5CFF'
        BgType      = 'gradient'      # gradient | solid | image
        BgColor     = '#0E1420'
        BgColor1    = '#101A2E'
        BgColor2    = '#0A0E16'
        BgDir       = 'diag'
        BgImage     = ''
        BgScrim     = 0.15
        BenchEnabled = $false
        BenchTarget = '1.1.1.1'
        BenchCount  = 5
    }
}

function Get-SettingsPath { Join-Path $script:AppRoot 'settings.json' }

function Load-Settings {
    $script:Settings = Get-DefaultSettings
    $path = Get-SettingsPath
    if (Test-Path -LiteralPath $path) {
        try {
            $j = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($p in @($script:Settings.PSObject.Properties.Name)) {
                $v = $j.$p
                if ($null -ne $v) { $script:Settings.$p = $v }
            }
        } catch {}
    }
}

function Save-Settings {
    try {
        $script:Settings | ConvertTo-Json -Depth 5 |
            Set-Content -LiteralPath (Get-SettingsPath) -Encoding UTF8
    } catch {}
}

# ---------------------------------------------------------------------
#  Apply background + accent
# ---------------------------------------------------------------------
function Apply-Background {
    if (-not $script:BgHost) { return }
    $s = $script:Settings
    switch ($s.BgType) {
        'solid' {
            $script:BgHost.Background = New-Object System.Windows.Media.SolidColorBrush (Parse-Color $s.BgColor)
        }
        'image' {
            if ($s.BgImage -and (Test-Path -LiteralPath $s.BgImage)) {
                try {
                    $img = New-Object System.Windows.Media.Imaging.BitmapImage
                    $img.BeginInit()
                    $img.CacheOption = 'OnLoad'
                    $img.UriSource = New-Object System.Uri($s.BgImage)
                    $img.EndInit()
                    $img.Freeze()
                    $ib = New-Object System.Windows.Media.ImageBrush $img
                    $ib.Stretch = 'UniformToFill'
                    $script:BgHost.Background = $ib
                } catch {
                    $script:BgHost.Background = New-GradientBrush $s.BgColor1 $s.BgColor2 $s.BgDir
                }
            } else {
                $script:BgHost.Background = New-GradientBrush $s.BgColor1 $s.BgColor2 $s.BgDir
            }
        }
        default {
            $script:BgHost.Background = New-GradientBrush $s.BgColor1 $s.BgColor2 $s.BgDir
        }
    }
    $a = [byte]([math]::Round(255 * [double]$s.BgScrim))
    $script:ScrimHost.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb($a,0,0,0))
}

function Apply-Accent([string]$hex) {
    if (-not $script:Win) { return }
    $c1 = Parse-Color $hex
    $hsl = Color-ToHsl $c1
    $h2 = ($hsl[0] + 0.055) % 1.0
    $l2 = [math]::Min(0.74, $hsl[2] + 0.12)
    $c2 = Hsl-ToColor $h2 $hsl[1] $l2
    $g = New-Object System.Windows.Media.LinearGradientBrush
    $g.StartPoint = New-Object System.Windows.Point(0,0)
    $g.EndPoint   = New-Object System.Windows.Point(1,1)
    $gs1 = New-Object System.Windows.Media.GradientStop; $gs1.Color = $c1; $gs1.Offset = 0.0
    $gs2 = New-Object System.Windows.Media.GradientStop; $gs2.Color = $c2; $gs2.Offset = 1.0
    [void]$g.GradientStops.Add($gs1); [void]$g.GradientStops.Add($gs2)
    $g.Freeze()
    # NOTE: assigning through the indexer (Resources['x'] = ...) re-evaluates
    # DynamicResource references with a type-conversion path that rejects the
    # brush.  Remove + Add notifies owners correctly instead.
    if ($script:Win.Resources.Contains('AccentGradient')) { $script:Win.Resources.Remove('AccentGradient') }
    $script:Win.Resources.Add('AccentGradient', $g)
    if ($script:Win.Resources.Contains('Accent')) { $script:Win.Resources.Remove('Accent') }
    $script:Win.Resources.Add('Accent', (New-Object System.Windows.Media.SolidColorBrush $c1))
}

function Apply-Settings {
    Apply-Background
    Apply-Accent $script:Settings.Accent
}

# ---------------------------------------------------------------------
#  Appearance page
# ---------------------------------------------------------------------
function New-Swatch {
    param([string]$Hex, $OnClick, [bool]$Active = $false, [string]$Tip = '')
    $b = New-Object System.Windows.Controls.Border
    $b.Width = 34; $b.Height = 34
    $b.CornerRadius = New-Object System.Windows.CornerRadius(9)
    $b.Margin = New-Object System.Windows.Thickness(0,0,9,9)
    $b.Cursor = [System.Windows.Input.Cursors]::Hand
    $b.Tag = $Hex
    if ($Tip) { $b.ToolTip = $Tip }
    $b.Background = New-Object System.Windows.Media.SolidColorBrush (Parse-Color $Hex)
    if ($Active) {
        $b.BorderBrush = Brush '#FFFFFF'
        $b.BorderThickness = New-Object System.Windows.Thickness(2.5)
    } else {
        $b.BorderBrush = Brush '#3A4557'
        $b.BorderThickness = New-Object System.Windows.Thickness(1)
    }
    if ($OnClick) { $b.Add_MouseLeftButtonUp($OnClick) }
    return $b
}

function New-GradSwatch {
    param($Preset, $OnClick, [bool]$Active = $false)
    $b = New-Object System.Windows.Controls.Border
    $b.Width = 88; $b.Height = 44
    $b.CornerRadius = New-Object System.Windows.CornerRadius(9)
    $b.Margin = New-Object System.Windows.Thickness(0,0,10,10)
    $b.Cursor = [System.Windows.Input.Cursors]::Hand
    $b.Tag = $Preset
    $b.ToolTip = $Preset.Name
    $b.Background = New-GradientBrush $Preset.C1 $Preset.C2 'diag'
    if ($Active) {
        $b.BorderBrush = Brush '#FFFFFF'; $b.BorderThickness = New-Object System.Windows.Thickness(2.5)
    } else {
        $b.BorderBrush = Brush '#3A4557'; $b.BorderThickness = New-Object System.Windows.Thickness(1)
    }
    if ($OnClick) { $b.Add_MouseLeftButtonUp($OnClick) }
    return $b
}

function Add-AppearLabel {
    param($Parent, [string]$Text, [string]$Hex = '#5E6A7E', [double]$Top = 0)
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $Text; $t.FontSize = 10.5
    $t.FontWeight = [System.Windows.FontWeights]::Bold
    $t.Foreground = Brush $Hex
    $t.Margin = New-Object System.Windows.Thickness(0,$Top,0,8)
    [void]$Parent.Children.Add($t)
}

function Build-Appearance {
    if (-not $script:AppearStack) { return }
    $script:AppearStack.Children.Clear()
    $accent = $script:Settings.Accent

    # ---- background style ----
    $c = New-Card -Title 'BACKGROUND STYLE' -Accent $accent
    $row = New-Object System.Windows.Controls.StackPanel
    $row.Orientation = 'Horizontal'
    foreach ($m in @(
        [pscustomobject]@{ Id='gradient'; Label='Gradient' },
        [pscustomobject]@{ Id='solid';    Label='Solid colour' },
        [pscustomobject]@{ Id='image';    Label='Photo' })) {
        $tb = New-Object System.Windows.Controls.Primitives.ToggleButton
        $tb.Style = $script:Win.FindResource('Chip')
        $tb.Content = $m.Label
        $tb.Tag = $m.Id
        $tb.IsChecked = ($script:Settings.BgType -eq $m.Id)
        $tb.Add_Click({
            param($s, $e)
            $s.IsChecked = $true
            $script:Settings.BgType = $s.Tag
            Apply-Settings; Save-Settings
            Build-Appearance
        })
        [void]$row.Children.Add($tb)
    }
    [void]$c.Body.Children.Add($row)
    $hint = New-Object System.Windows.Controls.TextBlock
    $hint.Text = 'Pick a gradient, a flat colour, or your own photo. Photos are dimmed by the slider below so text stays readable.'
    $hint.FontSize = 12; $hint.Foreground = Brush '#8B95A7'; $hint.TextWrapping = 'Wrap'
    $hint.Margin = New-Object System.Windows.Thickness(0,10,0,0)
    [void]$c.Body.Children.Add($hint)
    [void]$script:AppearStack.Children.Add($c.Border)

    # ---- gradients ----
    $cg = New-Card -Title 'GRADIENTS' -Accent $accent
    $gw = New-Object System.Windows.Controls.WrapPanel
    foreach ($p in $script:BgGradients) {
        $active = ($script:Settings.BgType -eq 'gradient' -and $script:Settings.BgColor1 -eq $p.C1 -and $script:Settings.BgColor2 -eq $p.C2)
        [void]$gw.Children.Add((New-GradSwatch -Preset $p -Active $active -OnClick {
            param($s, $e)
            $script:Settings.BgType   = 'gradient'
            $script:Settings.BgColor1 = $s.Tag.C1
            $script:Settings.BgColor2 = $s.Tag.C2
            Apply-Settings; Save-Settings; Build-Appearance
        }))
    }
    [void]$cg.Body.Children.Add($gw)
    [void]$script:AppearStack.Children.Add($cg.Border)

    # ---- solid colours ----
    $cs = New-Card -Title 'SOLID COLOURS' -Accent $accent
    $sw = New-Object System.Windows.Controls.WrapPanel
    foreach ($hex in $script:BgSolids) {
        $active = ($script:Settings.BgType -eq 'solid' -and $script:Settings.BgColor -eq $hex)
        [void]$sw.Children.Add((New-Swatch -Hex $hex -Active $active -Tip $hex -OnClick {
            param($s, $e)
            $script:Settings.BgType  = 'solid'
            $script:Settings.BgColor = $s.Tag
            Apply-Settings; Save-Settings; Build-Appearance
        }))
    }
    [void]$cs.Body.Children.Add($sw)
    [void]$script:AppearStack.Children.Add($cs.Border)

    # ---- photo ----
    $cp = New-Card -Title 'PHOTO' -Accent $accent
    $prow = New-Object System.Windows.Controls.StackPanel
    $prow.Orientation = 'Horizontal'
    $choose = New-Object System.Windows.Controls.Button
    $choose.Style = $script:Win.FindResource('Btn'); $choose.Content = 'Choose photo...'
    $choose.Padding = New-Object System.Windows.Thickness(18,9,18,9)
    $choose.Add_Click({
        $dlg = New-Object Microsoft.Win32.OpenFileDialog
        $dlg.Title = 'Choose a background image'
        $dlg.Filter = 'Images|*.jpg;*.jpeg;*.png;*.bmp;*.gif;*.webp|All files|*.*'
        $dlg.CheckFileExists = $true
        if ($dlg.ShowDialog() -eq $true) {
            $script:Settings.BgType  = 'image'
            $script:Settings.BgImage = $dlg.FileName
            Apply-Settings; Save-Settings; Build-Appearance
            Write-Log ('Background photo set: {0}' -f $dlg.FileName) 'accent'
        }
    })
    [void]$prow.Children.Add($choose)
    $remove = New-Object System.Windows.Controls.Button
    $remove.Style = $script:Win.FindResource('Ghost'); $remove.Content = 'Remove photo'
    $remove.Padding = New-Object System.Windows.Thickness(18,9,18,9)
    $remove.Margin = New-Object System.Windows.Thickness(10,0,0,0)
    $remove.Add_Click({
        $script:Settings.BgImage = ''
        if ($script:Settings.BgType -eq 'image') { $script:Settings.BgType = 'gradient' }
        Apply-Settings; Save-Settings; Build-Appearance
    })
    [void]$prow.Children.Add($remove)
    [void]$cp.Body.Children.Add($prow)
    $ptxt = New-Object System.Windows.Controls.TextBlock
    $ptxt.Text = if ($script:Settings.BgImage) { $script:Settings.BgImage } else { 'No photo selected.' }
    $ptxt.FontSize = 11.5; $ptxt.Foreground = Brush '#8B95A7'; $ptxt.TextWrapping = 'Wrap'
    $ptxt.Margin = New-Object System.Windows.Thickness(0,12,0,0)
    [void]$cp.Body.Children.Add($ptxt)
    [void]$script:AppearStack.Children.Add($cp.Border)

    # ---- dim + direction ----
    $cd = New-Card -Title 'DIM & LAYOUT' -Accent $accent
    Add-AppearLabel $cd.Body ('DIM PHOTO / BACKGROUND  -  ' + [int]([double]$script:Settings.BgScrim * 100) + '%')
    $sl = New-Object System.Windows.Controls.Slider
    $sl.Minimum = 0; $sl.Maximum = 80
    $sl.Value = [double]$script:Settings.BgScrim * 100
    $sl.Width = 320
    $sl.HorizontalAlignment = 'Left'
    $script:SuppressSlider = $true
    $sl.Add_ValueChanged({
        param($s, $e)
        if ($script:SuppressSlider) { return }
        $script:Settings.BgScrim = [math]::Round($s.Value / 100.0, 3)
        Apply-Background
    })
    $sl.Add_MouseLeftButtonUp({
        $script:SuppressSlider = $false
        Save-Settings; Build-Appearance
    })
    $sl.Add_LostMouseCapture({ $script:SuppressSlider = $false; Save-Settings })
    [void]$cd.Body.Children.Add($sl)
    $script:SuppressSlider = $false

    Add-AppearLabel $cd.Body 'GRADIENT DIRECTION' '#5E6A7E' 12
    $drow = New-Object System.Windows.Controls.StackPanel
    $drow.Orientation = 'Horizontal'
    foreach ($d in @(
        [pscustomobject]@{ Id='diag';  Label='Diagonal' },
        [pscustomobject]@{ Id='vert';  Label='Vertical' },
        [pscustomobject]@{ Id='horiz'; Label='Horizontal' })) {
        $tb = New-Object System.Windows.Controls.Primitives.ToggleButton
        $tb.Style = $script:Win.FindResource('Chip')
        $tb.Content = $d.Label; $tb.Tag = $d.Id
        $tb.IsChecked = ($script:Settings.BgDir -eq $d.Id)
        $tb.Add_Click({
            param($s, $e)
            $s.IsChecked = $true
            $script:Settings.BgDir = $s.Tag
            Apply-Settings; Save-Settings; Build-Appearance
        })
        [void]$drow.Children.Add($tb)
    }
    [void]$cd.Body.Children.Add($drow)
    [void]$script:AppearStack.Children.Add($cd.Border)

    # ---- accent ----
    $ca = New-Card -Title 'ACCENT COLOUR' -Accent $accent
    $aw = New-Object System.Windows.Controls.WrapPanel
    foreach ($hex in $script:AccentPresets) {
        [void]$aw.Children.Add((New-Swatch -Hex $hex -Active ($script:Settings.Accent -eq $hex) -Tip $hex -OnClick {
            param($s, $e)
            $script:Settings.Accent = $s.Tag
            Apply-Settings; Save-Settings; Build-Appearance
            Write-Log ('Accent colour set to {0}' -f $s.Tag) 'accent'
        }))
    }
    [void]$ca.Body.Children.Add($aw)
    [void]$script:AppearStack.Children.Add($ca.Border)

    # ---- reset ----
    $cr = New-Card -Title 'RESET' -Accent '#FBBF24'
    $rb = New-Object System.Windows.Controls.Button
    $rb.Style = $script:Win.FindResource('Ghost'); $rb.Content = 'Restore default look'
    $rb.Padding = New-Object System.Windows.Thickness(18,9,18,9)
    $rb.HorizontalAlignment = 'Left'
    $rb.Add_Click({
        $script:Settings = Get-DefaultSettings
        Apply-Settings; Save-Settings; Build-Appearance
        Write-Log 'Appearance reset to defaults.' 'ok'
    })
    [void]$cr.Body.Children.Add($rb)
    [void]$script:AppearStack.Children.Add($cr.Border)
}
