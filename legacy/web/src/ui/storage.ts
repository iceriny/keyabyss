import type { Vocabulary, Settings } from "../contracts/game.ts";
export * as C from "../bootstrap/catalog-api.ts";
import * as C from "../bootstrap/catalog-api.ts";
import { StorageAdapter } from "../platform/StorageAdapter.ts";
export const storage = new StorageAdapter(() => localStorage);
export const read = <T>(key: string, fallback: T): T =>
  storage.read(key, fallback);
export const save = (key: string, value: unknown) => storage.save(key, value);
export function customBooks(): Vocabulary[] {
  const value = read<Vocabulary[]>("custom", []);
  return (Array.isArray(value) ? value : []).flatMap((b) => {
    try {
      const words = C.normalize(b.words).words;
      return words.length && typeof b.id === "string"
        ? [{ ...b, words, custom: true }]
        : [];
    } catch {
      return [];
    }
  });
}
export const defaultSettings: Settings = {
  volume: 0.28,
  sfxVolume: 1,
  shake: 0.5,
  largeText: false,
  fx: 1,
  meaning: true,
  labelMeaning: false,
  music: true,
  sound: true,
  reduceMotion: matchMedia("(prefers-reduced-motion: reduce)").matches,
};
export const fmt = (t: number) =>
  `${Math.floor(t / 60)
    .toString()
    .padStart(2, "0")}:${Math.floor(t % 60)
    .toString()
    .padStart(2, "0")}`;
export function download(value: unknown, name: string) {
  const url = URL.createObjectURL(
    new Blob([JSON.stringify(value, null, 2)], {
      type: "application/json;charset=utf-8",
    }),
  );
  const a = document.createElement("a");
  a.href = url;
  a.download = name;
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
const commands: Record<string, string> = {
  primary1: "grade1",
  primary2: "grade2",
  primary3: "grade3",
  primary4: "grade4",
  primary5: "grade5",
  primary6: "grade6",
  junior: "junior",
  senior: "senior",
  cet4: "cet4",
  cet6: "cet6",
  cpp: "cpp",
  extension: "lexicon",
};
export const vocabCommand = (b: Vocabulary, i: number) =>
  commands[b.id] || b.uiWord || `local${String(i + 1).padStart(2, "0")}`;
