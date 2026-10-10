# 键渊 · 失控咒典

**用键盘施法，在失控的咒典中写出下一章。**

键渊面向桌面键盘与鼠标：打字施法、弹反与闪避、四书、局内遗物和少量线性成长。主工程采用 Godot 原生 2D、类型化 GDScript、Forward+／HDR 2D，Windows 为首要平台。

正式流程包含四书、58 件局内遗物、三章九场、五档难度与保留遗物的连续挑战；大型天赋、专属许可、副书、形状配置和复杂加工／事件已退出。场外成长由有效人工字符自动推进，全书共享且有上限。最高档的成长与继承路径正在按[收益评估](docs/COMBAT-BALANCE-DESIGN.md)复验，实际状态与证据边界见[阶段总结](docs/STAGE-SUMMARY.md)。Godot 使用自己的档案，不迁入旧浏览器进度；玩法基线为[实施交接](docs/migration/AGENT-HANDOFF.md)指定的 Git 提交，当前 [legacy/web](legacy/web/README.md) 已含后续重构。

## 开发入口

使用 **Godot 4.7.2 .NET** 打开根目录 [project.godot](project.godot)，等待资源导入后运行。当前业务使用 GDScript，不需要安装 Node 或构建 C# 才能运行根工程。

本机已配置引擎路径，也可在 PowerShell 中运行：

```powershell
pwsh -File tools/godot/godot.ps1 doctor
pwsh -File tools/godot/godot.ps1 editor
pwsh -File tools/godot/godot.ps1 run
```

[迁移方案](docs/migration/PLAN.md)说明架构、顺序与阶段出口；[贡献指南](CONTRIBUTING.md)说明资源导入和工具配置；[文档导航](docs/README.md)通往有效产品与视觉规范。未完成工作统一维护在 [TODO](docs/TODO.md)。

源码许可见 [LICENSE](LICENSE)，依赖与素材说明见[第三方声明](THIRD_PARTY_NOTICES.md)。
