# 仓库维护方法论

本文件是 skillbox 库的"宪法"：新技能、新分类、旧技能升级、旧技能废弃、多机器同步
都有专门流程。所有变更遵循同一循环：

```
改动 → 本地验证 → 更新文档（README/CHANGELOG）→ commit → push → 打 tag（如需要）
```

## 0. 角色与权限

- **作者 / 维护者**：老辛（唯一合并者）
- **其他人**：通过 Issue / PR 提修改建议（见 [CONTRIBUTING.md](../CONTRIBUTING.md)），无直接推送权
- **主开发机**：老辛日常使用的机器（当前：LAPTOP-QAB8ME2F，Windows）。
  其他机器默认只读使用（pull），确需修改时按第 6 节流程走

## 1. 新增技能

适用：想到一个新的方法论要沉淀成技能。

1. **定分类**：归入现有分类；都不合适才新建分类（见第 2 节）
2. **建目录**：`skills/<分类>/<技能名>/<os>/`；技能名 kebab-case，全库唯一
3. **写 SKILL.md**（技能唯一入口，frontmatter 必填）：
   ```yaml
   ---
   name: <技能名>          # 与目录名一致
   description: <什么场景用 + 覆盖什么 + 触发词>   # 写清楚，这是技能被触发的依据
   agent_created: true
   version: 1.0.0          # 从 1.0.0 起
   os: windows             # windows / macos / linux
   ---
   ```
4. **按需建子目录**：`scripts/`（可执行脚本）、`references/`（按需加载的详解）、
   `assets/`（模板等静态资产）；跨 OS 共享内容放 `skills/<分类>/<技能名>/shared/`
5. **本地验证**（全部通过才提交）：
   - [ ] 技能能被加载（新会话可见、描述能触发）
   - [ ] 脚本在目标 OS 实跑通过（.ps1 必须 UTF-8 带 BOM，原因见 pc-maintenance 铁律 6）
   - [ ] 无密钥 / 个人信息 / 机器特有绝对路径
6. **登记**：更新根 README 技能导航表 + 分类 README + CHANGELOG
7. **提交并打 tag**：`feat(<技能名>): 新增 <技能名> <os> 版 v1.0.0`，
   tag：`<分类>/<技能名>/<os>/v1.0.0`

## 2. 新增分类

适用：现有分类装不下新技能。分类之间应互斥，合起来覆盖全部"使用类型"。

1. 命名：kebab-case，按**使用类型**命名，不按技术命名
   （✅ `computer-maintenance`、`office-documents`；❌ `powershell-stuff`）
2. 建 `skills/<新分类>/README.md`：分类职责、收录技能清单、收录标准
3. 在分类下建第一个技能（走第 1 节流程）
4. 根 README 的仓库结构树补上新分类

## 3. 旧技能升级

触发来源：自己踩到新坑、用户反馈、OS 大版本变化（如 Win11 25H2）。

1. 定位版本目录 `skills/<分类>/<技能>/<os>/`，改内容（SKILL.md / references / scripts）
2. 本地验证：同第 1 节第 5 步（重点：脚本实跑）
3. 定版本号（semver，各 OS 版本独立计数）：
   - 方法论 / 结构 / 命令不兼容变更 → **major**
   - 新增检查项 / 参考文档 / 脚本 → **minor**
   - 错别字 / 脚本 bug 修复 → **patch**
4. 更新 frontmatter `version`；SKILL.md 正文如有版本相关说明一并改
5. CHANGELOG 追加条目：改了什么、为什么、影响哪些机器
6. 提交并打 tag：`feat/fix(<技能名>): <简述>`，tag `<分类>/<技能>/<os>/v<新版本>`
7. 同一变更若其他 OS 版本也需要 → 在各版本里分别改、分别打 tag

## 4. 旧技能废弃

适用：方法论过时、被新技能取代、不再维护。三级退场，至少给一个 minor 版本通知期：

1. **deprecated（公告期）**：frontmatter 加 `status: deprecated` 和
   `deprecated_notice: <替代方案或原因>`；技能 README 顶部贴公告；CHANGELOG 记录。
   技能仍可正常使用
2. **archived（归档）**：一个 minor 版本后，整目录移入
   `skills/<分类>/<技能名>/archive/<os>-v<最后版本>/`；根 README 状态列改为 📦 已归档
3. **removed（移除）**：仅当内容被新技能完全覆盖且无历史参考价值时，整目录删除
   （git 历史仍在，随时可找回）

任何一级退场都要：CHANGELOG 记录 + 根 README 导航表状态更新；其他机器 pull 后
检查自己的 junction 有没有指向被废弃 / 归档的目录，有就换。

## 5. 日常提交规范

- 一个 commit 一件事；message 用 conventional commits：
  `feat(<技能>):` / `fix(<技能>):` / `docs:` / `chore:`
- commit 前 `git status` 确认没误带机器特有文件
- 常用技能改完当天 push——GitHub 公开库就是异地备份，拖太久等于没备份

## 6. 多机器同步协议

**拓扑**：一个 GitHub 远端 + N 台机器各自 clone + junction/符号链接接入本地技能目录。

| 机器 | 角色 | 权限 |
|---|---|---|
| 主开发机（老辛日常 Windows） | 唯一改动源 | push |
| 其他机器（如 Mac mini） | 只读使用，要改时走"建议流" | 只 pull |

规则：

1. **所有机器 clone 到各自固定路径**（建议 `~/skillbox`），用 junction / 符号链接
   把技能接进 `~/.workbuddy/skills/<技能名>`（命令见根 README"快速开始"）
2. **非主开发机上要改技能的正确姿势**：本地改 → 自测通过 → push 远端 →
   主开发机 pull。禁止两台机器同时改同一文件
3. **pull 一律 `--ff-only`**：出现 diverged 说明有人绕过协议，先 `git log` 比对，
   默认以主开发机为准
4. **同步节奏**：技能有更新时；或每月一次例行 `git pull`
5. **换新机器**：clone → junction → 跑一次技能自检脚本 → 用技能的
   machine-profile-template 登记机器档案
6. **某机器停用某技能**：只删 junction（不动仓库），其他机器不受影响

## 7. 安全与红线

- 仓库内**禁止**出现：密钥 / Token / 密码、真实个人信息组合、机器特有绝对路径
  （用 `%USERPROFILE%`、`~` 或模板占位符代替）
- 机器档案类内容脱敏后才能入库
- 公开库：提交前按"全世界都能看到"审查
