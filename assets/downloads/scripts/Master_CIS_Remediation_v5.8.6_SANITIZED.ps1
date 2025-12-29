# Master_CIS_Remediation_v5.8.6 (SANITIZED)
# NOTE: This public version has been sanitized to remove organization-specific hostnames (e.g., NTP/Syslog endpoints).

# Enforces CIS-aligned ESXi host settings across selected vCenters (Windows PowerShell 5.1 + PowerCLI).
# Menus/credential UX are IDENTICAL to your Audit v5.8 flow.
# Supports:
#   -AuditOnly          (dry-run; no changes; logs SKIPPED)
#   -Backout            (restore from a backup CSV)
#   -BackoutCsv <path>  (optional; if omitted you'll be prompted)
#
# Output CSVs in C:\Temp:
#   - Remediation run: Master_CIS_Remediation_<timestamp>.csv
#   - Backups for backout: Master_CIS_Backup_<timestamp>.csv
#   - Backout results: Master_CIS_Backout_<timestamp>.csv
#
#=========================
# REQUIRED: PowerShell 5.1
#=========================
#requires -Version 5.1

$ErrorActionPreference = 'Stop'

# --------------------------
# Mode switches (no param{} block)
# --------------------------
$AuditOnly = ($args -contains '-AuditOnly')
$Backout   = ($args -contains '-Backout')
$BackoutCsvPath = $null
for ($i=0; $i -lt $args.Count; $i++) {
    if ($args[$i] -ieq '-BackoutCsv' -and ($i + 1) -lt $args.Count) {
        $BackoutCsvPath = $args[$i+1]
    }
}

# --------------------------
# Remediation Target Values
# --------------------------
$Target_NtpServers               = @('ntp1.example.com','ntp2.example.com','ntp3.example.com','ntp4.example.com')
$Target_RemoteLogHost            = 'udp://syslog.example.com:514'
$Target_LogDatastorePath         = '[datastore1]/scratch/log'
$Target_SshBannerText            = @'
WARNING: This system is for authorized use only. All activities may be monitored and recorded.
By accessing this system, you consent to such monitoring. Unauthorized use is prohibited.
'@
$Target_AccountLockFailures      = 5
$Target_PasswordQualityControl   = 'similar=deny retry=5 passphrase=0 min=disabled,disabled,disabled,disabled,14'
$Target_DvFilterBindIpAddress    = ''   # $null = skip, '' = clear, 'x.x.x.x' = set

# --------------------------
# Module Handling
# --------------------------
function Ensure-Module {
    param([Parameter(Mandatory=$true)][string]$Name)
    if (-not (Get-Module -ListAvailable -Name $Name)) {
        Write-Host ("Installing module {0} for CurrentUser..." -f $Name)
        try { Install-Module -Name $Name -Scope CurrentUser -AllowClobber -Force } catch { }
    }
    if (-not (Get-Module -Name $Name)) {
        Import-Module -Name $Name -ErrorAction Stop
    }
}

# --------------------------
# Helpers (unchanged UX)
# --------------------------
function Nz { param([object]$v,[object]$default=''); if ($null -eq $v -or ($v -is [string] -and $v.Trim() -eq '')) { return $default } else { return $v } }

function Get-CredFolder { Join-Path $env:USERPROFILE 'Documents\vcentercreds' }

function New-VCenterCredentialFile {
    param([Parameter(Mandatory=$true)][string]$VCenterFqdn)
    $fq = $VCenterFqdn.Trim().ToLower()
    $dir = Get-CredFolder
    if (-not (Test-Path -LiteralPath $dir)) { [void](New-Item -ItemType Directory -Path $dir) }
    $dest = Join-Path $dir ($fq + '.xml')
    $cred = Get-Credential -Message ("Enter credentials for {0}" -f $fq)
    $cred | Export-Clixml -Path $dest
    Write-Host ("Saved: {0}" -f $dest) -ForegroundColor Green
}

function Get-CredForVCenter {
    param([Parameter(Mandatory=$true)][string]$VCenterFqdn)
    $fq = $VCenterFqdn.Trim().ToLower()
    $path = Join-Path (Get-CredFolder) ($fq + '.xml')
    if (Test-Path $path) { return Import-Clixml -Path $path } else { return $null }
}

function Create-Creds-Workflow {
    Write-Host ""
    Write-Host "== Create vCenter credential files ==" -ForegroundColor Cyan
    while ($true) {
        $fq = Read-Host "Enter vCenter FQDN (or just Enter to finish)"
        if ([string]::IsNullOrWhiteSpace($fq)) { break }
        try { New-VCenterCredentialFile -VCenterFqdn $fq } catch { Write-Warning $_.Exception.Message }
    }
}

function Select-VCentersFromCredStore {
    $files = Get-ChildItem -Path (Get-CredFolder) -Filter '*.xml' -File | Sort-Object Name
    if (-not $files) { Write-Warning "No vCenter credential files found in $(Get-CredFolder)." }
    Write-Host ""
    Write-Host "== Select vCenters ==" -ForegroundColor Cyan
    $i = 1
    foreach ($f in $files) {
        $name = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
        Write-Host ("[{0}] {1}" -f $i, $name)
        $i++
    }
    Write-Host "[M] Manually enter FQDN (not saved)"
    Write-Host "[A] All above"
    $sel = Read-Host "Choose numbers separated by comma, or M/A"
    if ($sel -match '^[mM]$') {
        $fq = Read-Host "Enter vCenter FQDN to connect (temp, not saved)"
        return ,@($fq.Trim().ToLower())
    }
    if ($sel -match '^[aA]$') {
        return $files | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) }
    }
    $list = @()
    foreach ($p in $sel -split '[, ]+') {
        if ($p -match '^\d+$') {
            $idx = [int]$p
            if ($idx -ge 1 -and $idx -le $files.Count) {
                $list += [System.IO.Path]::GetFileNameWithoutExtension($files[$idx-1].Name)
            }
        }
    }
    return ,$list
}

# CSV sinks
$Results  = New-Object System.Collections.ArrayList
$Backups  = New-Object System.Collections.ArrayList

function Write-Row {
    param([string]$VCenter,[string]$Hostname,[string]$Check,[string]$Status,[string]$Details)
    $obj = [pscustomobject]@{
        Timestamp = (Get-Date).ToString('s')
        VCenter   = Nz $VCenter
        Hostname  = Nz $Hostname
        Check     = Nz $Check
        Status    = Nz $Status
        Details   = Nz $Details
    }
    $Results.Add($obj) | Out-Null
}

function Write-BackupRow {
    param([string]$VCenter,[string]$Hostname,[string]$Setting,[string]$OldValue,[string]$NewValue,[string]$Note='enforced by v5.8.6')
    if ($AuditOnly) { return }
    $obj = [pscustomobject]@{
        Timestamp = (Get-Date).ToString('s')
        VCenter   = Nz $VCenter
        Hostname  = Nz $Hostname
        Setting   = Nz $Setting
        OldValue  = Nz $OldValue
        NewValue  = Nz $NewValue
        Note      = Nz $Note
    }
    $Backups.Add($obj) | Out-Null
}

# Change wrapper (respects dry-run)
function Invoke-Change {
    param([scriptblock]$Do, [string]$What, [string]$VCenter, [string]$HostName, [string]$CheckName)
    if ($AuditOnly) {
        Write-Row $VCenter $HostName $CheckName 'SKIPPED' ("AuditOnly: {0}" -f $What)
    } else {
        & $Do
    }
}

# Small utils
function Normalize-PQC {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $t = $Text.Trim().ToLower()
    while ($t -match '\s{2,}') { $t = $t -replace '\s{2,}',' ' }
    $t = $t.TrimEnd('.',';')
    return $t
}
function Get-ServiceRecord { param($VMHost,[string]$Key) (Get-VMHostService -VMHost $VMHost | Where-Object { $_.Key -eq $Key }) }


# iSCSI Mutual CHAP helper (credentials prompt; only used if CHAP check is selected)
$script:IscsiChapSecrets = $null
function Get-IscsiChapSecrets {
    if ($script:IscsiChapSecrets) { return $script:IscsiChapSecrets }
    Write-Host ""
    Write-Host "== iSCSI Mutual CHAP credentials (may require reboot) ==" -ForegroundColor Yellow
    $chapName = Read-Host "Outgoing CHAP name (host -> target)"
    $chapPassword = Read-Host "Outgoing CHAP secret"
    $mutualChapName = Read-Host "Mutual CHAP name (target -> host)"
    $mutualChapPassword = Read-Host "Mutual CHAP secret"
    $script:IscsiChapSecrets = [pscustomobject]@{
        ChapName           = $chapName
        ChapPassword       = $chapPassword
        MutualChapName     = $mutualChapName
        MutualChapPassword = $mutualChapPassword
    }
    return $script:IscsiChapSecrets
}

# --------------------------
# Menu (unchanged layout)
# --------------------------
$checkNames = @(
'Mem.ShareForceSalting',
'ESXi Shell (TSM)',
'SSH (TSM-SSH)',
'NTP & ntpd',
'SNMP',
'Persistent logging',
'Remote logging',
'SSH Connection Banner',
'SLP service (slpd)',
'SSH service policy Manual',
'Account lockout failures',
'DVFilter Bind IP',
'Password Complexity',
'Managed Object Browser (MOB)',
'Hyperthreading warning',
'iSCSI Mutual CHAP (may require reboot)'
)


# --------------------------
# Checks (remediation + backups + dry-run)
# --------------------------
$Checks = [ordered]@{}

# 1) Mem.ShareForceSalting -> enforce '2'
$Checks['Mem.ShareForceSalting'] = {
    param($VMHost,$VCenter)
    $name = 'Mem.ShareForceSalting'
    try {
        $adv = Get-AdvancedSetting -Entity $VMHost -Name $name -ErrorAction SilentlyContinue
        $val = if ($adv) { [string]$adv.Value } else { '' }
        if ($val -eq '2') {
            Write-Row $VCenter $VMHost.Name $name 'Pass' 'Value=2'
        } else {
            $old = Nz $val,''
            if ($adv) { Invoke-Change { Set-AdvancedSetting -AdvancedSetting $adv -Value '2' -Confirm:$false | Out-Null } "Set $name to 2" $VCenter $VMHost.Name $name }
            else      { Invoke-Change { New-AdvancedSetting -Entity $VMHost -Name $name -Value '2' -Confirm:$false | Out-Null } "Create $name=2" $VCenter $VMHost.Name $name }
            Write-BackupRow $VCenter $VMHost.Name $name $old '2'
            Write-Row       $VCenter $VMHost.Name $name ($(if($AuditOnly){'SKIPPED-CHANGE'}else{'Changed'})) ("Old='{0}' -> New='2'" -f (Nz $old,'(empty)'))
        }
    } catch { Write-Row $VCenter $VMHost.Name $name 'Error' $_.Exception.Message }
}

# 2) ESXi Shell (TSM) -> stop & policy off
$Checks['ESXi Shell (TSM)'] = {
    param($VMHost,$VCenter)
    $name = 'ESXi Shell (TSM)'
    try {
        $svc = Get-ServiceRecord -VMHost $VMHost -Key 'TSM'
        if (-not $svc) { Write-Row $VCenter $VMHost.Name $name 'Info' 'Service not present'; return }
        $oldState = if ($svc.Running) {'running'} else {'stopped'}
        $oldPol   = $svc.Policy
        $stateOk = -not $svc.Running
        $policyOk = ($svc.Policy -eq 'off')
        if ($stateOk -and $policyOk) {
            Write-Row $VCenter $VMHost.Name $name 'Pass' 'Stopped, Policy=off'
        } else {
            if ($svc.Running) { Invoke-Change { Stop-VMHostService -HostService $svc -Confirm:$false | Out-Null } "Stop TSM" $VCenter $VMHost.Name $name }
            if ($svc.Policy -ne 'off') { Invoke-Change { Set-VMHostService -HostService $svc -Policy 'off' -Confirm:$false | Out-Null } "Set TSM policy=off" $VCenter $VMHost.Name $name }
            Write-BackupRow $VCenter $VMHost.Name 'Service:TSM.State'  $oldState 'stopped'
            Write-BackupRow $VCenter $VMHost.Name 'Service:TSM.Policy' $oldPol   'off'
            Write-Row $VCenter $VMHost.Name $name ($(if($AuditOnly){'SKIPPED-CHANGE'}else{'Changed'})) 'Stopped and Policy=off'
        }
    } catch { Write-Row $VCenter $VMHost.Name $name 'Error' $_.Exception.Message }
}

# 3) SSH (TSM-SSH) -> stop & policy off
$Checks['SSH (TSM-SSH)'] = {
    param($VMHost,$VCenter)
    $name = 'SSH (TSM-SSH)'
    try {
        $svc = Get-ServiceRecord -VMHost $VMHost -Key 'TSM-SSH'
        if (-not $svc) { Write-Row $VCenter $VMHost.Name $name 'Info' 'Service not present'; return }
        $oldState = if ($svc.Running) {'running'} else {'stopped'}
        $oldPol   = $svc.Policy
        $stateOk = -not $svc.Running
        $policyOk = ($svc.Policy -eq 'off')
        if ($stateOk -and $policyOk) {
            Write-Row $VCenter $VMHost.Name $name 'Pass' 'Stopped, Policy=off'
        } else {
            if ($svc.Running) { Invoke-Change { Stop-VMHostService -HostService $svc -Confirm:$false | Out-Null } "Stop TSM-SSH" $VCenter $VMHost.Name $name }
            if ($svc.Policy -ne 'off') { Invoke-Change { Set-VMHostService -HostService $svc -Policy 'off' -Confirm:$false | Out-Null } "Set TSM-SSH policy=off" $VCenter $VMHost.Name $name }
            Write-BackupRow $VCenter $VMHost.Name 'Service:TSM-SSH.State'  $oldState 'stopped'
            Write-BackupRow $VCenter $VMHost.Name 'Service:TSM-SSH.Policy' $oldPol   'off'
            Write-Row $VCenter $VMHost.Name $name ($(if($AuditOnly){'SKIPPED-CHANGE'}else{'Changed'})) 'Stopped and Policy=off'
        }
    } catch { Write-Row $VCenter $VMHost.Name $name 'Error' $_.Exception.Message }
}

# 4) NTP & ntpd -> enforce servers; start service; policy on
$Checks['NTP & ntpd'] = {
    param($VMHost,$VCenter)
    $name = 'NTP & ntpd'
    try {
        $current = @()
        try { $current = (Get-VMHostNtpServer -VMHost $VMHost -ErrorAction Stop) } catch { $current = @() }
        $svc = Get-ServiceRecord -VMHost $VMHost -Key 'ntpd'
        $hasExact = ($current.Count -eq $Target_NtpServers.Count -and @($current | Where-Object { $_ -in $Target_NtpServers }).Count -eq $Target_NtpServers.Count)
        $runningOk = ($svc -and $svc.Running)
        $policyOk  = ($svc -and $svc.Policy -eq 'on')
        if ($hasExact -and $runningOk -and $policyOk) {
            Write-Row $VCenter $VMHost.Name $name 'Pass' ("Servers={0}; State=running; Policy=on" -f ($current -join ','))
        } else {
            $oldList = ($current -join ',')
            $toRemove = @($current | Where-Object { $_ -notin $Target_NtpServers })
            $toAdd    = @($Target_NtpServers | Where-Object { $_ -notin $current })
            if ($toRemove.Count -gt 0) { Invoke-Change { Remove-VMHostNtpServer -VMHost $VMHost -NtpServer $toRemove -Confirm:$false | Out-Null } ("Remove NTP: " + ($toRemove -join ',')) $VCenter $VMHost.Name $name }
            if ($toAdd.Count -gt 0)    { Invoke-Change { Add-VMHostNtpServer    -VMHost $VMHost -NtpServer $toAdd    -Confirm:$false | Out-Null } ("Add NTP: "    + ($toAdd -join ','))    $VCenter $VMHost.Name $name }
            $svc = Get-ServiceRecord -VMHost $VMHost -Key 'ntpd'
            $preStateTxt = if ($svc -and $svc.Running) {'running'} else {'stopped'}
            $prePolicy   = if ($svc) {$svc.Policy} else {''}
            if ($svc) {
                if (-not $svc.Running) { Invoke-Change { Start-VMHostService -HostService $svc -Confirm:$false | Out-Null } "Start ntpd" $VCenter $VMHost.Name $name }
                if ($svc.Policy -ne 'on') { Invoke-Change { Set-VMHostService -HostService $svc -Policy 'on' -Confirm:$false | Out-Null } "Set ntpd policy=on" $VCenter $VMHost.Name $name }
            }
            Write-BackupRow $VCenter $VMHost.Name 'NTP.Servers'         $oldList ($Target_NtpServers -join ',')
            Write-BackupRow $VCenter $VMHost.Name 'Service:ntpd.State'  $preStateTxt 'running'
            Write-BackupRow $VCenter $VMHost.Name 'Service:ntpd.Policy' $prePolicy   'on'
            Write-Row $VCenter $VMHost.Name $name ($(if($AuditOnly){'SKIPPED-CHANGE'}else{'Changed'})) ("Servers set to [{0}], ntpd running, Policy=on" -f ($Target_NtpServers -join ','))
        }
    } catch { Write-Row $VCenter $VMHost.Name $name 'Error' $_.Exception.Message }
}

# 5) SNMP -> stop & policy off
$Checks['SNMP'] = {
    param($VMHost,$VCenter)
    $name = 'SNMP'
    try {
        $svc = Get-ServiceRecord -VMHost $VMHost -Key 'snmpd'
        if (-not $svc) { Write-Row $VCenter $VMHost.Name $name 'Info' 'Service not present'; return }
        $oldState = if ($svc.Running) {'running'} else {'stopped'}
        $oldPol   = $svc.Policy
        if (-not $svc.Running -and $svc.Policy -eq 'off') {
            Write-Row $VCenter $VMHost.Name $name 'Pass' 'Stopped, Policy=off'
        } else {
            if ($svc.Running) { Invoke-Change { Stop-VMHostService -HostService $svc -Confirm:$false | Out-Null } "Stop snmpd" $VCenter $VMHost.Name $name }
            if ($svc.Policy -ne 'off') { Invoke-Change { Set-VMHostService -HostService $svc -Policy 'off' -Confirm:$false | Out-Null } "Set snmpd policy=off" $VCenter $VMHost.Name $name }
            Write-BackupRow $VCenter $VMHost.Name 'Service:snmpd.State'  $oldState 'stopped'
            Write-BackupRow $VCenter $VMHost.Name 'Service:snmpd.Policy' $oldPol   'off'
            Write-Row $VCenter $VMHost.Name $name ($(if($AuditOnly){'SKIPPED-CHANGE'}else{'Changed'})) 'Stopped and Policy=off'
        }
    } catch { Write-Row $VCenter $VMHost.Name $name 'Error' $_.Exception.Message }
}

# 6) Persistent logging -> set Syslog.global.logDir if neither scratch nor logDir persistent
$Checks['Persistent logging'] = {
    param($VMHost,$VCenter)
    $name = 'Persistent logging'
    try {
        $scratch = (Get-VMHost -Id $VMHost.Id).ExtensionData.Config.ScratchConfig.ConfiguredScratchLocation
        $logDirAdv = Get-AdvancedSetting -Entity $VMHost -Name 'Syslog.global.logDir' -ErrorAction SilentlyContinue
        $logDir = if ($logDirAdv) { [string]$logDirAdv.Value } else { '' }
        $isScratchPersistent = ($scratch -like '[*') -or ($scratch -like '/vmfs/volumes/*')
        $isLogDirPersistent  = ($logDir  -like '[*') -or ($logDir  -like '/vmfs/volumes/*')
        if ($isScratchPersistent -or $isLogDirPersistent) {
            Write-Row $VCenter $VMHost.Name $name 'Pass' ("Scratch='{0}', logDir='{1}'" -f (Nz $scratch,'(empty)'), (Nz $logDir,'(empty)'))
        } else {
            if (-not [string]::IsNullOrWhiteSpace($Target_LogDatastorePath)) {
                $old = $logDir
                if ($logDirAdv) { Invoke-Change { Set-AdvancedSetting -AdvancedSetting $logDirAdv -Value $Target_LogDatastorePath -Confirm:$false | Out-Null } "Set Syslog.global.logDir" $VCenter $VMHost.Name $name }
                else            { Invoke-Change { New-AdvancedSetting -Entity $VMHost -Name 'Syslog.global.logDir' -Value $Target_LogDatastorePath -Confirm:$false | Out-Null } "Create Syslog.global.logDir" $VCenter $VMHost.Name $name }
                Write-BackupRow $VCenter $VMHost.Name 'Syslog.global.logDir' $old $Target_LogDatastorePath
                Write-Row $VCenter $VMHost.Name $name ($(if($AuditOnly){'SKIPPED-CHANGE'}else{'Changed'})) ("Syslog.global.logDir '{0}' -> '{1}'" -f (Nz $old,'(empty)'), $Target_LogDatastorePath)
            } else {
                Write-Row $VCenter $VMHost.Name $name 'Warn' ("Non-persistent and no target path provided | Scratch='{0}', logDir='{1}'" -f (Nz $scratch,'(empty)'), (Nz $logDir,'(empty)'))
            }
        }
    } catch { Write-Row $VCenter $VMHost.Name $name 'Error' $_.Exception.Message }
}

# 7) Remote logging -> set logHost, ensure vmsyslogd running & policy on
$Checks['Remote logging'] = {
    param($VMHost,$VCenter)
    $name = 'Remote logging'
    try {
        $logHostAdv = Get-AdvancedSetting -Entity $VMHost -Name 'Syslog.global.logHost' -ErrorAction SilentlyContinue
        $logHost    = if ($logHostAdv) { [string]$logHostAdv.Value } else { '' }
        $svc = Get-ServiceRecord -VMHost $VMHost -Key 'vmsyslogd'
        $ok = (-not [string]::IsNullOrWhiteSpace($logHost)) -and $svc -and $svc.Running -and $svc.Policy -eq 'on'
        $preStateTxt = if ($svc -and $svc.Running) {'running'} else {'stopped'}
        $prePolicy   = if ($svc) {$svc.Policy} else {''}
        if ($ok -and ($logHost -eq $Target_RemoteLogHost)) {
            Write-Row $VCenter $VMHost.Name $name 'Pass' ("logHost='{0}', State=running, Policy=on" -f $logHost)
        } else {
            $old = $logHost
            if (-not [string]::IsNullOrWhiteSpace($Target_RemoteLogHost)) {
                if     ($logHostAdv) { Invoke-Change { Set-AdvancedSetting -AdvancedSetting $logHostAdv -Value $Target_RemoteLogHost -Confirm:$false | Out-Null } "Set logHost" $VCenter $VMHost.Name $name }
                else                 { Invoke-Change { New-AdvancedSetting -Entity $VMHost -Name 'Syslog.global.logHost' -Value $Target_RemoteLogHost -Confirm:$false | Out-Null } "Create logHost" $VCenter $VMHost.Name $name }
            }
            $svc = Get-ServiceRecord -VMHost $VMHost -Key 'vmsyslogd'
            if ($svc) {
                if (-not $svc.Running) { Invoke-Change { Start-VMHostService -HostService $svc -Confirm:$false | Out-Null } "Start vmsyslogd" $VCenter $VMHost.Name $name }
                if ($svc.Policy -ne 'on') { Invoke-Change { Set-VMHostService -HostService $svc -Policy 'on' -Confirm:$false | Out-Null } "Set vmsyslogd policy=on" $VCenter $VMHost.Name $name }
            }
            Write-BackupRow $VCenter $VMHost.Name 'Syslog.global.logHost' $old $Target_RemoteLogHost
            Write-BackupRow $VCenter $VMHost.Name 'Service:vmsyslogd.State'  $preStateTxt 'running'
            Write-BackupRow $VCenter $VMHost.Name 'Service:vmsyslogd.Policy' $prePolicy   'on'
            Write-Row $VCenter $VMHost.Name $name ($(if($AuditOnly){'SKIPPED-CHANGE'}else{'Changed'})) ("logHost '{0}' -> '{1}', syslog started, Policy=on" -f (Nz $old,'(empty)'), $Target_RemoteLogHost)
        }
    } catch { Write-Row $VCenter $VMHost.Name $name 'Error' $_.Exception.Message }
}

# 8) SSH Connection Banner -> enforce banner text
$Checks['SSH Connection Banner'] = {
    param($VMHost,$VCenter)
    $name='SSH Connection Banner'
    try {
        $adv = Get-AdvancedSetting -Entity $VMHost -Name 'Config.Etc.issue' -ErrorAction SilentlyContinue
        $val = if ($adv) { [string]$adv.Value } else { '' }
        $target = $Target_SshBannerText
        $need = ([string]::IsNullOrWhiteSpace($val) -or $val -ne $target)
        if (-not $need) {
            Write-Row $VCenter $VMHost.Name $name 'Pass' 'Banner configured'
        } else {
            $old = Nz $val,''
            if ($adv) { Invoke-Change { Set-AdvancedSetting -AdvancedSetting $adv -Value $target -Confirm:$false | Out-Null } "Set banner" $VCenter $VMHost.Name $name }
            else      { Invoke-Change { New-AdvancedSetting -Entity $VMHost -Name 'Config.Etc.issue' -Value $target -Confirm:$false | Out-Null } "Create banner" $VCenter $VMHost.Name $name }
            Write-BackupRow $VCenter $VMHost.Name 'SSH Banner' $old $target
            Write-Row $VCenter $VMHost.Name $name ($(if($AuditOnly){'SKIPPED-CHANGE'}else{'Changed'})) ("Banner set | Old len={0}, New len={1}" -f ($old.ToString().Length), ($target.ToString().Length))
        }
    } catch { Write-Row $VCenter $VMHost.Name $name 'Error' $_.Exception.Message }
}

# 9) SLP service (slpd) -> stop & policy off
$Checks['SLP service (slpd)'] = {
    param($VMHost,$VCenter)
    $name='SLP service (slpd)'
    try {
        $svc = Get-ServiceRecord -VMHost $VMHost -Key 'slpd'
        if (-not $svc) { Write-Row $VCenter $VMHost.Name $name 'Info' 'Service not present'; return }
        $oldState = if ($svc.Running) {'running'} else {'stopped'}
        $oldPol   = $svc.Policy
        $ok = (-not $svc.Running) -and ($svc.Policy -ne 'on')
        if ($ok) {
            Write-Row $VCenter $VMHost.Name $name 'Pass' ("Stopped, Policy={0}" -f $svc.Policy)
        } else {
            if ($svc.Running) { Invoke-Change { Stop-VMHostService -HostService $svc -Confirm:$false | Out-Null } "Stop slpd" $VCenter $VMHost.Name $name }
            if ($svc.Policy -ne 'off') { Invoke-Change { Set-VMHostService -HostService $svc -Policy 'off' -Confirm:$false | Out-Null } "Set slpd policy=off" $VCenter $VMHost.Name $name }
            Write-BackupRow $VCenter $VMHost.Name 'Service:slpd.State'  $oldState 'stopped'
            Write-BackupRow $VCenter $VMHost.Name 'Service:slpd.Policy' $oldPol   'off'
            Write-Row $VCenter $VMHost.Name $name ($(if($AuditOnly){'SKIPPED-CHANGE'}else{'Changed'})) 'Stopped and Policy=off'
        }
    } catch { Write-Row $VCenter $VMHost.Name $name 'Error' $_.Exception.Message }
}

# 10) SSH service policy Manual -> policy off
$Checks['SSH service policy Manual'] = {
    param($VMHost,$VCenter)
    $name='SSH service policy Manual'
    try {
        $svc = Get-ServiceRecord -VMHost $VMHost -Key 'TSM-SSH'
        if (-not $svc) { Write-Row $VCenter $VMHost.Name $name 'Info' 'Service not present'; return }
        $oldPol = $svc.Policy
        if ($svc.Policy -eq 'off') {
            Write-Row $VCenter $VMHost.Name $name 'Pass' 'Policy=off'
        } else {
            Invoke-Change { Set-VMHostService -HostService $svc -Policy 'off' -Confirm:$false | Out-Null } "Set TSM-SSH policy=off" $VCenter $VMHost.Name $name
            Write-BackupRow $VCenter $VMHost.Name 'Service:TSM-SSH.Policy' $oldPol 'off'
            Write-Row $VCenter $VMHost.Name $name ($(if($AuditOnly){'SKIPPED-CHANGE'}else{'Changed'})) 'Policy set to off'
        }
    } catch { Write-Row $VCenter $VMHost.Name $name 'Error' $_.Exception.Message }
}

# 11) Account lockout failures -> enforce if target specified
$Checks['Account lockout failures'] = {
    param($VMHost,$VCenter)
    $name='Account lockout failures'
    try {
        $adv = Get-AdvancedSetting -Entity $VMHost -Name 'Security.AccountLockFailures' -ErrorAction SilentlyContinue
        $val = if ($adv) { [string]$adv.Value } else { '' }
        if ($null -ne $Target_AccountLockFailures) {
            $desired = [string]$Target_AccountLockFailures
            if ($val -ne $desired) {
                if ($adv) { Invoke-Change { Set-AdvancedSetting -AdvancedSetting $adv -Value $desired -Confirm:$false | Out-Null } "Set AccountLockFailures=$desired" $VCenter $VMHost.Name $name }
                else      { Invoke-Change { New-AdvancedSetting -Entity $VMHost -Name 'Security.AccountLockFailures' -Value $desired -Confirm:$false | Out-Null } "Create AccountLockFailures=$desired" $VCenter $VMHost.Name $name }
                Write-BackupRow $VCenter $VMHost.Name 'Security.AccountLockFailures' $val $desired
                Write-Row $VCenter $VMHost.Name $name ($(if($AuditOnly){'SKIPPED-CHANGE'}else{'Changed'})) ("Old='{0}' -> New='{1}'" -f (Nz $val,'(empty)'), $desired)
            } else {
                Write-Row $VCenter $VMHost.Name $name 'Pass' ("Value={0}" -f $desired)
            }
        } else {
            Write-Row $VCenter $VMHost.Name $name 'Info' ("Current={0}; No target set" -f (Nz $val,'(empty)'))
        }
    } catch { Write-Row $VCenter $VMHost.Name $name 'Error' $_.Exception.Message }
}

# 12) DVFilter Bind IP -> respect target policy ($null skip, '' clear, value set)
$Checks['DVFilter Bind IP'] = {
    param($VMHost,$VCenter)
    $name='DVFilter Bind IP'
    try {
        $adv = Get-AdvancedSetting -Entity $VMHost -Name 'Net.DVFilterBindIpAddress' -ErrorAction SilentlyContinue
        $val = if ($adv) { [string]$adv.Value } else { '' }
        if ($null -eq $Target_DvFilterBindIpAddress) {
            Write-Row $VCenter $VMHost.Name $name 'Info' ("Used={0}; Value='{1}'" -f (-not [string]::IsNullOrWhiteSpace($val)), (Nz $val,'(empty)'))
            return
        }
        $desired = [string]$Target_DvFilterBindIpAddress
        if ($val -ne $desired) {
            if ($adv) { Invoke-Change { Set-AdvancedSetting -AdvancedSetting $adv -Value $desired -Confirm:$false | Out-Null } "Set DVFilterBindIpAddress='$desired'" $VCenter $VMHost.Name $name }
            else      { Invoke-Change { New-AdvancedSetting -Entity $VMHost -Name 'Net.DVFilterBindIpAddress' -Value $desired -Confirm:$false | Out-Null } "Create DVFilterBindIpAddress='$desired'" $VCenter $VMHost.Name $name }
            Write-BackupRow $VCenter $VMHost.Name 'Net.DVFilterBindIpAddress' $val $desired
            Write-Row $VCenter $VMHost.Name $name ($(if($AuditOnly){'SKIPPED-CHANGE'}else{'Changed'})) ("Old='{0}' -> New='{1}'" -f (Nz $val,'(empty)'), (Nz $desired,'(empty)'))
        } else {
            Write-Row $VCenter $VMHost.Name $name 'Pass' ("Value='{0}'" -f (Nz $desired,'(empty)'))
        }
    } catch { Write-Row $VCenter $VMHost.Name $name 'Error' $_.Exception.Message }
}

# 13) Password Complexity -> enforce exact target string (normalized compare)
$Checks['Password Complexity'] = {
    param($VMHost,$VCenter)
    $name='Password Complexity'
    try {
        $adv = Get-AdvancedSetting -Entity $VMHost -Name 'Security.PasswordQualityControl' -ErrorAction SilentlyContinue
        $val = if ($adv) { [string]$adv.Value } else { '' }
        $normVal = Normalize-PQC -Text $val
        $normTarget = Normalize-PQC -Text $Target_PasswordQualityControl
        if ($normVal -eq $normTarget -and -not [string]::IsNullOrWhiteSpace($val)) {
            Write-Row $VCenter $VMHost.Name $name 'Pass' 'Matches baseline'
        } else {
            if ($adv) { Invoke-Change { Set-AdvancedSetting -AdvancedSetting $adv -Value $Target_PasswordQualityControl -Confirm:$false | Out-Null } "Apply PQC baseline" $VCenter $VMHost.Name $name }
            else      { Invoke-Change { New-AdvancedSetting -Entity $VMHost -Name 'Security.PasswordQualityControl' -Value $Target_PasswordQualityControl -Confirm:$false | Out-Null } "Create PQC baseline" $VCenter $VMHost.Name $name }
            Write-BackupRow $VCenter $VMHost.Name 'Security.PasswordQualityControl' $val $Target_PasswordQualityControl
            Write-Row $VCenter $VMHost.Name $name ($(if($AuditOnly){'SKIPPED-CHANGE'}else{'Changed'})) 'Baseline applied'
        }
    } catch { Write-Row $VCenter $VMHost.Name $name 'Error' $_.Exception.Message }
}

# 14) Managed Object Browser (MOB) -> disable Config.HostAgent.plugins.solo.enableMob
$Checks['Managed Object Browser (MOB)'] = {
    param($VMHost,$VCenter)
    $name = 'Managed Object Browser (MOB)'
    $settingName = 'Config.HostAgent.plugins.solo.enableMob'
    try {
        $adv = Get-AdvancedSetting -Entity $VMHost -Name $settingName -ErrorAction SilentlyContinue
        $val = if ($adv) { [string]$adv.Value } else { '' }
        if ($val -eq 'false') {
            Write-Row $VCenter $VMHost.Name $name 'Pass' 'Value=false'
        } else {
            $old = Nz $val,''
            if ($adv) {
                Invoke-Change { Set-AdvancedSetting -AdvancedSetting $adv -Value 'false' -Confirm:$false | Out-Null } "Set $settingName to false" $VCenter $VMHost.Name $name
            } else {
                Invoke-Change { New-AdvancedSetting -Entity $VMHost -Name $settingName -Value 'false' -Confirm:$false | Out-Null } "Create $settingName=false" $VCenter $VMHost.Name $name
            }
            Write-BackupRow $VCenter $VMHost.Name $settingName $old 'false'
            Write-Row       $VCenter $VMHost.Name $name ($(if($AuditOnly){'SKIPPED-CHANGE'}else{'Changed'})) ("Old='{0}' -> New='false'" -f (Nz $old,'(empty)'))
        }
    } catch {
        Write-Row $VCenter $VMHost.Name $name 'Error' $_.Exception.Message
    }
}

# 15) Hyperthreading warning -> ensure UserVars.SuppressHyperthreadWarning = 0
$Checks['Hyperthreading warning'] = {
    param($VMHost,$VCenter)
    $name = 'Hyperthreading warning'
    $settingName = 'UserVars.SuppressHyperthreadWarning'
    try {
        $adv = Get-AdvancedSetting -Entity $VMHost -Name $settingName -ErrorAction SilentlyContinue
        $val = if ($adv) { [string]$adv.Value } else { '' }
        if ($val -eq '0') {
            Write-Row $VCenter $VMHost.Name $name 'Pass' 'Value=0'
        } else {
            $old = Nz $val,''
            if ($adv) {
                Invoke-Change { Set-AdvancedSetting -AdvancedSetting $adv -Value '0' -Confirm:$false | Out-Null } "Set $settingName to 0" $VCenter $VMHost.Name $name
            } else {
                Invoke-Change { New-AdvancedSetting -Entity $VMHost -Name $settingName -Value '0' -Confirm:$false | Out-Null } "Create $settingName=0" $VCenter $VMHost.Name $name
            }
            Write-BackupRow $VCenter $VMHost.Name $settingName $old '0'
            Write-Row       $VCenter $VMHost.Name $name ($(if($AuditOnly){'SKIPPED-CHANGE'}else{'Changed'})) ("Old='{0}' -> New='0'" -f (Nz $old,'(empty)'))
        }
    } catch {
        Write-Row $VCenter $VMHost.Name $name 'Error' $_.Exception.Message
    }
}

# 16) iSCSI Mutual CHAP (may require reboot) -> enable bidirectional CHAP for iSCSI HBAs
$Checks['iSCSI Mutual CHAP (may require reboot)'] = {
    param($VMHost,$VCenter)
    $name = 'iSCSI Mutual CHAP (may require reboot)'
    try {
        $hbas = Get-VMHostHba -VMHost $VMHost -ErrorAction SilentlyContinue | Where-Object { $_.Type -eq 'iScsi' -and $_.Status -eq 'Online' }
        if (-not $hbas -or $hbas.Count -eq 0) {
            Write-Row $VCenter $VMHost.Name $name 'Info' 'No online iSCSI HBAs found'
            return
        }

        foreach ($hba in $hbas) {
            $auth = $hba.AuthenticationProperties
            $oldChapType = $auth.ChapType
            $oldMutual   = $auth.MutualChapEnabled
            $isCompliant = ($auth.ChapType -eq 'Required' -and $auth.MutualChapEnabled)

            if ($isCompliant) {
                $detail = ("Device={0}, ChapType={1}, MutualEnabled={2} (already compliant)" -f $hba.Device, (Nz $oldChapType,''), (Nz $oldMutual,''))
                Write-Row $VCenter $VMHost.Name $name 'Pass' $detail
                continue
            }

            $oldSummary = ("ChapType={0};MutualEnabled={1}" -f (Nz $oldChapType,''), (Nz $oldMutual,''))
            $newSummary = "ChapType=Required;MutualEnabled=True"

            if ($AuditOnly) {
                $detail = ("Device={0}, {1} -> {2} (would change; potential session reset/reboot may be required)" -f $hba.Device, $oldSummary, $newSummary)
                Write-Row $VCenter $VMHost.Name $name 'Non-compliant' $detail
                continue
            }

            $secrets = Get-IscsiChapSecrets
            if (-not $secrets) {
                Write-Row $VCenter $VMHost.Name $name 'Error' 'CHAP secrets not provided'
                continue
            }

            try {
                Set-VMHostHba -IScsiHba $hba `
                    -ChapType Required `
                    -ChapName $secrets.ChapName `
                    -ChapPassword $secrets.ChapPassword `
                    -MutualChapEnabled $true `
                    -MutualChapName $secrets.MutualChapName `
                    -MutualChapPassword $secrets.MutualChapPassword `
                    -Confirm:$false | Out-Null

                Write-BackupRow $VCenter $VMHost.Name ("iSCSIChap:{0}" -f $hba.Device) $oldSummary $newSummary
                $detail = ("Device={0}, {1} -> {2}" -f $hba.Device, $oldSummary, $newSummary)
                Write-Row $VCenter $VMHost.Name $name 'Changed' $detail
            } catch {
                Write-Row $VCenter $VMHost.Name $name 'Error' ("Device={0}: {1}" -f $hba.Device, $_.Exception.Message)
            }
        }
    } catch {
        Write-Row $VCenter $VMHost.Name $name 'Error' $_.Exception.Message
    }
}

# --------------------------
# BACKOUT MODE
# --------------------------
function Get-ServiceRecordByKey { param($vmh,[string]$k) (Get-VMHostService -VMHost $vmh | Where-Object { $_.Key -eq $k }) }

if ($Backout) {
    Ensure-Module -Name VMware.VimAutomation.Core

    if ([string]::IsNullOrWhiteSpace($BackoutCsvPath)) {
        $BackoutCsvPath = Read-Host "Enter path to BACKUP CSV generated by this script"
    }
    if (-not (Test-Path -LiteralPath $BackoutCsvPath)) { throw "Backout CSV not found: $BackoutCsvPath" }

    $rows = Import-Csv -Path $BackoutCsvPath
    if (-not $rows -or $rows.Count -eq 0) { throw "No rows found in backout CSV." }

    # Prep paths
    $TempRoot = 'C:\Temp'
    if (-not (Test-Path -LiteralPath $TempRoot)) { [void](New-Item -ItemType Directory -Path $TempRoot) }
    $RunStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $BackoutResultCsvPath = Join-Path $TempRoot ("Master_CIS_Backout_{0}.csv" -f $RunStamp)

    # Connect per unique vCenter
    $vcs = @($rows | Select-Object -ExpandProperty VCenter -Unique | Where-Object { $_ -and $_.Trim() -ne '' })
    foreach ($vc in $vcs) {
        Write-Host ""; Write-Host ("== Connecting to {0} ==" -f $vc)
        $cred = Get-CredForVCenter -VCenterFqdn $vc
        if (-not $cred) { $cred = Get-Credential -Message "Enter credentials for $vc" }
        try { Connect-VIServer -Server $vc -Credential $cred -WarningAction SilentlyContinue | Out-Null }
        catch { Write-Row $vc '' 'Backout/Connect' 'Error' $_.Exception.Message }
    }

    foreach ($r in $rows) {
        $vc  = $r.VCenter
        $hn  = $r.Hostname
        $set = $r.Setting
        $old = $r.OldValue
        $new = $r.NewValue
        try {
            $vmh = Get-VMHost -Server $vc -Name $hn -ErrorAction Stop
            $ok  = $false

            switch -Regex ($set) {
                '^Service:(.+)\.State$' {
                    $key = $Matches[1]
                    $svc = Get-ServiceRecordByKey $vmh $key
                    if ($svc) {
                        $target = (Nz $old).ToLower()
                        if ($target -in @('running','on','true')) {
                            if (-not $svc.Running) { Start-VMHostService -HostService $svc -Confirm:$false | Out-Null }
                        } else {
                            if ($svc.Running) { Stop-VMHostService -HostService $svc -Confirm:$false | Out-Null }
                        }
                        $ok = $true
                    }
                }
                '^Service:(.+)\.Policy$' {
                    $key = $Matches[1]
                    $svc = Get-ServiceRecordByKey $vmh $key
                    if ($svc) {
                        $t = (Nz $old,'off')
                        if ($svc.Policy -ne $t) { Set-VMHostService -HostService $svc -Policy $t -Confirm:$false | Out-Null }
                        $ok = $true
                    }
                }
                '^(Syslog\.global\.logDir|Syslog\.global\.logHost|Security\.PasswordQualityControl|Security\.AccountLockFailures|Net\.DVFilterBindIpAddress|Mem\.ShareForceSalting|Config\.HostAgent\.plugins\.solo\.enableMob|UserVars\.SuppressHyperthreadWarning)$' {
                    $name = $set
                    $adv  = Get-AdvancedSetting -Entity $vmh -Name $name -ErrorAction SilentlyContinue
                    if ($adv) {
                        if ($adv.Value -ne $old) { Set-AdvancedSetting -AdvancedSetting $adv -Value $old -Confirm:$false | Out-Null }
                    } else {
                        if (-not [string]::IsNullOrWhiteSpace($old)) {
                            New-AdvancedSetting -Entity $vmh -Name $name -Value $old -Confirm:$false | Out-Null
                        }
                    }
                    $ok = $true
                }
                '^iSCSIChap:(.+)$' {
                    $device = $Matches[1]
                    $hba = Get-VMHostHba -VMHost $vmh -Type iScsi -ErrorAction SilentlyContinue | Where-Object { $_.Device -eq $device }
                    if ($hba) {
                        $chapType = $null
                        $mutualEnabled = $null
                        if (-not [string]::IsNullOrWhiteSpace($old)) {
                            $parts = $old.Split(';')
                            foreach ($p in $parts) {
                                $kv = $p.Split('=',2)
                                if ($kv.Count -eq 2) {
                                    $k = $kv[0].Trim()
                                    $v = $kv[1].Trim()
                                    if ($k -eq 'ChapType') { $chapType = $v }
                                    elseif ($k -eq 'MutualEnabled') { $mutualEnabled = $v }
                                }
                            }
                        }
                        if ($chapType -or $mutualEnabled) {
                            if ($chapType -and $mutualEnabled) {
                                $boolVal = $false
                                if ($mutualEnabled -match '^(?i:true|1|yes)$') { $boolVal = $true }
                                Set-VMHostHba -IScsiHba $hba -ChapType $chapType -MutualChapEnabled $boolVal -Confirm:$false | Out-Null
                            } elseif ($chapType) {
                                Set-VMHostHba -IScsiHba $hba -ChapType $chapType -Confirm:$false | Out-Null
                            } elseif ($mutualEnabled) {
                                $boolVal = $false
                                if ($mutualEnabled -match '^(?i:true|1|yes)$') { $boolVal = $true }
                                Set-VMHostHba -IScsiHba $hba -MutualChapEnabled $boolVal -Confirm:$false | Out-Null
                            }
                        }
                        $ok = $true
                    }
                }

                '^SSH Banner$' {
                    $adv = Get-AdvancedSetting -Entity $vmh -Name 'Config.Etc.issue' -ErrorAction SilentlyContinue
                    if ($adv) {
                        if ($adv.Value -ne $old) { Set-AdvancedSetting -AdvancedSetting $adv -Value $old -Confirm:$false | Out-Null }
                    } else {
                        if (-not [string]::IsNullOrWhiteSpace($old)) {
                            New-AdvancedSetting -Entity $vmh -Name 'Config.Etc.issue' -Value $old -Confirm:$false | Out-Null
                        }
                    }
                    $ok = $true
                }
                '^NTP\.Servers$' {
                    $targetList = @()
                    if (-not [string]::IsNullOrWhiteSpace($old)) {
                        $targetList = $old -split '\s*,\s*' | Where-Object { $_ -ne '' }
                    }
                    $current = @()
                    try { $current = (Get-VMHostNtpServer -VMHost $vmh -ErrorAction Stop) } catch { $current = @() }
                    $toRemove = @($current   | Where-Object { $_ -notin $targetList })
                    $toAdd    = @($targetList | Where-Object { $_ -notin $current })
                    if ($toRemove.Count -gt 0) { Remove-VMHostNtpServer -VMHost $vmh -NtpServer $toRemove -Confirm:$false | Out-Null }
                    if ($toAdd.Count -gt 0)    { Add-VMHostNtpServer    -VMHost $vmh -NtpServer $toAdd    -Confirm:$false | Out-Null }
                    $ok = $true
                }
                default {
                    Write-Row $vc $hn ('Backout:'+$set) 'Info' 'Setting not recognized for backout logic.'
                }
            }

            if ($ok) {
                Write-Row $vc $hn ('Backout:'+$set) 'Changed' ("Restored to '{0}'" -f (Nz $old,'(empty)'))
            }

        } catch {
            Write-Row $vc $hn ('Backout:'+$set) 'Error' $_.Exception.Message
        }
    }

    # Disconnect and write results
    Get-VIServer | ForEach-Object { Disconnect-VIServer -Server $_ -Confirm:$false | Out-Null }
    if ($Results.Count -gt 0) { $Results | Export-Csv -Path $BackoutResultCsvPath -NoTypeInformation -Encoding UTF8 }
    Write-Host ""
    Write-Host ("Backout complete. Results: {0}" -f $BackoutResultCsvPath)
    return
}

# --------------------------
# MAIN (menus unchanged)
# --------------------------
try {
    Ensure-Module -Name VMware.VimAutomation.Core

    Write-Host "== vCenter Credentials ==" -ForegroundColor Cyan
    $ans = Read-Host "Create credential files? (Y/N)"
    if ($ans -match '^[Yy]') { Create-Creds-Workflow }

    Write-Host ""
    Write-Host "== Select Checks (0 = ALL) ==" -ForegroundColor Cyan
    for ($i=0; $i -lt $checkNames.Count; $i++) { Write-Host ("[{0}] {1}" -f ($i+1), $checkNames[$i]) }
    $selChecks = Read-Host "Enter numbers separated by comma, or 0 for ALL"
    $selectedIndices = @()
    if ($selChecks -match '^\s*0\s*$') {
        $selectedIndices = 1..$checkNames.Count
    } else {
        foreach ($p in $selChecks -split '[, ]+') {
            if ($p -match '^\d+$') {
                $idx = [int]$p
                if ($idx -ge 1 -and $idx -le $checkNames.Count) { $selectedIndices += $idx }
            }
        }
        if (-not $selectedIndices) { $selectedIndices = 1..$checkNames.Count }
    }

    $vcenters = Select-VCentersFromCredStore
    if (-not $vcenters -or $vcenters.Count -eq 0) { throw "No vCenters selected." }

    $TempRoot = 'C:\Temp'
    if (-not (Test-Path -LiteralPath $TempRoot)) { [void](New-Item -ItemType Directory -Path $TempRoot) }
    $RunStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $ResultCsvPath = Join-Path $TempRoot ("Master_CIS_Remediation_{0}.csv" -f $RunStamp)
    $BackupCsvPath = Join-Path $TempRoot ("Master_CIS_Backup_{0}.csv" -f $RunStamp)

    foreach ($vc in $vcenters) {
        Write-Host ""; Write-Host ("== Connecting to {0} ==" -f $vc)
        $cred = Get-CredForVCenter -VCenterFqdn $vc
        if (-not $cred) { $cred = Get-Credential -Message "Enter credentials for $vc" }
        try { Connect-VIServer -Server $vc -Credential $cred -WarningAction SilentlyContinue | Out-Null }
        catch { Write-Row $vc '' 'Connect' 'Error' $_.Exception.Message; continue }

        try {
            $hosts = Get-VMHost -Server $vc | Sort-Object Name
            foreach ($h in $hosts) {
                foreach ($idx in $selectedIndices) {
                    $key = $checkNames[$idx-1]
                    $block = $Checks[$key]
                    try { & $block $h $vc } catch { Write-Row $vc $h.Name $key 'Error' $_.Exception.Message }
                }
            }
        } finally {
            Disconnect-VIServer -Server $vc -Confirm:$false | Out-Null
        }
    }

    if ($Results.Count -gt 0) { $Results | Export-Csv -Path $ResultCsvPath -NoTypeInformation -Encoding UTF8 }
    if ($Backups.Count -gt 0 -and -not $AuditOnly) { $Backups | Export-Csv -Path $BackupCsvPath -NoTypeInformation -Encoding UTF8 }

    Write-Host ""
    if ($AuditOnly) {
        Write-Host ("AuditOnly (dry-run) CSV: {0}" -f $ResultCsvPath)
        Write-Host "No backups written in dry-run mode."
    } else {
        Write-Host ("Remediation CSV:  {0}" -f $ResultCsvPath)
        if ($Backups.Count -gt 0) {
            Write-Host ("Backup CSV:      {0}" -f $BackupCsvPath)
        } else {
            Write-Host "No backup changes were recorded."
        }
    }
}
catch {
    Write-Error $_.Exception.Message
}