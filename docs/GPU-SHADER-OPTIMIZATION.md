# GPU 与 Shader 计算优化研究

研究日期：2026-10-23。源码基线：`ad5fe67`，Godot `4.7.2.stable.mono.official.ed1daf0bf`，Forward+／Vulkan。本文承接[全面性能研究](PERFORMANCE-RESEARCH.md)和[视效分级方案](VISUAL-QUALITY-DESIGN.md)，规定保持现有效果的 GPU 优化路径。实施状态与待办统一维护在 [TODO](TODO.md)。

## 结论与实施顺序

优先减少冰晶的跨派发依赖、流体的重复搬运和邻域读取，再处理水晶／冰面材质的采样复用。收益来自计算与数据组织；保持各档当前分辨率、迭代量、灯光、柔焦、折射、HDR 能量、随机时序及透明合成顺序。

| 顺序 | 目标 | 研究基线的源码结构 | 优化方向 |
| --- | --- | --- | --- |
| 1 | GPU 归因 | 现有战场 SubViewport GPU 时间不足以拆分自定义计算、主画布与合成 | 标记流体各阶段、冰晶生长／膜层、燃烧；将 GPU 时间线与 CPU 提交、画布事件对应 |
| 2 | 冰晶 | 生长每步两次派发；高档大冰域每秒 2688 步；膜层包围判定每像素最多六方向各 29 次探测 | 两阶段带 halo 合并、保持因果顺序；复用方向命中信息，降低有界射线探测成本 |
| 3 | 流体 | 每帧压力迭代之外还有七次派发；高分辨率颜色／浓度存在整图复制；涡度重复读取相同邻域 | 输出 ping-pong、邻域复用、紧凑工作集与保持顺序的影响源筛选 |
| 4 | 水晶／冰面 | 双晶片多层屏幕柔焦；冰面重复求高度、膜层和邻域覆盖 | 按实际采样坐标复用计算；只在严格条件下重排过滤与缓存 |
| 5 | 火焰／雾／其他材质 | 燃烧反应反馈、逐灯雾透射、透明叠加；大量低调用量解析材质 | 依据 TEX／ALU／带宽／覆盖率证据选择局部改写，保持现有视觉语言 |

首批实现已接入可选 GPU 分段计时、冰晶单步融合与流体去复制。10月25日两组旧／新计算器82项逐字节对照及四书战斗8段通过；冰晶整链中位下降约16%／21%，流体基线持平、极限约降2.6%，详细口径见[实施记录](migration/PERFORMANCE-IMPLEMENTATION.md#2026-10-25-gpu计算验证与后续优化)。流体同序供体复用候选数值一致，但没有稳定耗时收益，已撤回。下文成本分析保留研究基线 `ad5fe67` 的结构；调用数、字节数与派发数为源码推导。

## 效果保持的验收契约

1. **模拟结果**：同输入、种子、时钟、步长和源顺序下，保留冰枝附着时刻／拓扑、流体运动、热量和余火演化。阈值附近的浮点误差可能放大成不同分枝，单张相似截图不足以验收。
2. **光学结果**：保留厚度、薄膜、晶片层叠、模糊核、色散、折射取样时刻、冰面微结构、灯光与 HDR 高光。比较色调映射前浮点目标和最终画面，不能用最终截图饱和区掩盖能量变化。
3. **时间结果**：保留动画频率、随机相位、衰减、出生／消失、暂停和减少动态行为；切画质／流体精度时保持既有场连续。
4. **资源结果**：消费者在正确的帧读取正确的纹理；保持实例生命周期、重配置、释放和外部纹理包装的有效性。省一次复制不能引入一帧延迟。

优化分两类验收。只改重复访问、同序运算和数据搬运的变更，先要求模拟纹理逐像素／逐通道一致。涉及硬件插值、表达式重组或编译器精度变化的变更，单独记录误差传播和完整视觉对照；出现分枝、边缘、柔光、闪烁或时序变化则不采用。本文不预设一个宽松的统一误差阈值。

## 研究基线的计算链与成本

### 覆盖范围与当前证据

根工程 `ui/` 共计 **51 个 CanvasItem shader、1 个粒子 shader、4 个 compute shader、5 个 include**；另有开发实验室 `space.gdshader`。逐文件 SHA-256、行数和字面资源引用保存在 `.temp/gpu-shader-research-20261023/inventory.json`。引用扫描用于定位调用者，性能排序取决于实际派发、覆盖面积和材质路径。

10月23日现有两组四书结果中，高档极限整帧 p95 为 **28.31–40.92 ms**；战场 SubViewport 的 GPU p95 约 **3.26–3.81 ms**，口径见[实施记录](migration/PERFORMANCE-IMPLEMENTATION.md#2026-10-23-流体准备与弹幕尾迹)。不能把两者相减当作纯 CPU 时间：还需确定自定义计算、主画布、后处理和排队区间。当前研究优先级基于源码成本结构，具体毫秒收益由分段 GPU 数据确定。

### 流体

入口：[fluid_gpu.gd](../ui/effects/fluid_gpu.gd)、[fluid_solver.glsl](../ui/effects/fluid_solver.glsl)、[fluid_field_2d.gd](../ui/effects/fluid_field_2d.gd)。一个 compute list 依次执行：

`几何 4 → 速度 0 → 散度／清压力 1 → Jacobi 2 × N → 投影 3 → 物质平流 5 → 复制 6 → 公开状态刷新 7`

每次派发后调用 `compute_list_add_barrier()`，局部工作组为 `8×8`。当前压力迭代数为 6／10／18／24，速度长边为 96／192／384／768，颜色长边为 192／384／768／1536；关闭流体另行处理。因此每帧为 `N + 7` 次派发。1080p 中流体通常对应 `192×108` 速度网格和 `384×216` 颜色网格。

按锁定引擎源码，`compute_list_add_barrier()` 会结束当前 compute list，重新开始，并恢复 pipeline、uniform sets 和 push constants。因此 GDScript 中一个 list 包含多次调用，不代表驱动收到一块没有依赖切分的大批次。它与已弃用且为空操作的 `barrier()`／`full_barrier()` 不同。优化应减少真实的数据依赖及图节点，保留必需的读写可见性。[锁定版本 RenderingDevice](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/rendering_device.cpp)

- 速度、物质和颜色为 `RGBA16F`，压力为 `R32F`。一次复制两张颜色网格的纹理，逻辑读写量为 `像素数 × 32 B`；`384×216` 为约 2.65 MB／帧，`1536×864` 为约 42.47 MB／帧。缓存与压缩决定实际 DRAM 流量，不能直接用此数除显存带宽预测耗时。
- 模式 0 的涡度约束计算中心与四邻域的 curl，重复调用速度／边界读取；应按唯一坐标组织半径 2 的邻域。
- 模式 5 的浓烟过滤先做两字段双线性读取，再做 `4×4` Catmull–Rom，并用中心四样本限制过冲。中心样本可复用；滤波器的负权重和 donor clamp 都是当前外观的一部分。
- 最多 48 个影响源，每源 112 B。不同阶段分别处理固体、速度、膨胀和染料；影响源有顺序，位移响应依赖已累积速度。

### 冰晶生长与膜层

入口：[ice_patch.gd](../ui/effects/ice_patch.gd)、[frost_growth.gd](../ui/effects/frost_growth.gd)、[frost_growth.glsl](../ui/effects/frost_growth.glsl)、[frost_surface.glsl](../ui/effects/frost_surface.glsl)。

当前小冰域三档网格为 `128／160／224`，大冰域为 `160／256／384`。每秒生长步数为 `分辨率 × 7`；每步执行 donor 和 diffusion 两次派发，读取六边形邻域，生长状态采用 `RGBA32F`，膜层采用 `RGBA16F`。

| 活跃冰域 | 60 FPS 下平均生长步／帧 | 生长派发／帧 | 常规膜层派发／帧 |
| --- | ---: | ---: | ---: |
| 高档小冰域 224² | 26.13 | 52.27 | 2 |
| 高档大冰域 384² | 44.8 | 89.6 | 4 |

上述为 `delta = 1/60`、正常时钟、尚未完成生长时的推导；实际步数由累计年龄取整，多个冰域相加。生长成熟后停止相应计算，膜层亦有成熟终止条件。

膜层包围判定沿六个方向寻找第一个已附着冰晶；384² 网格每方向上限 29 次，单次刷新最坏为 `384² × 6 × 29 ≈ 2566 万` 次晶体读取。实际有提前命中，且当前已在同帧膜层子步之间复用包围结果；继续优化应针对首次刷新。

### 表面与合成

- [open_crystal_optics.gdshaderinc](../ui/materials/open_crystal_optics.gdshaderinc) 在高档下为两片不同的晶片计算厚度、坡度、流动粗糙度、色散和屏幕柔焦。`crystal_level()` 已用四次硬件双线性采样实现 cubic B-spline。屏幕柔焦与材料图的重复求值需要查看编译产物后确定实际成本。
- [ice_surface.gdshader](../ui/materials/ice_surface.gdshader) 的源码路径包含约 33 次纹理调用：晶体约 14、膜层约 12、微结构 6、背景 1；编译器公共子表达式消除、缓存、双／三线性过滤会改变实际执行与访存。其坡度使用屏幕导数决定采样间距，不能直接用固定分辨率法线图替换。
- [battle_periphery.gdshader](../ui/materials/battle_periphery.gdshader) 保留 5／9／25 点空间变化柔焦。核半径随离边缘距离变化，普通固定核可分离模糊不能直接等价替换。
- 战场使用 HDR SubViewport、4× MSAA 与 glow，再输出到主画布。战场晶饰直接读取 World 纹理；页面、火焰和冲击波另有特定时刻的背景捕获。应分别核对捕获对象和消费者，合并同一快照的访问。

## 深入优化设计

### A. 冰晶：减少派发同时保留六邻域因果关系

单步 donor 阶段依赖旧状态半径 1，diffusion 阶段再读取邻居 donor，因此合并两阶段需要旧状态半径 2 的 halo。以 `8×8` 输出块为例，先装入 `12×12` 的旧 `RGBA32F`，在共享内存中计算覆盖输出及一圈 halo 的 donor，再在工作组 barrier 后计算内部输出。旧状态窗口约 2304 B，另有 donor 临时存储。

每个组只写自己的内部输出；相邻组重复计算 halo，从同一旧纹理读取，从而无需跨工作组同步。保持原六方向求和顺序、边界 clamp、冻结单元捷径、附着阈值、出生迭代以及中间 `RGBA32F` 的舍入语义。边缘工作组的越界线程参与共享装载和 barrier，用写入掩码处理最终输出，不能在 barrier 前提前返回。

边界 halo 的 donor 必须先把中心坐标 clamp 到真实网格，再计算该中心的六邻域；仅把旧状态扩边后在虚拟越界中心计算，会产生不同的邻居计数。此处要与原来“读取已计算的边界 donor”完全一致。[Vulkan 工作组与导数规范](https://docs.vulkan.org/spec/latest/chapters/shaders.html)

首个实现只合并一完整生长步，使生长派发数减半。跨多个完整步的 temporal blocking 需要每步再扩展两圈 halo，增加冗余计算、共享内存和寄存器压力；依据实测再选，不能仅按派发数计算收益。

这条路径减少一个全域中间状态写回和一次依赖切分，但会增加 halo 重算；若输出纹理由固定第零张改为交替发布，膜层和材质绑定也随之更新。当前中间状态包含四个通道，合并实现必须先完成对应旧状态的 donor，再做原顺序的七项求和，不能顺便重排浮点归约。`RGBA32F` 保留，附着阈值附近的质量和出生迭代不采用半精度。

膜层的 `branch_enclosure()` 只使用六方向是否在有限距离内命中，以及这些方向向量，并不消费命中距离。可研究有界方向扫描／共享分块查询，输出与当前逐点搜索一致的六位命中掩码，再复用现有 enclosure 公式。扫描必须保持六边形方向、边界 clamp、距离上限和 `birth > 0.5` 判定。额外扫描的派发／中间纹理成本与当前提前命中次数一起比较。

一个可精确定义的方案是把 `a > 0.5` 转为整数占据值，沿水平、竖直和正对角三个轴计算前缀计数。设某条线的含当前点前缀为 `S(t)`、探测距离为 `R`，正向命中为 `S(t+R)-S(t)>0`，反向为 `S(t-1)-S(t-R-1)>0`。三个轴得到六个布尔值，再按原六方向次序累加向量。

边界需要专门落实：原来的对角射线是对每个采样坐标分别 clamp，到边后会沿边继续前进。可先在四周扩展 R 格、填入 clamped 占据值，再在线性扩展网格上扫描；384²、R=29 对应 442²，面积增加约 32.5%，三张 `R32UI` 前缀场约 2.34 MB。局部共享 bitset 可作为较少中间存储的实现选择。首个原型只比较这条候选与原有扫描；记录稀疏初生、分枝密集和成熟阶段，只有包含准备、扫描和查询后的总成本下降才采用。

活跃区域优化也受扩散影响：当前看不见的蒸气仍会向生长前沿运输。有限步合并可以按依赖锥确定 halo；仅按已显示冰枝的包围盒裁掉其他单元会改变后续生长。

### B. 流体：省搬运，复用 stencil，按阶段组织影响源

模式 6 是高分辨率物质／颜色回写的完整复制。候选实现让本帧结果直接成为下一帧输入，通过 ping-pong 的 uniform sets 和纹理 RID 接线保留同帧消费者；公开 `Texture2DRD` 对象保持稳定。模式 7 必须读取刚完成的颜色，燃烧、粒子、雾与画质切换都必须同步到正确一侧。收益包含整图读写和一次派发；CPU 端绑定更新的成本也计入。

涡度与 Jacobi 分别适合局部共享数据。优先做同一 invocation 内相同坐标的读取复用，然后比较带 halo 的共享 tile。压力迭代通常小网格、缓存命中高，共享内存和 barrier 未必更快。合并相邻 Jacobi 步同样需要更宽 halo 和正确的固体 Neumann 边界，不能在一个 dispatch 中用工作组 barrier 代替全局依赖。

每阶段的有效影响源有不同作用域。可用稳定索引列表或 48 位掩码减少无关源访问，仍按原索引处理。速度位移有有限作用范围，投影膨胀有单独范围；物质平流的膨胀查询位置在 backtrace 中点，筛选范围必须覆盖该点，不能只按目标像素分块。有限源只有 48 个，预处理、间接读取和分支也有成本；仅在影响源循环被证实为瓶颈时接入。

旋转轴、来源不变的尺度与指数系数可每源计算一次。若由 CPU 计算，双精度三角函数再转浮点可能改变结果；可保留 GPU 相同运算和精度，以独立小预处理或更紧凑输入组织实现。避免为少量计算引入比原成本更高的新派发。

当前 `mode` 是整次派发共享的 push constant，模式分支本身不造成同一 wave 内的分歧。拆分的价值在于缩短寄存器活跃区间和收紧读写资源接口：当前同一 shader 声明所有阶段的图像，图追踪也可能受到较宽的资源使用集合影响。先查反射后的读写 binding 和实际 barrier；若采用独立阶段 pipeline，同步减少其资源接口。仅加 specialization constant、让驱动删掉未用指令，并不自动保证引擎的资源依赖集合变窄。

手工四点双线性改为 sampler 是另一个需要独立核验的候选。统一归一化坐标、半 texel 偏移、clamp 与 LOD 后，硬件线性插值仍受 `subTexelPrecisionBits` 等精度约束，不能称逐位等价。对本项目优先保留手工插值并复用已读样本；硬件插值候选须通过持续反馈和视觉验收。[Vulkan 采样规范](https://docs.vulkan.org/spec/latest/chapters/textures.html)

### C. 水晶与冰面：按真实过滤数学优化

水晶的四次 B-spline 采样已经利用硬件线性过滤；流体 Catmull–Rom 含负权重，不能套用同一四采样公式。对同一材质调用中的相同坐标、LOD、采样器和导数路径，先检查编译器是否已复用；保留有实际 TEX／ALU 减少的改写。

屏幕柔焦使用空间变化半径和受折射扰动的坐标，色散在三个不同位置取样，两晶片还具有不同光学映射。只有取样位置及过滤完全相同的项才能共享。将模糊统一预烘焙为一张低分辨率图，会改变当前光学结果。

高档晶片每片的三通道折射柔焦最多调用三次五点 `softened()`，两片加最终底景构成 35 个屏幕柔焦采样位置，此外还有反射背景和材料图。先把每片中不依赖折射位置的参数、两片共享的 `crystal_frost(SCREEN_UV, clock, ...)` 计算提到共同作用域；对 `show_refraction`／`show_reflection` 等整材质开关研究预热的静态路径。必须以编译后代码确认省去了工作，避免把编译器已经完成的常量折叠算成收益。

战场边缘 25 点核的 tap 间距随像素变化。常见的双线性合并 Gaussian taps，要求合并的权重落在对应相邻 texel 的线性区间；这里不是固定 texel 间距。两次可分离模糊还会在中间点采用不同半径。优先复用中心样本、常量权重和严格相同的坐标运算，进一步算法改写需推导出同一离散核。

冰面保留屏幕 footprint 驱动的中心差分、膜层阈值、晶轴微结构和八邻域霜密度。先收集真实重复纹理坐标，再考虑同阶段缓存；固定法线／密度预计算仅在能重建当前任意缩放、局部扭曲和导数的结果时采用。

裁剪透明区域必须证明最终 premultiplied RGB、alpha 和灯光贡献都为零，并覆盖邻域采样和位移。涉及 `dFdx`／`dFdy`／`fwidth` 的计算在一致控制流中完成；分支后的隐式 LOD 和导数不能依赖已经丢弃的相邻 invocation。

### D. 燃烧与雾：保留反应反馈与光传输

燃烧计算每像素先执行 RK2 速度追踪、状态采样与散度估计，再处理最多 64 个源。[combustion.glsl](../ui/effects/combustion.glsl) 的源为 Gaussian，具有非零长尾。普通半径剔除会改变燃料注入及后续反应；优先处理相同样本复用、精确零源和重复的统一参数计算。燃料／温度继续使用当前格式与反应时序。

[fluid_fog.gdshader](../ui/effects/fluid_fog.gdshader) 的光照沿灯到当前片元累计密度，并处理固体遮挡和光源起点位于固体内部的情况。逐灯成本应乘实际覆盖像素和实际采样数，利用原生灯光裁剪数据测量。保留光程、步数、柔和衰减和边界语义，再考虑同坐标查询复用。

### E. 画布、屏幕捕获与其他材质

1080p 一张 `RGBA16F` 目标约 16.59 MB，完整读加写约 33.18 MB；完整 mip 链像素量约为 base 的 4/3。4× MSAA 增加颜色样本存储和 resolve 成本，但通常不代表每个像素执行四遍片元 shader。应先核对实际 attachment 格式、sample count、区域、mip 生成和执行时间，再计算带宽。[Godot 屏幕读取与 BackBufferCopy](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html)

当前需要分别追踪的捕获点为：

| 捕获／读取 | 当前用途 | 优化检查 |
| --- | --- | --- |
| `BattleRuleVisuals._field_capture` | 领域／冰面的背景折射 | 依据真实消费者与退场节点判断需要捕获的帧；任何 ROI 包含最大折射、过滤足迹和全部重叠领域 |
| `FluidAtmosphere._fire_capture` | 燃烧表面的热扰动 | 已按火面可见性启用；核对余热末尾与捕获区域，保留火面下方内容 |
| `BattleWorld.WorldCapture` | 冲击波 | 已按波面可见性启用；保持波面之前的世界快照 |
| `BattlePage.SlowCapture` | 慢镜透镜与色散 | 与世界内捕获所在画布／合成时刻不同，依据依赖图决定复用 |
| `BattlePage.WordCapture` | 词咒背后亮度与字形柔影 | 当前完整复制；限定区域时必须包含屏幕五点取样及 LOD 2 过滤足迹，保持 HUD／正文前后关系 |
| `PageShell.Capture` | 阅读页、控件与遗物晶饰 | 嵌套页已共用原始捕获；同一背景快照内共享 mip，保留三个遗物各自的折射 |
| 战场 `CrystalEdges` | 侧边晶片 | 直接绑定 World 输出；归入纹理采样和主画布成本 |

逐 shader 家族的处理如下；表内名称对应 `ui/materials/`，`fluid_fog` 与粒子位于 `ui/effects/`。

| 家族与源码 | 视觉目的／实际计算 | 保留效果的优化重点 |
| --- | --- | --- |
| `open_crystal`、`open_crystal_edge`、`relic_choice`、`gold_inlay`、`crystal_sheet`、`gold_filament`、`engraved_gold` | 薄晶、金丝、折射、局部高光 | 共用背景与统一参数；保留连续过滤、图案掩码和光学层次；以实际覆盖率排序 |
| `battle_periphery`、`battle_shockwave`、`battle_slow_lens`、`archive_lens` | 柔焦、波动、透镜与色散 | 捕获／合成依赖和全屏读写；`archive_lens` 读取其输入纹理，区别于隐式屏幕捕获 |
| `ice_surface`、`combustion`、`spell_field`、`ultimate_field`、`actor_surface`、`corrosion`、`fluid_fog` | 冰火、领域、状态覆盖和光传输 | 上述计算链；冻结外壳的邻域膨胀与主体 alpha 都需保留。`actor_surface` 在 `burning == 0` 时可研究跳过其独立三层 fBm，使用整材质一致分支 |
| `word_reading`、`about_reading`、`setup_reading` | 字形柔影、正文背景与阅读层 | 字形 pass 与普通线条分别归因；保持正文清晰和底景亮度自适应。扫描未找到 `setup_reading` 的字面资源引用，实施前确认动态加载关系 |
| `archive_floor`、`archive_paper`、`archive_ritual`、`battle_atmosphere`、`ritual_atmosphere`、`outcome_atmosphere` | 纸纹、仪式云气、尘埃与大面积背景 | 静态项与时间统一参数复用；保留空间噪声、频谱和已有整数 hash 接缝修复。已有纹理噪声／尘场继续复用 |
| `archive_book`、`book_orbit`、`book_seal`、`ritual_light` | 法书景深、轨道、印记与仪式光 | 法书模糊在预乘 alpha 空间求和，保留软边／阴影／光晕；固定幂和时间参数仅在编译后仍重复时上提 |
| `battle_ribbon`、`spell_link`、`lightning_arc`、`melee_attack`、`spirit_paper` | 连续尾迹、连线、电弧、斩击与纸灵 | 保留物理宽度 UV、渐细和导数过滤；优先减少透明几何覆盖和重复提交，不重新引入尾迹分节 |
| `battle_fragment`、`burst_splinter`、`energy_burst`、`field_mote`、`flame_burst`、`frost_impact`、`item_burst`、`projectile_flame` | 短时爆发、碎片、雾粒与火弹 | 同帧实例数乘有效覆盖；共同参数提前求值、有限支持范围裁剪；Gaussian 柔光的长尾仍保留 |
| `cast_progress`、`ultimate_indicator`、`startup_wave`、`departure_ritual`、`open_wash`、`open_button_light`、`popup_depth` | 输入反馈、蓄能、入退场和控件光效 | 按事件长帧看首次管线与合成；整材质关闭的分支可特化，保持淡入淡出连续 |
| `fluid_particles` | GPU 粒子受流体驱动、渐变和缩放 | 当前已有 GPU 并行；先区分粒子更新与粒子绘制 overdraw，保留出生随机数、阻尼和耦合时序 |

共同 include 为 `open_crystal_optics`、`crystal_frost`、`soft_shapes`、`element_medium`、`fire_fallback`。其中 `soft_shapes` 用导数过滤窄线和有符号距离，属于连续尾迹与柔光品质的基础；不能用固定宽度或不带导数的近似函数替换。开发实验室 `space.gdshader` 单列，不计入正式战斗的收益。

## GPU 执行层的采用条件

| 观察到的瓶颈 | 需要的证据 | 对应动作与约束 |
| --- | --- | --- |
| dispatch 依赖与调度成本 | 派发时间、相邻依赖间隙、CPU 命令记录成本；区分 GPU 等 CPU 和 GPU 等前一阶段 | 冰晶合并、去复制、独立实例批次；保留真实数据依赖 |
| TEX 延迟 | shader 采样指令及相关停顿、cache 命中、活跃 wave | 同坐标复用、独立读取提前发出、适量增加并行；地址依赖链较长时优先缩短链 |
| 显存／缓存带宽 | L2／DRAM 流量与吞吐、read/write 单元繁忙度 | 取消整图复制、减少重复字段读取；纹理格式变化须先证明精度与通道用途 |
| ALU／特殊函数吞吐 | 数学管线繁忙度、`sin/cos/exp/pow` 的实际指令和占比 | 共同表达式、时间／源常量、精确零分支；保留噪声 hash 和反应参数 |
| 寄存器／shared 限制 | 寄存器数、spill、理论和实际 occupancy、shared 字节数 | 缩短值的存活区间，拆阶段或调整 tile；不把 occupancy 百分比当最终目标 |
| 透明 overdraw／blend | 片元数、图元覆盖、颜色目标带宽、重叠层数 | 紧凑且保守的几何边界、正确 scissor、捕获复用；保持透明排序和柔光 |
| 冷启动管线 | 首次 pipeline 编译／创建事件、首次使用材质和 shader hash | 接入已有渲染准备与 Shader Baker，覆盖实际专用变体，不把编译搬到首个高压帧 |

GPU 每个 SM／CU 的寄存器和共享内存预算是有限的。更大的 tile 可以降低 halo 比例，也可能减少同时驻留的工作组；过度展开循环还会扩大指令和寄存器压力。以当前 `8×8` 为对照，依据首个热点的资源占用选择一个候选尺寸，持续保留基线／极限两种业务负载。高 occupancy 仅是隐藏延迟的手段，须以总耗时与 spill 情况判断。[NVIDIA shader 优化](https://developer.nvidia.com/blog/advanced-api-performance-shaders/)、[AMD occupancy 解释](https://gpuopen.com/learn/occupancy-explained/)

subgroup 可以高效交换邻域、压缩占据位和做整数扫描，但大小、支持的指令和 invocation 排布要查询设备能力。二维横纵邻居不一定恰好位于相邻 lane，不能固定按 NVIDIA 32 lane 推断所有设备。首个实现保留通用共享内存路径；只有映射、活动 lane 与边界明确时使用 subgroup。[Vulkan subgroup 指南](https://docs.vulkan.org/guide/latest/subgroups.html)

异步计算需要两个同时具有足够执行资源、且没有当前帧读写依赖的工作。Godot 的 `call_on_render_thread()` 是 CPU 侧渲染线程派发，`WorkerThreadPool` 也不会自动生成独立 GPU 队列。当前流体投影→平流→雾、冰晶→膜层→冰面具有帧内依赖；先在同一 RenderingDevice 上优化。多个独立冰域可以组织成带实例索引的批次，让同一阶段的独立工作并行，但网格、年龄、随机种子和输出仍逐实例保持。只有时间线显示可重叠空档且引擎接线允许时，再研究独立队列；跨进程传纹理会增加同步与生命周期成本，不列入当前方案。

`RGBA16F` 存储不意味着所有运算都是 FP16；把 shader 算术改成半精度还涉及设备能力与舍入。压力、冰晶附着、微结构阈值继续采用现有精度。对显示材质做 `pow(x, n)` 展开、FMA 合并或快速三角近似，同样需要核对编译器原有结果和跨帧图像；不得只按源代码运算符数量判断成本。

## 两组验证与落地出口

### 测量入口

延续 [test_visual_quality.gd](../tests/godot/test_visual_quality.gd) 的基线／极限入口及右上角 `FpsDisplay`，复用 [test_feedback_effects.gd](../tests/godot/test_feedback_effects.gd) 和 [test_fluid.gd](../tests/godot/test_fluid.gd) 已有 GPU timestamp 读取方法。GPU 诊断标记按需开启，正式运行关闭。

| 组别 | 保留的战斗规模 | Shader 研究新增的固定阶段 |
| --- | --- | --- |
| 基线 | 6 目标、96 弹、纸灵实际 4 容量，四书依次运行 | 正常菜单切书／阅读页／遗物展示；单次领域从出生到成熟与消退；当前常规光照和折射 |
| 极限 | 18 目标、256 弹、纸灵实际 10 容量及既有纸鹤构筑，四书依次运行 | 同一时间表内触发反制、终式、可达的重叠冰火／冻结演员与升级页面；记录实际活跃冰域、源和光源数量 |

对照版本使用相同种子和**模拟时钟驱动的事件表**，避免按渲染帧数触发导致快版本拥有更多源或不同生长年龄。首轮性能固定当前高画质／中流体、1920×1080；针对改变了共享 shader 的批次，在同两种负载内追加低／中档和减少动态的短视觉段。其他流体精度依照受影响边界补检，不排列画质×精度×窗口尺寸的新性能矩阵。

菜单、冷建、战斗稳态、反制／终式和退出分别标记，不混成一个 p95。冰晶至少保留初生、稀疏前沿、密集分枝、成熟膜层的样本：成熟后停止生长的高 FPS 不能冲淡初生成本。动态冰域并发数量按实际状态输出，未发生指定事件时该阶段不作有效对照。

### GPU 时标与队列口径

1. 标记 `fluid.geometry / velocity / divergence / pressure / projection / transport / publish`、`ice.growth / surface`、`combustion`，同时保存网格、迭代数、dispatch 数、实例数和影响源数。首轮每阶段一对标记，不给每次 Jacobi 或每个冰晶小步各加一对。
2. 标记在渲染线程记录。锁定引擎不允许在已经派发过任务的活跃 compute list 内直接调用 `capture_timestamp()`；利用当前已有的 barrier 分界／list 结束处，或给完整阶段加标记，避免为测量额外切碎生产调度。
3. 按 `get_captured_timestamps_frame()` 去重，成对匹配同帧同实例的名称；只读取已经返回的结果，不调用 `sync()`、`texture_get_data()` 或截图强制等待 GPU。
4. 已核对锁定版本 Vulkan 驱动：GPU 查询经 `timestampPeriod` 转为**纳秒**，CPU 值由 `get_ticks_usec()` 记录为**微秒**。毫秒分别除 `1e6` 与 `1e3`；现有冰晶夹具采用这一换算。[RenderingDevice 实现](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/rendering_device.cpp)、[Vulkan 时间戳实现](https://github.com/godotengine/godot/blob/ed1daf0bf/drivers/vulkan/rendering_device_driver_vulkan.cpp)
5. 当前 Vulkan timestamp 写在 `BOTTOM_OF_PIPE`，阶段间隔包含该区间内的依赖和执行成本。用队列事件核对标记归属，不能把每段区间相加就称作整帧关键路径。采集名称、GPU 帧号、提交 CPU 时间和呈现帧时间，明确两者的延迟映射。

CanvasItem 由引擎组织 draw，GDScript 的 `_draw()` 前后只说明命令准备时间。水晶、冰面、逐灯雾、glow、MSAA resolve、屏幕复制和 mip 的 GPU 成本，由图形捕获中的实际 pipeline／draw／dispatch 与 attachment 对应，不能用主线程函数耗时替代。

### 当前可用工具与硬件计数器

本次只读核对的本机为 **RTX 4070 SUPER、驱动 610.88、12282 MiB**。已安装 `Nsight Systems 2024.6.2.225`，CLI 位于：

`C:/Program Files/NVIDIA Corporation/Nsight Systems 2024.6.2/target-windows-x64/nsys.exe`

其本地帮助确认支持 `--trace=vulkan` 和 `--vulkan-gpu-workload=batch|individual`。先采集有明确阶段的短窗口，用 batch 看 GPU 是否等提交、是否存在气泡、CPU 是否在建 pipeline；只有需要归因到具体 draw／dispatch 时才启用 individual。Profiler 开销下的时间单独标记，最终收益来自关闭 profiler 的同组窗口。[Nsight Systems Vulkan 使用说明](https://docs.nvidia.com/nsight-systems/UserGuide/)

本机有 Nsight Compute 和 `nvdisasm`，它们面向 CUDA，不替代 Vulkan 图形 shader 的计数器／汇编分析。当前工具清单未发现 Nsight Graphics、RenderDoc 或 SPIR-V 离线工具。实施时如需寄存器、stall 和 shader 管线统计，应补充相应图形工具；本次未安装软件或开展新的 GPU 性能采样。[Nsight 工具职责](https://docs.nvidia.com/nsight-developer-tools/index.html)

对最热的一两个 shader，采集实际 pipeline hash、寄存器数、shared 用量、spill、活跃／可调度 wave、TEX／L2／DRAM 与主要 stall。根据硬件可用性使用 Nsight Graphics Shader Profiler，其他目标设备使用对应厂商工具。SPIR-V 用来检查分支、采样、精度和资源接口；它不等同于最终 GPU 指令。[Nsight Graphics Shader Profiler](https://docs.nvidia.com/nsight-graphics/UserGuide/shader-profiler.html)

本机结果用于排序，最终共享内存／subgroup 路径还需在至少一个不同架构的目标设备验证，尤其检查低资源 GPU 的工作组驻留与带宽。跨设备验证沿用同两组输入，不以本机高端显卡的单次百分比作为通用收益。

### 视觉、数值与性能出口

| 改动 | 最小直接验证 | 采用条件 |
| --- | --- | --- |
| 去流体复制／接线 | 同步推进时比较当前完整场；出生、关闭再开、切精度与释放；检查雾、粒子、燃烧读取侧 | 同帧结果一致，绑定成本计入后 publish 与整链总耗时下降 |
| 冰晶两阶段合并 | 固定种子的每步状态与最终出生图；边缘 clamp、冻结单元、不同网格和减少动态 | 附着／分枝／出生时刻一致，包含 halo 和发布后的总成本下降 |
| enclosure 整数扫描 | 六方向命中掩码逐像素一致，覆盖边／角、空场、稀疏与密集晶体 | enclosure 与后续膜层一致，含预处理和中间存储的总耗时下降 |
| 流体 stencil／源筛选 | 稳定源次序、移动固体与 backtrace 边界；持续模拟场比较 | 无反馈轨迹变化，热点实际时间下降；小批基线不受预处理拖累 |
| 光学采样／材质特化 | 固定时钟下 HDR 与最终图像；同两组内切档、缩放、缩小高光与动态回放 | 过滤、折射、色散、柔光、微结构与文字效果保持，实际 TEX／ALU 或 pass 成本下降 |
| 捕获／合成复用 | 同一帧快照的层次与最大取样范围，退出／嵌套页面与重叠效果 | 不出现旧帧、漏采样、错误折射对象；copy／mip／合成成本下降 |

数值／图像读回在独立的等价检查阶段进行，性能窗口中不截图、不同步取纹理。重用现有夹具的断言与像素比较；只有新增并行算法缺少直接保护时才补必要的回归断言。源代码修改后的 Godot 检查遵循项目约定，shader 编译与运行验证使用锁定引擎。

每个计算链分别记录改动前后两组的整帧 p50／p95／p99、事件峰值、对应 GPU 段和 CPU 提交段，并保留源码 hash。最低采用门槛是：视觉／数值出口通过，候选热点耗时改善超过窗口自然波动，整帧和事件长帧无实质回退。计数器改善但总耗时变差的候选不采用。只在差异与波动无法区分时复测相同两组。

首批实现涉及 `gpu_effect_timing.gd`、`frost_growth.gd/.glsl`、`fluid_gpu.gd/fluid_solver.glsl` 与现有测量入口；燃烧仅增加分段标记。后续依据实际 GPU 排序选择邻域复用、膜层查询、水晶、冰面或捕获链。每批同步更新[性能实施记录](migration/PERFORMANCE-IMPLEMENTATION.md)与 TODO，测试结果与源码实现状态分别记录。

## 研究交付与参考

研究阶段完成全量 shader 清单、关键路径源码分析、锁定引擎同步／时间戳核对、具体算法与两组验收设计。源码清单及引擎参考副本位于 `.temp/gpu-shader-research-20261023/`；后续实现状态见本文开头与实施记录。

过滤、同步和硬件执行的主要原始资料：

- [GPU Gems 2：Fast Third-Order Texture Filtering](https://developer.nvidia.com/gpugems/gpugems2/part-iii-high-quality-rendering/chapter-20-fast-third-order-texture-filtering)：用硬件线性过滤组合权重的条件；本项目 B-spline 与 Catmull–Rom 路径的判断依据。
- [Vulkan Shader 规范](https://docs.vulkan.org/spec/latest/chapters/shaders.html)：工作组同步作用域、helper invocation、导数及一致控制流。
- [Vulkan Sampling 规范](https://docs.vulkan.org/spec/latest/chapters/textures.html)：texel 定位、过滤和插值精度。
- [NVIDIA Advanced API Performance: Shaders](https://developer.nvidia.com/blog/advanced-api-performance-shaders/)、[AMD Occupancy explained](https://gpuopen.com/learn/occupancy-explained/)：寄存器、内存和工作组资源的实际取舍。

方案中的派发融合、前缀查询、资源接线和材质优先级是依据当前工程推导出的设计；上述资料支持 GPU 机制，不构成本项目的性能结果。
