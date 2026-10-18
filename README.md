# skillbox — 老辛的个人技能库

一个 Git 仓库管理所有自研技能（Skills）：按使用类型分类，每个分类支持多种 OS 版本，
在 GitHub 公开备份。**本仓库是所有技能的唯一真实来源（Single Source of Truth）。**

## 设计原则

1. **一个仓库管所有技能**：不按技能建库，统一导航、统一版本、统一备份
2. **按使用类型分类**：目录即分类，如 `computer-maintenance`（电脑维护）
3. **多 OS 版本**：同一技能按 OS 分版本目录，Windows / macOS / Linux 各自演进
4. **公开备份 + 受控贡献**：GitHub 公开库即异地备份；许可证允许自由使用，禁止商用
   和修改后分发，欢迎提修改建议（见 [CONTRIBUTING.md](CONTRIBUTING.md)）
5. **可持续维护**：新技能、新分类、升级、废弃都有既定流程
   （见 [docs/repo-maintenance.md](docs/repo-maintenance.md)）

## 仓库结构

```
skillbox/
├── README.md                    ← 本文件：技能导航 + 升级说明
├── LICENSE                      ← CC BY-NC-ND 4.0 全文
├── CONTRIBUTING.md              ← 如何提修改建议
├── CHANGELOG.md                 ← 全库变更日志
├── docs/
│   ├── repo-maintenance.md      ← 库维护方法论（增/改/废/多机同步）
│   └── os-variants.md           ← 多 OS 版本规范
└── skills/                      ← 所有技能（唯一命名空间）
    └── <分类>/                   ← 按使用类型分类
        └── <技能名>/
            ├── README.md        ← 技能族说明 + 各 OS 版本总览
            ├── shared/          ← 跨 OS 共享内容（可选）
            ├── windows/         ← Windows 版（含 SKILL.md，可被加载）
            ├── macos/           ← macOS 版
            └── linux/           ← Linux 版
```

## 技能导航

| 技能 | 分类 | 可用系统 | 当前版本 | 状态 | 说明 |
|---|---|---|---|---|---|
| pc-maintenance | computer-maintenance | Windows | 1.0.0 | ✅ 活跃 | Windows 电脑全面维护：体检→整改→验证→建档→持续维护 |

> 新增/升级/废弃技能后，必须同步更新本表和 [CHANGELOG.md](CHANGELOG.md)。

## 快速开始（新机器部署）

每台机器做两件事：clone 本仓库到固定路径 → 用 junction（Windows）或符号链接
（macOS/Linux）把技能目录接进 WorkBuddy 技能目录 `~/.workbuddy/skills/<技能名>`。

```bash
# 1. 克隆（所有平台；Windows 下即 %USERPROFILE%\skillbox）
git clone https://github.com/<你的GitHub用户名>/skillbox.git ~/skillbox

# 2a. Windows（junction，无需管理员权限）
cmd /c mklink /J "%USERPROFILE%\.workbuddy\skills\pc-maintenance" "%USERPROFILE%\skillbox\skills\computer-maintenance\pc-maintenance\windows"

# 2b. macOS / Linux（符号链接，以 macos 版为例）
ln -s ~/skillbox/skills/computer-maintenance/pc-maintenance/macos ~/.workbuddy/skills/pc-maintenance
```

3. 重启 WorkBuddy（或新开会话），技能出现在可用技能列表即成功。

注意事项：

- 链接目标必须位于仓库内；**移动或删除仓库 = 技能失效**，重新 clone 后重建链接即可
- 链接是双向的：通过链接目录的修改就是仓库修改，改完记得 commit + push
- 同一台机器上，同一技能只接一个 OS 版本
- junction 创建失败先检查链接路径是否已存在（已存在先删旧目录/旧链接）

## 升级说明

```bash
cd ~/skillbox
git pull --ff-only        # 只接受快进；出现 diverged 先看 docs/repo-maintenance.md 第 6 节
```

升级后必做三件事：

1. **读 [CHANGELOG.md](CHANGELOG.md)**：本次更新影响了哪些技能、用法有无变化
2. **验证技能可用**：新会话中确认技能能被加载和触发
3. **有脚本的技能跑一次自检**（如 pc-maintenance 的 `health-check.ps1`），
   确认脚本未因升级损坏

版本号规则（semver，每个技能的每个 OS 版本独立计数）：

- `major`：方法论 / 目录结构 / 命令不兼容变更
- `minor`：新增内容（新参考文档、新检查项）
- `patch`：文字修正、脚本 bug 修复

版本标签：`<分类>/<技能>/<os>/v<版本>`，例：`computer-maintenance/pc-maintenance/windows/v1.1.0`。

## 维护入口

| 我要… | 去看 |
|---|---|
| 加新技能 | docs/repo-maintenance.md 第 1 节 |
| 加新分类 | docs/repo-maintenance.md 第 2 节 |
| 升级某个技能 | docs/repo-maintenance.md 第 3 节 |
| 废弃某个技能 | docs/repo-maintenance.md 第 4 节 |
| 新建某技能的 macOS/Linux 版 | docs/os-variants.md |
| 多机器同步 | docs/repo-maintenance.md 第 6 节 |
| 提修改建议 | CONTRIBUTING.md |

## 许可证

[CC BY-NC-ND 4.0](LICENSE)：任何人可自由使用、分享本仓库内容；**不得商用；
不得修改后分发；可向作者提修改建议**。
