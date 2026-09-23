# 文档归档

这里保存已被当前实现取代的方案、旧版约定、历次验收记录及当时生成的快照，供追溯使用。归档内容不作为当前功能、参数或验收要求；开发时以根目录 `AGENT.md` 和 `docs/` 中未归档的文档为准。

- `ARCHITECTURE.md`：实施前的架构设计。当前扩展方式见 [架构实施记录](../ARCHITECTURE-IMPLEMENTATION.md)。
- `INTERACTION.md`：旧版启动和输入约定。
- `BALANCE.md`：0.2–0.5 版本的难度调校记录；对应 JSON 是当时的探针快照。
- `TESTING.md`：历次验收流水账；当前测试命令见 [测试说明](../TESTING.md)。
- `rendering-discussion.md`：渲染重构前的讨论草稿。
- `tests-v*.tap`、`performance-v*.json`、`release-sha256.json`：历史测试、性能和发行快照。

新的浏览器截图、探针结果与发行校验清单统一生成在仓库根目录的 `.temp/`，该目录不提交到 Git。
