# 当前天赋全量目录

> 历史归档：保留当时的方案、状态或检查结果，不作为当前待办、完成声明或实施约束。当前入口见[文档导航](../../README.md)。

[返回现状汇总](01-CURRENT-SYSTEM.md) · [研讨总纲](00-DESIGN-BRIEF.md)

基线 `767b349`，2026-09-23，共 144 个节点。按注册表原分组和顺序收录，不表示新系统应保留这些分组。

来源：[内容定义](../../../legacy/web/src/content/talents.ts)、[分配规则](../../../legacy/web/src/shared/talents.ts)。登记文案原样保留；本目录没有逐节点运行验证，也不把现有用语当作新文案标准。

“授予”是每次取得节点写入统计的原始增量，不等于最终伤害倍率；百分数、整数与布尔开关由执行代码解释。“能力前置”对应 `requires`，“节点前置”对应 `requiresNodes`，后者与路径连接是不同条件。未写特殊前置表示没有额外登记，仍须遵守相邻接入、预算、最多两个关键节点等公共规则。

“登记连接”保留原始 `links`；“实际邻接”补齐反向边，表示玩家可沿着连接接入的相邻节点，而不是必须全部购买的前置。当前共 156 条无向边。

根节点登记价格为 2 点；所选主书根节点实际免费。数值预算 `budget` 与购买价格 `cost` 分列，未登记预算不按 0 处理。

## 寒墨（frost，22 个）

### frost-root · 霜页

施法积累寒气，让冰晶法术参与碎裂和穿透。

- 分类：法书起点；学派 `frost`；价格 2；预算 未登记；主书为 `frost` 时免费。
- 授予：`{"crystalPayload":1}`；声明能力：`["cold"]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`cold-ink`、`frost-path-4`、`frost-path-3`。
- 实际邻接：霜·寒气强度Ⅰ（`cold-ink`）、霜·保存时间（`frost-path-3`）、霜·穿透次数（`frost-path-4`）。

### cold-ink · 霜·寒气强度Ⅰ

寒气强度 +0.2。

- 分类：普通强化；学派 `frost`；价格 1；预算 3。
- 授予：`{"coldStacks":0.2}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`rime`。
- 实际邻接：霜页（`frost-root`）、霜·寒气强度Ⅱ（`rime`）。

### frost-path-2 · 霜·法术伤害Ⅰ

法术伤害 +2.5%。

- 分类：普通强化；学派 `frost`；价格 1；预算 3。
- 授予：`{"spellPower":0.025}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`frost-path-11`。
- 实际邻接：霜·法术伤害Ⅱ（`frost-path-11`）、霜·寒气强度Ⅱ（`rime`）。

### frost-path-3 · 霜·保存时间

法术保存时间 +0.4 秒。

- 分类：普通强化；学派 `frost`；价格 1；预算 3。
- 授予：`{"carrierLifetime":0.4}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`frost-path-9`。
- 实际邻接：霜·法术存量（`frost-path-9`）、霜页（`frost-root`）。

### frost-path-4 · 霜·穿透次数

穿透次数 +1。

- 分类：普通强化；学派 `frost`；价格 1；预算 3。
- 授予：`{"payloadPierce":1}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`frost-path-6`。
- 实际邻接：霜·碎片威力（`frost-path-6`）、霜页（`frost-root`）。

### rime · 霜·寒气强度Ⅱ

寒气强度 +0.2。

- 分类：普通强化；学派 `frost`；价格 1；预算 3。
- 授予：`{"coldStacks":0.2}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`frost-path-2`。
- 实际邻接：霜·寒气强度Ⅰ（`cold-ink`）、晶构（`crystal`）、霜·法术伤害Ⅰ（`frost-path-2`）。

### frost-path-6 · 霜·碎片威力

分给碎片的威力 +2%。

- 分类：普通强化；学派 `frost`；价格 1；预算 3。
- 授予：`{"fragmentShare":0.02}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`frost-path-10`。
- 实际邻接：析晶（`frost-division`）、霜·碎片数量（`frost-path-10`）、霜·穿透次数（`frost-path-4`）。

### frost-path-7 · 霜·连锁距离

连锁距离 +18。

- 分类：普通强化；学派 `frost`；价格 1；预算 3。
- 授予：`{"chainReach":18}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`frost-path-12`。
- 实际邻接：霜·储备上限（`frost-path-12`）、霜·法术存量（`frost-path-9`）。

### frost-path-8 · 霜·减少损耗

法术加工保留的威力 +3%。

- 分类：普通强化；学派 `frost`；价格 1；预算 3。
- 授予：`{"materialConserve":0.03}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：无。
- 实际邻接：霜·碎片数量（`frost-path-10`）、封寒（`frost-preserve`）。

### frost-path-9 · 霜·法术存量

法术保存数量 +1。

- 分类：普通强化；学派 `frost`；价格 1；预算 3。
- 授予：`{"carrierCapacity":1}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`frost-path-7`。
- 实际邻接：霜·保存时间（`frost-path-3`）、霜·连锁距离（`frost-path-7`）、冰匣（`frost-vessel`）。

### frost-path-10 · 霜·碎片数量

碎片数量 +1。

- 分类：普通强化；学派 `frost`；价格 1；预算 3。
- 授予：`{"fragmentCount":1}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`frost-path-8`。
- 实际邻接：霜·碎片威力（`frost-path-6`）、霜·减少损耗（`frost-path-8`）。

### frost-path-11 · 霜·法术伤害Ⅱ

法术伤害 +2.5%。

- 分类：普通强化；学派 `frost`；价格 1；预算 3。
- 授予：`{"spellPower":0.025}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：无。
- 实际邻接：贯晶（`frost-needle`）、霜·法术伤害Ⅰ（`frost-path-2`）。

### frost-path-12 · 霜·储备上限

储备上限 +8。

- 分类：普通强化；学派 `frost`；价格 1；预算 3。
- 授予：`{"heatCapacity":8}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：无。
- 实际邻接：解冻出口（`frost-melt`）、霜·连锁距离（`frost-path-7`）。

### crystal · 晶构

冰晶法术可以碎裂；与热量配合时，将部分威力分给碎片。

- 分类：机制节点；学派 `frost`；价格 2；预算 6。
- 授予：`{"crystalPayload":1}`；声明能力：`["cold"]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`rime`。
- 实际邻接：合订·资源积累（`binding-bridge-1`）、霜·寒气强度Ⅱ（`rime`）。

### frost-vessel · 冰匣

用冰晶保存法术：可多保存 1 份，保存时间延长 1 秒。

- 分类：机制节点；学派 `frost`；价格 2；预算 6。
- 授予：`{"crystalStorage":1,"carrierCapacity":1,"carrierLifetime":1}`；声明能力：`["carrier"]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`frost-path-9`。
- 实际邻接：冷藏抄本（`cold-manuscript`）、霜·法术存量（`frost-path-9`）、护持·保存时间（`warding-bridge-1`）。

### frost-division · 析晶

碎裂时多产生 1 枚碎片，并把更多法术威力分给碎片。

- 分类：机制节点；学派 `frost`；价格 2；预算 6。
- 授予：`{"fragmentCount":1,"fragmentShare":0.06}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`frost-path-6`。
- 实际邻接：碎镜书写（`broken-mirror`）、霜·碎片威力（`frost-path-6`）、分合·连锁距离（`geometry-bridge-1`）。

### frost-needle · 贯晶

法术可多穿透 1 个敌人；分给碎片的威力减少。

- 分类：机制节点；学派 `frost`；价格 2；预算 6。
- 授予：`{"payloadPierce":1,"fragmentShare":-0.04}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`frost-path-11`。
- 实际邻接：霜·法术伤害Ⅱ（`frost-path-11`）、完整晶页（`whole-crystal`）。

### frost-preserve · 封寒

保存法术时损失的威力更少，保存时间延长 1 秒；释放晚 0.2 秒。

- 分类：机制节点；学派 `frost`；价格 2；预算 6。
- 授予：`{"materialConserve":0.12,"carrierLifetime":1,"carrierDelay":0.2}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`frost-path-8`。
- 实际邻接：霜·减少损耗（`frost-path-8`）。

### frost-melt · 解冻出口

冰晶中存有热量时，可以提前释放保存的法术。需要先学会保存法术。

- 分类：机制节点；学派 `frost`；价格 2；预算 6。
- 授予：`{"thermalRelease":1}`；声明能力：`[]`。
- 额外条件：能力全部满足 `["carrier"]`；无指定节点前置；无互斥组。
- 登记连接：`frost-path-12`。
- 实际邻接：霜·储备上限（`frost-path-12`）、易形·碎片威力（`transmutation-bridge-4`）。

### whole-crystal · 完整晶页

集中攻击更少的敌人，多穿透 1 个敌人；碎片数量减少。

- 分类：关键节点；学派 `frost`；价格 3；预算 9。
- 授予：`{"concentrate":1,"payloadPierce":1,"fragmentCount":-1}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；互斥组 `frost-form`。
- 登记连接：`frost-needle`。
- 实际邻接：贯晶（`frost-needle`）。

### broken-mirror · 碎镜书写

产生更多碎片，并把更多威力分给碎片；攻击范围更广，单枚威力更低。

- 分类：关键节点；学派 `frost`；价格 3；预算 9。
- 授予：`{"forkPayload":1,"fragmentCount":2,"fragmentShare":0.12}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；互斥组 `frost-form`。
- 登记连接：`frost-division`。
- 实际邻接：析晶（`frost-division`）。

### cold-manuscript · 冷藏抄本

冰晶可多保存 2 份法术，并优先留作防御；通常释放晚 0.6 秒。

- 分类：关键节点；学派 `frost`；价格 3；预算 9。
- 授予：`{"crystalStorage":1,"carrierRetain":1,"carrierCapacity":2,"carrierDelay":0.6}`；声明能力：`["carrier"]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`frost-vessel`。
- 实际邻接：冰匣（`frost-vessel`）。

## 灰烬（flame，22 个）

### flame-root · 焰页

施法积累热量，用于灼烧、储存和释放法术。

- 分类：法书起点；学派 `flame`；价格 2；预算 未登记；主书为 `flame` 时免费。
- 授予：`{"heatPayload":1}`；声明能力：`["heat"]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`warm-ink`、`flame-path-4`、`flame-path-3`。
- 实际邻接：焰·储备上限Ⅰ（`flame-path-3`）、焰·法力回收（`flame-path-4`）、焰·灼烧伤害（`warm-ink`）。

### warm-ink · 焰·灼烧伤害

灼烧伤害 +0.15。

- 分类：普通强化；学派 `flame`；价格 1；预算 3。
- 授予：`{"burnPower":0.15}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`ember`。
- 实际邻接：焰·灼烧时间（`ember`）、焰页（`flame-root`）。

### flame-path-2 · 焰·法术伤害Ⅰ

法术伤害 +2.5%。

- 分类：普通强化；学派 `flame`；价格 1；预算 3。
- 授予：`{"spellPower":0.025}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`flame-path-11`。
- 实际邻接：焰·灼烧时间（`ember`）、焰·法术伤害Ⅱ（`flame-path-11`）。

### flame-path-3 · 焰·储备上限Ⅰ

储备上限 +10。

- 分类：普通强化；学派 `flame`；价格 1；预算 3。
- 授予：`{"heatCapacity":10}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`flame-path-9`。
- 实际邻接：焰·储备上限Ⅱ（`flame-path-9`）、焰页（`flame-root`）。

### flame-path-4 · 焰·法力回收

剩余法力回收比例 +2.5%。

- 分类：普通强化；学派 `flame`；价格 1；预算 3。
- 授予：`{"recoveryEfficiency":0.025}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`flame-path-8`。
- 实际邻接：焰·碎片威力（`flame-path-8`）、焰页（`flame-root`）。

### ember · 焰·灼烧时间

灼烧时间 +0.15 秒。

- 分类：普通强化；学派 `flame`；价格 1；预算 3。
- 授予：`{"burnDuration":0.15}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`flame-path-2`。
- 实际邻接：焰·法术伤害Ⅰ（`flame-path-2`）、蓄热（`heat-payload`）、焰·灼烧伤害（`warm-ink`）。

### flame-path-6 · 焰·资源积累

施法资源积累速度 +4%。

- 分类：普通强化；学派 `flame`；价格 1；预算 3。
- 授予：`{"materialRate":0.04}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`flame-path-7`。
- 实际邻接：焰·保存时间（`flame-path-7`）、焰·储备上限Ⅱ（`flame-path-9`）。

### flame-path-7 · 焰·保存时间

法术保存时间 +0.4 秒。

- 分类：普通强化；学派 `flame`；价格 1；预算 3。
- 授予：`{"carrierLifetime":0.4}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：无。
- 实际邻接：余温（`flame-economy`）、焰·资源积累（`flame-path-6`）。

### flame-path-8 · 焰·碎片威力

分给碎片的威力 +2.5%。

- 分类：普通强化；学派 `flame`；价格 1；预算 3。
- 授予：`{"fragmentShare":0.025}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`flame-path-10`。
- 实际邻接：焰·联动威力（`flame-path-10`）、焰·法力回收（`flame-path-4`）、余热回收（`recovery`）。

### flame-path-9 · 焰·储备上限Ⅱ

储备上限 +10。

- 分类：普通强化；学派 `flame`；价格 1；预算 3。
- 授予：`{"heatCapacity":10}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`flame-path-6`。
- 实际邻接：热匣（`flame-furnace`）、焰·储备上限Ⅰ（`flame-path-3`）、焰·资源积累（`flame-path-6`）。

### flame-path-10 · 焰·联动威力

法术联动威力 +2.5%。

- 分类：普通强化；学派 `flame`；价格 1；预算 3。
- 授予：`{"reactionEfficiency":0.025}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`flame-path-12`。
- 实际邻接：焰·减少损耗（`flame-path-12`）、焰·碎片威力（`flame-path-8`）。

### flame-path-11 · 焰·法术伤害Ⅱ

法术伤害 +2.5%。

- 分类：普通强化；学派 `flame`；价格 1；预算 3。
- 授予：`{"spellPower":0.025}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：无。
- 实际邻接：焚页（`flame-delivery`）、焰·法术伤害Ⅰ（`flame-path-2`）。

### flame-path-12 · 焰·减少损耗

法术加工保留的威力 +4%。

- 分类：普通强化；学派 `flame`；价格 1；预算 3。
- 授予：`{"materialConserve":0.04}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：无。
- 实际邻接：续写抽取（`flame-extract`）、焰·联动威力（`flame-path-10`）。

### heat-payload · 蓄热

手动输入字符时积累热量，用于灼烧与法术联动。

- 分类：机制节点；学派 `flame`；价格 2；预算 6。
- 授予：`{"heatPayload":1}`；声明能力：`["heat"]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`ember`。
- 实际邻接：合订·减少损耗（`binding-bridge-4`）、焰·灼烧时间（`ember`）。

### recovery · 余热回收

回收尚未造成伤害的剩余热量；回收时会损失一部分，其余留给后续施法。

- 分类：机制节点；学派 `flame`；价格 2；预算 6。
- 授予：`{"heatRecovery":1}`；声明能力：`["recovery"]`。
- 额外条件：能力全部满足 `["heat"]`；无指定节点前置；无互斥组。
- 登记连接：`flame-path-8`。
- 实际邻接：焰·碎片威力（`flame-path-8`）、藏量·储备上限Ⅰ（`reserve-bridge-1`）。

### flame-extract · 续写抽取

完成咒文时，抽取上一个仍存活目标身上的灼烧，转为热量储备。原本后续的灼烧伤害会减少，回收的热量最早用于下一次施法。

- 分类：机制节点；学派 `flame`；价格 2；预算 6。
- 授予：`{"recoveryExtract":1,"heatRecovery":1}`；声明能力：`["recovery"]`。
- 额外条件：能力全部满足 `["heat"]`；无指定节点前置；无互斥组。
- 登记连接：`flame-path-12`。
- 实际邻接：灰烬归卷（`ash-manuscript`）、焰·减少损耗（`flame-path-12`）。

### flame-furnace · 热匣

热量储备上限增加 30；释放所需储备提高 12，需要积攒更久。

- 分类：机制节点；学派 `flame`；价格 2；预算 6。
- 授予：`{"heatCapacity":30,"reserveThreshold":12}`；声明能力：`["recovery"]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`flame-path-9`。
- 实际邻接：焰·储备上限Ⅱ（`flame-path-9`）、炉心封装（`furnace-binding`）、易形·减少损耗（`transmutation-bridge-1`）。

### flame-delivery · 焚页

保存的法术含有热量时，可以提前释放；保存时间缩短 0.5 秒。

- 分类：机制节点；学派 `flame`；价格 2；预算 6。
- 授予：`{"thermalRelease":1,"carrierLifetime":-0.5}`；声明能力：`[]`。
- 额外条件：能力全部满足 `["carrier"]`；无指定节点前置；无互斥组。
- 登记连接：`flame-path-11`。
- 实际邻接：焚页速写（`burning-script`）、焰·法术伤害Ⅱ（`flame-path-11`）、词形·复写威力（`letters-bridge-1`）。

### flame-economy · 余温

提高剩余热量的回收比例，减少法术加工损失；储备上限减少 8。

- 分类：机制节点；学派 `flame`；价格 2；预算 6。
- 授予：`{"recoveryEfficiency":0.12,"materialConserve":0.08,"heatCapacity":-8}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`flame-path-7`。
- 实际邻接：焰·保存时间（`flame-path-7`）。

### furnace-binding · 炉心封装

热量可以存入冰晶；储备上限增加 30，法术释放晚 0.5 秒。

- 分类：关键节点；学派 `flame`；价格 3；预算 9。
- 授予：`{"crystalStorage":1,"heatCapacity":30,"carrierDelay":0.5}`；声明能力：`["carrier"]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`flame-furnace`。
- 实际邻接：热匣（`flame-furnace`）。

### ash-manuscript · 灰烬归卷

剩余热量可以带入下一个房间；法术伤害降低 5%。

- 分类：关键节点；学派 `flame`；价格 3；预算 9。
- 授予：`{"reservePersist":1,"heatRecovery":1,"spellPower":-0.05}`；声明能力：`["recovery"]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`flame-extract`。
- 实际邻接：续写抽取（`flame-extract`）。

### burning-script · 焚页速写

复写所需字符减少 2，保存的法术提前 0.6 秒释放；保存时间缩短 1.5 秒。

- 分类：关键节点；学派 `flame`；价格 3；预算 9。
- 授予：`{"thermalRelease":1,"copyCadence":2,"carrierDelay":-0.6,"carrierLifetime":-1.5}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`flame-delivery`。
- 实际邻接：焚页（`flame-delivery`）。

## 雷鸣（storm，22 个）

### storm-root · 雷页

施法积累电荷，让法术在敌人之间连锁。

- 分类：法书起点；学派 `storm`；价格 2；预算 未登记；主书为 `storm` 时免费。
- 授予：`{"conductionPayload":1}`；声明能力：`["conduction"]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`branch`、`reflected-light`、`storm-path-4`。
- 实际邻接：雷·连锁威力（`branch`）、雷·弹反伤害（`reflected-light`）、雷·资源积累（`storm-path-4`）。

### branch · 雷·连锁威力

分给连锁的威力 +2.5%。

- 分类：普通强化；学派 `storm`；价格 1；预算 3。
- 授予：`{"chainShare":0.025}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`storm-path-6`。
- 实际邻接：雷·连锁次数（`storm-path-6`）、雷页（`storm-root`）。

### storm-path-2 · 雷·法术伤害Ⅰ

法术伤害 +2.5%。

- 分类：普通强化；学派 `storm`；价格 1；预算 3。
- 授予：`{"spellPower":0.025}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`storm-path-11`。
- 实际邻接：雷·弹反伤害（`reflected-light`）、短路分枝（`storm-near`）、雷·法术伤害Ⅱ（`storm-path-11`）。

### storm-path-3 · 雷·连锁距离Ⅰ

连锁距离 +25。

- 分类：普通强化；学派 `storm`；价格 1；预算 3。
- 授予：`{"chainReach":25}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`storm-path-9`。
- 实际邻接：雷·连锁次数（`storm-path-6`）、雷·连锁距离Ⅱ（`storm-path-9`）。

### storm-path-4 · 雷·资源积累

施法资源积累速度 +4%。

- 分类：普通强化；学派 `storm`；价格 1；预算 3。
- 授予：`{"materialRate":0.04}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`storm-path-8`。
- 实际邻接：雷·法术存量（`storm-path-8`）、雷页（`storm-root`）。

### reflected-light · 雷·弹反伤害

弹反伤害 +0.15。

- 分类：普通强化；学派 `storm`；价格 1；预算 3。
- 授予：`{"reflectPower":0.15}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`storm-path-2`。
- 实际邻接：雷·法术伤害Ⅰ（`storm-path-2`）、雷页（`storm-root`）。

### storm-path-6 · 雷·连锁次数

连锁次数 +1。

- 分类：普通强化；学派 `storm`；价格 1；预算 3。
- 授予：`{"chainCount":1}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`storm-path-3`。
- 实际邻接：雷·连锁威力（`branch`）、导流（`conduction-payload`）、雷·连锁距离Ⅰ（`storm-path-3`）。

### storm-path-7 · 雷·联动威力

法术联动威力 +2.5%。

- 分类：普通强化；学派 `storm`；价格 1；预算 3。
- 授予：`{"reactionEfficiency":0.025}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：无。
- 实际邻接：雷·法术伤害Ⅱ（`storm-path-11`）、回路（`storm-return`）。

### storm-path-8 · 雷·法术存量

法术保存数量 +1。

- 分类：普通强化；学派 `storm`；价格 1；预算 3。
- 授予：`{"carrierCapacity":1}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`storm-path-10`。
- 实际邻接：雷·减少损耗（`storm-path-10`）、雷·资源积累（`storm-path-4`）、页间中继（`storm-relay`）。

### storm-path-9 · 雷·连锁距离Ⅱ

连锁距离 +25。

- 分类：普通强化；学派 `storm`；价格 1；预算 3。
- 授予：`{"chainReach":25}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：无。
- 实际邻接：长弧（`storm-far`）、雷·连锁距离Ⅰ（`storm-path-3`）。

### storm-path-10 · 雷·减少损耗

法术加工保留的威力 +4%。

- 分类：普通强化；学派 `storm`；价格 1；预算 3。
- 授予：`{"materialConserve":0.04}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`storm-path-12`。
- 实际邻接：雷·保存时间（`storm-path-12`）、雷·法术存量（`storm-path-8`）。

### storm-path-11 · 雷·法术伤害Ⅱ

法术伤害 +2.5%。

- 分类：普通强化；学派 `storm`；价格 1；预算 3。
- 授予：`{"spellPower":0.025}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`storm-path-7`。
- 实际邻接：雷·法术伤害Ⅰ（`storm-path-2`）、雷·联动威力（`storm-path-7`）。

### storm-path-12 · 雷·保存时间

法术保存时间 +0.4 秒。

- 分类：普通强化；学派 `storm`；价格 1；预算 3。
- 授予：`{"carrierLifetime":0.4}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：无。
- 实际邻接：并流（`storm-merge`）、雷·减少损耗（`storm-path-10`）。

### conduction-payload · 导流

手动输入字符时积累电荷，让法术在多个敌人之间连锁。

- 分类：机制节点；学派 `storm`；价格 2；预算 6。
- 授予：`{"conductionPayload":1}`；声明能力：`["conduction"]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`storm-path-6`。
- 实际邻接：分合·联动威力（`geometry-bridge-4`）、雷·连锁次数（`storm-path-6`）。

### storm-relay · 页间中继

连锁攻击可以经过保存法术的纸页或冰晶继续跳向敌人；连锁距离增加 40。

- 分类：机制节点；学派 `storm`；价格 2；预算 6。
- 授予：`{"carrierRelay":1,"chainReach":40}`；声明能力：`[]`。
- 额外条件：能力全部满足 `["carrier"]`；无指定节点前置；无互斥组。
- 登记连接：`storm-path-8`。
- 实际邻接：雷·法术存量（`storm-path-8`）、运输·法术存量（`transport-bridge-4`）。

### storm-far · 长弧

连锁距离增加 110，连锁次数减少 1；更适合相距较远的敌人。

- 分类：机制节点；学派 `storm`；价格 2；预算 6。
- 授予：`{"chainReach":110,"chainCount":-1}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`storm-path-9`。
- 实际邻接：远枝共鸣（`remote-resonance`）、雷·连锁距离Ⅱ（`storm-path-9`）。

### storm-near · 短路分枝

连锁次数增加 2，距离减少 60；总威力分给更多近处敌人。

- 分类：机制节点；学派 `storm`；价格 2；预算 6。
- 授予：`{"chainCount":2,"chainReach":-60}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`storm-path-2`。
- 实际邻接：独卷·法术伤害（`focus-bridge-1`）、孤雷定本（`single-thunder`）、雷·法术伤害Ⅰ（`storm-path-2`）。

### storm-return · 回路

回收未命中法术的部分剩余威力；储备上限增加 12。

- 分类：机制节点；学派 `storm`；价格 2；预算 6。
- 授予：`{"missRecovery":1,"heatCapacity":12}`；声明能力：`["recovery"]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`storm-path-7`。
- 实际邻接：藏量·减少损耗（`reserve-bridge-4`）、雷·联动威力（`storm-path-7`）。

### storm-merge · 并流

将可以合并的法术集中攻击更少的敌人；释放晚 0.3 秒。

- 分类：机制节点；学派 `storm`；价格 2；预算 6。
- 授予：`{"mergePayload":1,"carrierDelay":0.3}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`storm-path-12`。
- 实际邻接：并行传页（`parallel-pages`）、雷·保存时间（`storm-path-12`）。

### remote-resonance · 远枝共鸣

连锁可以经过纸页或冰晶接力，距离增加 150、次数增加 1；分给连锁的威力减少。

- 分类：关键节点；学派 `storm`；价格 3；预算 9。
- 授予：`{"carrierRelay":1,"chainReach":150,"chainShare":-0.05,"chainCount":1}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；互斥组 `storm-form`。
- 登记连接：`storm-far`。
- 实际邻接：长弧（`storm-far`）。

### single-thunder · 孤雷定本

将雷电集中攻击更少的敌人；连锁次数减少，分给连锁的威力增加。

- 分类：关键节点；学派 `storm`；价格 3；预算 9。
- 授予：`{"concentrate":1,"chainCount":-2,"chainShare":0.06}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；互斥组 `storm-form`。
- 登记连接：`storm-near`。
- 实际邻接：短路分枝（`storm-near`）。

### parallel-pages · 并行传页

将法术分存到更多纸页或冰晶，可多保存 3 份；复写法术威力降低 8%。

- 分类：关键节点；学派 `storm`；价格 3；预算 9。
- 授予：`{"forkPayload":1,"carrierCapacity":3,"copyEfficiency":-0.08}`；声明能力：`[]`。
- 额外条件：能力全部满足 `["carrier"]`；无指定节点前置；无互斥组。
- 登记连接：`storm-merge`。
- 实际邻接：并流（`storm-merge`）。

## 纸灵（spirit，22 个）

### spirit-root · 纸页

输入字符积累复写纸页，用于保存和再次释放法术。

- 分类：法书起点；学派 `spirit`；价格 2；预算 未登记；主书为 `spirit` 时免费。
- 授予：`{"copyPages":1}`；声明能力：`["carrier"]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`copy-page`、`spirit-path-5`、`spirit-path-3`。
- 实际邻接：纸·复写威力Ⅰ（`copy-page`）、纸·法术存量Ⅰ（`spirit-path-3`）、纸·法术防御（`spirit-path-5`）。

### copy-page · 纸·复写威力Ⅰ

复写法术威力 +1.5%。

- 分类：普通强化；学派 `spirit`；价格 1；预算 3。
- 授予：`{"copyEfficiency":0.015}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`spirit-path-6`。
- 实际邻接：纸·复写速度（`spirit-path-6`）、纸页（`spirit-root`）。

### spirit-path-2 · 纸·法术伤害Ⅰ

法术伤害 +2.5%。

- 分类：普通强化；学派 `spirit`；价格 1；预算 3。
- 授予：`{"spellPower":0.025}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：无。
- 实际邻接：复文（`paper-inherit`）、纸·复写威力Ⅱ（`spirit-path-9`）。

### spirit-path-3 · 纸·法术存量Ⅰ

法术保存数量 +1。

- 分类：普通强化；学派 `spirit`；价格 1；预算 3。
- 授予：`{"carrierCapacity":1}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`spirit-path-8`。
- 实际邻接：纸·法术存量Ⅱ（`spirit-path-8`）、纸页（`spirit-root`）。

### spirit-path-4 · 纸·保存时间Ⅰ

法术保存时间 +0.5 秒。

- 分类：普通强化；学派 `spirit`；价格 1；预算 3。
- 授予：`{"carrierLifetime":0.5}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`spirit-path-10`。
- 实际邻接：护页（`paper-ward`）、纸·保存时间Ⅱ（`spirit-path-10`）、纸·法术防御（`spirit-path-5`）。

### spirit-path-5 · 纸·法术防御

法术防御效果 +8%。

- 分类：普通强化；学派 `spirit`；价格 1；预算 3。
- 授予：`{"guardEfficiency":0.08}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`spirit-path-4`。
- 实际邻接：纸·保存时间Ⅰ（`spirit-path-4`）、纸页（`spirit-root`）。

### spirit-path-6 · 纸·复写速度

复写所需字符减少 +0.5 字。

- 分类：普通强化；学派 `spirit`；价格 1；预算 3。
- 授予：`{"copyCadence":0.5}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`spirit-path-9`。
- 实际邻接：纸·复写威力Ⅰ（`copy-page`）、承页（`paper-carrier`）、纸·复写威力Ⅱ（`spirit-path-9`）。

### spirit-path-7 · 纸·减少损耗

法术加工保留的威力 +3%。

- 分类：普通强化；学派 `spirit`；价格 1；预算 3。
- 授予：`{"materialConserve":0.03}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`spirit-path-12`。
- 实际邻接：纸·连锁距离（`spirit-path-12`）、纸·法术存量Ⅱ（`spirit-path-8`）。

### spirit-path-8 · 纸·法术存量Ⅱ

法术保存数量 +1。

- 分类：普通强化；学派 `spirit`；价格 1；预算 3。
- 授予：`{"carrierCapacity":1}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`spirit-path-7`。
- 实际邻接：归纸（`paper-salvage`）、纸·法术存量Ⅰ（`spirit-path-3`）、纸·减少损耗（`spirit-path-7`）。

### spirit-path-9 · 纸·复写威力Ⅱ

复写法术威力 +2%。

- 分类：普通强化；学派 `spirit`；价格 1；预算 3。
- 授予：`{"copyEfficiency":0.02}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`spirit-path-2`。
- 实际邻接：纸·法术伤害Ⅰ（`spirit-path-2`）、纸·复写速度（`spirit-path-6`）。

### spirit-path-10 · 纸·保存时间Ⅱ

法术保存时间 +0.5 秒。

- 分类：普通强化；学派 `spirit`；价格 1；预算 3。
- 授予：`{"carrierLifetime":0.5}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`spirit-path-11`。
- 实际邻接：纸·法术伤害Ⅱ（`spirit-path-11`）、纸·保存时间Ⅰ（`spirit-path-4`）。

### spirit-path-11 · 纸·法术伤害Ⅱ

法术伤害 +2.5%。

- 分类：普通强化；学派 `spirit`；价格 1；预算 3。
- 授予：`{"spellPower":0.025}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：无。
- 实际邻接：遗响（`echo`）、纸·保存时间Ⅱ（`spirit-path-10`）。

### spirit-path-12 · 纸·连锁距离

连锁距离 +20。

- 分类：普通强化；学派 `spirit`；价格 1；预算 3。
- 授予：`{"chainReach":20}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：无。
- 实际邻接：递书（`paper-transport`）、纸·减少损耗（`spirit-path-7`）。

### paper-carrier · 承页

手动输入字符时积累纸页，用来保存法术并再次释放。

- 分类：机制节点；学派 `spirit`；价格 2；预算 6。
- 授予：`{"copyPages":1}`；声明能力：`["carrier"]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`spirit-path-6`。
- 实际邻接：词形·保存时间（`letters-bridge-4`）、纸·复写速度（`spirit-path-6`）。

### echo · 遗响

纸页或冰晶用于防御、或保存时间结束时，释放其中尚未用掉的法术。

- 分类：机制节点；学派 `spirit`；价格 2；预算 6。
- 授予：`{"carrierRelease":1}`；声明能力：`["release"]`。
- 额外条件：能力全部满足 `["carrier"]`；无指定节点前置；无互斥组。
- 登记连接：`spirit-path-11`。
- 实际邻接：纸·法术伤害Ⅱ（`spirit-path-11`）。

### paper-ward · 护页

保存的法术可以用于防御。用于防御的那部分威力会被消耗。

- 分类：机制节点；学派 `spirit`；价格 2；预算 6。
- 授予：`{"carrierGuard":1}`；声明能力：`["guard"]`。
- 额外条件：能力全部满足 `["carrier"]`；无指定节点前置；无互斥组。
- 登记连接：`spirit-path-4`。
- 实际邻接：以守代发（`defensive-script`）、纸·保存时间Ⅰ（`spirit-path-4`）、护持·复写威力（`warding-bridge-4`）。

### paper-inherit · 复文

复写的法术保留原有的联动效果；复写威力降低 3%。

- 分类：机制节点；学派 `spirit`；价格 2；预算 6。
- 授予：`{"copyInheritance":1,"copyEfficiency":-0.03}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`spirit-path-2`。
- 实际邻接：独卷·减少损耗（`focus-bridge-4`）、纸·法术伤害Ⅰ（`spirit-path-2`）、速行装订（`swift-script`）。

### paper-salvage · 归纸

纸页消失时，回收未释放法术的部分剩余威力；储备上限增加 12。

- 分类：机制节点；学派 `spirit`；价格 2；预算 6。
- 授予：`{"paperRecovery":1,"heatCapacity":12}`；声明能力：`["recovery"]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`spirit-path-8`。
- 实际邻接：纸·法术存量Ⅱ（`spirit-path-8`）。

### paper-transport · 递书

纸灵可以运送保存的法术；运送会占用它原本的一次攻击。

- 分类：机制节点；学派 `spirit`；价格 2；预算 6。
- 授予：`{"summonTransport":1}`；声明能力：`[]`。
- 额外条件：能力全部满足 `["carrier"]`；无指定节点前置；无互斥组。
- 登记连接：`spirit-path-12`。
- 实际邻接：行间编队（`between-lines`）、纸·连锁距离（`spirit-path-12`）、运输·保存时间（`transport-bridge-1`）。

### defensive-script · 以守代发

优先保留法术用于防御，保存时间延长 2 秒，因此自动攻击变少。搭配「遗响」可释放防御后剩余的法术。

- 分类：关键节点；学派 `spirit`；价格 3；预算 9。
- 授予：`{"carrierRetain":1,"carrierGuard":1,"carrierLifetime":2}`；声明能力：`["guard"]`。
- 额外条件：无能力前置；无指定节点前置；互斥组 `paper-form`。
- 登记连接：`paper-ward`。
- 实际邻接：护页（`paper-ward`）。

### swift-script · 速行装订

复写所需字符减少 2，法术提前 0.7 秒释放；可保存的法术减少 1 份。

- 分类：关键节点；学派 `spirit`；价格 3；预算 9。
- 授予：`{"copyCadence":2,"carrierDelay":-0.7,"carrierCapacity":-1}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；互斥组 `paper-form`。
- 登记连接：`paper-inherit`。
- 实际邻接：复文（`paper-inherit`）。

### between-lines · 行间编队

纸灵可以运送并合并法术，可多保存 2 份；运送会占用它原本的攻击。

- 分类：关键节点；学派 `spirit`；价格 3；预算 9。
- 授予：`{"summonTransport":1,"mergePayload":1,"carrierCapacity":2}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`paper-transport`。
- 实际邻接：递书（`paper-transport`）。

## 合订（binding，7 个）

### binding-bridge-1 · 合订·资源积累

施法资源积累速度 +5%。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"materialRate":0.05}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`binding-bridge-2`、`crystal`。
- 实际邻接：合订·复写威力（`binding-bridge-2`）、晶构（`crystal`）。

### binding-bridge-2 · 合订·复写威力

复写法术威力 +2%。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"copyEfficiency":0.02}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`binding-bridge-3`。
- 实际邻接：合订（`binding`）、合订·资源积累（`binding-bridge-1`）、合订·储备上限（`binding-bridge-3`）。

### binding-bridge-3 · 合订·储备上限

储备上限 +10。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"heatCapacity":10}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`binding-bridge-4`。
- 实际邻接：合订·复写威力（`binding-bridge-2`）、合订·减少损耗（`binding-bridge-4`）、副页供给（`binding-supply`）。

### binding-bridge-4 · 合订·减少损耗

法术加工保留的威力 +4%。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"materialConserve":0.04}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`heat-payload`。
- 实际邻接：合订·储备上限（`binding-bridge-3`）、蓄热（`heat-payload`）。

### binding · 合订

可以选择一本副书，获得该书的施法资源，用于与主书配合。

- 分类：机制节点；学派 `shared`；价格 2；预算 6。
- 授予：`{"secondaryBinding":1}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；互斥组 `binding`。
- 登记连接：`binding-bridge-2`。
- 实际邻接：合订·复写威力（`binding-bridge-2`）、异材同工（`binding-economy`）。

### binding-supply · 副页供给

施法资源积累速度提高 12%。

- 分类：机制节点；学派 `shared`；价格 2；预算 6。
- 授予：`{"materialRate":0.12}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`binding-bridge-3`。
- 实际邻接：合订·储备上限（`binding-bridge-3`）、异材同工（`binding-economy`）。

### binding-economy · 异材同工

减少法术加工损失，提高联动威力；法术伤害降低 5%。

- 分类：关键节点；学派 `shared`；价格 3；预算 9。
- 授予：`{"materialConserve":0.2,"reactionEfficiency":0.06,"spellPower":-0.05}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`binding`、`binding-supply`。
- 实际邻接：合订（`binding`）、副页供给（`binding-supply`）。

## 独卷（focus，7 个）

### focus-bridge-1 · 独卷·法术伤害

法术伤害 +2.5%。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"spellPower":0.025}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`focus-bridge-2`、`storm-near`。
- 实际邻接：独卷·穿透次数（`focus-bridge-2`）、短路分枝（`storm-near`）。

### focus-bridge-2 · 独卷·穿透次数

穿透次数 +1。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"payloadPierce":1}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`focus-bridge-3`。
- 实际邻接：独卷（`focus`）、独卷·法术伤害（`focus-bridge-1`）、独卷·储备上限（`focus-bridge-3`）。

### focus-bridge-3 · 独卷·储备上限

储备上限 +10。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"heatCapacity":10}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`focus-bridge-4`。
- 实际邻接：独卷·穿透次数（`focus-bridge-2`）、独卷·减少损耗（`focus-bridge-4`）、定本（`focus-structure`）。

### focus-bridge-4 · 独卷·减少损耗

法术加工保留的威力 +4%。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"materialConserve":0.04}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`paper-inherit`。
- 实际邻接：独卷·储备上限（`focus-bridge-3`）、复文（`paper-inherit`）。

### focus · 独卷

专精当前主书，无法选择副书。

- 分类：机制节点；学派 `shared`；价格 2；预算 6。
- 授予：`{"singleFocus":1}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；互斥组 `binding`。
- 登记连接：`focus-bridge-2`。
- 实际邻接：独卷·穿透次数（`focus-bridge-2`）、独卷精修（`single-refinement`）。

### focus-structure · 定本

强化当前主书：冰晶增加穿透，火焰增加储备，雷电集中攻击，纸灵加强运送。

- 分类：机制节点；学派 `shared`；价格 2；预算 6。
- 授予：`{"singleFrost":1,"singleFlame":1,"singleStorm":1,"singleSpirit":1}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`focus-bridge-3`。
- 实际邻接：独卷·储备上限（`focus-bridge-3`）、独卷精修（`single-refinement`）。

### single-refinement · 独卷精修

复写保留原有联动，减少法术加工损失；连锁次数减少 1。需要先点亮「独卷」。

- 分类：关键节点；学派 `shared`；价格 3；预算 9。
- 授予：`{"copyInheritance":1,"materialConserve":0.18,"chainCount":-1}`；声明能力：`[]`。
- 额外条件：无能力前置；节点全部满足 独卷（`focus`）；无互斥组。
- 登记连接：`focus`、`focus-structure`。
- 实际邻接：独卷（`focus`）、定本（`focus-structure`）。

## 储备回收（reserve，7 个）

### reserve-bridge-1 · 藏量·储备上限Ⅰ

储备上限 +12。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"heatCapacity":12}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`reserve-bridge-2`、`recovery`。
- 实际邻接：余热回收（`recovery`）、藏量·法力回收（`reserve-bridge-2`）。

### reserve-bridge-2 · 藏量·法力回收

剩余法力回收比例 +2.5%。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"recoveryEfficiency":0.025}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`reserve-bridge-3`。
- 实际邻接：藏量·储备上限Ⅰ（`reserve-bridge-1`）、藏量·储备上限Ⅱ（`reserve-bridge-3`）、大匣（`reserve-wide`）。

### reserve-bridge-3 · 藏量·储备上限Ⅱ

储备上限 +12。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"heatCapacity":12}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`reserve-bridge-4`。
- 实际邻接：藏量·法力回收（`reserve-bridge-2`）、藏量·减少损耗（`reserve-bridge-4`）、细匣（`reserve-fine`）。

### reserve-bridge-4 · 藏量·减少损耗

法术加工保留的威力 +4%。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"materialConserve":0.04}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`storm-return`。
- 实际邻接：藏量·储备上限Ⅱ（`reserve-bridge-3`）、回路（`storm-return`）。

### reserve-wide · 大匣

储备上限增加 45；剩余法力的回收比例降低 6%。

- 分类：机制节点；学派 `shared`；价格 2；预算 6。
- 授予：`{"heatCapacity":45,"recoveryEfficiency":-0.06}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；互斥组 `reserve-shape`。
- 登记连接：`reserve-bridge-2`。
- 实际邻接：余量归档（`reserve-archive`）、藏量·法力回收（`reserve-bridge-2`）。

### reserve-fine · 细匣

剩余法力的回收比例提高 15%；储备上限减少 10。

- 分类：机制节点；学派 `shared`；价格 2；预算 6。
- 授予：`{"recoveryEfficiency":0.15,"heatCapacity":-10}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；互斥组 `reserve-shape`。
- 登记连接：`reserve-bridge-3`。
- 实际邻接：余量归档（`reserve-archive`）、藏量·储备上限Ⅱ（`reserve-bridge-3`）。

### reserve-archive · 余量归档

储备可以带入下一个房间；释放所需储备提高 15，法术伤害降低 4%。

- 分类：关键节点；学派 `shared`；价格 3；预算 9。
- 授予：`{"reservePersist":1,"reserveThreshold":15,"spellPower":-0.04}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`reserve-wide`、`reserve-fine`。
- 实际邻接：细匣（`reserve-fine`）、大匣（`reserve-wide`）。

## 分合（geometry，7 个）

### geometry-bridge-1 · 分合·连锁距离

连锁距离 +25。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"chainReach":25}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`geometry-bridge-2`、`frost-division`。
- 实际邻接：析晶（`frost-division`）、分合·碎片威力（`geometry-bridge-2`）。

### geometry-bridge-2 · 分合·碎片威力

分给碎片的威力 +2.5%。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"fragmentShare":0.025}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`geometry-bridge-3`。
- 实际邻接：分合·连锁距离（`geometry-bridge-1`）、分合·法术存量（`geometry-bridge-3`）、分发（`geometry-split`）。

### geometry-bridge-3 · 分合·法术存量

法术保存数量 +1。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"carrierCapacity":1}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`geometry-bridge-4`。
- 实际邻接：分合·碎片威力（`geometry-bridge-2`）、分合·联动威力（`geometry-bridge-4`）、收束（`geometry-merge`）。

### geometry-bridge-4 · 分合·联动威力

法术联动威力 +2.5%。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"reactionEfficiency":0.025}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`conduction-payload`。
- 实际邻接：导流（`conduction-payload`）、分合·法术存量（`geometry-bridge-3`）。

### geometry-split · 分发

将法术分给更多敌人；总威力不变，每份威力更低。

- 分类：机制节点；学派 `shared`；价格 2；预算 6。
- 授予：`{"forkPayload":1}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；互斥组 `geometry`。
- 登记连接：`geometry-bridge-2`。
- 实际邻接：分合·碎片威力（`geometry-bridge-2`）、旁路传递（`geometry-network`）。

### geometry-merge · 收束

合并法术，集中攻击更少的敌人。

- 分类：机制节点；学派 `shared`；价格 2；预算 6。
- 授予：`{"concentrate":1,"mergePayload":1}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；互斥组 `geometry`。
- 登记连接：`geometry-bridge-3`。
- 实际邻接：分合·法术存量（`geometry-bridge-3`）、旁路传递（`geometry-network`）。

### geometry-network · 旁路传递

连锁攻击可以经过纸页或冰晶接力，距离增加 90；保存的法术释放晚 0.4 秒。

- 分类：关键节点；学派 `shared`；价格 3；预算 9。
- 授予：`{"carrierRelay":1,"chainReach":90,"carrierDelay":0.4}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`geometry-split`、`geometry-merge`。
- 实际邻接：收束（`geometry-merge`）、分发（`geometry-split`）。

## 护持（warding，7 个）

### warding-bridge-1 · 护持·保存时间

法术保存时间 +0.6 秒。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"carrierLifetime":0.6}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`warding-bridge-2`、`frost-vessel`。
- 实际邻接：冰匣（`frost-vessel`）、护持·法术防御（`warding-bridge-2`）。

### warding-bridge-2 · 护持·法术防御

法术防御效果 +8%。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"guardEfficiency":0.08}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`warding-bridge-3`。
- 实际邻接：护持·保存时间（`warding-bridge-1`）、护持·法术存量（`warding-bridge-3`）、新页护封（`warding-new`）。

### warding-bridge-3 · 护持·法术存量

法术保存数量 +1。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"carrierCapacity":1}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`warding-bridge-4`。
- 实际邻接：护持·法术防御（`warding-bridge-2`）、护持·复写威力（`warding-bridge-4`）、终页余响（`warding-echo`）。

### warding-bridge-4 · 护持·复写威力

复写法术威力 +2%。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"copyEfficiency":0.02}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`paper-ward`。
- 实际邻接：护页（`paper-ward`）、护持·法术存量（`warding-bridge-3`）。

### warding-new · 新页护封

防御时优先消耗最新保存的法术，把更早保存的法术留给攻击。

- 分类：机制节点；学派 `shared`；价格 2；预算 6。
- 授予：`{"guardNewest":1,"carrierGuard":1}`；声明能力：`["guard"]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`warding-bridge-2`。
- 实际邻接：护持·法术防御（`warding-bridge-2`）、护文反照（`warding-return`）。

### warding-echo · 终页余响

纸页或冰晶用于防御、或保存时间结束时，释放尚未用掉的法术；复写威力降低 3%。

- 分类：机制节点；学派 `shared`；价格 2；预算 6。
- 授予：`{"carrierRelease":1,"copyEfficiency":-0.03}`；声明能力：`["release"]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`warding-bridge-3`。
- 实际邻接：护持·法术存量（`warding-bridge-3`）、护文反照（`warding-return`）。

### warding-return · 护文反照

优先保存法术用于防御，并在防御或保存结束时释放剩余法术；可多保存 2 份，释放晚 0.5 秒。

- 分类：关键节点；学派 `shared`；价格 3；预算 9。
- 授予：`{"carrierRetain":1,"carrierRelease":1,"carrierCapacity":2,"carrierDelay":0.5}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`warding-new`、`warding-echo`。
- 实际邻接：终页余响（`warding-echo`）、新页护封（`warding-new`）。

## 词形（letters，7 个）

### letters-bridge-1 · 词形·复写威力

复写法术威力 +2%。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"copyEfficiency":0.02}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`letters-bridge-2`、`flame-delivery`。
- 实际邻接：焚页（`flame-delivery`）、词形·法术存量（`letters-bridge-2`）。

### letters-bridge-2 · 词形·法术存量

法术保存数量 +1。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"carrierCapacity":1}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`letters-bridge-3`。
- 实际邻接：词形·复写威力（`letters-bridge-1`）、词形·资源积累（`letters-bridge-3`）、聚字成页（`letters-carry`）。

### letters-bridge-3 · 词形·资源积累

施法资源积累速度 +5%。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"materialRate":0.05}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`letters-bridge-4`。
- 实际邻接：词形·法术存量（`letters-bridge-2`）、词形·保存时间（`letters-bridge-4`）、分字联章（`letters-scatter`）。

### letters-bridge-4 · 词形·保存时间

法术保存时间 +0.5 秒。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"carrierLifetime":0.5}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`paper-carrier`。
- 实际邻接：词形·资源积累（`letters-bridge-3`）、承页（`paper-carrier`）。

### letters-carry · 聚字成页

将一部分字母标记增伤转为纸页保存的法术；这部分威力不再直接造成标记伤害。

- 分类：机制节点；学派 `shared`；价格 2；预算 6。
- 授予：`{"markCarrier":1}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；互斥组 `letter-form`。
- 登记连接：`letters-bridge-2`。
- 实际邻接：词形·法术存量（`letters-bridge-2`）、词令复调（`letters-resonance`）。

### letters-scatter · 分字联章

散出的字母优先寻找不同敌人，扩大攻击范围。

- 分类：机制节点；学派 `shared`；价格 2；预算 6。
- 授予：`{"markSpread":1,"letterScatter":1}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；互斥组 `letter-form`。
- 登记连接：`letters-bridge-3`。
- 实际邻接：词形·资源积累（`letters-bridge-3`）、词令复调（`letters-resonance`）。

### letters-resonance · 词令复调

手动施法触发的字母标记可转为纸页法术，并保留原有联动；可多保存 2 份，释放晚 0.3 秒。

- 分类：关键节点；学派 `shared`；价格 3；预算 9。
- 授予：`{"markCarrier":1,"copyInheritance":1,"carrierCapacity":2,"carrierDelay":0.3}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`letters-carry`、`letters-scatter`。
- 实际邻接：聚字成页（`letters-carry`）、分字联章（`letters-scatter`）。

## 运输（transport，7 个）

### transport-bridge-1 · 运输·保存时间

法术保存时间 +0.5 秒。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"carrierLifetime":0.5}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`transport-bridge-2`、`paper-transport`。
- 实际邻接：递书（`paper-transport`）、运输·连锁距离（`transport-bridge-2`）。

### transport-bridge-2 · 运输·连锁距离

连锁距离 +25。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"chainReach":25}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`transport-bridge-3`。
- 实际邻接：运输·保存时间（`transport-bridge-1`）、运输·复写威力（`transport-bridge-3`）、接力页（`transport-relay`）。

### transport-bridge-3 · 运输·复写威力

复写法术威力 +2%。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"copyEfficiency":0.02}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`transport-bridge-4`。
- 实际邻接：运输·连锁距离（`transport-bridge-2`）、运输·法术存量（`transport-bridge-4`）、行间递送（`transport-spirit`）。

### transport-bridge-4 · 运输·法术存量

法术保存数量 +1。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"carrierCapacity":1}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`storm-relay`。
- 实际邻接：页间中继（`storm-relay`）、运输·复写威力（`transport-bridge-3`）。

### transport-relay · 接力页

连锁攻击可以经过纸页或冰晶接力，距离增加 40。

- 分类：机制节点；学派 `shared`；价格 2；预算 6。
- 授予：`{"carrierRelay":1,"chainReach":40}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`transport-bridge-2`。
- 实际邻接：运输·连锁距离（`transport-bridge-2`）、流动书架（`transport-fleet`）。

### transport-spirit · 行间递送

纸灵可以运送保存的法术；每次运送占用一次普通攻击。

- 分类：机制节点；学派 `shared`；价格 2；预算 6。
- 授予：`{"summonTransport":1}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`transport-bridge-3`。
- 实际邻接：运输·复写威力（`transport-bridge-3`）、流动书架（`transport-fleet`）。

### transport-fleet · 流动书架

纸灵可以运送并合并法术，可多保存 3 份；保存的法术释放晚 0.6 秒。

- 分类：关键节点；学派 `shared`；价格 3；预算 9。
- 授予：`{"summonTransport":1,"mergePayload":1,"carrierCapacity":3,"carrierDelay":0.6}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`transport-relay`、`transport-spirit`。
- 实际邻接：接力页（`transport-relay`）、行间递送（`transport-spirit`）。

## 易形（transmutation，7 个）

### transmutation-bridge-1 · 易形·减少损耗

法术加工保留的威力 +4%。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"materialConserve":0.04}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`transmutation-bridge-2`、`flame-furnace`。
- 实际邻接：热匣（`flame-furnace`）、易形·联动威力（`transmutation-bridge-2`）。

### transmutation-bridge-2 · 易形·联动威力

法术联动威力 +2.5%。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"reactionEfficiency":0.025}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`transmutation-bridge-3`。
- 实际邻接：易形·减少损耗（`transmutation-bridge-1`）、易形·储备上限（`transmutation-bridge-3`）、受热易形（`transmutation-heat`）。

### transmutation-bridge-3 · 易形·储备上限

储备上限 +12。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"heatCapacity":12}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`transmutation-bridge-4`。
- 实际邻接：易形·联动威力（`transmutation-bridge-2`）、易形·碎片威力（`transmutation-bridge-4`）、废页再用（`transmutation-return`）。

### transmutation-bridge-4 · 易形·碎片威力

分给碎片的威力 +2.5%。

- 分类：普通强化；学派 `shared`；价格 1；预算 3。
- 授予：`{"fragmentShare":0.025}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`frost-melt`。
- 实际邻接：解冻出口（`frost-melt`）、易形·储备上限（`transmutation-bridge-3`）。

### transmutation-heat · 受热易形

含有热量的纸页或冰晶会提前释放法术，因此留给防御的时间更短。

- 分类：机制节点；学派 `shared`；价格 2；预算 6。
- 授予：`{"thermalRelease":1}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`transmutation-bridge-2`。
- 实际邻接：易形·联动威力（`transmutation-bridge-2`）、万页炉（`transmutation-furnace`）。

### transmutation-return · 废页再用

回收消失纸页和未命中法术的部分剩余威力。

- 分类：机制节点；学派 `shared`；价格 2；预算 6。
- 授予：`{"paperRecovery":1,"missRecovery":1}`；声明能力：`["recovery"]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`transmutation-bridge-3`。
- 实际邻接：易形·储备上限（`transmutation-bridge-3`）、万页炉（`transmutation-furnace`）。

### transmutation-furnace · 万页炉

冰晶可以保存法术，热量使纸页和冰晶提前释放，复写保留原有联动；复写威力降低 8%。

- 分类：关键节点；学派 `shared`；价格 3；预算 9。
- 授予：`{"thermalRelease":1,"crystalStorage":1,"copyInheritance":1,"copyEfficiency":-0.08}`；声明能力：`[]`。
- 额外条件：无能力前置；无指定节点前置；无互斥组。
- 登记连接：`transmutation-heat`、`transmutation-return`。
- 实际邻接：受热易形（`transmutation-heat`）、废页再用（`transmutation-return`）。
