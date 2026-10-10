# 冰面微观材质

`assets/art/effects/ice_microstructure.png` 与 `assets/art/effects/frost_microfacets.png`：2026-10-08 使用内置 imagegen 生成的灰度材质，正式战斗和独立小样共用。原图保留在生成工具输出目录；不引用旧冰晶图集。不含玩家、第三方参考图或项目数据输入。

`ice_microstructure.png` 调制冰膜的高度、透光密度和可见冻结边缘；高低频噪波共同影响边缘阈值，并按像素足迹过滤。裸露前沿的生长遮罩与高度使用同一贴图扰动坐标，内部成熟冰面保留原有起伏。`frost_microfacets.png` 提供细针状晶面，按晶格三个轴向混合，在主枝与冰膜上补微起伏、粗糙度及可在普通照明下辨认的霜晶，并调制晶体覆盖边缘的细碎缺口。主枝与分枝仍由生长求解决定，贴图只修饰局部轮廓；shader 采用内部 UV 区域，不假定生成图边缘真正无缝。

边缘疏散按生长枝网周围的结冰密度控制：内部完整，外侧逐步提高微晶贴图的覆盖阈值，留下碎晶与零散亮点；晶体和冰膜共用此筛选。外缘取样带随冰域尺寸缩放，最大36像素，不添加独立粒子或圆形淡出蒙版。

主晶面使用沉积高度的六邻域平滑与线性采样，显示高度系数7，保留早结晶部分持续增厚的弧面感。法线从连续高度差分取得，采样间距跟随屏幕像素与实际晶格分辨率；高光按法线变化过滤。外缘仍由贴图扰动及密度筛选形成碎冰、星点，不使用三角平面斜率、同侧法线整合或距离场尖脊。高画质大冰域晶格384²，小范围结霜224²，具体分级见[元素接线](ELEMENT-EFFECTS.md)。

`ice_microstructure.png` 生成提示词：

```text
Use case: stylized-concept. Asset type: square grayscale microstructure data texture for a real-time clear-ice material in a top-down game, NOT a beauty render. Create a seamless edge-to-edge 1024x1024 isotropic microscopic ice surface: irregular fine crystalline grains and minute enclosed bubbles, with sparse slightly larger soft hazy inclusions and very shallow interlocking mineral facets. Fine varied scale detail, most grains 2–12 pixels across, larger cloudy inclusions 20–60 pixels, quiet clear areas mixed organically with subtly dense areas. Very low contrast midgray height field, average neutral gray, mostly values 95–160, subtle extremes only. The brightness represents minute surface height and material density, not lighting. Absolutely NO snowflakes, branches, fern shapes, cracks, scratches, circles, obvious polygons, recognizable objects, big motifs, directional illumination, highlights, shadows, colored tint, perspective, vignette, borders, text, watermark. No regular repeating lattice. Flat evenly distributed grayscale texture with natural spatial variation; perfectly opaque. The result will be used at low amplitude for normals, roughness and internal scattering on a separately simulated branching crystal. Both opposing edge pairs should match for tiling.
```

`frost_microfacets.png` 生成提示词：

```text
Use case: stylized-concept. Asset type: monochrome micro-height / micro-roughness texture for a real-time transparent hoarfrost material. One square 1024x1024 texture, full bleed, opaque. A sharp microscopic aggregate of very fine ice needles, tiny angular elongated crystalline prisms and minute branching frost tips, in sparse broken clusters with clear empty gaps between them. It must read as crisp hoarfrost microcrystals, NOT sand, soap foam, stone, smooth clouds, or a macro snowflake. Most elements are 3–14 pixels wide, lengths 8–35 pixels, very few small clusters up to 90 pixels. Dominant slender growth from lower-left toward upper-right, with irregular short side needles 60 degrees off that axis, natural variation and unequal spacing. Roughly 55 percent quiet dark space, no large solid cloudy masses. Grayscale scalar map only: dark gray background value about 45; crystal ridges midgray to lightgray value 110–205, sharp but antialiased edges. Brightness denotes micro-height/density, no photograph shading, no cast shadows, no glowing outlines, no baked lighting, no blue tint. Uniform texture distribution, no focal motif, no vignette, no borders, no labels, no watermark. This texture only supplies sub-pixel surface facets on an independently simulated crystal skeleton; no large snowflake or fern silhouette. Texture-like, not an illustration.
```
