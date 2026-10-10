# 当前实现快照

战斗查询由 `BattleSession` 的房间 ID 索引和 `SpellRuntime` 的单目标线性择优处理，范围伤害仍保留排序快照。单命中投射物选最早连续接触，贯穿与实体分离维持原顺序。自动闪避保留 GDScript 预测，以一次 `DodgeScorer.Choose` 调用在 .NET 内完成批量评分；状态与视觉事件仍归 GDScript。窄程序集、构建／预览和代价见[工具链](migration/TOOLCHAIN.md)与[实施记录](migration/COMBAT-ALGORITHM-IMPLEMENTATION.md)。

词库抽样由`VocabularyIndex`与`VocabularySampler`共用：前者持有26个按可输入词长排序的索引桶及26×25累计计数，后者只持有按目标ID管理的占用和26位掩码。按合法总词数抽一个整数，再定位桶内词条；在线抽词最多扫描固定26桶，释放按ID常数时间，不遍历词库或全体敌人。战斗与习字均使用它，渐进范围和长词偏好在当前范围上查询，不重新分桶。

`VocabularyRepository`在导入／同步保存后立即预处理并写入`user://vocabulary/indices/<词库ID>.bin`，索引与标准化词形／释义一同持久化。启动加载书库前由Bootstrap后台线程准备目录：已有索引直接还原，源词条记录或索引格式变化才重建。外部编辑在下次启动或打开对应词库时发现，以源记录精确比较判断，不依赖时间戳精度或摘要。正式战斗请求必须传入已准备索引；开始游戏只筛选配置范围并引用索引，不重建。独立规则夹具的`start_baseline`仍可从合成词条建立测试索引。索引为派生文件，保存使用临时文件加替换；源词库和玩家进度分别保存。

根工程现在使用 Godot。以下描述实际文件，不把[迁移方案](migration/PLAN.md)中的目标模块写成已经实现。整体状态见[阶段总结](STAGE-SUMMARY.md)。

冰火小样已接入正式战斗，并继续保留 `development/element_lab/run.cmd` 作为独立观察入口。两者共用 `ui/effects/frost_growth.*`、`frost_surface.glsl`、`combustion.*` 及 `ui/materials/ice_surface.gdshader`、`combustion.gdshader`。晶枝实时附着、增厚，薄膜从成熟枝网延迟铺展，晶尖领先；两张生成微观纹理位于 `assets/art/effects/`。小样可切换膜层及水汽密度，暂停时仍可移动灯光，详见[小样说明](../development/element_lab/README.md)。

正式入口已收缩：主书直接起局，编译／奖励只读取主书及 R001–R058，旧天赋、副书、形状和材料不再参与。`s2_itinerary.tres` 连接三章九房、17 类普通敌人与三位守关者；路线为休息／付血换遗物。图鉴使用固定列表与详情。留痕按有效字符自动增长，最多增加 20 点初始生命。连续挑战保留主书、遗物和已用机会，先升档，再进入最高档周目。

御术按真实玩家碰撞体和至多 0.06 秒来弹轨迹预测判定；持续 0.30 秒，前 0.10 秒为完美，冷却 0.70 秒（R058 为 0.49）。普通防御免除该攻击伤害并轻推周围敌人，力度为完美防御的 15%，保留运动、蓄力、冲锋与待发攻击；已防住的同次冲锋继续穿越且不重复伤害玩家。完美反射敌弹或中断近战／冲锋，区域攻击不反射。两种防御命中后，每次御术产生一次 160 设计像素的周边击退，直接攻击者受力更强，按质量衰减，不附加范围伤害；空按不产生击退，范围不参与来弹拦截。反制道具在 520 设计像素范围内反射敌弹并中断敌人及 Boss，基础伤害为 12 点，不随反射弹数膨胀。普通纸灵移动推进为原来的 0.75，特殊交叉合击、伤害和存续计时不变。

首次完美防御成功后开启独立的 0.30 秒连续反弹窗口，按真实时间倒计时，补足御术剩余时长；窗口内将命中的后续攻击继续按完美防御处理。后续命中不刷新窗口，不重复周边冲击、慢时间或蓄能奖励。闪避取消窗口，新房间／新御术重置状态；普通防御不会开启该窗口。

`BattleStatistics` 从真实输入与战斗事件采集错字、错词、最高连笔、连续正确字符、闪避、御术、完美防御、终式、击破和实际伤害；最高连笔与连续正确字符分别记录，受伤降连笔不抹掉已达峰值，跨房取最大值。伤害读取 `impact.applied_q`，覆盖直接伤害及死亡连锁并排除过杀。各房段快照按稳定 ID 覆盖，保存重试不双计，续挑战清空此轮统计。结果页读取归档 `result_build` 与 `result_stats`，呈现遗物层数、前十二个错词及释义，支持 JSON 战报；旧档没有数据时不伪造累计值。

图鉴复用编译器／目录和详情节点，先注册全部词令，再以 2ms 批次建立列表。`OpenButton` 在可见滚动区域内按每帧共享 2ms 预算准备装饰，切页或隐藏即停止；普通页面按钮维持同步建立。头顶词咒保留稳定实体顺序与上次避让偏移，实体直接跟随，只有避让偏移连续移动。

Ctrl 补字只由 R017「通灵羽毛笔」的 `assist` 规则解锁，每 4 个亲手完成的词咒产生一次机会；执行与可用提示共用遗物权限和机会余额，通用输入资源不能兑换。可用状态通过人物身旁 Arcana384「全」字符脉冲表达，减少动态保持静态。R028 腐蚀墨迹仍是附着敌人的持续伤害，其脚下蚀纹随状态退出；不新增地面伤害判定。焰印接入流体粒子后持续同步实际发射形状／半径，覆盖火场内部；新增腐蚀材质纳入启动预热。

`BattleSession.world_delta()` 提供无副作用的世界时间积分，`world_time` 累计实际推进量；流体与燃烧使用相同增量，`BattleVisualClock` 缓存战斗子树粒子与 Tween，统一速度、灯光退场和粒子回收。纸灵轨道、普通击退和世界动画使用世界时间；主动闪避、御术操作窗口、输入、HUD 与实际用时统计保留真实时间。反制覆盖半径与 shader 细节尺寸分离，普通／完美御术分别使用青白／金白反馈，角色保持可辨识。

`BattleSlowLens` 在战场／危险提示之后、HUD 之前采样一次屏幕，采用四次径向鱼眼与从边缘向中心推进的冷色遮罩，词咒锚点使用逆映射跟随实体。正常时间关闭屏幕复制，减少动态关闭镜头变形。

启动入口为 `app/bootstrap.tscn`：在首屏前读取并应用全屏、输出分辨率与减少动态设置，随后将同一设置实例交给主场景，避免加载完成时重设窗口。先绘制 `DepartureRitual` 的符文、柔光与 `ritual_backdrop.tscn`，再线程加载正式资源、准备四条共享计算管线及正式材质（47 个自定义 Canvas／粒子 shader），最后载入欢迎与书库。加载和欢迎共用暗青中心柔光、细金环、轴线、月牙与双层流动细尘；外围背景压暗，标题附近纹样自然消隐。`ritual_light` 用笔画覆盖梯度表现浅金属边缘与局部掠光，`engraved_gold` 为标题和刻线提供暗金／浅金反射，文字覆盖保持清晰。阶段、完成数与等待秒数可见，未知时长的书库加载保留已完成符文环，减少动态冻结装饰运动并保留进度。准备视口完成后停止更新；后续出征在遮罩下等待实际战场绘制，揭幕后恢复物理步与打字输入。固定材质、粒子曲线、场效果、灯光、按钮光效和奖励项已使用原生 `.tscn`／`.tres`，实例数据独立；具体范围和维护入口见[渲染准备方案](migration/PLAN.md#渲染准备与原生资源实施方案)。Shader Baker 已开启，导出必须有图形设备。

共用页面通过 `BodyRegion` 保持标题下方的固定留白，`ContentMargin` 将正文与滚动条隔开，嵌套词库列表继续填充剩余高度；按钮左右内容边距统一为 12 个设计像素。

首屏等待使用 Arcana384 的 24 枚符文与中心符号，原生 `TextureProgressBar` 径向点亮、`AnimationPlayer` 旋转；有总量时对应实际阶段完成数，无总量时亮弧仅表示活动。减少动态停止旋转，仍显示阶段与计数。欢迎场景大法阵待机透明度为 0.03，与唤醒动画起点一致，避免加载后背景突然变得难以辨认。

设置使用固定的显示／效果／声音／玩法标签；`fluid_quality` 独立保存关闭／低／中／高／极高，开启档均逐帧更新。`FluidField2D` 和 `fluid_solver.glsl` 在主渲染设备求解速度与独立高分辨率雾场，输送密度、有符号温度、颜色、年龄，压力使用 R32F。`FluidBody2D` 默认通过动量推雾，硬障碍另行选择。`FluidMotionPath` 保留连续扫掠与折点，`FluidAtmosphere` 接首页书体与战场事件，`FluidMedium` 配置物质，`FluidEffectProfile`／`FluidEmitter2D` 组合力、注入、粒子与共享原生光源。闪避沿途补雾、雷电路径光、冰火尾迹、出征淡出均已接入；粒子通过 `FluidParticleFlow` 读取相同速度。质量切换保留外层纹理 RID，关闭流体保留场景照明。接口、预设与近似边界见[流体视觉工具](FLUID-EFFECTS.md)。

主画布和首页／入场／战斗 HDR 视口使用 4× 2D MSAA，并关闭 Control 整像素吸附。细线 shader 以连续距离的像素足迹过滤；四书法阵按小／中／大分别生成 128／384／1024 像素资源，以 mipmaps 处理缩小采样，大规格保留双层符文环、交错几何与元素卫星阵。拖尾在保持光学宽度的同时留出抗锯齿边缘。

寒墨冰域与终式通过 `IcePatch` 持有有限 GPU 模拟，读取付费对象的半径、时钟和到期状态。普通冰域按画质新建 96／128／160² 晶格，大区域为 128／192／256²；暂停停止成长，到期释放。命中及冻结敌人只使用同源微晶细节，不重复求解。`FluidAtmosphere` 从实际火场、终式和火焰冲击提供燃料，单一燃烧网格读取相同气流；热态独立发光，停供冷却后停止调度，火星绑定该气流。质量切换保留材质采样绑定。旧冰晶图集及离线显露工具移入 `.delete/element-integration/`。雷电与终式采用金色，路径灯光随放电闪烁；完美御术／反制／爆墨使用 `BattleVisuals._spawn_item_burst` 的两层 GPU 粒子和局部材质，亮核、碎晶与火星承担主体，薄雾和短时照明作辅助，不依赖流体开关。旧道具体积资源移入 `.delete/particle-bursts-20261009/`。道具散光已收短，火书命中强化为白热核心、橙色余光与短寿命火星。当前渲染准备回归覆盖四书场效果／终式、道具粒子及回收，未复验引力规则或完整遭遇的观感。战场无上下浮力或沉降，正文保持独立层。证据见[元素材质](art/ELEMENT-EFFECTS.md)；`builds/windows-release/` 是此前通过烘焙导出与独立启动的包，不包含本轮反馈修改。

| 入口 | 当前职责 |
| --- | --- |
| `project.godot` | 4.7 特性、主场景、Forward+、HDR 2D、1920×1080 默认窗口与设计尺寸、60 Hz、用户目录 |
| `app/bootstrap.tscn`、`bootstrap.gd` | 启动等待、异步加载、渲染准备与主场景揭幕；维持共享管线和资源生命周期 |
| `app/main.tscn`、`main.gd` | 应用场景包含首页实例、输入路由、音频、设置保存计时器和指针；脚本负责服务注入、页面切换、设置／词库／导入、暂停与胜败入口 |
| `app/frame_capture.gd` | 仅显式传入 `--frame-profile` 时加载；逐帧间隔、物理与视口 CPU／GPU 记录，默认持续到正常退出，一次写入 `user://performance/`；自动化可显式指定时长 |
| `app/debug_log.gd` | Debug 默认启用；长帧上下文、每五秒心跳、硬件／渲染／编译／资源与关键操作记录，后台线程持续写 JSONL；Release 可显式开启，跨设备入口见 TESTING |
| `ui/scenes/archive_stage.tscn`、`battle_stage.tscn` | 首页与战场的可编辑 HDR 视口、WorldEnvironment、背景和输出层；场景材质各实例独立。首页隐藏时停止节点处理与离屏绘制 |
| `ui/scenes/archive_home.tscn`、`archive_book_visual.tscn`、`archive_effects.tscn` | 首页固定标题、菜单、出征两翼、法阵／光束／尘埃及法书视图模板；书本内容、选书轨道和展开动画由脚本驱动 |
| `ui/scenes/archive_gate.tscn` | 入场仪式的 HDR 视口、双法印、文字、粒子、输出材质与 AnimationPlayer，引用既有唤醒时间线 |
| `ui/scenes/departure_ritual.tscn` | 出征遮幕与战场交接；场景发出 covered／completed，应用在揭幕后才开放输入和固定步 |
| `ui/scenes/pause_content.tscn`、`battle_result.tscn`、`stat_readout.tscn` | 原生暂停、实际等级与状态、构筑／图鉴／指南／设置入口；主动结束一步归档返回，复用 PageShell 固定头尾 |
| `game/spells/battle_ultimate.gd`、`ui/scenes/ultimate_field.tscn`、`ultimate_indicator.tscn` | 已付终式的固定步持续状态、领域光效与蓄能／持续时间指示；视觉读取规则，不驱动伤害 |
| `ui/scenes/popup_crystal.tscn`、`ui/popup_crystal.gd` | 原生 PopupMenu 背后阅读材质、金丝及高度限制，保留原生条目选择与滚动 |
| `ui/scenes/page_shell.tscn`、`practice_page.tscn` | 共用浮层的固定头尾、滚动正文和柔焦层；习字采用继承场景，词库列表与练习词条仍动态填充 |
| `ui/scenes/battle_page.tscn`、`battle_world.tscn`、`battle_word.tscn` | 战场组合、HUD 锚点／偏移、危险层、世界折射层与无底板词条；词条以字形细衬保证辨识，实时值和防重叠布局由脚本更新 |
| `ui/scenes/battle_actor_visual.tscn`、`battle_projectile_visual.tscn`、`battle_spirit_visual.tscn` | 角色、投射物与纸灵的 Sprite、形状、尾迹、粒子和材质模板；各实例独立更新受击与施法状态，轨迹服从固定步规则 |
| `game/input/` | InputRouter 上下文归属、TypingSession 词进度、唯一 ManualInputReceipt；下个固定步 drain 一次领取 |
| `game/vocabulary/` | 具名词条与导入报告、五类外部格式解析、严格选词、用户词表原子保存 |
| `game/persistence/app_settings.gd` | ConfigFile 设置与备份恢复，分辨率预设、自动输出、窗口／全屏及音量应用 |
| `ui/game_display.gd` | 1920×1080 设计坐标与实际输出分离，统一游戏像素预算、独立界面缩放和高分辨率字体采样 |
| `ui/page_shell.gd`、`open_button.gd` | 固定标题／操作、内部滚动、开放按钮柔光、词令使用辅助字体；普通控件无默认焦点和 Tooltip |
| `ui/command_tag.gd`、`ui/key_hint.gd`、`ui/scenes/key_hint.tscn` | 可见词令标签与具名按键标记；词令操作调用同一个真实控件，文本编辑和滑条调整有独立输入归属 |
| `ui/smooth_scroll.gd` | 桌面滚轮连续目标与浮点收敛；滚动条拖动立即接管，减少动态直接定位 |
| `ui/viewport_output.gd` | 编辑器与运行时都按输出节点的相对路径取得 HDR 视口纹理，避免嵌套场景的局部纹理路径失效 |
| `ui/archive_stage.gd`、`archive_theme.gd` | 场景独立 HDR 合成、WorldEnvironment 柔光与全幅选书折射；原生文字不受模糊；共享 Theme 实例随当前 accent 渐变。减少动态按需刷新一帧并在渲染后停更 |
| `ui/guide_content.gd` | 输入、防御、道具、远征、成长和连续挑战说明，四条直观遗物示例与词输入练习入口 |
| `ui/practice_page.gd` | 实际词会话、三词选择、渐进词长、本次人工字符／错字统计；不发成长收入 |
| `game/build/`、`game/content/build/` | 4 书和 58 件遗物定义、构筑快照、叠层、局内多前置、逐份资产与使用身份；旧字段只供已存档数据解析 |
| `game/progression/`、`game/persistence/save_repository.gd` | 自动线性成长、普通／God 隔离、正式获取、经验事实、奖励与保存成功后发布的事务；旧版本首次迁移保留独立原档副本 |
| `game/session/run_session.gd`、`run_state_codec.gd` | 九房流程、简单路线、保存边界、跨房遗物周期、去重结算、通关保留遗物升档及最高档周目 |
| `RunSession.suspend_battle`、`restart`、`isolate_to_god` | 单份活动存档、窗口关闭保存、房间级恢复、重开原子归档；隐藏 God 接管先保护普通档锁，再写隔离档，失败可重试且不重复成长 |
| `ui/journey_emblem.gd`、`app/main.gd` 的行间／留痕／记录 | 原生线绘路线选择、五阶成长进度、固定列表及历史构筑详情；构筑与记录统计正式遗物实例 |
| `ui/content_description.gd`、`app/main.gd` 的图鉴页面 | 58 件遗物的固定列表与详情、检索、层数和当前获取条件；奖励与图鉴共用描述和图形 |
| `ui/relic_reward_choice.gd`、`ui/materials/relic_choice.gdshader` | 三件遗物并排展示共用图形、名称与简述，独立详情阻止背景领取；羽化透光材质、图案点击与正式获取事务 |
| `game/session/battle_session.gd`、`game/session/run_combat_state.gd`、`game/spells/spell_runtime.gd` | 唯一固定步、四书独立产出、接触与有限派生、遗物周期、道具词咒、防御、一次结果与跨房交接 |
| `game/combat/damage_packet.gd`、`game/content/element_trait.gd` | 五类伤害组成、确定分割与实际抗性结算 |
| `development/build_lab.tscn`、`build_lab.gd`、`build_lab_scenarios.gd` | 完整目录、编译诊断、十类遭遇、正式输入及战斗链、有效结果与来源检查、安全更新；独立开发配置 |
| `ui/battle_rule_visuals.gd`、`ui/spell_field_visual.gd` | 按 effect.kind 区分冰面、火场与引力区域，粒子和局部光照随类型匹配，到期淡出释放；低画质与减少动态保留范围识别 |
| `ui/battle_threat_overlay.gd`、`ui/battle_visuals.gd` | 敌弹光核、插值相连的曳光与近身流体尾迹；完美御术／反制／爆墨接独立粒子、亮核、光扫及辅助薄雾 |
| `game/combat/combat_geometry.gd` | 设计像素空间的相对运动圆扫掠、首次接触时刻与表面接触点；投射物、纸刃、敌弹和实体分离共用 |
| `game/content/battle_encounter.gd`、`encounters/`、`s2_itinerary.tres` | 三章九房只读定义、各章敌人组合、分批波次与 Boss；物理章节、五档压力与后续周目分别计算 |
| `ui/battle_page.gd`、`battle_stage.gd`、`battle_visuals.gd`、`battle_projectile_visual.gd` | 1920×1080 战场等比映射与统一输出像素密度的 HDR 层；超宽屏 HUD 随战场居中；无按钮焦点的词目标、强化周期与防御 HUD；原生粒子、晶片／折纸、热扰动与有界位移波，暂停返回时应用画质与减少动态 |
| `ui/battle_actor_visual.gd`、`assets/art/actors/` | 玩家、17 类普通敌人及 3 Boss 的独立矢量轮廓、元素染色、受击、冻结／灼烧与死亡溶解 |
| `ui/archive_home.gd`、`archive_gate.gd` | 原四书轨道书库、入场仪式、中央向外展开的出征书页；固定法阵骨架、四封印权重交接、可中断主题色与连续悬浮状态 |
| `ui/archive_effects.gd`、`startup_sigil.gd`、`archive_cursor.gd` | 双仪式平面、原矢量法印和指针交互 |
| `ui/effects/` | 可复用 GPUParticles2D 尘埃场景、寿命／纹理渐变、独立实例材质；AnimationPlayer 入场时序资源 |
| `ui/effects/motion_trail.gd`、`damped_motion.gd` | 插值头尾衔接、弧长裁剪与向心 Catmull–Rom 尾迹；解析临界阻尼回弹供角色与镜头共用，不持有战斗规则状态 |
| `ui/materials/soft_shapes.gdshaderinc` | 共用高斯柔光、像素足迹补偿的细线与导数抗锯齿轮廓；纸灵、火焰、尾迹、御术和按钮使用同一基础函数 |
| `ui/motion_curve.gd` | 按时间求解 cubic-bezier，供选书轨道与中央向外展开使用 |
| `game/content/books/`、`assets/art/` | 四书展示 Resource 与原 PNG／SVG 资产，未存战斗状态 |
| `ui/materials/` | 无缝噪声纸面、稳定法阵、mipmaps 与九点透明边缘景深、环绕微光、地面与光束、独立 HDR SubViewport 径向折射、连续细线柔光；尊重减少动态与父级淡出 |
| `ui/theme/keyabyss.tres` | 两套字体、文字层级、开放控件基础皮肤，运行时按法书元素色派生 |
| `assets/fonts/` | 汇文明朝体、京華老宋体 v3.0 的 TTF 与导入配置 |
| `audio/default_bus_layout.tres`、`archive_audio.gd` | 六条总线、18类菜单反馈、16声部限流、切书即时交叉淡出、四秒合成氛围循环 |
| `audio/cues.json`、`sound_bank.gd`、`assets/audio/clips/`、`assets/audio/cues/` | 56类反馈、49个库组、196个原样WAV；Godot四变体随机池，不连续重复 |
| `tools/audio/build-game-audio.mjs`、`assets/audio/selection.json` | 从Agent库复制选用文件，生成池与内容哈希；不依赖旧FLAC／JS |
| `audio/battle_audio.gd` | 38类战斗反馈、真实提交与输入判定、14声部上限与重要反馈优先，威胁独立总线 |
| `assets/vocabulary/` | 12 本生成 JSON、来源与 SHA256 索引；运行时不访问 legacy |
| `export_presets.cfg` | Windows x86_64 活动资源导出，显式包含词库 JSON，排除开发场景、测试与工具桥 |
| `tools/godot/godot.ps1` | 引擎版本核对、导入、运行、编辑器、生成预览、Debug／Release 导出 |
| `tools/godot/toolchain.json` | 精确引擎与 MCP 提交锁、活动资源目录 |
| `tools/godot/mcp-smoke.mjs` | 可复用的本机 MCP 协议和窗口集成检查 |
| `tools/godot/import-vocabulary.mjs` | 从冻结旧 JSON 生成活动词库快照和哈希，不手工双维护 |
| `tests/godot/` | 词库、输入／设置、单房规则及原生应用窗口的针对性回归入口 |
| `.agents/skills/` | 原生开发、视觉、工具三类项目指引 |
| `legacy/web/` | 完整旧实现、工具、素材及既有改动；被 Godot 扫描排除 |

MCP 运行在 `.temp/godot-mcp/project` 生成副本；根工程是唯一活动代码源。副本不用于编辑和导出，刷新前停止占用 9090 的实例。工具安装与边界见[工具链](migration/TOOLCHAIN.md)。

在 Godot 编辑器中从 `app/main.tscn` 查看应用组合，打开 `ui/scenes/battle_page.tscn` 调整 HUD 的锚点和偏移，打开对应实体场景调整固定图形、尾迹、粒子与材质。页面和组件需要由应用注入会话或设置，独立运行游戏使用主场景。首页轨道、出征展开、战斗轨迹和词条避让仍由脚本控制；这些节点的运行时位置不以编辑器初始偏移为最终值。敌人和法术规则状态继续由 `BattleSession` 持有，没有另建节点物理权威。

碰撞先推进敌人移动并处理实体接触，再处理已付弹道与敌人攻击。`CombatGeometry.sweep_discs()` 接受两圆本步起止像素位置及半径和，返回 `[0,1]` 的首次接触时刻，无接触返回 `INF`；弹道候选按此时间排序，同一时刻按目标 ID 排序。命中事件的 `at` 仍是敌人中心，另以 `contact` 和 `direction` 驱动接触光效与受击回弹。碰撞分离采用质量加权冲量和四次位置约束投影，低速接触不回弹，高速冲击保留少量恢复；适用于当前小规模单房，不是通用刚体引擎。

`MotionTrail.build()` 接受从旧到新的物理采样、最新物理头和插值显示头，先替换未来采样，再按弧长裁剪；纸灵选择向心 Catmull–Rom，短直弹道保留折线。它只生成显示点，不更改飞行或命中轨迹。`DampedMotion` 以解析临界阻尼返回原点；角色普通／强化受击上限为 3／5 设计像素，镜头普通／防御上限为 1.7／5 像素，减少动态时归零。

`soft_shapes.gdshaderinc` 的距离与宽度使用调用方同一坐标空间，细线函数按 `fwidth` 扩展到像素足迹并补偿亮度，轮廓函数提供导数抗锯齿。元素颜色、发光预算和画质分级仍由各材质负责，共用函数不增加纹理采样或粒子数量。

敌人从八向来袭扇区内的外围冷区分散进入，词咒与目标登记在进入有效战场后出现；有效锁定意图由固定步写入 `BattleEnemy.combat_locked`，`BattleSession.enemy_in_combat()` 保留被击退敌人的交战资格至死亡。三波数量、伤害和经济不因此改变。精灵、词咒、危险层和震屏输出只使用手动插值，词咒不再在物理回调中定位；页面晚于世界层处理，读取本帧相机偏移。固定步继续持有实际位置与碰撞。

`ui/scenes/battle_word.tscn` 以 `BattleWord` 组织英文、可选中文及 `word_reading.gdshader` 羽化阅读层，实际测量完整词咒并限制释义为两行，处理选中游标与色阶。`BattlePage` 统一词条时序、透明度、层级、边缘与 HUD 避让。设置键 `show_meaning` 保留存储兼容，含义为头顶中文释义，词令为 `translation`；底部施法释义不受该开关控制。

按钮以 `caption_alignment` 保存场景对齐意图，其缓存同样使用 `HorizontalAlignment` 类型，词令与标题作为一组测量。文字按钮、开关、下拉和词令输入框共用 `GoldFilaments`：按词令的稳定种子生成贝塞尔主脉与短淡分枝，以共同根部弧长驱动 `gold_filament.gdshader` 的柔和亮带；相同尺寸与种子不重复生成网格。各控件流光速度与相位错开，悬停与操作增强局部受光而不重置传播节奏，减少动态关闭流动。`CrystalInlay` 在曲线之上绘制晶面，使用同一主脉控制点决定坡度，晶面柔光也按独立相位缓慢流转；控件不采样重复 SVG，Theme 不绘制硬直底边。页面装饰继续使用“流柳”“流脉”“羽脉”“回蔓”原图。页面 `open_wash.gdshader` 根据实际阅读区域生成开放曲面，保留压暗和柔焦，两侧独立移动的受光驱动局部折射与透光；正文独立清晰。资源预设按实例复制后写入状态，使用约定见 [UI 材质](../ui/materials/README.md)。施法区使用独立细线进度材质与按键提示，已输入字符用暖橙强调。

正式设置写入 `user://settings.cfg`（备份 `.bak`），自定义库写入 `user://vocabulary/`。普通／God档案分别保存在 `user://profiles/normal/profile.json` 和 `user://profiles/god/profile.json`，包含四书配置、有效人工字符、结算回执、记录与本局检查点；原子保存使用临时文件验证和有效备份。房间之间恢复同一报价，房内异常退出按最后已保存事实结束本局。预览目录名为 `Keyabyss-M1-Preview`；检查为设置、词库和档案注入独立证据路径。新游戏不接旧浏览器存档。

设置提供自动及 17 个桌面分辨率预设，覆盖 720p、1366×768、1080p、1440p、4K、16:10、4:3、5:4、21:9 和 32:9。窗口模式按所选尺寸调整客户区，超过当前显示器可用区域时等比缩小；自动模式跟随实际窗口或全屏尺寸。全屏模式用所选分辨率渲染整幅画面，保持比例居中，不修改操作系统显示模式。窗口手动调整后，修改声音等无关选项不重置窗口大小；往返全屏恢复原窗口尺寸。

运行时根 Window 使用 Viewport 缩放、KEEP 比例和固定 `content_scale_factor = 1`；`GameDisplay` 以 `min(output / design) × ui_scale` 缩放逻辑界面，额外宽高留给场景布局。85%–125% 界面缩放不改变输出缓冲尺寸，字体按显示倍率提高采样。首页、入场、战场的 HDR 层与正文共用所选输出密度；超宽屏书库和 HUD 限于中央内容区，背景延展。战场坐标、碰撞和战斗计时不随分辨率改变；暂停缩放保留已测量词条宽度。

音量实时预听，拖动结束或 350ms 防抖后保存；恢复默认批量更新并显式保存一次。页面重排同步装饰位置，静态按钮与入场背景按变化更新。具体取舍及曾出现的问题见 [UI 迁移实践](migration/UI-IMPLEMENTATION-LESSONS.md)。

旧 TypeScript 的主要模块、资源约束、素材和音频工具见[迁移前快照](archive/pre-godot/TECHNICAL-SNAPSHOT.md)，其中代码路径现在统一加 `legacy/web/`。详细目标映射见[代码与数据映射](migration/DATA-AND-ASSETS.md)。
