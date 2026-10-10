"""Bake a Reiter hexagonal diffusion/receptive-cell growth study; no runtime solver.

Based on C. Reiter, A Local Cellular Model for Snow Crystal Growth (2005).
Output is an art study with mass and first-freeze time, not a physical prediction.
Requires numpy and Pillow. Run from the repository root.
"""
from pathlib import Path
import json
import time

import numpy as np
from PIL import Image


def neighbors(a):
    return (np.roll(a, 1, 0), np.roll(a, -1, 0), np.roll(a, 1, 1),
            np.roll(a, -1, 1), np.roll(np.roll(a, 1, 0), -1, 1),
            np.roll(np.roll(a, -1, 0), 1, 1))


def grow(seed, beta, steps=1800, n=256):
    rng = np.random.default_rng(seed)
    # Small spatial vapor variation breaks perfect sixfold repetition.
    mass = np.full((n, n), beta, np.float32) + rng.normal(0, 0.003, (n, n)).astype(np.float32)
    frozen_at = np.full((n, n), steps, np.float32)
    for _ in range(5):
        x, y = rng.integers(-3, 4, 2) + n // 2
        mass[y, x] = 1.0
        frozen_at[y, x] = 0
    yy, xx = np.mgrid[:n, :n].astype(np.float32) - n / 2
    radial = np.hypot(xx + yy * 0.5, yy * 0.8660254)
    boundary = radial > n * 0.45
    for step in range(steps):
        ice = mass >= 1
        receptive = ice.copy()
        for near in neighbors(ice):
            receptive |= near
        vapor = np.where(receptive, 0, mass)
        diffusion = vapor * 0.5 + sum(neighbors(vapor)) / 12.0
        gamma = 0.0001 if step < steps * 0.65 else 0.0005
        mass = diffusion + np.where(receptive, mass + gamma, 0)
        mass[boundary] = beta
        newly_frozen = (mass >= 1) & (frozen_at == steps)
        frozen_at[newly_frozen] = step
        if np.any(newly_frozen & (radial > n * 0.40)):
            break
    # Resample the axial lattice onto an orthogonal bitmap without a skewed snowflake.
    out_y, out_x = np.mgrid[:512, :512].astype(np.float32)
    world_x = (out_x - 256) * n / 512
    world_y = (out_y - 256) * n / 512
    sy = world_y / 0.8660254 + n / 2
    sx = world_x - world_y / 0.8660254 * 0.5 + n / 2
    ix = np.clip(np.rint(sx).astype(int), 0, n - 1)
    iy = np.clip(np.rint(sy).astype(int), 0, n - 1)
    density = np.clip((mass[iy, ix] - 0.9) * 2.0, 0, 1)
    birth = frozen_at[iy, ix] / max(1, step)
    rgba = np.zeros((512, 512, 4), np.uint8)
    rgba[:, :, :3] = (160, 214, 237)
    rgba[:, :, 3] = (density * 255).astype(np.uint8)
    data = np.stack([density, np.clip(birth, 0, 1), np.clip(mass[iy, ix] / 3, 0, 1)], axis=-1)
    return Image.fromarray(rgba), Image.fromarray((data * 255).astype(np.uint8)), step + 1


def main():
    target = Path('.temp/element-vfx-20261008/growth-study')
    target.mkdir(parents=True, exist_ok=True)
    records = []
    for seed, beta in [(12, 0.35), (73, 0.4), (145, 0.5)]:
        start = time.perf_counter()
        color, data, iterations = grow(seed, beta)
        color.save(target / f'crystal-{seed}.png')
        preview = Image.new('RGBA', color.size, (14, 25, 29, 255))
        preview.alpha_composite(color)
        preview.convert('RGB').save(target / f'preview-{seed}.png')
        data.save(target / f'growth-{seed}.png')
        records.append(dict(seed=seed, beta=beta, cells=256**2, iterations=iterations,
                            cpu_seconds=round(time.perf_counter() - start, 3)))
    (target / 'metrics.json').write_text(json.dumps(records, indent=2), encoding='utf-8')
    print(json.dumps(records, indent=2))


if __name__ == '__main__':
    main()
