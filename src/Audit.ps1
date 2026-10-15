# =====================================================================
#  Scottimizer 2  -  Security audit
#  Runs read-only checks and returns pass/fail items with a score.
#  Each item can carry a FixId that links to a tweak in Tweaks.ps1.
# =====================================================================

function New-AuditItem {
    param([string]$Area, [string]$Check, [ValidateSet('pass','fail','warn','info')][string]$Status,
          [string]$Detail, [string]$FixId = '')
    [pscustomobject]@{ Area = $Area; Check = $Check; Status = $Status; Detail = $Detail; FixId = $FixId }
}

function Invoke-SecurityAudit {
    $r = New-Object System.Collections.ArrayList
    function Add($a,$c,$s,$d,$f='') { [void]$r.Add((New-AuditItem -Area $a -Check $c -Status $s -Detail $d -FixId $f)) }

    # ---- Defender ----
    $mp = $null; $mpc = $null
    try { $mp  = Get-MpPreference -ErrorAction Stop } catch {}
    try { $mpc = Get-MpComputerStatus -ErrorAction Stop } catch {}
    if ($mpc) {
        if ($mpc.RealTimeProtectionEnabled) { Add 'Defender' 'Real-time protection' 'pass' 'On' } else { Add 'Defender' 'Real-time protection' 'fail' 'Off' 'defender-hard' }
        if ($mpc.AntivirusEnabled)          { Add 'Defender' 'Antivirus engine'      'pass' 'Active' } else { Add 'Defender' 'Antivirus engine' 'fail' 'Not active' 'defender-hard' }
        if ($mpc.IsTamperProtected)         { Add 'Defender' 'Tamper protection'     'pass' 'On' } else { Add 'Defender' 'Tamper protection' 'warn' 'Off (enable it in Windows Security)' }
        if ($mpc.AntivirusSignatureAge -le 3) { Add 'Defender' 'Signature age'        'pass' ("{0} day(s)" -f $mpc.AntivirusSignatureAge) } else { Add 'Defender' 'Signature age' 'warn' ("{0} day(s) old" -f $mpc.AntivirusSignatureAge) }
    } else {
        Add 'Defender' 'Microsoft Defender' 'info' 'Not present or a third-party AV is managing the system'
    }
    if ($mp) {
        $cloud = @($mp.MAPSReporting) -join ''
        if ($mp.MAPSReporting -ge 2) { Add 'Defender' 'Cloud-delivered protection' 'pass' 'Advanced' } else { Add 'Defender' 'Cloud-delivered protection' 'warn' 'Basic/off' 'defender-hard' }
        if ($mp.PUAProtection -ge 1) { Add 'Defender' 'PUA protection' 'pass' 'On' } else { Add 'Defender' 'PUA protection' 'warn' 'Off' 'defender-hard' }
        if ($mp.EnableNetworkProtection -ge 1) { Add 'Defender' 'Network protection' 'pass' 'On' } else { Add 'Defender' 'Network protection' 'warn' 'Off' 'defender-hard' }
        if ($mp.EnableControlledFolderAccess -eq 1) { Add 'Defender' 'Ransomware protection (CFA)' 'pass' 'Enforced' } else { Add 'Defender' 'Ransomware protection (CFA)' 'warn' 'Off' 'cfa' }
    }

    # ---- Firewall ----
    try {
        $fw = Get-NetFirewallProfile -ErrorAction Stop
        $off = @($fw | Where-Object { -not $_.Enabled })
        if ($off.Count -eq 0) { Add 'Firewall' 'Firewall enabled (all profiles)' 'pass' 'On' } else { Add 'Firewall' 'Firewall enabled (all profiles)' 'fail' (($off.Name) -join ', ' + ' off') 'firewall-on' }
        $weak = @($fw | Where-Object { $_.DefaultInboundAction -ne 'Block' })
        if ($weak.Count -eq 0) { Add 'Firewall' 'Inbound traffic blocked by default' 'pass' 'Block' } else { Add 'Firewall' 'Inbound traffic blocked by default' 'warn' 'Not blocked' 'firewall-block' }
    } catch { Add 'Firewall' 'Firewall status' 'warn' 'Could not read' }

    # ---- OS hardening / boot ----
    try {
        if ((Get-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'EnableLUA' 1) -eq 1) { Add 'Windows' 'User Account Control (UAC)' 'pass' 'On' } else { Add 'Windows' 'User Account Control (UAC)' 'fail' 'Disabled' }
        $cpa = Get-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'ConsentPromptBehaviorAdmin' 5
        if ($cpa -in 0,1,5) { Add 'Windows' 'UAC prompt level' 'warn' 'Allows silent elevation (weak)' } else { Add 'Windows' 'UAC prompt level' 'pass' 'Prompts on elevation' }
    } catch {}
    try {
        $sb = Confirm-SecureBootUEFI -ErrorAction Stop
        if ($sb) { Add 'Boot' 'Secure Boot' 'pass' 'Enabled' } else { Add 'Boot' 'Secure Boot' 'warn' 'Disabled' }
    } catch { Add 'Boot' 'Secure Boot' 'info' 'Legacy BIOS or not supported' }
    try {
        $tpm = Get-Tpm -ErrorAction Stop
        if ($tpm.TpmPresent -and $tpm.TpmReady) { Add 'Boot' 'TPM' 'pass' 'Present and ready' }
        elseif ($tpm.TpmPresent) { Add 'Boot' 'TPM' 'warn' 'Present but not ready' }
        else { Add 'Boot' 'TPM' 'warn' 'Not present' }
    } catch { Add 'Boot' 'TPM' 'info' 'Not available' }
    try {
        $bl = Get-BitLockerVolume -MountPoint "$env:SystemDrive" -ErrorAction Stop
        if ($bl.ProtectionStatus -eq 'On') { Add 'Boot' 'Drive encryption (BitLocker)' 'pass' 'On' } else { Add 'Boot' 'Drive encryption (BitLocker)' 'warn' 'Off' }
    } catch { Add 'Boot' 'Drive encryption (BitLocker)' 'info' 'Not available (Home edition?)' }

    # ---- Core isolation / credential protection ----
    try {
        $dg = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction Stop
        if (@($dg.SecurityServicesRunning) -contains 2) { Add 'Kernel' 'Memory integrity (HVCI)' 'pass' 'Running' } else { Add 'Kernel' 'Memory integrity (HVCI)' 'warn' 'Not running' 'mem-integrity' }
        if (@($dg.SecurityServicesRunning) -contains 1) { Add 'Kernel' 'Credential Guard' 'pass' 'Running' } else { Add 'Kernel' 'Credential Guard' 'info' 'Not running (needs compatible hardware/edition)' }
    } catch { Add 'Kernel' 'Core isolation' 'info' 'Not supported on this device' }
    if ((Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RunAsPPL' 0) -eq 1) { Add 'Kernel' 'LSA protection' 'pass' 'Enabled' } else { Add 'Kernel' 'LSA protection' 'warn' 'Disabled' 'lsa-ppl' }
    if ((Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest' 'UseLogonCredential' 1) -eq 0) { Add 'Credentials' 'Plaintext passwords (WDigest)' 'pass' 'Disabled' } else { Add 'Credentials' 'Plaintext passwords (WDigest)' 'fail' 'Enabled' 'wdigest-off' }
    if ((Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'NoLMHash' 0) -eq 1) { Add 'Credentials' 'LM hash storage' 'pass' 'Disabled' } else { Add 'Credentials' 'LM hash storage' 'warn' 'Enabled' 'nolmhash' }
    try { if ((Get-LocalUser -Name 'Guest' -ErrorAction Stop).Enabled) { Add 'Credentials' 'Guest account' 'warn' 'Enabled' 'guest-off' } else { Add 'Credentials' 'Guest account' 'pass' 'Disabled' } } catch {}
    try {
        $ap = Get-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' 'DefaultPassword' ''
        if ($ap) { Add 'Credentials' 'Autologon password' 'warn' 'Plaintext password stored' } else { Add 'Credentials' 'Autologon password' 'pass' 'Not stored' }
    } catch {}

    # ---- Network attack surface ----
    try {
        $smb = Get-SmbServerConfiguration -ErrorAction Stop
        if (-not $smb.EnableSMB1Protocol) { Add 'Network' 'SMBv1 protocol' 'pass' 'Disabled' } else { Add 'Network' 'SMBv1 protocol' 'fail' 'Enabled' 'smbv1-off' }
        if ($smb.RequireSecuritySignature) { Add 'Network' 'SMB signing (server)' 'pass' 'Required' } else { Add 'Network' 'SMB signing (server)' 'warn' 'Not required' 'smb-sign' }
    } catch {}
    try { $sc = Get-SmbClientConfiguration -ErrorAction Stop
        if (-not $sc.EnableInsecureGuestLogons) { Add 'Network' 'Insecure guest logons' 'pass' 'Blocked' } else { Add 'Network' 'Insecure guest logons' 'warn' 'Allowed' 'smb-guest' }
    } catch {}
    if ((Get-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' 'EnableMulticast' 1) -eq 0) { Add 'Network' 'LLMNR' 'pass' 'Disabled' } else { Add 'Network' 'LLMNR' 'warn' 'Enabled' 'llmnr-off' }
    try {
        $nb = @((Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True' -ErrorAction SilentlyContinue).TcpipNetbiosOptions)
        if ($nb.Count -gt 0 -and @($nb | Where-Object { $_ -ne 2 }).Count -eq 0) { Add 'Network' 'NetBIOS over TCP/IP' 'pass' 'Disabled' } else { Add 'Network' 'NetBIOS over TCP/IP' 'warn' 'Enabled' 'netbios-off' }
    } catch {}
    if ((Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections' 1) -eq 1) { Add 'Network' 'Remote Desktop (RDP)' 'pass' 'Disabled' } else { Add 'Network' 'Remote Desktop (RDP)' 'warn' 'Enabled' 'rdp-off' }
    if ((Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance' 'fAllowToGetHelp' 1) -eq 0) { Add 'Network' 'Remote Assistance' 'pass' 'Disabled' } else { Add 'Network' 'Remote Assistance' 'warn' 'Enabled' 'remote-assist' }

    # ---- Exploit / scripting surface ----
    if ((Get-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'NoDriveTypeAutoRun' 0) -eq 255) { Add 'Malware' 'AutoRun/AutoPlay' 'pass' 'Disabled' } else { Add 'Malware' 'AutoRun/AutoPlay' 'warn' 'Enabled' 'autorun-off' }
    if ((Get-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'HideFileExt' 1) -eq 0) { Add 'Malware' 'File extensions visible' 'pass' 'Shown' } else { Add 'Malware' 'File extensions visible' 'warn' 'Hidden' 'file-ext' }
    if ((Get-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableSmartScreen' 1) -eq 1) { Add 'Malware' 'SmartScreen' 'pass' 'On' } else { Add 'Malware' 'SmartScreen' 'warn' 'Off' 'smartscreen' }
    if ((Get-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows Script Host\Settings' 'Enabled' 1) -eq 0) { Add 'Malware' 'Windows Script Host' 'pass' 'Disabled' } else { Add 'Malware' 'Windows Script Host' 'info' 'Enabled (common malware vector)' 'wsh-off' }
    try {
        $psv2 = Get-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2 -ErrorAction Stop
        if ($psv2.State -ne 'Enabled') { Add 'Malware' 'PowerShell 2.0 engine' 'pass' 'Removed' } else { Add 'Malware' 'PowerShell 2.0 engine' 'warn' 'Installed' 'psv2-off' }
    } catch {}

    # ---- Privacy / update ----
    if ((Get-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 3) -eq 0) { Add 'Privacy' 'Diagnostic data' 'pass' 'Minimal' } else { Add 'Privacy' 'Diagnostic data' 'warn' 'Not minimized' 'telemetry' }
    if ((Get-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 0) -eq 1) { Add 'Privacy' 'Windows Recall' 'pass' 'Disabled' } else { Add 'Privacy' 'Windows Recall' 'info' 'Enabled or not present' 'recall-off' }
    try {
        if ((Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Services\wuauserv' 'Start' 3) -eq 4) { Add 'Updates' 'Windows Update service' 'fail' 'Disabled' } else { Add 'Updates' 'Windows Update service' 'pass' 'Enabled' }
    } catch {}

    return $r
}

function Get-AuditScore {
    param($Items)
    $scored = @($Items | Where-Object { $_.Status -ne 'info' })
    if ($scored.Count -eq 0) { return 0 }
    $pass = @($scored | Where-Object { $_.Status -eq 'pass' }).Count
    return [int][math]::Round(100 * $pass / $scored.Count)
}

function Get-AuditGrade([int]$Score) {
    switch ($true) {
        ($Score -ge 90) { 'A'; break }
        ($Score -ge 80) { 'B'; break }
        ($Score -ge 70) { 'C'; break }
        ($Score -ge 60) { 'D'; break }
        default         { 'F' }
    }
}
