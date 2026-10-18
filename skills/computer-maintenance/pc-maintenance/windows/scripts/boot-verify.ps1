# boot-verify.ps1 - 开机性能专项验证
# 用法: Set-ExecutionPolicy -Scope Process Bypass -Force; .\boot-verify.ps1
# 用途: 整改后/大更新后验证稳态开机时长、降级事件、服务超时。
# 注意: 功能更新(23H2->24H2 类)后的首次开机含 SafeOS 安装，时长会暴涨(如 431s)，
#       那不是稳态值——需完整关机冷启动后再跑一次本脚本取数。
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'SilentlyContinue'

$os = Get-CimInstance Win32_OperatingSystem

'===== 最近 5 次开机时长 ====='
$boots = Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Diagnostics-Performance/Operational';Id=100} -MaxEvents 5
if (-not $boots) { 'no boot events found'; exit }
$vals = @()
foreach ($b in $boots) {
  $m = $b.Message
  if ($m -match 'Boot Duration[^\d]*(\d+)\s*ms') {
    $ms = [int]$Matches[1]
    $vals += $ms
    $note = ''
    if ($b.TimeCreated -ge $os.LastBootUpTime) { $note = '  <-- 本次开机' }
    $pad = '{0,7}' -f ([math]::Round($ms/1000,1).ToString() + 's')
    ($b.TimeCreated.ToString('MM-dd HH:mm') + ' | ' + $pad + $note)
  }
}
if ($vals.Count -ge 2) {
  $avg = [math]::Round((($vals | Measure-Object -Average).Average)/1000,1)
  $max = [math]::Round((($vals | Measure-Object -Maximum).Maximum)/1000,1)
  ''
  ('平均 ' + $avg + 's | 最慢 ' + $max + 's | 样本 ' + $vals.Count + ' 次')
}

''
'===== 本次开机降级事件(101)明细 ====='
$deg = Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Diagnostics-Performance/Operational';Id=101;StartTime=$os.LastBootUpTime}
if ($deg) {
  'count = ' + $deg.Count + ' (target: 0)'
  $deg | ForEach-Object { '  - ' + (($_.Message -replace "`r`n",' ').Trim()) }
} else {
  '0 项 - 合格'
}

''
'===== 本次开机服务超时/错误 ====='
$svcErr = Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='Service Control Manager';StartTime=$os.LastBootUpTime;Level=1,2,3} | Where-Object {$_.Id -in 7000,7011,7024,7034,7038,7043}
if ($svcErr) {
  $svcErr | ForEach-Object { ($_.TimeCreated.ToString('HH:mm') + ' | Id=' + $_.Id + ' | ' + (($_.Message -replace "`r`n",' ').Trim())) }
} else {
  '无 - 合格'
}

''
'===== 判定 ====='
$cur = Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Diagnostics-Performance/Operational';Id=100} -MaxEvents 1
if ($cur.Message -match 'Boot Duration:\s*(\d+)ms') {
  $sec = [math]::Round([int]$Matches[1]/1000,1)
  if ($sec -gt 120) {
    '本次开机 ' + $sec + 's 异常偏长。若刚装过功能更新(如 24H2)，此为 SafeOS 安装的正常开销；'
    '请完整关机(非重启)后冷启动，再跑一次本脚本取稳态值。'
  } elseif ($sec -le 60) {
    '本次开机 ' + $sec + 's - 达标(商务本 <=45~60s 口径)'
  } else {
    '本次开机 ' + $sec + 's - 偏慢但未失控，建议核对上面的降级事件明细'
  }
}
