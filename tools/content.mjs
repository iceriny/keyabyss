import { manifest } from "../src/content/manifest.ts";
import { validateContent } from "../src/content-sdk/validate.ts";
import { validateValues } from "../src/content-sdk/validate-values.ts";
import { baseValues } from "../src/content/combat-values.ts";
import fs from "node:fs";
import { enemyActions } from "../src/content/shared/enemy-actions.ts";
validateContent(manifest);
validateValues(baseValues, manifest.relics, manifest.books);
for (const enemy of manifest.enemies)
  if (!enemyActions[enemy.behavior.attack])
    throw new Error(
      `enemy ${enemy.id}: unknown attack ${enemy.behavior.attack}`,
    );
const behaviorIds = [...new Set(manifest.books.map((book) => book.behavior))];
for (const id of behaviorIds) {
  const { default: behavior } = await import(
    `../src/content/books/${id}/behavior.ts`
  );
  for (const method of ["cast", "ultimate", "duration", "dash"])
    if (typeof behavior[method] !== "function")
      throw new Error(`book behavior ${id}: missing ${method}`);
}
const behaviors =
  "// Generated from content/manifest.ts by tools/content.mjs. Do not edit.\n" +
  behaviorIds
    .map((id, i) => `import behavior${i} from './books/${id}/behavior.ts';\n`)
    .join("") +
  "import type {BookBehavior} from '../content-sdk/BookBehavior.ts';\nexport const bookBehaviors:Readonly<Record<string,BookBehavior>>=Object.freeze({" +
  behaviorIds.map((id, i) => `${JSON.stringify(id)}:behavior${i}`).join(",") +
  "});\n";
const behaviorDestination = new URL(
  "../src/content/book-behaviors.ts",
  import.meta.url,
);
if (
  !fs.existsSync(behaviorDestination) ||
  fs.readFileSync(behaviorDestination, "utf8") !== behaviors
)
  fs.writeFileSync(behaviorDestination, behaviors);
const names = {
  assets: "Asset",
  audio: "Audio",
  appearances: "Appearance",
  bosses: "Boss",
  books: "Book",
  modes: "Mode",
  enemies: "Enemy",
  elites: "Elite",
  relics: "Relic",
  chapters: "Chapter",
  routes: "Route",
};
const generated =
  "// Generated from content/manifest.ts by tools/content.mjs. Do not edit.\n" +
  Object.entries(manifest)
    .map(
      ([key, items]) =>
        `export type ${names[key]}Id = ${items.map((i) => JSON.stringify(i.id)).join(" | ")};\n`,
    )
    .join("");
const destination = new URL("../src/contracts/content-ids.ts", import.meta.url);
if (
  !fs.existsSync(destination) ||
  fs.readFileSync(destination, "utf8") !== generated
)
  fs.writeFileSync(destination, generated);
console.log(
  "Content validated: " +
    Object.entries(manifest)
      .map(([key, items]) => `${items.length} ${key}`)
      .join(", "),
);

const bossIds = [...new Set(manifest.bosses.map((b) => b.behavior))];
for (const id of bossIds) {
  const module = await import(`../src/content/bosses/${id}/behavior.ts`);
  if (typeof module.default !== "function")
    throw Error(`Invalid boss behavior ${id}`);
}
fs.writeFileSync(
  new URL("../src/content/boss-behaviors.ts", import.meta.url),
  "// Generated from manifest.\n" +
    bossIds
      .map((id, i) => `import b${i} from './bosses/${id}/behavior.ts';\n`)
      .join("") +
    "import type {EnemyAction} from '../content-sdk/EnemyBehavior.ts';\nexport const bossBehaviors:Readonly<Record<string,EnemyAction>>={" +
    bossIds.map((id, i) => `${JSON.stringify(id)}:b${i}`).join(",") +
    "};\n",
);
