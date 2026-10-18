# 基本性能维护（Performance）

## 开机链路模型

Windows 开机时间 = 固件 + 引导加载 + 内核初始化 + **服务/驱动启动（最大变量）** + 用户登录 + Shell 启动 + 自启程序。家庭机"黑屏半天"90% 出在服务启动和 Shell 自启两段。

## 四大性能杀手与处置

### 1. 服务启动超时（AppReadiness 类）

**症状**：Diagnostics-Performance 事件 101 反复出现某服务；System 日志 7011 "服务未及时响应启动/控制请求"（每次超时 = 干等 30 秒，N 次就是 N×30 秒）。

**诊断**：
```powershell
Get-WinEvent -FilterHashtable @{LogName='System';Id=7011;StartTime=(Get-Date).AddHours(-2)} -EA SilentlyContinue
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Diagnostics-Performance/Operational';Id=101} -EA SilentlyContinue
```

**根因组合**：AppReadiness 卡死通常由"长期未更新 + 商店应用状态损坏"触发。

**修复顺序**（顺序不能乱）：
1. `sfc /scannow`（确认系统文件完好，从 CBS.log 验证无 repair 记录）
2. **装齐 Windows 更新**（AppReadiness 修复的前提，欠更 3 个月是常见诱因）
3. AppX 全量重注册：`Get-AppxPackage -AllUsers | ForEach-Object { Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -EA SilentlyContinue }`
   - 报错 `PathNotFound` 的是无路径框架包（.NET Runtime 等），属正常噪音
4. 重启后验证 7011/101 清零

### 2. 快速启动 + 现代待机

**原理**：快速启动（HiberbootEnabled=1） hybrid-boot 复用休眠内核，让"重启"不彻底重置驱动栈；现代待机让用户几乎不冷启动。两者叠加 = 服务卡死问题每次都被"带病唤醒"，反复触发。

**处置**：
```powershell
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled' -Value 0 -Type DWord -Force
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e   # 平衡计划
Disable-NetAdapterPowerManagement -Name 'WLAN'             # 治睡眠唤醒后断网
```

### 3. 启动项堆积

**采集**：
```powershell
Get-CimInstance Win32_StartupCommand | Select-Object Name,Location,User,Command
Get-ScheduledTask | Where-Object {$_.TaskPath -notlike '\Microsoft\*'} | Select-Object TaskName,TaskPath
Get-CimInstance Win32_Service | Where-Object {$_.StartMode -eq 'Auto' -and $_.PathName -notmatch 'Windows\\System32'} | Select-Object Name,State,PathName
```

**判定法（白名单）**：只保留 (a) 用户明确要用的（OneDrive/网盘/WorkBuddy/Tailscale）、(b) 本机品牌官方管理服务（Dell SupportAssist 等）、(c) 安全软件（Defender）、(d) 音频/触控板等硬件服务。其余一律进待卸清单让用户确认。

**注意**：计划任务要查 TaskPath，有的藏在根路径 `\` 下（如某些厂商任务），按 TaskPath 过滤会漏，要用 TaskName 补充匹配。

### 4. 更新欠账

**诊断**（COM 被挡时用事件）：
```powershell
Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='Microsoft-Windows-WindowsUpdateClient';StartTime=(Get-Date).AddDays(-30)} | Sort-Object TimeCreated -Descending
Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 5
```

**功能更新（23H2→24H2 类）卡住不动时的判定法**（重要经验）：
- 下载阶段看 `C:\Windows\SoftwareDistribution\Download` 体积增长 + 网卡流量双采样（间隔 30s 对比）
- 暂存阶段看 SetupHost CPU 双采样（30s 内稳定 +15s CPU = 在拼命干活，不是卡死）+ `C:\$WINDOWS.~BT\Sources\Panther\setupact.log` 实时写入
- **97% 卡久的真相可能是应用迁移**：mighost 逐个处理 AppX 包，机器上用户档案多、应用多时（实测 1221 个包 ≈ 1 小时），进度条按批次粗粒度刷新会长时间不动
- 暂存完成的信号：日志出现 `SetupHost Logging End`、`ShutdownBlockReasonDestroy succeeded`、RebootRequired 注册表置位
- **暂存中严禁手动重启**（可能回滚）；暂存完成前 CPU 停滞超 20 分钟且日志停写才需要干预
- 干预手法（标准修复）：停 wuauserv/bits/usosvc → 清 SoftwareDistribution\Download → 重启服务 → 重试

### 5. 磁盘与电源

- SSD 健康：`Get-PhysicalDisk | Get-StorageReliabilityCounter`（看 Wear/Temperature/Errors）
- 空间：C 盘保持 >15% 空闲；功能更新需要约 10-20GB 暂存空间
- 电源计划被穿越（Dell 机器跑着"Lenovo 智能电源"）：一律回平衡
- 笔记本电池：`powercfg /batteryreport`，健康度 <80% 建议换；日常可设充电上限 80%（Dell 用 Dell Power Manager，联想用 Vantage，没有官方工具则提醒用户）

## 验证口径

| 指标 | 工具/命令 | 合格线 |
|---|---|---|
| 开机时长 | Diag-Perf 事件 100 (Boot Duration ms) | 老旧商务本 ≤45s；功能更新首启除外 |
| 降级事件 | Diag-Perf 事件 101 | 0 |
| 服务超时 | System 7011 | 0 |
| 更新状态 | WindowsUpdateClient 事件 19 (Installation Successful) | 无失败，build 号最新 |

**注意**：整改后第一次重启若期间装了功能更新，时长会含 SafeOS 安装而暴涨，必须**再完整关机冷启动一次**取稳态值。

**解析技巧**：事件 100 的 Message 里数字前可能混有 U+200E 隐形字符，正则必须宽容：`'Boot Duration[^\d]*(\d+)\s*ms'`（写成 `':\s*\d+'` 会失配）。功能更新会轮换日志，更新后可能只剩 1 条开机事件，属正常。
