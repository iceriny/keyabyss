# 键渊 · 失控咒典

**用键盘施法，在失控的咒典中写出下一章。**

键渊面向桌面键盘与鼠标：打字施法、弹反与闪避、四书构筑、遗物和跨局成长。主工程采用 Godot 原生 2D、类型化 GDScript、Forward+／HDR 2D，Windows 为首要平台。

当前 Godot 的 M1 应用底座与 M2 单房完整战斗已通过用户验收；M3 已接入构筑编译、统一战斗规则和开发试验场，逐项内容与体验仍有待验收。当前优先推进 [M4 天赋图基础](docs/migration/M4-TALENT-GRAPH-PLAN.md)，整体平衡留到 M5 完成后的 M6。Godot 按新游戏建立成长，不迁入旧浏览器进度。既有 Web 实现保留于 [legacy/web](legacy/web/README.md)，实际范围见[阶段总结](docs/STAGE-SUMMARY.md)和[体验映射](docs/migration/EXPERIENCE-MAP.md)。

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
