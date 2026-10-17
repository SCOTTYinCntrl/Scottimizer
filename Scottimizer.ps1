# =====================================================================
#  Scottimizer 2  -  Advanced Windows gaming / privacy / security tuner
#  Entry point.  Windows 10/11, Windows PowerShell 5.1+, Administrator.
#
#  Modules (src\):
#    Core.ps1        snapshot engine, helpers, system info, ping
#    Tools.ps1       cleanup, memory, network-reset tools
#    Tweaks.ps1      the tweak catalog
#    Audit.ps1       security audit checks
#    Ui.ps1          XAML theme + UI builders
#    Personalize.ps1 settings, custom background + accent, Appearance page
#    Benchmark.ps1   per-tweak latency benchmarking + page
#    Actions.ps1     page building + apply/undo flows
# =====================================================================

# ---------- Elevate + STA (WPF needs STA) ----------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$isSta   = ([Threading.Thread]::CurrentThread.GetApartmentState() -eq 'STA')

if ($PSCommandPath -and $PSCommandPath.EndsWith('.ps1') -and $env:SCOTTIMIZER_SELFTEST -ne '1') {
    $relaunch = '-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "{0}"' -f $PSCommandPath
    if (-not $isAdmin) { Start-Process powershell.exe -ArgumentList $relaunch -Verb RunAs; exit }
    if (-not $isSta)   { Start-Process powershell.exe -ArgumentList $relaunch; exit }
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# ---------- Paths / state ----------
$script:AppName = 'Scottimizer'
$script:Version = '2.1.2'
$script:AppRoot = $PSScriptRoot
if (-not $script:AppRoot) { $script:AppRoot = (Get-Location).Path }

# The app folder can sit somewhere Windows protects (e.g. Documents / OneDrive),
# where Defender Controlled Folder Access blocks unsigned apps from writing.
# Probe the app folder once and fall back to %LOCALAPPDATA% so logging and the
# undo snapshot keep working instead of crashing at the end of Apply.
function Test-FolderWritable([string]$Path) {
    try {
        New-Item -ItemType Directory -Path $Path -Force -ErrorAction Stop | Out-Null
        $probe = Join-Path $Path ('.wtest-{0}' -f [guid]::NewGuid().ToString('N'))
        Set-Content -LiteralPath $probe -Value 'ok' -Encoding ASCII -ErrorAction Stop
        Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
        return $true
    } catch { return $false }
}

$script:DataRoot     = $script:AppRoot
$script:DataFallback = $false
if (-not (Test-FolderWritable (Join-Path $script:AppRoot 'logs'))) {
    $alt = Join-Path $env:LOCALAPPDATA 'Scottimizer'
    if (Test-FolderWritable (Join-Path $alt 'logs')) { $script:DataRoot = $alt; $script:DataFallback = $true }
}

$script:LogDir   = Join-Path $script:DataRoot 'logs'
$script:StateDir = Join-Path $script:DataRoot 'state'
$script:StateFile= Join-Path $script:StateDir 'last-apply.json'
New-Item -ItemType Directory -Path $script:LogDir, $script:StateDir -Force -ErrorAction SilentlyContinue | Out-Null
$script:LogFile = Join-Path $script:LogDir ('scottimizer-{0}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

function New-StateObject {
    [pscustomobject]@{
        PowerPlanPrev = $null
        Reg           = New-Object System.Collections.ArrayList
        Dns           = New-Object System.Collections.ArrayList
        AppliedTweaks = New-Object System.Collections.ArrayList
    }
}
$script:State = New-StateObject

# ---------- Load modules ----------
. (Join-Path $script:AppRoot 'src\Core.ps1')
. (Join-Path $script:AppRoot 'src\Tools.ps1')
. (Join-Path $script:AppRoot 'src\Tweaks.ps1')
. (Join-Path $script:AppRoot 'src\Audit.ps1')
. (Join-Path $script:AppRoot 'src\Ui.ps1')
. (Join-Path $script:AppRoot 'src\Personalize.ps1')
. (Join-Path $script:AppRoot 'src\Benchmark.ps1')
. (Join-Path $script:AppRoot 'src\Actions.ps1')

# ---------- User settings + benchmark history ----------
Load-Settings
Load-Benchmarks

# ---------- Load window ----------
[xml]$xaml = $script:XamlText
$script:Win = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))

# ---------- Window icon (title bar + taskbar) ----------
$iconPath = Join-Path $script:AppRoot 'appicon.ico'
if (Test-Path -LiteralPath $iconPath) {
    try {
        $dec = New-Object System.Windows.Media.Imaging.IconBitmapDecoder(
            (New-Object System.Uri($iconPath)),
            [System.Windows.Media.Imaging.BitmapCreateOptions]::None,
            [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
        $frame = $dec.Frames | Sort-Object PixelWidth -Descending | Select-Object -First 1
        if ($frame) { $script:Win.Icon = $frame }
    } catch {}
}

foreach ($n in 'RootBorder','TitleBar','DragArea','MinBtn','CloseBtn','NavStack','AdminText','ScoreMini',
               'PageTitle','PageSub','SearchBox','SearchHint','ToolbarPanel','ToolbarRight','ProfileStack',
               'AllBtn','NoneBtn',
               'BgHost','ScrimHost','LogoBorder',
               'TweakHost','TweakStack','SpecialHost','DashScroll','DashStack',
               'BenchScroll','BenchStack','AppearScroll','AppearStack',
               'AuditScroll','AuditStack',
               'AboutScroll','AboutStack','LogBox','RestoreChk','BenchChk','StatusText','Prog','UndoBtn','ApplyBtn') {
    Set-Variable -Scope Script -Name $n -Value $script:Win.FindName($n)
}

# ---------- Page + profile definitions ----------
$script:Pages = @(
    [pscustomobject]@{ Id='Dashboard'; Title='Dashboard'; Sub='System overview, security score and quick tools'; Kind='special'; Target='DashScroll';  Glyph=0xE80F }
    [pscustomobject]@{ Id='Gaming';    Title='Gaming & Performance'; Sub='Free up CPU, GPU and scheduler time for your game'; Kind='group'; Group='Gaming'; Glyph=0xE7FC }
    [pscustomobject]@{ Id='Network';   Title='Network & Latency'; Sub='Lower ping, steadier packets, fewer hitches'; Kind='group'; Group='Network'; Glyph=0xE968 }
    [pscustomobject]@{ Id='Security';  Title='Security Hardening'; Sub='Shrink the attack surface and protect credentials'; Kind='group'; Group='Security'; Glyph=0xE72E }
    [pscustomobject]@{ Id='Privacy';   Title='Privacy'; Sub='Cut telemetry, tracking and unwanted content'; Kind='group'; Group='Privacy'; Glyph=0xE890 }
    [pscustomobject]@{ Id='Debloat';   Title='Debloat'; Sub='Remove pre-installed apps and clutter'; Kind='group'; Group='Debloat'; Glyph=0xE74D }
    [pscustomobject]@{ Id='System';    Title='System & Storage'; Sub='Boot, filesystem and drive tuning'; Kind='group'; Group='System'; Glyph=0xE713 }
    [pscustomobject]@{ Id='Benchmarks'; Title='Latency Benchmarks'; Sub='Per-tweak before/after ping and jitter results'; Kind='special'; Target='BenchScroll'; Glyph=0xE916 }
    [pscustomobject]@{ Id='Appearance'; Title='Appearance'; Sub='Customise the background, colours and accent'; Kind='special'; Target='AppearScroll'; Glyph=0xE790 }
    [pscustomobject]@{ Id='Audit';     Title='Security Audit'; Sub='Scan this PC and fix weak settings with one click'; Kind='special'; Target='AuditScroll'; Glyph=0xE9D9 }
    [pscustomobject]@{ Id='About';     Title='About'; Sub='Profiles, risk levels and how undo works'; Kind='special'; Target='AboutScroll'; Glyph=0xE946 }
)

$script:Profiles = @(
    [pscustomobject]@{ Name='Recommended';    Hint='Balanced, safe defaults';         Select={ param($t) $t.Default } }
    [pscustomobject]@{ Name='Max performance';Hint='Everything for FPS';              Select={ param($t) ($t.Group -in 'Gaming','Network') -and ($t.Risk -in 'Safe','Moderate') } }
    [pscustomobject]@{ Name='Low latency';    Hint='Network and input latency focus'; Select={ param($t) (($t.Tags -contains 'Latency') -or ($t.Group -eq 'Network')) -and ($t.Risk -in 'Safe','Moderate') } }
    [pscustomobject]@{ Name='Hardened';       Hint='Security and privacy hardening'; Select={ param($t) ($t.Group -in 'Security','Privacy') -and ($t.Risk -in 'Safe','Moderate') } }
    [pscustomobject]@{ Name='Private';        Hint='Privacy and debloat';             Select={ param($t) ($t.Group -in 'Privacy','Debloat') -and ($t.Risk -in 'Safe','Moderate') } }
    [pscustomobject]@{ Name='Everything';     Hint='All safe + moderate tweaks';     Select={ param($t) $t.Risk -in 'Safe','Moderate' } }
)

$script:ActivePage  = $script:Pages[0]
$script:ActiveGroup = $null

# ---------- Build navigation, profiles, tweak rows ----------
foreach ($p in $script:Pages) { [void](New-NavButton $p) }

$script:ProfileChips = @()
foreach ($p in $script:Profiles) {
    $chip = New-Object System.Windows.Controls.Primitives.ToggleButton
    $chip.Style = $script:Win.FindResource('Chip')
    $chip.Content = $p.Name
    $chip.Tag = $p
    $chip.ToolTip = $p.Hint
    $chip.Add_Click({
        param($s, $e)
        if (-not $s.IsChecked) { $s.IsChecked = $true; return }
        foreach ($c in $script:ProfileChips) { if ($c -ne $s) { $c.IsChecked = $false } }
        Apply-Profile $s.Tag
    })
    $script:ProfileChips += $chip
    [void]$script:ProfileStack.Children.Add($chip)
}

foreach ($t in $script:Tweaks) { [void](New-TweakRow $t) }

# ---------- Runtime state ----------
$script:ScoreSummary  = ''
$script:GradeText     = ''
$script:AuditDone     = $false
$script:SuppressSearch= $false

# =====================================================================
#  Events
# =====================================================================
$script:TitleBar.Add_MouseLeftButtonDown({ $script:Win.DragMove() })
$script:MinBtn.Add_Click({ $script:Win.WindowState = 'Minimized' })
$script:CloseBtn.Add_Click({ $script:Win.Close() })

$script:AllBtn.Add_Click({  foreach ($t in $script:Tweaks) { if ($t.Check.Visibility -eq 'Visible') { $t.Check.IsChecked = $true } } })
$script:NoneBtn.Add_Click({ foreach ($t in $script:Tweaks) { if ($t.Check.Visibility -eq 'Visible') { $t.Check.IsChecked = $false } } })

$script:ApplyBtn.Add_Click({ Invoke-Apply })
$script:UndoBtn.Add_Click({ Invoke-Undo })

if ($script:BenchChk) {
    $script:BenchChk.Add_Click({
        $script:Settings.BenchEnabled = ($script:BenchChk.IsChecked -eq $true)
        Save-Settings
    })
}

# Drop a picture anywhere on the window to use it as the background.
if ($script:RootBorder) {
    $script:RootBorder.AllowDrop = $true
    $script:RootBorder.Add_DragOver({
        param($s, $e)
        if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) { $e.Effects = [System.Windows.DragDropEffects]::Copy }
        else { $e.Effects = [System.Windows.DragDropEffects]::None }
        $e.Handled = $true
    })
    $script:RootBorder.Add_Drop({
        param($s, $e)
        try {
            $files = @($e.Data.GetData([System.Windows.DataFormats]::FileDrop))
            $img = @($files | Where-Object { $_ -match '\.(jpe?g|png|bmp|gif|webp)$' })[0]
            if ($img) {
                $script:Settings.BgType  = 'image'
                $script:Settings.BgImage = $img
                Apply-Settings; Save-Settings; Build-Appearance
                Write-Log ("Background photo set: {0}" -f $img) 'accent'
            }
        } catch {}
        $e.Handled = $true
    })
}

$script:SearchBox.Add_TextChanged({
    if ($script:SuppressSearch) { return }
    $q = $script:SearchBox.Text
    $script:SearchHint.Visibility = if ($q) { 'Collapsed' } else { 'Visible' }
    if ($q.Trim()) {
        $script:TweakHost.Visibility = 'Visible'
        $script:SpecialHost.Visibility = 'Collapsed'
        $script:ToolbarPanel.Visibility = 'Collapsed'
        $script:ToolbarRight.Visibility = 'Collapsed'
        foreach ($t in $script:Tweaks) {
            $hay = ("{0} {1} {2} {3}" -f $t.Name, $t.Desc, (($t.Tags) -join ' '), $t.Group)
            $t.Check.Visibility = if ($hay -like "*$q*") { 'Visible' } else { 'Collapsed' }
        }
        $script:PageTitle.Text = 'Search'
        $script:PageSub.Text = ("Results for `"{0}`"" -f $q)
    } else {
        Show-Page $script:ActivePage
    }
})
$script:SearchBox.Add_GotFocus({ $script:SearchHint.Visibility = 'Collapsed' })
$script:SearchBox.Add_LostFocus({ if (-not $script:SearchBox.Text) { $script:SearchHint.Visibility = 'Visible' } })

$script:Win.Add_Loaded({
    Write-Log ("Scottimizer {0} ready." -f $script:Version) 'accent'
    if ($script:DataFallback) { Write-Log ("App folder is not writable - using {0} for logs and undo data." -f $script:DataRoot) 'warn' }
    if ($isAdmin) { $script:AdminText.Text = 'Administrator: elevated'; $script:AdminText.Foreground = Brush '#34D399'; Set-Status 'Ready. Pick tweaks or a profile, then Apply selected.' 'info' }
    else { $script:AdminText.Text = 'Not elevated - some tweaks need admin.'; $script:AdminText.Foreground = Brush '#F87171'; Set-Status 'Running without elevation - some tweaks will fail.' 'warn' }

    if (Test-Path -LiteralPath $script:StateFile) { Write-Log 'Snapshot found - "Undo changes" can restore your previous settings.' 'warn' }

    foreach ($c in $script:ProfileChips) { if ($c.Tag.Name -eq 'Recommended') { $c.IsChecked = $true } }

    # apply the saved look (background + accent)
    Apply-Settings
    if ($script:BenchChk) { $script:BenchChk.IsChecked = [bool]$script:Settings.BenchEnabled }

    Build-Dashboard
    Build-Benchmarks
    Build-Appearance
    Build-About
    Navigate-To 'Dashboard'

    # ---- optional self-test (used by the build/test harness) ----
    if ($env:SCOTTIMIZER_SELFTEST -eq '1') {
        try {
            foreach ($p in $script:Pages) { Navigate-To $p.Id; Pump }
            Apply-Profile $script:Profiles[0]
            $items = Invoke-SecurityAudit
            $line = "SELFTEST OK - tweaks={0} auditItems={1} score={2}" -f $script:Tweaks.Count, @($items).Count, (Get-AuditScore $items)
            Add-Content -LiteralPath (Join-Path $script:AppRoot 'selftest.txt') -Value $line -Encoding UTF8
            Write-Log $line 'ok'
        } catch {
            Add-Content -LiteralPath (Join-Path $script:AppRoot 'selftest.txt') -Value ("SELFTEST FAIL - " + $_.Exception.ToString()) -Encoding UTF8
        }
        $script:SelfTestTimer = New-Object System.Windows.Threading.DispatcherTimer
        $script:SelfTestTimer.Interval = [TimeSpan]::FromMilliseconds(600)
        $script:SelfTestTimer.Add_Tick({
            $script:SelfTestTimer.Stop()
            function Save-Shot([string]$file) {
                try {
                    $script:Win.UpdateLayout()
                    $w = [int]$script:Win.ActualWidth; $h = [int]$script:Win.ActualHeight
                    if ($w -lt 10) { $w = 1250 }; if ($h -lt 10) { $h = 830 }
                    $bmp = New-Object System.Windows.Media.Imaging.RenderTargetBitmap($w, $h, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
                    $bmp.Render($script:RootBorder)
                    $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
                    $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($bmp))
                    $fs = [System.IO.File]::Create((Join-Path $script:AppRoot $file))
                    $enc.Save($fs); $fs.Close()
                } catch {}
            }
            Navigate-To 'Dashboard'; Pump; Save-Shot 'shot-dashboard.png'
            Navigate-To 'Gaming';    Pump; Save-Shot 'shot-gaming.png'
            Navigate-To 'Security';  Pump; Save-Shot 'shot-security.png'
            Navigate-To 'Appearance'; Pump; Save-Shot 'shot-appearance.png'

            # seed a few sample rows so the Benchmarks page renders with data
            if (@($script:Benchmarks).Count -eq 0) {
                $script:Benchmarks.Clear()
                $seed = @(
                    @{ N='Disable Nagle''s algorithm'; I='tcp-nodelay'; B=18.4; A=11.2; JB=4.1; JA=1.8; D=-7.2 },
                    @{ N='Set DNS to Cloudflare + Google'; I='dns-fast'; B=17.1; A=12.6; JB=3.4; JA=1.9; D=-4.5 },
                    @{ N='Disable network throttling index'; I='net-throttle'; B=14.2; A=13.1; JB=2.2; JA=1.6; D=-1.1 },
                    @{ N='TCP autotuning normal'; I='tcp-autotune'; B=13.0; A=13.4; JB=1.9; JA=2.4; D=0.4 },
                    @{ N='Enable RSS on adapter'; I='net-rss'; B=12.8; A=9.9; JB=2.0; JA=1.2; D=-2.9 }
                )
                foreach ($s in $seed) {
                    [void]$script:Benchmarks.Add([pscustomobject]@{
                        Time=(Get-Date).ToString('s'); Name=$s.N; Id=$s.I; Target='1.1.1.1';
                        Before=$s.B; After=$s.A; JitterBefore=$s.JB; JitterAfter=$s.JA; Loss=0; Delta=$s.D; Manual=$false })
                }
            }
            Navigate-To 'Benchmarks'; Pump; Save-Shot 'shot-benchmarks.png'

            Navigate-To 'Audit';     Pump; Start-Sleep -Milliseconds 300; Pump; Save-Shot 'shot-audit.png'
            $script:Win.Close()
        })
        $script:SelfTestTimer.Start()
    }
})

$script:Win.Add_Closed({ try { Write-Log 'Closed.' } catch {} })

try {
    [void]$script:Win.ShowDialog()
} catch {
    $detail = $_.Exception.ToString()
    if ($_.ScriptStackTrace) { $detail += "`r`n--- Script stack ---`r`n" + $_.ScriptStackTrace }
    if ($_.InvocationInfo) { $detail += "`r`n--- Invocation ---`r`n" + $_.InvocationInfo.PositionMessage }
    $msg = "Scottimizer hit an error:`r`n`r`n$($_.Exception.Message)`r`n`r`nLog: $($script:LogFile)"
    try { Add-Content -LiteralPath $script:LogFile -Value $detail -Encoding UTF8 } catch {}
    [System.Windows.MessageBox]::Show($msg, 'Scottimizer', 'OK', 'Error') | Out-Null
}

