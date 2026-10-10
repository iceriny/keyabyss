# 文档导航

有效产品规则、当前代码状态、实施交接和历史证据分别维护。主工程为根目录 Godot，当前实施方向是恢复打字核心与重构前 Web 程度的局内构筑。

## 接手入口

| 要了解什么 | 入口 | 职责 |
| --- | --- | --- |
| 下一位实施者从哪里开始 | [实施交接](migration/AGENT-HANDOFF.md) | 已定范围、准确 Web 基线、当前依赖、S1 操作顺序与后续边界 |
| 游戏应该是什么 | [产品设计](PRODUCT-DESIGN.md) | 打字、四书、局内遗物、线性成长、最高档与保留遗物升档 |
| 四书怎样战斗与成长 | [四书战斗机制](FOUR-BOOKS-DESIGN.md) | 直接施法、第三次强化、闪避、终极、状态点数、场景优势与首轮定参 |
| 当前实际做到哪里 | [阶段总结](STAGE-SUMMARY.md) | 收缩后的正式流程、验证证据及尚未完成的体验与发行边界 |
| 有什么没完成 | [TODO](TODO.md) | 唯一工作清单 |
| 阶段顺序与技术边界 | [实施方案](migration/PLAN.md) | S1–S4、状态所有权、原生实现和出口 |
| 当前源码入口 | [实现快照](TECHNICAL-SNAPSHOT.md) | 实際文件与职责，不规定全部继续保留 |
| 怎样核对旧玩法和素材 | [数据与素材映射](migration/DATA-AND-ASSETS.md)、[体验映射](migration/EXPERIENCE-MAP.md) | Git 基线、旧入口、素材来源与体验边界 |
| 怎样启动和观察 | [工具链](migration/TOOLCHAIN.md) | 引擎锁、CLI、生成预览与导出 |
| 怎样选择验证 | [TESTING](TESTING.md)、[收益与难度评估](COMBAT-BALANCE-DESIGN.md) | 保留行为的最小检查、完整内容评估和最高档门槛 |

## 专题规范与工具

| 资料 | 职责 |
| --- | --- |
| [金丝水晶](ART-DIRECTION.md)、[开放 UI](OPEN-UI.md) | 材质、画面层级、固定操作与内部滚动 |
| [文案规范](CONTENT-STYLE.md) | 词咒、条件、效果、代价和玩家可读说明 |
| [四书实施](migration/PLAN.md#四书战斗机制实施) | 输入契约、分书接入、遗物与正式流程、场景校准的依赖与出口 |
| [四书遥测参考](COMBAT-TELEMETRY.md) | 未来可选的玩法事件、观察问题与指标口径 |
| [UI 实践](migration/UI-IMPLEMENTATION-LESSONS.md)、[M2 实施经验](migration/M2-IMPLEMENTATION-LESSONS.md) | 已遇到的问题、原生取舍和历史证据边界 |
| [流体工具](FLUID-EFFECTS.md) | 当前原生流体、预设、照明和质量成本 |
| [渲染准备方案](migration/PLAN.md#渲染准备与原生资源实施方案) | 首屏反馈、原生场景／材质、计算管线复用、Shader Baker 与必要验收 |
| [战斗算法优化](migration/PLAN.md#战斗算法优化)、[实施记录](migration/COMBAT-ALGORITHM-IMPLEMENTATION.md) | 查询、首击选择与 .NET 闪避评分核；保留碰撞／视觉语义，记录性能取舍及验证 |
| [音频索引](audio/README.md) | 原件、切片和实际事件接线 |
| [Git 与资产方案](GIT-AND-ASSETS.md) | 独立的仓库、LFS 与跨设备协作工作 |

## 历史资料

[2026-10-08 构筑体系归档](archive/2026-10-08-build-system/README.md)保留被取消的天赋／加工／事件设计、旧阶段计划、M3／M4 验收以及整理前文档。更早资料见[历史总入口](archive/README.md)。

归档中的候选数量、路径算法、参数、失败和“下一步”属于当时状态，不构成当前完成义务。当前 `legacy/web/` 也已经含构筑重构；玩法恢复以交接中锁定的 Git 提交为准。

## 维护方式

产品行为写在产品设计与专题；实际接入写阶段总结和实现快照；待办只写 TODO；实施路线和开工条件写交接与实施方案。详细过程和过期要求归档，不建立第二份活动计划。

展示定义、代码接入、检查通过和实际体验分别报告。文档调整不等于游戏已经改完，历史验收不自动覆盖恢复后的规则。
