import fs from "node:fs";
import { runeGlyphs, starPath } from "../src/shared/sigil.ts";
const motifs = {
  frost:
    "M0 -120V120M-104 -60L104 60M-104 60L104 -60M-25 -88L0 -65L25 -88M-25 88L0 65L25 88",
  storm: "M-8 -125L-63 -12H8L-29 127L76 -36H8L43 -125Z",
  spirit:
    "M0 -122C116 -58 116 58 0 122C-116 58 -116 -58 0 -122ZM-122 0C-58 -116 58 -116 122 0C58 116 -58 116 -122 0Z",
  flame:
    "M0 -128C-26 -65 75 -37 33 32C90 0 98 89 0 126C-95 89 -80 25 -35 -8C-58 81 30 61 0 -128Z",
};
for (const [school, motif] of Object.entries(motifs)) {
  const circles = [476, 467, 432, 424, 390, 376, 165, 152]
    .map((r, i) => `<circle r="${r}" opacity="${i % 2 ? 0.65 : 0.35}"/>`)
    .join("");
  const runes = Array.from(
    { length: 60 },
    (_, i) =>
      `<g transform="rotate(${i * 6}) translate(0 -449) scale(2.3)"><path d="${runeGlyphs[(i + (school === "storm" ? 3 : 0)) % 12]}" stroke-width=".65"/></g>`,
  ).join("");
  const nodes = Array.from(
    { length: 6 },
    (_, i) =>
      `<g transform="rotate(${i * 60})"><path d="M0 -494V-465M-8 -485H8M0 -376V-348"/><g transform="translate(0 -287)"><circle r="58"/><circle r="51" opacity=".55"/><path d="${starPath(0, 0, 43, 5, 2)}" opacity=".65"/><circle r="20"/><path d="${runeGlyphs[i * 2]}" transform="scale(3.1)"/></g></g>`,
  ).join("");
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" fill="none" stroke="white" stroke-width="1.5"><g transform="translate(512 512)">${circles}${runes}<path d="${starPath(0, 0, 388, 7, 3)}" opacity=".4"/><path d="${starPath(0, 0, 373, 7, 2)}" opacity=".22"/>${nodes}<path d="${motif}" stroke-width="2.5"/><circle r="12"/></g></svg>`;
  fs.writeFileSync(
    new URL(`../art/runes/${school}-seal.svg`, import.meta.url),
    svg + "\n",
  );
}
console.log("Generated four layered rune seals.");
