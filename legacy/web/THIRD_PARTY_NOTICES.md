# 第三方数据与许可说明

本文件随 Keyabyss 0.6.0 分发，Qwerty 数据快照更新日期为 2026-09-20，其他快照保留各自采集日期。游戏实现与词库数据分离。

## 界面与视觉依赖

React、React DOM、Scheduler、Three.js、postprocessing、three.quarks、quarks.core 及 Floating UI（dom / core / utils）使用 MIT 许可证，版本锁定在 `package-lock.json`。发行包的 `THIRD-PARTY-LICENSES.txt` 包含它们的完整许可，以及本项目和词库许可，设置页「关于」提供离线入口。Floating UI 用于提示层定位与边缘避让。运行时代码随发行包分发；不从 CDN 加载。

Vite、TypeScript、React Vite 插件、vite-plugin-singlefile、javascript-obfuscator、Prettier 和类型声明包仅用于开发、检查与构建。Three.js 用于原生战场场景、角色图集、实例化弹幕、粒子、位移场、辉光与 WebGL 生命周期管理；独立 TypeScript 模拟输出状态，文字与危险预警使用 Canvas 覆盖层。

## Qwerty Learner

来源项目：<https://github.com/RealKai42/qwerty-learner>，作者和贡献者为其对应仓库所载权利人。来源项目采用 GPL-3.0；许可证全文随包保留在 `licenses/Qwerty-Learner-GPL-3.0.txt`。

本项目收录该项目 `public/dicts/` 中以下文件的单词数据。对应逐文件 URL、SHA-256、完整源范围、过滤记录与数量位于 `data/sources.json` 及各词库 JSON 文件中。

| 本地 ID | 上游文件 | 收录范围 |
| --- | --- | --- |
| primary1 | PEP_SL_XiaoXue1_1_t.json、PEP_SL_XiaoXue1_2_t.json | 完整源文件合并、过滤并去重；96 词 |
| primary2 | PEP_SL_XiaoXue2_1_t.json、PEP_SL_XiaoXue2_2_t.json | 完整源文件合并、过滤并去重；93 词 |
| primary3 | PEPXiaoXue3_1_T.json、PEPXiaoXue3_2_T.json | 完整源文件合并、过滤并去重；133 词 |
| primary4 | PEPXiaoXue4_1_T.json、PEPXiaoXue4_2_T.json | 完整源文件合并、过滤并去重；153 词 |
| primary5 | PEPXiaoXue5_1_T.json、PEPXiaoXue5_2_T.json | 完整源文件合并、过滤并去重；230 词 |
| primary6 | PEPXiaoXue6_1_T.json、PEPXiaoXue6_2_T.json | 完整源文件合并、过滤并去重；204 词 |
| junior | PEPChuZhong7_1_T.json、PEPChuZhong7_2_T.json、PEPChuZhong8_1_T.json、PEPChuZhong8_2_T.json、PEPChuZhong9_1_T.json | 完整源文件合并、过滤并去重；1906 词 |
| senior | PEPGaoZhong_1_T.json、PEPGaoZhong_2_T.json、PEPGaoZhong_3_T.json、PEPGaoZhong_4_T.json、PEPGaoZhong_5_T.json、PEPGaoZhong_6_T.json、PEPGaoZhong_7_T.json、PEPGaoZhong_8_T.json、PEPGaoZhong_9_T.json、PEPGaoZhong_10_T.json、PEPGaoZhong_11_T.json | 完整源文件合并、过滤并去重；2941 词 |
| cet4 | CET4_T.json | 完整源文件合并、过滤并去重；2607 词 |
| cet6 | CET6_T.json | 完整源文件合并、过滤并去重；2345 词 |

数据改动：将 `name` / `trans` 转换为 `word` / `meaning`；小写化、去重和输入字符过滤；移除音标；保留当前完整源中文释义。教材名称用于说明第三方分类，不代表本项目获得教材机构背书，也不代表与最新教材版本逐项对齐。小学合并所列教材上下册；初高中按表中完整源分册合并。

词库工坊的完整源同步由玩家明确点击触发，向以下地址之一请求对应 JSON，绝不上传玩家导入词库：

```text
https://raw.githubusercontent.com/RealKai42/qwerty-learner/master/public/dicts/<filename>
https://cdn.jsdelivr.net/gh/RealKai42/qwerty-learner@master/public/dicts/<filename>
```

上游 `master` 数据可能继续变化。命令行同步保存新的获取时间和逐源文件原始响应 SHA-256，浏览器同步作为新本地库保存。保留来源说明不等于对上游每项第三方释义完成独立权利核验。

## CMU Pronouncing Dictionary

来源项目：<https://github.com/cmusphinx/cmudict>。

本包提取环境中第三方 Python `cmudict` 包 **1.1.3** 所附 `cmudict.dict` 的词形，保留全部 1–8 位纯英文字母词形并去重，得到 84,620 条。原始词典文件 SHA-256：

```text
81917843c7f44ce2b094ac63873c2c7a4cf802040792c455ba3ca406891c3d22
```

仅保留词形，移除发音，不提供中文释义。它含专有名称、生僻形式，不是词频名单、教材分级或大学考试词表。原始版权与许可通知完整保留在 `licenses/CMUdict-LICENSE.txt`，发行包的 `THIRD-PARTY-LICENSES.txt` 也保留该通知。

## C++ 工作草案关键词

来源：<https://eel.is/c++draft/lex.key>，2026-09-19 检索快照。

`data/cpp.json` 收录 `[lex.key]` 表 5 的 82 个关键词词形与表 6 的 11 个替代运算符词形，合计 93 条；没有复制标准正文。该名单对应工作草案快照，不标注为某个已经发布的 C++ 版本；其中包括较新的草案词条。`import`、`module` 等上下文相关标记不属于此处表 5，未混入该表。

仅用于打字挑战，不进行 C++ 编译、语法分析或语言合规性判断。需要教学中的特定标准版本时，可用自定义导入词库替换。

## 游戏代码、视觉与声音

原创游戏代码以 GPL-3.0-only 分发，见根目录 `LICENSE`。战场采用 Canvas / CSS / Three.js 程序绘制，首页、选择卡、图鉴与 HUD 使用用户提供的四张法书原图；当前环境及 512px 粒子光斑均由程序生成，见 `docs/ART-DIRECTION.md`。声音采用浏览器 Web Audio 合成。未包含商业游戏美术、外部音乐、远程字体或字体文件。源码版包含词库与构建代码，通过 `npm ci` 安装锁定的第三方依赖后构建。
