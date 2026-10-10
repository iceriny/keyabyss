---
name: keyabyss-godot-tools
description: 在键渊启动 Godot、导入资源、运行 MCP 预览、检查截图日志或准备 Windows 导出时使用。
---

命令、版本和安装方式见 [工具说明](../../../docs/migration/TOOLCHAIN.md)。优先 CLI，只有运行时观察与输入需要 MCP。

1. 路径或版本有疑问时运行 `pwsh -File tools/godot/godot.ps1 doctor`，不默认升级引擎或 npm 包。
2. 正式编辑使用根工程。CLI `run`／`editor` 使用根 `project.godot`，不要求 MCP 或 Node。
3. MCP 先用 `preview` 生成 `.temp/godot-mcp/project`，所有 `projectPath` 指向该副本。默认只允许有限工具；不以 MCP 文件写入代替 apply_patch。
4. 一次只让一个 Agent 管理运行实例。上游固定使用 127.0.0.1:9090；停止实例后再刷新副本。端口被占用时识别拥有者，不任意终止进程。
5. `stop_project` 后磁盘副本仍在，刷新时旧副本移入 `.delete/`。预览使用预置桥接，上游不会删工程文件；源工程及导出不注入桥接。
6. 整理交付时区分 CLI 成功、MCP 服务实测、当前聊天是否加载工具、视觉与完整玩法验收。不要把协议握手写成全部工具通过。
