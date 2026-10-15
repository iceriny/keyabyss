# Windows 发布流程

本流程适用于根目录 Godot 工程的 Windows x64 测试包与正式包。导出入口为 `tools/godot/godot.ps1`，发布位置为 `iceriny/keyabyss` 的 GitHub Releases；`preview` 分支和 `legacy/web/` 不使用本流程。

本文规定发布步骤与放行条件，不记录每次发布的完成状态。实际状态见[阶段总结](STAGE-SUMMARY.md)，未完成事项只维护在 [TODO](TODO.md)。工具参数以[工具链](migration/TOOLCHAIN.md)和脚本为准，验证范围以 [TESTING](TESTING.md)为准。

## 1. 选择包的用途

| 项目 | 测试包 | 正式包 |
| --- | --- | --- |
| 用途 | 定向试玩、反馈与问题复现 | 面向玩家的稳定分发 |
| 导出命令 | `godot.ps1 export` | `godot.ps1 export-release` |
| Godot／.NET 配置 | Debug／`ExportDebug` | Release／`ExportRelease` |
| 固定输出目录 | `builds/windows/` | `builds/windows-release/` |
| 诊断 | 默认启用会话日志，附诊断启动与系统记录工具 | 默认关闭会话日志，按需用 `-- --debug-log` 开启 |
| GitHub 标记 | 勾选 Pre-release，不设为 Latest | 正式发布后设为 Latest |
| 放行范围 | 本次测试目标可执行，已知问题和未验证范围明确 | 当前发行范围的玩法、画面、存档、目标机和来源许可均已验收 |

Release 是构建配置，不是验收结论。需要测真实发行性能时，可以把 Release 构建作为候选包，仍标为 Pre-release，并在发布说明中写明构建配置。Debug 测试通过后，必须重新导出并验证 Release，不能把 Debug ZIP 改名作为正式包。

两种配置当前共用 `Windows Desktop` 预设，均生成控制台包装器；预设保留托管调试符号，未启用代码签名。不要把 Release 描述为已签名或已移除所有调试信息。

## 2. 固定版本与输入

### 版本命名

| 对象 | 约定／示例 |
| --- | --- |
| 测试标签 | `v0.7.0-test.20261015`；同日再次发布追加 `.2`、`.3` |
| 正式候选标签 | `v0.7.0-rc.1`、`v0.7.0-rc.2` |
| 正式标签 | `v0.7.0`；后续修复使用新的补丁版本，例如 `v0.7.1` |
| ZIP | `keyabyss-0.7.0-test.20261015-windows-x64.zip` 或 `keyabyss-0.7.0-windows-x64.zip` |

示例不是本次已发布的版本。标签和文件名必须唯一；已经分发的同名包不覆盖，标签不移动到其他提交。日期按北京时间填写。

发布前同步以下版本字段并纳入发布提交：

- `project.godot` 的 `config/version`：如 `0.7.0-test.20261015`、`0.7.0-rc.1` 或 `0.7.0`。
- `export_presets.cfg` 的 `application/file_version`、`application/product_version`：使用四段数值，如 `0.7.0.1`，最后一段区分本版本的构建，按发布顺序递增。
- 发布说明、包名和发布记录：同时写明可读版本、Windows 四段版本与 Debug／Release 配置。

只改标签或 ZIP 名称不会更新游戏和 EXE 内的版本。每次重新构建都记录实际版本字段，不能沿用尚未改动的 `-dev` 标识冒充正式版本。

### 代码与素材

1. 确定本次发布范围和相对上一包的变化。检查 `git status --short`，先处理需要纳入的代码、资源、UID、导入配置和版本字段；不把其他任务的未完成改动顺手发布。
2. 按[Git 与资产开发](GIT-AND-ASSETS.md)固定资产提交、上传实际 LFS 对象，再固定引用该资产的代码提交。`asset-lock.json` 中的提交与清单哈希属于发布输入；只保存 LFS 指针不够。
3. `node tools/dev.mjs push "说明"` 会提交当前工作区全部未提交代码变化，只在这些变化都属于本次已确认发布范围时使用。需要拆分时先整理提交，不能对多人工作区直接执行全量提交。
4. 从已经固定的代码提交构建。构建工作区应没有待发布的未提交改动；正在持续开发的工作区可另建隔离检出目录，并按同一资产锁恢复。不要从 MCP 预览副本或编辑器未保存状态导出。
5. 发布记录保存完整代码提交、资产提交与清单哈希。生成包后若修改了运行代码、资源、配置或版本，重新构建，并重做受影响检查和成品验证。

本地临时诊断可从工作区导出，但含未提交内容的包只作为本地证据，不发布为可追溯的版本包。

## 3. 准备构建环境

在发布检出目录根运行，逐条确认成功后继续：

```powershell
node tools/assets/assets.mjs sync --profile runtime
node tools/assets/assets.mjs verify --profile runtime
pwsh -NoProfile -File tools/godot/godot.ps1 doctor
pwsh -NoProfile -File tools/godot/godot.ps1 import
```

已有修改的素材先按资产流程处理，不用同步覆盖。已有完整 `authoring` 环境也可使用对应范围校验；发行只需要运行素材，不需要把音频原件和制作库装进包。

环境锁包括：

- `tools/godot/toolchain.json`：精确 Godot .NET 引擎、引擎哈希和 Windows 模板；当前为 Godot 4.7.2。
- `global.json`、`Keyabyss.csproj` 和三份 `packages.*.lock.json`：当前 .NET SDK 9.0.201，以及 `Debug`／`ExportDebug`／`ExportRelease` 依赖。不能改用普通 `Release` 配置或临时重生成锁文件绕过失败。
- 本机 `tools/godot/local.paths.json` 或 `GODOT_PATH`：只负责定位引擎，不进入发布包。

`doctor` 核对引擎与 SDK，并报告模板状态；模板安装及包哈希校验按[工具链](migration/TOOLCHAIN.md)执行。当前 Shader Baker 需要真实图形设备，导出时不能追加 `--headless`；脚本已传 `--screen 0`。

每次构建使用空的对应输出目录。已有 `builds/windows/` 或 `builds/windows-release/` 时，先判断是否需要留档；需保留的成品归入对应版本目录，废弃输出移到 `.delete/release/<唯一目录>/`。移动前核对源与目标的绝对路径都在工作区内，不覆盖已有目录。导出脚本会重建转换缓存，但不会清空输出目录，不能任由旧日志、DLL 或诊断文件混入新包。

## 4. 选择本轮验证

按本次差异和未覆盖风险选择[测试入口](../tests/README.md)，不默认运行全量历史套件。已有证据可复用，但记录其代码版本、范围及为何仍适用；变更影响到的结论必须重新验证。

| 本次变化 | 需要的验证 |
| --- | --- |
| GDScript | 锁定引擎逐个检查受影响脚本：`--debug --check-only --script res://路径.gd`；修复警告与错误 |
| 输入、战斗、页段、遗物或奖励 | 对应规则与正式流程，覆盖真实输入、命中／取得、跨页／章交接和重复执行边界 |
| 保存、成长或版本兼容 | 新档、旧档副本、保存回读、失败恢复、不兼容进行中远征处理、普通／God 隔离 |
| UI、shader、字体、音频 | 实际 Forward+ 窗口操作与画面／声音；相关画质档、减少动态、暂停／恢复与退出 |
| C# 或导出依赖 | 对应算法／跨语言检查，以及最终导出程序集在独立包中的实际执行 |
| 完整内容与难度收束 | 按[收益与难度评估](COMBAT-BALANCE-DESIGN.md)统一评估，结合真人体验；不逐件遗物重跑平衡 |

静态检查示例，需将路径换为本次受影响脚本；`--check-only` 必须同时带 `--script`：

```powershell
pwsh -NoProfile -File tools/godot/godot.ps1 run --headless --debug --check-only --script res://app/main.gd
```

测试包至少保证启动、目标场景和反馈路径可用。测试目标之外尚未验收的体验可写明后交付定向试玩；崩溃、资源缺失、存档破坏或目标流程不可执行时不能放行。

正式包还须具备当前发行范围的完整流程、真人输入／防御、整体难度、目标设备长时性能和干净环境证据。具体未完成项查 TODO；本机高配设备、机器人九页流程和短时启动不能替代这些结论。首次正式发布补齐全部发行范围；后续补丁按差异复验并保留有效基线，无须每次从头运行所有专项。

## 5. 导出测试包或正式包

每次只选择本轮需要的配置。在独立 PowerShell 会话中用 transcript 保存完整构建输出，路径名称替换为本次版本：

```powershell
$releaseId = '0.7.0-test.20261015'
$evidenceDir = Join-Path (Get-Location) ".temp/releases/$releaseId"
New-Item -ItemType Directory -Path $evidenceDir -ErrorAction Stop | Out-Null
Start-Transcript -Path (Join-Path $evidenceDir 'build.log') -ErrorAction Stop
try {
    pwsh -NoProfile -File tools/godot/godot.ps1 export
    if ($LASTEXITCODE -ne 0) { throw '导出失败，停止发布。' }
} finally {
    Stop-Transcript
}
```

正式包或 Release 候选包将 `releaseId` 换为对应版本，将 `export` 换为 `export-release`。同一版本需要重试时使用新的证据子目录，保留失败日志，不能覆盖后只留下成功结果。

导出脚本已经执行：

1. 校验精确引擎／SDK，按 `win-x64` locked restore 验证对应导出配置，由 Godot 执行 `dotnet publish`。
2. 拒绝根工程的 MCP Autoload；将 `.godot/exported/` 旧转换缓存移入 `.delete/`，重新导出资源。
3. 通过真实 RenderingDevice 导出并烘焙 shader。人工核对日志中 `baking_shaders` 完成及 `res://.godot/shader_cache/` 入包记录；当前脚本不把这两项作为独立断言。
4. 检查 `data_Keyabyss_windows_x86_64/Keyabyss.dll` 存在。
5. 用编辑器引擎加载成品 PCK，执行三个 Boss、五档生成与血量检查。此项使用当前 Debug 程序集，不证明成品 Release 程序集已执行。
6. 从输出目录调用 `keyabyss.console.exe`，以隔离 APPDATA 执行 1800 帧 headless 启动烟测；要求正常退出、出现 `Keyabyss ready` 且无显式引擎错误。日志位置会输出为 `.temp/export-smoke/<唯一目录>/`。
7. 复制 `LICENSE`、`THIRD_PARTY_NOTICES.md`、引擎／.NET／词库许可与词库来源；Debug 包再复制 `tools/godot/playtest/` 中的使用说明与诊断工具。

把烟测日志一并归入本版本证据。任一步失败即停止发包；目录中已经生成 EXE 不等于本次导出成功。导出警告也须审阅，不能把脚本未拦截的警告当作自动验收通过。

## 6. 验收独立成品

从源码目录之外的独立解压／候选目录运行最终 EXE，记录包版本、硬件、Windows／驱动、分辨率、画质、词库和验证时长。实际 Forward+ 窗口验证至少包括：

1. 新用户目录首次启动：启动准备有反馈，字体、词库和音频可用；完成首访设置，退出重开后设置保留。
2. 正式输入进入战斗，验证词咒、御术、自动闪避与终式；实际触发 C# 自动闪避评分路径，不能只停留首页。覆盖受影响法书／敌人／效果。
3. 完成奖励、路线、下一页、Boss／结算／重开等本次涉及的路径；涉及连续挑战时验证保留遗物升档。正式版使用完整发行范围的证据，不以短局夹具代替完整行程。
4. 暂停、设置、恢复、退出及相关画质／减少动态切换正常，正文和危险提示清晰，退出日志无未解释的脚本、资源或渲染错误。
5. 使用旧版档案副本验证升级；检查设置、词库、成长、记录及进行中远征的兼容边界。先备份再测试，不在唯一玩家档案上试迁移。

测试包和正式包默认都使用 `%APPDATA%\Keyabyss`，包放在不同目录不会隔离存档。新档检查可在独立启动会话中临时设置 APPDATA，结束后恢复；升级检查向该隔离环境复制旧档。自动导出烟测的隔离不延续到之后的双击启动。

正式包须在不依赖开发 SDK、源码目录和本机导入缓存的干净环境启动，并在当前目标设备（见 TODO，包含 Quadro P620）完成长时运行与真实战斗检查。记录卡顿、内存趋势、输入与画面结果；没有实际验收时不发布最低配置或流畅运行承诺。

成品模板不支持编辑器的 `--script`、`--main-pack`、`--path` 参数。包内启动用 `keyabyss.exe`，需要等待退出和捕获日志时用 `keyabyss.console.exe`；不得用编辑器测试通过替代成品执行。

## 7. 整理与校验分发包

完整输出目录至少包含：

```text
keyabyss.exe
keyabyss.console.exe
keyabyss.pck
data_Keyabyss_windows_x86_64/   # 保留全部托管运行文件及子目录
LICENSE
THIRD_PARTY_NOTICES.md
licenses/
```

保留导出器生成的其他运行依赖，不按上述最小清单删文件。Debug 包还应保留诊断 CMD、配套 PowerShell 文件和两份使用说明。正式包另附简短启动说明：完整解压、启动 EXE、版本、存档位置、反馈入口。

逐项核对：

- EXE、同名 PCK 与托管目录来自同次导出；不要单独改 EXE 名称或只发送 EXE。
- 根工程无 MCP 调试桥，导出预设排除 `development/`、`tests/`、`tools/`、`docs/`、`legacy/` 等开发内容；变更资源依赖或导出预设时核对实际 PCK 内容，不能仅凭排除规则推定。
- 分发目录没有本地 `logs/`、玩家档案、性能记录、凭据、源素材库和构建证据。测试过的目录不要直接压缩；从未运行的完整导出结果整理分发副本。
- 按[第三方声明](../THIRD_PARTY_NOTICES.md)核对实际采用素材的来源、使用范围及随包文件，并提供对应版本源码入口。公开测试包同样属于分发，不能仅凭 Pre-release 标记跳过现有声明要求；资产库设为私有也不等于授权已解决。公开源码自动 ZIP 不应被直接认定为全部发行资料已齐备。

正式分发前未完成的字体／音频资料仍以 TODO 和第三方声明为准；文件已被导出脚本复制只证明随包，不证明来源资料已补齐。

将干净输出目录压为新 ZIP，以下示例只打测试包，正式包替换目录与名称：

```powershell
$zipPath = Join-Path (Get-Location) 'builds/keyabyss-0.7.0-test.20261015-windows-x64.zip'
if (Test-Path -LiteralPath $zipPath) { throw '包名已存在，请使用新的构建版本。' }
Compress-Archive -LiteralPath 'builds/windows' -DestinationPath $zipPath -ErrorAction Stop
Get-FileHash -LiteralPath $zipPath -Algorithm SHA256
Get-Item -LiteralPath $zipPath | Select-Object Name, Length
```

保存最终 ZIP 字节数和 SHA-256，生成随包上传的 `SHA256SUMS.txt`，每行是 `哈希  文件名`。完成说明、签名（若后续引入）等所有会改变字节的操作后再计算哈希。

将该 ZIP 解压到新的独立目录，核对关键文件及托管目录完整，并启动一次确认到达可交互首页；必要时复验受影响玩法。压缩前的启动不替代解压验证。通过后冻结 ZIP，不再往其中追加文件。

## 8. 发布与下载验证

1. 将标签关联到实际构建的完整代码提交，并确认该提交及资产锁可恢复。不要在发布时直接选已经前进的分支 HEAD。
2. 在 GitHub Releases 建立草稿，填写版本、变化、试玩目标／发行范围、已验证环境、已知问题、存档兼容说明、启动与反馈方式、对应源码入口。上传冻结 ZIP 和 `SHA256SUMS.txt`。
3. 根据包用途选择 Pre-release 或正式发布。发布前核对资产名称、字节数、标签提交和本地记录；测试包保留明确的未验收范围，正式包不得把阻断项改写成已通过。
4. 发布后通过实际下载链接重新下载 ZIP 和校验文件，计算下载 ZIP 的 SHA-256，与构建时保存的值逐字比对；再次解压启动。仅看到资产列表或上传成功不算下载验证。
5. 下载验证成功后更新根 README 的下载入口，使文案与“测试包／正式包”一致。下载链接指向明确版本；正式发布的 Latest 设置只指向已验收正式包。
6. 将版本、标签提交、资产锁、下载链接、哈希及实际验证边界写入阶段总结；只更新 TODO 中对应工作的完成状态，不把测试包发布等同于 S4 全部完成。

发布说明可使用以下简短结构，填写事实，不复制空模板给玩家：

```text
键渊 <版本> · Windows x64 · <Debug 测试包／Release 候选包／正式包>

主要变化：
验证范围与环境：
已知问题与未验证范围：
存档兼容与升级方式：
下载及启动：完整解压后运行 keyabyss.exe。
反馈：版本、复现步骤、实际结果、硬件／画质；测试包附本次 logs。
源码：对应标签／完整提交入口。
校验：ZIP 文件名、字节数、SHA-256。
```

## 9. 反馈、撤回与回退

测试包优先通过“启动并记录.cmd”复现并回收同次 `logs/`；需要排除诊断开销时使用“无诊断对照.cmd”。进一步的系统轨迹只在确有性能疑点时按包内说明采集，不作为每位测试者的默认步骤。

收到阻断问题后，先关联到具体版本、哈希、复现路径和日志。确认影响下载或使用时，将下载入口退回上一已知可用版本，在问题 Release 说明中明确停止推荐及原因；需要撤下错误资产时保留原始成品和哈希用于调查，不用同名文件静默替换。修复后发布新版本，并复验对应风险与分发链。

回退程序不等于回退存档。先备份当前 `%APPDATA%\Keyabyss`，确认旧包能否读取新档；不能读取时使用升级前备份或独立用户目录，不让旧程序覆盖唯一的新档。不要清空玩家目录处理兼容问题。

## 10. 发布记录与收尾

每次发布保留一份记录，与日志、验收图像和最终包关联：

| 字段 | 内容 |
| --- | --- |
| 身份 | 可读版本、四段版本、标签、完整代码提交、构建配置、北京时间 |
| 输入 | 资产提交／清单哈希、引擎版本／哈希、SDK、依赖锁、导出预设 |
| 验证 | 选用的检查及结果、复用证据依据、成品运行环境／时长、存档兼容、未验证范围 |
| 构建 | 完整导出日志、shader 烘焙记录、Boss 检查、独立启动烟测日志 |
| 分发 | ZIP 文件名／字节数／SHA-256、下载地址、下载回验结果、对应源码入口 |
| 回退 | 上一可用版本、档案兼容边界、必要备份与问题说明 |

`.temp/releases/<版本>/` 可保存本地原始证据，但它被 Git 忽略，不能作为唯一长期发布档案；将需要保留的成品、记录与证据备份到维护者持久存储，公开发布记录保留版本与校验信息。日志及失败尝试不要混入玩家 ZIP。

确认必要证据已保存后，将不再需要的解压目录、旧输出和临时下载移入工作区 `.delete/release/<唯一目录>/`，由用户手动删除；不永久删除、不清空已有 `.delete/`。完成本次发布后停止，不顺带整理其他任务的产物。
