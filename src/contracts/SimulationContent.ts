import type { BossDefinition } from "./content.ts";
import type { EnemyAction } from "../content-sdk/EnemyBehavior.ts";
import type {
  Book,
  Mode,
  Relic,
  EnemyDefinition,
  ChapterDefinition,
  RouteDefinition,
} from "./content.ts";
import type { BookBehavior } from "../content-sdk/BookBehavior.ts";
export interface SimulationContent {
  readonly values: import("./values.ts").ValueDefinitions;
  readonly elites: Readonly<
    Record<string, import("./content.ts").EliteDefinition>
  >;
  readonly audio: readonly import("./content.ts").AudioDefinition[];
  readonly appearances: readonly import("./content.ts").AppearanceDefinition[];
  readonly bosses: Readonly<Record<string, BossDefinition>>;
  readonly bossBehaviors: Readonly<Record<string, EnemyAction>>;
  readonly enemyActions: Readonly<Record<string, EnemyAction>>;
  readonly books: Readonly<Record<string, Book>>;
  readonly modes: Readonly<Record<string, Mode>>;
  readonly enemies: Readonly<Record<string, EnemyDefinition>>;
  readonly relics: readonly Relic[];
  readonly chapters: readonly ChapterDefinition[];
  readonly routes: readonly RouteDefinition[];
  readonly bookBehaviors: Readonly<Record<string, BookBehavior>>;
}
