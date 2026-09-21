import { baseValues } from "../content/combat-values.ts";
import { manifest } from "../content/manifest.ts";
import { Registry } from "../content-sdk/Registry.ts";
import { bossBehaviors } from "../content/boss-behaviors.ts";
import { enemyActions } from "../content/shared/enemy-actions.ts";
import {
  BOOKS,
  MODES,
  TYPES,
  ELITES,
  RELICS,
  chapterRegistry,
  ROUTES,
} from "../content/catalog.ts";
import { bookBehaviors } from "../content/book-behaviors.ts";
import type { SimulationContent } from "../contracts/SimulationContent.ts";
export const builtinContent: SimulationContent = Object.freeze({
  values: baseValues,
  audio: manifest.audio,
  appearances: manifest.appearances,
  bosses: new Registry("bosses", manifest.bosses).record(),
  bossBehaviors,
  enemyActions,
  books: BOOKS,
  modes: MODES,
  enemies: TYPES,
  elites: ELITES,
  relics: RELICS,
  chapters: chapterRegistry.list(),
  routes: ROUTES,
  bookBehaviors,
});
