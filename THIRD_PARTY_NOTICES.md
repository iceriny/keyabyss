# 第三方工具、数据与素材

本项目代码使用 GPL-3.0-only，见 [LICENSE](LICENSE)。本说明区分活动 Godot 依赖与冻结的 Web 实现。

## Godot 与开发工具

- Godot 4.7.2 .NET：Godot Engine 的 MIT 许可及其第三方依赖信息见[官方许可](https://godotengine.org/license/)和[版权清单](https://github.com/godotengine/godot/blob/4.7.2-stable/COPYRIGHT.txt)。该版本原文保存在 `licenses/GODOT_LICENSE.txt`、`licenses/GODOT_COPYRIGHT.txt`，导出脚本随包复制到 `licenses/`。
- tugcantopaloglu/godot-mcp 3.1.0：MIT，固定提交 `fcbc29e03297900b9a1fcc6c7cbae116fe9d532a`，来源及本地安装见[工具链](docs/migration/TOOLCHAIN.md)。只在开发预览中运行，不随游戏导出。
- Node.js、PowerShell、Codex 与项目 Skills 是开发工具；Godot GDScript 游戏不依赖 Node 或 MCP 运行。

## 字体与原始素材

当前字体均来自特里王的[特里活字库](https://huozi.cool/)。2026-10-08 核对作者公开的[字体记录](https://huozi.cool/api/fonts)及[许可配置](https://huozi.cool/api/license-config)：汇文明朝体列为免费商用、允许修改；京华老宋体全系列列为免费商用、不允许修改；两类均包含软件嵌入场景。本项目保留字体原二进制，不将源码 GPL 许可套用于字体。

- `assets/fonts/huiwen-ming.ttf`：内嵌版本 `1.00; January 14, 2021`，版权字段为 `Public Domain`，SHA-256 `1ea5d0450c0d034c3e4077f2b533d74fbd1bf1f14d938477389338e64d3d8d9c`。当前作者网站提供后续 GBK 版；尚未取得 2021 原始发布包的独立许可文件，当前使用范围依据作者系列许可。
- `assets/fonts/jinghua-song.ttf`：内嵌版本 `3.000; June 10, 2025`，`Font © Copyright 2022 TerryWang. All rights reserved.`；SHA-256 `f7fef9fc413e9e2343f0bb432c51cca41c44b8fe37f071dc86b050896ae9f9e2`，与[作者 v3.0 原始下载](https://huozi.cool/fonts/%E4%BA%AC%E8%8F%AF%E8%80%81%E5%AE%8B%E4%BD%93v3.0.ttf)逐字节一致。京華老宋体商标属于 TerryWang／王廷瑞。

四张法书 PNG 与四枚封印 SVG 已从 `legacy/web/art/` 原样复制到 `assets/art/`。原插画在旧声明中标记为用户提供；封印的生成来源为旧 `tools/generate-runes.ts` 与 `art/runes/README.md`。

启动符文环与中心符号来自用户提供的 `docs/art/Arcana384/svg-clean/`，由 `tools/art/build_loading_runes.py` 组合为 `assets/art/ui/loading_runes.svg` 与 `loading_core.svg`；保留原始符形，仅作排布与单色呈现，不将整套字体或文档装入游戏。

`assets/audio/ui/` 的 27 个 WAV 由 `tools/godot/import-ui-audio.mjs` 从原 Web FLAC 片段解码生成，覆盖 12 类 UI cue；原声音来自 BOOM Library Magic UI Designed，原元数据标记为 © 2026 BOOM Library / All Rights Reserved。生成器移除不合 UTF-8 的 WAV 元数据，不改变该来源与权利归属。当前进行本地开发复用；正式分发前需要补齐项目对应的音频授权资料。原音频索引、片段映射及源 WAV 保留在 `legacy/web/`，不适用旧声明中“纯合成音频”的描述。氛围底音则从旧 `ThreeAudioSystem.ambient()` 的公式转为原生 PCM 循环。

## 旧 Web 实现与词库

既有 React、Three.js、Web 工具依赖、Qwerty Learner 与 CMUdict 等词库声明保存在 [legacy/web/THIRD_PARTY_NOTICES.md](legacy/web/THIRD_PARTY_NOTICES.md)，完整许可在 `legacy/web/licenses/`，词库出处和哈希在 `legacy/web/data/sources.json`。

M1 已将 12 本词库 JSON 原样生成到 `assets/vocabulary/`；[来源记录](assets/vocabulary/sources.json)和[生成哈希索引](assets/vocabulary/index.json)保留原始出处，许可文本仍完整保存在上述 `legacy/web/licenses/`。生成工具只复制快照，Godot 在加载与用户导入边界规范化词形，不改写源 JSON。

旧声明中的浏览器音频、字体和渲染描述不作为当前 Godot 工程的事实。导出脚本随包复制本说明、项目 LICENSE、实际词库许可与来源、Godot 许可和版权清单；公开分发前仍需解决上文注明的音频授权资料，并提供对应源码。
