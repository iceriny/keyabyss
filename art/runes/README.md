# 魔法纹路

四个原创 SVG 使用 1024×1024 viewBox、透明背景和白色细线，可独立缩放、着色或组合。

| 文件 | 图形主题 |
| --- | --- |
| frost-seal.svg | 六向冰晶、断续刻度 |
| storm-seal.svg | 闪电折线、八向刻印 |
| spirit-seal.svg | 交叠灵轨、十二节点 |
| flame-seal.svg | 火舌闭合轮廓、十向刻印 |

项目通过 `src/content/assets.ts` 登记素材，`MagicPattern` 为通用 UI 组件；资源随发行包放入 `assets/art/`。

新版共同包含多重环带、60 枚铭文和六组副法阵。运行 `node tools/generate-runes.ts` 可重新生成。
