import type { Arena, Point } from "../combat/model.ts";

/** The visual veil and ability boundary share this world-space width. */
export function edgeWidth(arena: Readonly<Arena>) {
  return Math.min(arena.r - arena.l, arena.b - arena.t) * 0.1;
}
export function inClearArena(
  arena: Readonly<Arena>,
  point: Point,
  padding = 0,
) {
  const margin = edgeWidth(arena) + padding;
  return (
    point.x >= arena.l + margin &&
    point.x <= arena.r - margin &&
    point.y >= arena.t + margin &&
    point.y <= arena.b - margin
  );
}
export function clearArena(arena: Readonly<Arena>, padding = 0): Arena {
  const margin = edgeWidth(arena) + padding;
  return {
    l: arena.l + margin,
    r: arena.r - margin,
    t: arena.t + margin,
    b: arena.b - margin,
  };
}

/** A lock acquired inside the arena survives knockback into the veil. */
export function enemyInCombat(arena: Readonly<Arena>, enemy: Point & { r: number; combatLocked?: boolean }) {
  return !!enemy.combatLocked || inClearArena(arena, enemy, enemy.r);
}
