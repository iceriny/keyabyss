#!/usr/bin/env python3
"""Author smooth optical control fields for the transparent relic ornaments.

The PNGs remain untouched. RG stores signed surface slopes, B thickness, and A
roughness in linear RGBA16F. This is a 2-D relief design, not recovered geometry.
Requires the same NumPy/SciPy/Pillow/OpenEXR environment as build_crystal_fields.
"""
from pathlib import Path
import hashlib
import json

import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt, gaussian_filter

from build_crystal_fields import ROOT, godot_import, save_rgba


def build(source: Path) -> dict:
    rgba = np.asarray(Image.open(source).convert("RGBA").resize((512, 512), Image.Resampling.LANCZOS), dtype=np.float32) / 255
    alpha = rgba[..., 3]
    rgb = rgba[..., :3]
    linear = np.where(rgb <= .04045, rgb / 12.92, ((rgb + .055) / 1.055) ** 2.4)
    luma = linear @ np.array([.2126, .7152, .0722], dtype=np.float32)
    weight = gaussian_filter(alpha, 3.0)
    broad = gaussian_filter(luma * alpha, 3.0) / np.maximum(weight, .001)
    interior = distance_transform_edt(alpha > .35)
    # Rounded bevels follow the actual silhouettes; broad photographed folds
    # add a quieter internal relief. Tiny gold lines do not become noisy normals.
    dome = 1 - np.exp(-interior / 11.0)
    height = gaussian_filter(dome * (.60 + .40 * broad), 1.4)
    dy, dx = np.gradient(height)
    slope = np.stack((dx, dy), -1) * 8.0
    slope /= np.maximum(1.0, np.linalg.norm(slope, axis=-1, keepdims=True) / .82)
    thickness = np.clip(height, 0, 1)
    roughness = np.clip(.30 + .40 * (1 - broad) - .16 * (1 - dome), .18, .72)
    fields = np.concatenate((slope * .5 + .5, thickness[..., None], roughness[..., None]), -1)
    destination = source.with_name(source.stem + "_optics.exr")
    save_rgba(destination, fields)
    godot_import(destination)
    return {"source": source.name, "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            "field": destination.name, "size": [512, 512], "storage": "linear RGBA16F",
            "channels": ["slope_x * .5 + .5", "slope_y * .5 + .5", "thickness", "roughness"]}


if __name__ == "__main__":
    directory = ROOT / "assets/art/ui/relic_ornaments"
    records = [build(source) for source in sorted(directory.glob("*.png"))]
    (directory / "fields.json").write_text(json.dumps(records, indent=2) + "\n", encoding="utf-8")
    print(f"Built {len(records)} optical fields in {directory}")
