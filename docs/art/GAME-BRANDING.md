# 游戏图标与启动徽记

图标以实际欢迎法阵、四书首页和战斗UI为参考，由内置imagegen生成。主体为墨绿黑底上的金色符印：钥孔、抽象书页弧线、星点与断开的环轨。原始PNG、完整SVG路径和Windows多尺寸ICO位于 `assets/art/branding/`；项目窗口与Windows导出共用这一图标。

`keyabyss-icon.svg` 按原图RGBA水平像素段编码为路径，不嵌入位图、不量化颜色、不近似描边；保留原图1254×1254的采样网格。它是无损保留原图的路径表示，并非重新拟合的平滑贝塞尔曲线，文件较大。转换入口为 `tools/assets/icon-svg.py`，ICO含16／24／32／48／64／128／256像素规格。渲染器的预乘透明度舍入可能产生微小色差，不能把路径数据无损等同于所有渲染器的输出逐字节相同。

`boot-emblem.svg` 为用户提供的 `emblem-recreated.svg` 原件，完整保留构图与文字。锁定Godot的引擎启动图只支持PNG，所以 `boot-emblem.png` 直接由该SVG渲染，配置采用保持比例的Keep模式；进入原生加载与欢迎场景后的表现继续由现有场景负责。

## 生图提示词

参考图：当前欢迎法阵、四书首页、用户启动徽记。内置imagegen，透明背景。

Create ONE final square desktop game icon for 键渊 / Keyabyss. The attached images are STYLE AND IDENTITY REFERENCES, not edit targets: first is the actual game welcome ritual, second its current archive UI with grimoires, third the supplied startup emblem. Study their shared visual language carefully: ink-dark midnight teal, aged champagne-gold, restrained translucent material, slender botanical metal curves, airy magical circles and scholarly sealed-archive mood. The icon must look like it belongs to THIS game, not a generic mobile RPG. Design a spare centered golden magical sigil derived from the supplied emblem: a small open ring/keyhole crown on a vertical stem, with three pairs of graceful outward rising arcs suggesting the pages of an open spellbook and delicate leaf veins; one tiny four-point star at their junction. Surround it with only two broken orbital arcs and four small rune-like abstract ticks, substantially less complex than the welcome ritual. Build a coherent clear central silhouette. Thin-to-medium elegant gold strokes with subtle metallic light and shade, not chunky gold borders. NO literal teal gemstone book, no broad crystal wedges, no cartoon shapes, no saturated turquoise surfaces, no shiny embossed badge, no lettering, no words. The dark background should be a very quiet softly rounded square of near-black blue-green ink (#061115), with all details inside 12 percent safe inset, gently disappearing outer border. Dominant color is deep ink; the sigil is muted luminous gold (#c9a76b) with a few tiny ivory highlights. No overpowering bloom or fog, no gritty texture. Flat frontal high-quality symbolic graphic, balanced negative space, legible and visually calm at 32 and 48 pixels. Output only the icon at 1024x1024 with transparent pixels outside the rounded square, no presentation board, no watermark.
