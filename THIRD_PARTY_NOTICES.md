# 第三方工具、数据与素材

本项目代码使用 GPL-3.0-only，见 [LICENSE](LICENSE)。当前 Godot 根工程已完成 M1，本说明区分活动依赖与冻结的 Web 实现。

## Godot 与开发工具

- Godot 4.7.2 .NET：Godot Engine 的 MIT 许可及其第三方依赖信息见[官方许可](https://godotengine.org/license/)和[版权清单](https://github.com/godotengine/godot/blob/4.7.2-stable/COPYRIGHT.txt)。正式发行需随包提供相应声明。
- tugcantopaloglu/godot-mcp 3.1.0：MIT，固定提交 `fcbc29e03297900b9a1fcc6c7cbae116fe9d532a`，来源及本地安装见[工具链](docs/migration/TOOLCHAIN.md)。只在开发预览中运行，不随游戏导出。
- Node.js、PowerShell、Codex 与项目 Skills 是开发工具；Godot GDScript 游戏不依赖 Node 或 MCP 运行。

## 字体与原始素材

当前活动工程复用仓库已有的汇文明朝体及京華老宋体 v3.0 TTF，来源路径与复制关系见[资产映射](docs/migration/DATA-AND-ASSETS.md)。原仓库未完整记录两套字体的原始发布地址与许可文本，正式分发前需补齐；不据“仓库已有”宣称字体属于原创或已获任意分发授权。

四张法书 PNG 与四枚封印 SVG 已从 `legacy/web/art/` 原样复制到 `assets/art/`。原插画在旧声明中标记为用户提供；封印的生成来源为旧 `tools/generate-runes.ts` 与 `art/runes/README.md`。

`assets/audio/ui/` 的 27 个 WAV 由 `tools/godot/import-ui-audio.mjs` 从原 Web FLAC 片段解码生成，覆盖 12 类 UI cue；原声音来自 BOOM Library Magic UI Designed，原元数据标记为 © 2026 BOOM Library / All Rights Reserved。生成器移除不合 UTF-8 的 WAV 元数据，不改变该来源与权利归属。当前进行本地开发复用；正式分发前需要补齐项目对应的音频授权资料。原音频索引、片段映射及源 WAV 保留在 `legacy/web/`，不适用旧声明中“纯合成音频”的描述。氛围底音则从旧 `ThreeAudioSystem.ambient()` 的公式转为原生 PCM 循环。

## 旧 Web 实现与词库

既有 React、Three.js、Web 工具依赖、Qwerty Learner 与 CMUdict 等词库声明保存在 [legacy/web/THIRD_PARTY_NOTICES.md](legacy/web/THIRD_PARTY_NOTICES.md)，完整许可在 `legacy/web/licenses/`，词库出处和哈希在 `legacy/web/data/sources.json`。

M1 已将 12 本词库 JSON 原样生成到 `assets/vocabulary/`；[来源记录](assets/vocabulary/sources.json)和[生成哈希索引](assets/vocabulary/index.json)保留原始出处，许可文本仍完整保存在上述 `legacy/web/licenses/`。生成工具只复制快照，Godot 在加载与用户导入边界规范化词形，不改写源 JSON。

旧声明中的浏览器音频、字体和渲染描述不作为当前 Godot 工程的事实。正式发行仍需将实际使用的数据及引擎许可文本随发行包整理。
