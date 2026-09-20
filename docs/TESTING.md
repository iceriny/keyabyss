# 原生战场验证（2026-09-20）

环境：Windows、Node.js 24.19.0、Python / Playwright、本机无头 Chrome。测试使用独立浏览器配置与测试存档。

## 冲击波方向与传播（最新）

构建、138 项单元检查通过；冲击波 GPU 探针 3 组、弹反原生渲染回归 2 组通过。验证实际合成取样方向、内爆/外扩、中心稳定、连续帧半径、场类型、减少动态效果及文字清晰度。详见 [SHOCKWAVES.md](SHOCKWAVES.md)，截图与结果位于 `test-output-shockwave/`。

## 弹反与文字稳定性

构建、136 项单元检查通过；UI 12 组、文本 5 组、原生弹反/文字 2 组、音画反馈 3 组共 22 组浏览器检查通过。验证正文悬停与同段去重、键盘不触发提示、长距离反制与周边无伤控制、时缓恢复、文字固定锚点与覆盖命中、GPU 位移与减少动态效果。证据在 `test-output-counter/`，实现见 [COUNTER-AND-READABILITY.md](COUNTER-AND-READABILITY.md)。

## 统一文本与术语提示

构建、内容、TypeScript 和架构检查通过；132 项单元检查通过。12 组 UI 回归与 5 组文本/Tooltip 浏览器检查通过，覆盖共源说明、最长术语匹配、数值染色、搜索分类、提示移入阅读和关闭、边缘避让、低档/减少动态效果与战斗输入。窄屏验证发现的主菜单遮挡已修复并复核。截图见 `test-output-text/`；说明见 [TEXT-AND-TOOLTIPS.md](TEXT-AND-TOOLTIPS.md)。

## 手动导航、闪避与法阵更新

构建、TypeScript、架构与内容检查通过，129 项单元检查通过。此次更新旧纸灵数量与组合闪避断言，并记录雷鸣/纸灵的新平衡轨迹 `ritual-baseline.json`；寒霜/灰烬旧轨迹保持一致。

32 组浏览器检查通过（UI 12 / 首屏 6 / 防御 7 / 菜单 4 / 本轮综合 3）。新增 `python -X utf8 tests/ritual-browser.py` 检查手动焦点顺序、跳过次要操作、隐藏系统鼠标、自制光标不挡点击、独立音效总线、方向键/Alt 直放与重复抑制、弹反双层位移，以及首屏和菜单粒子。1080P 证据见 `test-output-ritual/`；发行仍为 146 个校验文件，约 53.35MiB。相关检查通过后没有追加无关检查。

## 音效并发历史检查

构建通过。`python -X utf8 tests/audio-polyphony-browser.py` 验证 48 个空间声源和 16 个非空间声源真实同时播放、满额拒绝、优先级替换、空间单类 6 路/命中与打字 8 路限制，以及停止后零活动声源。证据见 `test-output-audio/polyphony.json`。

`npm run test:audio -- --runtime-only` 6 组通过，覆盖真实 HRTF、全部 112 个片段解码、并发与缓存、暂停、静音和释放，报告为 `test-output-audio/runtime-report.json`。切片编辑器依赖本地开发服务器，与本轮播放并发改动无关，未重新验收。声源数与解码并行数是两个独立预算；后者仍为 4。

## 开放式下拉与菜单原生特效历史检查

正式构建、应用与工具 TypeScript、架构边界检查通过。`test:menu` 4 组、`test:startup` 6 组、`test:ui` 12 组真实 Chrome 检查通过，合计 22 组；发行包含 146 个校验文件，约 53.31MiB。

新增检查直接读取原生画布像素，确认着色器确实绘制并随时间变化；检查四法书与 SVG 的离线加载、仅两次菜单绘制调用、下拉模糊与键盘焦点、720P 锚点更新、系统减少动态静止，以及出征/回营共用一个 WebGL 上下文。1080P 主菜单、下拉列表和 720P 截图见 `test-output-menu/`。现有 UI 套件的首屏等待同步为过渡完成后再输入，避免旧检查把过渡中的菜单挂载误判为已经可操作。相关检查通过后未扩大测试。

## 入场、弹反与打字反馈历史检查

`node --test tests/defense.test.cjs tests/audio.test.cjs` 16 项通过；`npm run test:feedback` 3 组、`npm run test:audio` 7 组、`npm run test:startup` 6 组通过。验证 1.6 秒入场及声音、过渡期间菜单输入隔离、连续词令/施法字符音效与短音释放、起手/成功声音区分、同时反射 5 枚弹道只触发一次成功反馈、三级前景特效和减少动态。1080P 截图与报告见 `test-output-feedback/`。音频回归覆盖全部 112 个切片的实际解码与 HRTF 输出。

应用与工具 TypeScript、架构边界检查及正式构建通过，发行包含 142 个校验文件，约 53.30MiB；其中按需音效约 37.95MiB。相关检查通过后未扩大到无关套件。

## Magic UI 音效历史检查

124 项单元检查通过，包含 4 项切片/引用/发布检查；`npm run test:audio` 7 组真实 Chrome 检查通过：离线 UI 预热、战斗按组加载、真实 HRTF 左右 PCM、暂停/静音与并发限制、全部 108 个变体解码、隐藏与释放、编辑器试听和保存。应用及工具 TypeScript 与正式构建通过。输出 138 个校验文件，共约 52.94MiB；音效 108 个文件约 37.59MiB。证据见 `test-output-audio/report.json` 和 `test-output-audio/editor.png`。

下方为此前各轮记录，没有重复执行无关浏览器套件。

## 首屏历史检查

`npm run test:startup` 6 组和加载回归 4 组通过：加载中输入不会排队、提示不是按钮、四角点击、字母 / 数字 / 空格 / Enter / Esc / 方向 / Shift 进入、首次输入不传入首页、真实符印动画、窄屏与减少动态。启动截图与报告位于 `test-output-startup/`。发行构建通过，共 30 个校验文件，约 15.24 MB。

## 本轮防御与界面

120 项单元检查、31 组浏览器检查（防御 7 / UI 12 / 加载 4 / 全屏 8）以及完整构建通过。设计、参数与 68 场规则输入探针见 [DEFENSE-AND-PACING.md](DEFENSE-AND-PACING.md)。新增截图在 `test-output-defense/`；此轮没有重新测量性能，下方性能与未重跑的架构 / 火焰 / 原生完整视觉套件保留为前轮记录。

## 检查结果

| 检查 | 结果 / 入口 |
| --- | --- |
| 内容与架构边界 | `validate:content` 通过；dependency-cruiser / SWC 扫描 216 个模块、549 条依赖，无违规 |
| 构建与 TypeScript | `npm run build` 通过；离线 index.html + 12 本词库脚本及 12 个完整 JSON + 原生渲染脚本 + 四张法书图片，共 30 个校验文件，约 15.23 MB |
| 玩法、素材、词库与键盘逻辑 | `npm test`，120 项通过 |
| 内容扩容与资源释放 | `npm run test:architecture`，6 组通过；`test-output-native/architecture-report.json` |
| 页面与输入回归 | `npm run test:ui`，12 组通过；`test-output-native-ui/report.json` |
| 原生战场视觉与生命周期 | `npm run test:visual`，11 组通过；`test-output-native/report.json` |
| 加载取消 / 重试 / 开发模式 | `python -X utf8 tests/loading-browser.py`，4 组通过；`test-output-native/loading-report.json` |
| 四本插画、音频导入与火焰实战 | `npm run test:flame`，6 组通过；`test-output-flame/report.json` |
| 全屏边缘、分级效果与完整词库 | `npm run test:fullscreen`，8 组通过；`test-output-fullscreen/report.json` |

当前截图位于 `docs/test-output-native/`、`docs/test-output-native-ui/` 、`docs/test-output-flame/` 和 `docs/test-output-fullscreen/`；带 v2–v6 的旧目录保留为历史记录。

## 本轮架构迁移回归

A–F 完成时曾验证三本法书的 180 帧迁移前轨迹一致。本轮扩大场地并更改选词算法，旧种子的具体轨迹随之改变；现以独立固定词表记录四本法书 240 帧新基线 `defense-baseline.json`（本轮难度重调），前轮 `fullscreen-baseline.json` 和旧 `architecture-baseline.json` 保留为历史证据。新增验证涵盖第四本法书实际施法、组合敌人和任意 ID 精英、四房间两波章节、乱序目录中的分支路线及下一周目、自定义 Boss 阶段与攻击、遗物修饰/触发/能力组合、来源失效、必需任务阻止清房、词条占用回收、独立提示游标、依赖预热及旧存储兼容。详见 `tests/architecture.test.cjs`。

6 组架构浏览器检查验证旧玩法全局对象不存在、43 个外观（27 个内置 + 16 个测试扩展）自动分为两页、第二页角色改变实际 GPU 像素、跨页透明角色保持排序且不改世界数组、图集不重复上传、销毁解除监听与清房回收粒子。UI、原生画面及加载套件也已通过。

## 素材与火焰扩展回归

新增 10 项单元检查覆盖图片 / 音频缓存、失败重试、取消和资源释放，以及火焰弹道的词条占用、灼烧周期与叠层、熔爆、死亡传播深度、闪避火场、专属遗物、觉醒终式与重新开始。四法书采用本轮全屏与索引选词的新轨迹基线。

6 组火焰浏览器检查验证四张原始透明图片在首页、选择卡和图鉴中加载，并逐字节对比 art 与发行文件；使用内存生成的 WAV 验证本地文件导入、浏览器真实解码、用户手势播放和释放停止。火焰实战验证实际弹道命中、灼烧与火场、终式和陨火的 GPU 实例像素、暂停逐像素一致，以及 720P 减少动态时关闭热扭曲。发行物没有新增音乐文件。

## 全屏与词库回归

新增 7 项单元检查覆盖边缘攻击与冲锋禁用、驻地单位进入清晰区、持续激光 / 落点预警 / 延迟来源取消、道具位置、边缘死亡能力、God Mode、5 万词索引抽样及完整源数量。索引构造后禁用整库遍历方法，验证选词在候选耗尽和重复随机值下仍可完成。

新增 8 组浏览器检查通过真实词令激活 God Mode，并出征加载 2,607 词完整四级库；截图差分确认边缘单词受模糊且中心像素不变。三级特效的原生实例数量、位移 / 辉光尺寸、前景层级均检查；动态背景暂停逐像素一致，720P 减少动态禁用扭曲。报告在 `test-output-fullscreen/report.json`，使用与复杂度说明见 [全屏与词库实现](FULLSCREEN-AND-VOCABULARY.md)。

## 视觉与资源证据

- 1920×1080 主场景，960×540 位移与辉光，2048×1024 角色图集；启动页预热 Three.js 战场，完成后点击继续。
- 直接通过 `file://` 加载发行物，无 HTTP 请求或着色器错误；GPU 实体目标中实际存在非透明像素。
- 待机、打字聚光、普通命中、引力，以及三本法书的真实终式均有截图。
- 开关位移图时环境像素变化，独立文字 Canvas 的像素数据完全一致。
- 17 种敌人和三个 Boss 的图集剪影、纸灵、冰晶和闪电均渲染；运行中纹理数量保持 15（含辉光金字塔与 Quarks 光斑），图集 version 保持 1，无逐帧上传。
- Quarks 粒子确实发射；暂停反复重绘时 GPU 实体缓冲逐像素一致，寿命结束归零且纹理数量稳定。
- 暂停停止渲染；WebGL 上下文真正丢失后暂停玩法，恢复后重新预热。
- 720P 与减少动态可用；DPR 2 / 1080P 下世界仍为 1920×1080，文字画布独立为 3840×2160。
- 启动页脚本失败后可以重试；加载中取消不会在异步完成后误入战斗，再次出征复用资源。
- 无 WebGL 2 时显示加载错误、保留重试入口，模拟不会启动。
- Vite 开发入口可延迟导入同一个渲染器。

## 完成改造后的统一采样

同一浏览器、1920×1080、DPR 1、完整特效。每个场景预运行 350 ms，再采样约 2.2 秒。保留真实模拟和画面更新，不再冻结 `update()` / `updateVisual()`。密集场景以 24 个敌人、96 颗初始子弹开始；多个场景含 6 个环境场。结果为短时回归样本，不是长时稳定性或其他机器帧率结论。

| 场景 | RAF FPS | 帧间隔 P95 | CPU 渲染提交 P95 | 绘制调用 |
| --- | --- | --- | --- | --- |
| 真实战斗 | 60.2 | 16.8 ms | 1.1 ms | 18 |
| 密集弹幕 | 60.2 | 16.8 ms | 1.2 ms | 21 |
| 多个场效果 | 60.3 | 16.8 ms | 1.2 ms | 19 |
| 终式 | 60.0 | 16.8 ms | 1.1 ms | 18 |

CPU 提交包括引擎 `render()` 与独立文字层工作，不等于 GPU 执行耗时。样本受浏览器刷新节奏约束，当前没有 GPU timer-query 分项归因。旧 1440×900 冻结 Canvas 样本不作为这次的同条件对比。

## 复现

```powershell
npm ci
npm run build
npm test
npm run test:architecture
npm run test:ui
npm run test:visual
npm run test:flame
npm run test:fullscreen
# 如只需重新采样：npm run test:performance
```

加载 / 开发模式检查需先在另一个终端执行 `npm run dev`（默认 4318），再运行 `python -X utf8 tests/loading-browser.py`。浏览器依赖见 `requirements-dev.txt`。旧 `visual-upgrade-browser.py` 与 `performance-browser.py` 入口转向当前原生套件。
