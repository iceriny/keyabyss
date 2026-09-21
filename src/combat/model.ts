import type { Word } from "../contracts/game.ts";

export interface Point {
  x: number;
  y: number;
}
export interface Arena {
  l: number;
  r: number;
  t: number;
  b: number;
}
export interface Box extends Point {
  w: number;
  h: number;
}
export interface Dash extends Point {
  tx: number;
  ty: number;
  time: number;
  duration: number;
  trail: number;
}
export interface Player extends Point {
  r: number;
  hp: number;
  maxHp: number;
  shield: number;
  invuln: number;
  dash: number;
  maxDash: number;
  vx: number;
  vy: number;
  recoil: number;
  lean: number;
  dashState: Dash | null;
  parryTime: number;
  parryCooldown: number;
  parrySuccess: boolean;
}
export const createPlayer = (): Player => ({
  x: 640,
  y: 490,
  r: 7,
  hp: 115,
  maxHp: 115,
  shield: 0,
  invuln: 0,
  dash: 2,
  maxDash: 2,
  vx: 0,
  vy: 0,
  recoil: 0,
  lean: 0,
  dashState: null,
  parryTime: 0,
  parryCooldown: 0,
  parrySuccess: false,
});
interface TargetBase extends Point, Word {
  id: number;
  type: string;
  r: number;
  hp: number;
  maxHp: number;
  boss: boolean;
  age: number;
  phase: number;
  dead: boolean;
  grace: number;
  pendingHits: number;
  wordPending: boolean;
  phaseLock: number;
}
export interface Enemy extends TargetBase {
  /** Acquired by player targeting in the clear arena; retained until death. */
  combatLocked?: boolean;
  approachDirection?: number;
  ambush?: boolean;
  burn?: {
    life: number;
    stacks: number;
    tick: number;
    damage: number;
    spreadDepth: number;
  };
  bossId?: string;
  countsForClear?: boolean;
  kind?: never;
  px: number;
  py: number;
  speed: number;
  mass: number;
  vx: number;
  vy: number;
  ix: number;
  iy: number;
  angle: number;
  tilt: number;
  squash: number;
  shoot: number;
  chill: number;
  freeze: number;
  flash: number;
  small: boolean;
  elite: string | null;
  stun: number;
  impactTime: number;
  /** Counter pressure is displacement only; suppress secondary wall/body damage. */
  counterPushTime?: number;
  collisionCD: number;
  poise: number;
  conduct: number;
  dot: number;
  dotStacks: number;
  dotTick: number;
  mark: number;
  windup: number;
  windMax: number;
  charge: number;
  mirror: number;
  mirrortime: number;
  spawnCount: number;
  phaseBefore: number;
  towerSpawned: boolean;
  attackIndex: number;
  aimX: number;
  aimY: number;
  cx: number;
  cy: number;
}
export const enemyDefaults = () => ({
  boss: false,
  px: 0,
  py: 0,
  speed: 0,
  angle: 0,
  small: false,
  elite: null,
  windup: 0,
  windMax: 0,
  charge: 0,
  mirror: 1,
  mirrortime: 5,
  spawnCount: 0,
  phaseBefore: 1,
  towerSpawned: false,
  attackIndex: 0,
  aimX: 0,
  aimY: 0,
  cx: 0,
  cy: 0,
  pendingHits: 0,
  wordPending: false,
  phaseLock: 0,
  dead: false,
});
export interface RuneNode extends TargetBase {
  kind: "rune" | "ink";
  life: number;
  source: number | null;
}
export type CombatTarget = Enemy | RuneNode;
export interface Label extends Box {
  meaningText?: string;
  meaningLines?: string[];
  target: Readonly<CombatTarget>;
  font: number;
}
export interface BulletOptions {
  reflected?: boolean;
  heavy?: boolean;
  curve?: number;
  accel?: number;
  source?: number;
  speed?: number;
}
export interface Bullet extends Point, BulletOptions {
  px: number;
  py: number;
  vx: number;
  vy: number;
  r: number;
  life: number;
  age: number;
  dead: boolean;
  color: string;
  grazed: boolean;
}
export interface Laser {
  vertical: boolean;
  pos: number;
  width: number;
  warning: number;
  warningMax: number;
  active: number;
  age: number;
  dead: boolean;
  source?: number;
}
export interface Blast extends Point {
  r: number;
  warning: number;
  max: number;
  life: number;
  dead: boolean;
  fired?: boolean;
  ring: boolean;
  source: number | null;
}
export interface SpellOptions {
  kind?: string;
  direct?: boolean;
  empowered?: boolean;
  critical?: boolean;
  depth?: number;
  from?: Point;
  pierce?: number;
  refreshWord?: boolean;
}
export interface Shot extends Point, SpellOptions {
  px: number;
  py: number;
  vx: number;
  vy: number;
  speed: number;
  kind: string;
  targetId: number;
  homing: boolean;
  age: number;
  life: number;
  r: number;
  dmg: number;
  pierce: number;
  hits: Set<number>;
  trail: Point[];
  dead: boolean;
  seed: number;
  reserved: boolean;
  wordTarget?: Enemy | null;
}
export interface Field extends Point {
  kind: string;
  r: number;
  life: number;
  max: number;
  age: number;
  ultimate: boolean;
  seed: number;
}
export interface Particle extends Point {
  px: number;
  py: number;
  vx: number;
  vy: number;
  life: number;
  max: number;
  color: string;
  r: number;
  angle: number;
  spin: number;
  kind: string;
}
export const createParticle = (): Particle => ({
  x: 0,
  y: 0,
  px: 0,
  py: 0,
  vx: 0,
  vy: 0,
  life: 0,
  max: 1,
  color: "#ffffff",
  r: 1,
  angle: 0,
  spin: 0,
  kind: "spark",
});
export interface Debris extends Point {
  z: number;
  vz: number;
  vx: number;
  vy: number;
  r: number;
  angle: number;
  spin: number;
  life: number;
  max: number;
  color: string;
  bounces: number;
  ice: boolean;
}
export interface Decal extends Point {
  r: number;
  color: string;
  life: number;
}
export interface Trail extends Point {
  life: number;
  max: number;
  angle: number;
}
export interface Spirit extends Point {
  i: number;
  vx: number;
  vy: number;
  mode: "orbit" | "dive" | "return";
  cooldown: number;
  angle: number;
  trail: Point[];
  block: number;
  targetId?: number;
  life: number;
}
interface EffectBase extends Point {
  life: number;
  max: number;
  color: string;
}
export interface RingEffect extends EffectBase {
  type: "ring";
  r: number;
}
export interface ArcEffect extends EffectBase {
  type: "arc" | "beam" | "lightning";
  tx: number;
  ty: number;
  width: number;
  seed: number;
}
export interface BurstEffect extends EffectBase {
  type: "burst";
  r: number;
  kind: string;
  seed: number;
}
export interface SlashEffect extends EffectBase {
  type: "slash";
  r: number;
  angle: number;
}
export interface TextEffect extends EffectBase {
  type: "text";
  text: string;
  size: number;
}
export type VisualEffect =
  RingEffect | ArcEffect | BurstEffect | SlashEffect | TextEffect;
export const isArcEffect = (effect: VisualEffect): effect is ArcEffect =>
  ["arc", "beam", "lightning"].includes(effect.type);

export type { EnemyDefinition } from "../contracts/content.ts";
export interface EliteDefinition {
  name: string;
  color: string;
  tip: string;
}
export interface BattleRenderer {
  renderMenu(frame: import('../contracts/menu-scene.ts').MenuSceneFrame, time: number): void;
  prepare(): Promise<void>;
  render(): void;
  clear(): void;
  resize(): void;
  dispose(): void;
  diagnostics(): Record<string, unknown>;
}
