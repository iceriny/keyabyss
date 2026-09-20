import type { SimulationContent } from "../contracts/SimulationContent.ts";

/** Resolve summon/death dependencies before rendering or entering a room. */
export function roomResources(content: SimulationContent, roomId: string) {
  const chapter = content.chapters.find((c) =>
    c.rooms.some((r) => r.id === roomId),
  );
  const room = chapter?.rooms.find((r) => r.id === roomId);
  if (!chapter || !room) throw new Error(`Unknown resource room ${roomId}`);
  const enemies = new Set<string>(),
    appearances = new Set(
      Object.values(content.books).map((b) => b.appearance),
    );
  function visit(id: string) {
    if (enemies.has(id)) return;
    const definition = content.enemies[id];
    if (!definition) throw new Error(`Missing summon dependency ${id}`);
    enemies.add(id);
    appearances.add(definition.appearance);
    for (const child of [
      ...(definition.behavior.dependencies ?? []),
      ...(definition.behavior.deathSpawns ?? []).map((s) => s.enemy),
    ])
      visit(child);
  }
  for (const id of [
    ...room.enemies,
    ...(room.easyEnemies?.pool ?? []),
    ...(room.opening ?? []),
  ])
    visit(id);
  if (room.boss) {
    const boss = chapter.bossId && content.bosses[chapter.bossId];
    if (!boss) throw new Error(`Missing room boss ${roomId}`);
    appearances.add(boss.appearance);
    for (const id of [
      boss.reinforcement,
      ...boss.shieldUnits,
      ...boss.phases.flatMap((p) => p.summons.map((s) => s.enemy)),
    ])
      visit(id);
  }
  for (const appearance of content.appearances)
    if (["node", "spirit"].includes(appearance.kind))
      appearances.add(appearance.id);
  for (const id of appearances)
    if (!content.appearances.some((a) => a.id === id))
      throw new Error(`Missing appearance ${id}`);
  return Object.freeze({
    enemies: Object.freeze([...enemies]),
    appearances: Object.freeze([...appearances]),
  });
}
export function prepareResourcePlan(content: SimulationContent) {
  return Object.freeze(
    content.chapters.flatMap((chapter) =>
      chapter.rooms.map((room) => roomResources(content, room.id)),
    ),
  );
}
