# 常用软件维护（Software）

## 软件处置总原则：白名单制

不列"黑名单"（永远列不全），而是反过来：**只留白名单内的，其余全部进待卸清单交用户确认**。

白名单（默认保留）：
1. 用户明确要用的软件（维护时逐项问）
2. 本机品牌官方管理组件（Dell SupportAssist/Dell Client Management、联想 Vantage 等）——用于驱动与 BIOS 更新
3. 安全软件：Windows Defender（第三方杀毒默认建议不装第二只）
4. 硬件必需服务：音频（Realtek/Waves/Dolby）、触控板、Thunderbolt、显卡最小集
5. 用户日常工具：浏览器、输入法、WPS/Office、网盘、Tailscale 等（按用户答复）

## 五类必须清除的软件（本方法论核心判定法）

1. **品牌穿越软件**：A 牌机器上跑着 B 牌全家桶（Dell 上的联想电源计划/联想服务/ImController）。判定：`Get-CimInstance Win32_Service | ? PathName -match 'Lenovo|HP|Asus|Acer'` 出现在不对应的品牌机器上
2. **无硬件对应的组件**：Intel 核显机器上的 AMD 残留、无 NVIDIA 独显机器的 NVIDIA 任务/崩溃报告。判定：`Get-CimInstance Win32_VideoController` 对比任务与服务名
3. **卫士/广告类**：鲁大师类（含"硬件检测"实则广告+推广）、各种"电脑管家"第三方版。**重点：查内核驱动**（`Get-CimInstance Win32_SystemDriver | ? PathName -match '厂商名'`，如 LudashiProtect），驱动必须 ChangeStartMode Disabled，仅删目录不够
4. **娱乐预装**：Xbox 系列（机器无游戏用途）、纸牌、Zune、YourPhone、People、反馈中心等。判定：家庭学习/文档用途
5. **孤儿服务/死键/死任务**：宿主软件已卸载但服务/自启项/计划任务还在，且**目标文件已不存在**（先 `Test-Path` 验证目标，再动手）

## 处置手法（按优先级）

1. **有官方卸载入口的**：注册表 Uninstall 键的 QuietUninstallString / 控制面板卸载，优先走官方
2. **无卸载入口的**（TechHub 类）：停服务 → ChangeStartMode Disabled → 杀残留进程 → 删目录（锁定的记入"重启后删除"清单）
3. **服务禁用标准动作**（sc.exe 被禁时）：
   ```powershell
   $s = Get-CimInstance Win32_Service -Filter "Name='XXX'"
   Invoke-CimMethod -InputObject $s -MethodName ChangeStartMode -Arguments @{StartMode='Disabled'}
   Stop-Service -Name 'XXX' -Force -EA SilentlyContinue
   ```
4. **商店应用**：`Get-AppxPackage -AllUsers -Name 'XXX' | Remove-AppxPackage -AllUsers`，失败退回 `Remove-AppxProvisionedPackage`；**有常驻服务的先停服务 + ChangeStartMode Disabled 再卸**（否则卸不干净，或服务变孤儿）
5. **死键死任务**：目标文件确认不存在后，删 Run 键值 / `Unregister-ScheduledTask`

## 卸载后四项验证（缺一不可）

```powershell
# 1 启动项（注意死键目标文件不存在）
Get-CimInstance Win32_StartupCommand | Select-Object Name,Location
# 2 第三方 Auto 服务
Get-CimInstance Win32_Service | ? {$_.StartMode -eq 'Auto' -and $_.PathName -notmatch 'Windows\\System32'} | Select-Object Name,State
# 3 非微软计划任务（TaskName 与 TaskPath 双重匹配，防根路径漏网）
Get-ScheduledTask | ? {$_.TaskPath -notlike '\Microsoft\*'} | Select-Object TaskName,TaskPath
# 4 注册表孤儿项
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -EA SilentlyContinue | ? {$_.DisplayName -match '已卸软件名'}
```

## 已知陷阱

- **功能更新回填**：Windows 功能更新会用升级前系统配置快照恢复已禁用的服务/自启键/计划任务（实测：ImControllerService 回到 Auto、ComputerZ-Tray 自启键复活、HP 计划任务复活）。**每次大更新后必须重跑四项验证并二次清除**
- **系统受保护组件**：个别商店应用（如 XboxGameCallableUI 在 SystemApps 下）设计上不可卸载，若已无用户安装、无自启 = inert 空壳，强拆有风险，记录为"保留无害"即可，不纠缠
- **卸载器跑完≠干净**：卸载程序退出后要复查目录残留和注册表（实测鲁大师卸载器跑完仍留 1.1GB 目录 + 938 文件 + 内核驱动）
- **瞬态失败**：功能更新期间商店应用更新报 0x80073D02 是组件占用导致的瞬态冲突，更新装完后自动恢复，不要当时干预
- **残留可能躲在 System32**：友商服务的二进制不一定在自家目录——联想 `IBMPMSVC`（ibmpmsvc.exe）就在 `C:\WINDOWS\System32\` 下，删 `C:\Program Files\Lenovo` 清不掉它。正确做法：按服务路径全盘搜 `Get-CimInstance Win32_Service | ? {$_.PathName -match 'Lenovo|ImController|IBMPM|fibocom|DPR'}`，逐个禁用后删二进制（先确认无其他服务引用同一文件）
- **同一软件可能双版本并存（传统安装版 + Store 版）**：实测微软电脑管家在本机同时存在两份——传统安装版（`C:\Program Files\Microsoft PC Manager`，`uninst.exe /S` 可卸）和 Microsoft Store 版（`C:\Program Files\WindowsApps\Microsoft.MicrosoftPCManager_3.23.0.0_x64__8wekyb3d8bbwe`，归 Get-AppxPackage 管）。卸掉传统版后，**Store 版的服务照常运行**（`PCManager Service Store`，LocalSystem/Automatic，PathName 指向 WindowsApps）——普通卸载程序完全摸不到 Store 版。正确做法：① 卸载注册表 **和** `Get-AppxPackage -AllUsers -Name '*关键词*'` 双路查；② Store 版先停服务 + ChangeStartMode Disabled，再 `Remove-AppxPackage -AllUsers`；③ 包 deregister 后 WindowsApps 里可能留孤儿目录（实测 555 项），受 TrustedInstaller ACL 保护、常规手段删不掉属正常，无害不纠缠，记录即可
- **luafv 类微软驱动首启被阻止**：功能更新后首次开机，合法微软驱动（如 luafv.sys LUA 虚拟化）可能报 "blocked from loading"（事件 7000），多为瞬态，下次启动观察是否恢复；StartMode 仍为 Auto 的不用动，反复被阻再查驱动 blocklist

## 新软件安装的网络出口选择（沙箱环境）

沙箱代理可能只通部分域名。安装任何东西前先实测：
```powershell
curl.exe -s --noproxy '*' -o NUL -w "direct: HTTP %{http_code} | %{time_total}s" --max-time 15 "<URL>"
curl.exe -s -x http://127.0.0.1:65200 -o NUL -w "proxy: HTTP %{http_code} | %{time_total}s" --max-time 15 "<URL>"
```
用通的那条。国内 npm 镜像（npmmirror/阿里云/华为）不一定通，官方源直连常最快——以实测为准，不套经验。pip/npm 卡住先查是不是继承了不该用的代理环境变量。
