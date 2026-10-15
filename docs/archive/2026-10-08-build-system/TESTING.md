# 验证范围与证据

> 历史归档：2026-10-08 调整范围前的设计、计划或证据。正文中的要求与“下一步”不构成当前任务；当前实施见[交接文档](../../migration/AGENT-HANDOFF.md).

检查与改动风险相称。优先最低成本的充分验证；相关小修改在阶段边界统一检查，已有证据足够时停止加验。当前结果见[阶段总结](STAGE-SUMMARY.md)，阶段出口见迁移方案。

| 改动 | 首选检查 | 扩大条件 |
| --- | --- | --- |
| 文档、路径和简单资源配置 | 内容、差异、引用和直接结果 | 出现未解释的缺失引用或配置行为 |
| GDScript、场景、导入配置 | 最小脚本检查及 Godot 导入 | 核心共享类型、加载或生命周期有疑点 |
| 战斗、资源与输入 | 对应原生规则案例，覆盖真实回执、原子失败与边界 | 跨系统状态或正式流程接线变化 |
| UI、材质与输入归属 | 对应原生场景的实际操作和图像 | 共享布局、暂停、窗口、缩放变化 |
| 存档、交易与内容 | Godot 自身版本、失败恢复、去重、普通／God 隔离 | 正式获取接通或本游戏存档结构变化；不测浏览器账号迁移 |
| Windows 导出 | 导出依赖、独立启动、无调试桥 | 正式 Release 与干净环境发行 |
| 收益与难度 | 功能／内容完整后统一场景评估 | 明确的失败或覆盖缺口 |

不为简单可逆改动习惯性新建测试，不逐件遗物运行平衡脚本。不因为旧 Node 套件存在而全跑，不用脚本成功替代图谱观感、手感和成长门槛。

M4 已有按职责拆分的图、保存、交易、事件和正式应用检查，结果与证据边界见[M4 验收记录](migration/M4-ACCEPTANCE.md)。构筑体验结合真实路径和遭遇检查；整体收益、成长曲线和难度平衡统一留到 M5 完成后的 M6。

## 静态诊断与运行日志

GDScript 的整数除法、属性遮蔽、三元类型与整数当枚举等警告按其语义修正，不关闭全局警告、不删除类型标注。整数规则账保留精确的 int64 运算和向零截断；确认有意取整的语句使用局部 `@warning_ignore("integer_division")`，所在模块说明余数分摊、向上取整费用等约定，不改成浮点除法。枚举字段保留枚举类型；公共边界收到整数时再显式转换。

`--debug --check-only --script res://app/main.gd` 可通过锁定版本的 console 输出应用依赖链的解析警告，`--log-file` 使用绝对文件路径。`--check-only` 成功只证明解析通过，不带 `--debug` 的空输出不能证明警告为空。报告分别写清“解析通过”“运行未见错误”“编辑器诊断为空”，不得互相替换。检查对象以本轮修改脚本和相关加载链为限，不默认启动全量套件。M2 的实际反例和改法见 [M2 实施经验](../../migration/M2-IMPLEMENTATION-LESSONS.md)。

测试断言、引擎日志和退出清理分别审阅；通过数不覆盖运行错误或资源在用提示。窗口失焦造成暂停、自动化首个点击不稳定等失败保留原始记录，不拼接不同运行中的通过项，也不为自动化关闭正式产品行为。

## 原生工具入口

```powershell
pwsh -File tools/godot/godot.ps1 import
pwsh -File tools/godot/godot.ps1 run --headless --quit-after 3
# 只有工具接入或运行时观察需要时：
pwsh -File tools/godot/godot.ps1 preview
node tools/godot/mcp-smoke.mjs
# 只有导出配置或发行产物变化需要时：
pwsh -File tools/godot/godot.ps1 export
```

导入可能创建 UID 与导入配置，应审阅这些变化。Headless 运行不能证明 Forward+ 的真实画面；图形运行、截图和运行日志分别提供渲染、结构与错误证据。MCP 联调脚本验证连接和最小场景能力，不测游戏规则；输入、词库、应用和单房战斗检查如下。

视觉验收使用关闭游戏嵌入的独立窗口，并记录游戏分辨率与实际显示区域。编辑器右上角运行也可能启用嵌入；浮动的 Game 窗口仍属于嵌入。若编辑器运行与缓冲区截图的锯齿不同，先对照关闭 `Embed Game on Next Play` 后的同一工程，核对启动参数中的 `--wid`、实际窗口尺寸与缩放；不得仅凭资源文件或缓冲区截图声称用户可见问题已消除。嵌入模式不支持正常的窗口模式切换，不能作为全屏行为验收环境。参见 [Godot 游戏嵌入说明](https://docs.godotengine.org/en/4.7/tutorials/editor/game_embedding.html)。

## M4 图谱、保存与正式流程

```powershell
# 只在语义或图算法变化时生成候选，再独立检查后发布：
pwsh -File tools/godot/godot.ps1 run --headless --script res://tools/graphs/generate_talent_atlas.gd
pwsh -File tools/godot/godot.ps1 run --headless --script res://tools/graphs/publish_talent_atlas.gd
# 仅调整名称／描述时，保留正式拓扑和节点位置，刷新标签后仍须独立发布检查：
& ./tools/godot/godot.ps1 -Task run -EngineArguments @('--headless','--script','res://tools/graphs/generate_talent_atlas.gd','--','--refresh-labels')
pwsh -File tools/godot/godot.ps1 run --headless --script res://tools/graphs/publish_talent_atlas.gd
# 按改动选择对应职责，不要求每次全部运行：
pwsh -File tools/godot/godot.ps1 run --headless --script res://tests/godot/test_talent_allocation.gd
pwsh -File tools/godot/godot.ps1 run --headless --script res://tests/godot/test_talent_progress.gd
pwsh -File tools/godot/godot.ps1 run --headless --script res://tests/godot/test_profile_save.gd
pwsh -File tools/godot/godot.ps1 run --headless --script res://tests/godot/test_acquisition_rewards.gd
pwsh -File tools/godot/godot.ps1 run --headless --script res://tests/godot/test_reward_ledger.gd
pwsh -File tools/godot/godot.ps1 run --headless --script res://tests/godot/test_event_transactions.gd
pwsh -File tools/godot/godot.ps1 run --headless --script res://tests/godot/test_event_catalog.gd
pwsh -File tools/godot/godot.ps1 run --headless --script res://tests/godot/test_event_lifecycle.gd
pwsh -File tools/godot/godot.ps1 run --headless --script res://tests/godot/test_run_session.gd
pwsh -File tools/godot/godot.ps1 run --headless --script res://tests/godot/test_m4_battle_facts.gd
# 实际 Forward+ 窗口、原生鼠标／Unicode、独立保存和截图：
pwsh -File tools/godot/godot.ps1 run --script res://tests/godot/test_m4_application.gd
# 只核对 God 图谱路线／模式及连续静态抓图，不代替六房验收：
& ./tools/godot/godot.ps1 -Task run -EngineArguments @('--script','res://tests/godot/test_m4_application.gd','--','--visual-only')
# 只核对遗物图形、原生选中与详情名称：
& ./tools/godot/godot.ps1 -Task run -EngineArguments @('--script','res://tests/godot/test_m4_application.gd','--','--relics-only')
# 奖励三选一、详情隔离、天赋文案、真实输入触发冰霜／闪避及到期清理：
& ./tools/godot/godot.ps1 -Task run -EngineArguments @('--script','res://tests/godot/test_m4_application.gd','--','--quality-review')
& ./tools/godot/godot.ps1 -Task run -EngineArguments @('--script','res://tests/godot/test_m4_application.gd','--','--quality-review','--low','--reduce-motion')
```

图检查使用实际显示折线、节点外形与标签，量化为 1/16 像素，沿 824 条购买顺序逐前缀编译并查询当时用途；有限搜索没有最优路线证明。生成器只写候选，发布器 0 错误后才保存正式 Resource，打开页面不运行生成器。

获取报告逐项记录 171 件资格、主书、许可、层数、演化和真实能力需求；事件生命周期报告记录 32×3 个行动、具体对象、支付、检查点及边界。它们使用声明的合法情境，不证明每件战斗效果或统一收益。E17 另由 `test_m4_battle_facts.gd` 通过实际 Unicode 输入产生标记和正式历史查询，不以手工历史 fixture 替代。

应用检查使用独立档案。四书初始购买和普通跨书配置通过真实鼠标完成；普通预算来自正确前缀和放弃词咒的原生字符回执。战斗手动推进固定步，E31／E23 只固定已满足资格的事件身份，以覆盖抵押返还和试炼后奖励；其他状态、支付和房间结果走正式执行链。日志／JSON 明示 fixture，不能据此评价真人打字速度、难度或随机事件分布。

窗口抓图读取游戏客户区。取图时短暂置顶并等待正常布局／绘制，随后恢复原窗口状态，不请求键盘焦点；截图应与同次布局状态和原生操作结果一起审阅。

`--quality-review` 使用明确的遗物配置、敌人站位与候选 fixture，仍通过 Unicode 输入、方向键和正式交易触发效果与领取。专项合成输入关闭帧合并；完词等固定步提交后再断言；抓图引起失焦暂停时通过原生“继续战斗”恢复。短时命中在发生后抓图，页面仍等待布局稳定。它验证表现生命周期和交互，不替代随机获取、全内容组合或性能验收。截图须人工查看；进程退出码和通过数不能掩盖日志中的脚本错误。若指定引擎 `--log-file`，使用文件系统绝对路径，不传 `res://`。

实例快照、单份变体、事件战斗参数和新增遗物入口分别由 `test_m4_asset_snapshots.gd`、`test_asset_variants.gd`、`test_m4_event_rules.gd`、`test_m4_relic_increment.gd` 检查。损坏开场快照的负例会输出约定的拒绝错误；应逐条辨认，不能忽略其他脚本错误或退出警告。

## M3 规则与试验场检查

```powershell
pwsh -File tools/godot/godot.ps1 run --headless --script res://tests/godot/test_m3_core.gd
pwsh -File tools/godot/godot.ps1 run --headless --script res://tests/godot/test_m3_mechanisms.gd
pwsh -File tools/godot/godot.ps1 run --headless --script res://tests/godot/test_m3_review.gd
pwsh -File tools/godot/godot.ps1 run --headless --script res://tests/godot/test_m3_assets.gd
pwsh -File tools/godot/godot.ps1 run --headless --script res://tests/godot/test_build_lab_scenarios.gd
pwsh -File tools/godot/godot.ps1 run --headless --script res://tests/godot/test_m3_catalog.gd
# 实际 Forward+ 窗口、Unicode 输入、抗性、暂停及负载截图：
pwsh -File tools/godot/godot.ps1 run --script res://tests/godot/test_build_lab.gd
# 人工构筑试玩：
pwsh -File tools/godot/godot.ps1 run res://development/build_lab.tscn
```

核心检查覆盖来源账、编译与组成。机制检查按情境覆盖所有权竞争、旧快照、形状、辅助输入、运输、词形、实际两房交接与停笔收束；包含闪避供给、复写集中／分栏与寒墨穿透的同投入对照。`test_m3_review.gd` 从原生按键路由检查 Ctrl 补全、过期请求、输入归属，另查反击的打字供给及有效结果统计。资产检查覆盖逐份并存、指定移除／演化、返还回执与编译失败不改原配置；遭遇检查覆盖配置隔离、自然运动和真实攻击预警。

目录检查为每个保留 ID 建立记录，写入 `.temp/godot-m3/content-evidence.json`。每项只加入明示前置、许可和操作实际依赖，并与移除该项的构筑比较；登记、编译参数、生命周期和行为分别报告。总伤害只是运行观察，不再证明被检查条目有效。部分条目具有入口状态变化证据（`entry_state_only`），仍不足以证明全部条件、费用和描述承诺；整体行为缺证保留 `not_verified`。不能把该标记解释为全部未实现，也不能把目录退出成功解释为全内容验收完成。逐项费用、入口与验证族见 M3 内容映射，改法见[修正方案](migration/M3-REPAIR-PLAN.md)。

内容功能验收应按机制族复用情境，只带最少的必要前置，比较装备前后的具体结果及相应费用。普通数值节点可参数化覆盖；机制内容需检查触发条件、供给、消费和实际变化。输入功能还需从真实路由到达，测试直接调用结算函数不能替代入口证明。这些是正确性检查，不要求逐件新建平衡脚本；完整收益仍在功能与内容齐备后统一评估。

窗口检查复用正式战斗页、键盘路由和编译器，写入独立 `.temp/godot-m3/lab-*/` 证据；包含 Ctrl 提示与主动补全、实际命中后的结果汇总，以及三种战场情境。截图等待词咒渐入，战报等待真实接触，避免用空画面或全零计数代替观察。负载段加速手动推进固定步，观察实际允许的内容组合、活动对象与结束清理；其耗时和画面不代表真人输入速度、正式帧延迟或低端设备性能。人工基线、组合手感、收益和难度仍各自验收。

## M1 针对性检查

```powershell
pwsh -File tools/godot/godot.ps1 run --headless --script tests/godot/test_vocabulary.gd
pwsh -File tools/godot/godot.ps1 run --headless --script tests/godot/test_input_settings.gd
# 原生窗口操作、大小／全屏及截图；加 --headless 可只查交互断言。
pwsh -File tools/godot/godot.ps1 run --script tests/godot/test_application.gd
pwsh -File tools/godot/godot.ps1 run --script tests/godot/test_presentation.gd
# 修改输出分辨率、全屏或共用布局时：
pwsh -File tools/godot/godot.ps1 run --script tests/godot/test_display.gd
pwsh -File tools/godot/godot.ps1 run --script tests/godot/test_ui_refinement.gd
```

词库覆盖格式、行号、规范化、去重、过滤与写入恢复；输入覆盖原生事件路由、文本编辑归属、echo、组合键、辅助完成与一次领取；设置覆盖坏主档恢复后再保存、再次损坏仍可恢复的边界。应用检查经过正式 GUI／输入路由，覆盖左右法书直接点击、快速切书声部收束、准备页中央展开、主页 Enter 直接进入战斗且不创建焦点，以及导入、习字、暂停和设置往返，并保存原生窗口截图。测试注入 `.temp/godot-m1/` 下的独立路径，不写玩家设置或词库。

`test_display.gd` 使用 `.temp/display/` 独立设置，在十组代表性输出下检查设置固定头尾与滚动、准备页列宽、战场 HUD、安全区、正文／HDR 输出一致及字体采样。通过原生鼠标事件验证缩放与全屏留边后的命中位置；暂停中改界面缩放不推进战斗、不重置词条测量宽度。另覆盖分辨率保存恢复、窗口手动调整后修改无关设置、全屏往返及恢复默认。实际窗口保存 720p、4K、16:10、4:3 和超宽屏图像；无窗口仅验证断言，不作为图像或显卡性能证据。

`test_ui_refinement.gd` 使用真实输入事件检查种子编辑与词令隔离、难度与设置词令、滑条调整、下拉展开、按键组件及平滑滚动的累积／停稳／拖动接管；实际窗口保存悬浮、准备与设置图像。应用战斗检查等待冷区入场后再输入可见词条；单房规则检查覆盖八向出生间隔、冷区不可选和自然入场。

材质动态复查可为该入口追加 `-- --record-gold`，保存金丝局部连续帧及间隔采样的页面光晕帧。局部流光、分叉强弱、错峰节奏和整页受光分别观察；静态截图不能证明流动，采样过程含截图等待，不能据此评价真实帧率。

## M2 单房规则检查

修改光效采样、符阵导入或画布像素吸附时，可运行 `tests/godot/test_effect_sampling.gd`（必须使用图形模式）。它在 720p、1080p、1440p 中输出解析光环、SVG 符阵、原生线条与拖尾，检查实际 MSAA／mipmap 以及 0.35 像素移动是否被吸附。截图用于检查轮廓连续性，断言不替代视觉判断。

追加 `-- --application` 使用正式 `app/main.tscn`、设置和页面创建链路，检查三种分辨率下根视口与场景视口尺寸、实际 MSAA、像素吸附和动态创建的背景符阵过滤，并保存主界面原始帧及窗口／缓冲区尺寸。独立材质样例通过不代表正式页面所有实例均已接入；缓冲区截图也不能替代编辑器嵌入窗口缩放后的实际显示。

```powershell
pwsh -File tools/godot/godot.ps1 run --headless --script tests/godot/test_battle_session.gd
```

覆盖人工回执唯一性、四书付费主术、致死后仍执行的效果、残响改投、弹反／定向闪避、终式有限调度及胜败出口。纸灵另覆盖逐词增员与上限、同一实体俯冲返航、额度耗尽后盘旋、满员补给、静默消散与重新召唤；表现时序保存三只协同、返航与消散帧。原生窗口应用检查另以真实键盘事件完成一词并确认命中，保存战斗静态与施法帧。规则检查不证明完整操作手感、所有画质档、连续特效或数值难度。

`tests/godot/test_battle_room.gd` 通过正式应用完成四书三波普通房间，原生事件输入累计共鸣、释放终式、弹反与闪避，并覆盖暂停→设置→继续、胜败、重试和返回。使用独立临时设置与词库，不注入资源或无敌状态；窗口模式保存各波、赚得的终式和结果。Headless 可搭配引擎 `--fixed-fps 60` 快速验证规则流程，不能用其运行速度评价真实手感或性能。

`tests/godot/test_battle_presentation.gd` 在实际 Forward+ 窗口检查四书飞行／命中／终式、防御、暂停缩放与画质应用。防御时序断言真实反射弹仍在飞行、近战弹反立即反击且随后明显退出近身范围，并捕获闪避途中与落点。引擎可执行文件的 `--` 后支持 `--book=flame`、`--low`、`--medium`、`--reduce-motion`；`--audio-only` 不截图，采样默认音量下的实际总线峰值及声部上限。`--movie` 跳过截图暂停，可配合引擎 `--write-movie` 保存连续演出。时序用高生命目标观察后效，其注入的终式仅用于视觉检查，正式共鸣可达性由完整房间检查覆盖。证据生成于 `.temp/godot-m2/`。

表现检查使用 `.temp/legacy-ui-review/presentation-*/` 独立设置，经过真实入场事件验证首访不能跳过、F11 不触发入场、输入不泄漏到首页、音效顺序、再次跳过取消后续 cue、减少动态直接到达可交互状态及准备页背景文字退场；图形模式保存待机、两次折射波、到达书库与准备页的实际帧。图片需与旧版及源码一同检查，不能只凭断言认定效果相同。

动态连续性检查另覆盖悬浮的中间态／清晰终态／移开恢复、主题中间色、快速切书接续、房间法阵锚点不变、专属封印权重交接，以及过渡中打开页面的颜色继承。设置检查覆盖即时预听与防抖保存、仅下拉值不同的默认恢复和缩放后装饰位置。

按需绘制检查要确认场景的主题、悬浮、纹理就绪等刷新源已经收束，再在真实窗口中检查 Viewport 状态；无窗口模式没有实际绘制帧，不能用其状态证明停更。固定等待时长本身不能证明静止；当前本机窗口结果见阶段总结。

MCP 上游键注入缺少 `InputEventKey.unicode`；它适合鼠标、Tab、Esc 和运行时观察，不能作为字符输入证据。应用测试直接分发带 Unicode 的原生按键，不为测试改变正式输入处理。HDR 截图先按高精度像素转 sRGB 再写 PNG，避免线性颜色被误判为画面发黑；生成的预览桥也应用此转换。截图仍需查看，自动布局断言不替代视觉判断。迁移界面必须实际运行旧版对应流程，按[体验映射](migration/EXPERIENCE-MAP.md)核对，不能只检查新页面自己能否运行。

词条时序与冷区改动另由单房规则集覆盖：在途主术持有词条、无关命中不刷新、主目标命中后恢复词条；尚未有效锁定的冷区入场敌人不可新选／受伤／发动攻击，入场渐入。玩家靠边时，远程敌人也必须进入有效战场，不能因提前达到射程而停住，或因自行后退使词咒反复消失。有效战场内的点击、切换、字符锁定由固定步提交，击退至边缘及取消后仍可交战。表现脚本保存普通与强化施法对比、弹反、冷区与低画质帧；按钮悬浮截图包含中心光点及文字光晕。

`test_battle_presentation.gd -- --words-only` 单独检查头顶释义的两行测量与省略、空释义高度、选中层级、设置即时开关、底部提示独立、锁定后边缘可见及完整词牌避让 HUD，并保存开／关与边缘帧。使用实际 Forward+ 窗口；`test_ui_refinement.gd` 另经正式词令 `translation` 检查开关与保存回读。旧版 `WordLabelLayout`、`OverlayRenderer` 和实际锁定／击退画面是表现对照入口。

## 导出包周期卡顿记录

周期卡顿已按用户反馈暂缓排查，以下记录入口保留供再现时使用。

独立 EXE 使用 `keyabyss.exe -- --frame-profile`，默认持续记录直到正常退出游戏，不设时长或帧数截止。通过游戏退出或 Alt+F4 关闭时一次写出报告；强制终止进程无法保存内存中的记录。自动化可显式加 `--frame-profile-seconds=60`（5–120 秒，0 表示直到退出）。普通启动不加载记录节点。保持复现问题时的原有设置，记录期间先在首页停留，再打开设置或进入战斗。JSON 位于 `%APPDATA%\Keyabyss\performance\`，日志写出时刻不纳入帧统计。

记录含逐帧墙钟间隔、所在页面、物理耗时、主视口和离屏视口 CPU／GPU 耗时，以及开始／结束时的资源计数。汇总排除最初两秒，原始帧保留。`process_ms` 是引擎整帧时间，不能当成纯脚本 CPU 时间；渲染计数可能滞后一帧，GPU 计数不包含显示呈现等待。采样自身有开销，比较时保持相同记录条件，不能只凭总帧率归因。

本机可用 `pwsh -File tools/godot/godot.ps1 run --script tests/godot/profile_frames.gd -- --frame-profile --profile-driver --profile-label=sample` 运行首页→设置→战斗的固定窗口流程，输出 `.temp/frame-review/sample/frames.json`，并断言隐藏首页停绘和返回恢复。使用独立设置与词库，不改变玩家配置；这只能验证本机，不能替代发生卡顿的目标机采样。

## 旧实现的证据用途

旧版工具现在从 `legacy/web` 执行，例如 `node --test tests/resource-ledger.test.cjs`。详细覆盖见[旧验证说明](../pre-godot/TESTING.md)。旧测试的失败边界可用于设计原生案例，但不要求相同时间步、轨迹或随机序列。

浏览器自动化只用于明确需要回看旧版时，使用 Python Playwright；Godot 窗口使用 CLI／MCP。统一收益与难度评估必须覆盖正式 Godot 内容、获取与事件，旧结果不能替代。

## 证据记录

记录版本与内容状态、命令、范围、通过／失败／未覆盖及日志位置。原始输出放 `.temp/`，必要结论保留在文档。临时产物按规则移入 `.delete/`，不永久删除。

字体和图像实际显示不代表完整 UI 合格，短时窗口启动不代表长时性能，MCP 接口成功不代表全部工具已验证。工程正确性、视觉、交互、平衡、难度分别报告。
