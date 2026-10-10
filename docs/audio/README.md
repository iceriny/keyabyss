# 音频库与原生接线

## 查找素材

Agent 使用[音频库映射表](../../development/audio_library/index.csv)：576 个已切好的 WAV，表中只有文件路径、声音描述、时长和变体组，覆盖全部原件变体及未使用片段。查询、复制到游戏及恢复命令见[音频库说明](../../development/audio_library/README.md)。原始声音介绍沿用英文描述，不把同组变体描述为已经逐个听辨。

以下两表保留原件及旧切片的来源记录，不作为 Agent 日常选音频入口：

- [原件详情](original-audio-details.csv)：144 个 WAV 的原文件路径、素材介绍、分类、实测时长、采样率、声道、位深、大小、变体数、旧事件引用及原表来源字段。
- [有效切片](original-audio-slices.csv)：576 段切片的零起始编号、起止时间、长度及旧事件引用。人工修订的边界优先于自动检测。

两表使用 UTF-8 BOM，可直接在表格软件中打开。原件位置为 `legacy/web/art/Magic UI Designed/`；CSV 是索引，不复制或改写原始音频。未被引用的原件不进入 Godot 发行资源。

```powershell
# 校验原件规格并重新生成两份索引；需要 ffprobe。
node tools/godot/audio-inventory.mjs

# 查找已切好的片段并直接复制到游戏资源目录。
node tools/audio/library.mjs query whoosh-light-shimmer
node tools/audio/library.mjs export whoosh-light-shimmer-01.wav assets/audio/selected/shimmer.wav
```

导出目标不得已经存在。新库以采样帧边界提取原件，无网页格式转换，不依赖旧 FLAC／JS 包装；制作边界与哈希保存于 `development/audio_library/segments.json`。历史切片台见[原音频系统文档](../archive/AUDIO-SYSTEM.md)，不作为新库的使用步骤。

## Godot 使用方式

游戏使用 `assets/audio/clips/` 的196个选中WAV。`audio/cues.json` 将56类操作反馈映射到49个库变体组；`assets/audio/cues/` 的原生 `AudioStreamRandomizer` 各引用四个变体，等概率随机且避免连续重复，不额外随机音高或音量。不同反馈可以共享片段文件，各反馈分别保留轮换历史。`SoundBank` 为播放服务复制池资源，底层音频保持共享；不会消耗战斗会话的随机数。

```powershell
# 修改 audio/cues.json 的组名后，复制选中片段并生成 Godot 资源。
node tools/audio/build-game-audio.mjs
pwsh -File tools/godot/godot.ps1 import

# 校验选用文件与库逐字节一致、池资源和导入参数正确。
node tools/audio/build-game-audio.mjs verify
```

工具不覆盖未记录的本地修改，替换／退出的选用文件移入 `.delete/`。`assets/audio/selection.json` 保存生成内容哈希，不用于运行。跨设备运行只需活动资产；重新选音或生成资源才需要完整音频库。运行时不读取库目录、JSON映射、Node、FFmpeg或旧Web包装。

| 语义 | 表达 |
| --- | --- |
| 四书施法、命中、终式 | 短促施法／命中与较宽终式分开选音；每类四个变体 |
| 弹反 | 短起手；普通成功用锁扣式确认，完美弹反用金属撞击与0.8秒共鸣层 |
| 强化施法 | 雷系强化的能量层、火系强化命中的爆发层，保持常规施法辨识 |
| 近战、敌方射击与激光 | 分别用短掠风、轻魔法爆发与聚束掠风；危险预警优先于普通输出 |
| 纸灵召唤、符文道具、敌方治疗与Boss转阶段 | 各自独立选音，区别于普通命中 |
| 正确字符／错字／换目标／取消 | 战斗正确字符沿用提交回执，错字接既有判定；Tab与点击实际换目标、主动放弃才反馈，自动刷新不发声 |
| 御术／闪避／终式／补全不可用 | 在提交或授权失败处反馈；过期补全意图静默 |
| 菜单与设置 | 准备、页签、难度、连续挑战、暂停恢复与详情打开／关闭在实际变化处反馈；退格、初始化、同值不发字符音 |
| 奖励、重抽、补给、路线与成长 | 真实操作成功后播放专属声音，失败播放拒绝；页面重建不叠打开声，成长保存成功跨等级才播放 |
| 下拉选择 | 实际更换选项用四变体翻页声 |
| 出征 | 收束的起势声与揭幕时的轻共鸣；减少动态采用短确认声 |

`BattleAudio` 只消费已提交事件。打字、受伤、就绪和结果居中；世界事件保留位置。最多 14 个战斗声部，预警、防御、受伤和终式优先于普通命中。暂停清空战斗声部，UI 声音仍由独立服务控制。

原件、库片段与活动WAV均保留96kHz／24-bit立体声。Godot导入缓存采用最高48kHz、QOA、裁剪低于阈值的前后静音、不归一化、不循环；这些设置不改写WAV。高频反馈限制尾音、并发与冷却，切书交叉淡出；随机池没有固定时长，释放按反馈预算和自然结束处理。四秒合成环境底音保留。

当前196个活动WAV共248.11MiB，其Godot音频缓存合计12.94MiB；完整库899.78MiB。跨设备开发传活动WAV，缓存由引擎重建；缓存大小不是已重新导出的发行包大小。

音频回归入口为 `tests/godot/test_audio.gd`：校验原生池实际混音波形与不连续重复，覆盖真实输入、播放生命周期、容量优先级与奖励／路线接线。完整应用段需图形设备，使用锁定CLI `--screen 0 --audio-driver Dummy --max-fps 60 --debug --script res://tests/godot/test_audio.gd --ignore-error-breaks`；不创建试听界面。素材许可状态仍以阶段总结为准。
