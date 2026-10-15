# 效果与渲染实践

## 从更亮／更多粒子转到可观察因果

相似形状不能代替远程反射、近战推离、实际闪避与完整终式。用户否定过平滑亮块、液片长尾、触手外沿和道具体积云；后来保留冰火实际材料过程，并让短促道具采用局部粒子和材质。更复杂的模拟不是所有效果的目标。

先明确付费对象、实际中心／半径、起手／持续／尾段、暂停和到期，再选最小适用载体。冰域复用 IcePatch／FrostGrowth，持续火场复用共享流体的 Combustion，弹反／反制／爆墨读取已提交事件，用当前局部粒子组件；不要照历史流体 burst 配方把退出接线重新装回正式道具。

入口：`docs/art/ELEMENT-EFFECTS.md`、`ui/battle_visuals.gd::_spawn_item_burst()`、`ui/spell_field_visual.gd`、`ui/ultimate_field.gd`；历史 `docs/archive/2026-10-08-build-system/ELEMENT-EFFECTS-ATLAS.md` 解释舍弃过程。`development/element_lab/` 与正式场景共用组件，小样满意仍需正式尺度／事件复查。

## 时间、位置与状态各有所有者

曾逐渲染帧累加外推速度导致帧率改变形态；按时间积分才保持一致。慢动作若只缩规则速度，粒子、Tween、晶生长继续跑，会使画面寿命与真实对象脱离。使用 `BattleVisualClock.delta_for()`／`tween_for()` 及实际 `world_time`，暂停、精确输入慢时与结束一致；真人输入统计仍使用其真实时钟。

接触闪光用实际 `contact` 与方向，`at` 是实体中心。尾迹只做显示采样，先替换超前物理头再接插值头，不以轨迹曲线改碰撞。不要同时叠手动插值与节点物理插值。

来源：M2 经验 §2–4；`ui/battle_visual_clock.gd`、`game/session/battle_session.gd`、`ui/motion_curve.gd`；阶段总结 2026-10-09 道具形态记录。

## 流体：空气运动、物质、光照与战斗分开

最初容易用补雾替代推动空气、用 SOLID 遮住角色，造成尾部堆积与离开后的硬洞。后来区分：DISPLACE 推动已有空气，density 才注入物质，SOLID 只用于占据模拟切片的墙。场、物体、粒子需同画布局部坐标；extent 是半尺寸，沿线 end_offset 是发射器局部位移。

常用接法见 `docs/FLUID-EFFECTS.md`，复用 FluidField2D／Body／Emitter／Profile 公共接口，不直接触碰内部求解数组。瞬移、池复位用 rebase，连续闪避不重置扫掠。停止源不等于清空已有雾；隐藏、暂停、关闭和重建分别核对。战场俯视火焰不照首页配方添加屏幕向上浮力／沉降。

发光像素不是 Light2D；实际灯、接收 mask、路径与预算共同决定照明。火场共用现有速度／压力网格，不为每块另建求解器，不回读 GPU 去决定战斗弹道。减少动态与低画质保留范围和警示，模拟装饰可停。

## 弹幕：轮廓、HDR尾迹与流体分别取证

清晰轮廓、HDR光学尾迹、流体运动和环境受光分别判断。先查绘制层、视口、材质混合与输出链，再调亮度；增强识别不能丢掉材质层次，新增亮线不能替代已有流体。通过独立开关各层检查遮挡与效果保留，分别核对HDR像素、最终软边和原生照明。

尾迹先确定空间长度或时间残留语义，再选择位移或时间采样，避免固定帧数引入速度和帧率依赖。带状网格明确连接相邻左右截面，横向UV跨宽度、纵向UV沿路径，检查短段、急弯、自交和退化几何。连续收尖与柔化只处理显示，沿用同一插值头，不改变危险半径或弹道。

亮度检查同时看世界纹理和最终软边，HDR峰值只描述当前重叠条件，不设为通用目标。按改动检查低画质、减少动态、反射及清弹回收；回收断言应在负责更新的节点处理后执行，不能只等待帧开始信号。规则归属、造型辨识与验证方法见`docs/ENEMY-AND-BARRAGE-RESEARCH.md`第12节；既有证据不替代本次改动对应的验证，也不要求每次跑全部入口。

## RID 与渲染线程：重建不破坏消费者身份

质量切换曾先清空 Texture2DRD，再绑定新 RD 图像；既有材质持有失效外层 RID，显示白色矩形。后来保留 RenderingServer 纹理身份，先绑定新图像再释放旧图像。依赖速度纹理的燃烧等消费者在场关闭／重建前解除依赖；场真正退出再销毁外层对象。

RenderingDevice 操作在渲染线程，复用 `EffectPipeline.acquire()` 的 shader／pipeline，实例仅持有独立数据／uniform set。准备系统保留程序强引用，最后消费者退出才释放；纹理、uniform 与依赖的释放顺序在重建和退出均核对。隐藏节点不自动停止 compute／离屏绘制。

来源：`docs/FLUID-EFFECTS.md`“求解与成本”；`ui/effects/fluid_gpu.gd`、`effect_pipeline.gd`、`combustion.gd`；正式接入检查按需选 `test_fluid.gd` 或 `test_feedback_effects.gd` 的暂停／重建／到期路径。

## 冰生长：提高分辨率同时改变数值条件

增大网格不只增加细节，固定扩散步长和噪声尺度可能改变膜层稳定性与形态。后来按网格比例调整迭代上限、包围范围与噪声尺度，用有界子步处理膜扩散，并在同帧复用包围信息；实际慢帧也须保留晶尖领先与膜层连接。

调整先读 `frost_growth.gd::step()` 和 `ice_patch.gd`，核对晶格／膜层时钟与尺度，而不是只增常量。弧面、尖脊和平面斜率是不同材料表达，用户最终选择以当前实现为准，不将研究中的距离场方案当下一步。

来源：`docs/art/ELEMENT-EFFECTS.md`；`docs/STAGE-SUMMARY.md` 2026-10-10 冰晶弧面与大冰域记录。固定夹具的 30FPS 检查不等于真实目标机遭遇性能。

## 预热：加载资源不等于准备渲染管线

只 preload shader／短等待曾无法覆盖首次编译与管线变体。后来用原生材质／场景清单及实际渲染图元准备，compute 复用 EffectPipeline 并走最小真实 dispatch。`RenderPreparation` 读取 SceneState 的材质，不启动游戏逻辑；准备完成以真实阶段回执，不以固定时间猜测。

新固定材质加入 `ui/scenes/render_preparation.tscn` 的正式引用，按需更新 `test_render_preparation.gd` 覆盖。粒子过程、屏幕采样、受光与几何变体需实际绘制；只在脚本写 shader 路径不足以供 Shader Baker 发现正式材质。材质数证明集合覆盖，不证明所有硬件／状态管线皆预热。

来源：`docs/migration/PLAN.md`“渲染准备与原生资源实施方案”；`app/bootstrap.gd`、`ui/render_preparation.gd`。不要冻结历史材质计数。

## 性能：先界定测量对象再比较

旧 Web 移除 Canvas→Three.js 整屏上传链提高帧率，却未拆出每环节 GPU 耗时；render() 返回快也不能说明 GPU 完成。后来用阶段取证与同条件对照，拒绝凭效果数量或平均 FPS 归因。

取样明确是在测 CPU 准备、GPU compute、视口绘制还是整帧；嵌套阶段与重叠 GPU 时间不直接相加。截图回读、窗口等待、预热和正式采样分开。质量网格长边翻倍，面积约四倍，频率还影响每秒成本；按实际成本调局部网格／装饰预算，不削弱危险提示来通过。

来源：`docs/archive/rendering-discussion.md`；`docs/FLUID-EFFECTS.md`“求解与成本”；阶段总结的冰域并发取证。RTX 4070 SUPER 短样本不是 P620 长时结论。没有具体性能疑点就不加入常规采样。
