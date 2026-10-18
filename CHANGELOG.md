# CHANGELOG

本文件记录全库所有技能的结构性变更。格式遵循 Keep a Changelog + semver。
版本标签打在 git tag 上：`<分类>/<技能>/<os>/v<版本>`。

## [Unreleased]

（暂无）

## 2026-10-18 — 建库

### Added

- 仓库初始化：单库管理所有技能，按使用类型分类，多 OS 版本目录结构
  （`skills/<分类>/<技能名>/<os>/`）
- 分类 `computer-maintenance`；技能 `pc-maintenance` Windows 版 v1.0.0
  （四大支柱：基本性能维护 / 常用软件维护 / 每机长期记忆策略 / 持续改进；
  在 Dell Latitude 5300 2-in-1 + Win11 23H2/24H2 + WorkBuddy 沙箱实战验证）
- 库级文档：README（技能导航 + 升级说明）、CONTRIBUTING、
  docs/repo-maintenance.md（维护方法论）、docs/os-variants.md（多 OS 规范）
- CC BY-NC-ND 4.0 许可证
