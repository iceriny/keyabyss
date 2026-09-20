export type { BookId, ModeId } from "./content-ids.ts";
import type { BookId, ModeId } from "./content-ids.ts";

export type GameState =
  "home" | "playing" | "paused" | "upgrade" | "route" | "result";
export interface Word {
  word: string;
  meaning?: string;
}
export interface Vocabulary {
  id: string;
  title: string;
  words: Word[];
  count?: number;
  asset?: string;
  custom?: boolean;
  synced?: boolean;
  uiWord?: string;
  source?: string;
  sourceLabel?: string;
  scope?: string;
  description?: string;
  snapshot?: string;
  upstreamFile?: string;
  upstreamFiles?: string[];
}
export type { Book, Mode, Relic } from "./content.ts";
import type { Book, Mode, Relic } from "./content.ts";
export interface ImportResult {
  words: Word[];
  raw: number;
  duplicates: number;
  invalid: string[];
  initials: number;
  title: string;
}
export interface Settings {
  volume: number;
  sfxVolume: number;
  shake: number;
  largeText: boolean;
  fx: number;
  meaning: boolean;
  music: boolean;
  sound: boolean;
  reduceMotion: boolean;
}
export interface Config {
  book: BookId;
  mode: ModeId;
  words: Word[];
  vocabTitle: string;
  vocabId: string;
  progressive: boolean;
  seed: string;
}
export interface Route {
  id?: string;
  name?: string;
  icon?: string;
  tag?: string;
  desc?: string;
  type: string;
  heal?: number;
  hurt?: number;
  shield?: number;
  relic?: boolean;
}
export interface RouteInfo {
  offers: readonly import("./content.ts").RouteDefinition[];
  boss: boolean;
  cleared: number;
  chapter: number;
  loop: number;
}
export interface Report {
  chapter?: number;
  stage?: number;
  loop?: number;
  correct?: number;
  errors?: number;
  dashes?: number;
  reflections?: number;
  ultimates?: number;
  perfectDodges?: number;
  grazes?: number;
  wallHits?: number;
  overloads?: number;
  version: string;
  win: boolean;
  kills: number;
  casts: number;
  maxCombo: number;
  accuracy: number;
  wpm: number;
  elapsed: number;
  relics: Record<string, number>;
  words: Record<string, { errors: number; meaning?: string }>;
  seed: string;
  book: BookId;
  mode: ModeId;
  vocab: string;
}
export interface GameEvents {
  state?(state: GameState): void;
  hud?(): void;
  toast?(message: string): void;
  banner?(value: { title: string; sub: string }): void;
  upgrade?(choices: import("./rewards.ts").RewardChoice[]): void;
  route?(info: RouteInfo): void;
  pause?(): void;
  resume?(): void;
  relics?(): void;
  result?(report: Report): void;
  mistake?(): void;
}
