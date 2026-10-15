# =====================================================================
#  Scottimizer 2  -  Tools
#  Maintenance, memory, cleanup and network-reset helpers.
# =====================================================================

# ---------------------------------------------------------------------
#  Native memory helpers (clear standby list / working sets)
# ---------------------------------------------------------------------
if (-not ('MemUtil' -as [type])) {
    $memSrc = @'
using System;
using System.Runtime.InteropServices;
public static class MemUtil
{
    [DllImport("ntdll.dll", SetLastError=true)]
    static extern int NtSetSystemInformation(int InfoClass, IntPtr Info, int Length);
    [DllImport("advapi32.dll", SetLastError=true)]
    static extern bool OpenProcessToken(IntPtr h, uint acc, out IntPtr tok);
    [DllImport("advapi32.dll", SetLastError=true)]
    static extern bool LookupPrivilegeValue(string host, string name, out long luid);
    [DllImport("advapi32.dll", SetLastError=true)]
    static extern bool AdjustTokenPrivileges(IntPtr tok, bool dis, ref TOKEN_PRIVILEGES np, int len, IntPtr prev, IntPtr ret);
    [DllImport("kernel32.dll")]
    static extern IntPtr GetCurrentProcess();

    [StructLayout(LayoutKind.Sequential)]
    struct TOKEN_PRIVILEGES { public int Count; public long Luid; public int Attr; }

    static void EnablePrivilege(string name)
    {
        IntPtr tok; long luid;
        if (!OpenProcessToken(GetCurrentProcess(), 0x20 | 0x8, out tok)) return;
        if (!LookupPrivilegeValue(null, name, out luid)) return;
        TOKEN_PRIVILEGES tp = new TOKEN_PRIVILEGES();
        tp.Count = 1; tp.Luid = luid; tp.Attr = 0x2;
        AdjustTokenPrivileges(tok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
    }

    static int Do(int cmd)
    {
        EnablePrivilege("SeProfileSingleProcessPrivilege");
        IntPtr p = Marshal.AllocHGlobal(4);
        Marshal.WriteInt32(p, cmd);
        int r = NtSetSystemInformation(0x50, p, 4);
        Marshal.FreeHGlobal(p);
        return r;
    }

    public static int PurgeStandbyList()        { return Do(4); }
    public static int PurgeLowPriorityStandby() { return Do(5); }
    public static int EmptyWorkingSets()        { return Do(2); }
    public static int FlushModifiedPageList()   { return Do(3); }
}
'@
    try { Add-Type -TypeDefinition $memSrc -ErrorAction Stop } catch {}
}

function Clear-StandbyList {
    try {
        $r = [MemUtil]::PurgeStandbyList()
        if ($r -eq 0) { return $true }
        Write-Log ("Standby list purge returned 0x{0:X8} (privilege not held)." -f $r) 'warn'
    } catch { Write-Log "Standby list purge failed: $($_.Exception.Message)" 'warn' }
    return $false
}

function Clear-WorkingSets {
    try { return ([MemUtil]::EmptyWorkingSets() -eq 0) } catch { return $false }
}

# ---------------------------------------------------------------------
#  Disk cleanups
# ---------------------------------------------------------------------
function Clear-TempFiles {
    $freed = 0; $count = 0
    $targets = @(
        $env:TEMP,
        "$env:WINDIR\Temp",
        "$env:LOCALAPPDATA\Temp"
    ) | Select-Object -Unique
    foreach ($t in $targets) {
        if (-not (Test-Path -LiteralPath $t)) { continue }
        try {
            $items = Get-ChildItem -LiteralPath $t -Force -ErrorAction SilentlyContinue
            foreach ($it in $items) {
                try {
                    if (-not $it.PSIsContainer) { $freed += $it.Length }
                    Remove-Item -LiteralPath $it.FullName -Recurse -Force -ErrorAction SilentlyContinue
                    $count++
                } catch {}
            }
        } catch {}
    }
    return [pscustomobject]@{ Count = $count; MB = [math]::Round($freed / 1MB, 1) }
}

function Clear-RecycleBinSafe {
    try {
        Clear-RecycleBin -Force -ErrorAction Stop
        return $true
    } catch { return $false }
}

function Clear-WindowsUpdateCache {
    try {
        Stop-Svc 'wuauserv'; Stop-Svc 'bits'; Stop-Svc 'dosvc'
        Start-Sleep -Milliseconds 600
        $paths = @("$env:WINDIR\SoftwareDistribution\Download", "$env:WINDIR\SoftwareDistribution\DataStore")
        foreach ($p in $paths) {
            if (Test-Path -LiteralPath $p) {
                Get-ChildItem -LiteralPath $p -Force -ErrorAction SilentlyContinue |
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
        Start-Service -Name bits -ErrorAction SilentlyContinue
        return $true
    } catch { Write-Log "Update cache cleanup failed: $($_.Exception.Message)" 'warn'; return $false }
}

function Invoke-ComponentCleanup {
    try {
        $p = Start-Process -FilePath 'dism.exe' -ArgumentList '/Online','/Cleanup-Image','/StartComponentCleanup' `
                           -Wait -PassThru -WindowStyle Hidden
        return ($p.ExitCode -eq 0)
    } catch { Write-Log "Component cleanup failed: $($_.Exception.Message)" 'warn'; return $false }
}

function Clear-ThumbnailCache {
    try {
        $p = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
        if (Test-Path -LiteralPath $p) {
            Get-ChildItem -LiteralPath $p -Filter 'thumbcache_*.db' -Force -ErrorAction SilentlyContinue |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }
        Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer" -Filter 'iconcache_*.db' -Force -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
        return $true
    } catch { return $false }
}

# ---------------------------------------------------------------------
#  Network tools
# ---------------------------------------------------------------------
function Reset-NetworkStack {
    try {
        netsh winsock reset | Out-Null
        netsh int ip reset | Out-Null
        ipconfig /flushdns | Out-Null
        ipconfig /release | Out-Null
        ipconfig /renew | Out-Null
        return $true
    } catch { Write-Log "Network reset failed: $($_.Exception.Message)" 'warn'; return $false }
}

function Get-GatewayPing([int]$Count = 6) {
    try {
        $gw = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
               Sort-Object RouteMetric | Select-Object -First 1).NextHop
        if ($gw) { return (Invoke-PingTest -Target $gw -Count $Count) }
    } catch {}
    return $null
}

function Get-NetSummary {
    $out = [ordered]@{ Adapter = 'n/a'; LinkMbps = 0; LocalIp = 'n/a'; Gateway = 'n/a'; Dns = @() }
    try {
        $a = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up' | Select-Object -First 1
        if ($a) {
            $out.Adapter = "$($a.Name) - $($a.LinkSpeed)"
            $out.LinkMbps = try { [int]($a.LinkSpeed -replace '[^\d]','') } catch { 0 }
            $ip = Get-NetIPAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($ip) { $out.LocalIp = $ip.IPAddress }
            $dns = @((Get-DnsClientServerAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses)
            $out.Dns = $dns
        }
        $gw = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Sort-Object RouteMetric | Select-Object -First 1
        if ($gw) { $out.Gateway = $gw.NextHop }
    } catch {}
    return [pscustomobject]$out
}
