# Git、资产与跨设备开发

键渊使用两个仓库：[公开代码](https://github.com/iceriny/keyabyss)与[私有资产](https://github.com/iceriny/keyabyss-assets)。代码的 `asset-lock.json` 固定完整资产提交和清单哈希；相同代码版本在不同设备恢复相同素材。资产二进制通过 Git LFS 上传，实际工程路径保持不变。

## 首次准备

需要 Git、Git LFS、Node.js 22+、PowerShell 7、Godot 4.7.2 .NET、.NET SDK 9.0.201。Git 登录账号须能读取私有资产仓库；可以使用 Git Credential Manager，或可选的 GitHub CLI 登录后执行 `gh auth setup-git`。认证与机器路径不进入项目。

```powershell
git lfs install
git clone https://github.com/iceriny/keyabyss.git
Set-Location keyabyss
node tools/dev.mjs setup
Copy-Item tools/godot/local.paths.example.json tools/godot/local.paths.json
# 填写本机 Godot console.exe 路径。
pwsh -File tools/godot/godot.ps1 doctor
pwsh -File tools/godot/godot.ps1 import
pwsh -File tools/godot/godot.ps1 run
```

已经存在的路径配置不用再次复制。默认完整恢复全部开发素材；不需要手动克隆第二个仓库或抄写提交号。工具会在项目旁建立 `keyabyss-assets`，不会把嵌套 Git 仓库放进 Godot 工程。引擎、SDK 与可选 MCP 的精确安装方式见[工具链](migration/TOOLCHAIN.md)。

| 准备范围 | 首次命令 | 覆盖内容 |
| --- | --- | --- |
| 完整开发 | `node tools/dev.mjs setup` | 游戏资源、完整音频库、原件、未选用字体／图片及旧 Web 素材快照 |
| 游戏代码开发 | `node tools/dev.mjs setup runtime` | 当前选用的音频、字体和法书插画；其他活动资源来自代码仓库 |
| Agent 重新选音 | `node tools/dev.mjs setup library` | runtime 加全部 576 个独立片段和片段哈希；四字段映射与制作规则来自代码仓库 |

降低准备范围不会移除已下载原件。没有私有访问权限时工具明确报错；没有占位素材或跳过缺项的成功结果。

## 日常交接：两条命令

在前一台设备完成修改并推送，再在下一台拉取，同一项工作继续同一分支。

```powershell
# 开始工作：
node tools/dev.mjs pull

# 修改代码、选择音效或编辑素材后：
node tools/dev.mjs push "说明本次修改"
```

`pull` 检查代码与托管素材的本地修改，再以 fast-forward 拉取当前代码分支，并同步该代码锁定的资产版本；沿用上次准备范围。需要扩大范围时执行 `setup library` 或 `setup`。

`push` 检查远端是否已有别人提交，再收集配置目录内的新增／修改素材：提交资产 → 上传 LFS 与资产提交 → 自动更新代码锁 → 同步校验 → 提交并推送当前代码分支。没有资产变化时复用原版本；没有任何变化时不制造空提交。无需分别操作两个仓库。

该命令会提交当前工作区所有未提交代码变化，使用你提供的提交说明。想分成多个主题提交时，可先用普通 `git add`／`git commit` 整理，再执行 `push` 完成交接。它不会自动合并其他人的变更，也不会强制推送。网络失败时保留已有提交，修复网络后重试；资产先成功、代码后失败时不会产生引用不存在素材的公开版本。

主线为 `main`，功能使用 `codex/任务名` 等短期分支，通过 PR 合入。换设备前不只保存 stash；另一台需要同一远端分支。已推送的共享历史不重写。

## 素材如何保存与选用

公开仓库存放 GDScript、C#、场景、Resource、JSON、SVG、文档、自有纹理、制作工具和规则。`.gd.uid` 与旁置 `.import` 设置一起提交；`.godot`、日志、工具安装、导出物、凭据和 `.delete` 不上传。

私有资产覆盖商业音频、字体与法书插画的原件和游戏用版本，包含未被游戏引用的素材。全部 144 个商业 WAV 原件、576 个有效片段、当前 196 个选用片段、23 个字体及附带 PDF／XLSX 都有去向；设计用 SVG、PNG 样张和生成脚本在公开代码中保留。旧 Web 被忽略的素材与生成包装作为冻结快照随 authoring 恢复，不作为当前音频制作的输入。

`tools/assets/private-paths.json` 声明自动收集目录与制作结果。新增片段、原始 WAV、已有字体目录内的新文件会自动纳入；引入其他类别的私有素材时，添加对应规则和精确忽略路径，不粗略忽略整个 `assets/`。首次迁移盘点同时覆盖 tracked、untracked 和 ignored 文件。

音频选择使用[四字段映射](../development/audio_library/index.csv)：文件、声音描述、时长、变体组。选择后改 `audio/cues.json`，运行：

```powershell
node tools/audio/build-game-audio.mjs build
node tools/audio/build-game-audio.mjs verify
node tools/dev.mjs push "调整音频接线"
```

制作片段需要 authoring：修改 `development/audio_library/segments.json` 的明确采样帧边界，运行 `node tools/audio/library.mjs build` 与 `verify`，再用同一个 push 入口。WAV 原样复制，不转码；Godot 通过提交的导入设置生成本机缓存。选用文件直接位于 `assets/audio/clips/`，不在游戏启动时复制。

开发工程中的素材是受清单管理的工作副本；私有仓库是云端权威来源。同一 SHA-256 共用一个实际文件，清单为不同用途恢复对应路径。修改通过显式 push 收回资产仓库，不让两份副本分别编辑、分别发布。音频原件与片段不是重复文件，不能删掉原件只留成品。

词库以 `assets/vocabulary` 为活动快照。默认 `node tools/godot/import-vocabulary.mjs` 验证并重建本地哈希索引；只有明确提供 `--source directory` 才从其他准备好的目录导入，不再隐式依赖旧 Web 目录。

## 检查、更新与冲突

精细操作入口仍可单独使用：

```powershell
node tools/assets/assets.mjs status --profile authoring
node tools/assets/assets.mjs verify --profile authoring
node tools/assets/assets.mjs sync --profile authoring
```

status／verify 可以使用已经缓存的锁定清单离线核对，不下载、不写入资产。sync 先克隆／获取指定 Git 提交，按范围分批下载 LFS，校验全部源文件和目标，再安装。目标存在本地修改时整批停止；安装异常回滚旧文件与旧状态，退休的未修改托管文件移入 `.delete/assets/`。切换版本不会覆盖无关文件或同步 Godot 缓存。

日常直接修改工程文件后 push 即可。若提示资产仓库有直接编辑，先处理那里的变化，避免同时编辑工作副本：
1. 将直接编辑的原件及输出复制回清单对应的工程路径，并将资产仓库的改动正常提交。
2. 用 `capture(root, repo)` 重新生成清单；该函数在 `tools/assets/capture.mjs` 导出。检查并提交资产与清单，执行 `git lfs push origin main` 和普通 push。
3. 用同文件导出的 `writeLock(root, repo)` 固定已上传提交，再执行 sync、检查与代码提交。不要只修改提交号，遗漏清单哈希。

这条低层流程只用于直接资产仓库编辑或独立资产分支的维护。常规 Agent 开发和素材制作均使用工程路径与两个日常命令。

## 历史、验证与备份

本次只整理尚未上传的两个提交，保留玩法／视觉基线与算法优化主题；原始提交保存在本机备份引用。上传的规则基线为 `c39c032`，与原记录 `9f3539b` 的规则源码相同，比较工具默认使用上传基线。已有公开历史中的字体／音频仍在历史中；从当前版本停止跟踪不表示撤回旧公开副本。本次不强制推送、不改写已发布历史。

跨设备恢复验收使用从 GitHub 克隆的代码、独立空 LFS 缓存及完整 authoring 同步，核对实际字节和哈希，再导入 Godot。同步工具的回归覆盖本地修改保护、来源错误、范围切换、退休文件及安装回滚；具体完成证据见[阶段总结](STAGE-SUMMARY.md)。干净目录验证不等于已经在第二台硬件上做了性能或玩法验收。

备份必须同时包括 Git 历史和实际 LFS 对象；只有 Git bundle 或 LFS 指针不能恢复素材。本机私有资产 checkout 保留实际文件和对象，独立 Git 备份与原始盘点放在本地证据目录。后续备份应复制私有资产仓库的实际对象存储，并抽查恢复；不将本机备份推送到公开仓库。

LFS 下载范围决定传输量：完整原件和片段库首次较大，普通开发可只取 runtime；没有变化的文件不会再保存一个素材版本。账号实际配额以 GitHub 账单为准，工具不会自动购买额度或开设另一套存储服务。
