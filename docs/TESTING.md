# 测试与验证

按风险与影响范围选择最低成本的充分检查。纯文档与明确的局部改动可检查内容和差异；逻辑改动优先运行受影响的现有测试。共享核心改动才扩大到 `npm test`，需要验证发行产物时运行包含内容、架构和类型检查的 `npm run build`。已通过检查不因流程惯性重复，发现无关既有失败时保留证据，不扩展修复范围。

浏览器检查使用 Python Playwright 和独立浏览器配置，通常依赖已生成的 `dist/`，按受影响功能选择对应命令。战斗组合回归 `python -X utf8 tests/combat-refactor-browser.py` 也支持环境变量 `KEYABYSS_URL` 指向本地开发服务；覆盖天赋预算、实际输入结算、God 隔离与清理、桌面天赋窗口和组合渲染，证据写入 `.temp/combat-refactor/integration/browser/`。

| 范围 | 命令 |
| --- | --- |
| 页面、菜单与键盘输入 | `npm run test:ui` |
| 战斗画面与性能 | `npm run test:visual`、`npm run test:performance` |
| 内容扩展与资源释放 | `npm run test:architecture` |
| 桌面窗口布局与弹层滚动 | `npm run test:desktop`、`npm run test:scroll-shell` |
| 字体与首次进入 | `npm run test:fonts`、`npm run test:first-visit` |
| 战斗防御、音效与记录 | `npm run test:defense`、`npm run test:audio`、`npm run test:results` |

游戏面向桌面键盘与鼠标，以 1920×1080 为主要视觉基准。窗口布局检查覆盖 `AGENT.md` 规定的桌面 CSS 视口范围；不把旧记录中的窄屏检查视为移动端适配要求。

战斗重构的本轮工程、浏览器、难度和收益结果见 [统一验收](COMBAT-ACCEPTANCE.md)。图谱与事件界面回归入口为 `python -X utf8 tests/combat-acceptance-browser.py`；通用数值工具支持按阶段运行、分片与严格合并，命令和覆盖边界记录在验收文档中。

浏览器截图和报告写入仓库根目录 `.temp/test-output-*`；平衡探针写入 `.temp/balance-probe.json` 和 `.temp/defense-balance-probe.json`；构建校验清单写入 `.temp/release-sha256.json`。`.temp/` 已忽略，不作为文档或发行物提交。历次验收与旧快照见 [文档归档](archive/README.md)。
