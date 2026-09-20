import type { CombatStat } from "./stats.ts";
import type { DamageModifier, RelicHook } from "./relic-rules.ts";
export interface Book {
  artwork?: string;
  visual: { rays: number; highlight: string; shadow: string; ultimate: string };
  appearance: string;
  audio: string;
  behavior: string;
  id: string;
  command: string;
  shortcut?: string;
  headline: string;
  subtitle: string;
  eyebrow: string;
  name: string;
  short: string;
  icon: string;
  color: string;
  desc: string;
  detail: string;
  ultimate: string;
  ultimateDesc: string;
  cadence: string;
  cycle: number;
}
export interface Mode {
  name: string;
  rank: number;
  hp: number;
  speed: number;
  spawn: number;
  cap: number;
  window: number;
  baseLen: number;
  health: number;
  damage: number;
  elite: number;
  dashCD: number;
  iframe: number;
  dashI: number;
}
export type RelicRarity = "common" | "rare" | "curse" | "awaken";

export interface Relic {
  command?: string;
  grants?: Partial<Record<CombatStat, number>>;
  damageModifiers?: readonly DamageModifier[];
  hooks?: readonly RelicHook[];
  max: number;
  minWordLength?: number;
  maxWordLength?: number;
  id: string;
  name: string;
  icon: string;
  desc: string;
  tag: string;
  rarity?: RelicRarity;
  requires?: string[];
  book?: string;
  affinity?: string[];
}

export interface EnemyDefinition {
  appearance: string;
  behavior: EnemyProfile;
  name: string;
  hp: number;
  speed: number;
  r: number;
  xp: number;
  color: string;
  mass: number;
  tip: string;
}
export interface EliteDefinition {
  health?: number;
  mass?: number;
  speed?: number;
  cooldown?: number;
  unfrozenDamage?: number;
  echoDelay?: number;
  deathBlast?: { radius: number; warning: number };
  name: string;
  color: string;
  tip: string;
}
export interface ChapterDefinition {
  ambience?: number;
  bossId?: string;
  id: string;
  name: string;
  bossName: string;
  rooms: readonly RoomDefinition[];
}
export interface RouteDefinition {
  id: string;
  name: string;
  icon: string;
  desc: string;
  word: string;
  type: string;
  heal?: number;
  hurt?: number;
  shield?: number;
  relic?: boolean;
}

export interface EnemyProfile {
  attackRange?: number;
  targetingPriority?: number;
  contactDamage?: number;
  chargeDrain?: number;
  dependencies?: readonly string[];
  longWord?: boolean;
  eliteEligible?: boolean;
  spawnLimit?: number;
  countsForClear?: boolean;
  deathSpawns?: readonly { enemy: string; x: number; y: number }[];
  attack: string;
  cooldown?: number;
  ranged?: boolean;
  stationary?: boolean;
  weave?: boolean;
  chargeSpeed?: number;
  mirror?: boolean;
  frontArmor?: boolean;
  hasteAura?: boolean;
  pullAura?: boolean;
  deathSplit?: boolean;
  deathVortex?: boolean;
}

export interface RoomDefinition {
  opening?: readonly string[];
  quota?: number;
  spawnDelay?: number;
  nodeInterval?: number;
  objective?: "clear" | "boss";
  exits?: readonly { route: string; to: string }[];
  id: string;
  boss: boolean;
  waves: number;
  enemies: readonly string[];
  easyEnemies?: { belowRank: number; pool: readonly string[] };
  routes: readonly (string | readonly string[])[];
}

export interface BossDefinition {
  id: string;
  name: string;
  behavior: string;
  appearance: string;
  health: readonly number[];
  growth: number;
  reinforcement: string;
  movementRadius: number;
  shieldUnits: readonly string[];
  shieldMultiplier: number;
  phases: readonly {
    name: string;
    above: number;
    floor: number;
    summons: readonly { enemy: string; x: number; y: number }[];
  }[];
}

export interface AppearanceDefinition {
  id: string;
  kind: "enemy" | "boss" | "player" | "node" | "spirit";
  shape: string;
}

export type AudioLayer =
  | {
      kind: "tone";
      frequency: number;
      duration: number;
      wave: "sine" | "triangle" | "sawtooth" | "square";
      volume: number;
      slide: number;
    }
  | { kind: "noise"; duration: number; frequency: number; volume: number };
export interface AudioDefinition {
  id: string;
  keyBase: number;
  keyWave: "sine" | "triangle";
  cast: readonly AudioLayer[];
  heavyCast?: readonly AudioLayer[];
}
