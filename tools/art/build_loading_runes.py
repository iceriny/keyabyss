"""Compose the startup progress textures from the supplied Arcana384 vectors."""
from pathlib import Path
import xml.etree.ElementTree as ET

ET.register_namespace("", "http://www.w3.org/2000/svg")

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "docs/art/Arcana384/svg-clean"
TARGET = ROOT / "assets/art/ui"
TARGET.mkdir(parents=True, exist_ok=True)

def glyph(number):
    svg = ET.parse(SOURCE / f"rune-{number:03}.svg").getroot()
    group = list(svg)[1]
    group.set("stroke", "#ffffff")
    return ET.tostring(group, encoding="unicode")

runes = [1, 7, 16, 25, 34, 49, 58, 67, 82, 97, 115, 130,
         145, 163, 178, 193, 211, 229, 247, 265, 289, 313, 337, 361]
parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="384" height="384" viewBox="0 0 384 384">']
for index, number in enumerate(runes):
    parts.append(f'<g transform="translate(192 192) rotate({index * 15}) translate(-16 -174) scale(.25)">{glyph(number)}</g>')
parts.append('</svg>')
(TARGET / "loading_runes.svg").write_text('\n'.join(parts), encoding="utf-8")
(TARGET / "loading_core.svg").write_text('<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">' + glyph(67) + '</svg>', encoding="utf-8")
