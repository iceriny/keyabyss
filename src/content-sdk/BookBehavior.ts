import type {
  Point,
  Enemy,
  CombatTarget,
  Player,
  Spirit,
  SpellOptions,
  VisualEffect,
} from "../combat/model.ts";

/** Only capabilities needed by book abilities; no browser, renderers, progression or registry writes. */
export interface BookAbilityContext {
  readonly arena: Readonly<import("../combat/model.ts").Arena>;
  applyBurn(enemy: Enemy, stacks?: number, spreadDepth?: number): void;
  igniteExplosion(
    x: number,
    y: number,
    radius: number,
    damage: number,
    exclude?: Enemy | null,
    depth?: number,
    stacks?: number,
  ): void;
  effectSource(entity?: number): import("../contracts/effects.ts").EffectSource;
  applyEffect(
    request: import("../contracts/effects.ts").EffectRequest,
  ): boolean;
  readonly stats: import("../contracts/stats.ts").CombatStats;
  readonly relics: Readonly<Record<string, number>>;
  readonly player: Player;
  readonly enemies: readonly Enemy[];
  readonly spirits: readonly Spirit[];
  readonly target: CombatTarget | null;
  readonly ultimateTime: number;
  focusId: number | null;
  spiritTime: number;
  awakenedSpirits: number;
  ultTick: number;
  decoy: (Point & { life: number }) | null;
  readonly fx: VisualEffect[];
  rng(): number;
  damageMultiplier(): number;
  launchShot(
    from: Point,
    target: Enemy,
    kind: string,
    dmg: number,
    opts?: SpellOptions,
  ): void;
  strike(target: Enemy, dmg: number, opts?: SpellOptions): void;
  arc(
    from: Point,
    to: Point,
    color: string,
    width?: number,
    life?: number,
  ): void;
  chain(target: Enemy, dmg: number, count: number): void;
  schedule(delay: number, fn: () => void, source?: number | null): void;
  crossSlash(target: Enemy | null, dmg: number): void;
  nearest(
    from: Point,
    exclude?: Set<number>,
    radius?: number,
  ): Enemy | undefined;
  strikeDown(target: Enemy, dmg: number): void;
  addField(
    kind: string,
    x: number,
    y: number,
    r: number,
    life: number,
    ultimate?: boolean,
  ): void;
  applyCold(target: Enemy, amount?: number | null): void;
  damage(
    target: Enemy,
    dmg: number,
    depth?: number,
    direct?: boolean,
    from?: Point | null,
  ): void;
  impulse(target: Enemy, from: Point, force: number): void;
  explode(
    x: number,
    y: number,
    r: number,
    dmg: number,
    exclude?: Enemy | null,
    depth?: number,
    color?: string,
    cold?: boolean,
  ): void;
}
export interface BookBehavior {
  counterHit?(context: BookAbilityContext, target: Enemy, damage: number): void;
  readonly cold: number;
  readonly shatter: boolean;
  readonly nativeChain: boolean;
  readonly summons: boolean;
  cast(
    context: BookAbilityContext,
    target: Enemy,
    damage: number,
    empowered: boolean,
    critical: boolean,
  ): void;
  ultimate(context: BookAbilityContext): void;
  duration(context: BookAbilityContext): number;
  dash(context: BookAbilityContext, from: Point): void;
  tick?(context: BookAbilityContext): void;
  afterCast?(context: BookAbilityContext, target: Enemy, damage: number): void;
}
