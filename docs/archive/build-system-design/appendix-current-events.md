# 当前事件与房间路线全量目录

> 历史归档：保留当时的方案、状态或检查结果，不作为当前待办、完成声明或实施约束。当前入口见[文档导航](../../README.md)。

[返回现状汇总](01-CURRENT-SYSTEM.md) · [研讨总纲](00-DESIGN-BRIEF.md)

基线 `767b349`，2026-09-23，24 个构筑事件和 6 条房间路线。登记文案原样保留；相似名称不代表相同效果，不同名称也不自动代表不同玩法。

来源：[事件定义](../../../legacy/web/src/content/build-events.ts)、[事件执行](../../../legacy/web/src/simulation/progression/BuildEventSystem.ts)、[注册目录与路线](../../../legacy/web/src/content/catalog.ts)、[奖励与路线处理](../../../legacy/web/src/simulation/progression/RewardSystem.ts)。本步没有运行事件流程。

## 所有构筑事件共用的选择规则

合格事件尚未在本局提交过，接受后生命上限至少为 25；`needs` 须全部满足，`talentStats` 至少一项在实际出征天赋中为正；演化事件还须找到可替换遗物。即使上次选择保留原稿，该事件也会留下提交记录。

每个事件共用以下选项模板，没有为每个名字另配三套效果：

| 选项 | 出现条件 | 效果 |
| --- | --- | --- |
| 修订构筑／接受试炼（rewrite） | 事件合格 | 下表逐项记载的授予、生命上限代价、下一房压力、未来奖励扣除或遗物替换 |
| 校订本卷（annotate） | 当前生命上限至少 28 | 本局生命上限 -3，`spellPower +0.02` |
| 保留原稿（leave） | 始终 | 不改变当前构筑 |

房级效果指提交后的下一房，章级效果推进到不同章节时失效，本局效果持续本局。非试炼首选效果提交后立即激活；试炼首选效果完成下一房才激活。所有带压力的选项将压力附着在下一房，不能把 `scope: run` 误读为压力永久增加。

下面的压力是登记加值，不直接等于敌人所有属性的统一百分比；奖励债务按后续普通奖励机会扣除。生命上限降低后，当前生命会被限制在新的上限内。演化除事件自身的 `grants` 外，还改变持有遗物，二者共同影响构筑。

## 修订（revision，3 个）

### revision-binding · 装订师的改页

重新决定护页与交付的先后。

- 期限：本局（`run`）；激活：提交后；机制族：binding。
- 授予：`{"guardNewest":1}`。
- 资格：能力全部满足 `["carrier"]`；无指定天赋统计前置；须有可演化的同族遗物。
- 代价：生命上限 -5；后续奖励扣除 0 次；下一房压力 +0。
- 演化：目标 新页守则（`binding-newest`）；登记父件 `binding-clasp`，演化组 `binding`。实际来源在该父件及同组已持有分支中按预算降序、ID 升序选择，不能理解为同时移除整族。[遗物详情](appendix-current-relics.md)

### revision-crystal · 晶匠校形

把晶体从武器改为可保存法术的容器。

- 期限：本局（`run`）；激活：提交后；机制族：crystal。
- 授予：`{"crystalStorage":1}`。
- 资格：能力全部满足 `["cold"]`；无指定天赋统计前置；须有可演化的同族遗物。
- 代价：生命上限 -5；后续奖励扣除 0 次；下一房压力 +0。
- 演化：目标 冰藏定本（`crystal-vault`）；登记父件 `crystal-seed`，演化组 `crystal`。实际来源在该父件及同组已持有分支中按预算降序、ID 升序选择，不能理解为同时移除整族。[遗物详情](appendix-current-relics.md)

### revision-conduction · 孤弧定向

改变有限电性片段的交付结构。

- 期限：本局（`run`）；激活：提交后；机制族：conduction。
- 授予：`{"concentrate":1}`。
- 资格：能力全部满足 `["conduction"]`；无指定天赋统计前置；须有可演化的同族遗物。
- 代价：生命上限 -5；后续奖励扣除 0 次；下一房压力 +0。
- 演化：目标 定向电桥（`conduction-focus`）；登记父件 `conduction-coil`，演化组 `conduction`。实际来源在该父件及同组已持有分支中按预算降序、ID 升序选择，不能理解为同时移除整族。[遗物详情](appendix-current-relics.md)

## 借阅（loan，3 个）

### loan-echo · 借阅终章

借来的遗响让终结变成出口。

- 期限：本章（`chapter`）；激活：提交后；机制族：未登记。
- 授予：`{"carrierRelease":1,"carrierCapacity":-1}`。
- 资格：能力全部满足 `["carrier"]`；天赋授予至少一项为正 `["carrierGuard","thermalRelease"]`。
- 代价：生命上限 -0；后续奖励扣除 0 次；下一房压力 +0。
- 遗物替换：无。

### loan-shell · 借阅冰匣

以更长等待借得承载和晶壳加工。

- 期限：本章（`chapter`）；激活：提交后；机制族：未登记。
- 授予：`{"crystalStorage":1,"carrierCapacity":2,"carrierDelay":0.5}`。
- 资格：无额外能力前置；无指定天赋统计前置。
- 代价：生命上限 -4；后续奖励扣除 0 次；下一房压力 +0。
- 遗物替换：无。

### loan-relay · 借阅旁路

下一房让载体充当电性中继。

- 期限：下一房（`room`）；激活：提交后；机制族：未登记。
- 授予：`{"carrierRelay":1,"chainReach":90,"chainShare":-0.04}`。
- 资格：能力全部满足 `["carrier"]`；无指定天赋统计前置。
- 代价：生命上限 -0；后续奖励扣除 0 次；下一房压力 +0。
- 遗物替换：无。

## 连接（bridge，3 个）

### bridge-thermal · 热缝接页

为已有载体接入热加工出口。

- 期限：本局（`run`）；激活：提交后；机制族：未登记。
- 授予：`{"thermalRelease":1}`。
- 资格：能力全部满足 `["carrier","heat"]`；无指定天赋统计前置。
- 代价：生命上限 -0；后续奖励扣除 0 次；下一房压力 +0.12。
- 遗物替换：无。

### bridge-copy · 同文接续

让复写页继承天赋已经开放的加工。

- 期限：本局（`run`）；激活：提交后；机制族：未登记。
- 授予：`{"copyInheritance":1,"copyEfficiency":-0.035}`。
- 资格：能力全部满足 `["carrier"]`；天赋授予至少一项为正 `["crystalPayload","conductionPayload","heatPayload"]`。
- 代价：生命上限 -4；后续奖励扣除 0 次；下一房压力 +0。
- 遗物替换：无。

### bridge-return · 余载入匣

载体剩余与回收规则获得共同入口。

- 期限：本局（`run`）；激活：提交后；机制族：未登记。
- 授予：`{"paperRecovery":1,"missRecovery":1}`。
- 资格：能力全部满足 `["recovery"]`；无指定天赋统计前置。
- 代价：生命上限 -0；后续奖励扣除 0 次；下一房压力 +0.1。
- 遗物替换：无。

## 熔炼（smelt，3 个）

### smelt-thermal · 炉心退火

把已有热零件改作封装材料。

- 期限：本局（`run`）；激活：提交后；机制族：thermal。
- 授予：`{"carrierLifetime":1}`。
- 资格：能力全部满足 `["heat"]`；无指定天赋统计前置；须有可演化的同族遗物。
- 代价：生命上限 -5；后续奖励扣除 0 次；下一房压力 +0。
- 演化：目标 退火封装（`thermal-anneal`）；登记父件 `thermal-wick`，演化组 `thermal`。实际来源在该父件及同组已持有分支中按预算降序、ID 升序选择，不能理解为同时移除整族。[遗物详情](appendix-current-relics.md)

### smelt-fragment · 百屑淬炼

让碎片在载体受热时提前交付。

- 期限：本局（`run`）；激活：提交后；机制族：fragments。
- 授予：`{"fragmentShare":0.025}`。
- 资格：能力全部满足 `["cold"]`；无指定天赋统计前置；须有可演化的同族遗物。
- 代价：生命上限 -5；后续奖励扣除 0 次；下一房压力 +0。
- 演化：目标 淬火分梳（`fragments-temper`）；登记父件 `fragments-chisel`，演化组 `fragments`。实际来源在该父件及同组已持有分支中按预算降序、ID 升序选择，不能理解为同时移除整族。[遗物详情](appendix-current-relics.md)

### smelt-focus · 定本易形

交换即时威力与后续加工能力。

- 期限：本局（`run`）；激活：提交后；机制族：focus。
- 授予：`{"materialConserve":0.04}`。
- 资格：无额外能力前置；无指定天赋统计前置；须有可演化的同族遗物。
- 代价：生命上限 -5；后续奖励扣除 0 次；下一房压力 +0。
- 演化：目标 易形定本（`focus-sacrifice`）；登记父件 `focus-ink`，演化组 `focus`。实际来源在该父件及同组已持有分支中按预算降序、ID 升序选择，不能理解为同时移除整族。[遗物详情](appendix-current-relics.md)

## 归档（archive，3 个）

### archive-reserve · 余量入藏

把本局储备封存到之后的房间。

- 期限：本局（`run`）；激活：提交后；机制族：reserve。
- 授予：`{"heatCapacity":10}`。
- 资格：能力全部满足 `["recovery"]`；无指定天赋统计前置；须有可演化的同族遗物。
- 代价：生命上限 -4；后续奖励扣除 0 次；下一房压力 +0。
- 演化：目标 封存热匣（`reserve-archive`）；登记父件 `reserve-cruet`，演化组 `reserve`。实际来源在该父件及同组已持有分支中按预算降序、ID 升序选择，不能理解为同时移除整族。[遗物详情](appendix-current-relics.md)

### archive-copy · 覆文归档

放弃一次后续普通奖励，换取当前复写的结构改造。

- 期限：本局（`run`）；激活：提交后；机制族：copy。
- 授予：`{"copyInheritance":1}`。
- 资格：无额外能力前置；无指定天赋统计前置；须有可演化的同族遗物。
- 代价：生命上限 -0；后续奖励扣除 1 次；下一房压力 +0。
- 演化：目标 覆写底本（`copy-palimp`）；登记父件 `copy-quill`，演化组 `copy`。实际来源在该父件及同组已持有分支中按预算降序、ID 升序选择，不能理解为同时移除整族。[遗物详情](appendix-current-relics.md)

### archive-transport · 回航归档

给已拥有的运输结构增加回收出口。

- 期限：本局（`run`）；激活：提交后；机制族：transport。
- 授予：`{"heatCapacity":10}`。
- 资格：能力全部满足 `["carrier"]`；无指定天赋统计前置；须有可演化的同族遗物。
- 代价：生命上限 -5；后续奖励扣除 0 次；下一房压力 +0。
- 演化：目标 回航书袋（`transport-return`）；登记父件 `transport-satchel`，演化组 `transport`。实际来源在该父件及同组已持有分支中按预算降序、ID 升序选择，不能理解为同时移除整族。[遗物详情](appendix-current-relics.md)

## 校勘（proofread，3 个）

### proofread-letters · 词形重订

改变散字集中、分发与承载的关系。

- 期限：本局（`run`）；激活：提交后；机制族：letters。
- 授予：`{"carrierCapacity":1}`。
- 资格：无额外能力前置；无指定天赋统计前置；须有可演化的同族遗物。
- 代价：生命上限 -4；后续奖励扣除 0 次；下一房压力 +0。
- 演化：目标 词形重订（`letters-rebind`）；登记父件 `letters-dust`，演化组 `letters`。实际来源在该父件及同组已持有分支中按预算降序、ID 升序选择，不能理解为同时移除整族。[遗物详情](appendix-current-relics.md)

### proofread-gather · 聚字校勘

已兑现的标记部分改作载荷，不额外替玩家完成输入。

- 期限：本章（`chapter`）；激活：提交后；机制族：未登记。
- 授予：`{"markCarrier":1,"copyEfficiency":-0.02}`。
- 资格：无额外能力前置；天赋授予至少一项为正 `["letterScatter","copyPages"]`。
- 代价：生命上限 -3；后续奖励扣除 0 次；下一房压力 +0。
- 遗物替换：无。

### proofread-scatter · 分字校勘

把散字分向更多词条，降低单目标集中。

- 期限：本章（`chapter`）；激活：提交后；机制族：未登记。
- 授予：`{"letterScatter":1,"markSpread":1,"spellPower":-0.03}`。
- 资格：无额外能力前置；无指定天赋统计前置。
- 代价：生命上限 -0；后续奖励扣除 0 次；下一房压力 +0。
- 遗物替换：无。

## 契约（contract，3 个）

### contract-defense · 护文契约

牺牲部分承压余地改造防御出口。

- 期限：本局（`run`）；激活：提交后；机制族：defense。
- 授予：`{"carrierLifetime":0.5}`。
- 资格：能力全部满足 `["carrier"]`；无指定天赋统计前置；须有可演化的同族遗物。
- 代价：生命上限 -6；后续奖励扣除 0 次；下一房压力 +0。
- 演化：目标 新页反照（`defense-newest`）；登记父件 `defense-seal`，演化组 `defense`。实际来源在该父件及同组已持有分支中按预算降序、ID 升序选择，不能理解为同时移除整族。[遗物详情](appendix-current-relics.md)

### contract-geometry · 长廊契约

以更高后续压力换来远距交付路线。

- 期限：本局（`run`）；激活：提交后；机制族：geometry。
- 授予：`{"chainReach":25}`。
- 资格：无额外能力前置；无指定天赋统计前置；须有可演化的同族遗物。
- 代价：生命上限 -0；后续奖励扣除 0 次；下一房压力 +0.14。
- 演化：目标 折叠走廊（`geometry-fold`）；登记父件 `geometry-compass`，演化组 `geometry`。实际来源在该父件及同组已持有分支中按预算降序、ID 升序选择，不能理解为同时移除整族。[遗物详情](appendix-current-relics.md)

### contract-reserve · 细匣契约

增加回收效率，缩小容量并提高下一房压力。

- 期限：本局（`run`）；激活：提交后；机制族：未登记。
- 授予：`{"recoveryEfficiency":0.12,"heatCapacity":-12}`。
- 资格：能力全部满足 `["recovery"]`；无指定天赋统计前置。
- 代价：生命上限 -0；后续奖励扣除 0 次；下一房压力 +0.1。
- 遗物替换：无。

## 试炼（trial，3 个）

### trial-merge · 归并试炼

先承受下一房更高压力，清房后获得聚合规则。

- 期限：本局（`run`）；激活：清完下一房后；机制族：未登记。
- 授予：`{"mergePayload":1,"carrierCapacity":1,"carrierDelay":0.25}`。
- 资格：能力全部满足 `["carrier"]`；无指定天赋统计前置。
- 代价：生命上限 -0；后续奖励扣除 0 次；下一房压力 +0.18。
- 遗物替换：无。

### trial-supply · 燃字试炼

先完成压力房间，再取得更稳定的材料供给。

- 期限：本局（`run`）；激活：清完下一房后；机制族：未登记。
- 授予：`{"materialRate":0.12,"heatCapacity":12}`。
- 资格：无额外能力前置；无指定天赋统计前置。
- 代价：生命上限 -0；后续奖励扣除 0 次；下一房压力 +0.18。
- 遗物替换：无。

### trial-return · 遗页试炼

完成压力房间后，解锁剩余载荷回收。

- 期限：本局（`run`）；激活：清完下一房后；机制族：未登记。
- 授予：`{"paperRecovery":1,"missRecovery":1}`。
- 资格：能力全部满足 `["carrier"]`；无指定天赋统计前置。
- 代价：生命上限 -0；后续奖励扣除 0 次；下一房压力 +0.18。
- 遗物替换：无。

## 房间路线 · 6 条

这些是房间流向与即时奖励的入口，不是另外六个独立构筑事件。两条 `event` 路线进入上述事件系统；具体出现与目的地还受战役流程约束。

| ID | 名称 | 登记描述 | 房间类型 | 路线参数 |
| --- | --- | --- | --- | --- |
| `rest` | 安静的阅览室 | 恢复 26 点生命。 | `normal` | heal `26`；word `"rest"` |
| `trial` | 禁书试炼 | 更强的敌人，更多的经验。 | `elite` | word `"trial"` |
| `trade` | 错页商人 | 遇见修订事件，查看代价后选择借阅、演化或保留原稿。 | `event` | word `"trade"` |
| `shelter` | 留白的书房 | 获得 22 点护盾，恢复 10 点生命。 | `normal` | heal `10`；shield `22`；word `"shelter"` |
| `gift` | 未署名的赠礼 | 免费选择一件遗物。 | `normal` | relic `true`；word `"gift"` |
| `forge` | 朱砂工坊 | 研究构筑的另一种写法；以公开代价改变天赋与遗物的作用关系。 | `event` | word `"forge"` |

`word` 为路线输入词，`heal` / `shield` 为登记恢复量，`relic` 表示遗物奖励入口。图标等纯显示字段省略。
