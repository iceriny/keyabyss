# 当前实现快照

根工程现在使用 Godot。以下描述实际文件，不把[迁移方案](migration/PLAN.md)中的目标模块写成已经实现。整体状态见[阶段总结](STAGE-SUMMARY.md)。

共用页面通过 `BodyRegion` 保持标题下方的固定留白，`ContentMargin` 将正文与滚动条隔开，嵌套词库列表继续填充剩余高度；按钮左右内容边距统一为 12 个设计像素。

设置使用固定的显示／效果／声音／玩法标签；`fluid_quality` 独立保存关闭／低／中／高／极高，开启档均逐帧更新。`FluidField2D` 和 `fluid_solver.glsl` 在主渲染设备求解速度与独立高分辨率雾场，输送密度、有符号温度、颜色、年龄，压力使用 R32F。`FluidBody2D` 默认通过动量推雾，硬障碍另行选择。`FluidMotionPath` 保留连续扫掠与折点，`FluidAtmosphere` 接首页书体与战场事件，`FluidMedium` 配置物质，`FluidEffectProfile`／`FluidEmitter2D` 组合力、注入、粒子与共享原生光源。闪避沿途补雾、雷电路径光、冰火尾迹、出征淡出均已接入；粒子通过 `FluidParticleFlow` 读取相同速度。质量切换保留外层纹理 RID，关闭流体保留场景照明。接口、预设与近似边界见[流体视觉工具](FLUID-EFFECTS.md)。

主画布和首页／入场／战斗 HDR 视口使用 4× 2D MSAA，并关闭 Control 整像素吸附。细线 shader 以连续距离的像素足迹过滤，四书符阵以 2 倍导入尺寸和 mipmaps 处理缩小采样，拖尾在保持光学宽度的同时留出抗锯齿边缘。复核记录见 `.temp/effect-sampling/review.md`。

| 入口 | 当前职责 |
| --- | --- |
| `project.godot` | 4.7 特性、主场景、Forward+、HDR 2D、1920×1080 默认窗口与设计尺寸、60 Hz、用户目录 |
| `app/main.tscn`、`main.gd` | 主场景直接包含首页实例、输入路由、音频、设置保存计时器和指针；脚本负责服务注入、页面切换、设置／词库／导入、暂停与胜败入口 |
| `app/frame_capture.gd` | 仅显式传入 `--frame-profile` 时加载；逐帧间隔、物理与视口 CPU／GPU 记录，默认持续到正常退出，一次写入 `user://performance/`；自动化可显式指定时长 |
| `ui/scenes/archive_stage.tscn`、`battle_stage.tscn` | 首页与战场的可编辑 HDR 视口、WorldEnvironment、背景和输出层；场景材质各实例独立。首页隐藏时停止节点处理与离屏绘制 |
| `ui/scenes/archive_home.tscn`、`archive_book_visual.tscn`、`archive_effects.tscn` | 首页固定标题、菜单、出征两翼、法阵／光束／尘埃及法书视图模板；书本内容、选书轨道和展开动画由脚本驱动 |
| `ui/scenes/archive_gate.tscn` | 入场仪式的 HDR 视口、双法印、文字、粒子、输出材质与 AnimationPlayer，引用既有唤醒时间线 |
| `ui/scenes/departure_ritual.tscn` | 出征遮幕与战场交接；场景发出 covered／completed，应用在揭幕后才开放输入和固定步 |
| `ui/scenes/pause_content.tscn`、`battle_result.tscn`、`stat_readout.tscn` | 原生暂停分组、战报与状态读数，缺失内容保留骨架；复用 PageShell 的固定头尾 |
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
| `ui/guide_content.gd` | 原指南十节两栏说明、十四条构筑札记和词输入练习入口；装饰按 theme_changed 跟随渐变，正文保留原色；尚无演示战斗 |
| `ui/practice_page.gd` | 实际词会话、三词选择、渐进词长、本次人工字符／错字统计；不发成长收入 |
| `game/build/`、`game/content/build/` | 377 份原生定义、封闭规则与单位契约、构筑编译、稳定快照、逐份资产及使用身份、资产变更和临时覆盖接口；正式成长与交易仍待 M4 |
| `game/session/battle_session.gd`、`game/session/run_combat_state.gd`、`game/spells/spell_runtime.gd` | 唯一固定步、真实接触与全来源有限规则；来源账、保存、持续、路径、运输、词形、回收、一次结果与跨房交接 |
| `game/combat/damage_packet.gd`、`game/content/element_trait.gd` | 五类组成、确定分割、实际抗性结算、R172 冻结转换与固定敌人特征 |
| `development/build_lab.tscn`、`build_lab.gd`、`build_lab_scenarios.gd` | 完整目录、编译诊断、十类遭遇、正式输入及战斗链、有效结果与来源检查、安全更新；独立开发配置 |
| `ui/battle_rule_visuals.gd` | 原生已付外壳、有限区域、运输与中继、字母兑现轨迹；战斗页面显示抗性、护盾和位置标记 |
| `game/combat/combat_geometry.gd` | 设计像素空间的相对运动圆扫掠、首次接触时刻与表面接触点；投射物、纸刃、敌弹和实体分离共用 |
| `game/content/battle_encounter.gd`、`single_room.tres` | 三波九敌的只读单房定义、八方向扇区与矩形外围入场投影；方向由会话种子决定，波次与间歇由 BattleSession 推进 |
| `ui/battle_page.gd`、`battle_stage.gd`、`battle_visuals.gd`、`battle_projectile_visual.gd` | 1920×1080 战场等比映射与统一输出像素密度的 HDR 层；超宽屏 HUD 随战场居中；无按钮焦点的词目标、强化周期与防御 HUD；原生粒子、晶片／折纸、热扰动与有界位移波，暂停返回时应用画质与减少动态 |
| `ui/battle_actor_visual.gd`、`assets/art/actors/` | 玩家与三类敌人的矢量轮廓、披风／护甲折面、元素染色、受击、冻结／灼烧与死亡溶解 |
| `ui/archive_home.gd`、`archive_gate.gd` | 原四书轨道书库、入场仪式、中央向外展开的出征书页；固定法阵骨架、四封印权重交接、可中断主题色与连续悬浮状态 |
| `ui/archive_effects.gd`、`startup_sigil.gd`、`archive_cursor.gd` | 双仪式平面、原矢量法印和指针交互 |
| `ui/effects/` | 可复用 GPUParticles2D 尘埃场景、寿命／纹理渐变、独立实例材质；AnimationPlayer 入场时序资源 |
| `ui/effects/motion_trail.gd`、`damped_motion.gd` | 插值头尾衔接、弧长裁剪与向心 Catmull–Rom 尾迹；解析临界阻尼回弹供角色与镜头共用，不持有战斗规则状态 |
| `ui/materials/soft_shapes.gdshaderinc` | 共用高斯柔光、像素足迹补偿的细线与导数抗锯齿轮廓；纸灵、火焰、尾迹、弹反和按钮使用同一基础函数 |
| `ui/motion_curve.gd` | 按时间求解 cubic-bezier，供选书轨道与中央向外展开使用 |
| `game/content/books/`、`assets/art/` | 四书展示 Resource 与原 PNG／SVG 资产，未存战斗状态 |
| `ui/materials/` | 无缝噪声纸面、稳定法阵、mipmaps 与九点透明边缘景深、环绕微光、地面与光束、独立 HDR SubViewport 径向折射、连续细线柔光；尊重减少动态与父级淡出 |
| `ui/theme/keyabyss.tres` | 两套字体、文字层级、开放控件基础皮肤，运行时按法书元素色派生 |
| `assets/fonts/` | 汇文明朝体、京華老宋体 v3.0 的 TTF 与导入配置 |
| `audio/default_bus_layout.tres`、`archive_audio.gd` | 六条总线、原 UI 片段播放／并发限流、切书即时交叉淡出、原四秒氛围循环 |
| `assets/audio/ui/`、`tools/godot/import-ui-audio.mjs` | 12 cue / 27 WAV，从原 Web FLAC 封装解码生成，清除无效编码元数据 |
| `audio/battle_audio.gd`、`assets/audio/battle/`、`tools/godot/import-battle-audio.mjs` | 24 类原生战斗音源、事件触发、14 声部上限与重要反馈优先，威胁独立总线 |
| `assets/vocabulary/` | 12 本生成 JSON、来源与 SHA256 索引；运行时不访问 legacy |
| `export_presets.cfg` | Windows x86_64 活动资源 Debug 导出，显式包含词库 JSON，排除测试与工具桥 |
| `tools/godot/godot.ps1` | 引擎版本核对、导入、运行、编辑器、生成预览、导出 |
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

正式设置写入 `user://settings.cfg`（备份 `.bak`），自定义库写入 `user://vocabulary/`。预览目录名为 `Keyabyss-M1-Preview`；测试为设置与词库注入独立证据路径。普通／God 进度属于 M4，尚未实现；新游戏不接旧浏览器存档。

设置提供自动及 17 个桌面分辨率预设，覆盖 720p、1366×768、1080p、1440p、4K、16:10、4:3、5:4、21:9 和 32:9。窗口模式按所选尺寸调整客户区，超过当前显示器可用区域时等比缩小；自动模式跟随实际窗口或全屏尺寸。全屏模式用所选分辨率渲染整幅画面，保持比例居中，不修改操作系统显示模式。窗口手动调整后，修改声音等无关选项不重置窗口大小；往返全屏恢复原窗口尺寸。

运行时根 Window 使用 Viewport 缩放、KEEP 比例和固定 `content_scale_factor = 1`；`GameDisplay` 以 `min(output / design) × ui_scale` 缩放逻辑界面，额外宽高留给场景布局。85%–125% 界面缩放不改变输出缓冲尺寸，字体按显示倍率提高采样。首页、入场、战场的 HDR 层与正文共用所选输出密度；超宽屏书库和 HUD 限于中央内容区，背景延展。战场坐标、碰撞和战斗计时不随分辨率改变；暂停缩放保留已测量词条宽度。

音量实时预听，拖动结束或 350ms 防抖后保存；恢复默认批量更新并显式保存一次。页面重排同步装饰位置，静态按钮与入场背景按变化更新。具体取舍及曾出现的问题见 [UI 迁移实践](migration/UI-IMPLEMENTATION-LESSONS.md)。

旧 TypeScript 的主要模块、资源约束、素材和音频工具见[迁移前快照](archive/pre-godot/TECHNICAL-SNAPSHOT.md)，其中代码路径现在统一加 `legacy/web/`。详细目标映射见[代码与数据映射](migration/DATA-AND-ASSETS.md)。
