# 整体重构实施记录

> 历史归档：保留当时的方案、状态或检查结果，不作为当前待办、完成声明或实施约束。当前入口见[文档导航](../README.md)。

分支：`codex/combat-system-deepening`。设计契约见 [整体计划](Combat_System_Deepening_Plan.md) 与 [统一收益模型](../COMBAT-BALANCE-DESIGN.md)。阶段结果以实际接入和验收为准，不以新增文件数量认定完成。

## 难度目标

后两个难度要求足够的天赋投入、合理的构筑和应对遭遇的能力。高输入速度不能让初始成长账号稳定通关；中等输入水平在天赋与构筑投入充分、局内获得较好机会时，有实际可复现的通关路径。

不设置隐藏的天赋点数伤害惩罚或账号等级通关锁。难度通过敌人组织、同时存在的压力、阶段耐久、资源损耗和构筑成长曲线实现；基本小怪维持低血量，慢输入不额外失去联动资格。数值验收将分别比较初始/充分天赋、中等/高手输入、普通/有利获取路线，避免用平均值混合这些人群。

## 阶段状态

- P0：图谱、法术片段、灼烧贡献、事件事务与有限回执契约已落盘；收益与难度目标采用既定设计口径。
- P1：共享图视口与确定性布局生成器已接入。语义层级形成区域内弧环，主书与共用区域形成宏观星环；两张图使用同一生成器、路由、空间索引和交互组件。
- P2：人工供给、片段拆分、复写、晶壳、护持、热加工、中继、聚合、纸灵运输、逐来源灼烧与有限回收已接入正式模拟。
- P3：24 个事件定义及冻结选项、单次提交、演化替换、奖励预支、房/章到期与先试炼后兑现已接入；图关系使用带图谱类型的节点引用，避免天赋与遗物同 ID 混淆。
- P4：144 个天赋、140 件遗物及能力连接节点已接入双图；新增 72 件遗物有矢量图形，包含 12 个机制族及互斥演化、连接件和事件变体。
- P5：编队与三个 Boss 的阶段压力、最后两档难度参数、短语输入和 14 套学习构筑已接入；已执行 512 局远征、18,740 个固定场景案例及事件/Boss 专项。初始高手的后两档通关结果不满足成长门槛，须校准后重新验收。
- P6：天赋图版本迁移、普通/God 数据隔离、隔离模拟演示和最近 128 条资源流转战报已接入。类型、单元回归、架构、发行构建与桌面布局检查已通过；集成与数值覆盖的实际边界见 [统一验收](COMBAT-ACCEPTANCE.md)。

## 已接入的主要入口

| 职责 | 入口 |
| --- | --- |
| 图定义、布局生成与产物 | `src/content/graphs.ts`、`src/shared/graph-layout.ts`、`tools/graphs.mjs`、`src/generated/graph-layouts.ts` |
| 共用图视口与双图 | `src/ui/GraphViewport.tsx`、`TalentPanel.tsx`、`RelicGraphPanel.tsx` |
| 构筑编译与资源执行 | `src/shared/combat-build.ts`、`src/simulation/spells/packets.ts`、`systems/WeaveSystem.ts`、`systems/FlameSystem.ts` |
| 本局事件事务 | `src/content/build-events.ts`、`src/simulation/progression/BuildEventSystem.ts`、`src/ui/EventPanel.tsx` |
| 学习与因果回执 | `src/content/build-examples.ts`、`src/application/BuildDemonstration.ts`、`src/ui/BuildTraceDetails.tsx` |
| 通用收益评估 | `tools/build-balance.mjs`、`tools/balance-model.mjs`、`tools/build-balance.config.json` |

## 当前证据与待验范围

统一验收证据位于 `.temp/combat-acceptance/`。259 项单元检查已通过，包含双图产物的确定性与空间裁剪、有限资源、事件事务、短语输入和存档规则；发行构建校验了 159 个文件及 7z/zip 压缩包。检查命令、失败与修复过程、数值口径和未达标项见 [统一验收](COMBAT-ACCEPTANCE.md)。

执行交接保存在 `.temp/combat-implementation/` 下，各模块包含源码差异与报告。已替换的旧天赋源文件放在 `.delete/combat-implementation-original/`，该目录由 Git 排除。

验收持续核对资源同份双领、停笔与跨房收束、事件到期、旧档点数保留、双图桌面交互，以及学习样本实际可观察的差异。规则变化后的旧行为断言按最终语义审查，不能把旧统计直接视作当前通过证据。

评估工具以正式模拟和真实获取/事件流程取数，保留失败、未覆盖、超时与缺少适配的案例。Boss 生命周期单独观察，尚不强行折算为固定目标进度评分。战报回执记录已付片段的资源流转，不覆盖所有历史法书钩子，也不等同于完整伤害日志。

难度与收益系数目前是待校准的初值。尚不能声称已经达到“初始高手不能稳定通关最后两档、中等水平成熟构筑可借有利机会通关”的数值结果。
