# =====================================================================
#  Scottimizer 2  -  Actions & pages
#  Page-building, apply/undo flows and dashboard/audit rendering.
#  Dot-sourced by Scottimizer.ps1 (after Ui.ps1).
# =====================================================================

# ---------------------------------------------------------------------
#  Navigation
# ---------------------------------------------------------------------
function New-NavButton($page) {
    $rb = New-Object System.Windows.Controls.RadioButton
    $rb.Style = $script:Win.FindResource('NavItem')
    $rb.GroupName = 'Nav'
    $rb.Tag = $page

    $dock = New-Object System.Windows.Controls.StackPanel
    $dock.Orientation = 'Horizontal'
    $ico = New-Object System.Windows.Controls.TextBlock
    $ico.Text = [string][char]$page.Glyph
    $ico.FontFamily = New-Object System.Windows.Media.FontFamily('Segoe MDL2 Assets')
    $ico.FontSize = 14
    $ico.Width = 26
    $ico.VerticalAlignment = 'Center'
    $txt = New-Object System.Windows.Controls.TextBlock
    $txt.Text = $page.Title
    $txt.FontSize = 13
    $txt.VerticalAlignment = 'Center'
    [void]$dock.Children.Add($ico)
    [void]$dock.Children.Add($txt)
    $rb.Content = $dock

    $rb.Add_Checked({
        param($s, $e)
        $p = $s.Tag
        $script:ActivePage = $p
        if ($script:SearchBox.Text) { $script:SuppressSearch = $true; $script:SearchBox.Text = ''; $script:SuppressSearch = $false }
        Show-Page $p
    })
    [void]$script:NavStack.Children.Add($rb)
    return $rb
}

function Show-Page($page) {
    if ($page.Kind -eq 'group') {
        $script:ActiveGroup = $page.Group
        $script:TweakHost.Visibility = 'Visible'
        $script:SpecialHost.Visibility = 'Collapsed'
        $script:ToolbarPanel.Visibility = 'Visible'
        $script:ToolbarRight.Visibility = 'Visible'
        Update-TweakVisibility
        Update-ActiveBadges $page.Group
    } else {
        $script:ActiveGroup = $null
        $script:TweakHost.Visibility = 'Collapsed'
        $script:SpecialHost.Visibility = 'Visible'
        $script:ToolbarPanel.Visibility = 'Collapsed'
        $script:ToolbarRight.Visibility = 'Collapsed'
        foreach ($s in @($script:DashScroll, $script:BenchScroll, $script:AppearScroll, $script:AuditScroll, $script:AboutScroll)) {
            if ($s) { $s.Visibility = 'Collapsed' }
        }
        $target = $script:Win.FindName($page.Target)
        if ($target) { $target.Visibility = 'Visible' }
        if ($page.Id -eq 'Benchmarks') { Build-Benchmarks }
        if ($page.Id -eq 'Appearance') { Build-Appearance }
        if ($page.Id -eq 'Audit' -and -not $script:AuditDone) { Invoke-Audit }
    }
    $script:PageTitle.Text = $page.Title
    $script:PageSub.Text   = $page.Sub
}

function Update-TweakVisibility {
    $q = $script:SearchBox.Text.Trim()
    foreach ($t in $script:Tweaks) {
        if ($q) {
            $hay = ("{0} {1} {2} {3}" -f $t.Name, $t.Desc, (($t.Tags) -join ' '), $t.Group)
            $t.Check.Visibility = if ($hay -like "*$q*") { 'Visible' } else { 'Collapsed' }
        } else {
            $t.Check.Visibility = if ((-not $script:ActiveGroup) -or ($t.Group -eq $script:ActiveGroup)) { 'Visible' } else { 'Collapsed' }
        }
    }
}

function Update-ActiveBadges([string]$group) {
    foreach ($t in $script:Tweaks) {
        if ($group -and $t.Group -ne $group) { continue }
        $active = $false
        if ($t.Test) { try { $active = [bool](& $t.Test) } catch { $active = $false } }
        $existing = @($t.Badges.Children | Where-Object { $_.Tag -eq 'active' })
        if ($active -and $existing.Count -eq 0) {
            $b = New-ActiveBadge; $b.Tag = 'active'
            [void]$t.Badges.Children.Insert(0, $b)
        } elseif (-not $active -and $existing.Count -gt 0) {
            foreach ($e in $existing) { [void]$t.Badges.Children.Remove($e) }
        }
    }
}

function Apply-Profile($profile) {
    foreach ($t in $script:Tweaks) {
        $sel = $false
        try { $sel = [bool](& $profile.Select $t) } catch {}
        $t.Check.IsChecked = $sel
    }
    Write-Log ("Profile applied: {0}" -f $profile.Name) 'accent'
    Update-TweakVisibility
}

function Navigate-To([string]$id) {
    $page = @($script:Pages | Where-Object { $_.Id -eq $id })[0]
    if (-not $page) { return }
    foreach ($rb in @($script:NavStack.Children)) { if ($rb.Tag.Id -eq $id) { $rb.IsChecked = $true } }
    Show-Page $page
}

# ---------------------------------------------------------------------
#  Busy / status
# ---------------------------------------------------------------------
function Set-Busy([bool]$busy) {
    foreach ($c in @($script:ApplyBtn, $script:UndoBtn)) { $c.IsEnabled = (-not $busy) }
    if ($busy) { $script:Win.Cursor = [System.Windows.Input.Cursors]::Wait } else { $script:Win.Cursor = [System.Windows.Input.Cursors]::Arrow }
    Pump
}

function CreateRestorePoint-UI {
    Set-Status 'Creating restore point (can take a few seconds)...'
    if (New-ScottimizerRestorePoint) { Write-Log 'Restore point created.' 'ok'; Set-Status 'Restore point created.' 'ok' }
    else { Write-Log 'Restore point skipped (System Protection may be off).' 'warn'; Set-Status 'Restore point skipped.' 'warn' }
}

# ---------------------------------------------------------------------
#  Dashboard
# ---------------------------------------------------------------------
function Build-Dashboard {
    $script:DashStack.Children.Clear()

    $pc = New-Card -Title 'THIS PC'
    $info = Get-SystemInfo
    Add-InfoTile $pc.Body 'CPU' $info.Cpu
    Add-InfoTile $pc.Body 'GPU' $info.Gpu
    Add-InfoTile $pc.Body 'Memory' ("{0} GB" -f $info.RamGB)
    Add-InfoTile $pc.Body 'Operating system' $info.Os
    Add-InfoTile $pc.Body 'Uptime' $info.Uptime
    if ($info.Mobo) { Add-InfoTile $pc.Body 'System model' $info.Mobo }
    foreach ($d in $info.Disks) { Add-InfoTile $pc.Body 'Disk' ("{0} ({1} GB)" -f $d.Model, $d.GB) }
    [void]$script:DashStack.Children.Add($pc.Border)

    $sec = New-Card -Title 'SECURITY SCORE' -Accent '#34D399'
    $row = New-Object System.Windows.Controls.DockPanel
    $row.LastChildFill = $true

    $ring = New-Object System.Windows.Controls.Border
    $ring.Width = 96; $ring.Height = 96
    $ring.CornerRadius = New-Object System.Windows.CornerRadius(48)
    $ring.Background = Brush '#0E1626'
    $ring.BorderThickness = New-Object System.Windows.Thickness(4)
    $ring.BorderBrush = Brush '#34D399'
    $ring.Margin = New-Object System.Windows.Thickness(0,0,20,0)
    $inner = New-Object System.Windows.Controls.StackPanel
    $inner.VerticalAlignment = 'Center'
    $num = New-Object System.Windows.Controls.TextBlock
    $num.Text = '--'; $num.FontSize = 30; $num.FontWeight = [System.Windows.FontWeights]::Bold
    $num.Foreground = Brush '#EEF1F8'; $num.HorizontalAlignment = 'Center'
    $ring.Child = $inner
    $glbl = New-Object System.Windows.Controls.TextBlock
    $glbl.Text = ($script:GradeText -as [string]); $glbl.FontSize = 11; $glbl.Foreground = Brush '#8B95A7'
    $glbl.HorizontalAlignment = 'Center'
    [void]$inner.Children.Add($num); [void]$inner.Children.Add($glbl)
    [System.Windows.Controls.DockPanel]::SetDock($ring, [System.Windows.Controls.Dock]::Left)
    [void]$row.Children.Add($ring)

    $right = New-Object System.Windows.Controls.StackPanel
    $rtext = New-Object System.Windows.Controls.TextBlock
    $rtext.FontSize = 12.5; $rtext.Foreground = Brush '#9AA4B5'; $rtext.TextWrapping = 'Wrap'
    $rtext.Text = if ($script:ScoreSummary) { $script:ScoreSummary } else { "Run the audit to score this PC's security posture and fix weak settings in one click." }
    [void]$right.Children.Add($rtext)
    $btn = New-Object System.Windows.Controls.Button
    $btn.Style = $script:Win.FindResource('Btn')
    $btn.Content = 'Run security audit'; $btn.Padding = New-Object System.Windows.Thickness(18,9,18,9)
    $btn.Margin = New-Object System.Windows.Thickness(0,14,0,0); $btn.HorizontalAlignment = 'Left'
    $btn.Add_Click({ Invoke-Audit; Navigate-To 'Audit' })
    [void]$right.Children.Add($btn)
    [void]$row.Children.Add($right)
    [void]$sec.Body.Children.Add($row)
    [void]$script:DashStack.Children.Add($sec.Border)

    $net = New-Card -Title 'NETWORK & LATENCY' -Accent '#22D3EE'
    $n = Get-NetSummary
    Add-InfoTile $net.Body 'Adapter' $n.Adapter
    Add-InfoTile $net.Body 'Local IP' $n.LocalIp
    Add-InfoTile $net.Body 'Gateway' $n.Gateway
    Add-InfoTile $net.Body 'DNS' (@($n.Dns) -join ', ')
    $pg = New-Object System.Windows.Controls.StackPanel
    $pg.Orientation = 'Horizontal'; $pg.Margin = New-Object System.Windows.Thickness(0,6,0,0)
    $tb = New-Object System.Windows.Controls.TextBox
    $tb.Style = $script:Win.FindResource('Field'); $tb.Text = '1.1.1.1'; $tb.Width = 190
    $script:DashPingTarget = $tb
    $pb = New-Object System.Windows.Controls.Button
    $pb.Style = $script:Win.FindResource('Ghost'); $pb.Content = 'Test latency'
    $pb.Padding = New-Object System.Windows.Thickness(16,9,16,9); $pb.Margin = New-Object System.Windows.Thickness(10,0,0,0)
    $pb.Add_Click({
        Set-Busy $true
        try {
            Write-Log ("Latency test -> {0}" -f $script:DashPingTarget.Text) 'accent'
            $res = Invoke-PingTest -Target $script:DashPingTarget.Text -Count 10
            if ($res) {
                $script:DashPingResult.Text = ("avg {0} ms   min {1}   max {2}   jitter {3} ms   loss {4}%" -f $res.Avg, $res.Min, $res.Max, $res.Jitter, $res.Loss)
                Write-Log ("Result: avg {0} ms, jitter {1} ms, loss {2}%" -f $res.Avg, $res.Jitter, $res.Loss) 'ok'
            } else {
                $script:DashPingResult.Text = 'No reply from that host.'
                Write-Log 'Ping failed: no replies.' 'err'
            }
        } finally { Set-Busy $false; Set-Status 'Ready.' }
    })
    [void]$pg.Children.Add($tb); [void]$pg.Children.Add($pb)
    [void]$net.Body.Children.Add($pg)
    $pr = New-Object System.Windows.Controls.TextBlock
    $pr.FontSize = 13; $pr.Foreground = Brush '#34D399'; $pr.Margin = New-Object System.Windows.Thickness(0,10,0,0)
    $pr.Text = 'Not tested yet.'
    $script:DashPingResult = $pr
    [void]$net.Body.Children.Add($pr)
    [void]$script:DashStack.Children.Add($net.Border)

    $tools = New-Card -Title 'QUICK TOOLS' -Accent '#9B82FF'
    $wrap = New-Object System.Windows.Controls.WrapPanel
    function AddTool([string]$text, [string]$hint, $action) {
        $b = New-ToolButton -Text $text -Hint $hint
        $b.Add_Click($action)
        [void]$wrap.Children.Add($b)
    }
    AddTool 'Latency benchmarks' 'See per-tweak before/after ping results' { Navigate-To 'Benchmarks' }
    AddTool 'Create restore point' 'Snapshot Windows before you tweak' { CreateRestorePoint-UI }
    AddTool 'Flush DNS cache' 'Clear stale lookups' { Clear-DnsClientCache; ipconfig /flushdns | Out-Null; Write-Log 'DNS cache flushed.' 'ok' }
    AddTool 'Clear temp files' 'Delete temp files, skips files in use' { $r = Clear-TempFiles; Write-Log ("Temp cleaned: {0} items, {1} MB" -f $r.Count, $r.MB) 'ok' }
    AddTool 'Clear standby memory' 'Free cached RAM instantly' { if (Clear-StandbyList) { Write-Log 'Standby list cleared.' 'ok' } else { Write-Log 'Could not clear standby list.' 'warn' } }
    AddTool 'Trim working sets' 'Return RAM held by idle apps' { Clear-WorkingSets | Out-Null; Write-Log 'Working sets trimmed.' 'ok' }
    AddTool 'Reset network stack' 'Winsock/IP reset - reboot after' { if (Reset-NetworkStack) { Write-Log 'Network stack reset. Reboot recommended.' 'warn' } }
    AddTool 'Windows Update cache' 'Clear downloaded update cache' { if (Clear-WindowsUpdateCache) { Write-Log 'Update cache cleared.' 'ok' } }
    AddTool 'Component store cleanup' 'DISM cleanup - reclaim disk' {
        Set-Status 'Running DISM cleanup...'
        $ok = Invoke-ComponentCleanup
        if ($ok) { Write-Log 'Component cleanup complete.' 'ok' } else { Write-Log 'Component cleanup failed.' 'warn' }
        Set-Status 'Ready.'
    }
    AddTool 'System file check' 'Run SFC to repair corrupted files' { Start-Process cmd.exe -ArgumentList '/k','echo Running SFC... & sfc /scannow & echo. & echo Done.' | Out-Null }
    AddTool 'Empty Recycle Bin' 'Permanently delete bin contents' { if (Clear-RecycleBinSafe) { Write-Log 'Recycle Bin emptied.' 'ok' } }
    AddTool 'Disk cleanup wizard' 'Windows built-in cleanmgr' { Start-Process cleanmgr.exe | Out-Null }
    AddTool 'Reset power plans' 'Restore default power schemes' {
        $a = [System.Windows.MessageBox]::Show('Reset all power plans to Windows defaults? Custom plans will be removed.','Scottimizer','YesNo','Question')
        if ($a -eq 'Yes') { powercfg -restoredefaultschemes | Out-Null; Write-Log 'Power plans reset.' 'ok' }
    }
    [void]$tools.Body.Children.Add($wrap)
    [void]$script:DashStack.Children.Add($tools.Border)

    $leg = New-Card -Title 'RISK LEVELS' -Accent '#FBBF24'
    $lp = New-Object System.Windows.Controls.StackPanel
    function AddLegend([string]$risk, [string]$desc) {
        $d = New-Object System.Windows.Controls.DockPanel
        $b = New-Badge -Text $risk.ToUpper() -Color (Get-RiskColor $risk)
        [System.Windows.Controls.DockPanel]::SetDock($b, [System.Windows.Controls.Dock]::Left)
        [void]$d.Children.Add($b)
        $t = New-Object System.Windows.Controls.TextBlock
        $t.Text = $desc; $t.FontSize = 12; $t.Foreground = Brush '#8B95A7'
        $t.Margin = New-Object System.Windows.Thickness(12,0,0,0); $t.VerticalAlignment = 'Center'
        [void]$d.Children.Add($t)
        $d.Margin = New-Object System.Windows.Thickness(0,0,0,8)
        [void]$lp.Children.Add($d)
    }
    AddLegend 'Safe' 'Reversible, low risk, ideal for everyone.'
    AddLegend 'Moderate' 'Fixes a problem but changes behaviour. Read the description.'
    AddLegend 'Advanced' 'Can affect hardware, drivers or break specific setups.'
    [void]$leg.Body.Children.Add($lp)
    [void]$script:DashStack.Children.Add($leg.Border)
}

# ---------------------------------------------------------------------
#  Audit page
# ---------------------------------------------------------------------
function Invoke-Audit {
    Set-Status 'Running security audit...'
    Pump
    $script:AuditStack.Children.Clear()
    $items = Invoke-SecurityAudit
    $score = Get-AuditScore $items
    $grade = Get-AuditGrade $score
    $script:GradeText = "Grade $grade"
    $fails = @($items | Where-Object Status -eq 'fail').Count
    $warns = @($items | Where-Object Status -eq 'warn').Count
    $pass  = @($items | Where-Object Status -eq 'pass').Count
    $script:ScoreSummary = ("{0}/100 ({1})  -  {2} passed, {3} warnings, {4} failed." -f $score, $grade, $pass, $warns, $fails)

    $scoreColor = if ($score -ge 90) { '#34D399' } elseif ($score -ge 70) { '#FBBF24' } else { '#F87171' }

    $card = New-Card -Title 'SECURITY POSTURE' -Accent $scoreColor
    $st = New-Object System.Windows.Controls.TextBlock
    $st.FontSize = 40; $st.FontWeight = [System.Windows.FontWeights]::Bold; $st.Foreground = Brush $scoreColor
    $st.Text = ("{0}/100" -f $score)
    $sb = New-Object System.Windows.Controls.TextBlock
    $sb.FontSize = 12.5; $sb.Foreground = Brush '#9AA4B5'; $sb.Margin = New-Object System.Windows.Thickness(0,4,0,0)
    $sb.Text = $script:ScoreSummary
    [void]$card.Body.Children.Add($st); [void]$card.Body.Children.Add($sb)
    [void]$script:AuditStack.Children.Add($card.Border)

    $areas = @($items | ForEach-Object { $_.Area } | Select-Object -Unique)
    foreach ($area in $areas) {
        $group = @($items | Where-Object { $_.Area -eq $area } | Sort-Object @{Expression={ switch ($_.Status) { 'fail' {0} 'warn' {1} 'pass' {2} default {3} } }})
        [void]$script:AuditStack.Children.Add((New-AuditHeader $area))
        foreach ($it in $group) { [void]$script:AuditStack.Children.Add((New-AuditRow $it)) }
    }
    $script:AuditDone = $true
    Set-Status ("Audit complete: {0}/100 (grade {1})." -f $score, $grade) 'ok'
    $script:ScoreMini.Text = ("Security: {0}/100 ({1})" -f $score, $grade)
    $script:ScoreMini.Foreground = Brush $scoreColor
    if ($script:ActivePage.Id -eq 'Dashboard') { Build-Dashboard }
}

function Apply-SingleTweak([string]$id) {
    $t = @($script:Tweaks | Where-Object { $_.Id -eq $id })[0]
    if (-not $t) { return }
    Set-Busy $true
    try {
        Begin-StateSession
        Write-Log ("Applying fix: {0}" -f $t.Name) 'accent'
        try { & $t.Apply; [void]$script:State.AppliedTweaks.Add($t.Id); Save-ChangeState; Write-Log 'Applied.' 'ok' }
        catch { Write-Log ("Failed: {0}" -f $_.Exception.Message) 'err' }
    } finally { Set-Busy $false }
    Invoke-Audit
}

# ---------------------------------------------------------------------
#  About page
# ---------------------------------------------------------------------
function Build-About {
    $c1 = New-Card -Title ("WELCOME TO SCOTTIMIZER {0}" -f $script:Version)
    $p1 = New-Object System.Windows.Controls.TextBlock
    $p1.TextWrapping = 'Wrap'; $p1.FontSize = 12.5; $p1.Foreground = Brush '#9AA4B5'
    $p1.Text = "Scottimizer is a gaming performance, privacy and security tuner for Windows 10/11.`r`n`r`nPick a profile (or individual toggles), press Apply selected, then reboot if prompted. Everything is recorded before it changes - press Undo changes to restore your exact previous settings, not a guess."
    [void]$c1.Body.Children.Add($p1)
    [void]$script:AboutStack.Children.Add($c1.Border)

    $c2 = New-Card -Title 'PROFILES' -Accent '#22D3EE'
    foreach ($p in $script:Profiles) {
        $d = New-Object System.Windows.Controls.TextBlock
        $d.FontSize = 12.5; $d.Foreground = Brush '#9AA4B5'; $d.TextWrapping = 'Wrap'
        $d.Text = ("{0} - {1}" -f $p.Name, $p.Hint)
        $d.Margin = New-Object System.Windows.Thickness(0,0,0,6)
        [void]$c2.Body.Children.Add($d)
    }
    [void]$script:AboutStack.Children.Add($c2.Border)

    $c3 = New-Card -Title 'HOW UNDO WORKS' -Accent '#34D399'
    $p3 = New-Object System.Windows.Controls.TextBlock
    $p3.TextWrapping = 'Wrap'; $p3.FontSize = 12.5; $p3.Foreground = Brush '#9AA4B5'
    $p3.Text = "Before every change, Scottimizer stores the previous registry value, service state, power plan and DNS servers in a snapshot (state\last-apply.json).`r`n`r`nUndo changes -> Yes : restores that snapshot exactly.`r`nUndo changes -> No : resets the tweaks to Windows defaults instead.`r`n`r`nSome tweaks (GPU timeout, Memory Integrity, SMBv1, power plans) need a restart to take or undo."
    [void]$c3.Body.Children.Add($p3)
    [void]$script:AboutStack.Children.Add($c3.Border)

    $c4 = New-Card -Title 'SAFETY NOTES' -Accent '#FBBF24'
    $p4 = New-Object System.Windows.Controls.TextBlock
    $p4.TextWrapping = 'Wrap'; $p4.FontSize = 12.5; $p4.Foreground = Brush '#9AA4B5'
    $p4.Text = "Advanced tweaks are off by default for a reason - only enable what you understand. This app is additive for security: it never disables Defender, the firewall or Windows Update. Logs are written to the logs folder next to the app."
    [void]$c4.Body.Children.Add($p4)
    [void]$script:AboutStack.Children.Add($c4.Border)

    $c5 = New-Card -Title 'SUPPORT THE PROJECT' -Accent '#F472B6'
    $p5 = New-Object System.Windows.Controls.TextBlock
    $p5.TextWrapping = 'Wrap'; $p5.FontSize = 12.5; $p5.Foreground = Brush '#9AA4B5'
    $p5.Text = "Scottimizer is free, open source (MIT) and has no ads, telemetry or paid tiers. If it saved you time, latency or a headache, you can support development - every contribution goes straight back into test hardware and more tweaks.`r`n`r`nCan't chip in right now? Starring the repo and telling a friend helps just as much."
    [void]$c5.Body.Children.Add($p5)

    $links = New-Object System.Windows.Controls.WrapPanel
    $links.Margin = New-Object System.Windows.Thickness(0,14,0,0)
    function AddSupportLink([string]$text, [string]$hint, $action) {
        $b = New-ToolButton -Text $text -Hint $hint
        $b.Add_Click($action)
        [void]$links.Children.Add($b)
    }
    AddSupportLink 'Donate via Cash App' 'Open Cash App in your browser'  { try { Start-Process 'https://cash.app/$ScottyRockIt27' } catch {} }
    AddSupportLink 'Sponsor on GitHub'   'Open the GitHub Sponsors page'  { try { Start-Process 'https://github.com/sponsors/SCOTTYinCntrl' } catch {} }
    AddSupportLink 'Star the repo'       'Open the GitHub repository'    { try { Start-Process 'https://github.com/SCOTTYinCntrl/Scottimizer' } catch {} }
    [void]$c5.Body.Children.Add($links)
    [void]$script:AboutStack.Children.Add($c5.Border)
}

# ---------------------------------------------------------------------
#  Apply / undo flows
# ---------------------------------------------------------------------
function Begin-StateSession {
    $existing = Read-ChangeState
    $script:State = New-StateObject
    if ($existing) {
        $script:State.PowerPlanPrev = $existing.PowerPlanPrev
        foreach ($r in @($existing.Reg)) { [void]$script:State.Reg.Add($r) }
        foreach ($d in @($existing.Dns)) { [void]$script:State.Dns.Add($d) }
        foreach ($a in @($existing.AppliedTweaks)) { [void]$script:State.AppliedTweaks.Add($a) }
    } else {
        $script:State.PowerPlanPrev = Get-ActivePowerPlanGuid
        Save-DnsSnapshot
    }
}

function Invoke-Apply {
    $sel = @($script:Tweaks | Where-Object { $_.Check.IsChecked })
    if ($sel.Count -eq 0) {
        [void][System.Windows.MessageBox]::Show('Switch on at least one tweak first.', 'Scottimizer')
        return
    }
    $risky = @($sel | Where-Object { $_.Risk -eq 'Advanced' })
    if ($risky.Count -gt 0) {
        $msg = "You selected $($risky.Count) advanced tweak(s):`r`n`r`n" + (($risky | ForEach-Object { ' - ' + $_.Name }) -join "`r`n") + "`r`n`r`nApply anyway?"
        $ans = [System.Windows.MessageBox]::Show($msg, 'Scottimizer', 'YesNo', 'Warning')
        if ($ans -ne 'Yes') { return }
    }

    Set-Busy $true
    Set-Progress 0
    $bench   = ($script:BenchChk -and ($script:BenchChk.IsChecked -eq $true))
    $bTarget = $script:Settings.BenchTarget
    $bCount  = [int]$script:Settings.BenchCount
    if ($bCount -lt 1) { $bCount = 5 }
    Write-Log ('Applying {0} tweak(s)...' -f $sel.Count) 'accent'
    if ($bench) { Write-Log ("Benchmarking ping before/after every tweak -> {0} ({1} samples)." -f $bTarget, $bCount) 'accent' }
    $benchAdded = 0
    try {
        if ($script:RestoreChk.IsChecked) { CreateRestorePoint-UI }
        Begin-StateSession

        $i = 0; $needReboot = $false; $failed = 0
        foreach ($t in $sel) {
            $before = $null
            if ($bench) {
                Set-Status ("Measuring before: {0}" -f $t.Name) 'info'
                $before = Invoke-QuickPing $bTarget $bCount
            }
            try {
                & $t.Apply
                [void]$script:State.AppliedTweaks.Add($t.Id)
                Write-Log ('OK     ' + $t.Name) 'ok'
                if ($t.Reboot) { $needReboot = $true }
            } catch {
                $failed++
                Write-Log ('FAIL   ' + $t.Name + ' : ' + $_.Exception.Message) 'err'
            }
            if ($bench) {
                Start-Sleep -Milliseconds 150
                $after = Invoke-QuickPing $bTarget $bCount
                $rec = Add-BenchmarkRecord -Name $t.Name -Id $t.Id -Target $bTarget -Before $before -After $after
                $benchAdded++
                if ($null -ne $rec.Delta) {
                    $lvl = if ($rec.Delta -lt -0.05) { 'ok' } elseif ($rec.Delta -gt 0.05) { 'warn' } else { 'info' }
                    Write-Log ("BENCH  {0}: {1} -> {2} ms ({3:N1})" -f $t.Name, $rec.Before, $rec.After, $rec.Delta) $lvl
                } else {
                    Write-Log ("BENCH  {0}: incomplete (no replies)" -f $t.Name) 'warn'
                }
            }
            $i++
            Set-Progress ([math]::Round(100 * $i / $sel.Count))
        }
        Save-ChangeState
        Set-Progress 100
        if ($benchAdded -gt 0 -and $script:ActivePage.Id -eq 'Benchmarks') { Build-Benchmarks }
        $msg = if ($needReboot) { 'Done. Restart your PC so every change takes effect.' }
               elseif ($failed -gt 0) { "Done with $failed failure(s). See the log." }
               else { 'Done. Everything applied.' }
        Write-Log $msg $(if ($failed -gt 0) { 'warn' } else { 'ok' })
        Set-Status $msg $(if ($failed -gt 0) { 'warn' } else { 'ok' })
    } finally {
        Set-Busy $false
        if ($script:ActiveGroup) { Update-ActiveBadges $script:ActiveGroup }
    }
}

function Invoke-Undo {
    $state = Read-ChangeState
    if (-not $state) {
        $ans = [System.Windows.MessageBox]::Show('No snapshot found. Reset the tweaks to Windows defaults instead?', 'Scottimizer', 'YesNo', 'Question')
        if ($ans -ne 'Yes') { return }
        Reset-SelectedToDefaults
        return
    }
    $applied = @($state.AppliedTweaks).Count
    $ans = [System.Windows.MessageBox]::Show(
        "Restore the exact settings from before Scottimizer changed them?`r`n`r`nYes = undo snapshot ($applied tweak(s) recorded)`r`nNo = reset to Windows defaults`r`nCancel = do nothing",
        'Undo changes', 'YesNoCancel', 'Question')
    if ($ans -eq 'Cancel') { return }
    if ($ans -eq 'Yes') {
        Set-Busy $true; Set-Progress 0; Set-Status 'Restoring snapshot...'
        try {
            Restore-ChangeState $state
            Set-Progress 100
            Write-Log 'Restored the previous settings from the snapshot.' 'ok'
            Set-Status 'Undo complete. Reboot if you changed driver or power settings.' 'ok'
        } catch {
            Write-Log ("Undo failed: {0}" -f $_.Exception.Message) 'err'
        } finally { Set-Busy $false; if ($script:ActiveGroup) { Update-ActiveBadges $script:ActiveGroup } }
    } else {
        Reset-SelectedToDefaults
    }
}

function Reset-SelectedToDefaults {
    $list = @($script:Tweaks | Where-Object { $_.Check.IsChecked -and $_.Revert })
    if ($list.Count -eq 0) { $list = @($script:Tweaks | Where-Object { $_.Revert }) }
    Set-Busy $true; Set-Progress 0
    Write-Log 'Resetting tweaks to Windows defaults...' 'accent'
    try {
        $i = 0
        foreach ($t in $list) {
            try { & $t.Revert; Write-Log ('Reverted  ' + $t.Name) 'ok' }
            catch { Write-Log ('FAIL   ' + $t.Name + ' : ' + $_.Exception.Message) 'err' }
            $i++; Set-Progress ([math]::Round(100 * $i / $list.Count))
        }
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        Write-Log 'Reset complete. Restart your PC to finish.' 'ok'
        Set-Status 'Reset to defaults complete.' 'ok'
    } finally { Set-Busy $false; if ($script:ActiveGroup) { Update-ActiveBadges $script:ActiveGroup } }
}
