# =====================================================================
#  Scottimizer 2  -  Core
#  Registry snapshot engine, service/power/DNS helpers, system tools.
#  Dot-sourced by Scottimizer.ps1. Do not run this file on its own.
# =====================================================================

# ---------------------------------------------------------------------
#  Small UI helpers
# ---------------------------------------------------------------------
function Brush([string]$hex) {
    (New-Object System.Windows.Media.BrushConverter).ConvertFromString($hex)
}

function Pump {
    if ($script:Win) {
        try { $script:Win.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background) } catch {}
    }
}

function Write-Log {
    param([string]$Message, [ValidateSet('info','ok','warn','err','accent')][string]$Level = 'info')
    $stamp = Get-Date -Format 'HH:mm:ss'
    $plain = "[$stamp] $Message"
    try { Add-Content -LiteralPath $script:LogFile -Value $plain -Encoding UTF8 -ErrorAction SilentlyContinue } catch {}
    if (-not $script:LogBox) { return }
    $color = switch ($Level) {
        'ok'     { '#34D399' }
        'warn'   { '#FBBF24' }
        'err'    { '#F87171' }
        'accent' { '#22D3EE' }
        default  { '#9AA4B5' }
    }
    try {
        $para = New-Object System.Windows.Documents.Paragraph
        $para.Margin = New-Object System.Windows.Thickness(0)
        $ts  = New-Object System.Windows.Documents.Run ("[$stamp] ")
        $ts.Foreground = Brush '#4E5A6E'
        $msg = New-Object System.Windows.Documents.Run ($Message)
        $msg.Foreground = Brush $color
        [void]$para.Inlines.Add($ts)
        [void]$para.Inlines.Add($msg)
        [void]$script:LogBox.Document.Blocks.Add($para)
        while ($script:LogBox.Document.Blocks.Count -gt 500) {
            $script:LogBox.Document.Blocks.Remove($script:LogBox.Document.Blocks.FirstBlock)
        }
        $script:LogBox.ScrollToEnd()
    } catch {}
    Pump
}

function Set-Status {
    param([string]$Text, [string]$Level = 'info')
    if (-not $script:StatusText) { return }
    $color = switch ($Level) { 'ok' { '#34D399' } 'warn' { '#FBBF24' } 'err' { '#F87171' } default { '#8B95A7' } }
    $script:StatusText.Text = $Text
    $script:StatusText.Foreground = Brush $color
}

function Set-Progress {
    param([int]$Value)
    if ($script:Prog) { $script:Prog.Value = [math]::Max(0, [math]::Min(100, $Value)) }
    Pump
}

# ---------------------------------------------------------------------
#  Registry snapshot engine  (records the exact prior state for undo)
# ---------------------------------------------------------------------
function Ensure-RegKey([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force | Out-Null }
}

function Save-RegSnapshot {
    param([string]$Path, [string]$Name)
    $exists = $false; $value = $null; $kind = 'String'
    try {
        $key = Get-Item -LiteralPath $Path -ErrorAction Stop
        if ($key.GetValueNames() -contains $Name) {
            $exists = $true
            $kind   = $key.GetValueKind($Name).ToString()
            # Read REG_EXPAND_SZ literally (do not expand %vars%) so we can restore the template.
            $value  = $key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        }
    } catch {}
    [void]$script:State.Reg.Add([pscustomobject]@{
        Path = $Path; Name = $Name; Existed = $exists; Value = $value; Kind = $kind
    })
}

function Set-Reg {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        $Value,
        [ValidateSet('DWord','QWord','String','ExpandString','MultiString','Binary')][string]$Type = 'DWord',
        [switch]$NoSnapshot
    )
    if (-not $NoSnapshot) { Save-RegSnapshot -Path $Path -Name $Name }
    Ensure-RegKey $Path
    switch ($Type) {
        'MultiString'  { New-ItemProperty -LiteralPath $Path -Name $Name -Value ([string[]]$Value) -PropertyType MultiString  -Force | Out-Null }
        'Binary'       { New-ItemProperty -LiteralPath $Path -Name $Name -Value ([byte[]]$Value)     -PropertyType Binary       -Force | Out-Null }
        'QWord'        { New-ItemProperty -LiteralPath $Path -Name $Name -Value ([int64]$Value)     -PropertyType QWord        -Force | Out-Null }
        'String'       { New-ItemProperty -LiteralPath $Path -Name $Name -Value ([string]$Value)    -PropertyType String       -Force | Out-Null }
        'ExpandString' { New-ItemProperty -LiteralPath $Path -Name $Name -Value ([string]$Value)    -PropertyType ExpandString -Force | Out-Null }
        default        { New-ItemProperty -LiteralPath $Path -Name $Name -Value ([int]$Value)       -PropertyType DWord        -Force | Out-Null }
    }
}

function Remove-Reg {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Name, [switch]$NoSnapshot)
    if (-not $NoSnapshot) { Save-RegSnapshot -Path $Path -Name $Name }
    if (Test-Path -LiteralPath $Path) {
        Remove-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction SilentlyContinue
    }
}

function Get-RegValue {
    param([string]$Path, [string]$Name, $Default = $null)
    try {
        $key = Get-Item -LiteralPath $Path -ErrorAction Stop
        if ($key.GetValueNames() -contains $Name) { return $key.GetValue($Name, $Default) }
    } catch {}
    return $Default
}

function Test-RegValue {
    param([string]$Path, [string]$Name, $Expected)
    $v = Get-RegValue -Path $Path -Name $Name -Default '__missing__'
    return ($v -ne '__missing__' -and "$v" -eq "$Expected")
}

# ---------------------------------------------------------------------
#  Service helpers (recorded through the reg snapshot via Start value)
# ---------------------------------------------------------------------
function Set-ServiceStart {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('Automatic','Manual','Disabled','AutomaticDelayed')][string]$StartupType,
        [switch]$NoSnapshot
    )
    $path = "HKLM:\SYSTEM\CurrentControlSet\Services\$Name"
    if (-not (Test-Path -LiteralPath $path)) { return $false }
    $val = switch ($StartupType) { 'Automatic' { 2 } 'AutomaticDelayed' { 2 } 'Manual' { 3 } 'Disabled' { 4 } }
    Set-Reg -Path $path -Name 'Start' -Value $val -Type DWord -NoSnapshot:$NoSnapshot
    if ($StartupType -eq 'AutomaticDelayed') {
        Set-Reg -Path $path -Name 'DelayedAutostart' -Value 1 -Type DWord -NoSnapshot:$NoSnapshot
    }
    return $true
}

function Stop-Svc([string]$Name) {
    try { Stop-Service -Name $Name -Force -ErrorAction Stop } catch {}
}

# ---------------------------------------------------------------------
#  Power plan helpers
# ---------------------------------------------------------------------
function Get-ActivePowerPlanGuid {
    try {
        $out = (powercfg /getactivescheme 2>$null | Out-String)
        if ($out -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') { return $Matches[1] }
    } catch {}
    return $null
}

function Ensure-UltimatePowerPlan {
    $plans = (powercfg /list 2>$null | Out-String)
    if ($plans -match '([0-9a-fA-F-]{36})\s+\(Ultimate Performance\)') { return $Matches[1] }
    $o = (powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1 | Out-String)
    if ($o -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') { return $Matches[1] }
    return '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'   # High performance fallback
}

# ---------------------------------------------------------------------
#  DNS snapshot / restore
# ---------------------------------------------------------------------
function Save-DnsSnapshot {
    foreach ($a in @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue)) {
        try {
            $srv = @((Get-DnsClientServerAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses)
            [void]$script:State.Dns.Add([pscustomobject]@{ ifIndex = $a.ifIndex; Servers = $srv })
        } catch {}
    }
}

# ---------------------------------------------------------------------
#  State file (undo data)
# ---------------------------------------------------------------------
function Save-ChangeState {
    $obj = [pscustomobject]@{
        Version       = $script:Version
        AppliedAt     = (Get-Date).ToString('o')
        PowerPlanPrev = $script:State.PowerPlanPrev
        AppliedTweaks = @($script:State.AppliedTweaks)
        Reg           = @($script:State.Reg)
        Dns           = @($script:State.Dns)
    }
    New-Item -ItemType Directory -Path (Split-Path $script:StateFile) -Force -ErrorAction SilentlyContinue | Out-Null
    $obj | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $script:StateFile -Encoding UTF8
}

function Read-ChangeState {
    if (-not (Test-Path -LiteralPath $script:StateFile)) { return $null }
    try { return (Get-Content -LiteralPath $script:StateFile -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return $null }
}

function Restore-ChangeState {
    param($State)
    if (-not $State) { return }
    $regs = @($State.Reg)
    for ($i = $regs.Count - 1; $i -ge 0; $i--) {
        $e = $regs[$i]
        try {
            if ($e.Existed) {
                # Recreate the key if a tweak removed it, then write the original value/type.
                if (-not (Test-Path -LiteralPath $e.Path)) { New-Item -Path $e.Path -Force | Out-Null }
                switch ("$($e.Kind)") {
                    'MultiString'  { New-ItemProperty -LiteralPath $e.Path -Name $e.Name -Value ([string[]](@($e.Value))) -PropertyType MultiString  -Force | Out-Null }
                    'Binary'       { New-ItemProperty -LiteralPath $e.Path -Name $e.Name -Value ([byte[]](  @($e.Value))) -PropertyType Binary       -Force | Out-Null }
                    'QWord'        { New-ItemProperty -LiteralPath $e.Path -Name $e.Name -Value ([int64]$e.Value)               -PropertyType QWord        -Force | Out-Null }
                    'ExpandString' { New-ItemProperty -LiteralPath $e.Path -Name $e.Name -Value ([string]$e.Value)              -PropertyType ExpandString -Force | Out-Null }
                    'String'       { New-ItemProperty -LiteralPath $e.Path -Name $e.Name -Value ([string]$e.Value)              -PropertyType String       -Force | Out-Null }
                    default        { New-ItemProperty -LiteralPath $e.Path -Name $e.Name -Value ([int]$e.Value)                 -PropertyType DWord        -Force | Out-Null }
                }
            } else {
                if (Test-Path -LiteralPath $e.Path) {
                    Remove-ItemProperty -LiteralPath $e.Path -Name $e.Name -ErrorAction SilentlyContinue
                }
            }
        } catch {
            Write-Log ("Undo failed for {0}\{1}: {2}" -f $e.Path, $e.Name, $_.Exception.Message) 'warn'
        }
    }
    foreach ($d in @($State.Dns)) {
        try {
            $servers = @($d.Servers)
            if ($servers.Count -gt 0) { Set-DnsClientServerAddress -InterfaceIndex $d.ifIndex -ServerAddresses $servers -ErrorAction Stop }
            else { Set-DnsClientServerAddress -InterfaceIndex $d.ifIndex -ResetServerAddresses -ErrorAction Stop }
        } catch {}
    }
    if ($State.PowerPlanPrev) { powercfg /setactive $State.PowerPlanPrev | Out-Null }
    Clear-DnsClientCache -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------
#  Restore point
# ---------------------------------------------------------------------
function New-ScottimizerRestorePoint([string]$Desc = 'Scottimizer - before changes') {
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        # Allow more than one restore point per 24h for our purposes.
        try {
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' `
                             -Name 'SystemRestorePointCreationFrequency' -Value 0 -Type DWord -ErrorAction SilentlyContinue
        } catch {}
        Checkpoint-Computer -Description $Desc -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# ---------------------------------------------------------------------
#  System information
# ---------------------------------------------------------------------
function Get-SystemInfo {
    $info = [ordered]@{
        Cpu = 'Unknown'; Gpu = 'Unknown'; RamGB = 0; Os = 'Unknown'
        Mobo = ''; Disks = @(); Uptime = ''
    }
    try { $info.Cpu   = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name.Trim() } catch {}
    try {
        $g = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notmatch 'Basic|Remote|Virtual|Meta' } | Select-Object -First 1
        if ($g) { $info.Gpu = $g.Name.Trim() }
    } catch {}
    try { $info.RamGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1) } catch {}
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $info.Os = ("{0} (build {1})" -f $os.Caption.Trim(), $os.BuildNumber)
        $up = (Get-Date) - $os.LastBootUpTime
        $info.Uptime = ('{0}d {1}h {2}m' -f $up.Days, $up.Hours, $up.Minutes)
    } catch {}
    try {
        $sys = Get-CimInstance Win32_ComputerSystem
        if ($sys.Manufacturer -and $sys.Model) { $info.Mobo = ("{0} {1}" -f $sys.Manufacturer, $sys.Model).Trim() }
    } catch {}
    try {
        $info.Disks = @(Get-CimInstance Win32_DiskDrive | Where-Object { $_.MediaType -like '*Fixed*' -or $_.Size -gt 0 } |
            ForEach-Object { [pscustomobject]@{ Model = $_.Model; GB = [math]::Round($_.Size / 1GB); Type = $_.MediaType } })
    } catch {}
    return [pscustomobject]$info
}

# ---------------------------------------------------------------------
#  Ping / latency test
# ---------------------------------------------------------------------
function Invoke-PingTest {
    param([string]$Target, [int]$Count = 8)
    if (-not $Target) { $Target = '1.1.1.1' }
    $png   = New-Object System.Net.NetworkInformation.Ping
    $times = New-Object System.Collections.Generic.List[double]
    $lost  = 0
    for ($i = 1; $i -le $Count; $i++) {
        try {
            $r = $png.Send($Target, 1500)
            if ($r.Status -eq 'Success') { [void]$times.Add([double]$r.RoundtripTime) } else { $lost++ }
        } catch { $lost++ }
        Set-Status ("Testing $Target ... $i / $Count") 'info'
        Pump
        Start-Sleep -Milliseconds 200
    }
    $png.Dispose()
    if ($times.Count -eq 0) { return $null }
    $arr  = @($times)
    $avg  = ($arr | Measure-Object -Average).Average
    $min  = ($arr | Measure-Object -Minimum).Minimum
    $max  = ($arr | Measure-Object -Maximum).Maximum
    $jit  = 0
    if ($arr.Count -gt 1) {
        $d = 0
        for ($i = 1; $i -lt $arr.Count; $i++) { $d += [math]::Abs($arr[$i] - $arr[$i - 1]) }
        $jit = $d / ($arr.Count - 1)
    }
    return [pscustomobject]@{
        Target = $Target
        Avg    = [math]::Round($avg, 1)
        Min    = [math]::Round($min, 1)
        Max    = [math]::Round($max, 1)
        Jitter = [math]::Round($jit, 1)
        Loss   = [math]::Round(100 * $lost / $Count)
        Samples = $arr
    }
}
