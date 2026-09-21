# 键渊 · 失控咒典

**0.6.0 · TypeScript + Vite + React · 离线打字肉鸽**

直接打开 `dist/index.html` 游玩，并保留同级 `assets`、`word` 和 `audio` 文件夹。应用包含 React、Three.js、样式、词库与许可证，启动时预热战场，词库按出征阶段加载，无需安装、服务器或联网。开发入口 `index.html` 由 Vite 处理，不能直接双击运行。

## 核心规则

**不需要兼容小屏（移动端）布局。** 项目面向桌面键盘与鼠标操作，以 1920×1080 为主要视觉基准；默认不新增或维护移动端布局、断点、触屏交互及小屏适配测试，也不为移动端压缩桌面视觉效果。桌面窗口缩放、内容滚动及减少动态效果按实际需求处理。

开发与 Agent 执行规则见 [AGENT.md](AGENT.md) 和 [AGENTS.md](AGENTS.md)。历史移动端兼容记录不构成后续要求，用户当前明确指令优先。

## 开始冒险

Magic UI 音效已接入 UI、四本法书与战斗反馈，使用 Three.js 原生 HRTF 空间声音。素材的切片、试听、边界编辑和按需构建见 [音效工具与系统](docs/AUDIO-SYSTEM.md)。运行开发服务器后，可打开 [音效切片台](http://127.0.0.1:4318/tools/audio-preview.html)。

加载完成后点击任意位置 / 按任意键 → 主界面选择法书 →「准备出征」→ 选择词库与难度 →「进入咒典」。键盘可依次输入 `storm` → `start` → `easy` → `begin`；首次引导再输入 `begin`。

主界面围绕法书与出征设计；词库管理、咒典、玩法和设置位于营地菜单。支持键盘和鼠标。全局默认禁止选择文字，文本输入与粘贴字段例外。

| 操作 | 作用 |
| --- | --- |
| 输入完整词条 | 首字母锁定，完词施法；错字保留进度 |
| Space | 弹反：0.24 秒窗口、0.70 秒冷却，不限次数 |
| 方向键 / Alt | 直接定向闪避 / 自动择位闪避，提供 1 秒无敌 |
| 单独轻按 Shift | 满能量时释放终式；组合键不会误触 |
| Tab / Shift+Tab | 切换匹配当前前缀的目标 |
| Backspace | 放弃当前咒文 |
| Esc | 暂停；菜单中先清空词令，再返回 |
| 菜单上的英文词令 | 敲完立即执行，无需回车 |
| Tab / 方向键 / Enter | 按手动顺序导航 / 确认；跳过次要操作 |

自定义下拉使用 `combobox` / `listbox`，没有原生 `select`。方向键移动，Home / End 到首尾，Enter 确认，Esc 撤销本次浏览并恢复焦点。文本字段 Enter 完成、Esc 恢复编辑前内容；多行文本用 Tab 离开。

四本法书、58 种遗物、三章九场、五档难度与通关后的下一周目保留。设置可调声音、震动、低 / 中 / 高特效等级、大字号咒文与减少动态效果。

## 全屏战场与测试模式

战场铺满视口，边缘逐渐模糊并变暗，边缘敌人禁用能力、道具只在清晰区生成。背景使用差分动画，原生元素特效提供低 / 中 / 高三级，暂停、出征与选择等窗口统一采用开放式刻线布局。

在菜单词令输入 `imsuperman` 开启 God Mode：正常掉血，致死回满，无限终式和闪避；刷新页面关闭。

`npm run sync-vocab` 同步完整词库，构建自动输出到 `dist/word/`。选词使用长度 / 首字母桶及位置索引，不在刷新单位时扫描整本词库。细节见 [全屏、特效与完整词库](docs/FULLSCREEN-AND-VOCABULARY.md)。

## 弹反与战斗节奏

双手打字，无普通移动。空格弹反近身弹道和接触攻击；按方向键直接闪避，或 Alt 自动择位。新增回响护腕缩短弹反冷却、返咒铭文让反击附带法书效果。激光和地面爆炸需要闪避；沙漏减速期间继续打字。普通敌人需接近后发动能力，冲锋需处于能触及玩家的范围。五档节奏与渐进词长已重调，未增加全局攻击配额。详见 [防御与难度设计](docs/DEFENSE-AND-PACING.md)。

## 灰烬之书与素材管理

新增灰烬之书（词令 `flame` / 快捷键 `4`）：火弹附加灼烧，每三次施法释放熔爆，闪避留下火场，终式「焚世余烬」引爆并降下陨火。配套 7 件火焰遗物，包含觉醒「不灭炉心」。

`art/` 中四张法书原图用于首页、选择卡、图鉴与 HUD，构建原样复制到离线资产目录。统一 `AssetManager` 支持图片和音乐注册、预加载、缓存、文件导入、独立音轨及资源释放。接入方法见 [素材管理与火焰流派](docs/ASSETS-AND-FLAME.md)。

## 原生战场重构

- Three.js 直接绘制环境、角色、弹幕和法术。共享角色图集只上传一次，动态对象使用实例化缓冲；不再上传每帧 Canvas 战场。
- 墨雾、断裂刻线、符文、纸片与视差建立层次；加入冰霜结晶、雷电分叉、纸灵尾迹和流派终式法阵。
- `postprocessing` 负责多级辉光，`three.quarks` 负责新增爆发粒子的发射、寿命和批量渲染；图集、实例批次、环境、法术画笔、辉光和粒子分别封装。
- 首页、加载页与终式按钮共用矢量符印，施法面板按打字进度蓄光，选中卡片与能量条具有统一反馈；支持减少动态。
- 局部位移场扭曲背景及少量实体像素，文字独立绘制；屏幕边缘的渐变模糊同时覆盖战场与单词，HUD 保持清晰。
- 1080P 为基准，默认位移与辉光为 960×540；高 DPR 不额外放大战场像素预算。
- 启动时预热渲染资源，完成后点击继续；出征读取选定完整词库，保留取消、重试和缓存。需要 WebGL 2；上下文丢失时暂停，恢复后可继续。

渲染约定见 `docs/ART-DIRECTION.md`；历史改动见 `docs/CHANGELOG.md`。

后续法书、敌人、关卡和遗物的扩展方案见 [可扩展游戏架构设计](docs/ARCHITECTURE.md)。目标设计包含模块边界、内容注册、结算协议和渐进迁移验收标准；A–F 已全部落地，模块边界、扩展步骤与最终取舍见 [架构实施记录](docs/ARCHITECTURE-IMPLEMENTATION.md)。

## 0.4 的调整

- React 统一渲染页面。按钮、选择卡、弹窗、字段、开关、自定义下拉、进度条、统计块与词令提示复用同一套组件。
- 主文案采用 14–20 px 字号，词令最低 12 px；战场咒文默认 22 个设计像素，长词下限 16。移除无用的小字装饰与冗长副标题。
- Three.js 着色器扭曲法书周围的星场；终式对战场图像产生环形折射，最后再绘制清晰词条。低特效和减少动态会关闭战斗折射；WebGL 不可用时采用静态法阵。
- 首局增援等待 3.6 秒，首波不出精英；前三页缓慢升压。每波必须清完，再获得 1.6–2.8 秒喘息；后两波才增加高难度批量增援。
- 普通敌人生命由指数增长改为平缓二次曲线；Boss 章节生命倍率由 1.9 调为 1.7。没有依据玩家表现暗中调速。

## 开发与构建

字体默认使用「汇文明朝体」，小字使用「京華老宋体v3.0」，页面与 Canvas 战场文字统一。发行包内的 `font` 文件夹必须与 `index.html` 一起保留。网页先显示系统字体的小型等待组件，首次访问在两个字体文件完整下载并解析成功后仍停留，用户可开启全屏并点击「继续进入」；成功继续后记录完成，后续访问自动进入原有首屏载入页。启动 HTML、JS、CSS 合计约 6.5 KB，主游戏资源在通过门槛后才请求；失败或超时保留重试入口，不会提前显示游戏画面。

完整字体已压缩为 WOFF2，无需联网字体服务，离线 `file://` 和 HTTP 部署共用同一资源。普通构建只校验已有压缩文件；替换 `public/font` 中的原始字体后，安装 `requirements-dev.txt` 并执行 `npm run fonts:build` 重新压缩。发布时不复制原始 TTF/OTF，避免重复打包。字体 URL 带内容版本号，HTTP 服务器可为 `font/*.woff2` 设置长期缓存。

Node.js 22.18+（本次验证使用 24.19.0）：

```powershell
npm ci
npm run dev
npm run typecheck
npm test
npm run build
npm run test:architecture
npm run test:ui
npm run test:visual
npm run test:flame
npm run test:fullscreen
npm run test:defense
```

`npm run dev` / `npm run serve` 启动 Vite。`build` 先执行内容校验、依赖边界校验和严格 TypeScript 检查，再分别生成带内容哈希的启动 JS/CSS、游戏 JS/CSS 和原生渲染脚本，外置许可证，并校验 `index.html`、词库脚本、原生战场脚本及 public 静态资源的 SHA-256。生产文件可从 `file://` 直接打开。

浏览器集成检查需要 Python 与 Playwright：`python -m pip install -r requirements-dev.txt`。优先使用已安装的 Chrome / Edge；也可 `python -m playwright install chromium`。`test:browser`、`test:keyboard`、`test:regression` 都指向当前的集成套件。

```text
src/main.tsx               React 启动入口
src/input.ts               纯 TypeScript 词令解析器，与 Node 测试共用
src/ui/components.tsx      通用组件、输入归属与焦点导航
src/ui/Home.tsx            法书选择与出征配置
src/ui/Panels.tsx          图鉴、设置、词库与导入
src/ui/Battle.tsx          HUD、遗物、路线与结算
src/ui/Portal.tsx          首页静态矢量法阵
src/ui/App.tsx             页面栈、存储及战斗事件连接
src/rendering/             Three.js 原生场景、实例缓冲、位移与辉光
src/loading.ts            按需词库 / 战场加载与 GPU 预热
src/content/               法书、敌人、遗物、关卡定义及行为
src/content-sdk/           内容注册、校验与行为能力接口
src/contracts/             规则、HUD、渲染视图与命令契约
src/application/           会话控制器与表现适配
src/simulation/            无头战斗系统、遗物能力、调度与战役图
src/platform/              版本化存储与离线词库适配
src/vocabulary/            纯词库解析与选词
src/game.ts                浏览器循环、尺寸与资源生命周期
src/combat/                实体类型、状态工厂与 Web Audio
src/ui/Sigil.tsx           首页、加载页、终式按钮共用符印
src/style.css              统一视觉样式与响应布局
vite.config.mjs            Vite 开发配置（发行打包由 tools/build.mjs 执行）
```

`src` 下手写运行代码全部使用严格 TypeScript / TSX（`allowJs: false`），包含词库解析、战斗模拟、声音、渲染和 UI。构建工具及生成的离线数据脚本保留 JavaScript。已移除旧的 `ui.js` / `interaction.js` 和手工静态服务器。

## 词库与本地保存

随包 12 本词库、合计 95,421 条记录（不同库之间可能重合），来源与覆盖范围见 `data/sources.json` 和 `THIRD_PARTY_NOTICES.md`。小学合并上下册，初中 / 高中合并全套源分册，四六级为完整源文件；CMUdict 是词形挑战库，不是教材或词频表。词库始终与战斗难度独立，游戏不会偷偷换库。

可导入 UTF-8 TXT、CSV、TSV、JSON、JSONL，支持 1–24 位、字母开头的词条及数字、下划线、连字符、英文撇号。文件上限 5 MB / 100,000 条原始记录。先预览再确认，错误和重复有统计；最多保存 20 本自定义库。示例见 `examples/`。

导入在本机解析。仅主动点击「同步源词表」时联网；默认无网络请求、CDN、远程字体或外部图片。设置、词库和最近 50 份战报存于 localStorage，刷新结束当前战局。主菜单与结算页的「远征记录」支持查看阶段、构筑、错词和导出；旧战报兼容读取。存储不足时自定义词库与本次战报仍可在本次会话使用，并可导出备份。

每波普通敌人从随机八向之一主攻，另有 8% 概率从其他方向偷袭；角色周围的金色指示器表示主攻来源，珊瑚红短暂提示表示偷袭。胜负结算、生涯统计与未来天赋接口见 [八向进攻与远征记录](docs/ASSAULT-AND-RECORDS.md)。

验证记录见 `docs/TESTING.md`，难度设计见 `docs/BALANCE.md`，第三方许可见 `THIRD_PARTY_NOTICES.md`。

UI 数值统一染色，带点线的术语支持鼠标悬浮解释；图鉴新增可搜索、分类的术语页。文本与 Tooltip 的扩展方式见 [文本系统说明](docs/TEXT-AND-TOOLTIPS.md)。

