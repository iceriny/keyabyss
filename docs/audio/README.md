# 原始音频索引与原生接线

## 查找素材

- [原件详情](original-audio-details.csv)：144 个 WAV 的原文件路径、素材介绍、分类、实测时长、采样率、声道、位深、大小、变体数、旧事件引用及原表来源字段。
- [有效切片](original-audio-slices.csv)：576 段切片的零起始编号、起止时间、长度及旧事件引用。人工修订的边界优先于自动检测。

两表使用 UTF-8 BOM，可直接在表格软件中打开。原件位置为 `legacy/web/art/Magic UI Designed/`；CSV 是索引，不复制或改写原始音频。未被引用的原件不进入 Godot 发行资源。

```powershell
# 校验原件规格并重新生成两份索引；需要 ffprobe。
node tools/godot/audio-inventory.mjs

# 使用旧切片工具查询描述、边界，或导出一个原规格 WAV。
node legacy/web/tools/audio.ts query "Shimmer"
node legacy/web/tools/audio.ts export "DSGNWhsh_WHOOSH LIGHT-Shimmer_B00M_MUIDS.wav" 0 ".temp/shimmer-source.wav"
```

导出目标不得已经存在。完整切片台、手工标记方法与工具来源见[原音频系统文档](../archive/AUDIO-SYSTEM.md)；其中的浏览器运行和历史验收结论不代表 Godot 状态。

## Godot 使用方式

`tools/godot/import-ui-audio.mjs` 与 `import-battle-audio.mjs` 解码旧工程已选择的 FLAC 切片，生成 `assets/audio/ui/` 和 `assets/audio/battle/` 下的原生 WAV。运行时不依赖 Node、FFmpeg 或旧 Web 音频模块。

| 语义 | 表达 |
| --- | --- |
| 四书施法、命中、终式 | 各用原有独立音色，每类三个源变体，不连续重复；声音随机数独立于战斗种子 |
| 弹反 | 短起手、成功金属撞击与柔和共鸣尾音，后者限长 0.8 秒 |
| 强化施法 | 雷系强化的能量层、火系强化命中的爆发层，保持常规施法辨识 |
| 近战 | 与主动挥击同时出现的短掠风声，预警仍先于打击 |
| 纸灵召唤 | 克制的灵性出现声，与普通命中分开冷却和控制尾音 |
| 下拉选择 | 翻页式短音，沿用三变体 |
| 出征 | 收束的起势声与揭幕时的轻共鸣；减少动态采用短确认声 |

`BattleAudio` 只消费已提交事件。打字、受伤、就绪和结果居中；世界事件保留位置。最多 14 个战斗声部，预警、防御、受伤和终式优先于普通命中。暂停清空战斗声部，UI 声音仍由独立服务控制。

原件是 96 kHz / 24-bit 立体声；当前游戏 WAV 来自旧版重采样切片，使用 16-bit PCM。CSV 所列原件规格不能用来描述导入后的游戏文件。素材许可状态仍以阶段总结为准。
