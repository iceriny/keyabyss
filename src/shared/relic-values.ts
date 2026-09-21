import type { Relic, Book } from "../contracts/content.ts";
import type { HudSnapshot } from "../contracts/session.ts";
import { ValueRules } from "./ValueRules.ts";
import {
  buildStats,
  relicMultiplier,
  wordModifierApplies,
} from "./relic-build.ts";
import { DEFENSE } from "./defense.ts";
export { relicMultiplier } from "./relic-build.ts";

export type RelicPreview = Pick<
  HudSnapshot,
  | "relics"
  | "player"
  | "book"
  | "combo"
  | "chapter"
  | "target"
  | "mode"
  | "ultimateTime"
>;
export interface PreviewDefaults {
  wordLength: number;
}

/** No relic/book ID dispatch: content owns templates and all numeric expressions. */
export function describeRelic(
  relic: Relic,
  definitions: readonly Relic[],
  rules: ValueRules,
  books: Readonly<Record<string, Book>>,
  defaults: PreviewDefaults,
  game?: RelicPreview,
  formulas = false,
  candidate = false,
): string {
  if (!relic.description) return relic.desc;
  const levels = { ...game?.relics };
  const before = levels[relic.id] || 0;
  if (candidate) levels[relic.id] = Math.min(relic.max, before + 1);
  const player = {
    hp: game?.player.hp ?? 0,
    maxHp: game?.player.maxHp ?? 0,
    maxDash: game?.player.maxDash ?? 0,
  };
  if (candidate && levels[relic.id] > before)
    for (const hook of relic.hooks ?? []) {
      if (hook.phase !== "acquire") continue;
      const e = hook.effect;
      if (e.kind === "maxHealth") {
        player.maxHp += e.amount;
        player.hp = Math.min(player.maxHp, player.hp + e.heal);
      }
      if (e.kind === "dashCharge") player.maxDash += e.amount;
      if (e.kind === "bloodPrice")
        player.hp = Math.max(1, player.hp - e.amount);
    }
  const stats = buildStats(definitions, levels);
  const book = game ? books[game.book] : undefined;
  const wordLength =
    game?.target && !game.target.dead
      ? game.target.word.length
      : (relic.description.wordLength ?? defaults.wordLength);
  const inputs: Record<string, number> = {
    ...Object.fromEntries(
      definitions.map((r) => [`rank.${r.id}`, levels[r.id] || 0]),
    ),
    ...Object.fromEntries(
      definitions.flatMap((r) =>
        (r.damageModifiers ?? []).map((rule, index) => [
          `modifier.${r.id}.${index}`,
          Number(
            !!levels[r.id] &&
              (rule.belowHealth === undefined ||
                player.hp < player.maxHp * rule.belowHealth),
          ),
        ]),
      ),
    ),
    wordLength,
    damageMultiplier: relicMultiplier(definitions, levels, player),
    shortWord: Number(
      wordModifierApplies(definitions, levels, "shortWordDamage", wordLength),
    ),
    longWord: Number(
      wordModifierApplies(definitions, levels, "longWordDamage", wordLength),
    ),
    perfect: 1,
    combo: game?.combo ?? 0,
    chapter: game?.chapter ?? 0,
    schoolMultiplier: book?.castMultiplier.normal ?? 1,
    nativeChain: book?.combat?.nativeChain ?? 0,
    empoweredChain: 0,
    nativeSummons: book?.combat?.nativeSummons ?? 0,
    ultimateActive: Number((game?.ultimateTime ?? 0) > 0),
    empowered: 0,
    marked: 0,
    boss: 0,
    dotStacks: 1,
    dashCD: game?.mode.dashCD ?? 0,
    parryCooldown: DEFENSE.cooldown,
    maxHp: player.maxHp,
    maxDash: player.maxDash,
  };
  if (game && relic.description.castPreview) {
    inputs.castBase = rules.evaluate("cast.base", stats, inputs);
    inputs.hitDamage = rules.evaluate("cast.hit", stats, inputs);
  }
  const format = (key: string) => {
    const formula = rules.format(key);
    if (!game) return `（${formula}）`;
    const value = String(
      Math.round(rules.evaluate(key, stats, inputs) * 100) / 100,
    );
    return formulas ? `${value}（${formula}）` : value;
  };
  const text = relic.description.template.replace(
    /\{([^{}]+)\}/g,
    (_, key: string) => (key === "description" ? relic.desc : format(key)),
  );
  return text;
}
