# 键渊 · 失控咒典

**用键盘施法，在失控的咒典中写出下一章。**

键渊面向桌面键盘与鼠标：打字施法、弹反与闪避、四书、局内遗物和少量线性成长。主工程采用 Godot 原生 2D、类型化 GDScript、Forward+／HDR 2D，Windows 为首要平台。

正式流程包含四书、196 件局内遗物、三章九页、五档难度与保留遗物的连续挑战；大型天赋、专属许可、副书、形状配置和复杂加工／事件已退出。场外成长由有效人工字符自动推进，全书共享且有上限。最高档的成长与继承路径正在按[收益评估](docs/COMBAT-BALANCE-DESIGN.md)复验，实际状态与证据边界见[阶段总结](docs/STAGE-SUMMARY.md)。Godot 使用自己的档案，不迁入旧浏览器进度；玩法基线为[实施交接](docs/migration/AGENT-HANDOFF.md)指定的 Git 提交，当前 [legacy/web](legacy/web/README.md) 已含后续重构。

## 开发入口

[下载 Windows x64 测试包](https://github.com/iceriny/keyabyss/releases/tag/v0.7.0-test.20261015)。完整解压后双击 `keyabyss.exe`，无需安装 Godot 或 .NET 开发工具；包内附诊断启动脚本与使用说明，发布页提供 SHA-256 校验文件。

默认主分支 [`main`](https://github.com/iceriny/keyabyss/tree/main) 为 Godot 工程；原 Web 工程保存在 [`preview`（预览版）](https://github.com/iceriny/keyabyss/tree/preview)，可按该分支 README 启动或构建离线包。两个工程请克隆到不同目录。`legacy/web/` 保留迁移参考及制作工具，不作为预览版的启动入口。

开发需 Git LFS、Node.js 22+、PowerShell 7、**Godot 4.7.2 .NET** 与 **.NET SDK 9.0.201**。战斗逻辑以 GDScript 为主，自动闪避评分由 C# 批量计算，启动脚本会按锁文件构建程序集。

代码位于本仓库，字体、音频及素材源件位于私有的 [keyabyss-assets](https://github.com/iceriny/keyabyss-assets)。使用有权访问两个仓库的 GitHub 账号，在新设备执行：

```powershell
git lfs install
git clone https://github.com/iceriny/keyabyss.git
Set-Location keyabyss
node tools/dev.mjs setup
node tools/assets/assets.mjs verify --profile authoring
Copy-Item tools/godot/local.paths.example.json tools/godot/local.paths.json
# 填写本机 Godot console.exe 路径，再运行下面的入口。
```

`authoring` 恢复游戏素材、完整音频库和全部原始／未选用素材；只改游戏代码可选 `runtime`，Agent 重新选音可选 `library`。工具固定 [asset-lock.json](asset-lock.json) 中的提交，默认在项目旁创建资产仓库，校验哈希并保护本地修改。同步完成后打开根目录 [project.godot](project.godot)。具体更新与交接流程见[资产开发指南](docs/GIT-AND-ASSETS.md)。

日常换设备只用两条命令，代码与资产一起交接：

```powershell
# 在开始工作的设备：
node tools/dev.mjs pull
# 完成修改后：
node tools/dev.mjs push "说明本次修改"
```

`push` 自动收集配置目录中的新增／变动素材，先上传私有资产与 LFS，再更新版本锁、提交并推送当前代码分支。另一台设备 `pull` 会拉取该分支并恢复同一套资产。请在前一台推送完成后再开始另一台的工作。要使用其他范围，首次执行 `node tools/dev.mjs setup runtime` 或 `setup library`；后续拉取沿用本机范围。

配置好本机引擎路径后，可在 PowerShell 中运行：

```powershell
pwsh -File tools/godot/godot.ps1 doctor
pwsh -File tools/godot/godot.ps1 import
pwsh -File tools/godot/godot.ps1 editor
pwsh -File tools/godot/godot.ps1 run
```

[迁移方案](docs/migration/PLAN.md)说明架构、顺序与阶段出口；[贡献指南](CONTRIBUTING.md)说明资源导入和工具配置；[文档导航](docs/README.md)通往有效产品与视觉规范。未完成工作统一维护在 [TODO](docs/TODO.md)。

源码许可见 [LICENSE](LICENSE)，依赖与素材说明见[第三方声明](THIRD_PARTY_NOTICES.md)。
