---
name: keyabyss-godot
description: 在键渊 Godot 工程中实现或修改 GDScript、场景、资源、战斗与内容接线时使用。纯文档整理和 legacy/web 的维护不触发。
---

从 [迁移方案](../../../docs/migration/PLAN.md) 获取模块归属和实施阶段，从 [阶段总结](../../../docs/STAGE-SUMMARY.md) 获取已接入范围。目录由实际功能产生，不按方案预建空框架。

- 每迁一条功能链，先按[旧项目阅读方法](../../../docs/migration/PLAN.md#从旧项目理解待迁移的体验)追踪 `legacy/web/` 的入口、内容定义、状态、规则、表现和声音，再确定要保留的目标与 Godot 载体。截图不能代替源码或动态观察。
- 编辑 `res://` 内的场景、具名 Resource 和类型化 GDScript；高频无表现状态使用 RefCounted／类型化数组，具备独立生命周期的表现对象使用节点。
- `BattleSession._physics_process` 是战斗推进入口；规则提交有显式顺序，signals 通知已提交结果。UI 不直接改资源账、存档或战斗实体。
- 共享 `.tres` 是只读定义。每局状态另建实例；不得把运行余额写回资源缓存。跨线程只处理脱离场景树的数据，主线程提交结果。
- 查 API 时使用锁定 4.7 版本官方文档和本机 4.7.2 实际行为。旧源码是理解原游戏行为的重要依据；不冻结旧架构、运行轨迹和参数。第三方 Skill 与旧测试分别只作知识及边界参考。
- 根据影响选择最小检查。导入：`pwsh -File tools/godot/godot.ps1 import`。资源未导入时先导入再检查脚本；不要用删除类型标注消除错误。
- 完整数值评估留到内容和正式获取闭环，具体规则见根目录 AGENTS.md 与 TESTING；本 Skill 不增加固定全量测试步骤。
