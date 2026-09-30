# Godot 迁移实施 · Agent 接力

交接日期：2026-09-30。工作目录：`F:\Workshop\game\keyabyss`。

本文件帮助接手实施，不另立技术路线或待办清单。执行范围由当前用户授权决定；实际状态见[阶段总结](../STAGE-SUMMARY.md)，未完成项只维护在 [TODO](../TODO.md)。

## 接手结论

**当前先推进 M4 天赋图基础建设。** 先落实图数据、合法购买／撤点和程序生成，再做图谱交互及正式成长／获取；具体方法见[M4 天赋图方案](M4-TALENT-GRAPH-PLAN.md)。构筑体验结合真实图模型和 M5 遭遇判断，整体平衡放在 M5 完成后的 M6。Godot 按新游戏建立成长，不实现旧浏览器数据导入／导出。下面的 M3 记录用于说明现有基础，不构成等待其全部体验验收后才允许开工的限制。

**M1 与 M2 已验收；M3 的本轮明确缺口已修复，但逐项内容效果与体验尚未完整验收。** 接手先读[阶段总结](../STAGE-SUMMARY.md)、[功能修正方案](M3-REPAIR-PLAN.md)和 [M3 接入说明](M3-INTEGRATION.md)，设计依据保留在[天赋、战斗与打字核心评审](../build-system-design/08-TYPING-AND-BUILD-REVIEW.md)。当前参数版本 m3.2：Ctrl 主动补全、打字供给强化反击、R037／R041／R073／T03 修正、逐份资产身份、有效结果记录及三种战场情境已接入。用户已确认打字始终是主要进攻来源；继续沿用原生编译、快照、来源账和固定步。目录检查已去除无关预配能力并明确缺证，退出成功仍不代表每件内容有效，也不能扩写为正式获取、收益与远征已经完成。

工作区未自动提交，仍包含用户此前的战斗、内容与文档增量，以及 M0 目录搬迁状态。不要执行 `reset --hard`、`clean` 或覆盖式还原。旧实现位于 `legacy/web/`，不是第二条活动产品线。

特效迁移先确定 Godot 中的合理实现：旧代码用于理解目的、触发、节奏与受效范围，不作为 Web 架构照搬模板。当前入场使用独立 HDR SubViewport、CanvasItem 折射与 AnimationPlayer，尘埃使用 GPUParticles2D；后续战斗空间扭曲也应按原生场景合成、可读性与性能预算设计。保留原作身份与交互质感，允许原生实现达到更好的表现。

M1 与 M2 分别获得用户验收；后续新增内容仍需按实际改动确认。UI 开工先读 [UI 迁移实践](UI-IMPLEMENTATION-LESSONS.md)，沿用房间法阵／法书图案分层、正文清晰层、全操作词令和无默认焦点链；审美实现由主控亲自负责。最近的材质约束是光晕清楚且缓慢流转、金丝分叉短淡、流光柔和慢速且错峰，不把光晕反馈误改成更繁密的金枝。当前源码、旧导出与各轮检查的边界见阶段总结，不从历史全绿报告推断最新代码全部通过。

## 阅读入口

1. [根规则](../../AGENTS.md)、[阶段总结](../STAGE-SUMMARY.md)、[实现快照](../TECHNICAL-SNAPSHOT.md)和唯一 [TODO](../TODO.md)。
2. [迁移方案](PLAN.md)、[M3 接入说明](M3-INTEGRATION.md)与 [M2 实施经验](M2-IMPLEMENTATION-LESSONS.md)：状态所有权、输入与规则提交、内容、资产交接和表现边界。
3. [产品设计](../PRODUCT-DESIGN.md)、[构筑系统框架](../build-system-design/04-SYSTEM-FRAMEWORK.md)：四书、人工收入、主术、防御与已付后效。
4. UI 实施读取 [UI 迁移实践](UI-IMPLEMENTATION-LESSONS.md)，并按需读取[金丝水晶](../ART-DIRECTION.md)、[开放 UI](../OPEN-UI.md)、[玩家文案](../CONTENT-STYLE.md)、[工具链](TOOLCHAIN.md)和[旧数据映射](DATA-AND-ASSETS.md)。

历史资料在 `docs/archive/`，旧源码路径统一加 `legacy/web/`。历史测试数量、参数与“下一步”不能直接当作当前完成事实。

## 可直接使用的 M1 实现

| 入口 | 当前作用 |
| --- | --- |
| `app/main.tscn`、`app/main.gd` | 原生根场景、服务组装、页面与暂停切换 |
| `game/input/input_router.gd` | 文本编辑、模态、菜单和词会话的唯一输入归属 |
| `game/input/typing_session.gd` | 首字母锁定、进度、错误、取消、切换与辅助完成 |
| `game/input/manual_input_receipt.gd` | 正确人工字符的唯一回执，`drain_receipts()` 只领取一次 |
| `game/vocabulary/`、`assets/vocabulary/` | 12 本真实词库、严格词长筛选、五类外部词表解析与原子保存 |
| `game/persistence/app_settings.gd` | 设置、坏档备份恢复、全屏和统一缩放；可注入测试路径 |
| `ui/page_shell.gd`、`open_button.gd`、`practice_page.gd` | 固定标题与操作、内部滚动、鼠标与词令响应、习字统计；普通控件无默认键盘焦点 |
| `ui/archive_stage.gd`、`archive_theme.gd` | 独立 HDR 场景与柔光、全幅折射、共享渐变主题；正文在受效层外 |
| `ui/archive_home.gd`、`archive_gate.gd`、`game/content/books/` | 原四书身份、轨道书库、入场仪式、出征书页与保存配置 |
| `ui/theme/`、`ui/materials/`、`assets/art/` | 两套字体、原插画与封印、纸面 shader、浮层柔焦和减少动态 |
| `audio/archive_audio.gd`、`assets/audio/ui/` | 原 UI 音效片段、冷却／并发、四秒氛围循环 |
| `tests/godot/` | 词库、输入／设置、完整应用原生窗口的针对性回归检查 |
| `tools/godot/import-vocabulary.mjs` | 从冻结 JSON 生成活动词库及来源哈希，不手工双维护 |

词库与设置写入 `user://`；测试均使用注入的独立目录，预览使用 `Keyabyss-M1-Preview` 用户空间。普通／God 进度与成长尚未实现，不建设旧浏览器档案桥接。

## M2 已接入链路与后续边界

`BattleSession` 已接通人工字符 → 唯一收入 → 主术 → 命中 → 致死后已付效果 → 房间清理，四书、共同防御、终式、敌人和单房胜败均有正式入口。后续依据当前授权与 TODO 推进 M3，不重新铺空类、通用 ECS 或复刻旧 Web 双轨门控。

- 输入事件及时进入 `TypingSession`，在下个固定步领取人工回执。UI 与辅助完成不能自行发收入；习字统计不写入永久成长。
- `ManualInputReceipt.id` 是会话内唯一回执身份；资源事务层已经负责领取去重与合法收入提交，不把重复 signal 当成另一笔收益。
- `TypingSession.completed` 通知已完成词及人工字符数、辅助标记；需要保留已付后效时，以稳定目标身份与冻结来源处理，不依赖仍存活的节点。
- 当前 `InputRouter` 的 Space／方向／Alt／单独 Shift 已接入战斗动作；习字仍只显示按键反馈。实际反射弹、近战分离推离、闪避轨迹与无敌状态由统一规则链持有，不用播放特效冒充防御。
- 固定步与可变帧表现分离，暂停停止战斗，暂停页保持响应。共享 Resource 不存每局余额。公共接口和业务取舍由主 Agent 负责。

M2 出口见迁移方案：真实输入到收益闭环、致死后效、暂停与缩放、固定步和渲染分离、真实原生窗口中的手感。全图和全事件不构成 M2 前置；完整内容与平衡仍属于后续阶段。

固定表现结构已场景化，接触几何、尾迹、阻尼、按键提示、页面壳与材质有共用入口，详见实现快照。设计基准为 1920×1080，实际输出可在设置调整。周期卡顿按用户要求暂缓；若目标机独立 EXE 再次复现，沿已有帧记录入口排查，不把本机未复现写成根因已解决。

## 工具与证据

引擎锁定 `4.7.2.stable.mono.official.ed1daf0bf`，本机路径由 `tools/godot/local.paths.json` 指定。Windows 同版模板已就绪，无 C# 业务，不需构建程序集。

```powershell
pwsh -NoProfile -File tools/godot/godot.ps1 import
pwsh -NoProfile -File tools/godot/godot.ps1 run
pwsh -NoProfile -File tools/godot/godot.ps1 preview
```

MCP 主服务为 `keyabyss_godot`，固定 `127.0.0.1:9090`，只操作 `.temp/godot-mcp/project` 生成副本。先停止旧实例再刷新副本；正式改动始终写根工程。旧副本移入 `.delete/`，不永久删除。

MCP 可以观察窗口、结构、属性和日志；上游键注入不设置 `unicode`，不能用它证明字符输入链。`tests/godot/test_application.gd` 将真实 `InputEventKey` 经 `Input.parse_input_event()` 送入应用，并可运行真实图形窗口保存截图。复现见 [TESTING](../TESTING.md)。

原功能底座的检查索引为 `.temp/godot-m1/evidence.md`；本轮原项目对照、输入纠偏和资产声音记录在 `.temp/legacy-ui-review/`，更新后的应用检查在 `.temp/godot-m1/application/`。旧截图及旧导出只证明当时状态，不可用来代替本轮视觉检查。M0 证据仍在 `.temp/godot-preparation/`。这些本机忽略目录不会自动随仓库分发。

上游桥接的 5 条已知静态警告没有被隐藏；正式工程与导出不包含桥接。M1 证据不证明战斗、全内容、图谱、难度、长时性能、Release 或素材许可完成。

## 交付约定

只在用户授权范围推进。每阶段维护阶段总结、实现快照与唯一 TODO；本文件保持可用的接手入口，不追加完成流水。功能与检查对应，清理的临时文件移入 `.delete/`，不动用户既有改动。

字体来源许可仍待正式发行前补齐。后续正式资源进入项目时同步来源与声明；本地可显示不等于发行条件完备。
