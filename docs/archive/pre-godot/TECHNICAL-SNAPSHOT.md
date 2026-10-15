# 当前实现快照

这是 2026-09-27 整理时的代码地图，供理解已完成的工作和定位缺口。目录、技术栈、时钟单位及构建方式描述当前仓库，不要求后续设计沿用这些实现选择。实际完成状态以[阶段总结](STAGE-SUMMARY.md)为准。

## 当前运行组成

仓库使用 TypeScript、React 和 Vite；战场采用 Three.js、实例化几何、postprocessing 和 three.quarks，文字及危险提示另行绘制。菜单与战场共用背景表达。`NativeBattleRenderer`、`NativeSpellBattle` 中的 Native 是现有模块命名，不构成桌面原生发行已经完成的声明。

当前运行与打包方法见[贡献指南](../../../legacy/web/CONTRIBUTING.md)。其浏览器、离线包、CSS 视口和资源加载说明只适用于现有程序。历史画面使用过多组设计坐标、世界距离与纹理尺寸，详见渲染归档，这些数值不作为统一视觉规范。

## 主要入口

| 职责 | 当前文件或目录 | 边界 |
| --- | --- | --- |
| 会话与状态 | `src/application/SessionController.ts`、`src/simulation/CombatSimulation.ts`、`src/simulation/Runtime.ts` | 组装内容、输入、战斗与显示 |
| 新构筑契约 | `src/contracts/build-*.ts`、`src/contracts/native-spells.ts` | 定义、资源、规则、对象、执行与基础法术 |
| 新规则及展示 | `src/content/build/native.ts`、同目录各机制文件、`presentation.ts` | 83／56 规则登记与 206／171 展示目录分别维护 |
| 编译与语义 | `src/shared/build/compile.ts`、`conditions.ts`、`operations.ts`、`semantics.ts` | 合法配置快照、条件、操作和概念关系 |
| 资源与阶段 | `ResourceLedger.ts`、`SpellResourceRuntime.ts`、`SpellRuleExecutor.ts`、`SpellLifecycle.ts`，均位于 `src/simulation/spells/` | 真实所有权、原子操作、阶段和生命周期 |
| 正式主术适配 | 同目录 `NativeSpellBattle.ts`、`ManualSpellIncome.ts`、`LetterOpportunities.ts` | 人工回执、法书形状、命中、字母与有限纸灵 |
| 旧战斗及剩余钩子 | `src/simulation/systems/WeaveSystem.ts`、`CastSystem.ts`、`DefenseSystem.ts`、`MovementSystem.ts`，`src/content/books/*/behavior.ts` | 未迁移构筑及原生次生效果仍使用这些入口 |
| 旧内容与事件 | `src/content/talents.ts`、`src/content/relics/`、`src/content/build-events.ts`、`src/simulation/progression/BuildEventSystem.ts` | 与新契约尚未完成全量贯通 |
| 图谱 | `src/content/graphs.ts`、`src/shared/graph-layout.ts`、`tools/graphs.mjs`、`src/generated/graph-layouts.ts` | 现有生成与产物；未达到新平面网络目标 |
| 图谱界面 | `src/ui/GraphViewport.tsx`、`TalentPanel.tsx`、`RelicGraphPanel.tsx` | 共享视口、全屏图、搜索与悬浮详情 |
| 成长与记录 | `src/application/talentProgression.ts`、`runArchive.ts`、`src/ui/BuildTraceDetails.tsx` | 字符结算、God 隔离及部分因果解释 |
| 画面与 UI | `src/rendering/`、`src/ui/open-ui.css`、`results.css`、`BattleReadouts.tsx` | 现有材质、文字、特效与页面布局 |
| 数值与说明 | `src/shared/ValueRules.ts`、`relic-values.ts`、`src/content/combat-values.ts`、`src/content/glossary.ts` | 现有表达式、预览与术语；仍需与新资源内容一致 |
| 通用评估 | `tools/build-balance.mjs`、`balance-model.mjs`、`build-balance.config.json` | 已有正式模拟评估工具，新内容覆盖仍待完善 |

## 已实现资源约束

当前固定点比例为 Q=1024，资源类型为 `power / work / cold / heat / charge / opportunity`。同一份资源只有一个 owner；费用、次数与归属变化成功提交后才发布对象状态。新对象编号不能重置来源领取记录，合并和拆分不能重复获得原收入。

只有真实人工输入提供制作收入；派生、回收和自动输入不再记一次完词。对象保存创建时的编译快照，后续取得内容不改写旧法术。房间结束清理在途引用与临时账户，只有明确允许的储备通过交接进入下一房。

局部账务检查已覆盖共同防御、持续剩余、运输和中继；仍有原生钩子与旧构筑入口未统一结算。不能将新账中的数值当作当前整局总资源或总伤害。

## 素材、声音与已有工具

法书图片和符文在 `art/`，字体源文件在 `public/font/`；现有发行工具生成所需资源。默认字体为汇文明朝体，辅助小字为京華老宋体 v3.0。来源和许可见[第三方声明](../../../legacy/web/THIRD_PARTY_NOTICES.md)。

声音已有片段索引、查询、预览、导出与按需构建工具；使用方式保存在[音效工具归档](../AUDIO-SYSTEM.md)。原始素材、片段边界和试听结果可用于理解现有声音意图。

素材加载、启动、词库、渲染、音频等原实施细节从[归档目录](../README.md)检索。它们是定位代码和历史问题的参考，不是当前必须补完的技术任务。
