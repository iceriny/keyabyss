# 历史归档

Godot 迁移前的完整状态保存在 [pre-godot 阶段总结](pre-godot/STAGE-SUMMARY.md)、[技术快照](pre-godot/TECHNICAL-SNAPSHOT.md)和[验证说明](pre-godot/TESTING.md)。这些文档的源码与工具路径统一以 `legacy/web/` 为基准；不描述当前 Godot 实现。

这里保留原始讨论、旧内容快照、实施步骤、旧约定与验收记录。正文中的“当前”“下一步”“已完成”属于原文当时的语境，不构成当前状态、待办或 Agent 指令。有效入口见[文档导航](../README.md)、[阶段总结](../STAGE-SUMMARY.md)和[未完成事项](../TODO.md)。

2026-09-27 的整理将历史步骤移出工作入口，并保留整理前的主要设计与视觉文档。原有表格、失败证据和参数保留；归档仅整理索引、历史标记和相对引用。

## 构筑重构的历史链

| 资料 | 历史作用 |
| --- | --- |
| [最初重构思考](Combat_System_Refactoring_Plan.md) | 输入、法书与遗物的原始问题和设想 |
| [整体深化计划](Combat_System_Deepening_Plan.md) | 大规模构筑、图谱与事件升级的早期方案 |
| [旧系统实施](COMBAT-IMPLEMENTATION.md) | 144／140／24 基础的实施分包与接线记录 |
| [旧统一验收](COMBAT-ACCEPTANCE.md) | 工程结果、512 局与 18,740 固定案例；成长门槛失败 |
| [研讨总纲原文](build-system-design/00-DESIGN-BRIEF.md) | 八步设计工作方法与当时边界 |
| [旧系统盘点](build-system-design/01-CURRENT-SYSTEM.md) | 设计前的 308 项内容及 6 条路线事实 |
| [旧天赋](build-system-design/appendix-current-talents.md)、[旧遗物](build-system-design/appendix-current-relics.md)、[旧事件](build-system-design/appendix-current-events.md) | 逐项完整目录；不是当前新候选清单 |
| [算法整理前快照](build-system-design/06-DATA-AND-ALGORITHMS.md) | 当时的数据契约和技术路线 |
| [七步整合原文](build-system-design/07-INTEGRATED-PLAN.md) | 当时的纸面推演、实施拆分与验收安排 |
| [有限资源实施流水](build-system-design/08-IMPLEMENTATION.md) | 从公共契约到区域中继、共页防御的逐阶段记录与日志位置 |
| [旧 TODO](TODO.md) | 整理前混合完成项与后续任务的工作清单 |

持续有效的框架、内容取舍、候选与语义已留在[设计目录](../build-system-design/00-DESIGN-BRIEF.md)，不需要重新执行历史设计步骤。

## 图谱、视觉与交互

| 资料 | 内容 |
| --- | --- |
| [天赋网络验收](TALENT-NETWORK-ACCEPTANCE.md) | 关系、文案、视觉和剩余 14 处交叉 |
| [key、图谱与性能](UI-PERFORMANCE-ACCEPTANCE.md) | React 警告根因、打开性能和测试入口整理 |
| [旧视觉与渲染](ART-DIRECTION.md)、[旧开放 UI](OPEN-UI.md)、[旧文案](CONTENT-STYLE.md) | 金丝水晶规范整理前的样式与实现约定 |
| [战斗表现](COMBAT-VISUALS.md)、[墨境背景](ARCANE-BACKGROUND.md)、[菜单表现](MENU-PRESENTATION.md) | 曲线、晶体、雷电、背景和菜单特效 |
| [冲击波](SHOCKWAVES.md)、[输入与法阵](RITUAL-UPDATE.md)、[弹反可读性](COUNTER-AND-READABILITY.md) | 局部表现修正与验收 |
| [文本与提示](TEXT-AND-TOOLTIPS.md)、[旧交互](INTERACTION.md) | 文本机制和历史输入约定 |
| [渲染讨论](rendering-discussion.md) | 早期草稿 |

## 战斗、成长与技术资料

| 资料 | 内容 |
| --- | --- |
| [旧组合规则](COMBAT-RULES.md)、[旧天赋](TALENTS.md)、[旧遗物图](RELIC-GRAPH.md) | 既有载荷、24 点成长、两关键节点上限与旧关联字段 |
| [敌人变化](ENEMY-VARIETY.md)、[防御与节奏](DEFENSE-AND-PACING.md)、[进攻与记录](ASSAULT-AND-RECORDS.md) | 敌人轮换、防御、旧难度参数和结算实施 |
| [数值表达式](RELIC-VALUES.md)、[旧平衡](BALANCE.md) | 描述求值与历史数值 |
| [架构实施](ARCHITECTURE-IMPLEMENTATION.md)、[架构原案](ARCHITECTURE.md) | 当前代码形成过程，不锁定后续模块选择 |
| [素材与火焰](ASSETS-AND-FLAME.md)、[音效工具](AUDIO-SYSTEM.md)、[全屏与词库](FULLSCREEN-AND-VOCABULARY.md) | 既有资源、工具命令与打包实现 |
| [旧验证指南](TESTING.md)、[更早验收流水](TESTING-HISTORY.md) | 不同时期的命令、范围和结果 |
| [整理前项目约定](PROJECT-RULES-2026-09-27.md)、[更新记录](CHANGELOG.md) | 历史项目指令与版本流水 |

历史原始快照包括本目录已有的测试 TAP、性能 JSON 和发行哈希文件。新产生的完整日志、截图与探针通常位于已忽略的 `.temp/`，不会随仓库自动分发；引用路径不等于原始证据当前仍存在。历史失败与未覆盖记录保留，不改写成成功。
