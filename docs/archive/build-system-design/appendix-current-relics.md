# 当前遗物全量目录

> 历史归档：保留当时的方案、状态或检查结果，不作为当前待办、完成声明或实施约束。当前入口见[文档导航](../../README.md)。

[返回现状汇总](01-CURRENT-SYSTEM.md) · [研讨总纲](00-DESIGN-BRIEF.md)

基线 `767b349`，2026-09-23，共 140 件：68 件独立定义、72 件扩展定义。保留登记名称与 `desc` 原文；后续应逐项评估用途与表达，本步不作去留判断。

来源：[注册目录](../../../legacy/web/src/content/catalog.ts)、[扩展定义](../../../legacy/web/src/content/relics/expanded.ts)、[资格判断](../../../legacy/web/src/shared/relic-eligibility.ts)、[遗物执行](../../../legacy/web/src/simulation/RelicRules.ts)。独立定义另在各条目链接源文件。

字段读法：

- `grants` 为每层原始统计增量；`damageModifiers` 为伤害修正；`hooks` 为获取或施法时执行的效果。不能把三者相加当成最终收益。
- `provides` 声明能力；`needs` 要求已有能力；`modifies` 和 `connections` 表示关联，不能当成额外掉落前置。
- `requires`、`requiresLevels` 要求持有指定遗物；`book` 限制主书；`excludes` 需结合对方声明双向检查。天赋专属解锁目前没有独立字段。
- `affinity` 是权重倾向，不是法书硬限制。词长条件基于候选词库长度范围，详见资格判断代码。
- 未登记稀有度按当前展示惯例列为普通；预算未登记明确写“未登记”，不冒充已分配平衡预算。
- `eventOnly` 不进入普通奖励池；`evolution` 记载父件与组别，事件实际替换来源可能是该组已持有分支。
- 动态文案模板中的占位符需要场景和层数才能求值。这里只列模板和公式键，完整表达式保留在源定义；不是本次已算出的结果。

未列出的可选条件均未登记；图标、颜色等纯显示资源和输入快捷命令不在本玩法目录中展开。以下统计与描述未逐件进行运行验收。

## 独立定义 · 68 件

### power · 锋利笔尖

所有直接施法伤害提高 25%。

- 登记：标签 基础；稀有度 common（未显式登记）；最多 3 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/power/definition.ts)
- 授予：`{"directDamage":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。
- 伤害修正：`[{"factor":1.25,"perStack":true,"priority":10}]`。
- 动态描述登记：`{"template":"锋利笔尖伤害倍率 {power.damageMultiplier}；施法伤害 {cast.hit}。","castPreview":true}`。

### chain · 导电墨水

电弧多跳跃 1 个目标；非雷鸣咒典获得 1 次电弧跳跃。

- 登记：标签 雷鸣；稀有度 common（未显式登记）；最多 3 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/chain/definition.ts)
- 授予：`{"chainTargets":1}`。
- 能力与关联：provides `["conduction"]`；affinity `["storm"]`。
- 前置与互斥：无额外登记。
- 动态描述登记：`{"template":"普通施法电弧跳跃 {chain.count} 次。","castPreview":false}`；公式键 `["chain.count"]`。

### frost · 零度批注

所有施法附加寒气；已有寒气增加，冻结持续更久。

- 登记：标签 冰霜；稀有度 common（未显式登记）；最多 3 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/frost/definition.ts)
- 授予：`{"coldStacks":1}`。
- 能力与关联：provides `["cold"]`；affinity `["frost"]`。
- 前置与互斥：无额外登记。
- 动态描述登记：`{"template":"非冰霜施法附加 {cold.amount} 寒气；冻结 {cold.duration} 秒。冰霜直接施法基础积寒100。","castPreview":false}`；公式键 `["cold.amount","cold.duration"]`。

### shatter · 冰裂残页

冻结敌人死亡时爆裂，范围伤害提高，最多连锁三层。

- 登记：标签 冰霜；稀有度 common（未显式登记）；最多 2 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/shatter/definition.ts)
- 授予：`{"shatterStacks":1}`。
- 能力与关联：affinity `["frost"]`。
- 前置与互斥：无额外登记。
- 动态描述登记：`{"template":"冻结敌人死亡时爆裂，范围 {shatter.radius}，伤害 {shatter.damage}，最多连锁三层。","castPreview":false}`；公式键 `["shatter.radius","shatter.damage"]`。

### spirit · 折纸使魔

每次完词延长纸灵存在时间，纸灵数量上限增加1。每12个有效人工字符还可承载一张35%主术威力的复写页。

- 登记：标签 纸灵；稀有度 common（未显式登记）；最多 3 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/spirit/definition.ts)
- 授予：`{"summonStacks":1,"copyPages":1}`。
- 能力与关联：provides `["carrier"]`；affinity `["spirit"]`。
- 前置与互斥：无额外登记。
- 动态描述登记：`{"template":"纸灵上限 {summon.capacity}；未标记目标单次伤害 {summon.damage}；每词维持 {summon.duration} 秒（累计上限18秒）。每12个有效人工字符还可承载一张35%主术威力的复写页。","castPreview":false}`；公式键 `["summon.damage","summon.duration","summon.capacity"]`。

### echo · 双生笔尖

每第 3 次完词，向另一个敌人复制 65% 伤害法术。

- 登记：标签 连锁；稀有度 common（未显式登记）；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/echo/definition.ts)
- 授予：`{"echoCast":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。
- 动态描述登记：`{"template":"每第3次完词向另一敌人复制法术，伤害 {echo.damage}。","castPreview":true}`；公式键 `["echo.damage"]`。

### blast · 爆墨瓶

直接施法造成 90 范围溅射，伤害为本次施法的 35%。

- 登记：标签 爆破；稀有度 common（未显式登记）；最多 2 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/blast/definition.ts)
- 授予：`{"hitExplosion":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。
- 动态描述登记：`{"template":"直接施法造成 {blast.radius} 范围溅射，伤害 {blast.damage}。","castPreview":true}`；公式键 `["blast.radius","blast.ratio","blast.damage"]`。

### reflect · 镜面批注

拆弹反击伤害提高 60%；拆弹后下一次施法伤害翻倍。

- 登记：标签 反制；稀有度 common（未显式登记）；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/reflect/definition.ts)
- 授予：`{"reflectPower":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。

### dash · 折叠书页

闪避充能恢复加快 28%，充能上限增加 1。

- 登记：标签 生存；稀有度 common（未显式登记）；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/dash/definition.ts)
- 授予：`{"extraDash":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。
- 触发效果：`[{"phase":"acquire","priority":10,"effect":{"kind":"dashCharge","amount":1}}]`。
- 动态描述登记：`{"template":"闪避充能恢复间隔 {dash.cooldown} 秒；充能上限 {player.maxDash}。","castPreview":false}`；公式键 `["dash.cooldown"]`。

### dashnova · 留白之环

闪避后清除落点周围 135 范围的子弹，并推开附近敌人。

- 登记：标签 生存；稀有度 common（未显式登记）；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/dashnova/definition.ts)
- 授予：`{"dashShock":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。

### shield · 残句书签

输入中的目标被连锁或纸灵击杀，转化为 10 点护盾。

- 登记：标签 生存；稀有度 common（未显式登记）；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/shield/definition.ts)
- 授予：`{"partialWordShield":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。

### heal · 生命页签

最大生命增加 20，并立即回复 30 点生命。

- 登记：标签 恢复；稀有度 common（未显式登记）；最多 2 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/heal/definition.ts)
- 授予：`{"extraHealth":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。
- 触发效果：`[{"phase":"acquire","priority":10,"effect":{"kind":"maxHealth","amount":20,"heal":30}}]`。
- 动态描述登记：`{"template":"最大生命 {player.maxHp}；领取时立即回复30点生命（不超过最大生命）。","castPreview":false}`。

### leech · 朱砂印

每完成 6 次咒文恢复 4 点生命。

- 登记：标签 恢复；稀有度 common（未显式登记）；最多 2 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/leech/definition.ts)
- 授予：`{"castLeech":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。
- 触发效果：`[{"phase":"afterCast","priority":10,"every":6,"effect":{"kind":"heal","amount":4}}]`。
- 动态描述登记：`{"template":"每完成6次咒文获得 {leech.hook.0.amount} 点生命。"}`。

### short · 短咒连珠

长度不超过 4 的咒文伤害提高 60%，并回复少量闪避充能。

- 登记：标签 快攻；稀有度 common（未显式登记）；最多 2 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/short/definition.ts)
- 授予：`{"shortWordDamage":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：maxWordLength `4`。
- 动态描述登记：`{"template":"长度不超过4的咒文伤害倍率 {cast.short}，回复0.1次闪避充能；施法伤害 {cast.hit}。","castPreview":true,"wordLength":4}`；公式键 `["cast.short"]`。

### long · 长句回响

长度至少 7 的咒文伤害提高 75%，并清除目标周围子弹。

- 登记：标签 重击；稀有度 common（未显式登记）；最多 2 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/long/definition.ts)
- 授予：`{"longWordDamage":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：minWordLength `7`。
- 动态描述登记：`{"template":"长度至少7的咒文伤害倍率 {cast.long}，清除目标周围105范围子弹；施法伤害 {cast.hit}。","castPreview":true,"wordLength":7}`；公式键 `["cast.long"]`。

### perfect · 无瑕落款

本次咒文没有错字时，获得额外 35% 伤害。

- 登记：标签 精准；稀有度 common（未显式登记）；最多 2 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/perfect/definition.ts)
- 授予：`{"perfectDamage":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。
- 动态描述登记：`{"template":"无错字咒文伤害倍率 {cast.perfect}；施法伤害 {cast.hit}。","castPreview":true}`；公式键 `["cast.perfect"]`。

### feather · 通灵羽毛笔

每完成 4 次手动咒文，下一词输入前 2 个字母即可自动补全。

- 登记：标签 稀有；稀有度 rare；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/feather/definition.ts)
- 授予：`{"autofillCadence":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：minWordLength `3`。

### slow · 时间书签

锁定输入时，敌人与子弹移动速度降低 18%。

- 登记：标签 控场；稀有度 common（未显式登记）；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/slow/definition.ts)
- 授予：`{"aimingSlow":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。

### armor · 硬壳书封

受到的伤害减少 25%。

- 登记：标签 生存；稀有度 common（未显式登记）；最多 2 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/armor/definition.ts)
- 授予：`{"damageArmor":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。
- 动态描述登记：`{"template":"受到的伤害倍率 {armor.multiplier}。","castPreview":false}`；公式键 `["armor.multiplier"]`。

### pulse · 段落终结

每完成 5 次咒文，释放以自身为中心的清弹冲击波。

- 登记：标签 爆破；稀有度 common（未显式登记）；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/pulse/definition.ts)
- 授予：`{"castPulse":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。
- 触发效果：`[{"phase":"afterCast","priority":30,"every":5,"exclusiveGroup":"cast-pulse","effect":{"kind":"pulse","radius":220,"damage":35}}]`。

### gold · 鎏金藏书票

之后击杀获得的经验增加 35%。

- 登记：标签 成长；稀有度 common（未显式登记）；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/gold/definition.ts)
- 授予：`{"experienceBoost":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。

### crit · 惊叹号

每第 4 次直接施法必定暴击，造成 2 倍伤害。

- 登记：标签 重击；稀有度 common（未显式登记）；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/crit/definition.ts)
- 授予：`{"criticalCadence":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。
- 动态描述登记：`{"template":"每第4次直接施法必定暴击；施法伤害 {cast.hit}，暴击 {cast.critical}。","castPreview":true}`；公式键 `["crit.multiplier","cast.critical"]`。

### reach · 远行墨迹

电弧传导范围增加 100，爆炸范围增加 25。

- 登记：标签 连锁；稀有度 common（未显式登记）；最多 2 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/reach/definition.ts)
- 授予：`{"effectReach":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。
- 动态描述登记：`{"template":"电弧传导范围 {chain.radius}；爆墨瓶范围 {blast.radius}。","castPreview":false}`；公式键 `["chain.radius"]`。

### rescue · 未完待续

受到致命伤时复活一次，回复 45% 生命并清屏。

- 登记：标签 稀有；稀有度 rare；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/rescue/definition.ts)
- 授予：`{"lethalRescue":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。
- 动态描述登记：`{"template":"受到致命伤时复活一次，回复 {rescue.health} 点生命并清屏。","castPreview":false}`；公式键 `["rescue.health"]`。

### heavy · 鲸骨笔杆

法术击退提高60%；撞墙与撞敌造成的碰撞伤害翻倍。

- 登记：标签 冲击；稀有度 common（未显式登记）；最多 2 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/heavy/definition.ts)
- 授予：`{"impulsePower":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。
- 动态描述登记：`{"template":"法术击退倍率 {impulse.multiplier}；碰撞伤害翻倍。","castPreview":false}`；公式键 `["impulse.multiplier"]`。

### gravity · 引力墨核

直接施法命中时，牵引附近敌人靠近落点，便于穿透与连锁。

- 登记：标签 控场；稀有度 common（未显式登记）；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/gravity/definition.ts)
- 授予：`{"gravityOnHit":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。

### execute · 终止符

直接施法处决生命低于18%的普通敌人；对Boss伤害提高15%。

- 登记：标签 重击；稀有度 common（未显式登记）；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/execute/definition.ts)
- 授予：`{"execution":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。

### bleed · 腐蚀墨迹

直接施法留下4秒腐蚀，每秒造成8点伤害，最多叠3层。

- 登记：标签 持续；稀有度 common（未显式登记）；最多 2 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/bleed/definition.ts)
- 授予：`{"bleedStacks":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。
- 动态描述登记：`{"template":"直接施法留下4秒腐蚀，每秒伤害 {bleed.damage}，状态最多叠3层。","castPreview":false}`；公式键 `["bleed.damage"]`。

### nova · 完美段落

连续完成3次无错字咒文，释放一次半径150的清弹冲击波。

- 登记：标签 精准；稀有度 common（未显式登记）；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/nova/definition.ts)
- 授予：`{"perfectPulse":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。
- 触发效果：`[{"phase":"afterCast","priority":40,"every":3,"counter":"perfectWords","perfectOnly":true,"exclusiveGroup":"cast-pulse","effect":{"kind":"pulse","radius":150,"damage":24}}]`。

### rhythm · 连笔字帖

连笔伤害加成翻倍：最多额外获得25%施法伤害。

- 登记：标签 快攻；稀有度 common（未显式登记）；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/rhythm/definition.ts)
- 授予：`{"comboPower":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。
- 动态描述登记：`{"template":"连笔伤害倍率 {cast.combo}；施法伤害 {cast.hit}。","castPreview":true}`；公式键 `["cast.combo"]`。

### brittle · 脆裂书页

冻结敌人受到的施法伤害额外提高40%；非冰霜咒典也生效。

- 登记：标签 冰霜；稀有度 common（未显式登记）；最多 2 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/brittle/definition.ts)
- 授予：`{"frozenVulnerability":1}`。
- 能力与关联：affinity `["frost"]`。
- 前置与互斥：无额外登记。
- 动态描述登记：`{"template":"冻结敌人受到的施法伤害倍率 {frozen.multiplier}；强化冰枪再乘1.25。","castPreview":false}`；公式键 `["frozen.multiplier"]`。

### permafrost · 永冻墨池

霜场持续增加3秒，半径增加35；无霜场时施法额外生成小型霜场。

- 登记：标签 冰霜；稀有度 common（未显式登记）；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/permafrost/definition.ts)
- 授予：`{"frostField":1}`。
- 能力与关联：affinity `["frost"]`。
- 前置与互斥：无额外登记。

### conductor · 超导银墨

电弧跳跃衰减减轻，导电引爆伤害提高35%。

- 登记：标签 雷鸣；稀有度 common（未显式登记）；最多 2 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/conductor/definition.ts)
- 授予：`{"chainConduction":1}`。
- 能力与关联：affinity `["storm"]`。
- 前置与互斥：无额外登记。
- 动态描述登记：`{"template":"电弧每跳伤害倍率 {chain.retention}；导电引爆伤害 {overload.damage}，周围敌人受到其70%。","castPreview":false}`；公式键 `["overload.damage","chain.retention"]`。

### stormcell · 避雷印

过载爆炸会清除半径135内的敌弹；非雷鸣咒典命中也积累导电。

- 登记：标签 雷鸣；稀有度 common（未显式登记）；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/stormcell/definition.ts)
- 授予：`{"directConduction":1}`。
- 能力与关联：affinity `["storm"]`。
- 前置与互斥：无额外登记。

### bond · 共命书线

纸灵攻击提高30%，每词额外维持2秒；无纸灵时唤醒一只。

- 登记：标签 纸灵；稀有度 common（未显式登记）；最多 2 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/bond/definition.ts)
- 授予：`{"summonBond":1}`。
- 能力与关联：affinity `["spirit"]`。
- 前置与互斥：无额外登记。
- 动态描述登记：`{"template":"每次完词维持纸灵，无纸灵时唤醒一只。纸灵上限 {summon.capacity}；未标记目标单次伤害 {summon.damage}；每词维持 {summon.duration} 秒（累计上限18秒）。","castPreview":false}`。

### sacrifice · 背水誓书

生命低于40%时，施法和纸灵伤害提高50%。

- 登记：标签 风险；稀有度 common（未显式登记）；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/sacrifice/definition.ts)
- 授予：`{"lowHealthPower":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。
- 伤害修正：`[{"factor":1.5,"belowHealth":0.4,"priority":40}]`。
- 动态描述登记：`{"template":"低生命条件生效时提高施法与纸灵伤害，当前倍率 {sacrifice.damageMultiplier}。 施法伤害 {cast.hit}。","castPreview":true}`。

### magnet · 折返墨涡

闪避起点留下引力井，短暂牵引附近敌人，落点释放小型清弹。

- 登记：标签 生存；稀有度 common（未显式登记）；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/magnet/definition.ts)
- 授予：`{"dashMagnet":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。

### graze · 飞白笔锋

擦弹获得双倍共鸣，同时获得少量护盾；每颗子弹仅结算一次。

- 登记：标签 反制；稀有度 common（未显式登记）；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/graze/definition.ts)
- 授予：`{"grazeCharge":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。

### ward · 护页结界

每完成5词获得12点护盾，护盾最多60。

- 登记：标签 生存；稀有度 common（未显式登记）；最多 2 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/ward/definition.ts)
- 授予：`{"castWard":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。
- 触发效果：`[{"phase":"afterCast","priority":20,"every":5,"effect":{"kind":"shield","amount":12,"cap":60,"color":"#c3aaf1"}}]`。
- 动态描述登记：`{"template":"每完成5次咒文获得 {ward.hook.0.amount} 点护盾。"}`。

### haste · 共鸣墨晶

完词获得的共鸣提高35%。

- 登记：标签 终式；稀有度 common（未显式登记）；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/haste/definition.ts)
- 授予：`{"resonanceHaste":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。

### hourglass · 停笔沙漏

闪避后世界以10%速度流动，持续1.5秒；期间可继续打字施法，闪避与弹反仍按真实时间恢复。

- 登记：标签 闪避；稀有度 common（未显式登记）；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/hourglass/definition.ts)
- 授予：`{"precisionWindow":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。

### bloodprice · 血字契约

施法伤害提高40%；领取时及之后每进入新的一页损失8生命，同一页只扣一次，不会致死。

- 登记：标签 诅咒；稀有度 curse；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/bloodprice/definition.ts)
- 授予：`{"roomHealthCost":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。
- 伤害修正：`[{"factor":1.4,"priority":20}]`。
- 触发效果：`[{"phase":"acquire","priority":10,"effect":{"kind":"bloodPrice","amount":8}}]`。
- 动态描述登记：`{"template":"施法伤害倍率 {bloodprice.damageMultiplier}；领取时及之后每页损失 {bloodprice.hook.0.amount} 点生命，同页只扣一次，不会致死。 施法伤害 {cast.hit}。","castPreview":true}`。

### glass · 玻璃书封

施法与纸灵伤害提高45%，受到的伤害也提高30%。

- 登记：标签 诅咒；稀有度 curse；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/glass/definition.ts)
- 授予：`{"fragileDamage":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。
- 伤害修正：`[{"factor":1.45,"priority":30}]`。
- 动态描述登记：`{"template":"施法与纸灵伤害倍率 {glass.damageMultiplier}；受伤倍率（含护甲）{armor.multiplier}。 施法伤害 {cast.hit}。","castPreview":true}`。

### avalanche · 雪崩圣典

冻裂击杀向四周射出6枚冰针，冰枪额外穿透2次；连锁冰针不再自我复制。

- 登记：标签 觉醒；稀有度 awaken；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/avalanche/definition.ts)
- 授予：`{"deathFrostVolley":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：book `"frost"`；requires `["shatter","permafrost"]`。

### iceheart · 凛冬残卷

冰河纪事获得30护盾，持续冰针雨更密集；重型冰矛额外冻结附近敌人。

- 登记：标签 觉醒；稀有度 awaken；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/iceheart/definition.ts)
- 授予：`{"empoweredFreeze":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：book `"frost"`；requires `["frost","brittle"]`。

### superconductor · 超导禁卷

电弧额外跳跃2次，过载向内牵引敌人并造成更大范围爆炸。

- 登记：标签 觉醒；稀有度 awaken；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/superconductor/definition.ts)
- 授予：`{"overloadPull":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：book `"storm"`；requires `["chain","conductor"]`。
- 动态描述登记：`{"template":"{description} 普通施法电弧跳跃 {chain.count} 次。","castPreview":false}`。

### thunderheart · 永昼雷章

雷鸣终章延长3秒；期间每次完词额外落下两道雷击，命中回复少量护盾。

- 登记：标签 觉醒；稀有度 awaken；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/thunderheart/definition.ts)
- 授予：`{"ultimateChain":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：book `"storm"`；requires `["stormcell","haste"]`。

### legion · 千纸军团

增加3只纸灵；每次交叉斩额外发动一次全员俯冲。仍需要完词维持。

- 登记：标签 觉醒；稀有度 awaken；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/legion/definition.ts)
- 授予：`{"summonLegion":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：book `"spirit"`；requires `["spirit","bond"]`。
- 动态描述登记：`{"template":"{description} 纸灵上限 {summon.capacity}；未标记目标单次伤害 {summon.damage}；每词维持 {summon.duration} 秒（累计上限18秒）。","castPreview":false}`。

### marionette · 傀儡纸冠

纸灵在飞行中拦截敌弹；击杀标记目标额外获得8点共鸣。

- 登记：标签 觉醒；稀有度 awaken；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/marionette/definition.ts)
- 授予：`{"summonedMark":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：book `"spirit"`；requires `["ward","shield"]`。

### cinder · 余烬墨水

火焰每跳伤害提高30%。

- 登记：标签 火焰；稀有度 common（未显式登记）；最多 3 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/cinder/definition.ts)
- 授予：`{"burnPower":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：book `"flame"`。
- 动态描述登记：`{"template":"灼烧每层每跳伤害 {burn.damage}，每0.5秒结算一次。","castPreview":false}`；公式键 `["burn.damage"]`。

### pitch · 松脂印章

灼烧持续时间延长1秒。

- 登记：标签 火焰；稀有度 common（未显式登记）；最多 2 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/pitch/definition.ts)
- 授予：`{"burnDuration":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：book `"flame"`。
- 动态描述登记：`{"template":"灼烧持续 {burn.duration} 秒。","castPreview":false}`；公式键 `["burn.duration"]`。

### wildfire · 野火书签

燃烧敌人死亡时传播灼烧，最多传播两代；每层增加传播距离与目标数。

- 登记：标签 火焰；稀有度 common（未显式登记）；最多 2 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/wildfire/definition.ts)
- 授予：`{"burnSpread":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：book `"flame"`。
- 动态描述登记：`{"template":"燃烧敌人死亡时传播灼烧，最多两代；传播距离 {burn.spreadRadius}，目标数 {burn.spreadTargets}。","castPreview":false}`；公式键 `["burn.spreadRadius","burn.spreadTargets"]`。

### crucible · 熔炉封蜡

火弹熔爆与爆炸火场半径增加25。

- 登记：标签 火焰；稀有度 common（未显式登记）；最多 2 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/crucible/definition.ts)
- 授予：`{"fireRadius":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：book `"flame"`。
- 动态描述登记：`{"template":"普通火弹爆炸火场半径 {fire.radius}；强化施法采用同一公式的强化分支。","castPreview":false}`；公式键 `["fire.radius"]`。

### coal · 炽炭书封

每次熔爆施法获得5点护盾。

- 登记：标签 火焰；稀有度 common（未显式登记）；最多 2 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/coal/definition.ts)
- 授予：`{"emberShield":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：book `"flame"`。
- 动态描述登记：`{"template":"每次熔爆施法获得 {coal.shield} 点护盾，上限60。","castPreview":false}`；公式键 `["coal.shield"]`。

### firewalk · 灼痕行书

闪避火场半径增加20，持续时间延长1秒。

- 登记：标签 火焰；稀有度 common（未显式登记）；最多 2 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/firewalk/definition.ts)
- 授予：`{"fireTrail":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：book `"flame"`。
- 动态描述登记：`{"template":"闪避火场半径 {fireTrail.radius}，持续 {fireTrail.duration} 秒。","castPreview":false}`；公式键 `["fireTrail.radius","fireTrail.duration"]`。

### inferno · 不灭灰烬卷

灼烧上限提高至5层；终式延长至7秒，陨火间隔缩短至0.45秒。

- 登记：标签 觉醒；稀有度 awaken；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/inferno/definition.ts)
- 授予：`{"inferno":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：book `"flame"`；requires `["cinder","pitch"]`。

### inscription · 返咒铭文

弹反伤害附带咒典效果：冰霜积寒、雷鸣导电、火焰灼烧、纸灵标记并唤醒纸灵。

- 登记：标签 弹反；稀有度 common（未显式登记）；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/inscription/definition.ts)
- 授予：`{"parryAffinity":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。

### rebound · 回锋笔套

弹反冷却缩短 30%：0.70 秒 → 0.49 秒。

- 登记：标签 弹反；稀有度 common（未显式登记）；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/rebound/definition.ts)
- 授予：`{"parryHaste":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。
- 动态描述登记：`{"template":"弹反冷却 {parry.cooldown} 秒。","castPreview":false}`；公式键 `["parry.cooldown"]`。

### copyfolio · 复写页

每12个人工有效字符生成一张复写主术的纸页，造成主术35%伤害。纸页1.8秒后寻敌释放，存在5秒；无目标时等待至过期。Ⅰ阶同时最多1页，Ⅱ阶3页。

- 登记：标签 承载；稀有度 common（未显式登记）；最多 2 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/copyfolio/definition.ts)
- 授予：`{"copyPages":1}`。
- 能力与关联：provides `["carrier"]`；modifies `["carrier"]`。
- 前置与互斥：无额外登记。

### guardseal · 护封

未释放的承载纸页可消耗自身，拦截一次普通敌弹。防御消耗与正常释放只能兑现一次。

- 登记：标签 防御；稀有度 common（未显式登记）；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/guardseal/definition.ts)
- 授予：`{"carrierGuard":1}`。
- 能力与关联：provides `["guard"]`；needs `["carrier"]`；modifies `["carrier","release"]`。
- 前置与互斥：无额外登记。

### swiftbinding · 速朽装订

复写页每份成本降至8个人工有效字符，但纸页寿命缩至1秒。正常释放仍需1.8秒；须经防御消耗或遗响才能兑现短命纸页。

- 登记：标签 承载；稀有度 common（未显式登记）；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/swiftbinding/definition.ts)
- 授予：`{"swiftBinding":1}`。
- 能力与关联：needs `["carrier"]`；modifies `["carrier","guard","release"]`。
- 前置与互斥：无额外登记。

### scatterfolio · 散页分发

将Ⅱ阶复写页装订为散页：每份生成2张纸页，各造成主术25%伤害，同时最多6页。与重印孤页互斥。

- 登记：标签 分发；稀有度 common（未显式登记）；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/scatterfolio/definition.ts)
- 授予：`{"scatterPages":1}`。
- 能力与关联：needs `["carrier"]`；modifies `["carrier"]`。
- 前置与互斥：requires `["copyfolio"]`；requiresLevels `{"copyfolio":2}`；excludes `["heavyfolio"]`。

### heavyfolio · 重印孤页

将Ⅱ阶复写页装订为重印：同时最多1张纸页，每份造成主术70%伤害。与散页分发互斥。

- 登记：标签 重印；稀有度 common（未显式登记）；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/heavyfolio/definition.ts)
- 授予：`{"heavyPages":1}`。
- 能力与关联：needs `["carrier"]`；modifies `["carrier"]`。
- 前置与互斥：requires `["copyfolio"]`；requiresLevels `{"copyfolio":2}`；excludes `["scatterfolio"]`。

### thermalvault · 余热匣

敌人死亡时回收人工主术尚未结算的灼烧，下一次人工施法自动附加储热。Ⅰ阶回收35%、容量60、每次最多释放30；Ⅱ阶50%、100、50。派生产物不再次回收。

- 登记：标签 回收；稀有度 common（未显式登记）；最多 2 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/thermalvault/definition.ts)
- 授予：`{"heatRecovery":1}`。
- 能力与关联：provides `["recovery"]`；modifies `["heat","recovery"]`。
- 前置与互斥：无额外登记。

### crystalframe · 冰晶书脊

每次人工主术携带冰晶结构，基础积寒30。若同时携带火载荷，命中时消耗晶体释放3枚灼热碎片，总计造成主术45%伤害。

- 登记：标签 冰结构；稀有度 common（未显式登记）；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/crystalframe/definition.ts)
- 授予：`{"crystalPayload":1}`。
- 能力与关联：provides `["cold"]`；modifies `["heat"]`。
- 前置与互斥：无额外登记。

### emberink · 余烬墨

每12个人工有效字符供应一份火载荷，最多缓存3份。下一次人工主术命中附加灼烧，每次主术最多使用一份。

- 登记：标签 火载荷；稀有度 common（未显式登记）；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/emberink/definition.ts)
- 授予：`{"heatPayload":1}`。
- 能力与关联：provides `["heat"]`；modifies `["cold","recovery"]`。
- 前置与互斥：无额外登记。

### wirestitch · 导电缝线

每12个人工有效字符供应一份传导，最多缓存3份。人工主术命中后最多传至2个邻敌，总计造成主术40%伤害；每次主术最多使用一份。

- 登记：标签 传导；稀有度 common（未显式登记）；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/wirestitch/definition.ts)
- 授予：`{"conductionPayload":1}`。
- 能力与关联：provides `["conduction"]`；modifies `["conduction"]`。
- 前置与互斥：无额外登记。

### letterwake · 散字余音

正在输入的目标被友方击杀时，已输入字母飞向其他词条并点亮同字母。亲手输入每个亮字母，使该次主术伤害增加15%。残响仍可续写。

- 登记：标签 字符 · 续写；稀有度 rare；最多 1 层；预算 未登记；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/letterwake/definition.ts)
- 授予：`{"letterScatter":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。

## 复写（copy） · 6 件

### copy-quill · 双尖抄笔

以实际人工字符供给复写页，保存法术的基础形态。

- 登记：标签 复写；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"copyPages":1}`。
- 能力与关联：provides `["carrier"]`。
- 前置与互斥：无额外登记。

### copy-margin · 宽边抄本

提高复制威力折算并增加一格容量。

- 登记：标签 复写；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"copyEfficiency":0.065,"carrierCapacity":1}`。
- 能力与关联：modifies `["carrier"]`。
- 前置与互斥：无额外登记。

### copy-many · 分栏复写

同一付费额度分成更多较弱片段，容量扩大。

- 登记：标签 复写；稀有度 rare；最多 1 层；预算 16；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"copyPages":1,"forkPayload":1,"carrierCapacity":2,"copyEfficiency":-0.04}`。
- 能力与关联：provides `["carrier"]`。
- 前置与互斥：requires `["copy-quill"]`；excludes `["copy-deep","copy-palimp"]`。
- 替换关系：`{"from":"copy-quill","group":"copy"}`。

### copy-deep · 重墨复写

更少落点保存较强片段，增加交付等待。

- 登记：标签 复写；稀有度 rare；最多 1 层；预算 16；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"copyPages":1,"concentrate":1,"copyEfficiency":0.1,"carrierDelay":0.35}`。
- 能力与关联：provides `["carrier"]`。
- 前置与互斥：requires `["copy-quill"]`；excludes `["copy-many","copy-palimp"]`。
- 替换关系：`{"from":"copy-quill","group":"copy"}`。

### copy-inherit · 同文底片

复制继承合法加工方式；与晶壳、热加工和电性转交连接。

- 登记：标签 复写；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"copyInheritance":1,"materialConserve":0.05}`。
- 能力与关联：modifies `["carrier"]`；connections `["copy-many","copy-deep"]`。
- 前置与互斥：无额外登记。

### copy-palimp · 覆写底本

本局用部分复制威力换成加工继承与更高容量。

- 登记：标签 复写；稀有度 rare；最多 1 层；预算 16；仅事件获取。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"copyPages":1,"copyInheritance":1,"carrierCapacity":3,"copyEfficiency":-0.08}`。
- 能力与关联：provides `["carrier"]`。
- 前置与互斥：requires `["copy-quill"]`；excludes `["copy-many","copy-deep"]`。
- 替换关系：`{"from":"copy-quill","group":"copy"}`。

## 装订（binding） · 6 件

### binding-clasp · 护文搭扣

载体获得防御出口；攻击与防御竞争同一载荷。

- 登记：标签 装订；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"carrierGuard":1}`。
- 能力与关联：provides `["guard"]`；needs `["carrier"]`；modifies `["release"]`。
- 前置与互斥：无额外登记。

### binding-spine · 延寿书脊

增加载体寿命和容量，保留已支付的反击机会。

- 登记：标签 装订；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"carrierLifetime":1.6,"carrierCapacity":1}`。
- 能力与关联：needs `["carrier"]`；modifies `["release","guard"]`。
- 前置与互斥：无额外登记。

### binding-guard · 守页装订

优先保留防御页，延长留存，减少正常自动交付。

- 登记：标签 装订；稀有度 rare；最多 1 层；预算 16；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"carrierGuard":1,"carrierRetain":1,"carrierLifetime":1.8}`。
- 能力与关联：provides `["guard"]`；needs `["carrier"]`；modifies `["release"]`。
- 前置与互斥：requires `["binding-clasp"]`；excludes `["binding-cadence","binding-newest"]`。
- 替换关系：`{"from":"binding-clasp","group":"binding"}`。

### binding-cadence · 走页装订

更快交付并缩短留存，防御可用窗口减少。

- 登记：标签 装订；稀有度 rare；最多 1 层；预算 16；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"carrierGuard":1,"carrierDelay":-0.65,"carrierLifetime":-1,"copyCadence":1}`。
- 能力与关联：provides `["guard"]`；needs `["carrier"]`；modifies `["release"]`。
- 前置与互斥：requires `["binding-clasp"]`；excludes `["binding-guard","binding-newest"]`。
- 替换关系：`{"from":"binding-clasp","group":"binding"}`。

### binding-coda · 终章扣

终结时交出未用载荷，兼容受热与防御出口。

- 登记：标签 装订；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"carrierRelease":1}`。
- 能力与关联：provides `["release"]`；needs `["carrier"]`；modifies `["release","guard"]`；connections `["binding-guard","binding-cadence"]`。
- 前置与互斥：无额外登记。

### binding-newest · 新页守则

优先消耗最新护页，把旧页留给原交付路径。

- 登记：标签 装订；稀有度 rare；最多 1 层；预算 16；仅事件获取。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"carrierGuard":1,"guardNewest":1,"carrierRelease":1,"carrierCapacity":-1}`。
- 能力与关联：provides `["guard","release"]`；needs `["carrier"]`；modifies `["release"]`。
- 前置与互斥：requires `["binding-clasp"]`；excludes `["binding-guard","binding-cadence"]`。
- 替换关系：`{"from":"binding-clasp","group":"binding"}`。

## 晶壳（crystal） · 6 件

### crystal-seed · 空心晶种

提供可加工晶体结构。

- 登记：标签 晶壳；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"crystalPayload":1}`。
- 能力与关联：provides `["cold"]`。
- 前置与互斥：无额外登记。

### crystal-wall · 层晶匣壁

晶壳储存有限片段，提高留存寿命。

- 登记：标签 晶壳；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"crystalStorage":1,"carrierLifetime":1.2}`。
- 能力与关联：provides `["carrier"]`；modifies `["cold"]`。
- 前置与互斥：无额外登记。

### crystal-whole · 完整透镜

集中晶体内的份额并穿透，减少碎片数量。

- 登记：标签 晶壳；稀有度 rare；最多 1 层；预算 16；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"crystalPayload":1,"concentrate":1,"payloadPierce":1,"fragmentCount":-1}`。
- 能力与关联：provides `["cold"]`。
- 前置与互斥：requires `["crystal-seed"]`；excludes `["crystal-brittle","crystal-vault"]`。
- 替换关系：`{"from":"crystal-seed","group":"crystal"}`。

### crystal-brittle · 薄壁晶胆

更易展开为多片，放弃部分本体份额。

- 登记：标签 晶壳；稀有度 rare；最多 1 层；预算 16；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"crystalPayload":1,"fragmentCount":2,"fragmentShare":0.12}`。
- 能力与关联：provides `["cold"]`。
- 前置与互斥：requires `["crystal-seed"]`；excludes `["crystal-whole","crystal-vault"]`。
- 替换关系：`{"from":"crystal-seed","group":"crystal"}`。

### crystal-fuse · 熔缝晶扣

热材料可提前释放晶壳内部片段。

- 登记：标签 晶壳；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"thermalRelease":1,"materialConserve":0.05}`。
- 能力与关联：modifies `["cold"]`；connections `["crystal-whole","crystal-brittle"]`。
- 前置与互斥：无额外登记。

### crystal-vault · 冰藏定本

把晶体改作更耐久的容器，交付延迟。

- 登记：标签 晶壳；稀有度 rare；最多 1 层；预算 16；仅事件获取。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"crystalPayload":1,"crystalStorage":1,"carrierCapacity":2,"carrierLifetime":2,"carrierDelay":0.6}`。
- 能力与关联：provides `["cold","carrier"]`。
- 前置与互斥：requires `["crystal-seed"]`；excludes `["crystal-whole","crystal-brittle"]`。
- 替换关系：`{"from":"crystal-seed","group":"crystal"}`。

## 炉心（thermal） · 6 件

### thermal-wick · 字火灯芯

人工字符供给有限热材料。

- 登记：标签 炉心；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"heatPayload":1}`。
- 能力与关联：provides `["heat"]`。
- 前置与互斥：无额外登记。

### thermal-bellows · 页间风箱

提高热材料供给率，扩大有限储备。

- 登记：标签 炉心；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"materialRate":0.1,"heatCapacity":15}`。
- 能力与关联：modifies `["heat"]`。
- 前置与互斥：无额外登记。

### thermal-patient · 缓燃炉膛

保存更多热量，以更高阈值延迟兑现。

- 登记：标签 炉心；稀有度 rare；最多 1 层；预算 16；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"heatPayload":1,"heatCapacity":40,"reserveThreshold":14}`。
- 能力与关联：provides `["heat"]`。
- 前置与互斥：requires `["thermal-wick"]`；excludes `["thermal-flash","thermal-anneal"]`。
- 替换关系：`{"from":"thermal-wick","group":"thermal"}`。

### thermal-flash · 速燃引线

热量提前推动载体出口，留存缩短。

- 登记：标签 炉心；稀有度 rare；最多 1 层；预算 16；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"heatPayload":1,"thermalRelease":1,"carrierLifetime":-1}`。
- 能力与关联：provides `["heat"]`。
- 前置与互斥：requires `["thermal-wick"]`；excludes `["thermal-patient","thermal-anneal"]`。
- 替换关系：`{"from":"thermal-wick","group":"thermal"}`。

### thermal-siphon · 续写虹吸

完词从上个合法人工目标抽取既存灼烧，折损后供下词使用。

- 登记：标签 炉心；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"recoveryExtract":1,"heatRecovery":1}`。
- 能力与关联：provides `["recovery"]`；modifies `["heat"]`；connections `["thermal-patient","thermal-flash"]`。
- 前置与互斥：无额外登记。

### thermal-anneal · 退火封装

较少即时威力换取晶壳封装与更高热量容量。

- 登记：标签 炉心；稀有度 rare；最多 1 层；预算 16；仅事件获取。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"heatPayload":1,"crystalStorage":1,"heatCapacity":35,"spellPower":-0.04}`。
- 能力与关联：provides `["heat","carrier"]`。
- 前置与互斥：requires `["thermal-wick"]`；excludes `["thermal-patient","thermal-flash"]`。
- 替换关系：`{"from":"thermal-wick","group":"thermal"}`。

## 电路（conduction） · 6 件

### conduction-coil · 字电线圈

人工字符供给可分配的有限电荷。

- 登记：标签 电路；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"conductionPayload":1}`。
- 能力与关联：provides `["conduction"]`。
- 前置与互斥：无额外登记。

### conduction-braid · 双股导索

延长电性片段传递范围并提高加工保留。

- 登记：标签 电路；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"chainReach":65,"materialConserve":0.04}`。
- 能力与关联：modifies `["conduction"]`。
- 前置与互斥：无额外登记。

### conduction-long · 长距孤弧

减少落点以延伸距离，适合分散目标。

- 登记：标签 电路；稀有度 rare；最多 1 层；预算 16；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"conductionPayload":1,"chainReach":145,"chainCount":-1}`。
- 能力与关联：provides `["conduction"]`。
- 前置与互斥：requires `["conduction-coil"]`；excludes `["conduction-mesh","conduction-focus"]`。
- 替换关系：`{"from":"conduction-coil","group":"conduction"}`。

### conduction-mesh · 近距密网

增加跳转分配，单份更薄且距离缩短。

- 登记：标签 电路；稀有度 rare；最多 1 层；预算 16；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"conductionPayload":1,"chainCount":2,"chainReach":-65}`。
- 能力与关联：provides `["conduction"]`。
- 前置与互斥：requires `["conduction-coil"]`；excludes `["conduction-long","conduction-focus"]`。
- 替换关系：`{"from":"conduction-coil","group":"conduction"}`。

### conduction-relay · 页桥接点

把承载物加入有限电性路径，不复制整条链。

- 登记：标签 电路；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"carrierRelay":1,"chainReach":35}`。
- 能力与关联：modifies `["conduction"]`；connections `["conduction-long","conduction-mesh"]`。
- 前置与互斥：无额外登记。

### conduction-focus · 定向电桥

把电性份额集中交付，牺牲广域跳转。

- 登记：标签 电路；稀有度 rare；最多 1 层；预算 16；仅事件获取。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"conductionPayload":1,"concentrate":1,"chainCount":-1,"chainShare":0.06}`。
- 能力与关联：provides `["conduction"]`。
- 前置与互斥：requires `["conduction-coil"]`；excludes `["conduction-long","conduction-mesh"]`。
- 替换关系：`{"from":"conduction-coil","group":"conduction"}`。

## 几何（geometry） · 6 件

### geometry-compass · 寻页规

扩大法术自动交付范围。

- 登记：标签 几何；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"chainReach":65}`。
- 能力与关联：modifies `["conduction","carrier"]`。
- 前置与互斥：无额外登记。

### geometry-map · 折距图

扩大交付范围并延长载体等待。

- 登记：标签 几何；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"chainReach":45,"carrierLifetime":1.2}`。
- 能力与关联：modifies `["conduction","carrier"]`。
- 前置与互斥：无额外登记。

### geometry-lens · 收束透镜

减少落点，集中已付威力，削减广域分配。

- 登记：标签 几何；稀有度 rare；最多 1 层；预算 16；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"chainReach":65,"concentrate":1,"chainCount":-1}`。
- 能力与关联：modifies `["conduction","carrier"]`。
- 前置与互斥：requires `["geometry-compass"]`；excludes `["geometry-fan","geometry-fold"]`。
- 替换关系：`{"from":"geometry-compass","group":"geometry"}`。

### geometry-fan · 展开扇尺

把已有份额分给更多接收者，放弃单体集中。

- 登记：标签 几何；稀有度 rare；最多 1 层；预算 16；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"chainReach":65,"forkPayload":1,"fragmentCount":1}`。
- 能力与关联：modifies `["conduction","carrier"]`。
- 前置与互斥：requires `["geometry-compass"]`；excludes `["geometry-lens","geometry-fold"]`。
- 替换关系：`{"from":"geometry-compass","group":"geometry"}`。

### geometry-corridor · 旁路图

载体接力与未命中回收共同处理失去的目标。

- 登记：标签 几何；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"carrierRelay":1,"missRecovery":1}`。
- 能力与关联：provides `["recovery"]`；modifies `["conduction","carrier"]`；connections `["geometry-lens","geometry-fan"]`。
- 前置与互斥：无额外登记。

### geometry-fold · 折叠走廊

延长中继距离，增加交付等待并降低派生折算。

- 登记：标签 几何；稀有度 rare；最多 1 层；预算 16；仅事件获取。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"carrierRelay":1,"chainReach":170,"carrierDelay":0.4,"reactionEfficiency":-0.03}`。
- 能力与关联：modifies `["conduction","carrier"]`。
- 前置与互斥：requires `["geometry-compass"]`；excludes `["geometry-lens","geometry-fan"]`。
- 替换关系：`{"from":"geometry-compass","group":"geometry"}`。

## 回收（reserve） · 6 件

### reserve-cruet · 余量小瓶

回收合格灼烧剩余，折损入库。

- 登记：标签 回收；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"heatRecovery":1}`。
- 能力与关联：provides `["recovery"]`；needs `["heat"]`。
- 前置与互斥：无额外登记。

### reserve-cistern · 储量夹层

扩大储备容量，不增加回收率。

- 登记：标签 回收；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"heatCapacity":45}`。
- 能力与关联：needs `["heat"]`；modifies `["recovery"]`。
- 前置与互斥：无额外登记。

### reserve-wide · 宽口热匣

高容量低效率，偏向积蓄与集中释放。

- 登记：标签 回收；稀有度 rare；最多 1 层；预算 16；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"heatRecovery":1,"heatCapacity":65,"recoveryEfficiency":-0.07,"reserveThreshold":10}`。
- 能力与关联：provides `["recovery"]`；needs `["heat"]`。
- 前置与互斥：requires `["reserve-cruet"]`；excludes `["reserve-fine","reserve-archive"]`。
- 替换关系：`{"from":"reserve-cruet","group":"reserve"}`。

### reserve-fine · 细口热匣

高效率低容量，偏向持续周转。

- 登记：标签 回收；稀有度 rare；最多 1 层；预算 16；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"heatRecovery":1,"recoveryEfficiency":0.15,"heatCapacity":-10}`。
- 能力与关联：provides `["recovery"]`；needs `["heat"]`。
- 前置与互斥：requires `["reserve-cruet"]`；excludes `["reserve-wide","reserve-archive"]`。
- 替换关系：`{"from":"reserve-cruet","group":"reserve"}`。

### reserve-inlet · 异材入口

纸页和失去接收者的合法剩余可以折损回收。

- 登记：标签 回收；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"paperRecovery":1,"missRecovery":1}`。
- 能力与关联：provides `["recovery"]`；needs `["heat"]`；connections `["reserve-wide","reserve-fine"]`。
- 前置与互斥：无额外登记。

### reserve-archive · 封存热匣

储备跨房保存，达到阈值再释放，牺牲部分即时威力。

- 登记：标签 回收；稀有度 rare；最多 1 层；预算 16；仅事件获取。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"heatRecovery":1,"reservePersist":1,"reserveThreshold":15,"spellPower":-0.04}`。
- 能力与关联：provides `["recovery"]`；needs `["heat"]`。
- 前置与互斥：requires `["reserve-cruet"]`；excludes `["reserve-wide","reserve-fine"]`。
- 替换关系：`{"from":"reserve-cruet","group":"reserve"}`。

## 分合（fragments） · 6 件

### fragments-chisel · 析页刀

增加一个碎片，并将额外份额从本体转给碎片。

- 登记：标签 分合；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"fragmentCount":1,"fragmentShare":0.04}`。
- 能力与关联：modifies `["cold","conduction"]`。
- 前置与互斥：无额外登记。

### fragments-sieve · 同文筛

提高派生片段加工保留率。

- 登记：标签 分合；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"reactionEfficiency":0.05,"materialConserve":0.05}`。
- 能力与关联：modifies `["cold","conduction"]`。
- 前置与互斥：无额外登记。

### fragments-spray · 百屑分梳

更多较弱碎片展开，减少本体持有份额。

- 登记：标签 分合；稀有度 rare；最多 1 层；预算 16；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"fragmentCount":3,"fragmentShare":0.12,"forkPayload":1}`。
- 能力与关联：modifies `["cold","conduction"]`。
- 前置与互斥：requires `["fragments-chisel"]`；excludes `["fragments-knot","fragments-temper"]`。
- 替换关系：`{"from":"fragments-chisel","group":"fragments"}`。

### fragments-knot · 归并绳结

把兼容片段归并到少数落点，延后交付。

- 登记：标签 分合；稀有度 rare；最多 1 层；预算 16；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"mergePayload":1,"concentrate":1,"carrierDelay":0.4}`。
- 能力与关联：modifies `["cold","conduction"]`。
- 前置与互斥：requires `["fragments-chisel"]`；excludes `["fragments-spray","fragments-temper"]`。
- 替换关系：`{"from":"fragments-chisel","group":"fragments"}`。

### fragments-casing · 碎晶封套

允许分散片段进入晶壳并继承加工描述。

- 登记：标签 分合；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"crystalStorage":1,"copyInheritance":1}`。
- 能力与关联：provides `["carrier"]`；modifies `["cold","conduction"]`；connections `["fragments-spray","fragments-knot"]`。
- 前置与互斥：无额外登记。

### fragments-temper · 淬火分梳

热性加工提前交出碎片，缩短防御留存。

- 登记：标签 分合；稀有度 rare；最多 1 层；预算 16；仅事件获取。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"fragmentCount":2,"fragmentShare":0.08,"thermalRelease":1,"carrierLifetime":-0.8}`。
- 能力与关联：modifies `["cold","conduction"]`。
- 前置与互斥：requires `["fragments-chisel"]`；excludes `["fragments-spray","fragments-knot"]`。
- 替换关系：`{"from":"fragments-chisel","group":"fragments"}`。

## 运输（transport） · 6 件

### transport-satchel · 纸灵书袋

纸灵用原攻击周期运输已有载荷。

- 登记：标签 运输；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"summonTransport":1}`。
- 能力与关联：needs `["carrier"]`；modifies `["conduction","release"]`。
- 前置与互斥：无额外登记。

### transport-shelves · 巡游书架

扩大可运输容量和寿命。

- 登记：标签 运输；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"carrierCapacity":2,"carrierLifetime":0.8}`。
- 能力与关联：needs `["carrier"]`；modifies `["conduction","release"]`。
- 前置与互斥：无额外登记。

### transport-courier · 急递书袋

优先快速交付，减少留存时间。

- 登记：标签 运输；稀有度 rare；最多 1 层；预算 16；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"summonTransport":1,"carrierDelay":-0.6,"carrierLifetime":-0.8}`。
- 能力与关联：needs `["carrier"]`；modifies `["conduction","release"]`。
- 前置与互斥：requires `["transport-satchel"]`；excludes `["transport-convoy","transport-return"]`。
- 替换关系：`{"from":"transport-satchel","group":"transport"}`。

### transport-convoy · 编队书袋

聚合兼容载荷后运输，增加等待和容量。

- 登记：标签 运输；稀有度 rare；最多 1 层；预算 16；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"summonTransport":1,"mergePayload":1,"carrierCapacity":2,"carrierDelay":0.6}`。
- 能力与关联：needs `["carrier"]`；modifies `["conduction","release"]`。
- 前置与互斥：requires `["transport-satchel"]`；excludes `["transport-courier","transport-return"]`。
- 替换关系：`{"from":"transport-satchel","group":"transport"}`。

### transport-repeater · 接力书签

运输载体可成为电性中继。

- 登记：标签 运输；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"carrierRelay":1,"chainReach":55}`。
- 能力与关联：needs `["carrier"]`；modifies `["conduction","release"]`；connections `["transport-courier","transport-convoy"]`。
- 前置与互斥：无额外登记。

### transport-return · 回航书袋

运输后的未用合法剩余可回收，复制折算降低。

- 登记：标签 运输；稀有度 rare；最多 1 层；预算 16；仅事件获取。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"summonTransport":1,"paperRecovery":1,"missRecovery":1,"copyEfficiency":-0.04}`。
- 能力与关联：provides `["recovery"]`；needs `["carrier"]`；modifies `["conduction","release"]`。
- 前置与互斥：requires `["transport-satchel"]`；excludes `["transport-courier","transport-convoy"]`。
- 替换关系：`{"from":"transport-satchel","group":"transport"}`。

## 词形（letters） · 6 件

### letters-dust · 散字砂

未完成词的散字寻找其他合法同字母位置，仍需人工兑现。

- 登记：标签 词形；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"letterScatter":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。

### letters-gather · 聚墨纸

提高有限复制折算，并扩大一格容量。

- 登记：标签 词形；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"copyEfficiency":0.065,"carrierCapacity":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。

### letters-page · 聚字封页

标记的部分直接收益改作付费载荷。

- 登记：标签 词形；稀有度 rare；最多 1 层；预算 16；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"letterScatter":1,"markCarrier":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：requires `["letters-dust"]`；excludes `["letters-scatter","letters-rebind"]`。
- 替换关系：`{"from":"letters-dust","group":"letters"}`。

### letters-scatter · 分字书签

散字分向不同合法词条，减少集中同一目标。

- 登记：标签 词形；稀有度 rare；最多 1 层；预算 16；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"letterScatter":1,"markSpread":1}`。
- 能力与关联：无额外登记。
- 前置与互斥：requires `["letters-dust"]`；excludes `["letters-page","letters-rebind"]`。
- 替换关系：`{"from":"letters-dust","group":"letters"}`。

### letters-stencil · 形文拓片

标记载荷可继承加工方式，增加一次分发机会。

- 登记：标签 词形；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"copyInheritance":1,"fragmentCount":1}`。
- 能力与关联：connections `["letters-page","letters-scatter"]`。
- 前置与互斥：无额外登记。

### letters-rebind · 词形重订

分散标记并把部分收益改作承载，正常复制折算降低。

- 登记：标签 词形；稀有度 rare；最多 1 层；预算 16；仅事件获取。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"letterScatter":1,"markCarrier":1,"markSpread":1,"copyEfficiency":-0.05}`。
- 能力与关联：无额外登记。
- 前置与互斥：requires `["letters-dust"]`；excludes `["letters-page","letters-scatter"]`。
- 替换关系：`{"from":"letters-dust","group":"letters"}`。

## 防御（defense） · 6 件

### defense-seal · 页盾封印

付费载体可挡住一次普通弹幕。

- 登记：标签 反照；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"carrierGuard":1}`。
- 能力与关联：provides `["guard"]`；needs `["carrier"]`。
- 前置与互斥：无额外登记。

### defense-lining · 缓冲衬页

增强护持效率，延长可用时间。

- 登记：标签 反照；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"guardEfficiency":0.18,"carrierLifetime":0.8}`。
- 能力与关联：needs `["carrier"]`；modifies `["guard"]`。
- 前置与互斥：无额外登记。

### defense-retain · 守文衬页

保留载体防御，牺牲正常交付频率。

- 登记：标签 反照；稀有度 rare；最多 1 层；预算 16；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"carrierGuard":1,"carrierRetain":1,"carrierLifetime":1.4}`。
- 能力与关联：provides `["guard"]`；needs `["carrier"]`。
- 前置与互斥：requires `["defense-seal"]`；excludes `["defense-reply","defense-newest"]`。
- 替换关系：`{"from":"defense-seal","group":"defense"}`。

### defense-reply · 回敬衬页

防御消耗后交出未用片段，复制折算略低。

- 登记：标签 反照；稀有度 rare；最多 1 层；预算 16；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"carrierGuard":1,"carrierRelease":1,"copyEfficiency":-0.04}`。
- 能力与关联：provides `["guard","release"]`；needs `["carrier"]`。
- 前置与互斥：requires `["defense-seal"]`；excludes `["defense-retain","defense-newest"]`。
- 替换关系：`{"from":"defense-seal","group":"defense"}`。

### defense-current · 带电护封

护持载体可进入有限中继，扩大材料用途。

- 登记：标签 反照；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"carrierRelay":1,"chainShare":0.04}`。
- 能力与关联：needs `["carrier"]`；modifies `["guard"]`；connections `["defense-retain","defense-reply"]`。
- 前置与互斥：无额外登记。

### defense-newest · 新页反照

优先最新护页并释放余载，减少一个可存容量。

- 登记：标签 反照；稀有度 rare；最多 1 层；预算 16；仅事件获取。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"carrierGuard":1,"carrierRelease":1,"guardNewest":1,"carrierCapacity":-1}`。
- 能力与关联：provides `["guard","release"]`；needs `["carrier"]`。
- 前置与互斥：requires `["defense-seal"]`；excludes `["defense-retain","defense-reply"]`。
- 替换关系：`{"from":"defense-seal","group":"defense"}`。

## 独卷（focus） · 6 件

### focus-ink · 专注墨

以小幅威力提高支持各种主书。

- 登记：标签 定本；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"spellPower":0.065}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。

### focus-margin · 校订页边

减少加工损耗并提高派生折算。

- 登记：标签 定本；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"materialConserve":0.09,"reactionEfficiency":0.025}`。
- 能力与关联：无额外登记。
- 前置与互斥：无额外登记。

### focus-spike · 尖锋定本

强化集中与穿透，削减广域传导。

- 登记：标签 定本；稀有度 rare；最多 1 层；预算 16；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"spellPower":0.065,"concentrate":1,"payloadPierce":1,"chainCount":-1}`。
- 能力与关联：无额外登记。
- 前置与互斥：requires `["focus-ink"]`；excludes `["focus-cycle","focus-sacrifice"]`。
- 替换关系：`{"from":"focus-ink","group":"focus"}`。

### focus-cycle · 循章定本

延长储存并提升材料供给，降低即时威力。

- 登记：标签 定本；稀有度 rare；最多 1 层；预算 16；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"materialRate":0.16,"carrierLifetime":1.5,"spellPower":-0.04}`。
- 能力与关联：无额外登记。
- 前置与互斥：requires `["focus-ink"]`；excludes `["focus-spike","focus-sacrifice"]`。
- 替换关系：`{"from":"focus-ink","group":"focus"}`。

### focus-seal · 独卷印

在独卷配置中强化主书结构，不开放免费副书。

- 登记：标签 定本；稀有度 common；最多 1 层；预算 8；可参与普通奖励资格判断。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"singleFrost":1,"singleFlame":1,"singleStorm":1,"singleSpirit":1}`。
- 能力与关联：connections `["focus-spike","focus-cycle"]`。
- 前置与互斥：无额外登记。

### focus-sacrifice · 易形定本

提高结构继承与加工保留，减少即时威力。

- 登记：标签 定本；稀有度 rare；最多 1 层；预算 16；仅事件获取。[定义](../../../legacy/web/src/content/relics/expanded.ts)
- 授予：`{"copyInheritance":1,"materialConserve":0.18,"spellPower":-0.05}`。
- 能力与关联：无额外登记。
- 前置与互斥：requires `["focus-ink"]`；excludes `["focus-spike","focus-cycle"]`。
- 替换关系：`{"from":"focus-ink","group":"focus"}`。
