import { combatStats } from "../contracts/stats.ts";
import type { BossDefinition } from "../contracts/content.ts";
import type {
  Book,
  Mode,
  Relic,
  EnemyDefinition,
  EliteDefinition,
  ChapterDefinition,
  RouteDefinition,
} from "../contracts/content.ts";
import { Registry } from "./Registry.ts";
export interface ContentManifest {
  assets: readonly import("../contracts/assets.ts").AssetDefinition[];
  audio: readonly import("../contracts/content.ts").AudioDefinition[];
  appearances: readonly import("../contracts/content.ts").AppearanceDefinition[];
  bosses: readonly BossDefinition[];
  books: readonly Book[];
  modes: readonly (Mode & { id: string })[];
  enemies: readonly (EnemyDefinition & { id: string })[];
  elites: readonly (EliteDefinition & { id: string })[];
  relics: readonly Relic[];
  chapters: readonly ChapterDefinition[];
  routes: readonly RouteDefinition[];
}
export function validateContent(content: ContentManifest) {
  for (const [category, entries] of Object.entries(content))
    new Registry(category, entries);
  const books = new Set(content.books.map((b) => b.id)),
    relics = new Map(content.relics.map((r) => [r.id, r]));
  function positive(value: number, label: string, allowZero = false) {
    if (!Number.isFinite(value) || (allowZero ? value < 0 : value <= 0))
      throw new Error(
        `${label}: expected ${allowZero ? "non-negative" : "positive"} finite number`,
      );
  }
  function commands(values: readonly string[], scope: string) {
    for (const word of values)
      if (!/^[a-z]+$/.test(word))
        throw new Error(`${scope}: invalid command ${word}`);
    for (let i = 0; i < values.length; i++)
      for (let j = i + 1; j < values.length; j++)
        if (values[i].startsWith(values[j]) || values[j].startsWith(values[i]))
          throw new Error(
            `${scope}: conflicting commands ${values[i]} / ${values[j]}`,
          );
  }
  commands(
    [
      ...content.books.map((b) => b.command),
      "start",
      "vocab",
      "codex",
      "help",
      "settings",
    ],
    "home",
  );
  commands(
    content.routes.map((r) => r.word),
    "routes",
  );
  const shortcuts = new Set<string>();
  const images = new Set(
    content.assets.filter((a) => a.kind === "image").map((a) => a.id),
  );
  for (const b of content.books) {
    if (b.artwork && !images.has(b.artwork))
      throw new Error(`Missing book artwork ${b.artwork}`);
    if (!/^[a-z][a-z0-9-]*$/.test(b.behavior))
      throw new Error(`book ${b.id}: invalid behavior reference`);
    for (const key of [
      "name",
      "headline",
      "subtitle",
      "eyebrow",
      "icon",
      "color",
      "ultimate",
      "ultimateDesc",
      "desc",
      "detail",
    ] as const)
      if (!b[key].trim()) throw new Error(`book ${b.id}: missing ${key}`);
    positive(b.cycle, `book ${b.id} cycle`);
    if (!Number.isInteger(b.cycle))
      throw new Error(`book ${b.id}: fractional cycle`);
    if (b.shortcut) {
      if (shortcuts.has(b.shortcut))
        throw new Error(`duplicate book shortcut ${b.shortcut}`);
      shortcuts.add(b.shortcut);
    }
  }
  for (const e of content.enemies) {
    for (const key of ["hp", "r", "mass", "xp"] as const)
      positive(e[key], `enemy ${e.id} ${key}`);
    positive(e.speed, `enemy ${e.id} speed`, true);
    if (!e.behavior?.attack) throw new Error(`enemy ${e.id}: missing attack`);
    if (e.behavior.cooldown !== undefined)
      positive(e.behavior.cooldown, `enemy ${e.id} cooldown`);
    if (e.behavior.chargeSpeed !== undefined)
      positive(e.behavior.chargeSpeed, `enemy ${e.id} chargeSpeed`);
  }
  for (const elite of content.elites) {
    for (const key of [
      "health",
      "mass",
      "speed",
      "cooldown",
      "unfrozenDamage",
      "echoDelay",
    ] as const)
      if (elite[key] !== undefined)
        positive(elite[key]!, `elite ${elite.id} ${key}`);
    if (elite.deathBlast) {
      positive(elite.deathBlast.radius, `elite ${elite.id} blast radius`);
      positive(elite.deathBlast.warning, `elite ${elite.id} blast warning`);
    }
  }
  for (const m of content.modes)
    for (const [key, value] of Object.entries(m))
      if (typeof value === "number")
        positive(value, `mode ${m.id} ${key}`, ["rank", "elite"].includes(key));
  for (const r of content.relics) {
    if (
      r.rarity !== undefined &&
      !["common", "rare", "curse", "awaken"].includes(r.rarity)
    )
      throw new Error(`relic ${r.id}: invalid rarity ${r.rarity}`);
    for (const modifier of r.damageModifiers ?? []) {
      positive(modifier.factor, `relic ${r.id} factor`);
      if (!Number.isFinite(modifier.priority))
        throw new Error(`relic ${r.id}: invalid modifier priority`);
      if (
        modifier.belowHealth !== undefined &&
        (!(modifier.belowHealth > 0) || modifier.belowHealth > 1)
      )
        throw new Error(`relic ${r.id}: invalid health threshold`);
    }
    for (const hook of r.hooks ?? []) {
      if (
        !["acquire", "afterCast"].includes(hook.phase) ||
        !Number.isFinite(hook.priority)
      )
        throw new Error(`relic ${r.id}: invalid hook`);
      if (hook.every !== undefined) {
        positive(hook.every, `relic ${r.id} hook interval`);
        if (!Number.isInteger(hook.every))
          throw new Error(`relic ${r.id}: fractional hook interval`);
      }
      if (
        ![
          "heal",
          "maxHealth",
          "dashCharge",
          "bloodPrice",
          "shield",
          "pulse",
        ].includes(hook.effect.kind)
      )
        throw new Error(`relic ${r.id}: unknown effect`);
      for (const [key, value] of Object.entries(hook.effect))
        if (typeof value === "number")
          positive(value, `relic ${r.id} effect ${key}`, true);
    }
    positive(r.max, `relic ${r.id} max`);
    if (!Number.isInteger(r.max))
      throw new Error(`relic ${r.id}: fractional stacks`);
    for (const id of [...(r.affinity || []), ...(r.book ? [r.book] : [])])
      if (!books.has(id)) throw new Error(`relic ${r.id}: unknown book ${id}`);
    for (const id of r.requires || [])
      if (!relics.has(id))
        throw new Error(`relic ${r.id}: unknown prerequisite ${id}`);
  }
  const active = new Set<string>(),
    done = new Set<string>();
  function visit(id: string) {
    if (active.has(id)) throw new Error(`relic dependency cycle at ${id}`);
    if (done.has(id)) return;
    active.add(id);
    for (const parent of relics.get(id)?.requires || []) visit(parent);
    active.delete(id);
    done.add(id);
  }
  for (const id of relics.keys()) visit(id);
  const rooms = new Set<string>();
  const enemies = new Set(content.enemies.map((e) => e.id)),
    routes = new Set(content.routes.map((r) => r.id));
  for (const chapter of content.chapters) {
    if (!chapter.rooms.length)
      throw new Error(`chapter ${chapter.id}: no rooms`);
    for (const room of chapter.rooms) {
      if (rooms.has(room.id)) throw new Error(`duplicate room ${room.id}`);
      rooms.add(room.id);
      positive(room.waves, `room ${room.id} waves`);
      if (!Number.isInteger(room.waves))
        throw new Error(`room ${room.id}: fractional waves`);
      for (const pool of [
        room.enemies,
        ...(room.easyEnemies ? [room.easyEnemies.pool] : []),
      ]) {
        if (!pool?.length) throw new Error(`room ${room.id}: empty spawn pool`);
        for (const id of pool)
          if (!enemies.has(id))
            throw new Error(`room ${room.id}: unknown enemy ${id}`);
      }
      if (!room.routes?.length)
        throw new Error(`room ${room.id}: no route offers`);
      for (const choice of room.routes) {
        const ids = typeof choice === "string" ? [choice] : choice;
        if (!ids.length) throw new Error(`room ${room.id}: empty route choice`);
        for (const id of ids)
          if (!routes.has(id))
            throw new Error(`room ${room.id}: unknown route ${id}`);
      }
    }
  }
  const appearances = new Map(content.appearances.map((a) => [a.id, a]));
  const audio = new Set(content.audio.map((a) => a.id));
  for (const definition of [
    ...content.books,
    ...content.enemies,
    ...content.bosses,
  ])
    if (!appearances.has(definition.appearance))
      throw new Error(`Unknown appearance ${definition.appearance}`);
  for (const book of content.books) {
    if (!audio.has(book.audio)) throw new Error(`Unknown audio ${book.audio}`);
    positive(book.visual.rays, `book ${book.id} rays`);
  }
  for (const profile of content.audio) {
    positive(profile.keyBase, `audio ${profile.id} key base`);
    if (!profile.cast.length) throw new Error(`Empty audio ${profile.id}`);
    for (const layer of [...profile.cast, ...(profile.heavyCast ?? [])]) {
      positive(layer.duration, `audio ${profile.id} duration`);
      positive(layer.frequency, `audio ${profile.id} frequency`);
      positive(layer.volume, `audio ${profile.id} volume`, true);
    }
  }
  for (const appearance of content.appearances)
    if (
      !["enemy", "boss", "player", "node", "spirit"].includes(
        appearance.kind,
      ) ||
      !appearance.shape
    )
      throw new Error(`Invalid appearance ${appearance.id}`);
  for (const enemy of content.enemies) {
    for (const id of [
      ...(enemy.behavior.dependencies ?? []),
      ...(enemy.behavior.deathSpawns ?? []).map((s) => s.enemy),
    ])
      if (!enemies.has(id)) throw new Error(`Unknown summon dependency ${id}`);
    if (enemy.behavior.spawnLimit !== undefined) {
      positive(enemy.behavior.spawnLimit, `enemy ${enemy.id} spawn limit`);
      if (!Number.isInteger(enemy.behavior.spawnLimit))
        throw new Error("Fractional spawn limit");
    }
  }
  for (const relic of content.relics)
    for (const [stat, value] of Object.entries(relic.grants ?? {})) {
      if (!(combatStats as readonly string[]).includes(stat))
        throw new Error(`Unknown combat stat ${stat}`);
      positive(value, `relic ${relic.id} grant ${stat}`, true);
    }
  commands(
    [...content.relics.map((r) => r.command ?? r.id), "renewal"],
    "rewards",
  );
  const bosses = new Map(content.bosses.map((b) => [b.id, b]));
  for (const boss of content.bosses) {
    if (!/^[a-z][a-z0-9-]*$/.test(boss.behavior))
      throw new Error(`Invalid boss behavior ${boss.behavior}`);
    if (boss.health.length !== content.modes.length)
      throw new Error(`Boss health difficulty mismatch ${boss.id}`);
    for (const hp of boss.health) positive(hp, `boss ${boss.id} health`);
    positive(boss.growth, `boss ${boss.id} growth`);
    positive(boss.shieldMultiplier, `boss ${boss.id} shield`);
    if (!boss.phases.length || boss.phases.at(-1)!.above !== 0)
      throw new Error(`Boss ${boss.id} has no final phase`);
    let previous = 1;
    for (const phase of boss.phases) {
      if (
        !Number.isFinite(phase.above) ||
        phase.above < 0 ||
        phase.above >= previous ||
        phase.floor < 0 ||
        phase.floor > phase.above
      )
        throw new Error(`Invalid boss phase ${boss.id}`);
      previous = phase.above;
    }
    for (const id of [
      boss.reinforcement,
      ...boss.shieldUnits,
      ...boss.phases.flatMap((p) => p.summons.map((s) => s.enemy)),
    ])
      if (!enemies.has(id)) throw new Error(`Unknown boss dependency ${id}`);
  }
  const orderedRooms = content.chapters.flatMap((chapter) => chapter.rooms);
  const graph = new Map<string, string[]>();
  for (const chapter of content.chapters)
    for (const room of chapter.rooms) {
      if (room.boss && (!chapter.bossId || !bosses.has(chapter.bossId)))
        throw new Error(`Unknown boss for ${room.id}`);
      if (room.objective && room.objective !== (room.boss ? "boss" : "clear"))
        throw new Error(`Incompatible objective ${room.id}`);
      if (room.quota !== undefined) {
        positive(room.quota, `room ${room.id} quota`);
        if (!Number.isInteger(room.quota)) throw new Error("Fractional quota");
      }
      for (const id of room.opening ?? [])
        if (!enemies.has(id)) throw new Error(`Unknown opening enemy ${id}`);
      for (const delay of [room.spawnDelay, room.nodeInterval])
        if (delay !== undefined) positive(delay, `room ${room.id} interval`);
      const index = orderedRooms.indexOf(room),
        next = orderedRooms[index + 1];
      const exits =
        room.exits?.map((exit) => {
          if (!routes.has(exit.route) || !rooms.has(exit.to))
            throw new Error(`Unknown room exit ${exit.route} -> ${exit.to}`);
          return exit.to;
        }) ?? (next ? [next.id] : []);
      if (
        room.exits &&
        new Set(room.exits.map((e) => e.route)).size !== room.exits.length
      )
        throw new Error(`Duplicate exit route ${room.id}`);
      graph.set(room.id, exits);
    }
  const visiting = new Set<string>(),
    visited = new Set<string>();
  function walk(id: string) {
    if (visiting.has(id))
      throw new Error(
        `Campaign cycle ${id}; use explicit next-loop transition`,
      );
    if (visited.has(id)) return;
    visiting.add(id);
    for (const next of graph.get(id) ?? []) walk(next);
    visiting.delete(id);
    visited.add(id);
  }
  if (orderedRooms.length) walk(orderedRooms[0].id);
  if (visited.size !== orderedRooms.length)
    throw new Error("Unreachable campaign room");
}
