"""Encode a PNG as lossless SVG paths and create Windows icon sizes.

Each path contains same-color horizontal pixel runs. This preserves the source
RGBA grid exactly without embedding a raster; it does not simplify contours.
"""

import argparse
from collections import defaultdict
from pathlib import Path

from PIL import Image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("svg", type=Path)
    parser.add_argument("--ico", type=Path)
    args = parser.parse_args()
    image = Image.open(args.source).convert("RGBA")
    pixels = image.load()
    paths = defaultdict(list)
    for y in range(image.height):
        x = 0
        while x < image.width:
            color = pixels[x, y]
            end = x + 1
            while end < image.width and pixels[end, y] == color:
                end += 1
            if color[3]:
                paths[color].append(f"M{x} {y}h{end - x}v1h-{end - x}z")
            x = end
    args.svg.parent.mkdir(parents=True, exist_ok=True)
    with args.svg.open("w", encoding="utf-8", newline="\n") as output:
        output.write(
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{image.width}" '
            f'height="{image.height}" viewBox="0 0 {image.width} {image.height}" '
            'shape-rendering="crispEdges">\n'
        )
        for (r, g, b, alpha), runs in paths.items():
            opacity = f' fill-opacity="{alpha / 255:.10f}"' if alpha < 255 else ""
            output.write(f'<path fill="#{r:02x}{g:02x}{b:02x}"{opacity} d="{"".join(runs)}"/>\n')
        output.write("</svg>\n")
    if args.ico:
        args.ico.parent.mkdir(parents=True, exist_ok=True)
        image.save(args.ico, sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])
    print(f"SVG: {args.svg} ({args.svg.stat().st_size:,} bytes, {len(paths):,} RGBA paths)")


if __name__ == "__main__":
    main()
