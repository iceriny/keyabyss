# 数据、代码与素材迁移映射

> 历史归档：2026-10-08 调整范围前的设计、计划或证据。正文中的要求与“下一步”不构成当前任务；当前实施见[交接文档](../../../migration/AGENT-HANDOFF.md).

本页记录输入与目标边界，不替代 TODO 或候选内容的逐项去向表。旧路径均相对于 `legacy/web/`；完整旧实现接线见[迁移前快照](../../pre-godot/TECHNICAL-SNAPSHOT.md)。

## 代码去向

| Web 输入 | Godot 目标 | 处理方式 |
| --- | --- | --- |
| `src/application/SessionController.ts`、`src/simulation/{CombatSimulation,Runtime}.ts` | `app/`、`game/session/` | 按场景生命周期重组，不复制 Web 循环 |
| `src/input.ts`、应用层输入适配 | `game/input/` | InputMap 与 Unicode 词输入分流；人工回执语义保留 |
| `src/contracts/build-*.ts`、`src/contracts/native-spells.ts` | `game/builds/`、`game/spells/` 的具名 Resource／RefCounted | 单位、所有权、条件和操作成为可检查的类型 |
| `src/content/build/`、`src/shared/build/` | 内容 Resource 与 BuildCompiler | 以 D01–D12 和完整候选为输入，逐项注明正式入口 |
| `src/simulation/spells/` 中的 `ResourceLedger.ts`、`SpellResourceRuntime.ts`、`SpellLifecycle.ts` | 资源事务与法术生命周期 | 迁移不变量和失败边界；Q=1024 为初始量纲 |
| 同目录 `NativeSpellBattle.ts`、`ManualSpellIncome.ts`、`LetterOpportunities.ts` | 输入、基础法术和来源回执 | 保留合法供给关系，不迁移新旧门控 |
| `src/simulation/systems/` 中的 `WeaveSystem.ts`、`CastSystem.ts`、`DefenseSystem.ts`；`src/content/books/*/behavior.ts` | 同一原生法术／防御链 | 汇总未迁移行为，消除旁路重复收入／伤害 |
| `src/content/talents.ts`、`src/content/relics/`、`src/content/build-events.ts` | 正式天赋、遗物、事件资源 | 旧 144／140／24 与新 206／171／32 不相加 |
| `src/application/{talentProgression,runArchive}.ts`、`src/platform/StorageAdapter.ts` | `game/persistence/`、`game/progression/` | 参考去重结算和隔离语义；新游戏另建进度，不迁入浏览器账号、配置与历史 |
| `src/shared/graph-layout.ts`、`tools/graphs.mjs`、`src/generated/graph-layouts.ts` | 纯数据图生成器及 `ui/graph/` | 原图尚有交叉；重建完整候选的近邻、可达与平面图，不把旧坐标直接当成品 |
| React、CSS、Three、postprocessing、quarks、Web Audio | Control、Theme、CanvasItem shader、GPU 粒子、AudioServer | 重建原生表现；素材与视觉关系保留，接口不保留 |
| `tools/build-balance.mjs`、相关 tests | 后续正式 Godot 场景评估入口 | 复用案例思想和统计职责，不跨引擎套用旧结果 |

## 素材及工具

| 输入 | 当前处理 | 下一次使用时的要求 |
| --- | --- | --- |
| `public/font/汇文明朝体.ttf` | 已复制为 `assets/fonts/huiwen-ming.ttf`，用于主字体 | Godot 活动字体只维护这一份；旧文件保留在冻结 Web 实现 |
| `public/font/京華老宋体v3.0.ttf` | 已复制为 `assets/fonts/jinghua-song.ttf`，用于辅助字体 | 正式发行前补齐来源和许可文本 |
| `public/font/*.woff2`、重复 OTF | 保留在旧版，不导入 Godot | 原生使用现有 TTF，不继续运行字体 Web 打包步骤 |
| `art/*GRIMOIR*.png`、`art/runes/` | 四张 PNG 与四枚 SVG 已原样复制到 `assets/art/books/`、`assets/art/runes/`，接入四书 Resource 与书库 | 继续复用于入场、HUD、图鉴等正式入口，保留内容身份和来源 |
| `data/*.json`、`data/sources.json` | 12 本源词库由 `tools/godot/import-vocabulary.mjs` 生成到 `assets/vocabulary/`，保留来源与 SHA256 | 活动快照不手工编辑；更新源后重跑生成工具，运行时只读活动目录 |
| `public/audio/`、`data/audio-catalog.json`、`audio-overrides.json`、`tools/audio.ts` | 旧源完整保留；`tools/godot/import-ui-audio.mjs` 已生成 12 类 UI cue 的 27 个原生 WAV | 按真实 cue 复用片段、增益和并发；战斗混音随实际战斗接入，来源见第三方声明 |
| `tools/assets.mjs`、`fonts.py`、`bundle-vocab.mjs` | 随旧版保留 | 只抽取仍有价值的处理步骤，不把整个 Web predev 接到 Godot |
| `licenses/`、旧 `THIRD_PARTY_NOTICES.md` | 在旧版完整保存 | 使用哪份数据和素材，就迁移对应声明；Web 依赖不作为 Godot 运行依赖 |

复制字体是将冻结旧实现的素材提升为 Godot 活动输入，不建立两套持续同步的字体来源。Godot `.import` 文件固定导入方式，`.godot/imported` 可重建。

## 内容身份与新游戏存档

有效内容去向依据候选去向表，该表不是存档 ID 转换代码。Godot 内容目录需要独立的 schema_version 与 content_version，成长连线使用 graph_version，位置和画法另有 layout_version。

逐项落地时至少登记：稳定旧 ID（若有）、Godot ID、来源文档、保留／合并／移除原因、资源路径、许可、取得入口、作用规则、玩家说明及实际验证范围。未实现项不能仅凭展示资源进入可购买和可掉落集合。

不建设浏览器存档导入／导出或转换。旧 ID 只用于内容追踪，不成为新账号进度的映射规则。Godot 自身的成长、配置、记录与设置按新游戏建立，结算去重、失败保留原档和普通／God 隔离仍是保存契约。

现有自定义词库的 TXT／CSV／TSV／JSON／JSONL 文件导入继续保留；它与取消的浏览器账号迁移不同。Godot 发行后的自身版本升级需要保护本游戏已赚成长，但不承诺跨版本恢复任意时刻的旧战局。
