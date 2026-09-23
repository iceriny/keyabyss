import type { RoomDefinition } from "../../contracts/content.ts";
import type { CombatRuntime } from "../Runtime.ts";
import { assaultEntry } from "../../shared/assault.ts";

type Context = Pick<CombatRuntime, "allowedEnemies" | "arena" | "assaultDirection" | "content" | "enemies" | "pressure" | "spawnEnemy" | "wave">;

const front = new Set(["guard", "ram", "reaper", "sentinel"]);
const support = new Set(["priest", "binder", "brood", "mortar", "scribe", "mirror"]);

/** Spawn one complete, legal group. -1 means this batch must wait for open slots. */
export function spawnRoomFormation(context: Context, room: RoomDefinition, available: number, batchIndex: number): number {
  if (available < 2 || !room.formations?.length) return 0;
  const pool = new Set(context.allowedEnemies());
  const variants = room.formations.filter(group => group.length >= 2 && group.every(type => pool.has(type)));
  if (!variants.length) return 0;
  const group = variants[(context.wave - 1 + batchIndex) % variants.length];
  const living = context.enemies.filter(enemy => !enemy.dead);
  if (group.length > available) return 0;
  if (living.length + group.length > context.pressure.cap) return -1;
  const planned = new Map<string, number>();
  for (const type of group) {
    const next = (planned.get(type) ?? 0) + 1;
    planned.set(type, next);
    const limit = context.content.enemies[type]?.behavior.spawnLimit ?? Infinity;
    if (living.filter(enemy => enemy.type === type).length + next > limit) return -1;
  }
  let spawned = 0;
  group.forEach((type, index) => {
    // A narrow shared sector keeps the group legible while leaving an open approach.
    const entry = assaultEntry(context.arena, context.assaultDirection, 0.36 + index * (0.28 / Math.max(1, group.length - 1)));
    const centerX = (context.arena.l + context.arena.r) / 2;
    const centerY = (context.arena.t + context.arena.b) / 2;
    const dx = centerX - entry.x, dy = centerY - entry.y;
    const length = Math.hypot(dx, dy) || 1;
    const depth = front.has(type) ? 74 : support.has(type) ? 16 : 44;
    const enemy = context.spawnEnemy(type, entry.x + dx / length * depth, entry.y + dy / length * depth);
    if (enemy) {
      enemy.approachDirection = context.assaultDirection;
      spawned++;
    }
  });
  return spawned;
}
