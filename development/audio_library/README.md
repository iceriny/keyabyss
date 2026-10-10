# 音频库

576 个独立 WAV，144 个变体组；包含当前未使用的片段。

Agent 从 [映射表](index.csv) 选择音频。每行只有文件路径、声音描述、时长（秒）、变体组；[JSON](index.json) 是相同数据的机器读取版本。路径相对于游戏仓库根目录。描述沿用原件的声音介绍，同组变体共用介绍，具体时长由各片段计算；不编造变体之间的听感差异。

```powershell
# 按声音描述、变体组或文件名检索，输出四字段记录。
node tools/audio/library.mjs query whoosh-light-shimmer

# 将选中的片段原样复制到游戏资源目录，随后按普通 WAV 接入。
node tools/audio/library.mjs export whoosh-light-shimmer-01.wav assets/audio/selected/shimmer.wav
```

同组文件可以轮换使用。复制命令不会覆盖已有文件；目标文件名及游戏事件由使用者决定，不限定素材用途。库目录带 `.gdignore`，避免整套素材进入 Godot 导入与发行；游戏使用复制到 `assets/` 的选中片段。

当前游戏按 `audio/cues.json` 选用整组变体。修改组名后运行 `node tools/audio/build-game-audio.mjs`，将所需片段原样复制到 `assets/audio/clips/` 并生成原生随机池；随后执行Godot导入。查询只需本表，游戏选用与反馈边界见[音频接线](../../docs/audio/README.md)。

## 制作与恢复

```powershell
node tools/audio/library.mjs build
node tools/audio/library.mjs verify
```

需要 Node 22 或更高版本，以及 `segments.json` 指定的原件。构建直接提取原 WAV 中的 PCM 采样帧，保留 96kHz、24-bit、立体声，不重采样、不归一化、不加淡入淡出，也不生成网页音频包装。输出 WAV 仅保存格式与音频采样数据。

`segments.json` 是制作工具的输入，保存来源、原件哈希和有效片段边界；Agent 日常选用只读映射表。边界采用 `[start_frame, end_frame)`，一帧包含两个声道；迁移时沿用已有检测结果及人工修订，秒数四舍五入至最近采样帧。片段 ID 保持不变，增加片段时使用新 ID，不重排已有 ID。同一原件所有片段继承其声音描述。

调整制作数据后运行 `build`，自动更新两种映射表；相同片段不重写。替换或移除已生成片段时，旧文件移入 `.delete/audio-library/`；遇到未收录的本地修改会报出具体文件。`verify` 核对原件哈希、每个片段的采样内容、文件清单与映射表。

`clips/` 与 `.build.json` 在当前公开代码仓库中忽略；切好的文件已在本机生成，跨设备同步应包含它们，不能只传映射表。完整库准备进入独立资产仓库，安排见 [Git 与资产方案](../../docs/GIT-AND-ASSETS.md)。仅有原件时可以重建；没有原件或片段文件时不能声称素材已经就绪。

`migrate` 只用于首次从旧索引和人工边界生成制作数据，现已完成。后续构建、查询和复制均不依赖旧 Web JS 音频或事件定义。
