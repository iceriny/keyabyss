# 元素材质早期实验归档

这是实时冰火接入前的历史记录。当前接线与验证见 `docs/art/ELEMENT-EFFECTS.md`；下面的旧素材路径、待办及测量不再代表当前工程。

2026-10-08。运行效果使用原生 Godot 材质、GPU 粒子和局部光照；战斗规则、范围和付费生命周期仍由战斗会话持有。

## 当前实验与收尾交接

后续独立研究已恢复：用户要求冰火置于同一垂直俯视空间，并否定继续使用旧冰晶图片。当前小样在 `development/element_lab/`，以实时六邻域扩散／冻结／附着生成冰晶，以共享平面流体输运燃料／温度生成火焰。两者共用场景与照明，关闭屏幕向上浮力。入口、机制与当前实测见[小样说明](../../../development/element_lab/README.md)。正式战斗与此前发行包没有接入小样；下面保留此前正式运行路径的实验交接。

2026-10-08 用户要求先收尾，视觉调整暂停，等待其研究后的方向。以下为保留的源码状态，不表示审美验收或发行完成。后文的旧截图、成本与单张密集霜晶方案属于此前迭代。

- 冰晶：`assets/art/effects/frost-branches.png` 为 1280×1280 透明四变体图集，选用弯曲主干、Y 形分叉、稀疏扇簇及长矛形分支。`frost-arrival.png` 为 512×512 单通道到达图，`tools/art/bake_crystal_arrival.py` 按 alpha 连通代价从各晶簇根部求最短路径，沿主干向侧枝显露；这是离线美术动画数据，不是实时物理结晶。生成图本体与 alpha 未做脚本修改。四处接线为 `battle_visuals.gd`、`battle_actor_visual.gd`、`spell_field_visual.gd`、`ultimate_field.gd`，共用 `frost_texture.gdshaderinc`。
- 闪电：`ui/lightning_arc.gd` 使用随机中点细分、粗细分支与有限次数重击；窄网格上计算线段距离和 HDR 电晕。长度通过顶点 alpha 传入，避免颜色空间转换造成亮点断开。`spell_link.gdshader` 的旧电分支尚留文件中，但电击运行路径已经提前转入 `LightningArc`。
- 气体：`fluid_fog.gdshader` 用预乘 alpha 保留烟的覆盖与独立发光。火场发光较强，寒雾保持低发光冷色；爆墨／反制先一次性注入四个扰动团块，再施加短时膨胀。`fluid_solver.glsl` 在投影后施加膨胀速度，输运时同步稀释密度、颜色与发光量，未增加求解网格或 dispatch。最后把冲击核改为原点附近线性，避免径向速度奇异。

最近整组实拍在 `.temp/element-vfx-20261008/effects-3660777/`，`crystal-effects.log` 为四书检查 16 项、0 失败。该组爆墨仍表现为平滑亮块，不能算视觉问题已解决。最后膨胀核调整后，`expansion-import.log` 完成导入；`branch-materials.log` 流体材质回归 0 失败，气团二阶展宽从 18.784 到 774.108，中心密度 0.181、发光量 0.792。没有继续对最终核实拍或采样性能；此前低画质结果与 GPU 数值不自动适用于本实验。Windows Release 未重导，玩家数据未改，Git 未提交。

素材原件位于本机 `C:/Users/misss/.codex/generated_images/01a119c9-bec8-7b32-9ac4-8a19da0e74d5/`：首稿 `exec-92d7b346-1e51-4c5b-9c32-78d3f1875983.png`，选用稿 `exec-d964bf3e-e181-4b1e-bf7a-3d0cd70e5463.png`。首稿工作区副本和对应到达图已移入 `.delete/element-vfx-20261008/crystal-candidates/`；旧 `frost-crystals.png` 仍保留供后续研究，不再由当前冰晶材质引用。日志、截图与离线研究结果作为接续证据保留。

选用稿生成提示词（内置 imagegen，透明背景）：

> Production VFX atlas for a dark fantasy ice spell: square transparent PNG, exact 2x2 grid of four very DIFFERENT sparse crystalline growth formations, no visible grid. Four isolated sprites with wide transparent gutters, all crystal roots near the LOWER LEFT of their quadrant, growth proceeds towards UPPER RIGHT. Top left: an angular crooked ice spine with only 3 long lateral icicle needles. Top right: a wide bifurcating Y-shaped ice growth, two main prismatic tips, unequal secondary spurs. Bottom left: three main tapered hexagonal spears spreading into a loose fan from one root, sparse and asymmetric. Bottom right: one narrow long crooked ice lance with small alternating side crystals of very unequal lengths. True translucent water ice with glassy blue refraction, several broad clean facets, white silver specular ridges, slightly frosted edges. Clearly visible 3D thickness but viewed from straight above as a sprite. Strong hierarchy: big main axis, several thinner side axes, empty space, NOT dense microfilaments. Real crystalline fracture surfaces, not metal, not diamonds, not feathers, not leaf shapes, not snowflake symbols. Each silhouette dramatically different from the others. Only 15-25% occupied area per cell, no background, no glow or shadow or mist, no text, no labels, no border. Designed to retain readable ice facets at 200 pixels per sprite. Natural slight crookedness and competing branches, never perfectly symmetric. Fully preserve clean transparent gaps between branches and generous padding around each silhouette.

## 形态、材质与运动

冰晶细节来自透明霜晶贴图，区域、命中、冻结敌人与寒墨终式共用识别语言。材质按非均匀阈值逐渐显露，场内各次释放使用不同朝向；驻留时晶体稳定，退场淡出。它是受控的材质动画，不是运行时水分子或冰晶生长模拟。透明间隙、粗细不均的晶片、微小霜粒和明暗折面来自原始贴图；程序不再画等距排线和规则多边形裂纹。

火焰、爆墨和反制的烟气由既有共享流体产生：短促多源注入形成初始团块，动量与涡流负责后续卷动；持续火场和终式从真实战斗生命周期读取范围与退场时间。停止发射后余烟继续运动，密度消散与发光冷却分别控制。shader 只补局部命中亮核、折射和安静的范围底色，零重力 GPU 粒子补火星或碎晶。烟的厚度与受光来自实际密度，原生灯光沿途采样烟和障碍的遮光，保持正文独立清晰。接口见[流体系统](../../FLUID-EFFECTS.md)。

雷电按相接线段的最短距离取样，分支根部插值到同一主干；像素导数用于抗锯齿，亮芯与电晕连续衰减。它不再以竖直距离近似陡折，路径光降低到局部照明范围。霜晶贴图在旋转后的采样边缘羽化，不使用方形硬裁切。纸灵斩击保留方向性的薄刃和雾尾。瞄准、进度及危险提示的功能线条不承担这些材质效果。

动态效果沿施法方向、径向或无偏向漂移组织，没有固定向上火星或向下落冰。降低画质减少粒子和灯光；减少动态关闭粒子、闪烁和折射，保留范围内材质的出现和淡出。

## 为什么选择混合方式

| 方法 | 能解决的问题 | 成本与本项目取舍 |
| --- | --- | --- |
| 每像素公式绘制晶体 | 易控制轮廓、无需资产 | 等距条纹、固定分形或重复 Voronoi 易暴露公式；加更多噪声不等于冰的细节。只保留用于柔和运动的低频噪声 |
| 六邻域扩散／附着模拟 | 枝尖竞争、枝间屏蔽、分枝和生长时间 | 适合生成形态和生长数据。需要多轮状态更新，不直接提供厚度、散射和表面材质 |
| 生成／烘焙纹理 | 稳定提供自然微结构、层次、透明细节 | 存在复用痕迹和静态照明限制；通过朝向变化、局部遮罩和受控显露降低重复，不能无限放大 |
| 纹理＋shader＋粒子＋光 | 将形态细节、生命周期、散射和场景响应分开控制 | 冰晶采用，共享霜晶纹理；不做全屏晶体求解 |
| 共享流体＋材质输运＋粒子＋光 | 烟气随速度卷动，停止注入后仍连续运动 | 烟火采用，复用既有速度／压力与独立雾网格；不为每次效果建立求解器 |

参考 [Reiter 的局部六边形元胞模型](https://webbox.lafayette.edu/~reiterc/mvp/sfn/sfn_pp.pdf)，`tools/art/bake_frost_growth.py` 实现了扩散场与可附着边界的离线研究小样。初始结晶点及水汽有小幅不均匀扰动，记录首次冻结时间。它保留了六方向晶格约束，分枝由邻域供给产生，不是预先列出枝条坐标。论文模型本身不是完整物理预测，不能将二维结果称为真实冰面模拟。

小样采用 256×256 网格，三个种子分别迭代 1800、1800、1179 次；本机 NumPy CPU 时间约 1.60、1.41、0.94 秒，输出在 `.temp/element-vfx-20261008/growth-study/`。结果适合雪晶轮廓研究，但不直接承担玻璃霜晶的成品质感，因此没有把这份模拟器放进游戏运行时。

实时 GPU 方案在工程上可使用双缓冲状态纹理及 compute shader。以两张 RGBA16F 的 256×256 状态图为例，仅状态存储约 1 MiB；1800 轮对应约 1.18 亿网格更新，若每轮拆两阶段还要分别计算。怎样分帧、共享场或缓存，会决定延迟与并发成本。**未实现和测量该 GPU 求解器，不用 CPU 时间换算 GPU 毫秒数。** 当前冰区不要求随障碍物改变晶体生长，短时攻击重新模拟的收益不足以支持这项复杂度。[更完整的扩散与各向异性附着模型](https://arxiv.org/abs/0711.4020)可作为将来确有交互需求时的研究入口。

## 性能与观察证据

在 Forward+、1920×1080、RTX 4070 SUPER 上，通过 Godot `RenderingServer.viewport_set_measure_render_time` 读取主视口 GPU 时间。冻结战斗状态，分别附加 0、1、12 个 320×320 冰材质面；各预热 45 帧、采样 120 帧，采样期间不截屏。

| 额外材质面 | GPU 中位时间 | P95 |
| --- | ---: | ---: |
| 0 | 0.400 ms | 2.561 ms |
| 1 | 0.593 ms | 1.317 ms |
| 12 | 1.428 ms | 2.473 ms |

数据属于本机材质对照，P95 有明显系统波动；不是整场战斗的帧率、实时模拟成本或 P620 验收。采样方法依据 [Godot GPU 优化说明](https://docs.godotengine.org/en/4.7/tutorials/performance/gpu_optimization.html)。原始数据在 `.temp/element-vfx-20261008/effects-3638809/gpu-cost.json`。最终只保留一张 1280×1280 RGBA8 霜晶纹理，含 mip 链未压缩驻留量约 8.3 MiB；不按效果实例复制。

### 流体成本与细节保留

低阶半拉格朗日输运会不断平滑细节，[NVIDIA GPU Gems 3 的流体章节](https://developer.nvidia.com/gpugems/gpugems3/part-v-physics-simulation/chapter-30-real-time-simulation-and-rendering-3d-fluids)解释了这一问题及高阶输运需要限制过冲的原因。当前没有采用该章的多阶段 MacCormack，而是在短寿命烟火像素中使用受限双三次采样；普通环境雾仍走双线性路径。源先做包围范围剔除，全部材质共用一次输运，没有新增求解阶段或压力迭代。

密度纹理增加两个半精度通道，承载密度加权消散率与发光量。1920×1080 比例下，双缓冲额外占用中档约 0.63 MiB、极高档约 3.96 MiB。无逐帧 CPU 回读；材质混合使用局部密度加权近似，阴影为二维光学厚度近似。

`test_fluid.gd --budget` 使用 RenderingDevice 时间戳包围实际 compute 提交，逐组预热 45 帧、采样 60 帧，不截屏、不回读纹理。源数为实际烟源数量；36 源代表并发压力样本。最终数据在 `.temp/fluid/run-9116-3623504/smoke-budget.json`：

| 流体档位 | 烟源 | GPU 中位时间 | P95 |
| --- | ---: | ---: | ---: |
| 中 | 0 | 0.113 ms | 1.815 ms |
| 中 | 3 | 0.158 ms | 0.167 ms |
| 中 | 36 | 0.303 ms | 0.315 ms |
| 极高 | 0 | 0.730 ms | 0.732 ms |
| 极高 | 3 | 0.727 ms | 0.730 ms |
| 极高 | 36 | 1.069 ms | 2.200 ms |

这些数值只覆盖本机求解器，未包含全部场景绘制；小样本存在系统波动，不以空场和少量源的微小差异推断加源更快。P620 尚未测试。

窗口检查复用 `tests/godot/test_feedback_effects.gd`：真实四书周期施法、反制／爆墨完词及终式；在指定时间点暂停后截图，覆盖命中、扩散、驻留与淡出。`--low --reduce-motion` 检查降级配置；`--measure` 额外运行上面的材质采样。HDR 捕获先对浮点色值转换 sRGB，再量化到 8 位，避免先量化引入暗部色阶断层。正式通过记录见阶段总结。

## 资产与生成记录

- `assets/art/effects/frost-crystals.png`：1280×1280，透明 PNG，保留生成 alpha，开启 mipmaps。
- 雾纹理研究稿与采样 include 已移入 `.delete/element-vfx-20261008/unused-vapor/`；正式烟火不引用它。
- 使用内置 imagegen；未使用 CLI/API 回退，未将参考图或参考图水印裁剪进资源。
- 生成原件仍保留在本机 Codex `generated_images`；游戏引用工作区副本。

霜晶生成提示词：

> Use case: photorealistic-natural. Asset type: transparent game VFX texture, square 1024x1024. Create a single isolated irregular patch of real frost crystals as photographed through a macro lens, seen straight-on. Intricate interlocking dendritic ICE, not leaves or feathers: clusters of jagged translucent hexagonal ice needles, irregular branching and layered tiny faceted plates, dense fine hoarfrost grains mixed with open transparent gaps. Unequal branch lengths, patchy density, partially fused crystals, fine silvery-blue-white rims and darker transparent interiors. Several competing growth origins form an asymmetric roughly round patch, softer sparse tapering crystals at edges, all directions equally represented, no up/down orientation. Neutral diffuse light, restrained blue-grey albedo, no emissive glow, no light halo, no smoke, no drop shadow, no background glass pane. Crystals have subtle real thickness and tiny specular facets. Occupy middle 85% of image, 8% transparent margins. Real transparent background and holes between crystals. No text, labels, grid, watermark, border, stylized outlines, uniform parallel hatch lines, regular snowflake icon, plant-like smooth leaves, or repeated vector patterns. This will be layered over a dark teal game arena at 180-350 pixels wide; readable granular mass and grouped irregular crystalline branches matter more than hairline detail.

体积雾生成提示词：

> Use case: stylized-concept. Asset type: high quality neutral game VFX volumetric density texture, square. One isolated soft irregular turbulent puff of mist/combustion vapor, seen straight on, expanding isotropically outward in empty space, NO up or down. Multiple unequal interlocking rounded cauliflower billows with delicate wispy edge vortices, organic fluid folds and soft depth shading. Asymmetric cohesive mass with distributed small transparent channels, central body is partially filled, NOT a hollow ring, NOT a donut, NO circular rim. Neutral silver-grey diffuse values, small pale highlights, soft midgrey inner folds, no black opaque shadow. No emissive lighting, no bloom, no rays, no particles, no sparks, no sharp polygons or cracks. Texture will provide alpha density and luminance structure for shader-controlled teal magic and orange fire, so preserve nuanced density from transparent wisps through medium opacity to some opaque soft billows; no baked color. Entire cloud within central 80%, generous truly transparent padding on all four sides. No background, no surface, no text, no watermark, no grid. Art quality of a rendered high-resolution fluid simulation sprite, not a drawing.
