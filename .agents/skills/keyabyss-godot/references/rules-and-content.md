# 规则与内容实践

这些结论来自旧 Web、M2、构筑扩张与后续收缩的实践。历史文档解释问题形成过程；当前规则由产品文档、当前用户指令和源码确定。下列路径相对仓库根目录，不能据旧案例恢复天赋、合同或加工系统。

## 先确认读的是哪一代规则

一度把当前 `legacy/web/` 当原版，实际上它已含构筑重构；资源目录、旧通过数和归档“下一步”又容易让被取消内容成为隐含任务。后来明确分开：产品意图、当前接入、历史证据、未完成工作。

恢复工作先读 `docs/migration/AGENT-HANDOFF.md` 的锁定提交，用 `git show <提交>:src/...` 读当时路径，再核对当前实现。当前迁移基线为 `b713c6eea472f6c01d608710434e7daee407247f`，后续以交接更新为准。先追定义 → 注册 → 运行 → 输入／反馈／声音 → 现有测试，不直接搬整份旧系统。交接中的旧源码描述也要与阶段总结及实际代码核对。

来源：`docs/migration/AGENT-HANDOFF.md`“玩法基线与取证”；`docs/archive/2026-10-08-build-system/README.md`。

## 输入是意图，固定步才提交事实

曾出现辅助补全在取消／换目标后落到另一词，或测试在固定步前断言完词而假失败。后来理解：输入身份、尝试身份与目标词会话必须一致；UI 收到按键不等于已经支付、施法或赚到人工收入。

修改链路：从 `game/input/input_router.gd`、`typing_session.gd` 追到 `BattleSession._commit_word()` 与账本领取。覆盖真实 Unicode、echo、编辑归属、取消、同帧换词、暂停和提交后的回执。辅助完成、继承前缀、派生攻击不能再记人工收入。不要为 MCP 缺 Unicode 修改正式路由。

来源：`docs/migration/M2-IMPLEMENTATION-LESSONS.md` §2；历史 `docs/archive/2026-10-08-build-system/migration/M3-REPAIR-PLAN.md`“辅助补全与反击”、`M4-ACCEPTANCE.md`。最小入口：`test_input_settings.gd`；战斗提交选 `test_battle_session.gd` 或当前 `test_s2_rules.gd -- --four-books`，先审对应断言。

## 词咒、在途攻击与死亡目标分别有生命周期

完词立刻换词曾让玩家误以为已经命中；纸灵简化为发弹计时器、删除来弹直接扣反击伤害则丢失真实因果。后来把付费主术、被占用词咒、目标实体、表现节点分开管理。

沿 `_commit_word()` → 投射物／纸灵 → 命中 → 词咒释放追踪。主术在途持有原词，无关命中不抢先刷新；命中仍活目标后分配新词，阻挡／失效走真实归还规则。目标死亡不撤销已付费额度，尸体节点存活也不成为攻击的前提。纸灵实体存在、剩余攻击额度、待机和消散分别检查，视觉分枝不能产生收益。

来源：M2 经验 §2–3；`game/session/battle_session.gd`、`game/spells/spell_runtime.gd`、`ui/battle_word.gd`。旧逐词供能和世界时间寿命已被四书专项替换，先查 `docs/FOUR-BOOKS-DESIGN.md`，不重启旧断言。

## 位置条件不能抹掉交战历史

未入场敌人不可锁定／攻击，但已经有效锁定的敌人被击退到边缘仍可交战。只按当前位置隐藏／禁伤曾破坏这一语义；远程敌人在冷区提前按射程停住，也会让玩家失去有效目标。

核对 `enemy_in_combat()`、`combat_locked`、锁定提交和移动的 `entering` 分支。分别观察未入场 → 入场 → 锁定 → 取消／完词 → 击退；未入场远程先进入有效战场再应用理想射程。不以放宽资格补救错误移动，不以 `alive()` 一律替代交战资格。

来源：M2 经验 §5；`legacy/web/tests/cold-zone.test.cjs`；历史 M3 修正方案“验证与战场情境”。规则区域、词咒显示、危险层和低画质表达须共用语义，边界宽度是可调参数。

## 内容需要证明效果，实例需要保留身份

历史大目录已登记、编译通过，仍发现无供给、入口被覆盖或夹具预装能力替内容补条件。后来区分“存在、可获得、实际兑现、收益适合”，用只含必要前置的有／无差分检查代替战斗总伤害大于零。

沿 `acquisition_service.gd` → `build_compiler.gd` → 运行效果 → 实际结果验证；正式获取与快捷夹具的证据分别写清。叠层、一次性能力和跨房继承要查 `CombatAssetInstance.usage_key()`、`RunCombatState.claim_asset()`，加载／重装／升档不能刷新已消费权利。候选变更先验证成功再提交；失败后原局与保存仍一致。

当前遗物按机制族复用已有案例；奖励／路线／保存选择 `test_reward_ledger.gd`、`test_single_run_save.gd`、`test_s2_run.gd`。后者默认合法结果夹具与 `--formal` 实际打字九房各有边界。

来源：历史 `M3-REPAIR-PLAN.md`、`M3-INTEGRATION.md`、`M4-ACCEPTANCE.md`；`docs/TESTING.md`。旧 377 项目录、206／171／32 规模、借还抵押等义务已经退出。

## 资源流量不是实际伤害

制作、转换、清理支出曾被混作输出，过量伤害与未兑现力量也混入同一总数。后来明确账本解释去向，生命变化记录真实结果。

修改结果时核对 `game/session/room_combat_result.gd` 的 `raw_spent_q`、`actual_damage_q`、`overkill_damage_q`、`unused_power_q` 与实际扣血位置。报告指标先写计算对象，不能以花掉力量证明遗物有效；固定点数整数截断保留原语义，用局部注解处理必要警告。

来源：历史 M3 修正与接入记录；M2 经验 §9。

## 优化查询，不暗改提交顺序

首击线性择优可以减少临时集合；贯穿改成边扫描边提交则可能让击杀新生子体进入同一次攻击。死亡 ID 索引提前删除也会破坏在途引用。后来把顺序、快照、身份和查询实现分开。

先描述原始接触排序、并列 ID、事件顺序、RNG 和对象生命周期。单命中取最早 `(time, 字符串ID)`；多命中仍先收集快照再提交。保留 `at`、`contact`、方向与尾迹截断，规则改动也会影响视觉因果。

跨 GDScript／C# 需保留标量／向量精度及累加顺序，离散选点必须一致；先查锁定算法基线，再使用现有 `tools/godot/compare-combat.ps1`。性能比较涵盖真实封送、首次调用、稳定分位与 GC，不用热微基准代表整帧。夹具断言失败先追业务冲量，不能改求解器迎合测试。

来源：`docs/migration/COMBAT-ALGORITHM-IMPLEMENTATION.md`、`docs/migration/PLAN.md`“战斗算法优化”。空间网格和更多缓存只有新实测收益才引入；既有目标未达部分不以改规则通过。
