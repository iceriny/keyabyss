# Godot 本机工具链

核查日期：2026-09-27。公共版本和哈希固定在 [toolchain.json](../../tools/godot/toolchain.json)，本机路径位于忽略的 `tools/godot/local.paths.json`。当前配置已落地；更换机器时按本页恢复，不下载浮动 latest。

## 已安装与接入状态

| 组件 | 当前值 | 用途及边界 |
| --- | --- | --- |
| Godot | `4.7.2.stable.mono.official.ed1daf0bf` | 用户指定的 .NET 引擎；console.exe 哈希已锁定 |
| 引擎目录 | `F:\Program Files\Godot\Godot_v4.7.2-stable_mono_win64` | 原位置使用，未复制或覆盖引擎 |
| Windows 模板 | `%APPDATA%\Godot\export_templates\4.7.2.stable.mono` | 已安装 x86_64 Debug、Release、console wrappers、version.txt 和 ICU；不安装其他平台 |
| Node.js | `v24.19.0` | 只用于 MCP 与保留的资产工具 |
| .NET SDK | `9.0.201` | `global.json` 精确锁定；`Keyabyss.sln` 提供 `Debug`／`ExportDebug`／`ExportRelease` 配置；`Keyabyss.csproj` 使用 `Godot.NET.Sdk/4.7.2`、`net8.0`，只编译 `game/algorithms/*.cs` |
| 主 MCP | `@tugcantopaloglu/godot-mcp` 3.1.0 | 提交 `fcbc29e03297900b9a1fcc6c7cbae116fe9d532a`，本地 `.tools/godot-mcp/` |
| Codex 配置 | `.codex/config.toml` | 项目配置已被 CLI 识别；保持其他全局服务器原样 |
| 项目 Skill | `.agents/skills/` | 原生开发、视觉与工具三类；未批量引入第三方架构偏好 |

## 常用命令

从仓库根目录运行：

```powershell
pwsh -NoProfile -File tools/godot/godot.ps1 doctor
pwsh -NoProfile -File tools/godot/godot.ps1 import
pwsh -NoProfile -File tools/godot/godot.ps1 editor
pwsh -NoProfile -File tools/godot/godot.ps1 run
pwsh -NoProfile -File tools/godot/godot.ps1 run --headless --quit-after 3
pwsh -NoProfile -File tools/godot/godot.ps1 export
pwsh -NoProfile -File tools/godot/godot.ps1 export-release
```

`doctor` 验证精确引擎版本、console.exe 哈希和根工程实际解析的 .NET SDK，并报告 MCP 和模板是否就绪。其他任务也拒绝引擎或 SDK 版本不符。`import`／`editor`／`run` 先以 `Debug` 配置增量编译 C#，恢复依赖使用 locked mode；编译失败立即停止。依赖按 `packages.Debug.lock.json`、`packages.ExportDebug.lock.json`、`packages.ExportRelease.lock.json` 分配置锁定，不能用普通 `Release` 替代 Godot 的导出配置。

导入／导出除了退出码还检查显式引擎错误。`export` 生成 `builds/windows/` 下的 Debug 包；`export-release` 使用官方 Release 模板生成 `builds/windows-release/` 下的 EXE、PCK 和 `data_Keyabyss_windows_x86_64/` 托管运行目录。导出前验证对应 `ExportDebug`／`ExportRelease` 的 `win-x64` locked restore，随后由 Godot 自身执行该配置的 `dotnet publish`，不提前重复编译；子进程继续使用 `RestoreLockedMode=true`。两者同时复制项目声明、引擎及词库许可。导出不表示玩法、目标机器或素材许可已经验收，当前实际证据见阶段总结。

Windows 预设已启用 Shader Baker。`export`／`export-release` 使用真实 RenderingDevice，不能追加 `--headless`；官方烘焙步骤需要图形设备。非交互导出显式传 `--screen 0`，避免复用编辑器记忆中已不存在的显示器编号。日志应包含 `baking_shaders` 完成及 `res://.godot/shader_cache/` 入包记录，独立启动仍需创建硬件相关管线。资源导入和成品 Boss 检查继续使用 headless。原理与资源入口见[渲染准备方案](PLAN.md#渲染准备与原生资源实施方案)。

独立导出 EXE 从包含同名 PCK 的目录启动；锁定的官方模板不支持 `--script`、`--main-pack` 或 `--path`，这些参数留给编辑器引擎命令。成品验证使用 `keyabyss.console.exe` 捕获输出并等待退出，不以 GUI EXE 调用测试脚本。

导出前把 `.godot/exported/` 的转换缓存移入 `.delete/godot-export-cache/<唯一目录>/`，重新生成二进制资源；导入与 shader 缓存保留。锁定引擎曾将 `PackedInt32Array = []` 的导出属性漏掉，修正声明后旧转换缓存仍会保留坏数据。导出后确认托管目录中的 `Keyabyss.dll` 存在，增量编译当前 `Debug`，再用编辑器引擎加载成品 PCK 执行 Boss 检查脚本，核对三个 Boss 的五档生成和血量。该检查验证打包资源及当前 Debug 程序集，不执行成品发布程序集。

成品另用 `keyabyss.console.exe --quit-after 1800 --max-fps 60 --headless --log-file <绝对日志路径>` 做启动烟测，给首次词库索引的后台准备留出时间；原240帧曾在工作线程完成前退出，不能据此判断成品启动失败。Debug 和 Release 均生成控制台包装器。APPDATA 暂时隔离到 `.temp/export-smoke/<唯一目录>/appdata`，结束后恢复环境变量。检查退出码、输出和日志，要求出现 `Keyabyss ready` 且没有显式引擎错误；日志保留在该证据目录。短时启动通过不等于发布 C# 算法已经执行，仍需相应成品玩法验证。任一检查失败时不将产物视为可分发包。Debug 包附带“启动并记录.cmd”和“无诊断对照.cmd”，可回收目标设备日志。

官方 CLI 始终可直接使用。例如 `& $env:GODOT_PATH --headless --path . --editor --import`。便利脚本不承担游戏运行逻辑。原生 CLI 与导出能力参见 [Godot CLI 文档](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html)。

## MCP 的生成预览

该上游 `run_project` 会向 `project.godot` 注入 Autoload 并复制桥接脚本，停止时清理自己注入的文件。为使源工程不发生临时改写并遵守本仓库清理约定，使用生成副本：

```powershell
pwsh -NoProfile -File tools/godot/godot.ps1 preview
node tools/godot/mcp-smoke.mjs
```

`preview` 复制版本锁列出的活动资源目录、`project.godot`、`Keyabyss.sln`、`Keyabyss.csproj`、`global.json` 和三个配置依赖锁到 `.temp/godot-mcp/project`，在副本增量编译 `Debug`，预置桥接并导入资源，同时把用户目录改为 `Keyabyss-M1-Preview`，与正式玩家设置和词库隔离。预览程序集生成在副本自己的 `.godot/mono/temp/bin/Debug/`，不复制根工程编译缓存。上游检测到现有桥接后不执行删除。刷新副本前检查 9090 监听；上次副本移入 `.delete/godot-preview/<唯一目录>/`。根工程不注入 Autoload，不把调试桥列入导出。

在 MCP 中始终传：

```text
projectPath = F:/Workshop/game/keyabyss/.temp/godot-mcp/project
```

日常允许 19 项工具，覆盖版本／项目信息、场景读取、脚本检查、运行／停止、UI／场景树／属性／音频读取、截图、键鼠输入、日志和基础性能。没有默认开放任意 `game_eval`、文件写入、删除、网络或完整 3D 工具集。允许目录是工具使用范围约束，不宣称是操作系统沙箱。

可用顺序为：保存根工程修改 → 停止现有实例 → 刷新 preview → `run_project` → 按疑点读取结构／图像／日志 → `stop_project`。磁盘、编辑器未保存状态和运行时属性分开判断；运行时调优需保存回根工程才算完成。

本机 SDK 联调已验证服务和实际窗口，Codex CLI 也识别了配置。当前聊天已有工具集合不会因配置文件变化自动扩展；重开会话或重启客户端后使用项目 MCP。官方支持项目 `.codex/config.toml` 和工具允许列表，见 [Codex MCP 文档](https://developers.openai.com/codex/mcp)。

### 已知限制

- 上游使用固定 `127.0.0.1:9090`，同机默认一个游戏会话。发现占用时识别进程归属，不终止无关程序。
- 4.7.2 编译上游桥接出现 5 条静态警告（3 处 `name` 遮蔽、2 处整数与枚举）；目前不影响已测工具。未修改上游、未关闭项目警告；不把警告记成零错误的全面兼容证明。
- `run_project` 返回时 TCP 可能尚未连接，联调脚本进行有界等待；早期连接失败消息不是引擎崩溃。
- 生成副本随源码刷新，不代表编辑器未保存状态；副本使用独立用户目录。M1 回归检查另为设置与词库注入仓库证据路径，不以调试进程修改玩家数据。
- 上游 `game_key_press` 不写入 `unicode`；字符输入用 `tests/godot/test_application.gd` 的原生事件链验证，勿改正式路由去接受缺少 Unicode 的字母。

## 在另一机器恢复

先按根 README 克隆代码，安装 Git LFS 与 Node.js 22+，执行 `node tools/assets/assets.mjs sync --profile authoring` 和对应 `verify`。资产默认克隆到项目旁的 `keyabyss-assets`，无需复制本机缓存、音频处理程序或 Godot 导入结果。

1. 安装同版 Godot .NET 和精确 `.NET SDK 9.0.201`，复制 `tools/godot/local.paths.example.json` 为 `local.paths.json`，填写 console.exe 的绝对路径，或设置 `GODOT_PATH`。核对 `doctor`。首次构建按对应配置依赖锁恢复 NuGet 包，不改用浮动 SDK 或重生成锁文件。
2. 需要 MCP 时，安装 Node 22 或更高版本，按固定提交构建：

```powershell
git clone --no-checkout https://github.com/tugcantopaloglu/godot-mcp.git .tools/godot-mcp
git -C .tools/godot-mcp checkout --detach fcbc29e03297900b9a1fcc6c7cbae116fe9d532a
Push-Location .tools/godot-mcp
npm ci --ignore-scripts --no-audit --no-fund
npm run build
Pop-Location
```

已有目录时先检查状态，不覆盖或重置已有修改。使用上游 package-lock，不把依赖安装到根工程。

3. 复制 `.codex/config.example.toml` 为本机 `.codex/config.toml`，替换 `<PROJECT>`、Node 与 Godot 路径；若已有文件则合并单独的 `keyabyss_godot` 表，不覆盖其他配置。以 `codex mcp get keyabyss_godot --json` 检查解析，再运行 preview 和联调。仓库 Skills 使用官方 `.agents/skills` 发现约定，见 [Codex Skills 文档](https://developers.openai.com/codex/skills)。
4. 需要导出时，从 [4.7.2 官方发行页](https://github.com/godotengine/godot/releases/tag/4.7.2-stable)下载 `Godot_v4.7.2-stable_mono_export_templates.tpz` 和 `SHA512-SUMS.txt`，校验完整包哈希与版本锁一致。当前只抽取 `templates/windows_{debug,release}_x86_64{,_console}.exe`、`templates/version.txt`、`templates/icudt_godot.dat` 到上述模板目录；可用 Godot 模板管理器完整安装同版模板。不要使用机器已有的 4.4.1 模板。

源码与工具边界来自 [godot-mcp 固定提交](https://github.com/tugcantopaloglu/godot-mcp/tree/fcbc29e03297900b9a1fcc6c7cbae116fe9d532a)。没有安装备用 MCP、第三方 CLI 或 C# 插件；以后替换开发工具不改变游戏数据和运行架构。

## 证据与清理

`.temp/godot-preparation/` 保留本次原始 Git 状态、搬迁 SHA-256、导入／导出日志、MCP JSON 及截图。可复用的 MCP 检查脚本留在 `tools/godot/`；下载包和过期生成副本移入 `.delete/`，不永久删除。

只对当前修改选择必要检查。标题屏截图不是完整视觉验收，Debug 导出不是玩法完成，MCP 的原生窗口成功不证明全部工具或长时性能，详见[验证范围](../TESTING.md)。
