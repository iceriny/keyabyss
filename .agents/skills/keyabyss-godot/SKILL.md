---
name: keyabyss-godot
description: 在键渊 Godot 工程中实现或修改 GDScript、场景、资源、战斗与内容接线时使用。纯文档整理和 legacy/web 的维护不触发。
---

## 开工与取证

先读 [实施交接](../../../docs/migration/AGENT-HANDOFF.md) 和 [阶段总结](../../../docs/STAGE-SUMMARY.md)，按任务查 [实施方案](../../../docs/migration/PLAN.md) 的模块归属；待办只有 [TODO](../../../docs/TODO.md)。交接可能保留过期的代码描述，实际入口以当前源码和阶段总结核对。

恢复旧玩法时，从交接锁定的 Git 对象读取 `src/`，不要直接把当前 `legacy/web/` 当作基线。追踪一条完整的「输入 → 支付 → 运行 → 命中／中断 → 收尾 → 保存」链，再选择 Godot 载体。旧参数与架构不是自动继承的契约。

## 实施中的关键边界

- `BattleSession` 固定步提交战斗事实，signals 通知已提交结果；输入事件排队，表现回调不决定伤害、收入或胜败。
- `.tres` 保存只读定义，局内实例保存余额和生命周期；高频无表现状态用 RefCounted／类型化数组，独立表现生命周期用节点。固定视觉结构用原生场景，动态内容由脚本绑定，不预建空框架。
- 新效果先定位正式获取、编译、消费和结果入口。Resource 存在、编译合法、效果兑现、收益合适需要不同证据。
- 查 API 使用锁定版本官方文档与本机行为；保留类型标注。新 `class_name`／资源尚未导入时先更新缓存，不把缓存缺失当源码缺陷。

## 按任务读取实践

修改输入、词咒、碰撞、遗物、继承、结果或算法时，读 [规则与内容实践](references/rules-and-content.md) 的对应小节。它记录问题如何暴露、后来理解了什么、下次如何验证，并给出现行代码和历史来源；其中旧内容案例不产生恢复义务。

检查受影响脚本使用工具 Skill 的 [check-gdscript.ps1](../keyabyss-godot-tools/scripts/check-gdscript.ps1)。随后按 [TESTING](../../../docs/TESTING.md) 选最小相关现有入口。完整收益与难度评估留到内容和正式获取闭环，不为每件遗物建立平衡脚本。
