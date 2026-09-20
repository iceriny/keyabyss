import { manifest } from "./manifest.ts";
import { Registry } from "../content-sdk/Registry.ts";
import type {
  Book,
  Mode,
  Relic,
  EnemyDefinition,
  EliteDefinition,
  ChapterDefinition,
  RouteDefinition,
} from "../contracts/content.ts";
import type { BookId, ModeId } from "../contracts/content-ids.ts";

export const bookRegistry = new Registry<Book>("books", manifest.books);
export const modeRegistry = new Registry<Mode & { id: string }>(
  "modes",
  manifest.modes,
);
export const enemyRegistry = new Registry<EnemyDefinition & { id: string }>(
  "enemies",
  manifest.enemies,
);
export const eliteRegistry = new Registry<EliteDefinition & { id: string }>(
  "elites",
  manifest.elites,
);
export const relicRegistry = new Registry<Relic>("relics", manifest.relics);
export const chapterRegistry = new Registry<ChapterDefinition>(
  "chapters",
  manifest.chapters,
);
export const routeRegistry = new Registry<RouteDefinition>(
  "routes",
  manifest.routes,
);
// Transitional views retain existing call sites; definitions remain immutable.
export const BOOKS = bookRegistry.record() as Readonly<Record<BookId, Book>>;
export const MODES = modeRegistry.record() as Readonly<Record<ModeId, Mode>>;
export const TYPES = enemyRegistry.record();
export const ELITES = eliteRegistry.record();
export const RELICS = relicRegistry.list();
export const CHAPTERS = chapterRegistry.list().map((c) => c.name);
export const BOSS_NAMES = chapterRegistry.list().map((c) => c.bossName);
export const ROUTES = routeRegistry.list();
