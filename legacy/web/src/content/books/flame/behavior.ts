import type { BookBehavior } from "../../../content-sdk/BookBehavior.ts";
const behavior: BookBehavior = {
  counterHit(ctx, t, damage) {
    ctx.strike(t, damage, {
      kind: "fire",
      direct: false,
      depth: 1,
      from: ctx.player,
    });
  },
  cold: 0,
  shatter: false,
  nativeChain: false,
  summons: false,
  duration: (ctx) => (ctx.stats.inferno ? 7 : 5),
  cast(ctx, target, damage, empowered, critical) {
    ctx.launchShot(
      ctx.player,
      target,
      "fire",
      damage * ctx.bookData.castMultiplier[empowered ? "empowered" : "normal"],
      {
        direct: true,
        refreshWord: true,
        empowered,
        critical,
      },
    );
    if (empowered && ctx.stats.emberShield)
      ctx.player.shield = Math.min(
        60,
        ctx.player.shield + ctx.combatValue("coal.shield"),
      );
  },
  ultimate(ctx) {
    const center =
      ctx.target && !ctx.target.dead
        ? ctx.target
        : ctx.nearest(ctx.player) || ctx.player;
    ctx.igniteExplosion(
      center.x,
      center.y,
      240,
      65 * ctx.damageMultiplier(),
      null,
      0,
      3,
    );
    ctx.addField(
      "fire",
      center.x,
      center.y,
      240,
      ctx.stats.inferno ? 7 : 5,
      true,
    );
  },
  dash(ctx, from) {
    ctx.addField(
      "fire",
      from.x,
      from.y,
      ctx.combatValue("fireTrail.radius"),
      ctx.combatValue("fireTrail.duration"),
    );
  },
  tick(ctx) {
    if (ctx.ultTick > 0) return;
    const target = ctx.nearest({
      x: 200 + ctx.rng() * 850,
      y: 230 + ctx.rng() * 320,
    });
    if (target)
      ctx.launchShot(
        {
          x: Math.max(ctx.arena.l + 16, target.x - 100),
          y: Math.max(ctx.arena.t + 16, target.y - 260),
        },
        target,
        "fire",
        32 * ctx.damageMultiplier(),
        { empowered: true, direct: false, depth: 1 },
      );
    ctx.ultTick = ctx.stats.inferno ? 0.45 : 0.7;
  },
};
export default behavior;
