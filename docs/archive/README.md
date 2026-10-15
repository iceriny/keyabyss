# 历史归档

这里保留对当前开发仍有取证价值的实施、失败、技术取舍与验收记录。正文中的“当前”“下一步”“已完成”属于当时语境，不构成现在的状态、待办或 Agent 指令。有效入口见[文档导航](../README.md)、[阶段总结](../STAGE-SUMMARY.md)和 [TODO](../TODO.md)。

重复规范、旧待办、已取消的候选设计和一次性原始报告已退出文档树；原文可从 Git 历史查询。本地待删除副本保留在 `.delete/cleanup-20261013/`，不作为文档依赖。

## 迁移与构筑记录

| 资料 | 历史用途 |
| --- | --- |
| [迁移前阶段总结](pre-godot/STAGE-SUMMARY.md)、[技术快照](pre-godot/TECHNICAL-SNAPSHOT.md)、[验证说明](pre-godot/TESTING.md) | Web 实现与迁移起点，源码路径以 `legacy/web/` 为基准 |
| [2026-10-08 构筑体系记录](2026-10-08-build-system/README.md) | M3／M4 实际接线、失败与范围收缩证据 |
| [旧系统实施](COMBAT-IMPLEMENTATION.md)、[有限资源实施流水](build-system-design/08-IMPLEMENTATION.md) | 公共契约、派生与防御的实施过程 |
| [旧统一验收](COMBAT-ACCEPTANCE.md) | 工程结果、历史采样和成长门槛失败 |
| [架构实施](ARCHITECTURE-IMPLEMENTATION.md)、[架构原案](ARCHITECTURE.md) | 旧模块形成过程，不锁定当前架构 |
| [旧验证指南](TESTING.md)、[验收流水](TESTING-HISTORY.md)、[更新记录](CHANGELOG.md) | 历史命令、范围、结果与限制 |

## 视觉与交互证据

| 资料 | 历史用途 |
| --- | --- |
| [图谱验收](TALENT-NETWORK-ACCEPTANCE.md)、[UI与性能](UI-PERFORMANCE-ACCEPTANCE.md) | 已取消图谱的历史问题与实际验收，不产生恢复义务 |
| [战斗表现](COMBAT-VISUALS.md)、[墨境背景](ARCANE-BACKGROUND.md)、[菜单表现](MENU-PRESENTATION.md) | 曲线、晶体、雷电、背景和菜单取舍 |
| [冲击波](SHOCKWAVES.md)、[输入与法阵](RITUAL-UPDATE.md)、[防御可读性](COUNTER-AND-READABILITY.md) | 局部表现修正与验收 |
| [文本与提示](TEXT-AND-TOOLTIPS.md)、[交互记录](INTERACTION.md) | 旧文本与输入行为 |
| [渲染讨论](rendering-discussion.md) | 材质成本判断的原始来源 |

## 战斗、素材与工具证据

| 资料 | 历史用途 |
| --- | --- |
| [敌人变化](ENEMY-VARIETY.md)、[防御与节奏](DEFENSE-AND-PACING.md)、[进攻与记录](ASSAULT-AND-RECORDS.md) | 敌人、难度和结算实施 |
| [旧平衡](BALANCE.md) | 历史数值与失败边界，不能证明当前四书均衡 |
| [素材与火焰](ASSETS-AND-FLAME.md)、[音效工具](AUDIO-SYSTEM.md)、[全屏与词库](FULLSCREEN-AND-VOCABULARY.md) | 旧资源来源、工具命令和打包过程 |

原始日志与截图通常位于已忽略的 `.temp/`，不会随仓库分发；历史引用不保证文件仍在原处。必要结论和失败边界保留在上述记录中。
