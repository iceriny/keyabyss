"""Bake a periodic clustered point field; the runtime shader advects its density.

Run with Python + Pillow. No source imagery, regular point lattice or frame atlas.
"""
from array import array
from math import cos, sin, exp, erf, sqrt, floor, ceil, tau
from pathlib import Path
from random import Random

from PIL import Image


SIZE = 2048
OUTPUT = Path(__file__).resolve().parents[2] / "assets/art/effects/ritual_dust.png"
rng = Random(714209)
field = array("f", [0.0]) * (SIZE * SIZE)


def grain(x, y):
    radius = rng.uniform(0.38, 0.92)
    energy = rng.uniform(0.28, 0.95)
    # Pixel-integrated Gaussian preserves grains below one texel in size.
    sigma = radius * sqrt(2.0)
    reach = ceil(radius * 3.0)
    for py in range(floor(y) - reach, floor(y) + reach + 1):
        fy = (erf((py + 1 - y) / sigma) - erf((py - y) / sigma)) * 0.5
        for px in range(floor(x) - reach, floor(x) + reach + 1):
            fx = (erf((px + 1 - x) / sigma) - erf((px - x) / sigma)) * 0.5
            field[(py % SIZE) * SIZE + px % SIZE] += fx * fy * energy


# Broad bent clouds contain independently placed grains. Sampling continuous
# distributions avoids the tiny isolated blotches produced by child clusters.
for _ in range(5000):
    grain(rng.random() * SIZE, rng.random() * SIZE)
for _ in range(16):
    parent_x, parent_y = rng.random() * SIZE, rng.random() * SIZE
    angle = rng.random() * tau
    major, minor = rng.uniform(240, 540), rng.uniform(55, 130)
    bend = rng.uniform(-0.35, 0.35)
    phase = rng.random() * tau
    for _ in range(rng.randint(2000, 4200)):
        u, v = rng.gauss(0, major), rng.gauss(0, minor)
        v += sin(u / (major * 0.8) + phase) * major * bend
        x = parent_x + cos(angle) * u - sin(angle) * v
        y = parent_y + sin(angle) * u + cos(angle) * v
        grain(x, y)

image = Image.frombytes("L", (SIZE, SIZE), bytes(round(255 * (1 - exp(-value))) for value in field))
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
image.save(OUTPUT)
print(f"Baked periodic clustered dust: {OUTPUT} ({OUTPUT.stat().st_size} bytes)")
