# 晶纹母图生成记录

使用内置 image_gen 逐张编辑用户提供的 Demo 参考；输出原件已复制到本目录。四张实测均为 1672×941，未把提示中的分辨率请求当作实际输出，也未用插值放大文件冒充新增细节。源图只用于离线生成光学字段，不作为运行时底图。

## branch_fan.png

编辑参考：`F:/Workshop/game/gilded-crystal-material-v9/reference/variants/variant_01.png`。

最终提示词：

```text
Use case: precise-object-edit.
Asset type: high-resolution crystal vein source texture for a sophisticated dark fantasy game's borderless optical UI; not a UI screenshot.
Edit target: the attached blue and gold crystalline membrane. Rebuild the image at 3840 x 2160 resolution with genuinely fine, smoothly antialiased material detail. Preserve its large organic composition: a branching, gently curved transparent crystal fan rooted at the lower left (x 8%, y 81%), sweeping upward through the left third and extending delicate long arcs to the right. Keep the entire central-right half mostly absolute black negative space.
Refinement: very thin translucent layered crystal membranes, broad quiet smoky-blue planes, a few fluid hairline pale-gold inlays following botanical curves. Smooth continuous edges, fine internal etched striations aligned with the long curves, natural thickness and pearly refraction. Details should resolve cleanly when cropped large. Focus beauty in two restrained luminous intersections; all other veins recede gracefully. Reduce the starburst root drastically: a soft warm glint with no white blown-out center, no rays, no sparks. Clean black backdrop, matte-dark low-energy interiors, understated exquisite craft.
Keep the reference's asymmetry, open branching silhouette, cool mineral blue with champagne-gold highlights, softly disappearing extremities. No rectangular panel, frame, hard contour around a container, glyph, text, grain, glitter, noisy speckles, repeating scales, cracks, tiny separate gems, opaque solid crystal, or fog cloud. Highest available native resolution, landscape 16:9.
```

## river.png

编辑参考：`F:/Workshop/game/gilded-crystal-material-v9/reference/variants/variant_02.png`。

最终提示词：

```text
Use case: precise-object-edit.
Asset type: finely resolved source art for an animated borderless crystal UI.
Edit target: attached horizontal crystalline river. Preserve the composition and long connected arc from the left edge through the lower middle toward the right edge, leaving the upper half pure black negative space. Reconstruct the crystal surfaces with clean, smoothly antialiased curves, subtle flowing internal etching, pale sapphire transparent planes and a few fine champagne-gold threads.
Make the membranes broader, calmer and more graceful; the fine detail should follow the large curved folds, without small repeating cells. Quiet black interiors, a few delicate pearly refraction bands. Reduce all bright junctions to small warm glints with soft rolloff. No white starburst cores or rays, no scattered dust, glitter or grain. Edges must be continuous and silky but finely resolved, no rough crackle, pixel edges or overly blurred details.
Keep the exact open horizontal sweep and asymmetrical overlapping folds; no panel, glass rectangle, border, words or symbols. Highest available resolution, landscape 16:9, intended for large peripheral crops in a 2560x1440 UI.
```

## ascending.png

编辑参考：`F:/Workshop/game/gilded-crystal-material-v9/reference/variants/variant_03.png`。

最终提示词：

```text
Use case: precise-object-edit.
Asset type: source texture for an elegant animated open crystal UI.
Edit target: the attached left-side ascending crystal branch. Keep the exact large S-shaped sweep from bottom-left to the top at x25%, a small right-facing branch near the middle, and the entire right half pure black.
Rebuild for precise enlarged display: continuous smooth antialiased ridges, flowing long transparent layered folds with fine internal etched striations, a few gentle pale-gold veins, smoky sapphire and restrained pearlescent reflections. Broader calm planes instead of tiny repeating fragments. Organic botanical grace, dark interiors and clean negative space. One jewel-like small warm glint at the middle branch junction, other intersections much softer. Remove scattered points, sparkles, grain, starburst rays, blown-out white and gritty cracks.
No closed silhouette, rectangular glass panel or frame, text, symbols or detached small crystals. Keep open edges disappearing naturally into the black. Highest native resolution possible, 16:9 landscape, artwork intended for cropping at the edge of a 2560x1440 game interface.
```

## canopy.png

编辑参考：`F:/Workshop/game/gilded-crystal-material-v9/reference/variants/variant_04.png`。

最终提示词：

```text
Use case: precise-object-edit.
Asset type: high-resolution crystal vein source texture for a dark fantasy game's open optical UI.
Edit target: the attached top-right crystal branch. Reconstruct at 3840 x 2160 with truly high-resolution smoothly antialiased thin ridges and translucent internal detail. Preserve the composition: a connected open crystal membrane entering from top and right edges, with its two junctions near (74%,20%) and (83%,42%), long tapered arcs sweeping toward bottom left. The left half and bottom-left must remain pure black negative space.
Refine into a few large, graceful botanical curves in smoky sapphire glass with fine pale champagne-gold inlays. Layered transparent folds with delicate continuous internal striations, subtle pearly edges, natural thick-to-thin transitions. Long connected form, restrained fine craftsmanship. Lower intensity of the two junctions substantially; soft small warm glints without starburst rays or blown-out white, so the junctions are subtle jewel-like accents. Keep broad planes dim and smooth and the fine ridges clean and continuous. Eliminate random sparkles/grain.
Keep asymmetrical open silhouette, blue/gold palette, softly fading tips. No frame, panel, container, text, symbols, small separate gems, white glare, noise or repeating cells. Landscape 16:9, highest available native resolution.
```
