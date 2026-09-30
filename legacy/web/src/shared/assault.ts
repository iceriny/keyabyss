import type { Arena } from "../combat/model.ts";

/** Clockwise from north; shared by encounter rules and the player compass. */
export const assaultDirections = ["北", "东北", "东", "东南", "南", "西南", "西", "西北"] as const;
export const AMBUSH_CHANCE = 0.08;
export const assaultAngle = (direction: number) => direction * Math.PI / 4 - Math.PI / 2;

export function assaultEntry(arena: Readonly<Arena>, direction: number, spread: number) {
  const angle = assaultAngle(direction) + (spread - 0.5) * (110 * Math.PI / 180);
  const dx = Math.cos(angle), dy = Math.sin(angle);
  const cx = (arena.l + arena.r) / 2, cy = (arena.t + arena.b) / 2;
  const distance = Math.min(
    ((arena.r - arena.l) / 2 - 25) / Math.max(1e-8, Math.abs(dx)),
    ((arena.b - arena.t) / 2 - 25) / Math.max(1e-8, Math.abs(dy)),
  );
  return { x: cx + dx * distance, y: cy + dy * distance };
}
