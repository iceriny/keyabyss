# UI 与采样实践

源路径相对仓库根目录；目标视觉仍以正式规范为准。像素、时长与模糊半径属于当前实现参数，不冻结为通用常量。

## 从截图临摹转到行为与受效层

早期仅看截图，漏掉选书、准备展开、前缀词令、焦点、入场和声音。后来沿组件／CSS／路由／音效追踪完整流程，再决定原生场景与 AnimationPlayer 的载体。旧指南规模和旧天赋学习路线如今不产生恢复义务。

接界面先列触发、状态、过渡、中断、收尾、文字和声音；正式控件和词令调用同一动作。Theme 换外观而保留原生控件信号，逐类查看 CheckButton、OptionButton、SpinBox、滑条、滚动条及 PopupMenu，不能靠几个 Button 的主题认为全覆盖。

普通展示／词令控件使用 FOCUS_NONE，文本框只在显式进入编辑时取输入。关闭焦点遍历是用户要求，不能在审核中当缺陷恢复。方向键滑条上下文、文本编辑键、战斗 Tab 与全局词令分别归属 `InputRouter`。

来源：`docs/migration/UI-IMPLEMENTATION-LESSONS.md`“先恢复行为”“原生控件”“词令覆盖”；`app/main.gd::_apply_control_policy`、`ui/open_button.gd`、`ui/theme/keyabyss.tres`。

## 点击、布局、过渡需要独立状态

只改 z_index 曾出现看到前书却点中后书：绘制顺序不替代 GUI 命中顺序。装饰设 MOUSE_FILTER_IGNORE，点击区明确拥有，深度变化同步树顺序且只在顺序改变时 move_child。`ArchiveHome._layout_books()` 与 `book_hits.move_child` 是现行入口。

选书曾使背景锚点、shader 形态和图案分别跳变，颜色 Tween 不能解决。后来拆开固定房间骨架、四枚封印权重、法书轨道与文字命中层。可中断 Tween 从当前插值色和权重继续，旧 Tween kill，权重总和为 1；共享 accent 传播到一份独立 Theme 与存活粒子 tint。hover 使用连续权重共同驱动清晰度、亮度和透明度，不只柔化外发光。

固定标题、返回、主要操作与正文内部滚动由 `PageShell` 承载；切换详情不改变窗口位置。长下拉必须实际观察：about_to_popup 前已算最小尺寸，max_size 需两个有效维度并收束 min/current size；短列表通过不能证明长列表。

来源：UI 经验“绘制前后”“共享书色”“房间法阵”“景深”；`ui/archive_home.gd`、`archive_theme.gd`、`page_shell.gd`；M2 经验 §7。相关现有入口：`test_presentation.gd`、`test_ui_refinement.gd`、`test_display.gd`，只选改动对应部分。

## 先核对采样，再判断字体与细线

正文与场景同入 glow／CanvasGroup／折射曾变糊；低分辨率 SubViewport 放大也会丢细节。后来将场景独立 HDR，正文置于后绘制的主 Canvas，并按全局画布缩放配置实际像素尺寸。高分辨率不是低分辨率纹理放大。

检查顺序：实际输出区域 → 根画布／离屏尺寸 → 控件像素吸附 → 双重插值 → shader 内部过滤 → SVG mipmap／几何 MSAA。文字与实体读取同一渲染帧。`--wid` 嵌入曾将 2560×1440 内容显示在较小区域，独立窗口改善锯齿；不能据此认定资源覆盖或具体滤波算法。

连续有符号距离上计算导数，再 abs／非线性处理；`soft_shapes.gdshaderinc` 提供像素足迹过滤。MSAA 不修 shader 内部线条，mipmap 不替代景深。透明图像模糊先乘 alpha，滤后还原；采样足迹的软边需超出原 UV，二值截断会产生矩形阴影。

来源：UI 经验“受效层、HDR 与像素密度”“景深”；`ui/archive_stage.gd::_resize()`、`ui/materials/archive_book.gdshader`；`tests/godot/test_effect_sampling.gd -- --application` 可定位正式页面接入，缓冲区截图仍不替代最终显示。

## 同样直边，原因可以不同

第一轮纸纹矩形断层由替换 seamless NoiseTexture2D 消除，未证实具体驱动根因；后来的启动 cloud 直边通过逐层输出定位到浮点 sin/dot 格点哈希，整数混合使公共顶点连续。再一次“矩形雾”则可能是失效 Texture2DRD RID。不能仅凭形状复用 CanvasGroup 修复、压暗背景或指认 GPU 精度。

先关闭／单独输出相邻层，保留同条件前后图，再查边界采样、透明裁剪、格点连续性和资源引用。改动应针对已复现层；没有证据的底层机制标作未知。当前 `ritual_atmosphere.gdshader::hash2()` 及 `test_feedback_presentation.gd -- --ritual-boundary` 是格边核对入口；它不证明所有驱动都相同。

来源：UI 经验“连续背景”；`docs/FLUID-EFFECTS.md`“求解与成本”；`docs/STAGE-SUMMARY.md`。

## 设置与声音从实际事件收束

滑条每帧保存曾反复同步 I/O；程序修改 selected 不发 item_selected，又使默认恢复漏保存。即时更新对应音频总线，拖动收束／防抖再保存；恢复默认屏蔽批量信号、统一赋值后显式保存一次。不为音量变化重建窗口／主题。

长书声与 cooldown／并发上限曾漏掉快速切书。按“实际选择改变”发声，新声取得声部、旧声淡出；序列号阻止旧回调停掉复用的新声。可 kill 的 Tween 不以 await finished 作为唯一收尾路径，书声特例不扩散到所有 cue。

来源：UI 经验“音效”“设置”；`audio/archive_audio.gd`、`app/main.gd::_defaults()`／`_volume_setting()`；音频与原件选择查 `development/audio_library/README.md` 和 `docs/audio/README.md`，随机变体不消耗战斗 RNG。
