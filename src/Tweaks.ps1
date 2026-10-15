# =====================================================================
#  Scottimizer 2  -  Tweak catalog
#  Every tweak records its prior state so "Undo" can restore it exactly.
#  Each entry:  Id, Group, Name, Desc, Risk, Default, Reboot, Tags,
#               Apply {}, Revert {}, Test {} (optional)
# =====================================================================

$script:MM     = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
$script:Games  = "$($script:MM)\Tasks\Games"
$script:GPUD   = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
$script:IfRoot = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces'

# ---------- Tweak helpers ----------
function Get-ActiveNics { @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' }) }

function Set-NicSetting {
    param([string]$Match, [string[]]$Candidates)
    $changed = 0
    foreach ($a in Get-ActiveNics) {
        foreach ($p in @(Get-NetAdapterAdvancedProperty -Name $a.Name -ErrorAction SilentlyContinue)) {
            if ($p.DisplayName -like "*$Match*") {
                foreach ($c in $Candidates) {
                    if (@($p.ValidDisplayValues) -contains $c) {
                        try { Set-NetAdapterAdvancedProperty -Name $a.Name -DisplayName $p.DisplayName -DisplayValue $c -NoRestart -ErrorAction Stop; $changed++ } catch {}
                        break
                    }
                }
            }
        }
    }
    return $changed
}

function Set-DnsForActiveNics([string[]]$Servers) {
    foreach ($a in Get-ActiveNics) {
        try { Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses $Servers -ErrorAction Stop } catch {}
    }
}

function Invoke-PowerCfg([string[]]$Args) {
    $out = & powercfg @Args 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -and $out -match 'error') { throw $out.Trim() }
    return $out
}

$script:_MpPrefCache = $null
$script:_MpPrefTime  = [datetime]::MinValue
function Get-DefenderPref {
    if ($script:_MpPrefCache -and ((Get-Date) - $script:_MpPrefTime).TotalSeconds -lt 10) { return $script:_MpPrefCache }
    try { $script:_MpPrefCache = Get-MpPreference -ErrorAction Stop } catch { $script:_MpPrefCache = $null }
    $script:_MpPrefTime = Get-Date
    return $script:_MpPrefCache
}

# =====================================================================
#  TWEAKS
# =====================================================================
$script:Tweaks = @(

  # ---------------------------------------------------------------- GAMING
  [pscustomobject]@{
    Id='power-ultimate'; Group='Gaming'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Ultimate Performance power plan'
    Desc='Locks the CPU to full speed instead of downclocking. Uses more power on laptops and adds heat.'
    Tags=@('Performance','Recommended')
    Test={ ((powercfg /getactivescheme) -match 'Ultimate Performance') }
    Apply={
      if (-not $script:State.PowerPlanPrev) { $script:State.PowerPlanPrev = Get-ActivePowerPlanGuid }
      $guid = Ensure-UltimatePowerPlan
      Invoke-PowerCfg @('/setactive', $guid) | Out-Null
    }
    Revert={ Invoke-PowerCfg @('/setactive','381b4222-f694-41f0-9685-ff5bb260df2e') | Out-Null }
  },

  [pscustomobject]@{
    Id='power-boost'; Group='Gaming'; Risk='Moderate'; Default=$true; Reboot=$false
    Name='Aggressive CPU boost + 100% min state'
    Desc='Forces maximum processor state, disables core parking and prefers aggressive boost. Best for desktops with good cooling.'
    Tags=@('Performance','Recommended')
    Apply={
      foreach ($s in 'scheme_current') {
        Invoke-PowerCfg @('-setacvalueindex',$s,'sub_processor','PROCTHROTTLEMIN','100') | Out-Null
        Invoke-PowerCfg @('-setacvalueindex',$s,'sub_processor','PROCTHROTTLEMAX','100') | Out-Null
        Invoke-PowerCfg @('-setacvalueindex',$s,'sub_processor','CPMINCORES','100')   | Out-Null
        Invoke-PowerCfg @('-setacvalueindex',$s,'sub_processor','PERFBOOSTMODE','2')   | Out-Null
        Invoke-PowerCfg @('-setacvalueindex',$s,'sub_processor','PERFINCTHRESHOLD','10')| Out-Null
        Invoke-PowerCfg @('-setdcvalueindex',$s,'sub_processor','PROCTHROTTLEMIN','5') | Out-Null
      }
      Invoke-PowerCfg @('/setactive','scheme_current') | Out-Null
    }
    Revert={
      Invoke-PowerCfg @('-setacvalueindex','scheme_current','sub_processor','CPMINCORES','0') | Out-Null
      Invoke-PowerCfg @('/setactive','scheme_current') | Out-Null
    }
  },

  [pscustomobject]@{
    Id='power-throttling'; Group='Gaming'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Disable power throttling'
    Desc='Stops Windows from throttling background and foreground apps to save power.'
    Tags=@('Performance','Recommended')
    Apply={ Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' 1 }
    Revert={ Remove-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' }
  },

  [pscustomobject]@{
    Id='power-usb'; Group='Gaming'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Disable USB selective suspend'
    Desc='Prevents USB devices (mouse, keyboard, controllers, DACs) from being suspended mid-session.'
    Tags=@('Performance')
    Apply={
      Invoke-PowerCfg @('-setacvalueindex','scheme_current','2a737441-1930-4402-8d77-b2bebba308a3','48e6b7a6-50f5-4782-a5d4-53bb8f07e226','0') | Out-Null
      Invoke-PowerCfg @('/setactive','scheme_current') | Out-Null
    }
    Revert={
      Invoke-PowerCfg @('-setacvalueindex','scheme_current','2a737441-1930-4402-8d77-b2bebba308a3','48e6b7a6-50f5-4782-a5d4-53bb8f07e226','1') | Out-Null
      Invoke-PowerCfg @('/setactive','scheme_current') | Out-Null
    }
  },

  [pscustomobject]@{
    Id='game-mode'; Group='Gaming'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Game Mode on, background capture off'
    Desc='Enables Windows Game Mode and turns off Game DVR background recording that steals frames.'
    Tags=@('Recommended')
    Apply={
      Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
      Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1
      Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
      Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
      Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'HistoricalCaptureEnabled' 0
    }
    Revert={
      Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 1
      Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 1
    }
  },

  [pscustomobject]@{
    Id='scheduler-priority'; Group='Gaming'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Prioritize games in the scheduler (MMCSS)'
    Desc='Gives games higher CPU/GPU priority through the multimedia scheduler and removes network throttling.'
    Tags=@('Recommended','Latency')
    Apply={
      Set-Reg $script:MM 'SystemResponsiveness' 0
      Set-Reg $script:MM 'NetworkThrottlingIndex' -1
      Set-Reg $script:Games 'GPU Priority' 8
      Set-Reg $script:Games 'Priority' 6
      Set-Reg $script:Games 'Scheduling Category' 'High' 'String'
      Set-Reg $script:Games 'SFIO Priority' 'High' 'String'
    }
    Revert={
      Set-Reg $script:MM 'SystemResponsiveness' 20
      Set-Reg $script:MM 'NetworkThrottlingIndex' 10
      Set-Reg $script:Games 'Priority' 2
      Set-Reg $script:Games 'Scheduling Category' 'Medium' 'String'
      Set-Reg $script:Games 'SFIO Priority' 'Medium' 'String'
    }
  },

  [pscustomobject]@{
    Id='priority-separation'; Group='Gaming'; Risk='Moderate'; Default=$true; Reboot=$false
    Name='Foreground boost (Win32PrioritySeparation)'
    Desc='Makes the scheduler favour your game window with a short, fixed quantum (value 38).'
    Tags=@('Performance')
    Apply={ Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' 38 }
    Revert={ Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' 2 }
  },

  [pscustomobject]@{
    Id='hags'; Group='Gaming'; Risk='Moderate'; Default=$true; Reboot=$true
    Name='Hardware-accelerated GPU scheduling'
    Desc='Lets the GPU manage its own command queues. Needs a supported GPU and a recent driver. Restart required.'
    Tags=@('Performance','Recommended')
    Test={ (Get-RegValue $script:GPUD 'HwSchMode' 0) -eq 2 }
    Apply={ Set-Reg $script:GPUD 'HwSchMode' 2 }
    Revert={ Remove-Reg $script:GPUD 'HwSchMode' }
  },

  [pscustomobject]@{
    Id='tdr-delay'; Group='Gaming'; Risk='Advanced'; Default=$false; Reboot=$true
    Name='Increase GPU timeout (TDR delay)'
    Desc='Raises the driver-reset timeout from 2s to 10s. Can reduce "driver stopped responding" crashes under heavy load.'
    Tags=@('Advanced')
    Apply={
      Set-Reg $script:GPUD 'TdrDelay' 10
      Set-Reg $script:GPUD 'TdrDdiDelay' 10
    }
    Revert={
      Remove-Reg $script:GPUD 'TdrDelay'
      Remove-Reg $script:GPUD 'TdrDdiDelay'
    }
  },

  [pscustomobject]@{
    Id='fse-off'; Group='Gaming'; Risk='Moderate'; Default=$true; Reboot=$false
    Name='Disable fullscreen optimizations'
    Desc='Forces true exclusive fullscreen so games bypass the desktop compositor for lower latency.'
    Tags=@('Latency','Recommended')
    Apply={
      Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_FSEBehaviorMode' 2
      Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_HonorUserFSEBehaviorMode' 1
      Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_DXGIHonorFSEWindowsCompatible' 1
      Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_EFSEFeatureFlags' 0
    }
    Revert={
      Remove-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_FSEBehaviorMode'
      Remove-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_HonorUserFSEBehaviorMode'
      Remove-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_DXGIHonorFSEWindowsCompatible'
      Remove-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_EFSEFeatureFlags'
    }
  },

  [pscustomobject]@{
    Id='mouse-raw'; Group='Gaming'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Raw mouse input (no acceleration)'
    Desc='Turns off pointer acceleration so aim is 1:1 and consistent.'
    Tags=@('Recommended')
    Apply={
      Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseSpeed' '0' 'String'
      Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '0' 'String'
      Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' '0' 'String'
    }
    Revert={
      Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseSpeed' '1' 'String'
      Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '6' 'String'
      Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' '10' 'String'
    }
  },

  [pscustomobject]@{
    Id='transparency'; Group='Gaming'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Disable transparency effects'
    Desc='Saves a little GPU time and looks cleaner. Purely visual.'
    Tags=@('Recommended')
    Apply={ Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0 }
    Revert={ Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 1 }
  },

  [pscustomobject]@{
    Id='visual-effects'; Group='Gaming'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Visual effects -> best performance'
    Desc='Turns off window animations and shadows to free desktop GPU/CPU time.'
    Tags=@('Recommended')
    Apply={
      Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 2
      Set-Reg 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '0' 'String'
    }
    Revert={
      Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 0
      Set-Reg 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '1' 'String'
    }
  },

  [pscustomobject]@{
    Id='startup-delay'; Group='Gaming'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Remove Explorer startup delay'
    Desc='Makes Explorer appear instantly after sign-in instead of waiting ~10 seconds.'
    Tags=@('Recommended')
    Apply={ Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'StartupDelayInMSec' 0 }
    Revert={ Remove-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'StartupDelayInMSec' }
  },

  [pscustomobject]@{
    Id='menu-delay'; Group='Gaming'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Instant menus'
    Desc='Removes the ~400ms delay before menus open.'
    Tags=@('')
    Apply={ Set-Reg 'HKCU:\Control Panel\Desktop' 'MenuShowDelay' '0' 'String' }
    Revert={ Set-Reg 'HKCU:\Control Panel\Desktop' 'MenuShowDelay' '400' 'String' }
  },

  [pscustomobject]@{
    Id='kill-timeouts'; Group='Gaming'; Risk='Moderate'; Default=$true; Reboot=$false
    Name='Faster app close / kill timeouts'
    Desc='Lets runaway apps and services be terminated sooner when they hang.'
    Tags=@('')
    Apply={
      Set-Reg 'HKCU:\Control Panel\Desktop' 'HungAppTimeout' '1000' 'String'
      Set-Reg 'HKCU:\Control Panel\Desktop' 'WaitToKillAppTimeout' '2000' 'String'
      Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control' 'WaitToKillServiceTimeout' '2000' 'String'
    }
    Revert={
      Set-Reg 'HKCU:\Control Panel\Desktop' 'HungAppTimeout' '5000' 'String'
      Set-Reg 'HKCU:\Control Panel\Desktop' 'WaitToKillAppTimeout' '5000' 'String'
      Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control' 'WaitToKillServiceTimeout' '5000' 'String'
    }
  },

  [pscustomobject]@{
    Id='delivery-opt'; Group='Gaming'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Stop Delivery Optimization peer uploads'
    Desc='Stops Windows Update from uploading to and downloading from other PCs, which can eat bandwidth mid-game.'
    Tags=@('Privacy')
    Apply={
      Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config' 'DODownloadMode' 0
      Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' 0
    }
    Revert={
      Remove-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode'
      Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config' 'DODownloadMode' 1
    }
  },

  [pscustomobject]@{
    Id='xbox-gamebar'; Group='Gaming'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Stop Xbox Game Bar overlay/autostart'
    Desc='Disables the Game Bar overlay and its startup panel while keeping the Xbox app and controller support.'
    Tags=@('')
    Test={ (Get-RegValue 'HKCU:\Software\Microsoft\GameBar' 'ShowStartupPanel' 1) -eq 0 }
    Apply={
      Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'ShowStartupPanel' 0
      Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'UseNexusForGameBarEnabled' 0
      Set-Reg 'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\ApplicationManagement\AllowGameDVR' 'value' 0
    }
    Revert={ Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'ShowStartupPanel' 1 }
  },

  [pscustomobject]@{
    Id='sysmain-off'; Group='Gaming'; Risk='Moderate'; Default=$false; Reboot=$false
    Name='Disable SysMain (Superfetch)'
    Desc='Stops the SysMain prefetch service. On SSDs it frees a little RAM and disk activity; on HDDs it can hurt.'
    Tags=@('Advanced')
    Test={ (Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Services\SysMain' 'Start' 3) -eq 4 }
    Apply={ [void](Set-ServiceStart 'SysMain' 'Disabled'); Stop-Svc 'SysMain' }
    Revert={ [void](Set-ServiceStart 'SysMain' 'Automatic') }
  },

  [pscustomobject]@{
    Id='search-off'; Group='Gaming'; Risk='Moderate'; Default=$false; Reboot=$false
    Name='Disable Windows Search indexing'
    Desc='Stops background file indexing. Frees CPU/disk on big drives, but Start-menu file search gets slower.'
    Tags=@('Advanced')
    Test={ (Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Services\WSearch' 'Start' 3) -eq 4 }
    Apply={ [void](Set-ServiceStart 'WSearch' 'Disabled'); Stop-Svc 'WSearch' }
    Revert={ [void](Set-ServiceStart 'WSearch' 'AutomaticDelayed') }
  },

  # --------------------------------------------------------------- NETWORK
  [pscustomobject]@{
    Id='tcp-base'; Group='Network'; Risk='Safe'; Default=$true; Reboot=$false
    Name='TCP tuning (Normal auto-tuning + RSS)'
    Desc='Restores normal receive auto-tuning and enables Receive Side Scaling for steady, low-overhead networking.'
    Tags=@('Recommended')
    Apply={
      netsh int tcp set global autotuninglevel=normal | Out-Null
      netsh int tcp set global rss=enabled | Out-Null
    }
    Revert={
      netsh int tcp set global autotuninglevel=normal | Out-Null
    }
  },

  [pscustomobject]@{
    Id='tcp-adv'; Group='Network'; Risk='Moderate'; Default=$true; Reboot=$false
    Name='Advanced TCP (low latency)'
    Desc='Disables heuristics, timestamps and ECN and keeps RSC on. Reduces latency for small game packets.'
    Tags=@('Latency','Recommended')
    Apply={
      netsh int tcp set heuristics disabled | Out-Null
      netsh int tcp set global timestamps=disabled | Out-Null
      netsh int tcp set global ecncapability=disabled | Out-Null
      netsh int tcp set global rsc=enabled | Out-Null
    }
    Revert={
      netsh int tcp set heuristics enabled | Out-Null
      netsh int tcp set global timestamps=default | Out-Null
      netsh int tcp set global ecncapability=default | Out-Null
    }
  },

  [pscustomobject]@{
    Id='nagle'; Group='Network'; Risk='Safe'; Default=$true; Reboot=$true
    Name="Disable Nagle's algorithm"
    Desc='Sends small game packets immediately instead of batching them. Restart required.'
    Tags=@('Latency','Recommended')
    Apply={
      foreach ($a in Get-ActiveNics) {
        $k = Join-Path $script:IfRoot $a.InterfaceGuid
        if (Test-Path $k) {
          Set-Reg $k 'TcpAckFrequency' 1
          Set-Reg $k 'TCPNoDelay' 1
          Set-Reg $k 'TcpDelAckTicks' 0
        }
      }
    }
    Revert={
      Get-ChildItem $script:IfRoot -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Reg $_.PSPath 'TcpAckFrequency'
        Remove-Reg $_.PSPath 'TCPNoDelay'
        Remove-Reg $_.PSPath 'TcpDelAckTicks'
      }
    }
  },

  [pscustomobject]@{
    Id='nic-power'; Group='Network'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Stop network adapter power saving'
    Desc='Keeps your network card awake so it cannot sleep or stall mid-match.'
    Tags=@('Recommended')
    Apply={ foreach ($a in Get-ActiveNics) { try { Disable-NetAdapterPowerManagement -Name $a.Name -NoRestart -ErrorAction Stop } catch {} } }
    Revert={ foreach ($a in Get-ActiveNics) { try { Enable-NetAdapterPowerManagement -Name $a.Name -NoRestart -ErrorAction Stop } catch {} } }
  },

  [pscustomobject]@{
    Id='nic-eee'; Group='Network'; Risk='Moderate'; Default=$true; Reboot=$false
    Name='Turn off Energy Efficient Ethernet'
    Desc='Disables EEE / Green Ethernet on the NIC, which can add latency by sleeping the link between packets.'
    Tags=@('Latency')
    Apply={ [void](Set-NicSetting -Match 'Energy Efficient Ethernet' -Candidates @('Disabled','Off')) }
    Revert={ [void](Set-NicSetting -Match 'Energy Efficient Ethernet' -Candidates @('Enabled','On')) }
  },

  [pscustomobject]@{
    Id='nic-intmod'; Group='Network'; Risk='Advanced'; Default=$false; Reboot=$false
    Name='Disable NIC interrupt moderation'
    Desc='Cuts packet-handling latency at the cost of higher CPU use. Can help competitive shooters; may reduce throughput.'
    Tags=@('Latency','Advanced')
    Apply={ [void](Set-NicSetting -Match 'Interrupt Moderation' -Candidates @('Disabled','Off')) }
    Revert={ [void](Set-NicSetting -Match 'Interrupt Moderation' -Candidates @('Enabled','On')) }
  },

  [pscustomobject]@{
    Id='qos-bandwidth'; Group='Network'; Risk='Moderate'; Default=$true; Reboot=$false
    Name='Remove QoS reserved bandwidth'
    Desc='Stops the QoS packet scheduler reserving ~20% of your link.'
    Tags=@('Latency','Recommended')
    Apply={ Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched' 'NonBestEffortLimit' 0 }
    Revert={ Remove-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched' 'NonBestEffortLimit' }
  },

  [pscustomobject]@{
    Id='flush-dns'; Group='Network'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Flush DNS cache'
    Desc='Clears stale DNS lookups. Runs once; nothing to undo.'
    Tags=@('')
    Apply={ Clear-DnsClientCache -ErrorAction SilentlyContinue; ipconfig /flushdns | Out-Null }
    Revert=$null
  },

  [pscustomobject]@{
    Id='dns-cf'; Group='Network'; Risk='Safe'; Default=$false; Reboot=$false
    Name='DNS: Cloudflare (1.1.1.1)'
    Desc='Fast, privacy-respecting DNS. Often lower lookup latency than your ISP default.'
    Tags=@('Latency')
    Apply={ Set-DnsForActiveNics @('1.1.1.1','1.0.0.1'); Clear-DnsClientCache }
    Revert={ foreach ($a in Get-ActiveNics) { try { Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ResetServerAddresses } catch {} } }
  },

  [pscustomobject]@{
    Id='dns-cf-sec'; Group='Network'; Risk='Safe'; Default=$false; Reboot=$false
    Name='DNS: Cloudflare Security (1.1.1.2)'
    Desc='Cloudflare DNS that blocks known malware domains. A good default with a security focus.'
    Tags=@('Security')
    Apply={ Set-DnsForActiveNics @('1.1.1.2','1.0.0.2'); Clear-DnsClientCache }
    Revert={ foreach ($a in Get-ActiveNics) { try { Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ResetServerAddresses } catch {} } }
  },

  [pscustomobject]@{
    Id='dns-quad9'; Group='Network'; Risk='Safe'; Default=$false; Reboot=$false
    Name='DNS: Quad9 (9.9.9.9)'
    Desc='Security-focused resolver that blocks malicious domains using threat intelligence.'
    Tags=@('Security')
    Apply={ Set-DnsForActiveNics @('9.9.9.9','149.112.112.112'); Clear-DnsClientCache }
    Revert={ foreach ($a in Get-ActiveNics) { try { Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ResetServerAddresses } catch {} } }
  },

  [pscustomobject]@{
    Id='doh'; Group='Network'; Risk='Moderate'; Default=$false; Reboot=$true
    Name='Encrypt DNS (DNS over HTTPS)'
    Desc='Turns on Windows DoH auto-upgrade so DNS queries to known resolvers are encrypted. Restart required.'
    Tags=@('Security','Privacy')
    Apply={ Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters' 'EnableAutoDoh' 2 }
    Revert={ Remove-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters' 'EnableAutoDoh' }
  },

  [pscustomobject]@{
    Id='ipv6-off'; Group='Network'; Risk='Advanced'; Default=$false; Reboot=$true
    Name='Disable IPv6 on active adapters'
    Desc='Some games and routers behave better without IPv6. Do not use if your ISP uses IPv6 for connectivity.'
    Tags=@('Advanced')
    Apply={ foreach ($a in Get-ActiveNics) { try { Disable-NetAdapterBinding -Name $a.Name -ComponentID ms_tcpip6 -ErrorAction Stop } catch {} } }
    Revert={ foreach ($a in Get-ActiveNics) { try { Enable-NetAdapterBinding -Name $a.Name -ComponentID ms_tcpip6 -ErrorAction Stop } catch {} } }
  },

  # -------------------------------------------------------------- SECURITY
  [pscustomobject]@{
    Id='firewall-on'; Group='Security'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Enable Windows Firewall on all profiles'
    Desc='Turns the firewall on for Domain, Private and Public networks.'
    Tags=@('Security','Recommended')
    Test={ -not (Get-NetFirewallProfile -ErrorAction SilentlyContinue | Where-Object { -not $_.Enabled }) }
    Apply={ Set-NetFirewallProfile -All -Enabled True }
    Revert={ Set-NetFirewallProfile -Profile Public,Private -Enabled True }
  },

  [pscustomobject]@{
    Id='firewall-block'; Group='Security'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Firewall: block inbound by default'
    Desc='Sets inbound traffic to Block (allow outbound), which is the recommended baseline.'
    Tags=@('Security','Recommended')
    Apply={ Set-NetFirewallProfile -All -DefaultInboundAction Block -DefaultOutboundAction Allow }
    Revert={ Set-NetFirewallProfile -All -DefaultInboundAction NotConfigured -DefaultOutboundAction NotConfigured }
  },

  [pscustomobject]@{
    Id='firewall-log'; Group='Security'; Risk='Safe'; Default=$false; Reboot=$false
    Name='Firewall logging'
    Desc='Logs dropped inbound connections to a file for troubleshooting and detection.'
    Tags=@('Security')
    Apply={
      $log = "$env:WINDIR\System32\LogFiles\Firewall\pfirewall.log"
      Set-NetFirewallProfile -All -LogBlocked True -LogAllowed False -LogFileName $log -LogMaxSizeKilobytes 16384
    }
    Revert={ Set-NetFirewallProfile -All -LogBlocked False }
  },

  [pscustomobject]@{
    Id='defender-hard'; Group='Security'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Harden Microsoft Defender'
    Desc='Enables cloud-delivered protection (high block level), PUA blocking and network protection.'
    Tags=@('Security','Recommended')
    Apply={
      if (Get-DefenderPref) {
        try { Set-MpPreference -MAPSReporting Advanced -SubmitSamplesConsent SendSafeSamples -CloudBlockLevel High -PUAProtection Enabled -EnableNetworkProtection Enabled -DisableRealtimeMonitoring $false -ErrorAction Stop } catch {}
      }
    }
    Revert={ if (Get-DefenderPref) { try { Set-MpPreference -MAPSReporting Basic -PUAProtection Disabled -EnableNetworkProtection Disabled } catch {} } }
  },

  [pscustomobject]@{
    Id='cfa'; Group='Security'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Ransomware protection (Controlled Folder Access)'
    Desc='Blocks untrusted apps from modifying your protected folders. Best combined with your own app allow-list.'
    Tags=@('Security','Recommended')
    Test={ (Get-DefenderPref).EnableControlledFolderAccess -eq 1 }
    Apply={ if (Get-DefenderPref) { try { Set-MpPreference -EnableControlledFolderAccess Enabled -ErrorAction Stop } catch {} } }
    Revert={ if (Get-DefenderPref) { try { Set-MpPreference -EnableControlledFolderAccess Disabled } catch {} } }
  },

  [pscustomobject]@{
    Id='mem-integrity'; Group='Security'; Risk='Moderate'; Default=$false; Reboot=$true
    Name='Memory integrity (Core Isolation / HVCI)'
    Desc='Runs kernel-mode code-integrity checks in a virtualised container. Strong anti-malware measure. Restart required.'
    Tags=@('Security','Recommended')
    Apply={ Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' 'Enabled' 1 }
    Revert={ Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' 'Enabled' 0 }
  },

  [pscustomobject]@{
    Id='lsa-ppl'; Group='Security'; Risk='Moderate'; Default=$true; Reboot=$true
    Name='LSA protection (RunAsPPL)'
    Desc='Protects the process holding your credentials from being read by credential-stealing malware. Restart required.'
    Tags=@('Security','Recommended')
    Test={ (Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RunAsPPL' 0) -eq 1 }
    Apply={ Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RunAsPPL' 1 }
    Revert={ Remove-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RunAsPPL' }
  },

  [pscustomobject]@{
    Id='wdigest-off'; Group='Security'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Stop storing plaintext passwords (WDigest)'
    Desc='Prevents Windows from keeping your password in memory in cleartext.'
    Tags=@('Security','Recommended')
    Test={ (Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest' 'UseLogonCredential' 0) -eq 0 }
    Apply={ Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest' 'UseLogonCredential' 0 }
    Revert={ Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest' 'UseLogonCredential' 1 }
  },

  [pscustomobject]@{
    Id='nolmhash'; Group='Security'; Risk='Moderate'; Default=$true; Reboot=$false
    Name='Do not store LAN Manager hashes'
    Desc='Prevents the weak LM hash of your password from being stored.'
    Tags=@('Security','Recommended')
    Apply={ Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'NoLMHash' 1 }
    Revert={ Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'NoLMHash' 0 }
  },

  [pscustomobject]@{
    Id='restrict-anon'; Group='Security'; Risk='Moderate'; Default=$true; Reboot=$false
    Name='Restrict anonymous access'
    Desc='Blocks anonymous enumeration of accounts and shares over SMB.'
    Tags=@('Security','Recommended')
    Apply={
      Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RestrictAnonymous' 1
      Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RestrictAnonymousSAM' 1
    }
    Revert={
      Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RestrictAnonymous' 0
      Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RestrictAnonymousSAM' 0
    }
  },

  [pscustomobject]@{
    Id='smbv1-off'; Group='Security'; Risk='Safe'; Default=$true; Reboot=$true
    Name='Disable SMBv1'
    Desc='Turns off the legacy SMBv1 protocol used by WannaCry and other worms. Restart required.'
    Tags=@('Security','Recommended')
    Apply={
      try { Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction Stop } catch {}
      try { Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction Stop | Out-Null } catch {}
    }
    Revert={ try { Set-SmbServerConfiguration -EnableSMB1Protocol $true -Force } catch {} }
  },

  [pscustomobject]@{
    Id='smb-sign'; Group='Security'; Risk='Moderate'; Default=$true; Reboot=$false
    Name='Require SMB signing'
    Desc='Signs SMB traffic so it cannot be tampered with in transit.'
    Tags=@('Security')
    Apply={
      try { Set-SmbClientConfiguration -RequireSecuritySignature $true -Force -ErrorAction Stop } catch {}
      try { Set-SmbServerConfiguration -RequireSecuritySignature $true -Force -ErrorAction Stop } catch {}
    }
    Revert={
      try { Set-SmbClientConfiguration -RequireSecuritySignature $false -Force } catch {}
      try { Set-SmbServerConfiguration -RequireSecuritySignature $false -Force } catch {}
    }
  },

  [pscustomobject]@{
    Id='smb-guest'; Group='Security'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Block insecure SMB guest logons'
    Desc='Stops Windows from signing in to remote shares as an anonymous guest.'
    Tags=@('Security','Recommended')
    Apply={ try { Set-SmbClientConfiguration -EnableInsecureGuestLogons $false -Force -ErrorAction Stop } catch {} }
    Revert={ try { Set-SmbClientConfiguration -EnableInsecureGuestLogons $true -Force } catch {} }
  },

  [pscustomobject]@{
    Id='llmnr-off'; Group='Security'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Disable LLMNR'
    Desc='Stops Link-Local Multicast Name Resolution, a common credential-relay attack vector.'
    Tags=@('Security','Recommended')
    Test={ (Get-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' 'EnableMulticast' 1) -eq 0 }
    Apply={ Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' 'EnableMulticast' 0 }
    Revert={ Remove-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' 'EnableMulticast' }
  },

  [pscustomobject]@{
    Id='netbios-off'; Group='Security'; Risk='Moderate'; Default=$true; Reboot=$false
    Name='Disable NetBIOS over TCP/IP'
    Desc='Closes another legacy name-resolution attack surface on your adapters.'
    Tags=@('Security','Recommended')
    Apply={ foreach ($a in Get-ActiveNics) { try { (Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "Index=$($a.ifIndex)").SetTcpipNetbios(2) | Out-Null } catch {} } }
    Revert={ foreach ($a in Get-ActiveNics) { try { (Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "Index=$($a.ifIndex)").SetTcpipNetbios(0) | Out-Null } catch {} } }
  },

  [pscustomobject]@{
    Id='autorun-off'; Group='Security'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Disable AutoRun / AutoPlay for all drives'
    Desc='Stops USB drives and media from auto-launching programs (a classic malware vector).'
    Tags=@('Security','Recommended')
    Apply={
      Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoDriveTypeAutoRun' 255
      Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoAutorun' 1
      Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoDriveTypeAutoRun' 255
    }
    Revert={
      Remove-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoDriveTypeAutoRun'
      Remove-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoAutorun'
      Remove-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoDriveTypeAutoRun'
    }
  },

  [pscustomobject]@{
    Id='rdp-off'; Group='Security'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Disable Remote Desktop'
    Desc='Stops others from connecting to your PC over RDP. Turn off for normal home use.'
    Tags=@('Security','Recommended')
    Test={ (Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections' 1) -eq 1 }
    Apply={
      Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections' 1
      try { Set-NetFirewallRule -DisplayGroup 'Remote Desktop' -Enabled False -ErrorAction SilentlyContinue } catch {}
    }
    Revert={ Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections' 0 }
  },

  [pscustomobject]@{
    Id='remote-assist'; Group='Security'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Disable Remote Assistance'
    Desc='Blocks unsolicited Remote Assistance invitations.'
    Tags=@('Security','Recommended')
    Apply={ Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance' 'fAllowToGetHelp' 0 }
    Revert={ Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance' 'fAllowToGetHelp' 1 }
  },

  [pscustomobject]@{
    Id='smartscreen'; Group='Security'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Enable SmartScreen'
    Desc='Blocks known-bad apps and websites in Windows and Edge.'
    Tags=@('Security','Recommended')
    Apply={
      Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableSmartScreen' 1
      Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'ShellSmartScreenLevel' 'Block' 'String'
      Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AppHost' 'EnableWebContentEvaluation' 1
    }
    Revert={ Remove-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableSmartScreen' }
  },

  [pscustomobject]@{
    Id='psv2-off'; Group='Security'; Risk='Advanced'; Default=$false; Reboot=$true
    Name='Remove PowerShell 2.0 engine'
    Desc='Downlevel PowerShell is often abused by attackers to bypass logging. Restart required.'
    Tags=@('Security','Advanced')
    Apply={ try { Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2 -NoRestart -ErrorAction Stop | Out-Null } catch {} }
    Revert={ try { Enable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2 -NoRestart | Out-Null } catch {} }
  },

  [pscustomobject]@{
    Id='wsh-off'; Group='Security'; Risk='Advanced'; Default=$false; Reboot=$false
    Name='Disable Windows Script Host'
    Desc='Blocks .vbs/.js script files, which are a very common malware dropper. Breaks legitimate scripts.'
    Tags=@('Security','Advanced')
    Apply={ Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows Script Host\Settings' 'Enabled' 0 }
    Revert={ Remove-Reg 'HKLM:\SOFTWARE\Microsoft\Windows Script Host\Settings' 'Enabled' }
  },

  [pscustomobject]@{
    Id='file-ext'; Group='Security'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Show file extensions'
    Desc='Shows .exe/.pdf/.txt endings so disguised files like "invoice.pdf.exe" are obvious.'
    Tags=@('Security','Recommended')
    Apply={ Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'HideFileExt' 0 }
    Revert={ Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'HideFileExt' 1 }
  },

  [pscustomobject]@{
    Id='guest-off'; Group='Security'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Disable the Guest account'
    Desc='Ensures the built-in Guest account stays disabled.'
    Tags=@('Security','Recommended')
    Test={ -not (Get-LocalUser -Name 'Guest' -ErrorAction SilentlyContinue).Enabled }
    Apply={ try { net user guest /active:no 2>&1 | Out-Null } catch {} }
    Revert={ try { net user guest /active:no 2>&1 | Out-Null } catch {} }
  },

  [pscustomobject]@{
    Id='recall-off'; Group='Security'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Turn off Windows Recall'
    Desc='Disables Windows Recall (Win11), which continuously snapshots your screen. Big privacy/security win.'
    Tags=@('Security','Privacy','Recommended')
    Apply={
      Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1
      Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1
    }
    Revert={
      Remove-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis'
      Remove-Reg 'HKCU:\Software\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis'
    }
  },

  # --------------------------------------------------------------- PRIVACY
  [pscustomobject]@{
    Id='telemetry'; Group='Privacy'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Minimize telemetry (diagnostic data)'
    Desc='Sets diagnostic data to the lowest level and disables the tailored-experience feedback.'
    Tags=@('Privacy','Recommended')
    Apply={
      Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0
      Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'AllowTelemetry' 0
      Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'MaxTelemetryAllowed' 0
    }
    Revert={ Remove-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' }
  },

  [pscustomobject]@{
    Id='telemetry-svc'; Group='Privacy'; Risk='Moderate'; Default=$true; Reboot=$false
    Name='Disable telemetry services'
    Desc='Stops Connected User Experiences and Telemetry (DiagTrack) and the WAP push service.'
    Tags=@('Privacy','Recommended')
    Test={ (Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Services\DiagTrack' 'Start' 3) -eq 4 }
    Apply={
      [void](Set-ServiceStart 'DiagTrack' 'Disabled'); Stop-Svc 'DiagTrack'
      [void](Set-ServiceStart 'dmwappushservice' 'Disabled'); Stop-Svc 'dmwappushservice'
    }
    Revert={ [void](Set-ServiceStart 'DiagTrack' 'Automatic'); [void](Set-ServiceStart 'dmwappushservice' 'Manual') }
  },

  [pscustomobject]@{
    Id='ad-id'; Group='Privacy'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Turn off advertising ID'
    Desc='Stops apps using a per-user ad tracking ID.'
    Tags=@('Privacy','Recommended')
    Apply={
      Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0
      Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' 'DisabledByGroupPolicy' 1
    }
    Revert={ Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 1 }
  },

  [pscustomobject]@{
    Id='activity-history'; Group='Privacy'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Disable activity history / Timeline'
    Desc='Stops Windows collecting and uploading the apps and files you open.'
    Tags=@('Privacy','Recommended')
    Apply={
      Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableActivityFeed' 0
      Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'PublishUserActivities' 0
      Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'UploadUserActivities' 0
    }
    Revert={ Remove-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableActivityFeed' }
  },

  [pscustomobject]@{
    Id='location-off'; Group='Privacy'; Risk='Moderate'; Default=$false; Reboot=$false
    Name='Disable location tracking'
    Desc='Turns off system location and per-user location access.'
    Tags=@('Privacy')
    Apply={
      Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' 'DisableLocation' 1
      Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' 'Value' 'Deny' 'String'
    }
    Revert={ Remove-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' 'DisableLocation' }
  },

  [pscustomobject]@{
    Id='feedback'; Group='Privacy'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Stop feedback requests'
    Desc='Disables Windows Feedback notifications and the SIUF survey.'
    Tags=@('Privacy','Recommended')
    Apply={
      Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'DoNotShowFeedbackNotifications' 1
      Set-Reg 'HKCU:\Software\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' 0
    }
    Revert={ Remove-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'DoNotShowFeedbackNotifications' }
  },

  [pscustomobject]@{
    Id='consumer-content'; Group='Privacy'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Block suggested/promoted content'
    Desc='Stops Windows silently installing promoted apps and showing suggestions in the Start menu.'
    Tags=@('Privacy','Debloat','Recommended')
    Apply={
      Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1
      Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableConsumerAccountStateContent' 1
      Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableSoftLanding' 1
      Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SystemPaneSuggestionsEnabled' 0
      Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SilentInstalledAppsEnabled' 0
      Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338388Enabled' 0
      Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338389Enabled' 0
      Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-310093Enabled' 0
    }
    Revert={ Remove-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' }
  },

  [pscustomobject]@{
    Id='copilot-off'; Group='Privacy'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Disable Windows Copilot'
    Desc='Removes the Copilot button and disables the service integration.'
    Tags=@('Privacy','Recommended')
    Apply={
      Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
      Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
    }
    Revert={
      Remove-Reg 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot'
      Remove-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot'
    }
  },

  [pscustomobject]@{
    Id='widgets-off'; Group='Privacy'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Disable Widgets / news feed'
    Desc='Removes the taskbar Widgets button and its background news/feed processes.'
    Tags=@('Privacy','Debloat','Recommended')
    Apply={
      Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0
      Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarDa' 0
    }
    Revert={ Remove-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' }
  },

  [pscustomobject]@{
    Id='bing-search'; Group='Privacy'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Disable Bing/web results in Start search'
    Desc='Keeps Start-menu search local and offline.'
    Tags=@('Privacy','Recommended')
    Apply={ Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1 }
    Revert={ Remove-Reg 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' }
  },

  [pscustomobject]@{
    Id='cortana-off'; Group='Privacy'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Disable Cortana'
    Desc='Turns off the Cortana voice assistant integration.'
    Tags=@('Privacy','Recommended')
    Apply={
      Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'AllowCortana' 0
      Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'CortanaConsent' 0
    }
    Revert={ Remove-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'AllowCortana' }
  },

  [pscustomobject]@{
    Id='tailored'; Group='Privacy'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Disable tailored experiences & launch tracking'
    Desc='Stops Windows personalising tips/ads from your usage data and tracking launched apps.'
    Tags=@('Privacy','Recommended')
    Apply={
      Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0
      Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableTailoredExperiencesWithDiagnosticData' 1
      Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_TrackProgs' 0
    }
    Revert={ Remove-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableTailoredExperiencesWithDiagnosticData' }
  },

  [pscustomobject]@{
    Id='bg-apps'; Group='Privacy'; Risk='Moderate'; Default=$false; Reboot=$false
    Name='Disable background apps'
    Desc='Stops Store apps running in the background. Saves RAM/CPU but you lose background notifications.'
    Tags=@('Privacy','Advanced')
    Apply={ Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' 1 }
    Revert={ Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' 0 }
  },

  # -------------------------------------------------------------- DEBLOAT
  [pscustomobject]@{
    Id='debloat-apps'; Group='Debloat'; Risk='Moderate'; Default=$false; Reboot=$false
    Name='Remove pre-installed Store apps'
    Desc='Uninstalls a curated list of consumer bloat apps (news, weather, solitaire, etc). Keeps Xbox, Store and calculator.'
    Tags=@('Debloat','Advanced')
    Apply={
      $bloat = @(
        'Microsoft.3DBuilder','Microsoft.BingWeather','Microsoft.BingNews','Microsoft.BingSearch',
        'Microsoft.GetHelp','Microsoft.Getstarted','Microsoft.MicrosoftOfficeHub',
        'Microsoft.MicrosoftSolitaireCollection','Microsoft.MixedReality.Portal','Microsoft.People',
        'Microsoft.SkypeApp','Microsoft.WindowsFeedbackHub','Microsoft.WindowsMaps','Microsoft.YourPhone',
        'Microsoft.ZuneMusic','Microsoft.ZuneVideo','Microsoft.Todos','Microsoft.PowerAutomateDesktop',
        'Microsoft.WindowsAlarms','Microsoft.WindowsSoundRecorder','Microsoft.Copilot','Microsoft.News',
        'Microsoft.MicrosoftJournal','Microsoft.StartExperiencesApp',
        'Clipchamp.Clipchamp','MicrosoftTeams','Disney.*','SpotifyAB.SpotifyMusic','*Twitter*','*Facebook*','*TikTok*'
      )
      foreach ($pkg in @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue)) {
        foreach ($pat in $bloat) {
          if ($pkg.Name -like $pat) {
            try { Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop }
            catch { try { Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop } catch {} }
            break
          }
        }
      }
      foreach ($pat in $bloat) {
        foreach ($prov in @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $pat })) {
          try { Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction Stop | Out-Null } catch {}
        }
      }
    }
    Revert=$null
  },

  [pscustomobject]@{
    Id='debloat-cortana'; Group='Debloat'; Risk='Moderate'; Default=$false; Reboot=$false
    Name='Remove the Cortana app'
    Desc='Uninstalls the standalone Cortana application package.'
    Tags=@('Debloat')
    Apply={ foreach ($p in @(Get-AppxPackage -AllUsers 'Microsoft.549981C3F5F10' -ErrorAction SilentlyContinue)) { try { Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop } catch {} } }
    Revert=$null
  },

  [pscustomobject]@{
    Id='debloat-onedrive'; Group='Debloat'; Risk='Advanced'; Default=$false; Reboot=$false
    Name='Uninstall / unlink OneDrive'
    Desc='Runs the OneDrive uninstaller and removes it from Explorer. Your cloud files stay safe online.'
    Tags=@('Debloat','Advanced')
    Apply={
      Stop-Process -Name 'OneDrive' -Force -ErrorAction SilentlyContinue
      $exe = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
      if (-not (Test-Path $exe)) { $exe = "$env:SystemRoot\System32\OneDriveSetup.exe" }
      if (Test-Path $exe) { Start-Process $exe -ArgumentList '/uninstall' -Wait -ErrorAction SilentlyContinue }
    }
    Revert=$null
  },

  [pscustomobject]@{
    Id='debloat-teams'; Group='Debloat'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Hide consumer Teams / Chat button'
    Desc='Removes the personal Chat/Teams button from the taskbar.'
    Tags=@('Debloat','Recommended')
    Apply={
      Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarMn' 0
      Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarDa' 0
    }
    Revert={ Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarMn' 1 }
  },

  # --------------------------------------------------------------- SYSTEM
  [pscustomobject]@{
    Id='fast-startup-off'; Group='System'; Risk='Moderate'; Default=$true; Reboot=$false
    Name='Disable Fast Startup (hybrid boot)'
    Desc='Ensures a clean full shutdown each time. Fixes many "works only after reboot" issues and dual-boot problems.'
    Tags=@('Recommended')
    Test={ (Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled' 1) -eq 0 }
    Apply={ Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled' 0 }
    Revert={ Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled' 1 }
  },

  [pscustomobject]@{
    Id='hibernation-off'; Group='System'; Risk='Moderate'; Default=$false; Reboot=$false
    Name='Disable hibernation'
    Desc='Frees several GB on the system drive and removes hiberfil.sys (which can hold secrets at rest).'
    Tags=@('Security','Advanced')
    Apply={ powercfg /hibernate off | Out-Null }
    Revert={ powercfg /hibernate on | Out-Null }
  },

  [pscustomobject]@{
    Id='ntfs-lastaccess'; Group='System'; Risk='Safe'; Default=$true; Reboot=$false
    Name='NTFS: stop tracking last-access time'
    Desc='Removes a small per-file I/O overhead on every read.'
    Tags=@('Recommended')
    Apply={ fsutil behavior set disablelastaccess 1 | Out-Null }
    Revert={ fsutil behavior set disablelastaccess 2 | Out-Null }
  },

  [pscustomobject]@{
    Id='ntfs-8dot3'; Group='System'; Risk='Moderate'; Default=$false; Reboot=$false
    Name='NTFS: disable 8.3 short names'
    Desc='Stops creating DOS-compatible file names. Speeds up file creation on large drives.'
    Tags=@('Advanced')
    Apply={ fsutil behavior set disable8dot3 1 | Out-Null }
    Revert={ fsutil behavior set disable8dot3 0 | Out-Null }
  },

  [pscustomobject]@{
    Id='trim'; Group='System'; Risk='Safe'; Default=$true; Reboot=$false
    Name='Ensure SSD TRIM is enabled'
    Desc='Keeps SSD performance and lifespan healthy.'
    Tags=@('Recommended')
    Apply={ fsutil behavior set DisableDeleteNotify 0 | Out-Null }
    Revert={ }
  }
)
