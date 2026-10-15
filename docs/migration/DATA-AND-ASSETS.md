# 数据与素材映射

Godot 是活动实现的唯一来源。玩法恢复基线为 `b713c6eea472f6c01d608710434e7daee407247f`，当前 `legacy/web/` 已包含后续重构。下面的 `src/` 路径用于 `git show b713c6e:<path>`，不是当前工作区路径。

## 玩法取证与原生落点

| 基线入口 | Godot 落点 | 核对内容 |
| --- | --- | --- |
| `src/content/manifest.ts`、`content/books/*/{definition,behavior}.ts` | `game/content/`、`game/spells/`、`game/session/battle_session.gd` | 四书身份、强化周期、主术、终式与真实触发 |
| `src/content/relics/*/definition.ts`、`values.ts`、`simulation/RelicRules.ts` | `game/content/build/`、`game/build/`、`game/spells/` | 58 件遗物的名称、效果、叠层、条件、获取钩子与派生边界 |
| `simulation/progression/{RewardSystem,EligibilityService}.ts` | `game/progression/`、奖励页 | 三选一、主书／词库／已有遗物资格、觉醒前置、重抽和满层补给 |
| `content/routes/*.ts`、`RewardSystem.chooseRoute()` | `RunSession` 与路线页 | 休息、试炼、赠礼、庇护、付血换奖励；具体支付与不可致死等条件 |
| `content/enemies/`、`content/bosses/`、`content/elites/` | 敌人定义与战斗调度 | 原 17 类普通敌人、3 Boss、精英变化的实际行为与威胁 |
| `content/chapters/`、`progression/{Campaign,EncounterDirector,difficulty}.ts` | 行程 Resource 与 RunSession | 三章九页、段、Boss、五档及周目压力 |
| `RewardSystem.continueLoop()`、`application/SessionController.ts` | 结算页与连续远征 | 保留遗物、更强周目、生命／重抽；本次另接升到下一难度 |
| `src/ui/`、`src/rendering/`、音频定义 | 原生 Control、场景、shader、粒子与音频 | 反馈、时序、声音、阅读层级与减少动态；不迁移 Web 框架 |

原生 R 编号和基线旧 ID 已按名称及规则逐项对应。下面保留基线源码事实，并记录当前 Godot 的实际入口；R 编号不按旧目录顺序推断。

原基线 58 件是恢复范围的起点；合并需说明用途重复，不以取消 171 件中的全部新增项为由误删基线遗物。旧基线的局内前置和觉醒保留，不沿用重构后永久天赋许可。

## 58 件遗物逐项对应

以下保留 `b713c6eea472f6c01d608710434e7daee407247f` 的源码审查结果。原生资源统一位于 `game/content/build/`，四书及 R001–R058 已进入正式目录并恢复规则。表中当前状态指现有 Godot 实现，基线数值列仍是旧源码事实；运行证据范围见表后，不能据此推定所有随机组合和平衡已完成。`s` 表示持有层数。

每行定义证据均为 `src/content/relics/<旧ID>/definition.ts`，有公式的同时核对同目录 `values.ts`。完整基线源码证据保存在 `.temp/shrink/baseline/source-b713c6e.zip`。下面的入口缩写均指该提交：

- **C**：`src/simulation/systems/CastSystem.ts` 的 `cast/afterCast`；**S**：`StatusSystem.ts` 的 `strike/applyCold/conduct/chain`；**D**：`DamageSystem.ts` 的 `kill/hurt/gainXP/payBloodPrice`。
- **M**：`MovementSystem.ts` 的 `dodge/finishDodge/getDashCooldown/resolveBodies`；**F**：`FlameSystem.ts` 的 `applyBurn/spreadBurn/fireImpact`；**P**：`ProjectileSystem.ts`；**E**：`EnemySystem.ts`；**U**：`SummonSystem.ts`；**B**：对应 `src/content/books/<book>/behavior.ts`；**H**：`src/simulation/RelicRules.ts` 的 `run/damageMultiplier`。
- **G**：所有遗物正式获取共用 `RewardSystem.upgradeChoices → canUpgrade → EligibilityService.eligibleRelic → chooseUpgrade → H.run("acquire")`。限制由旧定义的 `max/book/requires/minWordLength/maxWordLength` 决定，`affinity` 仅提高抽取评分，不是主书门禁。
- 当前正式入口共用 `RunSession.take_reward → RunTransactionService.prepare_acquisition/prepare_actions → AcquisitionService.evaluate → BuildCompiler.compile → BattleSession.install_prepared_build`；主术输入共用 `BattleSession._commit_word → SpellRuntime.assemble/dispatch/contact`，道具词咒由 `SpellRuntime.on_pickup_completed` 结算。下面“原生入口”是在这条链中的实际分支；**SR** 为 `game/spells/spell_runtime.gd`，**BS** 为 `game/session/battle_session.gd`。不得以直接注入 build 代替正式获取验证。

| 旧 ID／名称 | 原生 ID | 基线效果与限制（事实） | 当前恢复状态 | 基线真实触发 → 原生入口证据 |
| --- | --- | --- | --- | --- |
| power／锋利笔尖 | R001 | 伤害修饰乘 `1.25^s`，最多3层 | 已恢复乘法叠层，覆盖施法及纸灵共享倍率 | G；H.damageMultiplier、C.cast→ SR.damage_multiplier/assemble/contact |
| chain／导电墨水 | R002 | 额外跳跃s次，最多3层；非雷书从本次伤害45%起跳 | 已恢复额外有限跳跃与衰减 | G；C.cast、S.chain、雷B→ SR.contact/_chain/_continue_arc |
| frost／零度批注 | R003 | 非冰霜每命中积寒45s；冰霜直接积寒100；普通冻结1.55+0.45s秒，Boss0.8秒；最多3层 | 已恢复附加积寒及普通／Boss冻结时间 | G；S.strike/applyCold→ SR.contact/_apply_cold |
| shatter／冰裂残页 | R004 | 冻结死亡爆裂，半径100+20s+25×reach层，伤害28+18s；depth<3；最多2层 | 已恢复独立冻裂及三层深度边界 | G；D.kill/explode→ SR.on_enemy_death |
| spirit／折纸使魔 | R005 | 纸灵容量+s；每完词维持4+s+2×bond层秒，累计18秒；基础攻击12+3s；最多3层 | 已恢复纸灵容量、持续时间与基础攻击 | G；C.cast、U、spirit.values→ SR.assemble/_fill_spirit_queue、BS._advance_blades |
| echo／双生笔尖 | R006 | casts每3次向另一目标发65%本次dmg的echo弹，direct=false；最多1层 | 已恢复第三次周期额外弹，不复制整套书行为 | G；C.cast→ SR.assemble/_periodic_copy |
| blast／爆墨瓶 | R007 | 直接命中额外溅射，半径90+25×reach层，伤害35%×s×命中dmg；最多2层 | 已恢复直接命中额外溅射 | G；S.strike→ SR.contact/_burst |
| reflect／镜面批注 | R008 | 拆弹反击×1.6，随后一次施法×2；最多1层 | 已恢复道具词咒拆弹与下一主术一次翻倍 | G；E的拆弹分支、C.reflectionBoost→ BS道具词咒提交 → SR.on_pickup_completed/on_disarm/disarm_burst |
| dash／折叠书页 | R009 | 闪避恢复间隔×0.72；上限+1，领取充能+1；最多1层 | 已恢复充能恢复速度、容量及领取去重 | G；H.acquire、M.getDashCooldown→ RunTransactionService.prepare_actions、BS构建安装及防御恢复 |
| dashnova／留白之环 | R010 | 闪避落点清弹135并推开附近敌人；最多1层 | 已恢复落点清弹与推开 | G；M.finishDodge→ SR.on_dodge_landed |
| shield／残句书签 | R011 | 输入目标死亡且prefix非空时+10护盾，上限60；最多1层。执行未限定击杀来源 | 已恢复输入目标死亡触发，不限定击杀来源 | G；D.kill→ SR.on_enemy_death |
| heal／生命页签 | R012 | 每次领取最大生命+20、立即恢复30；最多2层 | 已恢复固定生命及实例领取回复 | G；H.acquire→ BuildCompiler.compile、RunTransactionService.prepare_actions |
| leech／朱砂印 | R013 | 每6次casts恢复4s生命；最多2层 | 已恢复第六次完词治疗 | G；H.afterCast→ SR._after_cast/heal |
| short／短咒连珠 | R014 | 词长≤4，伤害×(1+0.6s)，回复0.1闪避；最多2层；词库存在≤4词 | 已恢复短词倍率、闪避回复与词库资格 | G；C.cast、short.values→ SR.assemble、AcquisitionService.evaluate |
| long／长句回响 | R015 | 词长≥7，伤害×(1+0.75s)，目标周围清弹105；最多2层；词库存在≥7词 | 已恢复七字门槛、倍率、清弹与词库资格 | G；C.cast、long.values→ SR.assemble、AcquisitionService.evaluate |
| perfect／无瑕落款 | R016 | 无错字伤害×(1.08+0.35s)，最多2层；1.08为基础无错字收益 | 已恢复无错字当词倍率，保留基础8% | G；C.cast、perfect.values→ SR.assemble |
| feather／通灵羽毛笔 | R017 | 每4次手动完词使下一词前2字母自动补全；最多1层，词库有≥3词 | 已接每四次人工完词就绪及Ctrl主动消费；明确保留主动语义，不恢复隐式截词 | G；C.manual/autofill、targeting输入→ SR.assist_ready/consume_assist、_record_word |
| slow／时间书签 | R018 | 存在锁定目标时敌人与子弹移动×0.82；最多1层 | 已恢复锁定输入期间敌人／子弹移动减速 | G；E.updateEnemies、P.updateBullets→ BS敌人／威胁推进中的锁定输入减速 |
| armor／硬壳书封 | R019 | 受伤×0.75^s，最多2层；与glass×1.3相乘 | 已恢复乘法叠层减伤 | G；D.hurt、armor.values→ BS._take_player_damage |
| pulse／段落终结 | R020 | 每5次casts自身清弹半径220并爆炸35；最多1层 | 已恢复第五次完词清弹及爆炸 | G；H.afterCast（cast-pulse组优先级30）→ SR._after_cast/_burst/clear_radius |
| gold／鎏金藏书票 | R021 | 领取后击杀经验×1.35；最多1层，无章额外经验上限 | 已恢复35%击杀经验，无章节额外经验cap | G；D.gainXP→ BS.commit_damage、RewardLedger.consume、RunSession奖励事实结算 |
| crit／惊叹号 | R022 | 每4次casts直接施法×2；最多1层；casts含道具完词，但道具分支不暴击 | 已恢复第四次完词周期；道具计数，该次须主术才暴击 | G；C.cast→ SR.assemble/_record_word |
| reach／远行墨迹 | R023 | 连锁距离265+100s，爆墨／冻裂半径+25s；最多2层 | 已恢复电弧与爆墨／冻裂对应范围 | G；S.chain、blast/shatter.values→ SR._chain/_continue_arc/contact/on_enemy_death |
| rescue／未完待续 | R024 | 致命伤一次复活45%最大生命、3秒无敌、清弹／激光／爆炸并范围伤害；最多1层 | 已恢复一次救援，消费身份跨页保存 | G；D.hurt→ BS._take_player_damage、SR.rescue_burst、RunCombatState.claim_asset |
| heavy／鲸骨笔杆 | R025 | 击退×(1+0.6s)，碰撞伤害×2（持有即生效）；最多2层 | 已恢复附加击退及碰撞翻倍 | G；S.strike、M.resolveBodies→ SR.contact/body_contact、BS碰撞边界 |
| gravity／引力墨核 | R026 | 直接命中牵引190范围、力260；最多1层，牵引排除Boss／固定敌人 | 已恢复直接命中额外牵引 | G；S.strike、M.pull→ SR.contact/_pull |
| execute／终止符 | R027 | 直接命中后普通敌人剩余比例<18%处决；Boss伤害×1.15（执行不限direct）；最多1层 | 已恢复生命比例处决及Boss伤害 | G；S.strike→ SR.contact |
| bleed／腐蚀墨迹 | R028 | 直接命中留4秒腐蚀，状态最多3层，每秒8×s×状态层伤害；最多2层 | 已恢复独立有限腐蚀状态 | G；S.strike/updateEnemyStatus→ SR._status/_pulse_status |
| nova／完美段落 | R029 | 连续3次无错casts清弹150、爆炸24；受伤也清perfectWords；最多1层 | 已恢复无错连续计数及与段落终结的互斥优先级 | G；C、D.hurt、H.afterCast优先级40→ SR._record_word/_after_cast/on_player_hurt |
| rhythm／连笔字帖 | R030 | 连笔基础每级2.5%（最多10）翻倍至最多50%总加成；额外贡献最多25%；最多1层 | 已恢复每词2.5%→5%，连笔总上限25%→50% | G；C.combo、rhythm.values、D.hurt→ SR.assemble/_record_word/on_player_hurt |
| brittle／脆裂书页 | R031 | 冻结目标施法伤害×(1.18+0.4s)，强化冰命中再×1.25；最多2层 | 已恢复冻结目标额外倍率及强化冰收益 | G；S.strike、brittle.values→ SR.contact |
| permafrost／永冻墨池 | R032 | 直接施法霜场半径+35、持续+3秒；非冰也产生小霜场；最多1层 | 已恢复霜场范围、持续及非冰小霜场 | G；S.strike→ SR.contact/_region/_apply_cold |
| conductor／超导银墨 | R033 | 跳跃保留率从0.76至0.91（第二层不再改善此项），过载伤害×(1+0.35s)；最多2层 | 已恢复跳跃保留率与过载伤害 | G；S.chain/conduct、conductor.values→ SR._chain/_continue_arc/_conduct |
| stormcell／避雷印 | R034 | 非雷直接命中也导电；3次导电过载清弹135；最多1层 | 已恢复非雷导电及过载清弹 | G；S.strike/conduct→ SR.contact/_conduct |
| bond／共命书线 | R035 | 纸灵攻击×(1+0.3s)，每词持续+2s；无书原生和spirit时容量至少1；最多2层 | 已恢复纸灵持续／攻击区别，未合并R005 | G；C.cast、spirit.values、U→ SR.assemble/_fill_spirit_queue |
| sacrifice／背水誓书 | R036 | 生命严格<40%时施法及纸灵伤害×1.5；最多1层 | 已恢复严格低于40%的风险收益 | G；H.damageMultiplier、spirit.values→ SR.damage_multiplier/contact |
| magnet／折返墨涡 | R037 | 闪避起点牵引并留190半径1.2秒引力井，落点清弹75／击退；最多1层 | 已恢复起点引力井与落点清弹 | G；M.dodge/finishDodge→ SR.on_dodge/on_dodge_landed |
| graze／飞白笔锋 | R038 | 擦弹共鸣1.4（基础0.7），护盾+0.6，上限60；每弹一次；最多1层 | 已恢复每弹一次擦弹、双倍共鸣及护盾 | G；P.updateBullets→ SR.graze、BS._advance_threats |
| ward／护页结界 | R039 | 每5次casts护盾+12s，上限60；最多2层 | 已恢复第五次完词护盾及60上限 | G；H.afterCast→ SR._after_cast/add_shield |
| haste／共鸣墨晶 | R040 | 完词共鸣×1.35，基础无错8／有错6；最多1层 | 已恢复完词共鸣倍率与8／6基础值 | G；C.addResonance→ BS主术／道具词咒共鸣提交 |
| hourglass／停笔沙漏 | R041 | 闪避后真实1.5秒世界速度10%，允许继续输入，防御恢复按真实时间；最多1层 | 已恢复世界／真实时间分离及持续输入 | G；M.dodge、CombatSimulation.update→ SR.on_dodge、BS.step |
| bloodprice／血字契约 | R042 | 伤害×1.4；领取及每新页扣8生命，同页一次，至少1生命；最多1层 | 已恢复领取／新页付血与同页去重 | G；H.acquire、D.payBloodPrice、EncounterDirector→ RunTransactionService.prepare_actions、RunSession新页付血 |
| glass／玻璃书封 | R043 | 施法及纸灵×1.45，受伤×1.3；最多1层 | 已恢复施法／纸灵收益及受伤风险 | G；H.damageMultiplier、D.hurt→ SR.damage_multiplier、BS._take_player_damage |
| avalanche／雪崩圣典 | R044 | frost书、shatter+permafrost前置；冻裂原始死亡depth0射最多6枚冰针，冰枪穿透+2；最多1层 | 已恢复局内组合前置与有限冰针 | G；D.kill、frostB.cast→ SR.on_enemy_death/_configure_shape、AcquisitionService.evaluate |
| iceheart／凛冬残卷 | R045 | frost书、frost+brittle前置；终式+30盾、冰针tick0.13替代0.25，强化冰附近155积寒100；最多1层 | 已恢复局内觉醒、终式护盾与冰针节奏 | G；frostB.ultimate/tick、S.strike→ BS._commit_ultimate/_advance_ultimates、SR.contact |
| superconductor／超导禁卷 | R046 | storm书、chain+conductor前置；电弧+2跳、过载190范围并牵引；最多1层 | 已恢复组合前置、额外跳跃与过载范围／牵引 | G；chain.values、S.conduct→ SR._configure_shape/_conduct、AcquisitionService.evaluate |
| thunderheart／永昼雷章 | R047 | storm书、stormcell+haste前置；终式6→9秒，期间敌人完词afterCast落雷目标1→3，每次存活目标落雷+2盾，上限60；最多1层 | 已恢复组合前置、终式持续及主词雷击；辅助主词也触发，雷击实际命中后获得护盾 | G；stormB.duration/afterCast→ BS._commit_ultimate/_commit_word、SR.storm_word_strike/contact |
| legion／千纸军团 | R048 | spirit书、spirit+bond前置；容量+3，强化交叉斩时全员cooldown=0；仍需完词维持；最多1层 | 已恢复组合前置、容量及强化纸灵攻击调度 | G；spirit.values、spiritB.cast→ SR.dispatch、BS._advance_blades、AcquisitionService.evaluate |
| marionette／傀儡纸冠 | R049 | spirit书、ward+shield前置；飞行纸灵拦截敌弹、标记击杀+8共鸣；最多1层 | 已恢复飞行拦截与标记击杀共鸣 | G；U、D.kill→ BS._advance_blades/commit_damage |
| cinder／余烬墨水 | R050 | flame书；每0.5秒每层灼烧6×伤害倍率×(1+0.3s)；最多3层 | 已恢复每跳灼烧收益 | G；F.tickBurn、cinder.values→ SR._pulse_status |
| pitch／松脂印章 | R051 | flame书；灼烧3+s秒，延长产生额外跳数；最多2层 | 已恢复延长灼烧及额外跳数 | G；F.applyBurn/tickBurn→ SR._burn/_status |
| wildfire／野火书签 | R052 | flame书；燃烧死亡传播最多2代，半径130+25s、目标2+s，每目标最多传2层；最多2层 | 已恢复最多两代传播及距离／目标数 | G；D.kill/F.spreadBurn → SR.on_enemy_death |
| crucible／熔炉封蜡 | R053 | flame书；普通55／强化115熔爆半径+25s；最多2层 | 已恢复火弹熔爆范围 | G；F.fireImpact、crucible.values→ SR.contact/_region |
| coal／炽炭书封 | R054 | flame书；每次强化火弹施法护盾+5s，上限60；最多2层 | 已恢复强化火施法护盾 | G；flameB.cast→ SR.assemble |
| firewalk／灼痕行书 | R055 | flame书；闪避起点火场半径60+20s、持续2+s秒；最多2层 | 已恢复起点火场范围与持续 | G；flameB.dash、firewalk.values→ SR.on_dodge |
| inferno／不灭灰烬卷 | R056 | flame书、cinder+pitch前置；灼烧上限3→5，终式5→7秒，陨火间隔0.7→0.45；最多1层 | 已恢复组合前置、灼烧上限及终式节奏 | G；F.applyBurn、flameB.duration/tick→ SR._burn/_status、BS._commit_ultimate/_advance_ultimates |
| inscription／返咒铭文 | R057 | 弹反附书效果，冰积寒／雷导电／火灼烧／纸标记及维持；最多1层 | 已恢复弹反书效果，不计为完词 | G；DefenseSystem.counterHit→ SR.counter_contact、BS弹反命中 |
| rebound／回锋笔套 | R058 | 弹反冷却×0.7，0.70→0.49秒；最多1层 | 已恢复0.70→0.49秒弹反冷却 | G；DefenseSystem、rebound.values→ BS弹反提交冷却 |

### 已恢复范围与运行证据

S1 实际代表池为 `R001、R002、R003、R005、R006、R012、R014、R015、R016、R019、R041、R050`（12件），随后S2扩展至R001–R058全部身份。此处记录恢复基线，不限制后续新增遗物或正式池调整；当前资格和机制见[遗物系统](../RELIC-SYSTEM.md)及[实施方案](PLAN.md)。四书无需天赋编译；主术强化计数包含辅助主词而不包含道具，遗物完词周期包含道具并跨页保存。R017保留Ctrl主动补全，与旧自动截词有意不同；人工字符回执与实例消费去重继续保留。

已有实际证据：`test_s1_rules.gd` 与 `test_s2_rules.gd` 均输出PASS0；S2事务241 checks／0 failures；正式四书九页流程469 checks／0 failures，流程证据目录为 `.temp/shrink/flow/s2-869684`。规则侧记录见 `.temp/shrink/relics/RESULT.md`。这些检查分别覆盖规则族、受控夹具、获取事务及正式流程，不表示所有正式随机组合、长局性能、玩家体验或整体平衡均已覆盖；后续小范围接线的验证以对应最新记录为准。

## 现有文件与旧生成链

旧M3内容表和候选设计已退出当前目录；必要的实施与验收证据见[历史记录](../archive/2026-10-08-build-system/README.md)。取消的天赋图／加工生成工具及相关旧资源已移入 `.delete/shrink-20261008/`。不得将旧候选或待删除工具重新接回生成链。

BuildCatalog与遗物定义共同维护当前原生内容，正式池以实际资格为准，Godot是唯一维护源，不双向同步Web。旧档必要解析字段及结构保留；兼容读取不自动赋予新奖励资格，也不恢复加工执行分支。

## 素材与工具

| 素材 | 当前来源／落点 | 使用边界 |
| --- | --- | --- |
| 中文字体 | `assets/fonts/`；旧 TTF 保留在 legacy | 活动字体只维护一份，正式发行补齐来源与许可 |
| 四书与符印 | `assets/art/books/`、`assets/art/runes/` | 延续原插画与元素识别，不因取消天赋删除共用素材 |
| 遗物矢量图案 | 当前奖励／图鉴共用图形和图标资产 | 只要求保留遗物具备辨识图案；不为已取消目录补齐美术 |
| 词库 | `assets/vocabulary/` 为活动快照；`tools/godot/import-vocabulary.mjs` 默认验证，明确 `--source` 才导入其他目录 | 保留12本快照及来源哈希，原生运行不依赖冻结Web目录 |
| UI／战斗音频 | Agent库 → `audio/cues.json`／`tools/audio/build-game-audio.mjs` → `assets/audio/clips/`及`cues/` | 原样复制选中WAV，四变体由Godot选择，按真实结果反馈与限流 |
| 原音频索引 | [音频目录](../audio/README.md) | 原件和切片可检索，不把全部素材打进发行包 |

普通资源复用与私有资产协作分开，后者见[Git 与资产方案](../GIT-AND-ASSETS.md)。

## 内容身份和保存

新正式目录保留稳定 ID 与版本；删除天赋后不再为新玩法维护 graph_version／layout_version。读取旧档时仍需识别旧版本，不能只删字段造成坏档或静默重置。

保留 Godot 的设置、自定义词库、有效人工字符和记录；线性成长由字符计算，旧天赋分配不转换成局内遗物。规则不兼容的进行中远征按明确边界结束并保留原档。连续挑战的已用机会、层数与新增结算具有稳定身份，换难度不能刷新。

不建设旧浏览器账号迁移。TXT／CSV／TSV／JSON／JSONL 词库导入继续有效，与账号转换无关。
