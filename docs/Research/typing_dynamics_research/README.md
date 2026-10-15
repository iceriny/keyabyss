# 动态随机英文词打字：机制建模与执行研究

本项目建立词汇识别、二维视觉搜索、扫视/追踪、工作记忆、十指准备与击键、错误修复以及词间衔接的耦合随机模型。`report/research_report.pdf` 是正式中文报告，`results/` 是真实运行输出，`figures/` 包含各图的 PNG、SVG 和 PDF。

主条件为：3–8字母英文词从5875词池中均匀独立抽取；词中心分布28×15度；D条件标称移动速度3度/秒；当前词首次击键时显示下一个词；允许凭已编码内容继续打字；空格提交；词尾修正；每场60秒墙钟计分。A为自写连贯句子的固定双槽位呈现，不是整段排版阅读。无预视条件和挑战场景另行保存。

五类名称是合成能力档，不是经人口抽样确立的现实分组。论文逐键类别均值用于词内校准，论文WPM均值另用于词间衔接残差的汇总校准。后者不具有唯一的心理学解释；没有独立动态打字人类试次验证，顶尖档仍是外推情景。

## 安装与单场运行

在项目根目录运行，建议 Python 3.13。复现当前包使用 `requirements.txt` 固定依赖。仿真本身不需要网络，真实词库已随包保存。

```bash
python -m venv .venv
# Windows PowerShell:
.venv\Scripts\Activate.ps1
$env:PYTHONUTF8 = "1"  # Windows终端以UTF-8处理项目的中文文本
# Linux/macOS:
# source .venv/bin/activate
python -m pip install -r requirements.txt
python -m pip install -e . --no-deps
python scripts/run_one.py --group expert --task D --seconds 60 --speed 3
python scripts/run_one.py --group ordinary --task D --no-preview --distractors 4
```

`wpm5` 是五字符标准词/分钟，`actual_wpm` 是完整正确英文词/分钟；`lpm` 是正确字母/分钟，`cpm` 是含正确提交空格的字符/分钟。纠错击键进入用时与原始击键计数，不额外计入净正确字符。末尾未提交词不计分。

## 完整重建

这些命令重新生成项目的数值结果。校准阶段必须按顺序执行：先词内间隔，再整任务词间衔接；只运行第一阶段会清除第二阶段的参数。

```bash
python scripts/prepare_data.py
python scripts/fit_parameters.py
python scripts/fit_boundaries.py
python scripts/run_experiments.py --stage all --workers 4
python scripts/analyze_results.py
python scripts/run_diagnostics.py
python scripts/build_provenance.py
python scripts/generate_figures.py
python -m pytest -q --junitxml=results/validation/pytest.xml
python scripts/reproduce_check.py
python scripts/build_report.py
# 安装PDF编译工具后：python scripts/build_report.py --pdf
```

支持分别执行 `--stage baseline`、`sensitivity`、`ablation`、`uncertainty` 或 `validation`。每场任务完整配置、个体ID、重复编号及种子保存为 `*_jobs.jsonl.gz`；与进程执行顺序无关。`baseline_words.csv.gz` 保存逐词记录，键盘及眼动微事件保存在 `results/traces/` 的固定诊断会话中，而不是为全部会话保存巨大的连续轨迹。

PDF编译另需 Pandoc、XeLaTeX 和系统中文字体（如 Noto Serif CJK SC）。本包不分发字体文件。`build_report.py` 总会生成Markdown；安装所需编译器后使用 `--pdf` 生成PDF。图形优先使用本机Noto CJK、微软雅黑或黑体；无中文字体的环境需要先自行安装合适字体。

## 数据与模型层次

`data/raw/typing_summary_observations.csv` 是人工核对作者PDF表3后转录的少量统计量，绝不是逐键原始数据。`data/raw/en-spelling.txt` 是TextBlob 0.19.0自带的真实词汇计数；现代语料代表性有限。`data/raw/sentences.txt` 的50个句子是本项目自写刺激。全部来源、核验范围和用途见 `data/sources.md`，参数的单位、数值、证据等级和不确定性见 `data/metadata/parameters.csv`。

`results/validation/zero_boundary_*` 专门保留未引入词间残差时的结构诊断。它们是消融对照，不是当前主模型的结果。最终模型通过显式词间事件闭合词内击键与整任务速度两种汇总约束；不能因此宣称唯一识别了真实认知过程。

主输出的均值置信区间是模型参数固定后的蒙特卡洛精度；p05–p95是合成个体均值分布；Latin Hypercube（拉丁超立方）区间来自显式参数先验，两者都不是现实人群的已验证置信区间。31张研究图的解释均随图记录，不能把消融差异直接当作生理机制的因果贡献。

## 主要文件

- `report/research_report.md`、`.pdf`：中文报告及源文档。
- `data/metadata/parameters.csv`、`references.json`：参数与文献。
- `results/analysis/baseline_statistics.csv`：所有主指标及个体聚类区间。
- `results/analysis/paired_task_contrasts.csv`：A→B→C→D配对比较。
- `results/analysis/ablation_contrasts.csv`、`uncertainty_intervals.csv`：机制消融及先验传播。
- `results/analysis/execution_ledger.csv`：实际执行场次、模拟时长、耗时、识别失败及结果哈希。
- `results/validation/replay.csv`：全新解释器复算20个代表会话的对照。
- `figures/manifest.json`：每张图的标题、解释、CSV来源和生成脚本。

## 明确的实现边界

本项目是可检验的机制候选模型，不是完整神经生理数字孪生。只实现小写英文、标准QWERTY及可选非标准双食指映射，没有实现大小写Shift组合。视觉字体用字框与平均字形宽度近似。遮挡交叠使用面积截断近似，重叠的多个遮挡框可能重复计入局部面积。竞争识别采用两个累积器及最强竞争者近似，不枚举所有词义。词间残差合并未分辨的任务/运动衔接效应，不能宣称直接测得。修复按键采用无二次错误的终止性策略，密集错误情景的纠错时间可能偏低。全部子模块源代码和参数公开，以便后续替换，而非通过输出WPM乘固定惩罚掩盖这些假设。

可选下载器默认仅核对随包词库，不下载大文件：`python scripts/download_data.py`。添加 `--aalto-raw` 才从官方页面解析并下载约1.4GB原始数据；添加 `--paper` 获取作者论文。下载失败不修改当前研究输入。

## 交付文件校验

`python scripts/verify_bundle.py` 会核对交付清单中的 SHA-256，并检查主结果计分恒等式、执行账本和31套图形文件。文件经过主动修改后，哈希不一致属于预期现象；保留原包可用于对照。Windows运行上述命令前请按安装部分启用UTF-8模式。
