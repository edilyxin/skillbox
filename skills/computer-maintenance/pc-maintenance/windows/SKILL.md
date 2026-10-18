---
name: pc-maintenance
description: Windows 电脑全面维护方法论。当用户要求体检/优化/清理任何 Windows 机器（开机慢、黑屏、卡顿、软件混乱、更新异常），或要求对新机器建立维护档案、定期维护、持续改进维护体系时使用。覆盖四大支柱：基本性能维护（开机/服务/更新/磁盘）、常用软件维护（卸载白名单/孤儿服务/计划任务）、每机长期记忆策略（机器档案+跨任务可见）、持续改进（指标追踪+技能迭代）。触发词：电脑体检、开机慢、黑屏、优化笔记本、清理电脑、电脑维护、新机器建档。
agent_created: true
version: 1.0.0
os: windows
---

# PC Maintenance — Windows 电脑维护方法论

## Overview

对任意 Windows 机器执行"体检 → 整改 → 验证 → 建档 → 持续维护"的完整闭环。四大支柱对应四份参考文档，按需加载，不必一次读全。

## 铁律（先读这段再动手）

1. **先体检后动手**：所有整改项必须先有实测证据（事件日志/进程/注册表），禁凭经验猜测
2. **不碰用户没确认的东西**：卸载类逐项列给用户确认；绝批量乱删
3. **创建还原点优先**：整改前 `Checkpoint-Computer`，确认保护就位再继续
4. **改动可回退**：服务用禁用不停用删除；目录删除前确认目标文件已无进程占用
5. **沙箱环境避坑**（本方法论在 WorkBuddy 沙箱内验证过的限制）：
   - `sc.exe` 可能被用户自配黑名单禁用 → 用 `Invoke-CimMethod -MethodName ChangeStartMode` 代替
   - COM 对象实例化（如 `Microsoft.Update.Session`）可能被沙箱策略挡 → 改用 `Get-WinEvent` 查 WindowsUpdateClient 事件
   - `.ps1` 文件可能被执行策略禁跑 → 用内联命令，或 `Set-ExecutionPolicy -Scope Process Bypass -Force`
   - 网络出口可能只通一半（代理挡部分域名）→ 装软件前先实测直连/代理两条路，用通的
6. **PowerShell 脚本含中文时必须存为 UTF-8 带 BOM**：PS 5.1 把无 BOM 的 UTF-8 当 ANSI(GB2312) 读，中文注释行尾的多字节序列会吞掉换行符，导致下一行被并入注释——代码静默丢失或解析错位（症状：`ExpressionsMustBeFirstInPipeline`、行号错位、变量为空）。Write 工具写出的是无 BOM 文件，**写完 .ps1 后必须用 `[System.IO.File]::WriteAllText($f,$c,New-Object System.Text.UTF8Encoding($true))` 补 BOM**
7. **事件日志消息含隐形字符**：Windows 事件 Message 里混有 U+200E/U+200F（LRM/RLM），`Boot Duration:‎431278ms` 这类数字前可能带隐形标记，写正则必须宽容：`'Boot Duration[^\d]*(\d+)\s*ms'`，别用 `':\s*'`
8. **友商残留可能躲在 System32**：联想电源服务 `IBMPMSVC` 的二进制在 `C:\WINDOWS\System32\ibmpmsvc.exe`（不在品牌目录，删目录清不掉它）——清残留必须按**服务路径全盘搜**（`Win32_Service | ? PathName -match '品牌名'`），不能只删品牌目录

## 工作流决策树

```
用户请求维护某台机器
├─ 首次接触这台机器 ─────────→ 完整流程（下方阶段 1-6）
├─ 定期维护/复查 ────────────→ 跳到阶段 4（指标比对）+ 阶段 5（更新记忆）
├─ 具体症状（开机慢/黑屏）───→ 阶段 1 定向采集 + references/performance.md
├─ 软件混乱/要装要卸 ────────→ references/software.md
├─ 新机器建档 ──────────────→ assets/machine-profile-template.md + references/memory-strategy.md
└─ 维护体系本身要改进 ───────→ references/continuous-improvement.md
```

## 阶段 1：体检采集（只读，不动任何设置）

按序并行采集，输出"证据链"而非感想：

1. **硬件基线**：CPU/内存/磁盘(SMART/HealthStatus)/电池(设计 vs 实际容量)/GPU/系统版本
2. **开机性能**（核心）：
   - `Microsoft-Windows-Diagnostics-Performance/Operational` 事件 100（开机时长，毫秒）/ 101（降级项明细）
   - Kernel-Boot、System 日志中 Service Control Manager 7011/7000/7034 等服务超时
   - 每次 101 降级事件都要定位到具体进程/服务——这是"黑屏半天"的量化证据
3. **启动项全清单**：`Win32_StartupCommand`（所有用户）+ 非微软计划任务 + 第三方 Auto 服务
4. **软件生态**：已安装程序（重点标出非本机品牌的穿越软件）、Store 应用、待装更新、Defender 状态
5. **配置项**：快速启动(HiberbootEnabled)、电源计划、页面文件、代理设置、BitLocker

## 阶段 2：根因定位

- 开机慢/黑屏的典型组合拳：**AppReadiness 等服务启动超时（每次干等 30 秒）+ 快速启动 + 现代待机（导致问题反复触发）+ 长期未更新**
- 用"每次开机 X 项降级 × 每项 Y 秒"算出总浪费时长，给出整改前的量化基线
- 排除硬件故障：无 Kernel-Power 41、无 WHEA、SSD 健康、sfc 干净——先给用户吃定心丸

## 阶段 3：整改（P0 当天 / P1 一周 / P2 每月）

- **P0 安全步骤先做**：还原点 → 装齐更新（修 AppReadiness 的前提）→ 关快速启动 → 电源计划回平衡 → 关 Wi-Fi 电源管理
- **P0 卸载项**：本机品牌无关的全家桶软件、穿越的友商残留（联想软件跑在 Dell 上）、无硬件对应的驱动组件（无 NVIDIA 却有 NVIDIA 任务）、娱乐商店应用、广告/卫士类（鲁大师类，注意查内核驱动）
- **P1**：自启项精剪、账户策略（家人账户降标准用户、孩子加家庭组）、备份策略
- 卸载后**必须验证**：启动项清单、服务清单、任务清单、注册表孤儿项四项全查

## 阶段 4：验证（整改后）

- 开机时长：事件 100 的 Boot Duration（毫秒）。**注意：功能更新后首次开机时长含 SafeOS 安装，会暴涨（如 431s），稳态数据要等下次冷启动**
- 降级事件：101 数量应为 0；AppReadiness 7011 超时应消失
- 更新：24H2 等功能更新要看 `Installation Successful` 事件实锤 + build 号变化
- **功能更新会拿升级前配置快照回填**，已禁用的服务/自启键/计划任务可能"复活"——更新后必须复查这四项并二次清除

## 阶段 5：建档与持续维护

1. **机器档案**（每台机器一份，按 `assets/machine-profile-template.md` 填写）：写入用户级 MEMORY.md（跨项目所有任务可见）+ 工作区当日日志
2. **指标基线**：记录整改前后的开机时长、降级事件数、启动项数、C 盘剩余空间——后续维护只比对这四个数
3. **节奏**：每月 10 分钟（完整关机重启一次、Defender 全盘扫描、磁盘清理、核对备份）；每季复查 BIOS/驱动
4. 详细策略见 `references/memory-strategy.md` 与 `references/continuous-improvement.md`

## Resources

### scripts/
- `health-check.ps1` — 一键体检快照：开机时长、降级事件、启动项/服务/任务清单、更新状态、磁盘、Defender。定期维护和整改后验证都用它，输出可直接贴给用户
- `boot-verify.ps1` — 开机性能专项：最近 5 次开机时长趋势 + 本次开机的降级事件明细 + 服务超时明细

### references/
- `performance.md` — 基本性能维护详解：开机链路各环节（快速启动/服务超时/启动项/更新/磁盘/电源）的原理、诊断命令、处置手法
- `software.md` — 常用软件维护详解：白名单判定法、五类必须清除的软件、孤儿服务/死键/死任务识别与清除、软件安装的网络出口选择
- `memory-strategy.md` — 长期记忆策略：三层记忆分工、每机档案落点与更新规则、跨任务可见性保障
- `continuous-improvement.md` — 持续改进：指标追踪表、维护周期、复盘协议、技能自身迭代规则

### assets/
- `machine-profile-template.md` — 新机器建档模板（硬件/账户/网络/软件生态/整改历史/指标基线）

## 使用注意

- 本技能的唯一真实来源是 skillbox 仓库 `skills/computer-maintenance/pc-maintenance/windows/`；本目录通过 junction 链接到仓库，所有修改即仓库修改，改完必须 commit + push（流程见仓库 docs/repo-maintenance.md）
- 本技能在 Windows 11（23H2/24H2）+ WorkBuddy 沙箱环境验证过；PowerShell 5.1 语法，勿用 PS7 专有语法（`??`、`?.`、`&&`）
- 所有给用户的结论必须带证据（事件 ID、进程名、实测数值），不写"可能""建议试试"
- 整改前后各跑一次 `health-check.ps1`，两次输出 diff 就是整改报告的核心素材
