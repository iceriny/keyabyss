# 运行与交付实践

以下路径相对仓库根目录。详尽参数由 `docs/migration/TOOLCHAIN.md` 与 `docs/TESTING.md` 维护，这里只保留实践中容易混淆的操作边界。

## 静态检查：退出 0 仍可能有警告

历史检查曾遗漏 `owner` 遮蔽、静态方法经实例调用及三元类型警告；新 `class_name` 未进缓存也曾造成检查失败。后来区分源码诊断、缓存、运行日志与编辑器诊断。

先保证必要资源已导入，再给 `check-gdscript.ps1` 显式脚本列表。工具用固定的 `--debug --ignore-error-breaks --check-only --script`，不能把裸 `--check-only` 交给主场景。`--debug` 会启用本地 stdout 调试器，语法错误时可能进入交互并反复输出；本次错误夹具实际复现后，加 `--ignore-error-breaks` 保留警告并正常返回错误。保留 engineExitCode 和原始日志；摘要非零不意味着引擎本身非零。入口输出中的依赖诊断保留真实位置，不宣称仅入口检查证明全工程干净。

工具不构建 C#：改了托管代码／首次恢复工程，先走既有 `godot.ps1 import` 或 `run` 的 locked build。没有新缓存需求时不重复导入。警告修复保留枚举类型、固定点截断和类型标注，不全局关闭警告。上游生成 MCP 桥的已知警告与根源码诊断分开报告。

## 预览：HEAD 相同不能证明副本新鲜

MCP 读取生成副本；未提交根源码改动、编辑器未保存值和运行时调色是三种不同状态。旧预览成功曾被误当正式文件交付。

停止当前 MCP 实例，再运行 `godot.ps1 preview`；从根目录执行：

```powershell
python .agents/skills/keyabyss-godot-tools/scripts/preview-audit.py --paths project.godot ui game/input
```

工具比较所选实际文件哈希并记录 Git 状态；只认磁盘文件，不推断编辑器状态。`project.godot` 的用户目录隔离和桥接 autoload 按现有生成器匹配。检查发现差异后在已停止状态重新生成，不直接修副本。不必每次哈希整个音频／开发资产目录，`--all-runtime` 留给完整来源核对。

一次只让一个管理者控制 9090 实例；`stop_project` 不删除副本，刷新由既有工具退休旧目录。不要复制生成桥到根工程。MCP 工具是否已加载、服务握手成功与具体方法实测是不同事实。

## 输入／截图：工具限制不是玩法缺陷

上游 MCP 键注入没有 `InputEventKey.unicode`，可用于鼠标、Tab、Esc 等观察；真实字符证据用现有原生 Unicode 应用测试。旧 Web 对照才使用 Python Playwright。

HDR 图像先从原高精度像素 `linear_to_srgb()` 写入新 RGBA8，再保存 PNG；先量化再转换会破坏暗部。现有生成桥、`test_application.gd` 等已实现转换，不另做一次 gamma。实际取图会同步等待和回读，不进入性能采样窗口。独立窗口是最终显示依据，`--wid` 嵌入缩放也可能造成锯齿。

## Headless、窗口与性能各有用途

规则、账本、存档可用 headless；compute、HDR、实际绘制停更和音频混音需要对应原生窗口。完整应用 headless 遇图形限制时换真实图形验证，不降低产品渲染配置迁就检查。

隐藏 Control 不自动停止子视口绘制与子系统。按需绘制需等实际 `frame_post_draw` 再确认停更；枚举设置或固定等待不证明渲染已停。`--fixed-fps` 加速规则不测手感或真实性能。

性能有具体疑点才记录。现有 `--frame-profile` 默认到正常退出，强杀无法写内存报告；普通 Debug JSONL 诊断与完整逐帧分析是两种入口。保留页面、CPU／GPU、窗口、画质与前后帧；嵌套阶段不求和，提交时间不等于 GPU 执行，探针不代表 GPU 等待。RTX 4070 SUPER 结果不外推到 P620，平均 FPS 不解释周期尖峰。

来源：`docs/migration/M2-IMPLEMENTATION-LESSONS.md` §9–10；`app/debug_log.gd`、`app/frame_capture.gd`、`tests/godot/profile_frames.gd` 与 `docs/TESTING.md`。

## Windows 导出：包内数据与独立 EXE 分别验证

继续使用 `godot.ps1 export`／`export-release`；它们已处理 locked restore、配置输出缓存退休、实际图形 Shader Baker、Boss 包内检查及 console 启动。不要 headless 导出，不以导出成功跳过引擎日志。

包内资源使用锁定编辑器引擎 `--main-pack <绝对PCK> --script <绝对测试脚本>`；官方 Release 模板不执行外部 `--script`。因此资源检查和独立 EXE 启动分开，短时启动不冒充战斗交互。C# 成品还需运行时目录及其实际加载证据，受限 SDK 搜索测试不等于卸载 SDK 的干净机。

副本导入／导出一旦出现原生异常，保留首次日志、退出码和复跑条件；查清事实后再决定是否复跑。历史访问异常原样复跑成功，不是自动重试或改画质的依据。

来源：`docs/migration/COMBAT-ALGORITHM-IMPLEMENTATION.md`、`ASSET-UPLOAD-IMPLEMENTATION.md`；`docs/STAGE-SUMMARY.md` 2026-10-10 记录。

## 常用命令与证据收束

PowerShell 用参数数组，尤其区分引擎参数与脚本的 `--`：

```powershell
& ./tools/godot/godot.ps1 -Task run -EngineArguments @('--headless', '--script', 'tests/godot/test_s2_rules.gd', '--', '--four-books')
& ./tools/godot/godot.ps1 -Task run -EngineArguments @('--script', 'tests/godot/test_battle_presentation.gd', '--', '--four-books', '--book=frost')
```

测试脚本是否自带隔离路径先读实现；不隔离的独立包验证使用单独 APPDATA，临时环境变量在 finally 恢复。原生进程完成后立即保存 `$LASTEXITCODE`，`ErrorActionPreference` 不替代它。`--log-file` 使用绝对路径。

为本次观察保留独立 `.temp/<任务>/<运行ID>/`，记录源码状态、命令、范围、原始日志与图像。`mcp-smoke.mjs` 当前覆盖固定输出名，若要保留多轮先归存上一轮证据。将通过、失败和未观察分别写清；测试清理／ObjectDB 告警不能在“检查通过”中消失。结论进入当前维护文档，不新增另一份 TODO。

清理先核对绝对源／目标在工作区内，再 `Move-Item -LiteralPath` 到独立 `.delete/<任务>/`，不覆盖已有目录或永久删除。保留 `.gd.uid` 和旁置 `.import`；跨设备资产使用既有 `node tools/dev.mjs setup/pull/push`（具体参数见 `docs/GIT-AND-ASSETS.md`），不复制资产同步实现。
