# health-check.ps1 - Windows 机器一键体检快照
# 用法: Set-ExecutionPolicy -Scope Process Bypass -Force; .\health-check.ps1
# 输出为纯文本，可直接贴给用户或存为基线。只读，不改任何设置。
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'SilentlyContinue'

function Section($t) { ''; '===== ' + $t + ' =====' }
function Line($s) { $s }

$os = Get-CimInstance Win32_OperatingSystem
$nt = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$cs = Get-CimInstance Win32_ComputerSystem

Section '系统与硬件'
Line ('OS           : ' + $nt.DisplayVersion + ' | Build ' + $nt.CurrentBuild + '.' + $nt.UBR + ' | ' + $os.OSArchitecture)
Line ('Machine      : ' + $cs.Manufacturer + ' ' + $cs.Model)
Line ('CPU          : ' + (Get-CimInstance Win32_Processor).Name.Trim())
Line ('RAM          : ' + [math]::Round($cs.TotalPhysicalMemory/1GB,0) + ' GB')
Line ('LastBoot     : ' + $os.LastBootUpTime + ' (uptime ' + [math]::Round(((Get-Date)-$os.LastBootUpTime).TotalHours,1) + 'h)')
$bat = Get-CimInstance Win32_PortableBattery
if ($bat) { Line ('Battery      : ' + $bat.Name) }

Section '开机性能（核心指标）'
$boots = Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Diagnostics-Performance/Operational';Id=100} -MaxEvents 5
if ($boots) {
  foreach ($b in $boots) {
    $m = $b.Message
    if ($m -match 'Boot Duration[^\d]*(\d+)\s*ms') {
      $sec = [math]::Round([int]$Matches[1]/1000,1)
      $flag = ''
      if ($m -match 'IsDegradation:\s*(\w+)') { $flag = ' | degradation=' + $Matches[1] }
      Line ('Boot ' + $b.TimeCreated.ToString('MM-dd HH:mm') + ' : ' + $sec + 's' + $flag)
    }
  }
} else { Line 'no boot events found' }
$deg = Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Diagnostics-Performance/Operational';Id=101;StartTime=$os.LastBootUpTime}
Line ('Degradation events THIS boot : ' + $(if($deg){$deg.Count}else{0}) + ' (target: 0)')
if ($deg) { $deg | ForEach-Object { '  - ' + (($_.Message -replace "`r`n",' ').Trim()) } }

Section '服务异常（本次开机）'
$svcErr = Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='Service Control Manager';StartTime=$os.LastBootUpTime;Level=1,2,3} | Where-Object {$_.Id -in 7000,7011,7024,7034,7038,7043}
if ($svcErr) { $svcErr | ForEach-Object { Line ($_.TimeCreated.ToString('HH:mm') + ' | Id=' + $_.Id + ' | ' + (($_.Message -replace "`r`n",' ').Trim())) } } else { Line 'none (clean)' }

Section '启动项（全用户）'
Get-CimInstance Win32_StartupCommand | ForEach-Object { Line ('  ' + $_.Name + '  [' + $(if($_.Location -match 'HKLM'){'HKLM'}elseif($_.Location -match 'HKU'){'HKU'}else{$_.Location}) + ']') }

Section '第三方 Auto 服务'
Get-CimInstance Win32_Service | Where-Object {$_.StartMode -eq 'Auto' -and $_.PathName -ne $null -and $_.PathName -notmatch 'Windows\\System32' -and $_.PathName -notmatch 'Windows\\SysWOW64'} | ForEach-Object { Line ('  ' + $_.Name + ' (' + $_.State + ')') }

Section '非微软计划任务'
Get-ScheduledTask | Where-Object {$_.TaskPath -notlike '\Microsoft\*'} | ForEach-Object { Line ('  ' + $_.TaskPath + $_.TaskName) }

Section '更新状态'
$rebootKeys = @(
  'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
  'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
)
foreach ($k in $rebootKeys) { if (Test-Path $k) { Line ('  REBOOT PENDING: ' + ($k -replace '.*\\','')) } }
$wu = Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='Microsoft-Windows-WindowsUpdateClient'} -MaxEvents 3
if ($wu) { $wu | ForEach-Object { Line ('  ' + $_.TimeCreated.ToString('MM-dd HH:mm') + ' | Id=' + $_.Id + ' | ' + (($_.Message -replace "`r`n",' ').Trim())) } }
Line ('  Latest hotfix: ' + ((Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1).HotFixID))

Section '配置与磁盘'
Line ('FastStartup   : HiberbootEnabled=' + (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name HiberbootEnabled).HiberbootEnabled + ' (0=off, 1=on)')
Line ('PowerPlan     : ' + ((powercfg /getactivescheme) -replace '.*: ','').Trim())
Get-Volume | Where-Object {$_.DriveLetter} | ForEach-Object { Line ('  Disk ' + $_.DriveLetter + ': ' + [math]::Round($_.SizeRemaining/1GB,1) + ' GB free / ' + [math]::Round($_.Size/1GB,1) + ' GB (' + [math]::Round(100*$_.SizeRemaining/$_.Size,1) + '%)') }
foreach ($d in Get-PhysicalDisk) { Line ('  SSD ' + $d.FriendlyName + ' : ' + $d.HealthStatus) }

Section 'Defender'
$mp = Get-MpComputerStatus
Line ('  RealTime=' + $mp.RealTimeProtectionEnabled + ' | SigUpdated=' + $mp.AntivirusSignatureLastUpdated + ' | QuickScanAge(d)=' + $mp.QuickScanAge)

Section 'END'
'Snapshot taken: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
