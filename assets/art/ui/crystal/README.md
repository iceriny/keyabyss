# 金丝水晶数据贴图

用户提供的 `F:/Workshop/game/gilded-crystal-material-v9` 是图案和光学路径的参考。当前四套母图通过内置 image_gen 重新编辑，清理碎光、星芒和断续细线，保留大幅连续曲面；原件、完整提示词在 [source](source/README.md)。工具实际输出均为 **1672×941**，没有将提示中的 4K 请求或插值放大冒充原生高清输出。

| 图集 | 构图 | 使用页面 |
| --- | --- | --- |
| branch_fan | 左下放射晶膜 | 共用页面、书库与战斗边缘 |
| river | 下缘长弧 | 指南／图鉴／奖励、词库／记录／结算 |
| ascending | 侧边分叉 | 指南／图鉴／奖励／教学选课 |
| canopy | 右上晶膜 | 设置／关于／暂停／校准、书库与战斗边缘 |

母图只提供亮度、冷暖分类和二维晶脊走向，不作为静态背景显示。离线生成器从图像结构张量追踪曲线，按弧长生成流向，并沿曲线另行构造圆润折面高度、厚度和梯度；这属于美术控制的光学近似，不是从一张图片恢复真实三维形状。

## 数据与采样

三张 EXR 均为线性 **RGBA16F**，alpha 是独立数据。结构图保留母图 1672×941；流向／梯度的空间频率来自 480 像素追踪域，以 836×470 保存，避免为低频场存储重复插值像素。四套 GPU 基础数据约 72 MiB（不含 mip），与原四套 RGBA8 全尺寸数据同量级。

- `structure`：R/G 为宽面／细脊的**线性光度**，B 为暖色分类，A 为 presence；不再平方根编码，线性过滤保留细脊的亚像素能量。
- `gradient`：RG 按 `(rg - .5) * 1.4` 解码高度梯度，B 为厚度，A 为几何有效区；半浮点准确保留中性 .5，减少低斜率台阶。
- `flow`：R/G 为沿晶脊／宽面的有界连续相位，B 为流动权重，A 为法线运动权重。

保留 mipmaps，关闭有损 HDR 压缩、alpha-border 修补、预乘与法线图转换；采样器不使用 `source_color`。中高画质用四次双线性采样实现正权重 B 样条重建，柔化放大纹理的像素拐角，不产生锐化振铃。高光在黑位附近使用有限增益，避免将微小像素放大为白色硬脊；亮头按相位的像素足迹过滤。低画质保留普通线性／mip 采样。

## 光学与构图

正式实现共用于 `open_crystal.gdshader`（阅读页）与 `open_crystal_edge.gdshader`（书库／战斗边缘）。每片晶膜独立计算非对称流光、双相位法线、沿切线输运的粗糙度、移动清透区、折射／色散和反射。环境直接采样游戏画面；阅读页复用一次背景捕获和 mipmap 五点过滤，边缘直接采样已有 HDR 子视口，用空间五点过滤。

晶纹宽度约为逻辑画布的 1.28–1.35 倍，根部和分支裁出画面；中央连续膜自然渐隐，阅读区压低透光与装饰强度。金丝保持暖金，冷色轻随四书变化。战斗只在外侧 11% 合成，词咒、HUD、危险信息保持清楚。减少动态冻结当前相位；恢复后连续推进。

## 重建

`tools/art/build_crystal_fields.py` 从 Demo 生成器移植，输出相同光学语义的半浮点字段。依赖 Python 3.10+、NumPy、SciPy、Pillow、OpenEXR；本次使用 NumPy 2.5.4、SciPy 1.18.1、Pillow 12.3.0、OpenEXR 3.5.2。

```powershell
python tools/art/build_crystal_fields.py assets/art/ui/crystal/source/branch_fan.png assets/art/ui/crystal/source/river.png assets/art/ui/crystal/source/ascending.png assets/art/ui/crystal/source/canopy.png --seed 1 --no-diagnostics
& ./tools/godot/godot.ps1 import
```

各 `*_fields.json` 保存源图 SHA-256、种子与实际尺寸；source 目录用 `.gdignore` 排除运行时导入。旧的 12 张 Demo PNG 及导入配置移入 `.delete/open-crystal-refinement/original-fields/`，不在正式材质中保留两套输出。
