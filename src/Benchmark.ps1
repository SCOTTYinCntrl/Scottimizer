# =====================================================================
#  Scottimizer 2  -  Benchmark
#  Per-tweak "before / after" latency benchmarking plus the Benchmarks
#  page (summary, table, export, clear).
#  Dot-sourced by Scottimizer.ps1 (after Personalize.ps1).
# =====================================================================

# ---------------------------------------------------------------------
#  Lean ping used during benchmarking (no status spam, short interval)
# ---------------------------------------------------------------------
function Invoke-QuickPing([string]$Target, [int]$Count = 5) {
    if (-not $Target) { $Target = '1.1.1.1' }
    if ($Count -lt 1) { $Count = 1 }
    if ($Count -gt 20) { $Count = 20 }
    $png   = New-Object System.Net.NetworkInformation.Ping
    $times = New-Object System.Collections.Generic.List[double]
    $lost  = 0
    try {
        for ($i = 0; $i -lt $Count; $i++) {
            try {
                $r = $png.Send($Target, 800)
                if ($r.Status -eq 'Success') { [void]$times.Add([double]$r.RoundtripTime) } else { $lost++ }
            } catch { $lost++ }
            if ($i -lt ($Count - 1)) { Start-Sleep -Milliseconds 60 }
        }
    } finally { $png.Dispose() }
    if ($times.Count -eq 0) { return $null }
    $arr = @($times)
    $avg = ($arr | Measure-Object -Average).Average
    $jit = 0.0
    if ($arr.Count -gt 1) {
        $d = 0.0
        for ($i = 1; $i -lt $arr.Count; $i++) { $d += [math]::Abs($arr[$i] - $arr[$i-1]) }
        $jit = $d / ($arr.Count - 1)
    }
    return [pscustomobject]@{
        Avg    = [math]::Round($avg, 1)
        Jitter = [math]::Round($jit, 1)
        Loss   = [math]::Round(100 * $lost / $Count)
    }
}

# ---------------------------------------------------------------------
#  Benchmark store
# ---------------------------------------------------------------------
function Get-BenchPath { Join-Path $script:AppRoot 'benchmarks.json' }

function Load-Benchmarks {
    $script:Benchmarks = New-Object System.Collections.ArrayList
    $path = Get-BenchPath
    if (Test-Path -LiteralPath $path) {
        try {
            # Assign first: ConvertFrom-Json emits the array as a single object,
            # so @(pipeline) would wrap it whole instead of enumerating it.
            $parsed = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($r in @($parsed)) {
                if ($r -and (@($r.PSObject.Properties.Name) -contains 'Name')) {
                    [void]$script:Benchmarks.Add($r)
                }
            }
        } catch {}
    }
}

function Save-Benchmarks {
    try {
        $items = @($script:Benchmarks)
        if ($items.Count -eq 0) {
            Set-Content -LiteralPath (Get-BenchPath) -Value '[]' -Encoding UTF8
            return
        }
        # Always emit a JSON *array*, even for a single record, so loading is
        # predictable (ConvertTo-Json drops the array for a one-item pipeline).
        $parts = @(foreach ($it in $items) { $it | ConvertTo-Json -Depth 5 -Compress })
        Set-Content -LiteralPath (Get-BenchPath) -Value ('[' + ($parts -join ',') + ']') -Encoding UTF8
    } catch {}
}

function Add-BenchmarkRecord {
    param(
        [string]$Name,
        [string]$Id = '',
        [string]$Target = '1.1.1.1',
        $Before,
        $After,
        [bool]$Manual = $false
    )
    if ($null -eq $script:Benchmarks) { Load-Benchmarks }
    $b = if ($Before) { [double]$Before.Avg } else { $null }
    $a = if ($After)  { [double]$After.Avg }  else { $null }
    $delta = if ($null -ne $b -and $null -ne $a) { [math]::Round($a - $b, 1) } else { $null }
    $rec = [pscustomobject]@{
        Time         = (Get-Date).ToString('s')
        Name         = $Name
        Id           = $Id
        Target       = $Target
        Before       = $b
        After        = $a
        JitterBefore = $(if ($Before) { [double]$Before.Jitter } else { $null })
        JitterAfter  = $(if ($After)  { [double]$After.Jitter }  else { $null })
        Loss         = $(if ($After)  { [double]$After.Loss }    else { $null })
        Delta        = $delta
        Manual       = $Manual
    }
    [void]$script:Benchmarks.Insert(0, $rec)
    Save-Benchmarks
    return $rec
}

function Clear-Benchmarks {
    $script:Benchmarks = New-Object System.Collections.ArrayList
    Save-Benchmarks
}

# ---------------------------------------------------------------------
#  Benchmarks page
# ---------------------------------------------------------------------
function Add-BenchCell {
    param($Grid, [int]$Col, [string]$Text, [string]$Color = '#C9D1E0', [string]$Weight = 'Normal')
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $Text
    $t.FontSize = 12.5
    $t.Foreground = Brush $Color
    if ($Weight -eq 'Bold') { $t.FontWeight = [System.Windows.FontWeights]::SemiBold }
    $t.VerticalAlignment = 'Center'
    $t.TextTrimming = 'CharacterEllipsis'
    $t.Margin = New-Object System.Windows.Thickness(0)
    [System.Windows.Controls.Grid]::SetColumn($t, $Col)
    [void]$Grid.Children.Add($t)
}

function New-BenchRow($r, [string]$Zebra) {
    $g = New-Object System.Windows.Controls.Grid
    $g.Margin = New-Object System.Windows.Thickness(0,0,0,0)
    foreach ($w in '0.9*','72','72','78','*','96') {
        $cd = New-Object System.Windows.Controls.ColumnDefinition
        $cd.Width = [System.Windows.GridLength]::new([double]($w -replace '[^\d\.]',''), $(if ($w -like '*') { [System.Windows.GridUnitType]::Star } else { [System.Windows.GridUnitType]::Pixel }))
        [void]$g.ColumnDefinitions.Add($cd)
    }
    $bg = New-Object System.Windows.Controls.Border
    $bg.Background = Brush $Zebra
    $bg.CornerRadius = New-Object System.Windows.CornerRadius(8)
    $bg.Padding = New-Object System.Windows.Thickness(12,9,12,9)
    [System.Windows.Controls.Grid]::SetColumnSpan($bg, 6)

    $name = if ($r.Manual) { 'Latency reading' } else { $r.Name }
    Add-BenchCell $g 0 $name '#E6EAF2' 'Bold'
    Add-BenchCell $g 1 $(if ($null -ne $r.Before) { "$($r.Before)" } else { '-' }) '#8B95A7'
    Add-BenchCell $g 2 $(if ($null -ne $r.After)  { "$($r.After)" }  else { '-' }) '#C9D1E0'

    if ($null -ne $r.Delta) {
        $dv = [double]$r.Delta
        $dcol = '#8B95A7'; $txt = '0.0'
        if ($dv -lt -0.05) { $dcol = '#34D399'; $txt = ("{0:N1}" -f $dv) }      # faster
        elseif ($dv -gt 0.05) { $dcol = '#F87171'; $txt = ("+{0:N1}" -f $dv) }  # slower
        else { $txt = '0.0' }
        Add-BenchCell $g 3 "$txt ms" $dcol 'Bold'
    } else {
        Add-BenchCell $g 3 '-' '#5E6A7E'
    }

    Add-BenchCell $g 4 $r.Target '#7C8AA0'
    $jt = if ($null -ne $r.JitterBefore -or $null -ne $r.JitterAfter) {
        ("j {0} -> {1}" -f $(if ($null -ne $r.JitterBefore) { $r.JitterBefore } else { '-' }),
                            $(if ($null -ne $r.JitterAfter)  { $r.JitterAfter }  else { '-' }))
    } else { '' }
    Add-BenchCell $g 5 $jt '#7C8AA0'

    $bg.Child = $g
    $wrap = New-Object System.Windows.Controls.Grid
    [void]$wrap.Children.Add($bg)
    $wrap.Margin = New-Object System.Windows.Thickness(0,0,0,6)
    return $wrap
}

function Build-Benchmarks {
    if (-not $script:BenchStack) { return }
    $script:BenchStack.Children.Clear()
    if ($null -eq $script:Benchmarks) { Load-Benchmarks }
    $list = @($script:Benchmarks)

    # ---- summary ----
    $deltas = @($list | Where-Object { $null -ne $_.Delta } | ForEach-Object { [double]$_.Delta })
    $c = New-Card -Title 'LATENCY BENCHMARKS' -Accent '#22D3EE'
    $sub = New-Object System.Windows.Controls.TextBlock
    $sub.FontSize = 12.5; $sub.Foreground = Brush '#9AA4B5'; $sub.TextWrapping = 'Wrap'
    $sub.Text = 'Switch on "Benchmark latency" in the footer and press Apply selected: Scottimizer pings your target before and after each tweak so you can see the real effect on ping and jitter.'
    [void]$c.Body.Children.Add($sub)

    $tiles = New-Object System.Windows.Controls.StackPanel
    $tiles.Orientation = 'Horizontal'; $tiles.Margin = New-Object System.Windows.Thickness(0,14,0,0)
    Add-InfoTile $tiles 'Measurements' ([string]$list.Count) '#E6EAF2'
    if ($deltas.Count -gt 0) {
        $avg = ($deltas | Measure-Object -Average).Average
        $best = ($deltas | Measure-Object -Minimum).Minimum
        $worst = ($deltas | Measure-Object -Maximum).Maximum
        Add-InfoTile $tiles 'Average change' ("{0:N1} ms" -f $avg) $(if ($avg -le 0) { '#34D399' } else { '#FBBF24' })
        Add-InfoTile $tiles 'Best' ("{0:N1} ms" -f $best) '#34D399'
        Add-InfoTile $tiles 'Worst' ("{0:N1} ms" -f $worst) '#F87171'
    } else {
        Add-InfoTile $tiles 'Average change' 'n/a' '#8B95A7'
    }
    [void]$c.Body.Children.Add($tiles)

    # ---- controls ----
    $ctl = New-Object System.Windows.Controls.StackPanel
    $ctl.Orientation = 'Horizontal'; $ctl.Margin = New-Object System.Windows.Thickness(0,16,0,0)
    $tb = New-Object System.Windows.Controls.TextBox
    $tb.Style = $script:Win.FindResource('Field'); $tb.Width = 170
    $tb.Text = $script:Settings.BenchTarget
    $tb.ToolTip = 'Ping target (IP or host)'
    [void]$ctl.Children.Add($tb)
    $cnt = New-Object System.Windows.Controls.TextBox
    $cnt.Style = $script:Win.FindResource('Field'); $cnt.Width = 60
    $cnt.Margin = New-Object System.Windows.Thickness(10,0,0,0)
    $cnt.Text = [string]$script:Settings.BenchCount
    $cnt.ToolTip = 'Samples per measurement'
    [void]$ctl.Children.Add($cnt)
    # keep script-scope refs so the click handler (which runs later) can read them
    $script:BenchTargetBox = $tb
    $script:BenchCountBox  = $cnt
    $now = New-Object System.Windows.Controls.Button
    $now.Style = $script:Win.FindResource('Btn'); $now.Content = 'Measure now'
    $now.Padding = New-Object System.Windows.Thickness(18,9,18,9)
    $now.Margin = New-Object System.Windows.Thickness(10,0,0,0)
    $now.Add_Click({
        $script:Settings.BenchTarget = $script:BenchTargetBox.Text.Trim()
        $script:Settings.BenchCount  = [int]($script:BenchCountBox.Text -as [int])
        if ($script:Settings.BenchCount -lt 1) { $script:Settings.BenchCount = 5 }
        Save-Settings
        Set-Busy $true
        try {
            Write-Log ("Benchmark reading -> {0} ({1} samples)" -f $script:Settings.BenchTarget, $script:Settings.BenchCount) 'accent'
            $res = Invoke-QuickPing $script:Settings.BenchTarget $script:Settings.BenchCount
            if ($res) {
                Add-BenchmarkRecord -Name 'Latency reading' -Target $script:Settings.BenchTarget -After $res -Manual $true
                Write-Log ("Result: avg {0} ms, jitter {1} ms, loss {2}%" -f $res.Avg, $res.Jitter, $res.Loss) 'ok'
            } else {
                Write-Log 'No reply from that host.' 'err'
            }
        } finally { Set-Busy $false; Set-Status 'Ready.' }
        Build-Benchmarks
    })
    [void]$ctl.Children.Add($now)
    $exp = New-Object System.Windows.Controls.Button
    $exp.Style = $script:Win.FindResource('Ghost'); $exp.Content = 'Export CSV'
    $exp.Padding = New-Object System.Windows.Thickness(18,9,18,9)
    $exp.Margin = New-Object System.Windows.Thickness(10,0,0,0)
    $exp.Add_Click({
        if (@($script:Benchmarks).Count -eq 0) { return }
        $dlg = New-Object Microsoft.Win32.SaveFileDialog
        $dlg.Title = 'Export benchmarks'
        $dlg.Filter = 'CSV|*.csv'
        $dlg.FileName = ('scottimizer-benchmarks-{0}.csv' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
        if ($dlg.ShowDialog() -eq $true) {
            try {
                @($script:Benchmarks) | Select-Object Time,Name,Target,Before,After,Delta,JitterBefore,JitterAfter,Loss |
                    Export-Csv -LiteralPath $dlg.FileName -NoTypeInformation -Encoding UTF8
                Write-Log ('Benchmarks exported: {0}' -f $dlg.FileName) 'ok'
            } catch { Write-Log ("Export failed: {0}" -f $_.Exception.Message) 'err' }
        }
    })
    [void]$ctl.Children.Add($exp)
    $clr = New-Object System.Windows.Controls.Button
    $clr.Style = $script:Win.FindResource('Danger'); $clr.Content = 'Clear'
    $clr.Padding = New-Object System.Windows.Thickness(18,9,18,9)
    $clr.Margin = New-Object System.Windows.Thickness(10,0,0,0)
    $clr.Add_Click({
        Clear-Benchmarks
        Write-Log 'Benchmark history cleared.' 'ok'
        Build-Benchmarks
    })
    [void]$ctl.Children.Add($clr)
    [void]$c.Body.Children.Add($ctl)
    [void]$script:BenchStack.Children.Add($c.Border)

    # ---- table ----
    if ($list.Count -eq 0) { return }
    $t = New-Card -Title 'RESULTS' -Accent '#9B82FF'
    $hdr = New-Object System.Windows.Controls.Grid
    foreach ($w in '0.9*','72','72','78','*','96') {
        $cd = New-Object System.Windows.Controls.ColumnDefinition
        $cd.Width = [System.Windows.GridLength]::new([double]($w -replace '[^\d\.]',''), $(if ($w -like '*') { [System.Windows.GridUnitType]::Star } else { [System.Windows.GridUnitType]::Pixel }))
        [void]$hdr.ColumnDefinitions.Add($cd)
    }
    Add-BenchCell $hdr 0 'TWEAK' '#5E6A7E' 'Bold'
    Add-BenchCell $hdr 1 'BEFORE' '#5E6A7E' 'Bold'
    Add-BenchCell $hdr 2 'AFTER' '#5E6A7E' 'Bold'
    Add-BenchCell $hdr 3 'CHANGE' '#5E6A7E' 'Bold'
    Add-BenchCell $hdr 4 'TARGET' '#5E6A7E' 'Bold'
    Add-BenchCell $hdr 5 'JITTER' '#5E6A7E' 'Bold'
    $hdr.Margin = New-Object System.Windows.Thickness(12,0,12,6)
    [void]$t.Body.Children.Add($hdr)
    $z = $false
    foreach ($r in ($list | Select-Object -First 200)) {
        $zebra = if ($z) { '#80161E2C' } else { '#00000000' }
        [void]$t.Body.Children.Add((New-BenchRow $r $zebra))
        $z = -not $z
    }
    [void]$script:BenchStack.Children.Add($t.Border)
}
