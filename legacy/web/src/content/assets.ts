import type { AssetDefinition } from "../contracts/assets.ts";
export const assets = [
  ...(['frost', 'storm', 'spirit', 'flame'] as const).map(school => ({
    id: `rune-${school}`, kind: 'image' as const,
    source: `art/runes/${school}-seal.svg`, src: `./assets/art/${school}-seal.svg`,
  })),
  {
    id: "book-frost",
    kind: "image",
    source: "art/FROST_GRIMOIRE.png",
    src: "./assets/art/FROST_GRIMOIRE.png",
  },
  {
    id: "book-storm",
    kind: "image",
    source: "art/STORM_GRIMOIRE.png",
    src: "./assets/art/STORM_GRIMOIRE.png",
  },
  {
    id: "book-spirit",
    kind: "image",
    source: "art/SPIRIT_GRIMOIRE.png",
    src: "./assets/art/SPIRIT_GRIMOIRE.png",
  },
  {
    id: "book-flame",
    kind: "image",
    source: "art/FLAME_GRIMOIR.png",
    src: "./assets/art/FLAME_GRIMOIR.png",
  },
] as const satisfies readonly AssetDefinition[];
