#!/usr/bin/env python3
"""Build linear, art-directed crystal control maps from a black-background image.

The image supplies scalar radiance, a warm/cool class, and planar ridge guides.
It never supplies a base-color texture or a physically recovered normal map.
Adapted from the supplied gilded-crystal-material-v9 field builder.
Requires Python 3.10+, NumPy, SciPy, Pillow, OpenEXR.
See assets/art/ui/crystal/README.md for channel and source contracts.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np
import OpenEXR
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter, map_coordinates
from scipy.spatial import cKDTree

ROOT = Path(__file__).resolve().parents[2]
GRADIENT_RANGE = 0.7


def blur(a: np.ndarray, sigma: float) -> np.ndarray:
    return gaussian_filter(a, sigma, mode="reflect")


def resize_float(a: np.ndarray, size: tuple[int, int]) -> np.ndarray:
    if a.ndim == 3:
        return np.stack([resize_float(a[..., i], size) for i in range(a.shape[2])], -1)
    return np.asarray(Image.fromarray(a.astype("float32")).resize(size, Image.Resampling.BILINEAR))


def smoothstep(a: float, b: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def scalar_structure(srgb: np.ndarray) -> tuple[np.ndarray, dict]:
    """Preserve reference v2's absolute linear radiance, including dim planes."""
    linear = np.where(srgb <= 0.04045, srgb / 12.92, ((srgb + 0.055) / 1.055) ** 2.4)
    baseline = np.quantile(linear, 0.05, axis=(0, 1)).astype("float32")
    residual = np.maximum(linear - baseline, 0)
    lum = residual @ np.array([0.2126, 0.7152, 0.0722], dtype="float32")
    scale = max(lum.shape) / 1672.0
    broad = blur(lum, max(0.5, 1.2 * scale))
    ridge = np.maximum(lum - broad, 0)
    color_blur = max(0.5, scale)
    ratio = blur(residual[..., 0], color_blur) / (blur(residual[..., 2], color_blur) + 1e-5)
    warm = smoothstep(0.38, 0.98, ratio)
    presence = np.clip(blur(lum, max(0.5, 2.5 * scale)) / 0.065, 0, 1)
    # Half-float stores linear energy directly. Filtering sqrt-encoded radiance
    # then squaring it loses thin-line coverage, especially at fractional scales.
    structure = np.stack((broad, ridge, warm, presence), -1)
    return np.clip(structure, 0, 1), {"lum": lum, "presence": presence, "baseline": baseline}


def ridge_guides(lum: np.ndarray, max_guides: int) -> tuple[list[np.ndarray], dict]:
    """Trace local ridge tangents, with orientation sign resolved at every step.

    Structure-tensor tangents guide direction; lateral attraction keeps a trace
    near bright ridges. These are 2-D design guides, not recovered 3-D edges.
    """
    h, w = lum.shape
    signal = np.log1p(lum * 65.0)
    sy, sx = np.gradient(blur(signal, 0.8))
    jxx, jxy, jyy = blur(sx * sx, 2.0), blur(sx * sy, 2.0), blur(sy * sy, 2.0)
    delta = np.sqrt((jxx - jyy) ** 2 + 4 * jxy * jxy)
    coherence = delta / (jxx + jyy + 1e-7)
    theta = 0.5 * np.arctan2(2 * jxy, jxx - jyy)
    tx, ty = -np.sin(theta), np.cos(theta)
    score = blur(signal, 0.8) * (0.3 + 0.7 * coherence)
    working = score.copy()
    yy, xx = np.mgrid[:h, :w]
    guides: list[np.ndarray] = []

    def sample(a: np.ndarray, p: np.ndarray) -> float:
        return float(map_coordinates(a, [[p[1]], [p[0]]], order=1, mode="nearest")[0])

    def trace(origin: np.ndarray, direction: float) -> list[np.ndarray]:
        p = origin.copy()
        previous = np.array([sample(tx, p), sample(ty, p)]) * direction
        points = []
        for _ in range(int(max(h, w) * 0.46)):
            tangent = np.array([sample(tx, p), sample(ty, p)])
            if np.dot(tangent, previous) < 0:
                tangent *= -1
            confidence = sample(coherence, p)
            tangent = tangent * (0.38 + 0.37 * confidence) + previous * (0.62 - 0.37 * confidence)
            tangent /= max(np.linalg.norm(tangent), 1e-8)
            normal = np.array([-tangent[1], tangent[0]])
            proposal = p + tangent * 1.4
            # Keep attraction subpixel so a bright crossing does not snap a line.
            left, center, right = [sample(signal, proposal + normal * v) for v in (-1.5, 0, 1.5)]
            attraction = np.clip((right - left) / (abs(center) + 0.04), -0.65, 0.65)
            proposal += normal * attraction
            if not (1 <= proposal[0] < w - 1 and 1 <= proposal[1] < h - 1):
                break
            if len(points) > 12 and sample(signal, proposal) < 0.009:
                break
            if len(points) > 20 and np.linalg.norm(proposal - points[-18]) < 8:
                break
            points.append(proposal.copy())
            previous = (proposal - p) / max(np.linalg.norm(proposal - p), 1e-8)
            p = proposal
        return points

    minimum = max(float(score.max()) * 0.022, 0.009)
    for _ in range(max_guides):
        iy, ix = np.unravel_index(np.argmax(working), working.shape)
        if working[iy, ix] < minimum:
            break
        origin = np.array([ix, iy], dtype="float64")
        backward, forward = trace(origin, -1), trace(origin, 1)
        points = np.array(list(reversed(backward)) + [origin] + forward)
        if len(points) >= 16:
            # Smooth geometric trajectories; no luminance becomes height.
            points = gaussian_filter(points, (1.3, 0), mode="nearest")
            guides.append(points)
            distance, _ = cKDTree(points).query(np.column_stack((xx.ravel(), yy.ravel())))
            working *= smoothstep(3.0, max(12.0, h * 0.055), distance.reshape(h, w))
        else:
            working *= smoothstep(2.0, max(10.0, h * 0.08), np.hypot(xx - ix, yy - iy))
    return guides, {"coherence": coherence, "tangent": np.stack([tx, ty], -1)}


def guided_fields(lum: np.ndarray, presence: np.ndarray, seed: int, max_guides: int, surface_mask: np.ndarray | None = None) -> tuple[np.ndarray, np.ndarray, dict]:
    """Arc-length flow plus an explicitly authored scalar fold-height field."""
    full_h, full_w = lum.shape
    ratio = min(1.0, 480.0 / max(full_w, full_h))
    w, h = max(16, round(full_w * ratio)), max(16, round(full_h * ratio))
    small = resize_float(lum, (w, h))
    guides, info = ridge_guides(small, max_guides)
    yy, xx = np.mgrid[:h, :w].astype("float64")
    pixels = np.column_stack((xx.ravel(), yy.ravel()))
    narrow_sum, broad_sum, phase_sum, wide_phase_sum = [np.zeros((h, w)) for _ in range(4)]
    largest = np.zeros((h, w))
    height, thickness = np.zeros((h, w)), np.zeros((h, w))
    rng = np.random.default_rng(seed)
    for i, points in enumerate(guides):
        distances, indices = cKDTree(points).query(pixels)
        nearest = points[indices]
        tangent = np.gradient(points, axis=0)
        tangent /= np.maximum(np.linalg.norm(tangent, axis=-1, keepdims=True), 1e-8)
        directions = tangent[indices]
        normal = np.column_stack((-directions[:, 1], directions[:, 0]))
        displacement = pixels - nearest
        arc = np.concatenate(([0.0], np.cumsum(np.linalg.norm(np.diff(points, axis=0), axis=1))))
        longitudinal = ((arc[indices] - arc[-1] * 0.5 + np.sum(displacement * directions, -1)) / h).reshape(h, w)
        lateral = (np.sum(displacement * normal, -1) / h).reshape(h, w)
        radial = distances.reshape(h, w) / h
        width = float(rng.uniform(0.035, 0.075))
        phase_offset = float(rng.uniform(-0.42, 0.42))
        length = max(arc[-1] / h, 0.1)
        along = np.exp(-np.maximum(np.abs(longitudinal) - length * 0.40, 0) ** 2 / 0.07 ** 2)
        narrow = np.exp(-(radial / 0.022) ** 2) * along
        wide = np.exp(-(radial / (width * 1.6)) ** 2) * along
        # Bounded, unwrapped phases: no 0/1 wrap seam in the stored textures.
        # Their gradients follow each curve's own arclength and local normal.
        local_phase = 0.5 + 0.39 * np.tanh(longitudinal * 1.4 + phase_offset)
        local_wide_phase = 0.5 + 0.36 * np.tanh(longitudinal * 0.88 + lateral * 1.6 + phase_offset + 0.16 * np.sin(longitudinal * 3.0 + i))
        phase_sum += narrow * local_phase
        wide_phase_sum += wide * local_wide_phase
        narrow_sum += narrow
        broad_sum += wide
        largest = np.maximum(largest, narrow)
        # Height amplitude, profile, and sign are authorial choices, not source
        # brightness. Differentiating THIS scalar field produces integrable slopes.
        amplitude = float(rng.uniform(0.10, 0.19)) * (-1 if i % 3 == 1 else 1)
        # Unsigned distance is continuous at the nearest-sample boundaries and
        # creates a gently rounded fold valley; no discontinuous tangent sign.
        profile = np.sqrt(radial * radial + 0.003 ** 2)
        sheet = np.exp(-(radial / (width * 1.4)) ** 2) * along
        height += amplitude * profile * sheet
        thickness += (0.08 + 0.05 * (i % 3) / 2.0) * sheet

    phase = phase_sum / np.maximum(narrow_sum, 1e-10)
    wide_phase = wide_phase_sum / np.maximum(broad_sum, 1e-10)
    # Fade unsupported data to a neutral phase. The same support also gates flow.
    phase = 0.5 + (phase - 0.5) * smoothstep(0.001, 0.08, narrow_sum)
    wide_phase = 0.5 + (wide_phase - 0.5) * smoothstep(0.001, 0.08, broad_sum)
    dominance = largest / np.maximum(narrow_sum, 1e-10)
    support = np.clip(narrow_sum, 0, 1)
    wide_support = np.clip(broad_sum, 0, 1)
    local_energy = np.clip(blur(small, 0.8) / 0.035, 0, 1)
    flow_mask = np.sqrt(local_energy) * support * (0.65 + 0.35 * dominance)
    refract_mask = np.sqrt(np.clip(blur(small, 1.8) / 0.025, 0, 1)) * wide_support
    flow_small = np.stack((blur(phase, 1.35), blur(wide_phase, 2.2), flow_mask, refract_mask), -1)
    flow = np.clip(resize_float(flow_small, (full_w, full_h)), 0, 1)
    if surface_mask is not None:
        flow[..., 2:] *= surface_mask[..., None]
    # Derivatives in aspect-correct screen units: one unit equals image height.
    authored_height = blur(resize_float(blur(height, 1.35), (full_w, full_h)), max(0.5, full_h / 941.0))
    if surface_mask is not None:
        authored_height *= surface_mask
    gy, gx = np.gradient(authored_height, 1 / max(full_h - 1, 1), 1 / max(full_h - 1, 1))
    slopes = np.stack((gx, gy), -1)
    # Normalize the whole height field, never clip individual slope components:
    # component clipping would destroy the scalar field's integrable gradient.
    slope_scale = min(1.0, (GRADIENT_RANGE * 0.98) / max(float(np.abs(slopes).max()), 1e-8))
    slopes *= slope_scale
    authored_height *= slope_scale
    thick = np.clip(resize_float(thickness, (full_w, full_h)) / 0.6, 0, 1)
    valid = resize_float(wide_support, (full_w, full_h)) * smoothstep(0.001, 0.06, presence)
    if surface_mask is not None:
        thick *= surface_mask
        valid *= surface_mask
    gradient = np.dstack((slopes / (2 * GRADIENT_RANGE) + 0.5, thick, valid))
    info.update({"guides": guides, "work_size": [w, h], "slope_max": float(np.abs(slopes).max()), "height": authored_height, "slope_scale": slope_scale})
    return flow, np.clip(gradient, 0, 1), info


def save_rgba(path: Path, value: np.ndarray) -> None:
    if not np.isfinite(value).all():
        raise ValueError(f"Nonfinite data in {path}")
    temporary = path.with_suffix(path.suffix + ".tmp")
    OpenEXR.File({"compression": OpenEXR.ZIP_COMPRESSION,
                 "type": OpenEXR.scanlineimage},
                {"RGBA": np.ascontiguousarray(value, dtype=np.float16)}).write(str(temporary))
    temporary.replace(path)


def godot_import(path: Path) -> None:
    """Write deterministic lossless import metadata without changing any shader."""
    try:
        relative = path.resolve().relative_to(ROOT)
    except ValueError:
        return  # Standalone outputs need no project-specific .import file.
    import_path = Path(str(path) + ".import")
    if import_path.exists():
        return  # Keep Godot's UID and the checked-in data import settings.
    resource = "res://" + relative.as_posix()
    imported = "res://.godot/imported/" + path.name + "-" + hashlib.md5(resource.encode()).hexdigest() + ".ctex"
    text = f'''[remap]

importer="texture"
type="CompressedTexture2D"
path="{imported}"
metadata={{
"vram_texture": false
}}

[deps]

source_file="{resource}"
dest_files=["{imported}"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=0
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=false
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
'''
    import_path.write_text(text, encoding="utf-8")


def diagnostics(path: Path, structure: np.ndarray, flow: np.ndarray, gradient: np.ndarray, info: dict) -> None:
    panels = [
        ("BROAD: linear scalar radiance", np.sqrt(structure[..., 0])),
        ("RIDGE: linear scalar radiance x3", np.sqrt(structure[..., 1]) * 3),
        ("WARM CLASS x PRESENCE", structure[..., 2] * structure[..., 3]),
        ("RIDGE PHASE (10 phase bands)", (0.5 + 0.5 * np.cos(flow[..., 0] * 10 * np.pi)) * flow[..., 2]),
        ("BROAD PHASE (10 phase bands)", (0.5 + 0.5 * np.cos(flow[..., 1] * 10 * np.pi)) * structure[..., 3]),
        ("FLOW / REFRACTION / VALID masks", np.dstack((flow[..., 2], flow[..., 3], gradient[..., 3]))),
        ("AUTHORED GRADIENT (not recovered)", gradient[..., :3]),
        ("AUTHORED THICKNESS", gradient[..., 2]),
        ("CURVE GUIDES (2-D art topology)", structure[..., 0]),
    ]
    tw, th = 440, round(440 * structure.shape[0] / structure.shape[1])
    canvas = Image.new("RGB", (tw * 3, (th + 32) * 3 + 35), (20, 23, 29))
    draw = ImageDraw.Draw(canvas)
    draw.text((10, 10), "LINEAR ENGINEERING DATA / NOT A MATERIAL RENDER / ART-DIRECTED GEOMETRY", fill="white")
    for i, (title, data) in enumerate(panels):
        if data.ndim == 2:
            data = np.repeat(data[..., None], 3, -1)
        im = Image.fromarray(np.uint8(np.clip(data, 0, 1) * 255)).resize((tw, th), Image.Resampling.LANCZOS)
        if i == 8:
            guide_draw = ImageDraw.Draw(im)
            ww, hh = info["work_size"]
            for j, curve in enumerate(info["guides"]):
                coords = [(float(p[0] * tw / ww), float(p[1] * th / hh)) for p in curve]
                guide_draw.line(coords, fill=(100 + j * 41 % 155, 230, 120 + j * 17 % 135), width=2)
        left, top = i % 3 * tw, i // 3 * (th + 32) + 35
        draw.text((left + 8, top + 9), title, fill="white")
        canvas.paste(im, (left, top + 32))
    canvas.save(path)


def build(source: Path, output_dir: Path, name: str, seed: int = 0, max_guides: int = 18, make_diagnostics: bool = True, pad_aspect: bool = True) -> dict:
    original = Image.open(source).convert("RGB")
    original_size = list(original.size)
    padding = [0, 0, 0, 0]
    if pad_aspect and abs(original.width / original.height - 16 / 9) > 0.003:
        # Preserve every original pixel. Extend only the black negative space,
        # rather than stretching the guide geometry or cutting off bright ridges.
        unit = math.ceil(max(original.width / 16, original.height / 9))
        canvas = Image.new("RGB", (unit * 16, unit * 9), "black")
        left, top = (canvas.width - original.width) // 2, (canvas.height - original.height) // 2
        canvas.paste(original, (left, top))
        padding = [left, top, canvas.width - original.width - left, canvas.height - original.height - top]
        original = canvas
    srgb = np.asarray(original, dtype="float32") / 255.0
    surface_mask = None
    feather_px = [0.0, 0.0]
    if any(padding):
        # Fade at the ORIGINAL content rectangle, not merely the padded canvas.
        # This avoids bright crystal ridges ending in a vertical crop line.
        feather_px = [original_size[0] * 0.04, original_size[1] * 0.04]
        ph, pw = srgb.shape[:2]
        yy, xx = np.mgrid[:ph, :pw].astype("float32")
        left, top, right, bottom = padding
        surface_mask = np.ones((ph, pw), dtype="float32")
        if left:
            surface_mask *= smoothstep(0, feather_px[0], xx - left)
        if right:
            surface_mask *= smoothstep(0, feather_px[0], pw - 1 - right - xx)
        if top:
            surface_mask *= smoothstep(0, feather_px[1], yy - top)
        if bottom:
            surface_mask *= smoothstep(0, feather_px[1], ph - 1 - bottom - yy)
        linear = np.where(srgb <= 0.04045, srgb / 12.92, ((srgb + 0.055) / 1.055) ** 2.4)
        linear *= surface_mask[..., None]
        srgb = np.where(linear <= 0.0031308, linear * 12.92, 1.055 * np.maximum(linear, 0) ** (1 / 2.4) - 0.055)
    if min(srgb.shape[:2]) < 16:
        raise ValueError("Source image must be at least 16 pixels in both dimensions.")
    structure, raw = scalar_structure(srgb)
    flow, gradient, info = guided_fields(raw["lum"], raw["presence"], seed, max_guides, surface_mask)
    output_dir.mkdir(parents=True, exist_ok=True)
    files = {}
    for suffix, values in (("structure", structure), ("flow", flow), ("gradient", gradient)):
        # Flow / rounded geometry are low-frequency fields traced on a 480 px
        # domain. Half-size float textures keep their precision without spending
        # full-resolution memory on interpolated copies of the same information.
        if suffix != "structure":
            values = resize_float(values, (round(original.width / 2), round(original.height / 2)))
        path = output_dir / f"{name}_{suffix}.exr"
        save_rgba(path, values)
        godot_import(path)
        files[suffix] = str(path.resolve())
    report = {
        "schema": "crystal_half_fields_v2", "name": name,
        "source": str(source.resolve()), "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "size": [srgb.shape[1], srgb.shape[0]], "source_size": original_size,
        "control_size": [round(original.width / 2), round(original.height / 2)],
        "black_padding_ltrb": padding, "content_edge_feather_px": feather_px,
        "seed": seed, "guide_count": len(info["guides"]),
        "max_guides": max_guides, "baseline_linear_rgb": raw["baseline"].tolist(),
        "decoded_broad_max": float(np.max(structure[..., 0])),
        "decoded_ridge_max": float(np.max(structure[..., 1])),
        "flow_mask_mean": float(flow[..., 2].mean()), "flow_mask_max": float(flow[..., 2].max()),
        "gradient_abs_max": info["slope_max"], "authored_height_scale": info["slope_scale"], "files": files,
        "linear_data": True, "storage": "RGBA16F", "premultiplied": False, "source_rgb_is_base_color": False,
        "geometry": "independently authored fold height along image-guided 2-D curves; not physical reconstruction",
    }
    manifest = output_dir / f"{name}_fields.json"
    manifest.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if make_diagnostics:
        diagnostics(output_dir / f"{name}_diagnostics.png", structure, flow, gradient, info)
    print(json.dumps(report, ensure_ascii=False, indent=2), flush=True)
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sources", nargs="+", type=Path, help="Black-background RGB crystal images; shell globs accepted")
    parser.add_argument("--output-dir", type=Path, default=ROOT / "assets/art/ui/crystal")
    parser.add_argument("--name", help="Output prefix, only allowed with a single source; otherwise source stem")
    parser.add_argument("--seed", type=int, default=0, help="Independent authored-height seed; batch increments per image")
    parser.add_argument("--max-guides", type=int, default=18)
    parser.add_argument("--no-diagnostics", action="store_true")
    parser.add_argument("--keep-aspect", action="store_true", help="Do not pad non-16:9 input with black space")
    args = parser.parse_args()
    if args.name and len(args.sources) != 1:
        parser.error("--name requires exactly one source")
    for i, source in enumerate(args.sources):
        build(source, args.output_dir, args.name or source.stem, args.seed + i, args.max_guides, not args.no_diagnostics, not args.keep_aspect)


if __name__ == "__main__":
    main()
