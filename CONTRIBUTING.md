# 参与贡献

感谢你帮助改进键渊。Bug 修复、体验改进、内容扩展、文案和可复现的问题反馈都很有价值。

## 本地运行

需要 Node.js 22.18 或更高版本。在自己的 Fork 或本仓库副本中执行：

```sh
npm ci
npm run dev
```

打开终端显示的本地地址（默认 `http://127.0.0.1:4318`）。开发启动会准备素材、字体、词库和音效；不需要手动打开源码根目录的 HTML。

生成可离线游玩的版本：

```sh
npm run build
```

完成后打开 `dist/index.html`。分享离线包时保留整个 `dist` 目录的内容，包括字体、音效、词库和许可文件。

发行构建默认混淆启动、游戏和战场脚本，开发模式不混淆。配置位于 `tools/obfuscate.mjs`；内容哈希与发行清单根据最终产物生成。词库数据和许可保持可读，`THIRD_PARTY_NOTICES.md` 仅保留在源码仓库。

普通构建直接使用已提供的 WOFF2 字体。只有替换 `public/font` 中的源字体后，才需要安装 `requirements-dev.txt` 中的工具并执行 `npm run fonts:build`。

## 改动前先看

[项目规则](AGENT.md)说明了布局、字体、启动与交互约定。尤其注意：

- 面向桌面键鼠，兼顾桌面窗口和全屏；不新增移动端布局或触屏适配。
- UI 沿用[开放式 UI 约定](docs/OPEN-UI.md)，用文字、留白和局部刻线组织内容。
- 弹层标题与主要操作固定，长内容在内部滚动；动态效果尊重减少动态设置。
- 内容扩展遵循现有模块边界；新增遗物需提供可辨认的 SVG 图案。

按改动需要查阅：

| 方向 | 参考 |
| --- | --- |
| 模块与内容扩展 | [架构实施记录](docs/ARCHITECTURE-IMPLEMENTATION.md) |
| UI 与视觉 | [视觉规则](docs/ART-DIRECTION.md)、[文案规则](docs/CONTENT-STYLE.md) |
| 难度与战斗节奏 | [防御与难度](docs/DEFENSE-AND-PACING.md) |
| 素材与音效 | [素材管理](docs/ASSETS-AND-FLAME.md)、[音效工具](docs/AUDIO-SYSTEM.md) |
| 文本与提示 | [文本系统](docs/TEXT-AND-TOOLTIPS.md) |
| 验证范围与命令 | [测试说明](docs/TESTING.md) |

## 验证改动

选择与改动相称的检查。代码改动可从下面两项开始；`build` 包含内容、架构和 TypeScript 校验：

```sh
npm test
npm run build
```

涉及界面、输入或启动流程时，再运行对应的浏览器检查。首次使用需准备 Python 依赖：

```sh
python -m pip install -r requirements-dev.txt
npm run test:ui
```

测试会优先寻找已安装的 Chrome / Edge；找不到时可执行 `python -m playwright install chromium`。具体专项检查见[测试说明](docs/TESTING.md)。纯文档改动检查内容和链接即可，不必运行游戏测试。

## 提交 PR

每个 PR 尽量围绕一个问题，避免混入无关格式调整或生成文件。请在描述中写明：

- **问题与结果**：什么场景下有问题，改动后是什么表现；如有相关 Issue，请附链接。
- **验证方式**：运行了哪些检查、结果如何；未能验证的部分直接说明。
- **体验变化**：界面改动附截图或录屏，玩法调整说明影响和取舍。

新增数据或素材时，请注明来源和许可，并按需要更新第三方声明。请勿提交依赖目录、本地存档或临时输出。对规模较大的改动，先通过 Issue 讨论范围，有助于减少返工。
