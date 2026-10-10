# 参与贡献

先阅读 [AGENTS.md](AGENTS.md)、[阶段总结](docs/STAGE-SUMMARY.md)和[迁移方案](docs/migration/PLAN.md)。有效产品语义与技术实现分开维护，旧版通过的测试不代表 Godot 已实现对应能力。

Git 与素材协作采用[公开代码＋私有资产方案](docs/GIT-AND-ASSETS.md)。该文档规定 LFS、版本清单、跨设备准备和分支策略；私有资产仓库及同步工具尚未建立，不能把其中的目标命令当成现成入口。

## 本地运行

使用 `tools/godot/toolchain.json` 锁定的 Godot **4.7.2 .NET**，直接打开根 `project.godot`。PowerShell 入口读取 `GODOT_PATH`，或本地 `tools/godot/local.paths.json`：

```powershell
Copy-Item tools/godot/local.paths.example.json tools/godot/local.paths.json
# 在 local.paths.json 填写本机 Godot console.exe 路径。
pwsh -File tools/godot/godot.ps1 doctor
pwsh -File tools/godot/godot.ps1 import
pwsh -File tools/godot/godot.ps1 run
```

已有本机配置时不需要再次复制。路径文件被忽略；公共工具版本入库。可绕过便利脚本直接使用官方 `--path`、`--editor`、`--import` 等 CLI 参数，项目不依赖 MCP。

## 调试与导出

MCP 安装和接入方法见[工具链](docs/migration/TOOLCHAIN.md)。运行时检查使用生成副本，代码编辑仍在根工程：

```powershell
pwsh -File tools/godot/godot.ps1 preview
node tools/godot/mcp-smoke.mjs
```

新会话加载项目 `.codex/config.toml` 后可使用 `keyabyss_godot` 工具。不要在两个 Agent 或两个实例之间争用 9090 端口。正式源文件、编辑器未保存状态、生成副本和运行时临时属性是不同状态，修改必须保存回根工程后才算交付。

Windows x86_64 开发导出：

```powershell
pwsh -File tools/godot/godot.ps1 export
```

输出在 `builds/windows/`，本机需安装匹配版本模板。此入口生成开发用 Debug 包；正式游戏发行另需[实施方案](docs/migration/PLAN.md)中的 S4 验收、完整素材许可与 Release 打包。导出覆盖活动资源，显式包含词库 JSON，并排除 tests、legacy、docs、tools 与调试桥。新增动态资源时核对实际包内容和独立启动，不把整个仓库打包。

## 修改与检查

新增原生内容依职责放在 `app/`、`game/`、`ui/`、`audio/`、`assets/`，不继续扩展根目录的 Web 工具链。`.tscn`、`.tres`、`.gd`、脚本 `.uid` 与资源 `.import` 配置入库；`.godot/`、`.tools/`、预览、日志和发行产物不入库。

检查按风险选择，见[验证范围](docs/TESTING.md)。文档修改不启动游戏；局部规则优先最小现有测试；完整数值在内容与正式流程贯通后统一进行。清理内容移至 `.delete/`，保留用户已有改动。

旧版需要回看或维护时，在 `legacy/web` 执行其原 Node 命令，具体见[旧版贡献指南](legacy/web/CONTRIBUTING.md)。这些命令不参与默认 Godot 启动和导出。
