import type { EnemyAction } from "../../content-sdk/EnemyBehavior.ts";
const distance = (a: { x: number; y: number }, b: { x: number; y: number }) =>
  Math.hypot(a.x - b.x, a.y - b.y);
export const enemyActions: Readonly<Record<string, EnemyAction>> =
  Object.freeze({
    pursue(ctx, e) {
      if (ctx.chapter > 0 || ctx.mode.rank >= 3) ctx.fire(e, "single");
    },
    fan(ctx, e) {
      ctx.fire(e, "fan");
    },
    ring(ctx, e) {
      ctx.fire(e, "ring");
    },
    charge(ctx, e) {
      e.windup = Math.max(0.75, 1.12 * ctx.pressure.warning);
      e.aimX = ctx.player.x;
      e.aimY = ctx.player.y;
      e.windMax = e.windup;
    },
    laser(ctx, e) {
      ctx.laser(e);
    },
    bombard(ctx, e) {
      ctx.makeBlast(
        ctx.player.x,
        ctx.player.y,
        82 + ctx.chapter * 5,
        Math.max(1, 1.5 * ctx.pressure.warning),
        e.id,
      );
    },
    heal(ctx, e) {
      const allies = ctx.enemies
        .filter((n) => !n.dead && n !== e && distance(n, e) < 300)
        .sort((a, b) => a.hp / a.maxHp - b.hp / b.maxHp)
        .slice(0, 3);
      for (const ally of allies) {
        ally.hp = Math.min(ally.maxHp, ally.hp + 12 + ctx.chapter * 4);
        ctx.arc(e, ally, "#a3ecc2", 2, 0.55);
      }
      ctx.ring(e.x, e.y, 140, "#b3e6bf", 0.65);
    },
    brood(ctx, e) {
      if (e.spawnCount < 5) {
        const baby = ctx.spawnEnemy(
          e.spawnCount % 2 ? "wisp" : "leech",
          e.x + (ctx.rng() - 0.5) * 45,
          e.y + 30,
          true,
        );
        if (baby) e.spawnCount++;
      }
      ctx.fire(e, "fan");
    },
    vortex(ctx, e) {
      ctx.makeBlast(ctx.player.x, ctx.player.y, 92, 1.4, e.id, false);
      ctx.fire(e, "ring", { curve: 0.28 });
    },
    bind(ctx, e) {
      ctx.fire(e, "ring", { curve: -0.15 });
    },
    curve(ctx, e) {
      ctx.fire(e, "single", { curve: 0.32, accel: 1.12 });
    },
  });
