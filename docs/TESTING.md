# 验证范围与证据

按行为查找脚本见[测试入口索引](../tests/README.md)。S1／S2 等文件名保留历史命名；选择依据是当前断言与依赖，不按阶段名执行整组。

模型对照、覆盖边界与日志联合判定的通用方法，见[战斗实施经验第12节](migration/M2-IMPLEMENTATION-LESSONS.md#12-模型评估状态交接与验证方法)。

检查与改动风险相称。优先最低成本的充分验证；相关小修改在阶段边界统一检查，已有证据足够时停止加验。当前结果见[阶段总结](STAGE-SUMMARY.md)，阶段出口见[迁移方案](migration/PLAN.md)。

| 改动 | 首选检查 | 扩大条件 |
| --- | --- | --- |
| 文档、路径和简单资源配置 | 内容、差异、引用和直接结果 | 出现未解释的缺失引用或配置行为 |
| GDScript、场景、导入配置 | 最小脚本检查及 Godot 导入 | 核心共享类型、加载或生命周期有疑点 |
| 战斗、资源与输入 | 对应原生规则案例，覆盖真实回执、原子失败与边界 | 跨系统状态或正式流程接线变化 |
| UI、材质与输入归属 | 对应原生场景的实际操作和图像 | 共享布局、暂停、窗口、缩放变化 |
| 存档、交易与内容 | Godot 自身版本、失败恢复、去重、普通／God 隔离 | 正式获取接通或本游戏存档结构变化；不测浏览器账号迁移 |
| Windows 导出 | 导出依赖、独立启动、无调试桥 | 正式 Release 与干净环境发行 |
| 收益与难度 | 功能／内容完整后统一场景评估 | 明确的失败或覆盖缺口 |

不为简单可逆改动习惯性新建测试，不逐件遗物运行平衡脚本。不因为旧 Node 套件存在而全跑，不用脚本成功替代画面、手感和最高档成长门槛。

当前范围为 S1–S4。旧 M3／M4 检查命令与证据已[归档](archive/2026-10-08-build-system/TESTING.md)，不是固定门禁。天赋图、377 项目录和 32 事件交易的取消规则不再补证；保留机制可抽取原有案例继续回归。

## 静态诊断与运行日志

GDScript 的整数除法、属性遮蔽、三元类型与整数当枚举等警告按其语义修正，不关闭全局警告、不删除类型标注。整数规则账保留精确的 int64 运算和向零截断；确认有意取整的语句使用局部 `@warning_ignore("integer_division")`，所在模块说明余数分摊、向上取整费用等约定，不改成浮点除法。枚举字段保留枚举类型；公共边界收到整数时再显式转换。

`--debug --check-only --script res://app/main.gd` 可通过锁定版本的 console 输出应用依赖链的解析警告，`--log-file` 使用绝对文件路径。`--check-only` 成功只证明解析通过，不带 `--debug` 的空输出不能证明警告为空。报告分别写清“解析通过”“运行未见错误”“编辑器诊断为空”，不得互相替换。检查对象以本轮修改脚本和相关加载链为限，不默认启动全量套件。M2 的实际反例和改法见 [M2 实施经验](migration/M2-IMPLEMENTATION-LESSONS.md)。

测试断言、引擎日志和退出清理分别审阅；通过数不覆盖运行错误或资源在用提示。窗口失焦造成暂停、自动化首个点击不稳定等失败保留原始记录，不拼接不同运行中的通过项，也不为自动化关闭正式产品行为。

## 原生工具入口

水晶阅读层专项：`godot.ps1 run --debug --script res://tests/godot/test_ui_refinement.gd -- --crystal-sheets`。使用隔离设置与档案，检查正文区避让、流光时钟、几何与布局稳定、减少动态切换及暂停返回，输出设置静态／动态、关于、图鉴和暂停实拍。截图用于审美检查，不用于性能结论。

### 遗物与阅读系统

按实际修改选择入口。目录检查覆盖97件正式遗物的独立可达性、全部196件定义读取、99件退池实例／已发报价兼容、前置／互斥、数值双层有效增量、用途差异和单次报价编译；机制检查按效果族通过正式取得、编译、人工输入与真实命中验证，包括状态消费、派生隔离、真实闪避落点、场到期、分裂一次性、电链回击、纸鹤攻防与跨页周期，不逐件建立测试。`test_s2_run.gd`默认分支包含旧构筑拒绝恢复时保留原档、失效奖励免费重建、保存失败与重试及事务去重。

```powershell
& ./tools/godot/godot.ps1 -Task run -EngineArguments @('--headless', '--debug', '--script', 'res://tests/godot/test_relic_catalog.gd', '--', '--expanded')
& ./tools/godot/godot.ps1 -Task run -EngineArguments @('--headless', '--debug', '--script', 'res://tests/godot/test_relic_effects.gd')
& ./tools/godot/godot.ps1 -Task run -EngineArguments @('--headless', '--debug', '--script', 'res://tests/godot/test_s2_run.gd')
# 内容闭环后按需统一采样，四书各六次获取，不作为普通改动固定检查：
& ./tools/godot/godot.ps1 -Task run -EngineArguments @('--headless', '--debug', '--script', 'res://tests/godot/test_relic_effects.gd', '--', '--gameplay-balance')
# 实际Forward+窗口，使用隔离档案：
& ./tools/godot/godot.ps1 -Task run -EngineArguments @('--debug', '--script', 'res://tests/godot/test_ui_refinement.gd', '--', '--relic-upgrade')
```

阅读窗口分支检查全部遗物首层／满层数字插值，并以原生鼠标／Alt事件检查术语悬浮、详情切换、固定操作位置和实际取得；另核对四书觉醒、减少动态、图鉴、指南与记录。保存的HDR转sRGB画面需人工审阅，不以断言或截图转换期间的帧率替代视觉／性能结论。

`test_ui_refinement.gd -- --menu-layout`使用同样的隔离窗口，覆盖书库／准备、设置分类、滑条与原生下拉、三选一、独立详情、稠密持有列表、图鉴检索、暂停往返和首次校准。检查方向／确认／数字与词令调用同一动作，输入框／词令前缀／弹层阻断误触，真实列表词令不被短编号提前提交，并保存各页布局。原生弹出窗口的按键事件携带该窗口ID；视口截图之后回到下一处理帧再继续操作。Windows可追加`--screen-capture`，将测试窗口置顶、等待0.8秒后仅截取客户区，使用显示输出颜色而不重复进行HDR转换；此参数只影响验证窗口。输入规则的较低成本回归仍用`test_input_settings.gd`。画面应单独审阅，功能断言不代替视觉检查。

效果检查的`--balance`分支用于内容收束后的统一组合采样，`--storm-ablation`用于定位雷鸣叠加来源；它们使用有限目标、固定3／6／9字符每秒及真实支付，不代表正式页段或真人通关。弹体同步微基准沿用`test_battle_presentation.gd -- --projectile-sync-cost`，仅测表现同步CPU开销。实际结果与限制见[阶段总结](STAGE-SUMMARY.md)和[收益评估](COMBAT-BALANCE-DESIGN.md)。

战斗算法可用 `pwsh -File tools/godot/compare-combat.ps1` 从优化前提交 `c39c032` 生成隔离参考子类，比较四书事件／状态与 1,152 个闪避选点；`-BenchmarkOnly` 只采样微基准，`-DodgeOnly` 跳过逐步战斗。该上传基线与本地原记录 `9f3539b` 的规则源码相同，仅剔除了转入私有资产库的新增字体。适配器针对该基线的方法与数据声明，未来结构变化需同步审阅，不能作为任意 Git 版本的通用比较器。正常运行前工具自动做锁定依赖的 Debug 编译。生成文件与日志留在 `.temp/`，不进入游戏或导出。

局部几何入口为 `test_battle_session.gd -- --geometry`，覆盖连续扫掠、首击顺序、贯穿快照／死亡连锁及接触尾迹；`test_defense_movement.gd` 覆盖御术与时钟。`test_combat_algorithms.gd -- --cold` 单列首次操作、会话准备、封送分配与 GC。数值程序集在各配置均启用优化，需和受影响 GDScript 一起检查；实际命令与结果见[实施记录](migration/COMBAT-ALGORITHM-IMPLEMENTATION.md)。

```powershell
pwsh -File tools/godot/godot.ps1 import
pwsh -File tools/godot/godot.ps1 run --headless --quit-after 3
# 只有工具接入或运行时观察需要时：
pwsh -File tools/godot/godot.ps1 preview
node tools/godot/mcp-smoke.mjs
# 只有导出配置或发行产物变化需要时：
pwsh -File tools/godot/godot.ps1 export
```

导入可能创建 UID 与导入配置，应审阅这些变化。Headless 运行不能证明 Forward+ 的真实画面；图形运行、截图和运行日志分别提供渲染、结构与错误证据。MCP 联调脚本验证连接和最小场景能力，不测游戏规则；输入、词库、应用和单页战斗检查如下。

视觉验收使用关闭游戏嵌入的独立窗口，并记录游戏分辨率与实际显示区域。编辑器右上角运行也可能启用嵌入；浮动的 Game 窗口仍属于嵌入。若编辑器运行与缓冲区截图的锯齿不同，先对照关闭 `Embed Game on Next Play` 后的同一工程，核对启动参数中的 `--wid`、实际窗口尺寸与缩放；不得仅凭资源文件或缓冲区截图声称用户可见问题已消除。嵌入模式不支持正常的窗口模式切换，不能作为全屏行为验收环境。参见 [Godot 游戏嵌入说明](https://docs.godotengine.org/en/4.7/tutorials/editor/game_embedding.html)。

## 渲染准备的相关回归

`tests/godot/test_render_preparation.gd` 需使用锁定引擎图形运行，不能 headless：

```powershell
pwsh -File tools/godot/godot.ps1 run --debug --script res://tests/godot/test_render_preparation.gd
```

检查正式材质覆盖、四条计算管线复用与实例纹理隔离、准备视口停更、原生粒子参数隔离、正常／减少动态的出征等待与单次完成、奖励绑定、四书场效果／终式及道具粒子回收。使用临时战斗，不读取或写入正式玩家档案；报告在 `.temp/render-preparation/checks.json`。当前固定计数50包含侧边晶片、法阵流光及启动柔光，随新增shader同步维护，不代表全部硬件管线变体覆盖。此检查不采样前后性能、不取代实际首屏→欢迎→出征的操作检查；导出还应确认烘焙记录与独立包启动，错误与退出日志单独审阅。

## 保留玩法的检查选择

加载／欢迎柔光局部检查使用`test_feedback_presentation.gd -- --ritual-light`图形运行：正常与减少动态两种模式下验证真实进度投影、点击继续、离场释放，并保存加载／欢迎／转场截图。观察不同光层的清晰度、透明边缘与文字隔离；不能用交互断言通过替代这些视觉判断。

结果页局部布局可运行锁定引擎的`--script res://tests/godot/test_feedback_presentation.gd -- --result-layout`（图形窗口）。该分支使用隔离档案，经正式出征后构造短局结果，检查归档数据、鼠标展开详情、底部位置与长列表内部滚动，并保存1920×1080截图；不模拟完整远征。默认分支另包含首页、符文规格和图鉴，只有相关改动才使用。截图阶段的同步取图与颜色转换耗时不作为游戏性能采样。

- S1：优先复用输入／设置、战斗会话、单页和表现检查；修改旧脚本中与取消规则相关的断言，不直接沿用整套旧 M4 应用流程。
- 每件保留遗物核对正式获取条件、叠层、触发和实际结果；按机制族复用案例，不用“有伤害”证明该遗物有效。
- 路线与奖励检查重复提交、支付、满层补给和退出边界。复杂合同／租期不再是当前覆盖要求。
- S2：覆盖三章九页、Boss、保留遗物升档、最高档继续周目、已用一次机会不刷新、普通重开清空局内遗物、结算不重复赚成长。
- S3：检查旧 Godot 字符／记录保留、线性成长、普通／God 隔离与不兼容旧局的处理；正式完整内容的收益与最高档门槛按[评估方案](COMBAT-BALANCE-DESIGN.md)统一进行。
- 人工输入速度、手感和视觉清晰度需要实际游玩；加速固定步或直接注入构筑只说明相应规则结果。

### 收缩后的正式检查

`test_boss_resources.gd` 专门核对三位 Boss 的五档血量、正式生成及页不会立即判胜；它不模拟完整 Boss 战。可用 `run --headless --script tests/godot/test_boss_resources.gd` 检查源码资源。导出工具还会用锁定编辑器引擎的 `--headless --main-pack <绝对 PCK 路径> --script <该脚本绝对路径>` 检查成品数据，失败即拒绝交付；源码检查不能替代这一步。

按改动选择下列入口，不作为每次修改后的全量套件：

```powershell
pwsh -File tools/godot/godot.ps1 run --headless --script tests/godot/test_s2_rules.gd
pwsh -File tools/godot/godot.ps1 run --headless --script tests/godot/test_s2_encounters.gd
pwsh -File tools/godot/godot.ps1 run --headless --script tests/godot/test_s2_run.gd
# 四书九页，通过正式 Unicode 输入、获取、路线与保存：
& ./tools/godot/godot.ps1 -Task run -EngineArguments @('--headless', '--script', 'tests/godot/test_s2_run.gd', '--', '--formal')
# 实际 Forward+ 窗口；--ui-only 仅复查页面与自然生成的道具词咒：
pwsh -File tools/godot/godot.ps1 run --script tests/godot/test_s1_application.gd
& ./tools/godot/godot.ps1 -Task run -EngineArguments @('--script', 'tests/godot/test_s1_application.gd', '--', '--ui-only')
```

`test_s2_run.gd` 的默认模式使用明确的合法结果夹具验证保存失败、升档、继承、去重、满层补给与重开；`--formal` 才包含实际打字打赢九页。`--balance` 为分阶段数值取样入口，记录速度、准确率、种子、防御策略与失败，不以预期胜败替代测量。`--cold-only`、`--retained-only --mistakes` 分别测快速冷开与中速继承，`--seed=s3-sample-2` 更换种子，`--book=frost` 等参数只复测受影响法书。`test_profile_save.gd`、`test_talent_progress.gd` 和 `test_reward_ledger.gd` 分别保护迁移原档、五阶自动成长与实际经验去重。

`test_s2_encounters.gd` 的 `--defense` 检查不打字的纯防御边界，`--tail` 检查停笔后有限效果，`--word-cost` 比较三／七字符的六词周期与主术等待。后两项隔离敌人 AI，不代表正式通关。窗口脚本支持 `--ui-only --low --reduce-motion` 复查低画质静态可读性；`--package-check` 将验证文件写到隔离的 `user://verification/`。使用锁定编辑器引擎的 `--main-pack <绝对 PCK 路径> --script <绝对测试脚本路径>` 从独立包目录验证资源，测试脚本本身不随包分发。官方 Release 模板不执行外部 `--script`，正式 EXE 另做独立启动检查；两类结果不能混称为 Release 交互自动化。测试子进程的 `APPDATA` 指向工作区独立目录，保持玩家数据不变。

体验与存档针对性回归：`test_single_run_save.gd` 覆盖唯一存档、退出保存、页恢复、重复奖励、重开原子性、God 分账及跨档写入失败重试；`test_s2_encounters.gd --arrival` 核对八向扇区分布与真实单敌批次，`--god` 核对四书普通／God 的致死、闪避和有限终式对象。`test_s1_application.gd --feedback` 在真实窗口完成首页打字、数字领奖、详情隔离、路线、继续／取消重开、暂停构筑／图鉴、隐藏激活和一步结束归档；`test_feedback_effects.gd` 使用受控敌人位置和敌弹，实际完词触发冰面、火场、反制与爆墨并截图，不将布置的战场当作正式玩法通关。

以下 M1／M2 命令是保留底座的定位入口，先核对与本次改动相关的断言，不因文件存在而全部执行。

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

`test_ui_refinement.gd` 使用真实输入事件检查种子编辑与词令隔离、难度与设置词令、滑条调整、下拉展开、按键组件及平滑滚动的累积／停稳／拖动接管；实际窗口保存悬浮、准备与设置图像。应用战斗检查等待冷区入场后再输入可见词条；单页规则检查覆盖八向出生间隔、冷区不可选和自然入场。

材质动态复查可为该入口追加 `-- --record-gold`，保存金丝局部连续帧及间隔采样的页面光晕帧。局部流光、分叉强弱、错峰节奏和整页受光分别观察；静态截图不能证明流动，采样过程含截图等待，不能据此评价真实帧率。

## M2 单页规则检查

四书机制优先使用当前专项入口，旧M2默认脚本中关于逐词供能、纸灵世界时间寿命和旧连锁规则的断言不作为当前契约：

```text
# 使用TOOLCHAIN锁定的Godot可执行文件；下列为引擎参数。
# 规则、人工投入、状态阈值、有限传播、闪避与终极：
--headless --path . --script res://tests/godot/test_s2_rules.gd -- --four-books
# 只复核雷鸣曲线、感电积累／衰减、分档接入及原生闪避／终极：
--headless --path . --script res://tests/godot/test_s2_rules.gd -- --four-books --book=storm
# 灰烬／寒墨当前参数、灼烧尾段与完词／落点清弹事件：
--headless --path . --script res://tests/godot/test_s2_rules.gd -- --combat-feedback
# 寒气1秒保留期、刷新／跨期分步、6点衰减、遗物、实际三次间隔施法冻结及冰雾：
--headless --path . --script res://tests/godot/test_s2_rules.gd -- --frost-control
# 冲锋普通防御互弹、完美闪避共鸣与无敌／慢时间，以及原有防御和世界时钟：
--headless --path . --script res://tests/godot/test_defense_movement.gd
# 实际窗口的HUD死角、连续30帧词咒稳定、固定表现时刻的清弹四阶段和三类敌人冻结起止、设置切换／暂停续播、完美闪避及真实大招无额外冲击波；可追加 --low --reduce-motion：
--path . --script res://tests/godot/test_battle_presentation.gd -- --combat-feedback
# 112组可重复的固定目标场景；不是正式Boss／真人体验：
--headless --path . --script res://tests/godot/test_s2_encounters.gd -- --four-books-balance
# 实际Forward+窗口，另可追加 --low --reduce-motion：
--path . --script res://tests/godot/test_battle_presentation.gd -- --four-books
```

场景采样固定3／6字符每秒、3／5／7字词、100%准确；普通目标100生命、耐久单体5000生命，停用AI移动／攻击及自动页段，保留击退。适配遗物经过实际获取事务预置；正式获取、真正Boss阶段与升档使用上方 `test_s2_run.gd --formal`。窗口专项以原生Unicode事件输入三词后观察状态、原生闪避与终极，终极人为充满仅用于视觉；输出HDR转sRGB帧需要人工查看。当前证据与限制见阶段总结。

修改光效采样、符阵导入或画布像素吸附时，可运行 `tests/godot/test_effect_sampling.gd`（必须使用图形模式）。它在 720p、1080p、1440p 中输出解析光环、SVG 符阵、原生线条与拖尾，检查实际 MSAA／mipmap 以及 0.35 像素移动是否被吸附。截图用于检查轮廓连续性，断言不替代视觉判断。

追加 `-- --application` 使用正式 `app/main.tscn`、设置和页面创建链路，检查三种分辨率下根视口与场景视口尺寸、实际 MSAA、像素吸附和动态创建的背景符阵过滤，并保存主界面原始帧及窗口／缓冲区尺寸。独立材质样例通过不代表正式页面所有实例均已接入；缓冲区截图也不能替代编辑器嵌入窗口缩放后的实际显示。

```powershell
pwsh -File tools/godot/godot.ps1 run --headless --script tests/godot/test_battle_session.gd
```

覆盖人工回执唯一性、四书付费主术、致死后仍执行的效果、残响改投、弹反／定向闪避、终式有限调度及胜败出口。纸灵另覆盖逐词增员与上限、同一实体俯冲返航、额度耗尽后盘旋、满员补给、静默消散与重新召唤；表现时序保存三只协同、返航与消散帧。原生窗口应用检查另以真实键盘事件完成一词并确认命中，保存战斗静态与施法帧。规则检查不证明完整操作手感、所有画质档、连续特效或数值难度。

`tests/godot/test_battle_room.gd` 通过正式应用完成四书三段普通页，原生事件输入累计共鸣、释放终式、弹反与闪避，并覆盖暂停→设置→继续、胜败、重试和返回。使用独立临时设置与词库，不注入资源或无敌状态；窗口模式保存各波、赚得的终式和结果。Headless 可搭配引擎 `--fixed-fps 60` 快速验证规则流程，不能用其运行速度评价真实手感或性能。

`tests/godot/test_battle_presentation.gd` 在实际 Forward+ 窗口检查四书飞行／命中／终式、防御、暂停缩放与画质应用。防御时序断言真实反射弹仍在飞行、近战弹反立即反击且随后明显退出近身范围，并捕获闪避途中与落点。引擎可执行文件的 `--` 后支持 `--book=flame`、`--low`、`--medium`、`--reduce-motion`；`--audio-only` 不截图，采样默认音量下的实际总线峰值及声部上限。`--movie` 跳过截图暂停，可配合引擎 `--write-movie` 保存连续演出。时序用高生命目标观察后效，其注入的终式仅用于视觉检查，正式共鸣可达性由完整页检查覆盖。证据生成于 `.temp/godot-m2/`。

表现检查使用 `.temp/legacy-ui-review/presentation-*/` 独立设置，经过真实入场事件验证首访不能跳过、F11 不触发入场、输入不泄漏到首页、音效顺序、再次跳过取消后续 cue、减少动态直接到达可交互状态及准备页背景文字退场；图形模式保存待机、两次折射波、到达书库与准备页的实际帧。图片需与旧版及源码一同检查，不能只凭断言认定效果相同。

动态连续性检查另覆盖悬浮的中间态／清晰终态／移开恢复、主题中间色、快速切书接续、页法阵锚点不变、专属封印权重交接，以及过渡中打开页面的颜色继承。设置检查覆盖即时预听与防抖保存、仅下拉值不同的默认恢复和缩放后装饰位置。

按需绘制检查要确认场景的主题、悬浮、纹理就绪等刷新源已经收束，再在真实窗口中检查 Viewport 状态；无窗口模式没有实际绘制帧，不能用其状态证明停更。固定等待时长本身不能证明静止；当前本机窗口结果见阶段总结。

MCP 上游键注入缺少 `InputEventKey.unicode`；它适合鼠标、Tab、Esc 和运行时观察，不能作为字符输入证据。应用测试直接分发带 Unicode 的原生按键，不为测试改变正式输入处理。HDR 截图先按高精度像素转 sRGB 再写 PNG，避免线性颜色被误判为画面发黑；生成的预览桥也应用此转换。截图仍需查看，自动布局断言不替代视觉判断。迁移界面必须实际运行旧版对应流程，按[体验映射](migration/EXPERIENCE-MAP.md)核对，不能只检查新页面自己能否运行。

词条时序与冷区改动另由单页规则集覆盖：在途主术持有词条、无关命中不刷新、主目标命中后恢复词条；尚未有效锁定的冷区入场敌人不可新选／受伤／发动攻击，入场渐入。玩家靠边时，远程敌人也必须进入有效战场，不能因提前达到射程而停住，或因自行后退使词咒反复消失。有效战场内的点击、切换、字符锁定由固定步提交，击退至边缘及取消后仍可交战。表现脚本保存普通与强化施法对比、弹反、冷区与低画质帧；按钮悬浮截图包含中心光点及文字光晕。

`test_battle_presentation.gd -- --words-only` 单独检查头顶释义的两行测量与省略、空释义高度、选中层级、设置即时开关、底部提示独立、锁定后边缘可见及完整词咒避让 HUD，并保存开／关与边缘帧。使用实际 Forward+ 窗口；`test_ui_refinement.gd` 另经正式词令 `translation` 检查开关与保存回读。旧版 `WordLabelLayout`、`OverlayRenderer` 和实际锁定／击退画面是表现对照入口。

## 首访配置与AOE反馈

时间停滞色散使用现有 `test_battle_presentation.gd -- --time-dispersion` 窗口分支：真实迫近弹道经闪避动作触发慢时，随后固定已提交战斗时钟，避免截图回读消耗状态；保存正常、起手、持续、低画质、减少动态及结束六帧。检查暂停保持过渡、减少动态停用通道偏移、到期关闭合成与屏幕拷贝。需实际审阅外围色边、中心及边缘词咒的清晰度，不代表真人闪避时机、完整遭遇或性能验收。

本轮设置与AOE反馈使用 `test_defense_movement.gd`、`test_input_settings.gd` 的最小规则集。前者覆盖圆圈、横竖激光、过早／不相交及反冲轨迹的完美闪避，并确认普通／完美御术均不防御AOE；后者覆盖FPS与首访完成标记的默认值和保存回读。

设置回归每次生成一个尚不存在的中文父目录，验证首次保存、校准完成标记回读和后续有效备份，避免已有目录掩盖初始化缺陷；创建／替换失败须在提示中指出环节。文件阻挡父目录的故意失败案例会输出引擎 `Could not create directory`，该项以失败返回值与提示断言为判据。

目标机同时出现用户shader缓存、词库索引目录与设置保存失败时，将 `检查保存目录.cmd` 与 `check-save-directory.ps1` 放在游戏EXE旁，保持报错游戏运行，普通双击CMD，输出 `logs/save-directory-*.log`。脚本记录目录／EXE的ACL、下载标记、签名与兼容性、账户及进程权限、安全软件配置和相关拦截事件；用独立临时文件验证创建／写入／重命名／回读，不修改现有设置或权限。验证必须包含Windows PowerShell 5.1默认CMD入口，不能仅用显式日志路径代替。PowerShell探针成功不证明游戏EXE未被单独拦截，失败则按实际HRESULT定位，不能据文件夹“只读”、EXE未签名或下载标记单独判断原因。

实际窗口运行 `test_ui_refinement.gd -- --setup-feedback`：原生入场、首访配置、鼠标调整音量与中文释义、三档画质和流体关闭／最高／低档配置、24秒压力循环回收、保存和再次入场、FPS开关、关于页返回，以及暂停中独立运行的试映。画质／流体选项通过真实控件信号提交，不能称为完整鼠标下拉操作验收。高低画面与关于截图需人工审阅。追加 `--cleanup-route=calibration` 或 `--cleanup-route=battle` 分别经过实际退出入口检查仍活跃的页面；战斗分支还核对暂停→设置→校准→返回时首页继续隐藏。

同一窗口入口还检查设置应用清除固定软件帧率上限并启用垂直同步，切换画质后策略保留；记录当前显示器刷新率及首页的一秒实际帧数。背景全屏柔焦、压暗与前景清晰度使用高低画面实拍审阅。60Hz显示器上的封顶检查不能代替120／144Hz或跨显示器切换的实际性能验收；截图阻塞及遭遇时序不同，不能直接把两帧FPS作为画质档位收益对照。

居中布局只需追加 `--setup-layout`：截取1920×1080与1440×900，通过正式显示设置及帧缓冲／预览视口尺寸确认实际输出，再检查中央设置组与FPS分离、真实鼠标释义／音量／保存，以及退出释放。该分支提前结束，不重跑24秒循环和无关页面；截图期间的FPS读数不用于性能比较。

垂直同步使用 `test_ui_refinement.gd -- --vsync-only` 的最小窗口分支，检查默认开启、真实鼠标关闭、保存回读、关闭后的刷新率上限、暂停中词令开启及恢复默认；多显示器时实际移动窗口并检查上限更新。不修改操作系统刷新率，当前60Hz设备的运行不能证明120／144Hz实际呈现或输入延迟。

`test_battle_presentation.gd -- --word-contrast` 使用暗／中／浅背景与共享BackBufferCopy，检查词咒空白区域不形成暗块并保存字形阴影帧。不是游戏CPU读回，也不代表所有战场背景或整帧性能。启动退出警告另以正式 `app/bootstrap.tscn`、锁定引擎的 `--verbose --quit-after` 观察完整载入与早退，不通过关闭警告验证。

## 导出包周期卡顿记录

`test_vocabulary.gd`覆盖持久索引读取、未变词库不重建、导入／同步后更新、同尺寸外部编辑失效、84,620词扩展库的字符串记录，以及抽样的逐票覆盖。首字母耗尽、释放、动态词长和短语字符数直接断言；真实战斗会话检查飞行主术保留／换词、死亡输入延续／放弃、道具到期和等待敌人补词，习字场景检查少量首字母与下一批候选。100／10,000词各5000次抽取／释放只测在线成本，排除预处理，不代表整帧性能。新增抽样规则不自动继承之前固定同词夹具的平衡结论。

`test_battle_presentation.gd -- --refresh-cost` 在实际窗口中使用一万词与32个保留目标（含12个死亡目标），采样60次内容未变的UI刷新，检查无效退场不重复发信号、重新测量不瞬移和最终坐标每帧移动上限。生成词条只服务测试，不改变正式选词。它不测整帧、全部输入更新或目标机长时表现。`--book-seals` 单独采四书首页法阵；`--four-books --book=storm` 额外断言并捕获第三击的独立电爆几何。

Debug 包默认运行 `app/debug_log.gd`，每 5 秒输出心跳，超过 50 ms 的帧保留前八帧、页面、战斗阶段／UI／特效／流体提交耗时、视口 CPU／GPU、管线编译计数及资源用量。存档／设置保存单独记录结果与耗时，词库读取超过 10 ms 时单独记录。日志不记录输入内容。Release 默认关闭，可用 `-- --debug-log` 开启；`-- --no-debug-log` 可关闭新增诊断作对照。

普通启动写 `user://diagnostics/session-日期-PID.jsonl`。测试包的“启动并记录.cmd”把会话日志和引擎日志写入同目录 `logs/`，用户可直接回传整个文件夹；引擎日志包含脚本错误／警告。会话日志由单独后台线程序列化、写入并刷新，不在主线程逐秒写磁盘。仅保留八帧上下文，事件队列上限 128，长帧报告限每秒四条；长期低帧率仍在心跳中计数，队列丢弃会明确记录。进程异常退出最多损失尚未写出的末批事件。

记录覆盖入场、菜单与战场，心跳保留帧率上限、垂直同步、载入状态，并每五秒异步提交一个渲染线程探针，记录排队／调度延迟；探针不等待 GPU，也不能排除提交之前发生的阻塞。阶段耗时是嵌套的包含耗时，不能直接求和；`fluid.prepare_submit` 只测主线程准备与提交，不代表 GPU 求解时间。视口计数可能滞后；锁定引擎的`TIME_PROCESS`按约一秒周期更新最大处理时间，不能当作当前帧纯脚本CPU时间。墙钟间隔包含调度、渲染等待和帧率限制，GPU时间戳跨度也不能直接证明shader计算很慢；需结合前后帧及同条件对照定位。原生场景载入之前的引擎阶段只有启动脚本的 `--verbose --log-file` 记录。两份启动脚本保持相同引擎参数，对照仅关闭新增会话记录。

无诊断对照仍有周期卡顿且游戏阶段耗时不足以解释时，使用包内“开始系统记录.cmd”／“保存系统记录.cmd”采集一次约30秒WPR轨迹；两个脚本右键以管理员身份运行，游戏正常启动。`GeneralProfile`和`GPU`记录线程切换／调用栈及GPU活动，保存后的`logs/system-stall-*.etl`与本次游戏日志一起回传。开始必须成功，保存会停止记录；具体步骤见[系统记录说明](../tools/godot/playtest/系统记录说明.txt)。2026-10-10目标机复现及尚未排除的边界见[调查记录](migration/PERIODIC-STALL-INVESTIGATION.md)。

需要完整逐帧报告时，独立 EXE 使用 `keyabyss.exe -- --frame-profile`，默认持续记录直到正常退出游戏。通过游戏退出或 Alt+F4 关闭时一次写出报告；强制终止进程无法保存内存中的记录。自动化可显式加 `--frame-profile-seconds=60`（5–120 秒，0 表示直到退出）。普通启动不加载这个完整帧分析器，默认 Debug 会话日志仍独立运行。保持复现问题时的原有设置，记录期间先在首页停留，再打开设置或进入战斗。JSON 位于 `%APPDATA%\Keyabyss\performance\`，日志写出时刻不纳入帧统计。

记录含逐帧墙钟间隔、所在页面、物理耗时、主视口和离屏视口 CPU／GPU 耗时，以及开始／结束时的资源计数。汇总排除最初两秒，原始帧保留。`process_ms`来自引擎按约一秒周期更新的最大处理时间，不能当成当前帧CPU耗时；渲染计数可能滞后，GPU计数不直接测显示呈现等待。采样自身有开销，比较时保持相同记录条件，不能只凭总帧率归因。

本机可用 `pwsh -File tools/godot/godot.ps1 run --script tests/godot/profile_frames.gd -- --frame-profile --profile-driver --profile-label=sample` 运行首页→设置→战斗的固定窗口流程，输出 `.temp/frame-review/sample/frames.json`，并断言隐藏首页停绘和返回恢复。使用独立设置与词库，不改变玩家配置；这只能验证本机，不能替代发生卡顿的目标机采样。

教学修改使用 `tests/godot/test_tutorial_lesson.gd`，覆盖五课的真实人工回执、付费施法和机制效果：冻裂超时后重试、火弹前排阻挡及停笔灼烧、感电实际充能、空雾与错线雷径不能达成、纸灵休眠再唤醒、纸鹤真实拦截反伤和四书终式。另检查读说明直至余火熄灭／纸灵睡完后仍可继续，以及在当前步骤创建新会话后能够通过实际操作完成。目标达成仅解锁继续，计时不会换步；`advance()`才切步／完成，重试及档案保持隔离。实际窗口专项为 `test_ui_refinement.gd -- --tutorial-mechanics --screen-capture`，覆盖25步全文排版、固定主操作与词咒避让、五课当前步骤重试／暂停／退出、术语原生鼠标提示、普通／减少动态入场、灰烬完整原生输入及余火重试、纸灵休眠步骤重试后的等待／唤醒、一次完成返回选课、完成标记及再次进入。排版专项中的步骤直设只检验表现，不能替代规则推进证据。原`--tutorial-arc`入口保留教学导航、灰烬输入和弧形飞行的组合检查。弹道的敌人起点、左右弯曲、远距离命中、场地边缘、分步一致性、扇形中央弹道、移动躲开、完美御术／闪避与无伤害尾迹纳入现有 `test_defense_movement.gd`。

仅修正弧形弹道时可运行实际窗口 `test_ui_refinement.gd -- --curved-trajectory --screen-capture`：正式敌人发射器产生来弹，关闭自动固定步后以受控步长推进实际威胁碰撞，捕获起点、途中、接近、低画质／减少动态及真实命中帧。通过 `godot.ps1` 调用时使用 `-EngineArguments @('--debug', '--script', 'res://tests/godot/test_ui_refinement.gd', '--', '--curved-trajectory', '--screen-capture')` 保留脚本参数。这些专项不替代连续真人体验与目标机性能。

切换目标与教学布局使用 `test_ui_refinement.gd -- --teaching-copy --screen-capture`，实操shade／shard／flame例子与即时目标提示，检查指南原生排版、五课正文与目标／操作的间隔、原生向上闪避时讲解让位及词咒避让同步、1.25倍桌面UI缩放，并保存实际画面。Tab前缀轮换规则沿用 `test_input_settings.gd`，不因文案更新改动输入规则。窗口检查独占图形运行，初始化完成后取得真实窗口焦点；不在检查中屏蔽产品失焦暂停，也不与启动其他引擎窗口的检查并行。

## 旧实现的证据用途

旧版工具现在从 `legacy/web` 执行，例如 `node --test tests/resource-ledger.test.cjs`。详细覆盖见[旧验证说明](archive/pre-godot/TESTING.md)。旧测试的失败边界可用于设计原生案例，但不要求相同时间步、轨迹或随机序列。

浏览器自动化只用于明确需要回看旧版时，使用 Python Playwright；Godot 窗口使用 CLI／MCP。统一收益与难度评估必须覆盖正式 Godot 保留内容、获取与连续挑战，旧结果不能替代。

## 证据记录

记录版本与内容状态、命令、范围、通过／失败／未覆盖及日志位置。原始输出放 `.temp/`，必要结论保留在文档。临时产物按规则移入 `.delete/`，不永久删除。

字体和图像实际显示不代表完整 UI 合格，短时窗口启动不代表长时性能，MCP 接口成功不代表全部工具已验证。工程正确性、视觉、交互、平衡、难度分别报告。
