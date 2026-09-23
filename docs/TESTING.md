# 测试与验证

按风险与影响范围选择最低成本的充分检查。明确的局部修改先检查结果与差异；需要验证行为时，再选择受影响的现有测试。已通过的检查不因流程惯性重复；无关的既有失败保留证据，不扩展修复范围。

| 层级 | 适用情况 | 入口 |
| --- | --- | --- |
| 静态检查 | 文档、配置、生成产物及明确的局部修改 | 检查差异和文件格式；涉及类型、内容或模块边界时分别用 `npm run typecheck`、`npm run validate:content`、`npm run check:architecture`。发行产物需要验证时用 `npm run build`，其中已包含内容、图谱生成、架构和类型检查。 |
| 行为单元测试 | 逻辑与规则修改 | 优先用 `node --test tests/相关文件.test.cjs` 运行受影响的现有文件；共享核心改动扩大到 `npm test`。`npm test` 自动收集全部单元测试文件。 |
| 浏览器功能测试 | 页面交互、渲染、发行包加载及桌面窗口布局 | 使用 Python Playwright；通常先生成 `dist/`，再按下表选对应入口。 |
| 性能与数值统一评估 | 渲染性能、难度或构筑收益需要整体验收 | 性能用 `npm run test:performance`；难度与收益用 `npm run balance:builds`，阶段、分片及严格合并命令见[统一验收](COMBAT-ACCEPTANCE.md)。普通构建和每次内容修改不自动运行数值评估。 |

| 浏览器范围 | 入口 |
| --- | --- |
| 页面、菜单与键盘输入 | `npm run test:ui` |
| 原生战斗画面、特效生命周期与性能采样 | `npm run test:visual` |
| 内容扩展与资源释放 | `npm run test:architecture` |
| 桌面窗口布局与弹层滚动 | `npm run test:desktop`、`npm run test:scroll-shell` |
| 字体与首次进入 | `npm run test:fonts`、`npm run test:first-visit` |
| 战斗防御、音效与记录 | `npm run test:defense`、`npm run test:audio`、`npm run test:results` |
| 天赋持久化与组合战斗 | `python -X utf8 tests/combat-refactor-browser.py` |
| 图谱与事件界面 | `python -X utf8 tests/combat-acceptance-browser.py` |

`test:visual` 最后也采样普通战斗、密集弹幕、多场域、终式、持续粒子爆发五种运行场景；`test:performance` 只运行启动检查与同一组性能采样，并分别记录模拟、视觉更新、实例填充、粒子和文字绘制的 CPU 耗时。一次综合验收选 `test:visual` 即可；仅需重测性能时选 `test:performance`，不要连续重复运行两者。两者分别输出 `.temp/test-output-native/report.json` 和 `performance.json`；可用 `KEYABYSS_TEST_OUT` 分开保存前后样本。

浏览器测试使用独立浏览器配置。`combat-refactor-browser.py` 也支持环境变量 `KEYABYSS_URL` 指向本地开发服务；它验证天赋预算、实际输入结算、God 隔离与清理、桌面天赋窗口和组合渲染，证据位于 `.temp/combat-acceptance/browser/combat-refactor/`。其余浏览器截图和报告通常写入 `.temp/test-output-*`，图谱与事件检查写入 `.temp/combat-acceptance/browser/graph-event/`。

游戏面向桌面键盘与鼠标，以 1920×1080 为主要视觉基准。窗口布局检查覆盖 `AGENT.md` 规定的桌面 CSS 视口范围；不把旧记录中的窄屏检查视为移动端适配要求。

战斗重构的工程、浏览器、难度和收益结果见[统一验收](COMBAT-ACCEPTANCE.md)。平衡探针写入 `.temp/balance-probe.json` 和 `.temp/defense-balance-probe.json`；构建校验清单写入 `.temp/release-sha256.json`。`.temp/` 已忽略，不作为文档或发行物提交。历次验收与旧快照见[文档归档](archive/README.md)。
