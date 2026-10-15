# 遗物选择晶饰

内置 imagegen 生成；2026-10-15。12 张独立形态，1254 × 1254 RGBA，保留原生透明通道。

用于遗物选择页的开放晶饰。每组三选一不重复；按遗物 ID 稳定分配形态、朝向和光源相位，不消耗局内 RNG。原图使用 sRGB、线性 mipmap 缩小采样，实际占位 204 × 156 逻辑像素。

`*_optics.exr` 是 512 × 512 线性 RGBA16F 材质数据：RG 为曲面坡度编码，B 为厚度，A 为粗糙度。`tools/art/build_relic_fields.py` 依据透明轮廓和宽幅折面生成圆润倒角与内部起伏；这是为 2D UI 设计的浮雕场，不是从照片恢复真实几何。安装 NumPy、SciPy、Pillow、OpenEXR 后，执行 `python tools/art/build_relic_fields.py` 可复现；`fields.json` 记录源图哈希及通道。PNG 母图保持不变。

`relic_choice.gdshader` 根据曲面法线计算移动高光、清漆反光、厚度吸收、背景折射和微弱色散，复用 PageShell 的原始背景捕获与 `crystal_frost.gdshaderinc`，不重复模糊已柔化的菜单。原有 RelicGlyph 在 256² 透明视口绘制一次作为刻纹遮罩，再由同一材质计算金色倒角、埋入阴影和受光；中央连续薄膜自然消隐，没有封闭边框。选中时轻微提亮，减少动态冻结当前相位。

## 最终提示词与来源

### crescent.png

原始输出：`C:/Users/misss/.codex/generated_images/01a1331d-a3d3-7c92-8956-1710d2385cb3/exec-e6d24be2-8319-451f-a2df-d19e2d9eb4df.png`

```text
Use case: stylized-concept. Asset type: isolated transparent PNG ornamental material for a refined dark fantasy game's relic selection UI.
Create ONE exquisite asymmetrical open crystal cradle, front view, square composition. Shape: a slender crescent of overlapping smoky blue crystal leaves rises from lower left, sweeps across the bottom, and dissolves into three long tapered tips on the right. Fine champagne-gold botanical filaments are embedded INSIDE the glass. Broad translucent surfaces, fine polished edges, very few restrained pearl glints; no white glare or bloom.
Leave the central circular area (center x50%, y44%, radius22%) COMPLETELY empty and transparent for a separate item glyph. The object occupies about 80% of the square, with generous transparent margins. Open silhouette, airy, delicate, low visual weight, luxurious craft. Gold accent approximately 15%, cool grey sapphire crystal 85%. Exact material palette must suit pale-gold text on almost-black teal.
No icon, words, text, symbols, rune, jewel at center, closed ring, frame, rectangle, background, cast shadow, floor, glitter, particles, gritty cracks, symmetrical wings or repeated geometric polygon. Genuine transparent background, high-resolution smooth edges. The shape itself is the UI ornament; no screenshot or interface mockup.
```

### quartz.png

原始输出：`C:/Users/misss/.codex/generated_images/01a1331d-a3d3-7c92-8956-1710d2385cb3/exec-594b85ec-b8af-45b4-b572-d36e7abe7c56.png`

```text
Use case: stylized-concept. Asset type: ONE isolated transparent material ornament for the relic selection screen of an elegant dark fantasy game, not an icon or a UI mockup.
Front view, square canvas. Finely polished smoky grey-blue crystal membranes with a few hairline champagne-gold botanical inlays, translucent layers, precise pearly edge reflections. Airy, restrained, sophisticated; thin luminous structure with darker quiet interiors. Gold is sparse and embedded, not thick metal armor. Keep the middle (center x50%, y44%, radius20%) entirely transparent for a separately rendered item glyph. Occupy 80% of the canvas with transparent margins. Open asymmetrical silhouette; do not close a ring around the center.
Three slender unequal crystal blades grow from the lower right and arc toward upper left, split by one curved golden vein. Keep a wide open gap across upper right; form is diagonal and sculptural, not a radial spray.
No item glyph, text, runes, symbols, star, polygon badge, card, rectangle, thick metal border, floor, cast shadow, glitter, speckled noise, blown-out bloom, or particles. Genuine transparent background. A single detailed crystal ornament, smoothly antialiased high-resolution edges.
```

### fan.png

原始输出：`C:/Users/misss/.codex/generated_images/01a1331d-a3d3-7c92-8956-1710d2385cb3/exec-e10879d3-f3fc-4837-b881-8444bd4a5706.png`

```text
Use case: stylized-concept. Asset type: ONE isolated transparent material ornament for the relic selection screen of an elegant dark fantasy game, not an icon or a UI mockup.
Front view, square canvas. Finely polished smoky grey-blue crystal membranes with a few hairline champagne-gold botanical inlays, translucent layers, precise pearly edge reflections. Airy, restrained, sophisticated; thin luminous structure with darker quiet interiors. Gold is sparse and embedded, not thick metal armor. Keep the middle (center x50%, y44%, radius20%) entirely transparent for a separately rendered item glyph. Occupy 80% of the canvas with transparent margins. Open asymmetrical silhouette; do not close a ring around the center.
A shallow fan of five broad paper-thin crystal petals sweeps across the lower third. Two long petals reach the left flank, the right tapers low and almost disappears. Fine gold veins fork once inside each sheet. The top and central area remain open.
No item glyph, text, runes, symbols, star, polygon badge, card, rectangle, thick metal border, floor, cast shadow, glitter, speckled noise, blown-out bloom, or particles. Genuine transparent background. A single detailed crystal ornament, smoothly antialiased high-resolution edges.
```

### sail.png

原始输出：`C:/Users/misss/.codex/generated_images/01a1331d-a3d3-7c92-8956-1710d2385cb3/exec-2e35d8a7-d083-461e-9fd5-bcf26e8220db.png`

```text
Use case: stylized-concept. Asset type: ONE isolated transparent material ornament for the relic selection screen of an elegant dark fantasy game, not an icon or a UI mockup.
Front view, square canvas. Finely polished smoky grey-blue crystal membranes with a few hairline champagne-gold botanical inlays, translucent layers, precise pearly edge reflections. Airy, restrained, sophisticated; thin luminous structure with darker quiet interiors. Gold is sparse and embedded, not thick metal armor. Keep the middle (center x50%, y44%, radius20%) entirely transparent for a separately rendered item glyph. Occupy 80% of the canvas with transparent margins. Open asymmetrical silhouette; do not close a ring around the center.
Two translucent folded glass sails cross below the center, one high narrow sail bends up the right side, the other is a long horizontal silver-blue blade to the left. Gently twisted planes and one fine golden seam; avoid a circle or flower.
No item glyph, text, runes, symbols, star, polygon badge, card, rectangle, thick metal border, floor, cast shadow, glitter, speckled noise, blown-out bloom, or particles. Genuine transparent background. A single detailed crystal ornament, smoothly antialiased high-resolution edges.
```

### ribbon.png

原始输出：`C:/Users/misss/.codex/generated_images/01a1331d-a3d3-7c92-8956-1710d2385cb3/exec-10e54dea-a9a7-49e6-9044-8bb4ecf8097e.png`

```text
Use case: stylized-concept. Asset type: ONE isolated transparent material ornament for the relic selection screen of an elegant dark fantasy game, not an icon or a UI mockup.
Front view, square canvas. Finely polished smoky grey-blue crystal membranes with a few hairline champagne-gold botanical inlays, translucent layers, precise pearly edge reflections. Airy, restrained, sophisticated; thin luminous structure with darker quiet interiors. Gold is sparse and embedded, not thick metal armor. Keep the middle (center x50%, y44%, radius20%) entirely transparent for a separately rendered item glyph. Occupy 80% of the canvas with transparent margins. Open asymmetrical silhouette; do not close a ring around the center.
An airy S-shaped ribbon of paper-thin crystal curls down the LEFT flank, with two fine gold seams following its twist. Its bottom end stretches horizontally to the right below the central area. Exactly one continuous folded strip, not leaves, no circular enclosure.
No item glyph, text, runes, symbols, star, polygon badge, card, rectangle, thick metal border, floor, cast shadow, glitter, speckled noise, blown-out bloom, or particles. Genuine transparent background. A single detailed crystal ornament, smoothly antialiased high-resolution edges.
```

### shell.png

原始输出：`C:/Users/misss/.codex/generated_images/01a1331d-a3d3-7c92-8956-1710d2385cb3/exec-c2e27f07-f578-446c-8942-d80da0662677.png`

```text
Use case: stylized-concept. Asset type: ONE isolated transparent material ornament for the relic selection screen of an elegant dark fantasy game, not an icon or a UI mockup.
Front view, square canvas. Finely polished smoky grey-blue crystal membranes with a few hairline champagne-gold botanical inlays, translucent layers, precise pearly edge reflections. Airy, restrained, sophisticated; thin luminous structure with darker quiet interiors. Gold is sparse and embedded, not thick metal armor. Keep the middle (center x50%, y44%, radius20%) entirely transparent for a separately rendered item glyph. Occupy 80% of the canvas with transparent margins. Open asymmetrical silhouette; do not close a ring around the center.
A single broad concave smoky crystal shell rests in the LOWER RIGHT quarter, with three curved nested inner folds and fine champagne gold seams. One very thin flake rises up the far right, while a low pointed end trails left. Quiet open upper half; a substantial smooth shell form rather than leaves.
No item glyph, text, runes, symbols, star, polygon badge, card, rectangle, thick metal border, floor, cast shadow, glitter, speckled noise, blown-out bloom, or particles. Genuine transparent background. A single detailed crystal ornament, smoothly antialiased high-resolution edges.
```

### fern.png

原始输出：`C:/Users/misss/.codex/generated_images/01a1331d-a3d3-7c92-8956-1710d2385cb3/exec-057ceeea-1157-427f-9e3e-f39e1b9c6b93.png`

```text
Use case: stylized-concept. Asset type: ONE isolated transparent material ornament for the relic selection screen of an elegant dark fantasy game, not an icon or a UI mockup.
Front view, square canvas. Finely polished smoky grey-blue crystal membranes with a few hairline champagne-gold botanical inlays, translucent layers, precise pearly edge reflections. Airy, restrained, sophisticated; thin luminous structure with darker quiet interiors. Gold is sparse and embedded, not thick metal armor. Keep the middle (center x50%, y44%, radius20%) entirely transparent for a separately rendered item glyph. Occupy 80% of the canvas with transparent margins. Open asymmetrical silhouette; do not close a ring around the center.
A delicate single fern-like branch made of nine very thin glass leaflets along a curved gold spine in the LOWER LEFT. The stem bends diagonally upward along the far LEFT edge, ending before upper center. The last three leaflets below center extend right. Airy lacy negative spaces, organic silhouette, no broad ribbon or shell.
No item glyph, text, runes, symbols, star, polygon badge, card, rectangle, thick metal border, floor, cast shadow, glitter, speckled noise, blown-out bloom, or particles. Genuine transparent background. A single detailed crystal ornament, smoothly antialiased high-resolution edges.
```

### tide.png

原始输出：`C:/Users/misss/.codex/generated_images/01a1331d-a3d3-7c92-8956-1710d2385cb3/exec-d2170d40-3cbb-4a80-86dc-5e61673cddbb.png`

```text
Use case: stylized-concept. Asset type: ONE isolated transparent material ornament for the relic selection screen of an elegant dark fantasy game, not an icon or a UI mockup.
Front view, square canvas. Finely polished smoky grey-blue crystal membranes with a few hairline champagne-gold botanical inlays, translucent layers, precise pearly edge reflections. Airy, restrained, sophisticated; thin luminous structure with darker quiet interiors. Gold is sparse and embedded, not thick metal armor. Keep the middle (center x50%, y44%, radius20%) entirely transparent for a separately rendered item glyph. Occupy 80% of the canvas with transparent margins. Open asymmetrical silhouette; do not close a ring around the center.
A single WIDE LOW wave of folded crystal silk across the bottom fifth of the square, forming two shallow curling crests of unequal height. Center and top two-thirds completely empty. Crystal material is thin, elegant, like frozen water with exactly three gold contour veins. Wide horizontal silhouette, no leaves or vertical side frame.
No item glyph, text, runes, symbols, star, polygon badge, card, rectangle, thick metal border, floor, cast shadow, glitter, speckled noise, blown-out bloom, or particles. Genuine transparent background. A single detailed crystal ornament, smoothly antialiased high-resolution edges.
```

### wing.png

原始输出：`C:/Users/misss/.codex/generated_images/01a1331d-a3d3-7c92-8956-1710d2385cb3/exec-d9524cff-2a68-4ff4-98b1-b7744d9ec85e.png`

```text
Use case: stylized-concept. Asset type: ONE isolated transparent material ornament for the relic selection screen of an elegant dark fantasy game, not an icon or a UI mockup.
Front view, square canvas. Finely polished smoky grey-blue crystal membranes with a few hairline champagne-gold botanical inlays, translucent layers, precise pearly edge reflections. Airy, restrained, sophisticated; thin luminous structure with darker quiet interiors. Gold is sparse and embedded, not thick metal armor. Keep the middle (center x50%, y44%, radius20%) entirely transparent for a separately rendered item glyph. Occupy 80% of the canvas with transparent margins. Open asymmetrical silhouette; do not close a ring around the center.
A single fine feather-like crystal wing sweeps diagonally from LOWER LEFT toward UPPER RIGHT, entirely along the right flank of the empty middle. It has seven long tapered parallel translucent barbs and one golden curved spine. Keep lower left root below the middle and central area unobstructed. NOT symmetrical wings, NOT a bird. A long elegant diagonal plume.
No item glyph, text, runes, symbols, star, polygon badge, card, rectangle, thick metal border, floor, cast shadow, glitter, speckled noise, blown-out bloom, or particles. Genuine transparent background. A single detailed crystal ornament, smoothly antialiased high-resolution edges.
```

### fold.png

原始输出：`C:/Users/misss/.codex/generated_images/01a1331d-a3d3-7c92-8956-1710d2385cb3/exec-54f2b937-2e9d-4355-8f5d-de3f64da6081.png`

```text
Use case: stylized-concept. Asset type: ONE isolated transparent material ornament for the relic selection screen of an elegant dark fantasy game, not an icon or a UI mockup.
Front view, square canvas. Finely polished smoky grey-blue crystal membranes with a few hairline champagne-gold botanical inlays, translucent layers, precise pearly edge reflections. Airy, restrained, sophisticated; thin luminous structure with darker quiet interiors. Gold is sparse and embedded, not thick metal armor. Keep the middle (center x50%, y44%, radius20%) entirely transparent for a separately rendered item glyph. Occupy 80% of the canvas with transparent margins. Open asymmetrical silhouette; do not close a ring around the center.
A small sculptural arrangement of three broad angular folded crystal sheets lies across the LOWER THIRD. Like translucent origami silk without a recognizable symbol: one long horizontal plane left, one short upturned triangle on far right, one curved underside. Sparse gold seams, faceted but not a polygon badge. No leaves, no circular arc, no crown, no ring.
No item glyph, text, runes, symbols, star, polygon badge, card, rectangle, thick metal border, floor, cast shadow, glitter, speckled noise, blown-out bloom, or particles. Genuine transparent background. A single detailed crystal ornament, smoothly antialiased high-resolution edges.
```

### petals.png

原始输出：`C:/Users/misss/.codex/generated_images/01a1331d-a3d3-7c92-8956-1710d2385cb3/exec-6142ae94-dc9f-44e5-b0ac-13b2a2348bd9.png`

```text
Use case: stylized-concept. Asset type: ONE isolated transparent material ornament for the relic selection screen of an elegant dark fantasy game, not an icon or a UI mockup.
Front view, square canvas. Finely polished smoky grey-blue crystal membranes with a few hairline champagne-gold botanical inlays, translucent layers, precise pearly edge reflections. Airy, restrained, sophisticated; thin luminous structure with darker quiet interiors. Gold is sparse and embedded, not thick metal armor. Keep the middle (center x50%, y44%, radius20%) entirely transparent for a separately rendered item glyph. Occupy 80% of the canvas with transparent margins. Open asymmetrical silhouette; do not close a ring around the center.
Three large rounded translucent crystal petals overlap diagonally ONLY in the LOWER LEFT quadrant: a tall teardrop at far left, a broad almond below center, and a small curved petal trailing right. Each petal has a fine embedded gold branching vein. Rounded smooth contours unlike sharp shards; no circular flower, no ring, no closed frame.
No item glyph, text, runes, symbols, star, polygon badge, card, rectangle, thick metal border, floor, cast shadow, glitter, speckled noise, blown-out bloom, or particles. Genuine transparent background. A single detailed crystal ornament, smoothly antialiased high-resolution edges.
```

### shards.png

原始输出：`C:/Users/misss/.codex/generated_images/01a1331d-a3d3-7c92-8956-1710d2385cb3/exec-7a24a691-39e4-4326-ba45-38d356fc9aa3.png`

```text
Use case: stylized-concept. Asset type: ONE isolated transparent material ornament for the relic selection screen of an elegant dark fantasy game, not an icon or a UI mockup.
Front view, square canvas. Finely polished smoky grey-blue crystal membranes with a few hairline champagne-gold botanical inlays, translucent layers, precise pearly edge reflections. Airy, restrained, sophisticated; thin luminous structure with darker quiet interiors. Gold is sparse and embedded, not thick metal armor. Keep the middle (center x50%, y44%, radius20%) entirely transparent for a separately rendered item glyph. Occupy 80% of the canvas with transparent margins. Open asymmetrical silhouette; do not close a ring around the center.
Four detached elongated smoky glass shards float at the far LEFT and lower RIGHT of the central empty area. One large curved blade on left with two small companions beneath it, one wide short crystal sheet on lower right. Deliberate asymmetric space between each shard; subtle gold vein inside each; no ring, no branches connecting the shards, no small glitter particles. Front view with clear empty central space.
No item glyph, text, runes, symbols, star, polygon badge, card, rectangle, thick metal border, floor, cast shadow, glitter, speckled noise, blown-out bloom, or particles. Genuine transparent background. A single detailed crystal ornament, smoothly antialiased high-resolution edges.
```
