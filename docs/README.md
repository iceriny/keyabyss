# 文档导航

有效产品规则、当前代码状态、实施交接和历史证据分别维护。主工程为根目录 Godot，当前实施方向是恢复打字核心与重构前 Web 程度的局内构筑。

## 接手入口

| 要了解什么 | 入口 | 职责 |
| --- | --- | --- |
| 下一位实施者从哪里开始 | [实施交接](migration/AGENT-HANDOFF.md) | 已定范围、准确 Web 基线、当前源码入口与保存／继承边界 |
| 游戏应该是什么 | [产品设计](PRODUCT-DESIGN.md) | 打字、四书、局内遗物、线性成长、最高档与保留遗物升档 |
| 四书怎样战斗与成长 | [四书战斗机制](FOUR-BOOKS-DESIGN.md) | 直接施法、第三次强化、闪避、终极、状态点数、场景优势与首轮定参 |
| 当前实际做到哪里 | [阶段总结](STAGE-SUMMARY.md) | 收缩后的正式流程、验证证据及尚未完成的体验与发行边界 |
| 有什么没完成 | [TODO](TODO.md) | 唯一工作清单 |
| 阶段顺序与技术边界 | [实施方案](migration/PLAN.md) | S1–S4、状态所有权、原生实现和出口 |
| 当前源码入口 | [实现快照](TECHNICAL-SNAPSHOT.md) | 实際文件与职责，不规定全部继续保留 |
| 怎样核对旧玩法和素材 | [数据与素材映射](migration/DATA-AND-ASSETS.md)、[体验映射](migration/EXPERIENCE-MAP.md) | Git 基线、旧入口、素材来源与体验边界 |
| 怎样启动和观察 | [工具链](migration/TOOLCHAIN.md) | 引擎锁、CLI、生成预览与导出 |
| 怎样发布测试包与正式包 | [Windows 发布流程](RELEASING.md) | 固定版本、导出、启动一次、压包上传 |
| 怎样选择验证 | [TESTING](TESTING.md)、[测试入口索引](../tests/README.md)、[收益与难度评估](COMBAT-BALANCE-DESIGN.md) | 按行为选择最小检查、完整内容评估和最高档门槛 |

## 专题规范与工具

| 资料 | 职责 |
| --- | --- |
| [金丝水晶](ART-DIRECTION.md)、[开放 UI](OPEN-UI.md) | 材质、画面层级、固定操作与内部滚动 |
| [文案规范](CONTENT-STYLE.md) | 词咒、条件、效果、代价和玩家可读说明 |
| [遗物与阅读系统](RELIC-SYSTEM.md) | 97件正式池及内容比例、人工触发与状态取舍、资格与奖励用途、共享说明、术语与Alt详情 |
| [四书实施](migration/PLAN.md#四书战斗机制实施) | 输入契约、分书接入、遗物与正式流程、场景校准的依赖与出口 |
| [敌人与弹幕](ENEMY-AND-BARRAGE-RESEARCH.md) | 源码与外部灵感、首批三敌规则、后续候选与性能采用条件；实体交互、造型辨识、HDR／流体分工及动态验证的通用经验 |
| [四书遥测参考](COMBAT-TELEMETRY.md) | 未来可选的玩法事件、观察问题与指标口径 |
| [UI 实践](migration/UI-IMPLEMENTATION-LESSONS.md)、[战斗实施经验](migration/M2-IMPLEMENTATION-LESSONS.md) | 输入、接触、表现与工具实践；第12节整理模型评估、状态交接、回调重入和验证判定的通用方法 |
| [流体工具](FLUID-EFFECTS.md) | 当前原生流体、预设、照明和质量成本 |
| [全面性能研究](PERFORMANCE-RESEARCH.md)、[实施路线](migration/PLAN.md#全面性能优化)、[实施记录](migration/PERFORMANCE-IMPLEMENTATION.md) | 当前工作区四书／弹幕／反制实测、成本地图、跨设备目标、逐批改动与实际收益 |
| [视效分级方案](VISUAL-QUALITY-DESIGN.md) | 低／中／高画质的目标外观与成本，流体及减少动态的独立职责，群体预算、切换和验收；已接入实现，两组实测及限制见性能实施记录 |
| [渲染准备方案](migration/PLAN.md#渲染准备与原生资源实施方案) | 首屏反馈、原生场景／材质、计算管线复用、Shader Baker 与必要验收 |
| [战斗算法优化](migration/PLAN.md#战斗算法优化)、[实施记录](migration/COMBAT-ALGORITHM-IMPLEMENTATION.md) | 查询、首击选择与 .NET 闪避评分核；保留碰撞／视觉语义，记录性能取舍及验证 |
| [周期卡顿调查](migration/PERIODIC-STALL-INVESTIGATION.md) | 目标机复现、诊断对照、指标边界与WPR线程／GPU采集 |
| [音频库](../development/audio_library/README.md)、[音频接线](audio/README.md) | Agent 按描述、时长和变体组选择已切好的 WAV；原件映射与实际事件接线 |
| [Git 与资产开发](GIT-AND-ASSETS.md)、[实施记录](migration/ASSET-UPLOAD-IMPLEMENTATION.md) | 双仓版本锁、完整资产、单命令交接与实际恢复证据 |

## 候选研究

| 资料 | 职责 |
| --- | --- |
| [星空之书](STARRY-SKY-BOOK-RESEARCH.md) | 引力、吞噬与天体轨道的机制草案，主术／强化／闪避／终式、梦幻星海视效、现有遗物联动及专属候选；尚未实施或验证 |

## 历史资料

[历史总入口](archive/README.md)保留有取证价值的实施、失败与验收记录；[2026-10-08 构筑体系记录](archive/2026-10-08-build-system/README.md)用于解释旧接线和范围收缩。已取消的候选设计、重复规范与旧待办不再维护，原文可从 Git 历史查询。

归档中的候选数量、路径算法、参数、失败和“下一步”属于当时状态，不构成当前完成义务。当前 `legacy/web/` 也已经含构筑重构；玩法恢复以交接中锁定的 Git 提交为准。

## 维护方式

产品行为写在产品设计与专题；实际接入写阶段总结和实现快照；待办只写 TODO；实施路线和开工条件写交接与实施方案。详细过程和过期要求归档，不建立第二份活动计划。

展示定义、代码接入、检查通过和实际体验分别报告。文档调整不等于游戏已经改完，历史验收不自动覆盖恢复后的规则。
