# 测试入口

根工程使用 `godot/` 下的原生检查。运行方法、图形窗口要求及证据边界见[验证说明](../docs/TESTING.md)，引擎与入口见[工具链](../docs/migration/TOOLCHAIN.md)。按修改行为选择最小集合，不把本表当作全量执行清单。

| 行为 | 入口 |
| --- | --- |
| 输入、设置、词库 | `test_input_settings.gd`、`test_vocabulary.gd`、`test_upstream_vocabulary.gd` |
| 四书、真实接触、防御与时钟 | `test_s2_rules.gd` 的对应专项、`test_battle_session.gd`、`test_battle_room.gd`、`test_defense_movement.gd` |
| 遗物资格、编译、正式取得与效果 | `test_relic_catalog.gd`、`test_relic_effects.gd` |
| 页段、Boss与连续远征 | `test_s2_encounters.gd`、`test_s2_run.gd`、`test_boss_resources.gd`；实际九页流程选择 `test_s2_run.gd -- --formal` |
| 研究驱动的整体难度探针 | `difficulty_probe.gd`、`difficulty_probe_actor.gd`；由 `tools/godot/run-difficulty-probe.py` 冻结源码、运行并生成证据，见下文 |
| 狙笔手、复诵者、护卷使与首见编排 | `test_enemy_expansion.gd` 默认规则分支；`-- --window` 为四书实际输入与画面，追加 `--low --reduce-motion` 复查必要提示 |
| 保存、恢复、成长与重复结算 | `test_profile_save.gd`、`test_single_run_save.gd`、`test_talent_progress.gd`、`test_reward_ledger.gd` |
| 菜单、窗口、布局和教学 | `test_application.gd`、`test_presentation.gd`、`test_display.gd`、`test_ui_refinement.gd`、`test_tutorial_lesson.gd`；局部参数见验证说明 |
| 战斗与反馈画面 | `test_battle_presentation.gd`、`test_feedback_effects.gd`、`test_feedback_presentation.gd`、`test_s1_application.gd`；图形运行并审阅画面 |
| 冰晶GPU成本 | `test_feedback_effects.gd -- --measure`，真实图形窗口；独立于战斗截图夹具，保存标记匹配的GPU／渲染线程CPU原始区间。受控冰龄推进，不代表整帧FPS |
| 流体、采样、渲染准备和音频 | `test_fluid.gd`、`test_effect_sampling.gd`、`test_render_preparation.gd`、`test_audio.gd` |
| 算法与性能定位 | `test_combat_algorithms.gd`、`profile_frames.gd`；只在对应问题或算法变化时选用 |
| 尾迹批量几何与粒子绑定 | `test_enemy_expansion.gd -- --feedback-fixes --trail-glow` 比较原采样几何并观察实际HDR；`test_fluid.gd -- --usage` 验证即时绑定、半径／选项变化与释放。两者为图形窗口，性能采样另用实施记录中的两组夹具 |
| 开发夹具 | `test_build_lab_scenarios.gd`；验证共享资源隔离与正式段出口 |

书库布局及持久教学解锁另用现有窗口入口：`test_ui_refinement.gd -- --archive-tutorial`。基础真实完成后任选灰烬，验证单书正式入场、重启回读、失败保存重试与未完远征保留；此UI／流程修改不需要重跑整体难度探针。

## 整体难度探针

从仓库根目录运行，每个`--label`必须是未使用的目录名：

```powershell
python tools/godot/run-difficulty-probe.py --label local-baseline --seed curve-17
# 单个场景、法书或词长分布可缩小诊断范围：
python tools/godot/run-difficulty-probe.py --label targeted-check --scenario retained_ordinary --book frost --seed curve-29 --vocabulary long
# 逗号分隔可在同一次冻结中复核多组边界：
python tools/godot/run-difficulty-probe.py --label boundary-check --scenario cold_expert,cold_elite,retained_ordinary --seed curve-29
```

运行器通过既有`godot.ps1 run`启动锁定引擎，输出到`.temp/difficulty-probe/<label>/`：源码快照、SHA-256清单、完整日志、逐页JSON、报价／选择流水和摘要。运行中源码发生变化、脚本诊断、流程断言失败或缺少结果均返回失败；玩家战败与600真实秒超时分别记录，不冒充脚本失败或真实通关。

默认场景覆盖四书：初学者启程、普通输入冒险、熟练输入深渊、高手噩梦、高手／顶尖灭世冷开、满成长高手灭世冷开，以及普通输入从冒险经深渊／噩梦升至灭世。冷开为空遗物起局，沿途正常取得；满成长是显式既往历史夹具。连续路径必须真实赢得每一档，不预装毕业遗物。固定采用正式随机三选一、预先声明的通用生存／伤害及分书优先级、休息路线，不重抽、不使用Ctrl；所以结论是这些策略的结果，不是对全部构筑的搜索证明。

输入模型采用研究中的有／无预视吞吐和词间残差，派生词内按键间隔；只允许预视一个后续词，记录识别／词间停顿、随机错字和实际Unicode输入。十个180秒输入夹具确认代码实现的吞吐尺度，无预视与有预视分别保存，不重新运行或验证研究。六字符夹具与研究混合词库不同，60Hz调度也有量化误差；容许16%差异，实际值必须随结果报告。正式战斗混合词库为25个3～7字符词，另提供短词与长词分布；不是研究的5875词词库。

防御每0.1秒观察一次，具有分档反应时间、漏判和停笔恢复；只外推已观察到的弹体直线切向，不读取未来曲线和精确碰撞结果。Alt使用玩家也能调用的正式自动择位，终式按实际共鸣施放。识别、搜索和防御参数属于明确的游戏探针假设，未被报告校准为真人模型。机器人仍能读取可选目标、生命和预警状态，不能将结果解释为真人胜率。

同轮比较固定种子、输入模型、词库与取奖策略；调参轮使用相同种子，最终轮另加入留出种子。判断同时查看前四档可达、高手／顶尖灭世冷开、普通输入继承路径、实际输入投入、页耗时与失败位置。有限样本中的冷开失败不证明所有高手必败；继承路径未抵达灭世时，必须标明上游中断，不能算作灭世战败。

## 保留的旧阶段入口

- `test_s1_rules.gd` 是 `test_s2_rules.gd` 的继承基础，不可按旧阶段名移除。
- `test_s1_run.gd` 除首章流程外，保留路线保存失败、付款与重复执行边界。
- `test_s1_encounters.gd` 保留第一位 Boss 攻击组合、冻结中断冲锋和世界减速期间的恢复检查。
- `test_encounter_pressure.gd` 检查五档生成配额、敌人数上限、两段全灭出口、奇数散射中心弹道及Boss参数；另检查段间保留飞行物、页／章结束清场和支付结清。`--flight-boundaries`仅运行边界与反射重入专项。
- `test_ui_refinement.gd -- --combat-revision`使用独立Forward+窗口检查章／页入场、敌弹材质、奖励真实时间延迟与未完远征的Esc返回，图像和断言写入隔离证据目录。
- `test_talent_progress.gd` 保护当前五阶线性成长与字符回执，名称不表示仍有天赋树。
- `combat_fixture.gd` 是共用夹具，不是独立测试入口。

规则断言、受控夹具、正式流程和视觉审阅回答不同问题；只有确认被其他入口完整覆盖后才移除重叠案例。其他 Agent 正在修改的专项应随其任务验收，不在清理时合并或改写。

## 旧 Web

`legacy/web/tests/` 只用于明确需要的历史取证，不作为 Godot 门禁。已取消的天赋图布局、构筑事件、旧候选目录及一次性图谱浏览器验收不再保留；混有输入、结算和获取边界的旧测试仍可供规则溯源。准确玩法基线是交接锁定的 Git 提交，而非整个 legacy 工作目录。
