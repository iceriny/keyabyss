# 原项目体验与迁移落点

> 历史归档：2026-10-08 调整范围前的设计、计划或证据。正文中的要求与“下一步”不构成当前任务；当前实施见[交接文档](../../../migration/AGENT-HANDOFF.md).

迁移前先运行旧版对应流程，再阅读入口、内容定义和素材调用。原项目的产品结构、内容身份、交互规则与既有资产是迁移输入；原生重建不等于重新设计游戏。程序正确、截图已生成和视觉合格分别记录。

本轮实际对照了 `legacy/web` 的首页、四书选择、出征书页、设置、词库、指南、天赋、图鉴、战斗与暂停。旧版通过本机 Vite 与 Python Playwright 运行；原图在 `.temp/legacy-ui-review/`，不能把历史测试报告当作运行观察。

| 原体验与来源 | Godot 落点 | 当前边界 |
| --- | --- | --- |
| `Home.tsx`、`ritual.css` 四书轨道、元素标题、封印书库 | `ui/archive_home.gd`、`game/content/books/*.tres` | 保留 frost / storm / spirit / flame、中文名、介绍、词令与 1–4 选择；主页以选书和准备出征为中心 |
| `art/*GRIMOIR*.png`、`art/runes/*-seal.svg` | `assets/art/books/`、`assets/art/runes/` | 复用四张透明插画、四枚封印源图；不以程序书页图形代替法书资产 |
| `ArcaneBackdrop.ts`、`MenuScene.ts`、`MenuDust.ts` | `ArchiveEffects`、CanvasItem 材质与 `archive_dust.tscn` | 纸面与房间法阵固定布局，光和尘埃独立流动；法书专属封印分层交叉淡入，不因选中索引改变而搬动背景。GPUParticles2D 管理寿命／漂移，画质调整密度，减少动态暂停模拟 |
| `ritual.css`、`desktop.css` 的书影与选书响应 | `ArchiveHome`、`ArchiveStage`、`MotionCurve`、书影与透镜 shader | 保留轨道、景深、浮动和卫星节奏；选书触发 1.3 秒全场景径向折射，摆脱法书控件裁剪；HDR 场景采用 WorldEnvironment 柔光，文字独立清晰绘制；连续换书从当前轨道继续，左右法书均可直接点击 |
| `StartupGate.tsx`、`StartupWave.tsx`、`Sigil.tsx` | `ArchiveGate`、`archive_awakening.tres`、`startup_wave.gdshader` | AnimationPlayer 统一七秒仪式、两次波前与 1.2 / 2.4 / 5.7 秒声音；独立 HDR SubViewport 绘制法阵／标题／64 个 GPU 微光，单次纹理采样施加有界径向折射与同波前光晕。阶段提示在受效层外；首次完成后才能跳过，减少动态直接 240 ms 淡入 |
| `Home.tsx`、`deployment.css` 的左右出征书页 | `ArchiveHome` preparation、`AppSettings` | 650 ms 两翼从中央向两侧展开并淡入，正文不经模糊；原两列难度与说明、词库、渐进词长和种子保存；中央操作与首页 Enter 均能进入单房战斗 |
| 设置、词库的集中浮层与固定头尾 | `PageShell`、`app/main.gd` | 保留书库背景、柔焦遮罩、内部滚动、自动保存、实际导入预览与导出；不以整屏表单代替全部空间结构 |
| `components.tsx`、`effects.css`、`open-ui.css` | `OpenButton`、`ArchiveTheme`、`ui/theme/`、`ui/controls/` | 按旧字号分层；透明按钮、连续细线与柔光、按压响应、词令前缀；控件关键色随所选法书变化。普通 UI 关闭默认焦点与 Tooltip，文本仅点击后编辑；不把文字栅格化进模糊层 |
| `Panels.tsx` 中的 `HelpPanel`、`BuildDemonstrationPanel.tsx` | `GuideContent` | 恢复十节两栏施法说明、五组按键提示和十四条构筑札记；真实构筑演示战斗待后续阶段接入，当前只提供札记选择与词输入练习 |
| `ArcaneCursor.tsx` | `ArchiveCursor` | 原 SVG 箭头、悬停光环与 420 ms 点击脉冲，不截获输入；减少动态停止旋转／扩散 |
| `Shockwave.ts`、`shaders.ts`、`FlameBrush.ts` | `BattleVisuals`、`battle_shockwave.gdshader` | 命中、弹反、终式、内爆与局部热扰动；四波同帧合成并限制总位移，文字与危险提示在受效层外；四书高画质、低画质／减少动态与中画质时序已在实际窗口检查 |
| 12 本 JSON、来源与词义 | `assets/vocabulary/`、`VocabularyRepository` | 数据字节一致、来源说明、词长筛选、五类导入与 JSON 导出；主动上游同步生成独立同步版，完整成功后替换，失败保留离线版 |
| `Targeting.ts` 首字母锁定、同前缀切换、继续输入换目标 | `TypingSession`、`InputRouter` | Tab / Shift+Tab 保留前缀；下一字符可转向匹配候选；继承前缀不重复发人工回执；鼠标重选和放弃重置 |
| 原输入玩法的教学练习 | 指南 → 练习咒文 | 用于验证输入与暂停，不能作为战斗主入口，也不记永久成长 |
| `sound-cues.ts`、Web FLAC 片段、`ThreeAudioSystem.ambient()` | `ArchiveAudio`、`BattleAudio`、`assets/audio/` | 12 类 UI cue、27 个原片段与原四秒氛围循环；切书 50 ms 交叉淡出；战斗 24 类 cue、14 声部上限、威胁总线与峰值采样；完整远征混音属于 M5 |
| 战斗 HUD、四书主术／终式、防御、敌人和场地 | `BattleSession`、`BattlePage`、`BattleVisuals` | 1920×1080 统一设计空间、三波九敌单房；人工输入收入、强化、终式、弹反、闪避、致死后效及胜败通过逐书完整窗口流程；人物折面与状态材质、原生粒子和火焰已结合源代码及旧版运行对照 |
| 天赋、遗物、图鉴、成长图、奖励、事件与记录 | M3–M5 内容及正式入口 | 未移植部分仍保留旧源；不做空入口、不用四书说明充当完整图鉴 |

UI 补充、文案和新资源必须解释其对应的原体验或当前正式设计。若确需改变产品语义，先说明改变理由，不能把实现方便作为迁移中删除玩法的依据。

主题色以共享、可中断的 0.9 秒过渡传播到场景与控件，悬浮权重共同驱动亮度和清晰度；后排景深结合 mipmaps 与九点柔化。实际踩坑、原因与原生取舍集中维护在 [UI 迁移实践](../../../migration/UI-IMPLEMENTATION-LESSONS.md)。

窗口默认 1920×1080，设计坐标同为 1920×1080。先读旧源码理解触发、节奏、受效范围和视觉身份，再选择 Godot 原生实现；不把 Web 渲染结构、SVG 滤镜、固定粒子轨迹或 CSS 数值当成引擎契约。空间扭曲使用原生 HDR 线性采样与柔光，强度和波宽在 Godot 中调节；不经整屏 sRGB 往返模拟浏览器混合。粒子、时序、材质分别由 GPUParticles2D、AnimationPlayer 和 CanvasItem shader 承担。判断标准是实际窗口里的可读性、响应与质感，截图不能代替动态观察。

入场的 SubViewport 随 ArchiveGate 销毁；跳过时暂停 AnimationPlayer 与粒子模拟，从当前状态淡出并取消后续声音。主菜单另由 ArchiveStage 在实际像素密度的 HDR SubViewport 中合成场景，再做全幅折射，正文和可操作提示独立绘制。背景纸纹使用无缝 NoiseTexture2D，避免插值噪声格在实际 GPU 画面形成矩形断层。辉光指柔和的扩散光，不以高亮描边或模糊文字代替。战斗扭曲使用自己的表现层与有界位移，不直接复用整个入场渲染层。菜单不启用默认 Tab／方向键焦点遍历；主页左右键切书，Enter 进入战斗，准备书页仍可用鼠标设置。战斗 Tab 属于目标切换玩法。

## 视觉取证

Godot HDR 2D 的 ViewportTexture 返回线性图像，直接保存 PNG 会偏暗。取证在高精度像素上调用 `Color.linear_to_srgb()`，再写入 RGBA8，避免先量化造成暗部色阶损失。应用测试和生成的 MCP 预览桥使用同一方法；不据偏暗截图修改游戏曝光。参见 [Godot 4.7 ViewportTexture 文档](https://docs.godotengine.org/en/4.7/classes/class_viewporttexture.html)。

本轮旧图、资产调用盘点、原生截图与检查报告属于局部 M1 证据。全游戏的视觉、手感、内容和难度验收仍按迁移阶段逐项完成。
