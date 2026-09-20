import type { Enemy } from "../../combat/model.ts";
import type { CombatRuntime } from "../Runtime.ts";
type Context = Pick<CombatRuntime, "player" | "pressure" | "enemyProfile">;
export function inAttackRange(this: Context, e: Enemy) {
  if (e.boss) return true;
  const profile = this.enemyProfile(e);
  // A charge must cover the distance despite acceleration and finish with room to make contact.
  const range = profile.chargeSpeed
    ? profile.chargeSpeed * Math.min(1.35, this.pressure.speed) * 0.42
    : (profile.attackRange ?? 310);
  return Math.hypot(e.x - this.player.x, e.y - this.player.y) <= range;
}
