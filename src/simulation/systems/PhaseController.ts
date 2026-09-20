import { inClearArena } from "../../shared/arena.ts";
import type { BossDefinition } from "../../contracts/content.ts";
import type { Arena, Enemy } from "../../combat/model.ts";
import type { CombatRuntime } from "../Runtime.ts";

export function limitBossDamage(
  definition: BossDefinition,
  enemy: Enemy,
  damage: number,
  enemies: readonly Enemy[],
  arena: Readonly<Arena>,
) {
  if (
    enemies.some(
      (e) =>
        !e.dead &&
        inClearArena(arena, e) &&
        definition.shieldUnits.includes(e.type),
    )
  )
    damage *= definition.shieldMultiplier;
  if (enemy.phaseLock > 0) damage *= 0.12;
  const phase =
    definition.phases.find((p) => enemy.hp / enemy.maxHp > p.above) ??
    definition.phases.at(-1)!;
  if (phase.floor > 0 && enemy.hp - damage < enemy.maxHp * phase.floor) {
    damage = enemy.hp - enemy.maxHp * phase.floor;
    enemy.phaseLock = 0.55;
  }
  return damage;
}
type Context = Pick<
  CombatRuntime,
  | "canEnemyAct"
  | "bossDefinition"
  | "spawnEnemy"
  | "emit"
  | "burst"
  | "bossName"
>;
export function updateBossPhase(this: Context, enemy: Enemy) {
  if (!this.canEnemyAct(enemy)) return;
  const definition = this.bossDefinition();
  const index = definition.phases.findIndex(
    (p) => enemy.hp / enemy.maxHp > p.above,
  );
  const phase = (index < 0 ? definition.phases.length - 1 : index) + 1;
  enemy.phase = phase;
  if (phase === enemy.phaseBefore) return;
  enemy.phaseBefore = phase;
  enemy.shoot = Math.min(enemy.shoot, 1);
  this.emit(
    "toast",
    `${this.bossName} · ${definition.phases[phase - 1].name}阶段`,
  );
  this.burst(enemy.x, enemy.y, 125, "#ffd39c", "shock");
  for (const summon of definition.phases[phase - 1].summons)
    this.spawnEnemy(summon.enemy, summon.x, summon.y, false, true);
  if (definition.phases[phase - 1].summons.length) enemy.towerSpawned = true;
}
