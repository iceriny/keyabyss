import type { EffectRequest, EffectSource } from "../../contracts/effects.ts";
import type { CombatRuntime } from "../Runtime.ts";
type Context = Pick<
  CombatRuntime,
  | "canEnemyAct"
  | "state"
  | "destroyed"
  | "domainEvents"
  | "roomVisit"
  | "enemies"
  | "damage"
  | "applyCold"
  | "launchShot"
  | "heal"
  | "spawnEnemy"
  | "content"
>;
export function effectSource(this: Context, entity?: number): EffectSource {
  return Object.freeze({
    session: this.domainEvents.session,
    room: this.roomVisit,
    entity,
  });
}
export function applyEffect(this: Context, request: EffectRequest): boolean {
  if (this.destroyed || this.state !== "playing") return false;
  const source = request.source;
  if (
    source.session !== this.domainEvents.session ||
    source.room !== this.roomVisit
  )
    return false;
  if (
    source.entity !== undefined &&
    !this.enemies.some((e) => e.id === source.entity && this.canEnemyAct(e))
  )
    return false;
  if (
    "target" in request &&
    (request.target.dead || !this.enemies.includes(request.target))
  )
    return false;
  if (
    "amount" in request &&
    (!Number.isFinite(request.amount) || request.amount <= 0)
  )
    return false;
  if (
    request.kind === "projectile" &&
    (!Number.isFinite(request.damage) || request.damage <= 0)
  )
    return false;
  if (request.kind === "spawn" && !this.content.enemies[request.enemy])
    return false;
  switch (request.kind) {
    case "damage":
      this.damage(
        request.target,
        request.amount,
        request.depth,
        request.direct,
        request.from,
      );
      break;
    case "cold":
      this.applyCold(request.target, request.amount);
      break;
    case "projectile":
      this.launchShot(
        request.from,
        request.target,
        request.projectile,
        request.damage,
        request.options,
      );
      break;
    case "heal":
      this.heal(request.amount);
      break;
    case "spawn":
      this.spawnEnemy(request.enemy, request.x, request.y);
      break;
  }
  return true;
}
