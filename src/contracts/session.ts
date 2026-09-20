import type { Book, Mode } from "./content.ts";
import type { Config, Settings, GameState, BookId } from "./game.ts";

export interface HudSnapshot {
  readonly state: GameState;
  readonly godMode: boolean;
  readonly book: BookId;
  readonly player: Readonly<{
    hp: number;
    maxHp: number;
    shield: number;
    dash: number;
    maxDash: number;
    parryTime: number;
    parryCooldown: number;
    invuln: number;
  }>;
  readonly bookData: Readonly<Book>;
  readonly mode: Readonly<Mode>;
  readonly target: Readonly<{
    word: string;
    meaning?: string;
    dead: boolean;
  }> | null;
  readonly boss: Readonly<{
    hp: number;
    maxHp: number;
    phase: number;
    dead: boolean;
  }> | null;
  readonly relics: Readonly<Record<string, number>>;
  readonly prefix: string;
  readonly chapterName: string;
  readonly bossName: string;
  readonly nextRoomIsBoss: boolean;
  readonly chapter: number;
  readonly roomNumber: number;
  readonly roomCount: number;
  readonly bossRoom: boolean;
  readonly wave: number;
  readonly waveCount: number;
  readonly spawned: number;
  readonly roomQuota: number;
  readonly elapsed: number;
  readonly kills: number;
  readonly combo: number;
  readonly bookCounter: number;
  readonly level: number;
  readonly xp: number;
  readonly nextXP: number;
  readonly precisionTime: number;
  readonly resonance: number;
  readonly ultimateTime: number;
  readonly rerolls: number;
  readonly stage: number;
  readonly loopCount: number;
}
export type GameCommand =
  | { type: "input"; key: string }
  | { type: "release"; key: string }
  | { type: "cycle"; direction: number }
  | {
      type:
        | "pause"
        | "resume"
        | "home"
        | "quit"
        | "continue"
        | "reroll"
        | "god-mode";
    }
  | { type: "upgrade"; id: string }
  | { type: "route"; id: string };
export interface SessionView extends HudSnapshot {
  getSnapshot(): HudSnapshot;
  subscribe(listener: () => void): () => void;
  dispatch(command: GameCommand): boolean;
  start(config: Config): void;
  prepare(stage?: (label: string) => void, book?: import('./game.ts').BookId): Promise<void>;
  applySettings(settings: Settings): void;
  setMenuScene(frame: import('./menu-scene.ts').MenuSceneFrame | null): void;
  unlockAudio(): void;
  playUISound(kind: import('./audio.ts').UISound): void;
  input(key: string): boolean;
  releaseKey(key: string): void;
  cycle(direction?: number): void;
  pause(): void;
  resume(): void;
  home(): void;
  end(win: boolean): void;
  continueLoop(): void;
  rerollUpgrade(): void;
  chooseUpgrade(id: string): void;
  chooseRoute(id: string): void;
}
