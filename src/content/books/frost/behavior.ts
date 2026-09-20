import type { BookBehavior } from "../../../content-sdk/BookBehavior.ts";
const dist = (a: { x: number; y: number }, b: { x: number; y: number }) =>
  Math.hypot(a.x - b.x, a.y - b.y);
const behavior: BookBehavior = {
  counterHit(ctx, t, damage) {
    ctx.strike(t, damage, {
      kind: "ice",
      direct: false,
      depth: 1,
      from: ctx.player,
    });
  },
  cold: 100,
  shatter: true,
  nativeChain: false,
  summons: false,
  duration: (ctx) => 4,
  cast(ctx, t, dmg, empowered, critical) {
    ctx.launchShot(ctx.player, t, "ice", dmg * (empowered ? 1.9 : 1.12), {
      direct: true,
      refreshWord: true,
      empowered,
      critical,
      pierce: 1 + (empowered ? 2 : 0) + (ctx.stats.deathFrostVolley ? 2 : 0),
    });
  },
  ultimate(ctx) {
    const center =
      ctx.target && !ctx.target.dead
        ? ctx.target
        : ctx.nearest(ctx.player) || ctx.player;
    ctx.addField("frost", center.x, center.y, 250, 6, true);
    for (const e of [...ctx.enemies])
      if (!e.dead) {
        ctx.applyCold(e, 100);
        ctx.applyEffect({
          source: ctx.effectSource(),
          kind: "damage",
          target: e,
          amount: 68 * ctx.damageMultiplier(),
          depth: 1,
          direct: false,
        });
        ctx.impulse(e, center, 150);
      }
    if (ctx.stats.empoweredFreeze)
      ctx.player.shield = Math.min(60, ctx.player.shield + 30);
  },
  dash(ctx, from) {
    ctx.addField("frost", ctx.player.x, ctx.player.y, 65, 2);
  },
  tick(ctx) {
    if (ctx.ultTick <= 0) {
      const e = ctx.nearest({
        x: 200 + ctx.rng() * 850,
        y: 230 + ctx.rng() * 320,
      });
      if (e)
        ctx.launchShot(
          { x: e.x - 110, y: e.y - 240 },
          e,
          "ice",
          30 * ctx.damageMultiplier(),
          { direct: false, depth: 1, pierce: 1, empowered: true },
        );
      ctx.ultTick = ctx.stats.empoweredFreeze ? 0.13 : 0.25;
    }
  },
};
export default behavior;
