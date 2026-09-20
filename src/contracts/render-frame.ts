import type { Book, EnemyDefinition, ChapterDefinition } from "./content.ts";
import type { Config, Settings, GameState } from "./game.ts";
import type {
  Player,
  Enemy,
  RuneNode,
  CombatTarget,
  Point,
  Arena,
  Decal,
  Field,
  Trail,
  Debris,
  Spirit,
  Bullet,
  Laser,
  Blast,
  Shot,
  Particle,
  VisualEffect,
} from "../combat/model.ts";

/** Borrowed read-only views, valid for the synchronous render pass; no world copies per frame. */
export interface RenderFrame {
  readonly roomVisit: number;
  readonly cues: import("./events.ts").EventReader<
    import("./events.ts").PresentationCue
  >;
  readonly state: GameState;
  readonly book: string;
  readonly chapter: number;
  readonly bookData: Book;
  readonly config: Config;
  readonly options: Readonly<Settings>;
  readonly player: Readonly<Player>;
  readonly target: Readonly<CombatTarget> | null;
  readonly arena: Readonly<Arena>;
  readonly prefix: string;
  readonly ultimateTime: number;
  readonly visualTime: number;
  readonly kickX: number;
  readonly kickY: number;
  readonly shake: number;
  readonly hitFlash: number;
  readonly entityScale: number;
  readonly ox: number;
  readonly oy: number;
  readonly scale: number;
  readonly decoy: Readonly<Point & { life: number }> | null;
  readonly enemies: readonly Readonly<Enemy>[];
  readonly nodes: readonly Readonly<RuneNode>[];
  readonly decals: readonly Readonly<Decal>[];
  readonly fields: readonly Readonly<Field>[];
  readonly trails: readonly Readonly<Trail>[];
  readonly corpses: readonly Readonly<Debris>[];
  readonly spirits: readonly Readonly<Spirit>[];
  readonly bullets: readonly Readonly<Bullet>[];
  readonly lasers: readonly Readonly<Laser>[];
  readonly blasts: readonly Readonly<Blast>[];
  readonly shots: readonly Readonly<Shot>[];
  readonly particles: readonly Readonly<Particle>[];
  readonly fx: readonly Readonly<VisualEffect>[];
  readonly content: {
    readonly appearances: readonly import("./content.ts").AppearanceDefinition[];
    readonly bosses: Readonly<
      Record<string, import("./content.ts").BossDefinition>
    >;
    readonly books: Readonly<Record<string, Book>>;
    readonly enemies: Readonly<Record<string, EnemyDefinition>>;
    readonly chapters: readonly ChapterDefinition[];
  };
}
export interface PresentationPort {
  readonly frame: RenderFrame;
  setDensity(value: number): void;
  contextLost(): void;
  contextRestored(): void;
  contextRestoreFailed(): void;
}
