---
name: keyabyss-godot-tools
description: 在键渊启动 Godot、导入资源、运行 MCP 预览、检查截图日志或准备 Windows 导出时使用。
---

## 选择入口

版本、路径、安装与既有命令以 [TOOLCHAIN](../../../docs/migration/TOOLCHAIN.md) 和 `tools/godot/toolchain.json` 为准；不默认升级。启动、导入、预览、导出继续用 `tools/godot/godot.ps1`，资产交接继续用 `tools/dev.mjs`，不另造并行工具链。

| 当前任务 | 入口与证据 |
| --- | --- |
| 路径／版本异常 | `godot.ps1 doctor`；检查本机配置、引擎哈希与 SDK |
| 新类／资源未入缓存 | `godot.ps1 import`；审阅导入日志，再检查脚本 |
| GDScript 静态检查 | 本 Skill 的 `scripts/check-gdscript.ps1`，显式给受影响脚本 |
| 规则回归／实际图形窗口 | `godot.ps1 run`，按 [TESTING](../../../docs/TESTING.md) 选入口 |
| MCP 运行观察 | 停旧实例 → `godot.ps1 preview` → 核对副本 → 主 MCP |
| Windows 包交付 | 现有 export／export-release；详见 [运行与交付实践](references/operations.md) |

## 技能内工具

从仓库根目录执行；脚本也可由绝对路径调用，不依赖当前工作目录。

```powershell
& ./.agents/skills/keyabyss-godot-tools/scripts/check-gdscript.ps1 -Scripts @('app/main.gd', 'res://game/input/input_router.gd')
python .agents/skills/keyabyss-godot-tools/scripts/preview-audit.py --paths project.godot app ui/game_display.gd
```

`check-gdscript.ps1` 复用 doctor 校验工具锁，不构建、导入或启动主场景；逐个执行 `--headless --debug --check-only --script`，保存源码哈希、原始输出、引擎退出码及诊断。发现警告／错误或非零退出即返回 1；依赖链诊断也保留，失败不自动扩大修复范围。

`preview-audit.py` 只读比较指定源路径与 `.temp/godot-mcp/project` 的实际文件，识别新增、缺失和变更；`project.godot` 按既有生成器变换后比较。需要完整复制范围时才加 `--all-runtime`。匹配返回 0，差异返回 1，输入／环境错误返回 2。它不刷新预览，也不证明副本导入、运行时值或未保存的编辑器状态正确。两工具的独立证据目录位于 `.temp/skill-tools/`。

## 运行约束

根工程是保存结果的权威源。MCP 的所有 `projectPath` 指向生成副本；运行时调参要落实到根文件再刷新。一次只由一个 Agent 管理实例，127.0.0.1:9090 被占用时先识别拥有者，不任意终止。停止后副本仍在，刷新由既有工具移入 `.delete/`。

出现输入不生效、截图发黑、headless 图形失败、退出告警、性能尖峰或导出差异时，读 [运行与交付实践](references/operations.md)。协议握手、工具调用、窗口启动和完整玩法各自报告实际覆盖。
