# 多 OS 版本规范

同一技能的不同 OS 版本是"同一方法论的不同落地"，不是同一份文件的多份拷贝。

## 目录结构

```
skills/<分类>/<技能名>/
├── README.md          ← 技能族说明：各 OS 版本状态总览
├── shared/            ← 跨 OS 共享内容（可选，不被技能加载器直接加载）
│   └── ...
├── windows/           ← Windows 版（可独立加载的技能目录）
│   ├── SKILL.md
│   ├── scripts/
│   ├── references/
│   └── assets/
├── macos/             ← macOS 版
└── linux/             ← Linux 版
```

放置判定原则：

- **OS 特定的**（命令、路径、服务管理、脚本）→ 放对应 OS 目录
- **OS 无关的**（方法论文字、判定标准、检查清单框架）→ 放 `shared/`，
  由各 OS 版本 SKILL.md 引用；也可以先只做 Windows 版，成熟后再上抽 shared

## SKILL.md 的 OS 标识

每个 OS 版本的 frontmatter：

```yaml
name: <技能名>       # 各版本同名（同名才能被识别为"同一技能"）
os: windows          # windows / macos / linux
version: 1.0.0       # 各 OS 版本独立版本号
```

## 版本号规则

- 各 OS 版本**独立计数**：Windows 版 v2.1.0 与 macOS 版 v1.0.0 可以并存
- 一个方法论变更要落到多个 OS 时，各版本分别改、分别打 tag
- 技能族 README 维护一张"OS × 版本 × 状态"总览表

## 新建一个 OS 版本

1. 从最成熟的版本（或 `shared/`）拷贝方法论骨架
2. 逐条翻译成本 OS 的做法，常见差异：
   - 服务管理：Windows `Invoke-CimMethod` / `sc.exe`；macOS `launchctl`；Linux `systemctl`
   - 路径与用户目录：`%USERPROFILE%` / `~` / `$HOME`
   - 脚本语言：Windows 优先 PowerShell 5.1（**必须 UTF-8 带 BOM**）；Unix 用 bash
   - 包管理：winget / brew / apt、dnf、pacman
   - 还原点：`Checkpoint-Computer` / Time Machine / timeshift、btrfs 快照
3. **不能照抄的命令必须重写并实跑验证**
4. frontmatter 设 `os`，`version: 1.0.0`（新 OS 版从 1.0.0 起）
5. 更新技能族 README 总览表 + 根 README 导航表 + CHANGELOG

## OS 能力速查（规划参考，各版本建立时以实测为准）

| 能力 | Windows | macOS | Linux |
|---|---|---|---|
| 开机性能数据 | 事件 100/101（Diagnostics-Performance） | `log show --last boot` | `systemd-analyze` |
| 服务管理 | `Get-Service` / CIM | `launchctl` | `systemctl` |
| 计划任务 | 任务计划程序 / `Get-ScheduledTask` | launchd plist | systemd timer / cron |
| 还原点 | `Checkpoint-Computer` | Time Machine | timeshift / btrfs 快照 |
| 脚本注意 | PS 5.1 语法 + UTF-8 BOM | zsh / bash | bash + 发行版差异 |
