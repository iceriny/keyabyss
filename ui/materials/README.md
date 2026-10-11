# UI 材质

## 启动背景细尘

加载完成时由 `ArchiveGate.reveal_from_loading` 将实际 `RitualBackdrop` 节点接入欢迎视口，保留 `clock`；`formation` 从 0 到 1 插值装饰位置、透明度和尘埃浓度。加载 CanvasLayer 的输出像素坐标必须转换为 GameDisplay 下的 Stage 逻辑坐标，再交接符文与文字的位置、缩放；验证需包含实际 GameDisplay 父节点和非 1080p 输出。不要重新创建背景、重置噪声相位或将整个不透明背景一起淡出。交接期间只启用欢迎层的处理，等待 `welcome_ready` 后再恢复应用输入。

`ritual_atmosphere.gdshader` 采样 `assets/art/effects/ritual_dust.png` 的线性密度。纹理由 `python tools/art/bake_ritual_dust.py` 确定性重建：独立散点与宽幅弯曲随机点云叠加，实际点数和间距形成疏密，周期边界支持重复采样；导入需保留 mipmaps。不要恢复为每格一个点再用遮罩调亮度，也不要将宽云拆成重复的细碎小团。两层点云坐标以不同相位平移、弯曲，受光区域独立缓慢漂移；共用 `clock`，减少动态时保持静止。`test_feedback_presentation.gd -- --ritual-boundary --dust-motion` 可输出像素尺度局部连续帧。

## 金丝与水晶阅读层

| 资源 | 用途 | 接入方式 |
| --- | --- | --- |
| `gold_inlay.tres` / `gold_inlay.gdshader` | 晶面折射、透射光和装饰 SVG 的嵌入效果 | 使用 `crystal_inlay.tscn`；控件通过 `CrystalInlay.decorate()` 接入 |
| `gold_filaments.gd` / `gold_filament.gdshader` | 控件的程序化分枝金丝与沿路径传播的亮点 | `CrystalInlay` 和 `OpenButton` 共用曲线生成器；无需纹理 |
| `crystal_reading.tres` / `open_wash.gdshader` | 全屏阅读遮罩，柔焦与压暗 | 遮罩之前放一次 `BackBufferCopy`，其后绘制晶片、金丝、正文与控件 |
| `crystal_sheets.gd` / `crystal_sheet.tres` | 阅读区外侧的交错薄晶片、局部金丝流光与折射 | `page_shell.tscn` 共用；六片合并为一个网格，复用阅读遮罩之前的捕获；正式场景引用由渲染准备自动收集 |
| `popup_depth.tres` / `popup_depth.gdshader` | 下拉与术语提示的灰青透光、消隐边缘及底部弧形金丝 | `popup_crystal.tscn` 与 `term_tooltip.tscn` 共用；PopupMenu 继承主视口 HDR，材质由既有 popup 渲染准备入口收集 |
| `open_button_light.gdshader` | 操作响应的柔光与文字背光 | 由 `OpenButton` 管理边距、文字中心和活动强度；金丝由独立网格绘制 |

金丝保留 SVG 的颜色、透明度与抗锯齿覆盖，作为晶面内的纹样采样。弯曲晶面的坡度同时驱动背景折射和金丝位移；埋入较深的部分降低对比并柔化，局部掠光照亮路径，冷色表面反光与暖色透射光分别合成。这是适合 2D UI 的光学近似，不是三维光线追踪。

`control_surface` 下不采样 SVG。`GoldFilaments` 用独立随机数实例和词令的稳定散列生成三次贝塞尔主脉、1–3 条相切起步的分枝；同尺寸控件也有不同弧度、分枝位置和长短。只在布局或文字组尺寸改变时重建带状网格，尺寸保持时不重建。UV 存储从共同根部累计的弧长和横向像素距离，shader 按距离推进亮点与尾光，分枝继承接点距离，因此光抵达接点后自然分流。

开关、下拉和输入框的曲线位于晶面下；晶面的坡度读取同一主脉控制点。文字按钮共用曲线生成器，背光单独绘制。分枝长度为主脉的 10–17%，上限 36 像素，强度为主脉的 20–32%。细芯按像素导数抗锯齿，末端衰减，无逐像素曲线搜索或每帧生成纹理。宽而柔和的流光按词令错开相位，以每秒 12–19 设计像素缓慢移动；悬停／操作平滑增加受光，保留原有节奏。

原 Theme 不提供硬直底边或矩形底色。控件通过原生悬停、切换及输入信号驱动 `activity` / `pulse`；材质节点忽略鼠标，不改变输入所有权。减少动态关闭沿路径流光，保留静态细芯和即时悬停响应。

`backdrop_gain` 指定折射景物的透过比例：共用阅读页使用 0.06，与其压暗背景匹配；书库控件使用 0.45。局部晶面使用同一已捕获场景，不逐控件创建屏幕副本。文字在材质之后绘制，不参与背景采样和折射。原 SVG 保留在标题、页脚和出征两翼；交互控件没有重复铺设底纹 SVG。

阅读遮罩的 `shade` 是外围场景透过比例，`transmission` 是阅读中心透过比例；`blur_lod` 控制屏幕柔焦层级，`field_center` / `field_scale` 定义连续的透光区域。HDR 屏幕样本为线性空间，染色参数标注 `source_color`。遮罩用于全屏页面，不直接作为小矩形底板：其外侧压暗也属于整页构图。

`CrystalSheets.arrange()` 根据实际阅读区生成六片错开的收尖曲面；短弹层减小弯曲幅度，宽页面按侧边余量收窄。只在布局变化时重建一个 ArrayMesh。Curve2D 按烘焙弧长取样，UV.x 储存设计像素距离，流光以14像素／秒前进；UV.y 横跨两个折面，逐三角面几何法线编码进顶点色。形状与法线基底固定，只有小幅法线倾斜、非对称光头与反射随时钟变化。`strength` 调反光，`refraction_pixels` / `dispersion_pixels` 分别控制折射与微弱色散，并按画布缩放换算到输出像素；减少动态固定时钟。预乘透明合成保留下层反光，不递归折射其他晶片；正文在最后绘制。`surface_light` 仍控制控件局部镶嵌晶面的反光。

设计参考用户提供的 `F:/Workshop/game/crystal-flow-kit`（`docs/ALGORITHMS.md`、`shared/crystal_math.glsl`）：保留稳定晶面、弧长流光与局部反射思路，按项目布局重建原生网格，不依赖 Demo 的图集、字体或运行时。引擎行为参考 [Curve2D](https://docs.godotengine.org/en/stable/classes/class_curve2d.html) 与 [屏幕采样](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html)。

`OpenButton.filament_extension` 控制金丝主脉在文字组两侧的延伸，不改变按钮的输入区域。准备出征使用每侧 44 像素的延伸。

`.tres` 是预设；`CrystalInlay` 和 `PageShell` 实例化独立材质后写入光心、时钟与交互强度，不修改共享资源。隐藏的镶嵌节点停止处理；减少动态将流光时钟固定为零，保留静态材质和即时悬停反馈。

共用页面标题使用“流柳”、页脚使用“流脉”，出征两翼使用“羽脉”和“回蔓”；位置在 `page_shell.gd` 与 `archive_home.tscn`，其余纹样保留在 `assets/art/ui/goldwork/`，按实际版面选择。

`ultimate_field.gdshader` 以固定步的中心、半径、年龄和寿命控制冰裂、焰域、雷暴弧与折纸光片；必须放在 `BattleWorld/Fields`，负 z 层会落到不透明背景后面。领域只负责表现，不能据其片元形状推导伤害。`ultimate_indicator.gdshader` 只平滑显示共鸣或剩余比例，不修改触发阈值；减少动态冻结光学时钟。
