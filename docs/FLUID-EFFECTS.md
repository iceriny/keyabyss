# 二维流体系统使用说明

`FluidField2D` 是独立、可放置和变换的 Godot `Control`。场的尺寸、位置、旋转和父级缩放决定覆盖区域，输出窗口的像素数不决定解算网格。可通过纹理遮罩形成任意轮廓，也可组合多个独立场。首页与战场使用 `FluidAtmosphere` 提供淡薄氛围；HUD、词咒、正文与危险提示保持原有独立层级。

本文面向在 Godot 编辑器里接效果、配置资源和编写少量接线代码。推荐依次阅读[快速开始](#快速开始)、[节点与资源](#节点与资源)、[调参顺序](#调参顺序)和[效果配方](#效果配方)；底层预算与扩展接口见后面的求解、接入和表现章节。

## 快速开始

本工程使用 Godot 4.7.2、Forward+ 和 HDR 2D。普通开发直接运行根工程；compute 解算不能用 headless 或 Compatibility 检查。节点尚未使用 `@tool`，编辑器未运行场景时不会解算雾，保存参数后运行查看。

一个最小场景可以这样组织：

```text
Scene (Node2D 或 Control，同一 Viewport 内)
├─ FluidField2D                 空气域与雾的绘制层
│  └─ FluidEmitter2D            持续补雾，profile 指向 mist.tres
└─ Visual (Node2D 或 Control)   被移动的图像、角色或 UI
   └─ FluidBody2D              field 指向上面的 FluidField2D
```

1. 实例化 [`fluid_field_2d.tscn`](../ui/scenes/fluid_field_2d.tscn)，设定 `position` 和 `size`。例如位置 `(0, 0)`、尺寸 `(800, 450)`、质量 `MEDIUM`。初始场只有空气，没有可见雾。
2. 在场内添加 `FluidEmitter2D`，将 `field` 拖到场节点，将 `profile` 指向 [`mist.tres`](../ui/effects/presets/mist.tres)。把发射器放到场的 `(400, 350)`。复制这个预设到自己的效果资源，先把源的 `density` 调到 `0.05～0.1`，避免长时间累积太浓。
3. 给可移动的视觉物体添加 `FluidBody2D`。指定 `field`，不需要碰撞节点时留空 `collision`，直接填 `extent`，例如 `(24, 24)`。把节点位置放到视觉主体中心，保持 `interaction = DISPLACE`、`body_shape = BLUNT`。
4. 移动物体。它会推开已有空气、让两侧绕流和后方回填；不会自己制造雾。小而快的物体改为 `POINTED`，先保留 `body_aspect = 2.4`、`response_speed = 240`。
5. 按画面层次安排场的位置和 `z_index`：雾绘制在背景之后、需要清晰的正文之前。同一画布中的节点才能直接交换位置和接收相同光照；不要把物体放在另一张 SubViewport 中，却指定外部的场。

场填满整个窗口时可使用全矩形锚点，并设 `edge_fade = 0`；局部雾片保留默认边缘羽化。场的位置和大小是空气域，补雾位置与尺寸是雾的来源，二者可以不同。想让雾沉底，应把补雾源放低、收窄其竖向范围，随后加少量 `settling`，而不是缩小整个空气域。

也可只用代码创建一个最小场：

```gdscript
extends Node2D

var fluid: FluidField2D

func _ready() -> void:
	fluid = FluidField2D.new()
	fluid.size = Vector2(800, 450)
	fluid.edge_fade = 0.0
	fluid.set_options(FluidField2D.Quality.MEDIUM, false)
	add_child(fluid)

	var mist := FluidInfluence.new()
	mist.shape = FluidInfluence.Shape.BOX
	mist.center = Vector2(400, 470)
	mist.extent = Vector2(700, 210)
	mist.density = 0.08
	mist.noise_amount = 1.0
	mist.noise_scale = 280.0
	fluid.sources.append(mist)

	var body := FluidBody2D.new()
	body.field = fluid
	body.extent = Vector2(32, 32)
	body.position = Vector2.ZERO  # Visual 的中心；有偏移时在这里调整
	$Visual.add_child(body)
```

所有示例数值以约 800～1920 个局部单位的场为起点，不是固定美术标准。场被父级缩放后，这些局部尺寸一起缩放。

## 节点与资源

添加节点时搜索对应自定义类型；也可给表中的基础节点挂脚本。`.tres` 定义在 Inspector 内展开编辑，常用预设在 [`ui/effects/presets/`](../ui/effects/presets/)。

| 类型 | 用途与配置位置 | 生命周期 |
| --- | --- | --- |
| [`FluidField2D`](../ui/effects/fluid_field_2d.gd)，Control | 场尺寸、空气运动、雾显示、质量、原生灯池；整个系统的容器 | 隐藏／暂停停止解算，质量或遮罩改变会清空场 |
| [`FluidBody2D`](../ui/effects/fluid_body_2d.gd)，Node2D | 跟随物体自动测量平移与旋转，推动已有空气；无需发射资源 | 隐藏、禁用碰撞或释放时注销 |
| [`FluidEmitter2D`](../ui/effects/fluid_emitter_2d.gd)，Node2D | 把效果资源放到场景位置，跟随父节点；可同时产生力、雾、粒子和光 | 短时效果自动释放；持续效果手动 `queue_free()` |
| [`FluidInfluence`](../ui/effects/fluid_influence.gd)，Resource | 一个力／补雾分布；用于 `sources`、`inject()` 或效果的 `influences` | 直接注册的源由使用者移除；效果内源由发射器管理 |
| [`FluidEffectProfile`](../ui/effects/fluid_effect_profile.gd)，Resource | 多个源的组合、持续时间、淡出、路径、灯光和粒子 | 定义资源，运行中不改变源数组结构 |
| [`FluidMedium`](../ui/effects/fluid_medium.gd)，Resource | 注入雾的颜色、密度倍率、冷热、消散率和自发光 | 可被多个只读效果共享 |
| [`FluidAtmosphere`](../ui/effects/fluid_atmosphere.gd)，Control | 首页／战场的应用适配层，自动创建环境源、追踪场景物体 | 由页面管理，普通自定义效果优先使用 `FluidField2D` |

`FluidGPU`、`FluidMotionPath`、`FluidParticleFlow` 是内部辅助实现，普通接入不需要实例化或访问 `_gpu`、`_scene_sources` 等私有字段。

### FluidBody2D：视觉物体与碰撞物体

**纯视觉物体**：把节点挂在 Sprite、Node2D 或 Control 下面，设置 `field`、位置偏移和手动 `extent` 即可。`extent` 是半尺寸，`(30, 20)` 对应约 `60 × 40` 的投影尺寸；节点缩放会进入换算。

**已有碰撞物体**：指定同一画布内的 `CollisionShape2D`。它的形状、全局位置、旋转和缩放取代手动 `shape`／`extent` 及本节点的变换。支持 Circle、Rectangle、Capsule；无需修改实际碰撞和伤害规则。

| 参数 | 默认值 | 用法 |
| --- | --- | --- |
| `field` | 空 | 必填；把所属 `FluidField2D` 拖入 |
| `collision` | 空 | 可选；指定后优先使用碰撞节点的形状与变换 |
| `shape`／`extent` | ELLIPSE／(24, 24) | 无碰撞时的手动投影；胶囊的长轴为节点局部 X |
| `interaction` | DISPLACE | 一般实体使用它；SOLID 只用于占满二维模拟切片的墙和结构，会排除内部雾 |
| `body_shape` | BLUNT | 圆钝或双尖受力；双尖沿实际运动方向，停下后保留最后方向 |
| `body_aspect` | 2.4 | 尖形前后伸展比；1.5～3 可作起点，只在 POINTED 下使用 |
| `coupling` | 24 | 动量交换速度；先在 12～36 内调整，越高响应越快 |
| `reach` | 3.2 | 受力范围倍率；先在 2.5～3.5 内调整，变大会影响更宽的已有雾 |
| `response_speed` | 240 | 小目标的速度交换尺度，局部单位／秒；不是物体的移动速度 |

DISPLACE 目前以投影最大半尺寸估计受力半径，圆钝／尖形由 `body_shape` 决定；它没有精确拟合矩形或椭圆表面的压力。SOLID 才使用 `shape`／碰撞轮廓作为硬边界。不要为了圆形角色遮住雾而选 SOLID，否则角色消失时容易产生空洞。

瞬移、循环轨道跳回或从对象池重新放置后，显式重置历史：

```gdscript
$Visual.position = new_position
$Visual/FluidBody2D.rebase()
$Visual/FluidEmitter2D.rebase()  # 有跟随尾迹时也重置
```

连续移动和闪避不调用 `rebase()`；调用它会取消跳跃这段路径的扫掠。释放场景时节点自行注销。

### FluidEmitter2D：放置与复用效果

Inspector 中设置 `field` 和 `profile`；发射器的位置、旋转、缩放构成效果的局部坐标系。挂在移动物体下就能跟随。`end_offset` 为发射器局部坐标的终点，供 `along_path` 的光束或横扫使用。

代码生成时，位置和角度使用场的局部坐标：

```gdscript
var burst: FluidEffectProfile = preload("res://ui/effects/presets/burst.tres")
fluid.emit_effect(burst, Vector2(400, 240))

var suction: FluidEffectProfile = preload("res://ui/effects/presets/suction.tres")
var effect := fluid.emit_effect(suction, Vector2(400, 240))
effect.position = Vector2(500, 240)
# 持续效果结束时：
effect.queue_free()
```

共享资源保持只读；修改单次效果时先复制，然后生成节点：

```gdscript
var template: FluidEffectProfile = preload("res://ui/effects/presets/burst.tres")
var fire := template.duplicate(true) as FluidEffectProfile
var medium := FluidMedium.new()
medium.color = Color("ff9a60")
medium.temperature = 0.8
for source in fire.influences:
	source.medium = medium
fire.light_color = medium.color
fluid.emit_effect(fire, hit_position)
```

`FluidMedium.color` 染色新注入的雾，`light_color` 照亮场景与已有雾；二者需分别配置。零密度的电光也能照雾，普通发光 shader 本身不会自动生成灯。

## 调参顺序

先用默认中档。确认有雾、坐标正确、物体在场内之后，每次只改一个通道：

1. **空间分布**：先调补雾源的 `center`、`extent` 和 `noise_scale`，决定雾在哪里存在、雾团多大。
2. **数量与存留**：调源的 `density` 和场的 `density_decay`，决定物质量；最后才用 `opacity` 调画面可见度。
3. **大尺度空气运动**：调 `wind`、`velocity_decay`、`settling`、`buoyancy`，确认缓慢漂移和冷热方向。
4. **实体反馈**：调 `body_shape`、`coupling`、`response_speed`；只有范围不对才改 `extent` 和 `reach`。
5. **卷散细节**：先调 `turbulence_scale` 和 `turbulence_force`，再调 `turbulence_detail`、`vorticity`。保留大雾团，不用高频噪声遮盖输入或边界问题。
6. **照明与成本**：调 `scattering`、光的颜色／能量／半径，最后比较画质档。正文和危险提示保持自己的清晰层。

以下默认值是通用 `FluidField2D` 的值；首页和战场的适配器另有参数，见本文末尾的实际接入说明。

### 场参数

| 参数 | 默认值／单位 | 作用与调整方向 |
| --- | --- | --- |
| `size` | 场局部单位 | 空气域；放大它不会增加网格数量，但同一格代表更大空间 |
| `quality` | MEDIUM | 通过 `set_options()` 切换；影响空间精度，所有开启档逐帧更新 |
| `wind` | (4, -2)，单位／秒² | 全域空气加速度；X 正向右，Y 正向下；不是目标风速 |
| `velocity_decay` | 0.35，1／秒 | 空气动量阻尼；增大更快停下，减小惯性更长 |
| `density_decay` | 0.16，1／秒 | 雾消散；增大痕迹更快消失，也需要更多环境补雾维持背景 |
| `heat_decay` | 0.5，1／秒 | 冷热回归中性；增大更快失去升沉趋势 |
| `settling` | 0 | 按密度向下施力；约 2～5 适合微弱沉降，覆盖范围仍要靠补雾位置控制 |
| `buoyancy` | 12 | 按有符号温度施力；正热上浮、负热下沉；环境中性雾不因此上浮 |
| `turbulence` | 0，权重 | 环境扰动总开关／强度；约 0.3～0.6 可作缓慢气流的起点 |
| `turbulence_scale` | 240，单位 | 大涡流空间尺度；增大更宽缓，减小更多局部变化 |
| `turbulence_force` | 65，单位／秒² | 扰动加速度；薄雾慢流可先试 10～20，战场当前为 42 |
| `turbulence_detail` | 0.8，权重 | 两层小涡流；约 0.2～0.5 可作克制细节的起点，受网格可解尺度限制 |
| `vorticity` | 0.45 | 保留既有卷曲的强度；不能单独代替风、实体运动或雾源 |
| `fog_color` | #668b9b | 未指定颜色的后续注入物质色；不统一重染已经输送的雾 |
| `opacity` | 0.12，0～1 | 显示透明度，不改物质量或运动；过高会遮住场景 |
| `scattering` | 0.6 | 雾接收原生灯光的散射强度；需要实际灯光才能看到差异 |
| `center_clear` | 0.3，0～1 | 显示时降低中央对比，不清除真实密度；首页为 0 |
| `edge_fade` | 0.07，UV 比例 | 四周显示羽化；填满窗口、需要贴边时设 0 |
| `fog_enabled` | true | 只隐藏雾显示，空气仍可驱动粒子和自定义材质 |

衰减均为指数率，半衰期约为 `0.693 / decay`：0.18 对应 3.85 秒，0.35 对应 1.98 秒，0.95 对应 0.73 秒。0 表示不衰减。持续补雾与衰减会一起决定稳定物质量，不能把 `density` 当作最终 alpha。

运行中改空气参数，下一步自动使用；改外观参数后调用 `update_appearance()`：

```gdscript
fluid.wind = Vector2(6, 1)
fluid.density_decay = 0.8
fluid.opacity = 0.1
fluid.edge_fade = 0.0
fluid.update_appearance()

fluid.set_options(settings.fluid_quality, settings.reduce_motion)
fluid.set_domain_mask(mask_texture)  # 会重建／清空场
```

### 单个影响源参数

`FluidInfluence` 的尺寸、坐标均相对于所属场；在效果资源里则相对于发射器，由节点转换到场坐标。持续源按秒，`inject()` 按一次注入量。普通方向力、实体动量和补雾可以独立组合。

| 参数 | 用途 |
| --- | --- |
| `shape`／`center`／`extent`／`rotation` | 分布形状、中心、半尺寸和弧度；BOX 是矩形区域内平滑衰减，不是四边硬裁切 |
| `density` | 持续率为密度／秒；`emission_per_distance` 时为密度／移动单位；零值不生成雾 |
| `temperature` | 有符号热量率，可对空气只加冷热；正暖、负冷 |
| `velocity` | `coupling = 0` 时为方向加速度；`coupling > 0` 时为目标空气速度 |
| `coupling` | 将空气向目标运动耦合；普通风、爆炸、吸力可留 0 |
| `spin` | 围绕中心的切向驱动；耦合时为目标角速度（弧度／秒），非耦合持续源为切向加速度系数 |
| `radial` | 正值向外，负值向内；持续时为加速度，不自动生成雾 |
| `color`／`medium` | `medium` 优先；否则透明 `color` 使用场的 `fog_color`，非透明值作为物质色，alpha 不控制源强度 |
| `noise_amount` | 0 为平滑分布，1 为充分噪声调制；只改变注入分布 |
| `noise_scale` | 雾团局部尺寸；先增大以取得成团感，随后用真实空气扰动卷散 |
| `initial_age` | 注入物质年龄；不控制空气扰动的开启 |
| `displacement_radius` | 大于 0 使用实体流函数；通常由 FluidBody2D 自动填，不需手写 |
| `body_shape`／`body_aspect`／`response_speed` | 与 FluidBody2D 一致；普通力和雾源不用设置 |

`FluidMedium.density_scale` 乘源的密度，`temperature` 表示每单位注入密度附带的热量。颜色按密度运输与混合；颜色的 alpha 不用来降低雾量。

`dissipation` 为额外密度消散率，0 沿用场默认值。`emission` 为每单位密度的初始发光量，默认 0；它随物质输运，另以 3／秒冷却，火光先熄、余烟后散。局部混合后的消散率按密度加权，是共享网格内的近似混合，不为每种物质建立独立求解器。

### 效果资源参数

| 参数 | 默认值 | 用法 |
| --- | --- | --- |
| `influences` | 空数组 | 添加一个或多个 FluidInfluence；只发光的效果也可不补雾 |
| `duration` | 0.5 秒 | 0 为持续效果；大于 0 自动结束，若有粒子会等待粒子存留期再释放 |
| `fade_out` | 0.7 | 最后 70% 时段逐渐减弱；1 覆盖全程，0 在终点结束；同时影响力、释放和光 |
| `sweep` | false | 保留移动段及折点，连接高速尾迹；挂在移动目标下的雾迹应开启 |
| `emission_per_distance` | false | 按移动距离生成密度与热量，停下后不再堆雾；不改变方向力的单位 |
| `inherit_velocity` | 0 | 把发射器的运动速度加到驱动中；普通尾雾先试 0～0.1，避免旧尾迹追着物体跑 |
| `along_path` | false | 将源铺到 `end_offset` 路径，并沿线提交光源候选 |
| `light_color`／`light_energy`／`light_radius` | 白／0／200 | 共享原生场景光；能量 0 表示不发光，半径使用场局部单位 |
| `particles` | 空 | 根节点必须为 GPUParticles2D 的 PackedScene；复用其原绘制材质 |
| `particle_coupling` | 1.8 | 粒子跟随空气的程度；与实体交换空气的 coupling 是不同参数 |

发射器的局部 X 是预设方向。方向喷流用 `(正值, 0)`，旋转节点指向攻击方向；后侧释放用源的负 X 偏移。`melee.tres` 自身包含向负 Y 的驱动，复用时按其资源方向旋转。

## 效果配方

### 环境薄雾和风

使用持续 `mist.tres` 产生物质，再使用 `wind.tres` 或场的 `wind` 推空气。两者分开后可以“风继续吹、雾源已关闭”。先缩小补雾的竖向范围、增大 `noise_scale`，再用微弱 settling 与慢涡流维持沉底大团。不要给每个移动实体附加环境补雾源。

### 飞行物和闪避尾迹

实体用 FluidBody2D，飞行物选 POINTED、角色选 BLUNT。另挂 FluidEmitter2D 释放少量物质，开启 `sweep` 和 `emission_per_distance`；让源中心位于实体后侧，默认闪避预设是 `(-64, 0)`。闪避开始时生成短时发射器，令其跟随实际渲染位移；预设持续 0.2 秒、`fade_out = 1`，停止后没有终点补雾。

后侧方向依赖发射器旋转，不会自动跟随父物体的速度改朝向；由物体的可视朝向或移动脚本设置。例如物体正沿局部 X 前进时使用零旋转。若每帧旋转，需保持方向连续。

战场额外痕迹可通过 `medium.dissipation` 独立调短，无需加速整个背景的消散。未混合时密度半衰期约为 `0.693 / (density_decay + dissipation)`。发射器结束代表停止补雾，已经注入的雾仍由场输送和消散。战场关闭浮力、沉降和定向环境风；首页仍保留自己的空间氛围。

### 近战横扫、爆炸、吸力

| 目标 | 复用资源 | 主要调哪些值 |
| --- | --- | --- |
| 近战扰动 | `melee.tres` | 胶囊半长／半宽、方向加速度、spin、duration；默认只扰动已有雾 |
| 爆炸 | `burst.tres` | radial、extent、density、temperature、光能量；不需要烟时把 density 置 0 |
| 吸力／旋吸 | `suction.tres` | 负 radial、spin、extent；先限制局部范围，结束时释放持续节点 |
| 发射气浪 | `gust.tres` | 正 X 驱动、范围、持续时间；默认不补雾 |

沿一段攻击路径生成效果：

```gdscript
var slash_profile: FluidEffectProfile = preload("res://ui/effects/presets/melee.tres")
var slash := slash_profile.duplicate(true) as FluidEffectProfile
slash.along_path = true
var attack := fluid.emit_effect(slash, start_local, direction_angle)
attack.end_offset = (end_local - start_local).rotated(-direction_angle)
```

`end_offset` 不等于场里的绝对终点，要减去起点再转换到发射器局部方向。一个沿线源通常已足够，不要每个像素生成独立节点。

### 冰、火与电光

冰与火共用效果资源，换 FluidMedium 的颜色和冷热即可；可以另调 `density_scale`。冷热在输送中衰减，不按法书写求解器分支。电光使用 `electric_flash.tres`，通过光色、能量、半径与路径照亮已有雾；没有密度的地方不会凭空出现散射物质。

### 粒子与坐标

已有粒子直接 `fluid.bind_particles($GPUParticles2D, 1.8)`，或把粒子场景填入效果资源。支持球形／盒形 ParticleProcessMaterial，需与场位于同一画布空间；不必逐粒子写 CPU 逻辑。其他过程材质未被适配。

鼠标位置转入场：`fluid.canvas_to_local(get_viewport().get_mouse_position())`。同一画布里的物体全局位置转入场：`fluid.get_global_transform().affine_inverse() * visual.global_position`。节点发射器与物体适配器自动做位置和缩放转换，优先使用它们。

## 常见问题

| 现象 | 检查和调整 |
| --- | --- |
| 场有尺寸但看不到雾 | 初始空气不含雾；检查补雾 density、位置、场质量、减少动态、节点可见性和绘制层次 |
| 空白处移动没有视觉反馈 | 该处空气仍运动；需要已有雾或绑定粒子作示踪，不要为普通破雾强行补密度 |
| 鼠标／小目标太弱 | 先调 coupling／response_speed；范围很小且低档网格无法解出时，再比较中档或略调作用范围 |
| 物体消失留下硬洞 | 一般实体使用 DISPLACE；检查是否错误使用 SOLID 或域遮罩 |
| 边缘像有斥力／雾离开窗口 | 检查 edge_fade；它只是显示羽化，窗口贴边设 0 |
| 雾铺满屏幕但不想减浓度 | 下移／收窄补雾源；不要只降低 opacity，也不要把整个空气域裁小 |
| 飞行物尾部被拖走、停止后积一坨 | 降低 inherit_velocity，后侧释放，按距离注入；破雾用物体节点，不另设宽范围吸力 |
| 尾迹不连续 | 开启 sweep；不要每帧新建短节点；确认父节点渲染移动确实进入发射器路径 |
| 光照不到雾或场景 | 检查实际 Light2D、接收 light_mask = 2、灯的 range_item_cull_mask = 2、光能量／半径和 scattering；发光像素不自动变灯 |
| 改参数没有生效 | 外观调用 update_appearance；质量用 set_options；运行中更换 profile 或 influences 数组时重新创建发射器 |
| 调质量后雾消失 | 重建会清空数据，持续源会逐渐补回；不是跨质量保留全部旧纹理数据 |
| 暂停／复用后出现长扫掠 | 瞬移后调用物体与发射器 rebase；场关闭／减少动态时不要积累输入事件 |
| 同时效果太多，一部分失效 | 看 dropped_influences；每个源、保留扫掠段和障碍都占预算，合并重复源或缩短效果生命周期 |

停止持续力或补雾，移除对应节点或 `sources.erase(source)`；它只停止新的输入，已有空气与雾继续演化。`set_active(false)` 暂停整个场及其效果时钟；关闭质量／隐藏单个发射器不等同于暂停短效果寿命。`reset_field()` 用于需要彻底清空状态的场景重置。

## 求解与成本

GPU 保存二维速度、密度、有符号温度、颜色、年龄和压力。每步先更新硬障碍、平流速度并施加动量，再做散度、压力迭代和速度投影，随后用当前步的新速度运输高分辨率雾并注入物质。起步输入在本步就能推动已有雾。速度阻尼、密度消散、冷热浮力、沉降与涡量约束分别可调。密度是不可压缩空气里的被动浓度；颜色和年龄以密度加权量保存，共用回溯路径与衰减，不把有限压力迭代的残余散度当作气体压缩去增亮密度。不同来源的雾自然混色。

速度使用低分辨率 RGBA16F；密度／温度／加权消散率／发光量使用独立高分辨率 RGBA16F，颜色／年龄为同尺寸 RGBA16F，均双缓冲。压力为 R32F，避免大尺寸局部坐标造成压力半精度溢出。运输后将密度／温度采样回速度网格，供浮力和既有消费者读取。GPU 结果由 `Texture2DRD` 直接供材质使用；正式运行没有每帧回读、CPU 网格循环或 GPU 同步等待。各档每个显示帧解算一次，单步最多 0.05 秒，不在卡顿后集中补算，也不通过降低更新率区分画质。

短寿命烟火在同一次输运中使用局部双三次采样，并将结果限制到四个供体格的最小／最大值内，减少反复双线性采样抹平细节和插值过冲。普通环境雾保留双线性路径。没有增加网格、求解阶段或压力迭代；源注入先做保守包围范围剔除，再计算旋转距离和噪声。显示材质复用密度导数形成团块受光，实际灯光沿密度与障碍采样遮光；这仍是二维光学厚度近似，不是三维体积阴影。

| 设置 | 速度网格最长边 | 雾网格最长边 | 压力迭代 | 雾光采样 |
| --- | --- | --- | --- | --- |
| 关闭 | 无 | 无 | 无 | 无 |
| 低 | 96 | 192 | 6 | 2 |
| 中 | 192 | 384 | 10 | 4 |
| 高 | 384 | 768 | 18 | 6 |
| 极高 | 768 | 1536 | 24 | 8 |

各开启档位的网格长边按 2 倍递增，最低档不变；相同宽高比下，每升一档网格数量约为 4 倍，GPU 成本不按长边线性增长。极高档相较此前的 384／960 长边，速度网格数量约增至 4 倍、雾网格约增至 2.56 倍；压力迭代和灯光预算不变。

另一边随场宽高比确定，最少 8 格。步长使用实际帧间隔，因此 60／144 Hz 等显示刷新率下都更新流动；较高刷新率也会增加每秒解算成本。每场每步最多 48 个影响对象，优先保留障碍和一次性扰动，再接受持续源；超出预算的数量可从 `dropped_influences` 观察。增加覆盖尺寸不会增加网格数量；需要局部细节时使用更小的场。多个场各自承担预算与成本，不交换流体，也不承诺无限实例的固定总成本。

关闭释放解算存储，只保留一张 1×1 零值纹理；减少动态隐藏流体并停止解算；场景暂停、隐藏与 `set_active(false)` 停止推进。恢复时不会补发过期扰动。调整质量、网格或遮罩会清空该场，以新配置重新建立流体。

材质持有的 RenderingServer 纹理 RID 在质量切换中保持不变。重建时先绑定新 RD 图像，再释放旧图像；场退出时才销毁外层纹理。不能先清空 `Texture2DRD.texture_rd_rid` 再重新分配，否则既有 CanvasItem／粒子材质会继续引用失效的 RID，采到默认白纹理，形成矩形雾。

## 接入

可实例化 `ui/scenes/fluid_field_2d.tscn`，或在自己的场景层创建：

```gdscript
var mist := FluidField2D.new()
mist.position = Vector2(200, 120)
mist.size = Vector2(800, 420)
mist.set_options(settings.fluid_quality, settings.reduce_motion)
add_child(mist)

var emitter := FluidInfluence.new()
emitter.center = Vector2(180, 300)
emitter.extent = Vector2(90, 50)
emitter.density = 0.06
emitter.temperature = 0.04
emitter.velocity = Vector2(12, -8)
emitter.spin = 0.3
mist.sources.append(emitter)
```

`FluidInfluence` 支持椭圆、旋转矩形和旋转胶囊。`extent` 为半尺寸；胶囊沿局部 X 轴，`extent.x` 是包含两端的半长，`extent.y` 是半径。`center`、`extent`、`velocity` 均使用所属场的局部坐标，旋转为弧度。持续源的 `velocity` 默认表示加速度，`density`／`temperature` 表示每秒注入量；`spin` 产生切向扰动，`radial` 为正时向外推、为负时向内吸。一次性扰动由 `inject(influence)` 复制并排队，以上数值按一次注入量使用；返回值说明是否接受，不修改传入 Resource。

推动空气和生成物质是两个独立通道：

- `coupling > 0` 时，`velocity` 和 `spin` 表示目标平移／角速度。接触区向目标速度传递动量，再经压力投影推动周边空气；`density = 0` 不会生成或抹去雾。
- 实体设置 `displacement_radius > 0`，由局部流函数的旋度生成前推、侧向绕流与后侧汇入。输入参考身体中心的空气速度，只交换相对动量。平移核使用紧支撑光滑函数，先淡出流函数再求速度；影响范围边缘不另设源汇。`body_shape` 为 `BLUNT` 时是圆钝绕流，`POINTED` 时采用平滑双尖度量与对应梯度，沿运动方向渐开、渐合；`body_aspect` 控制纵横比，默认 2.4。这与注入或硬障碍的 `shape` 独立。圆钝影响范围默认半径的 3.2 倍，尖形沿前后轴延长。沿路径扫掠并按接触时长加权，`response_speed`（默认 240 局部单位／秒）提供独立于尺寸的速度交换尺度，再结合身体尺寸与路径限制高速传递；小目标不会仅因尺寸小而几乎没有响应。停止后保留流场惯性，实体继续与局部空气耦合，隐藏时注销。尾部补位推动已有雾，不使用独立吸力源或补充密度。这是有滑移的二维投影视觉近似，没有求解实体表面的精确压力或分离边界层。
- `density > 0` 才注入雾。附带方向力可形成喷流，附带径向力可形成爆炸，附带负径向力可形成旋吸。单纯吸力和风不需要生成密度。
- `medium: FluidMedium` 配置物质颜色、密度倍率和每单位密度的冷热。正温度上浮、负温度下沉；显式 `temperature` 还能只加热／冷却已有空气。未指定 medium 时使用本源的 `color`，透明色表示场的 `fog_color`。
- `noise_amount`、`noise_scale` 只塑造注入时的密度，不在最终画面上叠加噪声贴图。`initial_age` 是输送物质的初始年龄，不控制空气是否运动。

已有持续源可直接更新位置、形状、强度或旋转；同一 Resource 的运行修改由使用者持有，不应修改被多个实例共用的只读定义。`sources` 与 `obstacles` 是持续影响列表，场景适配器不会清空外部注册内容。`wind` 是全场加速度；`buoyancy` 按温度施加浮力；`settling` 按密度提供向下加速度；`vorticity` 保留卷曲细节。`turbulence`、`turbulence_force`、`turbulence_scale` 控制空气涡流的权重、加速度与尺度；`turbulence_detail` 控制两层小涡流，最小尺度由网格间距限制，局部剪切增强受到上限约束。背景加速度较小，持续累积使旧尾迹逐渐弯曲，无需按雾龄开启空气运动。没有雾的区域同样演化速度，后来进入的雾随已有空气输送；这些力不生成密度。衰减参数使用每秒指数率。

`set_domain_mask(texture)` 用遮罩红通道定义流体域，红值小于 0.5 的网格单元参与实心边界，显示边缘保留遮罩渐变。白色允许流体，黑色排除；可用绘制、生成或导入纹理表达复杂轮廓。`edge_fade` 为场矩形边界的显示羽化宽度（UV 比例），局部场默认 0.07，主菜单设为 0，让沉降雾自然贴住窗口下沿；它不产生物理推力或删除密度。`reset_field()` 清空场。`canvas_to_local(point)` 将同一画布的坐标转换成局部位置。

`FluidBody2D` 为原生物体适配器：指定 `field`，可以直接使用本节点的手动半尺寸，也可指定圆、矩形或胶囊 `CollisionShape2D`。完整配置步骤见前面的节点说明。默认 `DISPLACE` 模式通过上述动量输入推雾；只有墙壁等占据整个模拟切片的结构使用 `SOLID` 或 `obstacles`，排除内部密度并提供移动边界速度。有剪切的组合变换和凹多边形使用多个简单形状或场域纹理。视觉压力不反写战斗规则。

## 可复用效果

`FluidEffectProfile` 组合一个或多个 `FluidInfluence`、持续时间、淡出、移动扫掠、原生光源，以及可选的 `GPUParticles2D` 场景。`FluidEmitter2D` 可挂在任意移动视觉节点下，指定 `field` 与 `profile`；在解算时采样整个移动间隔，自动处理生命周期和注销。也可直接生成：

```gdscript
field.emit_effect(preload("res://ui/effects/presets/burst.tres"), hit_position)
var suction := field.emit_effect(preload("res://ui/effects/presets/suction.tres"), center)
# 持续效果跟随节点位置；停止时释放节点。
suction.position = next_center
suction.queue_free()
```

预设均位于 `ui/effects/presets/`，可在 Inspector 复制并编辑，不需要修改求解器：

| 资源 | 组合 |
| --- | --- |
| `wind.tres` | 大范围方向风和轻微旋转，持续 |
| `mist.tres` | 大尺度不均匀补雾，持续 |
| `gust.tres` | 短时方向冲量与局部光，用于发射 |
| `dodge.tres` | 跟随闪避位移，在身体后侧按移动距离补雾；释放量从起步到结束逐渐减弱 |
| `melee.tres` | 胶囊形横扫、旋转扰动与短时光 |
| `burst.tres` | 径向扩张、物质注入和衰减光 |
| `suction.tres` | 向内径向力与旋转，不生成雾 |
| `electric_flash.tres` | 无密度闪光，可沿一段路径照亮已有雾 |

`duration = 0` 表示持续；`sweep` 连接两次解算之间的路径，`inherit_velocity` 携带发射器移动速度。`emission_per_distance` 将密度／热量解释为每移动局部单位的注入量，停止后不再生成物质；`fade_out = 1` 使释放强度在整个持续期逐渐减弱。源的局部 `center` 可把释放点放在身体后侧。`along_path` 使用节点局部的 `end_offset`，将输入铺到胶囊路径，并沿线提交最多三个灯光候选；仍受全场光源预算约束。普通静态光不需要流体源。预设默认按持续率配置，一次性数值使用 `inject`。

`FluidMotionPath` 为书体、鼠标和移动发射器保留最多八段弯折；直线合并，超出预算时简化最不显著的折点。每段使用完整胶囊覆盖，按接触时长分配动量和补雾，避免输入频率变高时重复加力。首页交互开启时取消鼠标事件合并，通过事件位置和相对位移接入首段，隐藏、关闭流体或退出时恢复输入设置。

只有既有页面适配器需要调用 `FluidAtmosphere.track_body()`／`untrack()`；自定义视觉物体优先用 FluidBody2D。首页／战场适配器会在 `_ready()` 设置环境参数，不作为任意场景通用可调模板；要配置独立环境，用 FluidField2D 加持续发射器。

四本法书的 `.tres` 指定 `FluidMedium`；`fluid_effects` 可以按已提交事件选择效果资源。冰的冷蓝雾、火的暖色热流、雷电的低密度与路径闪光、纸灵的扫掠使用相同求解规则。新增表现只配置物质／效果；只有增加新的游戏事件类型时才需要补充场景事件到效果的映射。

## 表现与复用

当前根工程保留一项尚未完成视觉验收的元素实验：`FluidInfluence.expansion` 在压力投影后添加短时径向膨胀，密度输运同时稀释物质和发光量；`FluidAtmosphere` 用它推散一次性注入的气团。雾材质采用预乘 alpha，使自发光不再乘以稀薄烟气的覆盖率。2026-10-08 用户要求暂停视觉调整；最后流体材质回归 0 失败，但最终核未重新实拍、测成本或导出。具体证据与素材见[元素材质交接](art/ELEMENT-EFFECTS.md)。

默认雾材质通过 CanvasItem `light()` 接收原生 `PointLight2D`／`DirectionalLight2D` 的位置或方向、颜色、强度和光纹理，沿光线采样密度及硬障碍，近似呈现散射与遮挡。发光物体内部的起始障碍跳过自遮挡，离开光源后遇到的障碍参与遮光。雾色来自被输送和混合的物质；`fog_color` 控制后续环境注入的颜色，`opacity`、`scattering`、`center_clear` 控制显示，修改后调用 `update_appearance()`。此处是二维密度场上的体积感近似，没有三维体素或真实三维体积光求解。

场景接收层使用 `light_mask = 2`：雾、纸面、法书材质、仪式装饰、角色表面和粒子接收同一批原生灯光；正文、HUD 与词咒保持独立。新增原生灯光使用 `range_item_cull_mask = 2`。发光 shader 和粒子不会自动生成灯光，效果资源将照明与发射绑定，`FluidField2D` 管理公共灯光池。通用画质低／中／高最多同时启用 3／5／8 盏局部灯，优先保留较强光源；额外手动放置的原生灯不受此池预算管理。流体解算质量独立，关闭流体仍保留场景灯光。减少动态保留稳定光照，取消短时闪光。HDR glow 对合成结果做柔光扩散。原生阴影由 Godot 的 LightOccluder2D 管理，流体硬边界只额外参与雾的光程估算。

也可关闭 `fog_enabled`，调用 `update_appearance()`，将 `field_texture()` 交给自己的 shader、粒子或局部材质：RG 为局部单位／秒的速度，B 为采样后的密度，A 为温度。`density_texture()` 返回独立雾网格的密度 R／温度 G；`matter_texture()` 返回同尺寸的密度加权线性 RGB／年龄 A。纹理在质量切换时保持 Resource 身份，但重新分配底层数据；材质无需每帧更换纹理。场释放后不继续持有其 GPU 结果。

`bind_particles(particles, coupling)` 将场内的 `GPUParticles2D` 接入 GPU 平流。支持本工程使用的球形／盒形 `ParticleProcessMaterial` 发射器，保留速度范围、方向、重力、阻尼、旋转、大小、颜色与曲线，以及原有绘制材质；这是这些参数的适配器，不承诺覆盖 ParticleProcessMaterial 的全部特性。粒子使用画布世界坐标，速度按场的变换转换，无逐粒子 CPU 更新。关闭流体时恢复原生过程材质，恢复时重新接入。

首页空气域覆盖整个场景，补雾源集中在下部并向上光滑衰减，中心为场尺寸的 `(0.5, 1.04)`、半尺寸为 `(0.95, 0.46)`。保持原雾透明度与注入率，通过空间分布减少中上部覆盖；输送出的雾不被高度裁切。微弱沉降、低速风和三个缓慢游移的涡流推动空气。法书使用圆钝受力，鼠标使用双尖受力；切换、缓慢浮动和掠过只改变动量，不补充密度或热量。法书淡出时同步降低交互和灯光并注销，不会留下持续清空的空洞。法书阴影和柔光按 mip 采样范围自然消隐，避免贴图边界硬裁切。法阵保留线条与光点，背景不叠加独立漂移雾环。

战场雾在不透明纸面之后、角色之前绘制，采用全域、偏下方的大尺度稀薄补雾，不使用四个固定椭圆雾区。玩家和敌人推开已有空气；闪避在身体后侧按距离释放前浓后淡的尾迹，不叠加第二份闪避推力。飞行物按实际实体尺寸推流，在后侧注入带少量余速的填充尾迹。新尾迹沿运动方向铺设，老尾迹受涡流、温度和沉降影响。战场密度衰减率 0.95／秒（半衰期约 0.73 秒），热量衰减率 1.2／秒；环境源补充率为 0.0875／秒，保持稀薄背景，同时使额外注入的痕迹更快消散。首页保留独立慢流参数。施法、命中、弹反、终式与召唤通过效果资源进入同一场。运动覆盖整个采样路径，低档也不会只在端点留雾。场景适配器不增加伤害、碰撞、收入或目标判定。

设置分为固定的“显示、效果、声音、玩法”标签，正文独立滚动。`fluid_quality` 与原有 `quality` 独立保存，默认中档；流体选择使用 `fluid` 词令，质量切换立即应用到首页与保留的战场。已有控件词令会切换到所属标签并操作真实控件，恢复默认会覆盖所有标签中的选项。

## 验证入口

```powershell
pwsh -NoProfile -File tools/godot/godot.ps1 import
pwsh -NoProfile -File tools/godot/godot.ps1 run --script res://tests/godot/test_fluid.gd
```

该回归必须使用实际 Forward+ GPU。覆盖运输、消散、遮罩、硬障碍与软推挤、刚体、坐标变换、资源生命周期、设置和暂停；检查密度加权混色、冷热升沉、物质年龄、细涡流、无雾空气与被动雾空气的相同演化、两种破雾形态及停止惯性、推挤的密度保持、吸力方向及效果灯光生命周期。检查各档独立雾分辨率及高刷新率响应、快速折返轨迹、首步起点输送、后侧两侧气流汇入与已有雾的补位、闪避路径密度和战场 30 秒静置。先绑定再分配的纹理会实际绘制；零初速 GPU 粒子检查位移；隔离雾和纸面分别切换灯光；真实输入触发切书、出征、闪避、冰／火飞行物和雷电照雾。`--materials` 可只运行物质与通用效果，`--motion` 可只运行连续运动、静置和战斗交互。

`--usage` 只检查节点使用契约：无碰撞的视觉物体、局部坐标与缩放、破雾不补密度、瞬移重置、隐藏／释放注销、碰撞适配、沿线终点、共享资源保持只读及零淡出寿命边界。新增效果先跑对应的最小集合，不必每次执行完整流体回归。

`--clip` 专用于连续录像，给录制输出增加 sRGB 编码层，避免直接量化 HDR 线性图像导致偏暗与色阶断层。该版本 [MovieWriter 实现](https://github.com/godotengine/godot/blob/4.7-stable/servers/movie_writer/movie_writer.cpp) 会在量化后再编码一次，因此转码时撤回这一额外转换；中间 AVI 与录制窗口不用于曝光判断。录制与转码命令（FFmpeg 需可从命令行调用）：

```powershell
& ./tools/godot/godot.ps1 -Task run -EngineArguments @('--write-movie','.temp/fluid/interaction.avi','--fixed-fps','60','--script','res://tests/godot/test_fluid.gd','--','--clip')
$transfer = 'if(lte(val/255,0.04045),val/12.92,pow((val/255+0.055)/1.055,2.4)*255)'
$filter = "format=gbrp,lutrgb=r='$transfer':g='$transfer':b='$transfer',format=yuv420p"
ffmpeg -i .temp/fluid/interaction.avi -vf $filter -c:v libx264 -crf 18 -an -movflags +faststart .temp/fluid/interaction.mp4
```

GPU 解算时间单独采集；首页 HDR 绘制时间包含雾光绘制，两者不能当作完整游戏帧耗时。设备、输出尺寸、失败和采样记录保存在本次 `.temp/fluid/` 证据中；不外推为低端显卡或发行验收。静态图片与接口检查不替代尾流、惯性和消散的连续观察。

底层接口参见 Godot 4.7 官方的 [compute shader](https://docs.godotengine.org/en/4.7/tutorials/shaders/compute_shaders.html)、[Texture2DRD](https://docs.godotengine.org/en/4.7/classes/class_texture2drd.html) 和 [RenderingDevice](https://docs.godotengine.org/en/4.7/classes/class_renderingdevice.html)。Vulkan GPU 时间戳实际为纳秒，换算依据 [4.7 Vulkan 驱动实现](https://github.com/godotengine/godot/blob/4.7-stable/drivers/vulkan/rendering_device_driver_vulkan.cpp)，不是类参考页面标注的微秒。

参考 [Locko2901/webgl-fluid-simulation](https://github.com/Locko2901/webgl-fluid-simulation) 的速度／染料分辨率分离、沿路径分配输入和涡量保持思路，保留本项目的成团薄雾、元素物质与原生 Light2D 规则。参考输入实现在一帧起终点之间插值 splat；这里保留折点并使用连续胶囊，避免快速折返被缩成起终点连线。鼠标事件策略依据 [Godot Input.use_accumulated_input](https://docs.godotengine.org/en/4.7/classes/class_input.html#class-input-property-use-accumulated-input)。流函数与不可压缩流背景见 [MIT 势流讲义](https://ocw.mit.edu/courses/2-20-marine-hydrodynamics-13-021-spring-2005/resources/lecture10/)；本工具使用的紧支撑核、滑移与扫掠是视觉和性能近似，并非完整势流边界求解。
