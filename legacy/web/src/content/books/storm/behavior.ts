import type { BookBehavior } from "../../../content-sdk/BookBehavior.ts";
const dist = (a: { x: number; y: number }, b: { x: number; y: number }) =>
  Math.hypot(a.x - b.x, a.y - b.y);
const behavior: BookBehavior = {
  counterHit(ctx, t, damage) {
    ctx.strike(t, damage, {
      kind: "storm",
      direct: false,
      depth: 1,
      from: ctx.player,
    });
  },
  cold: 0,
  shatter: false,
  nativeChain: true,
  summons: false,
  duration: (ctx) => (ctx.stats.ultimateChain ? 9 : 6),
  cast(ctx, t, dmg, empowered, critical) {
    ctx.arc(ctx.player, t, "#ffe7ac", empowered ? 8 : 5, 0.36);
    ctx.strike(t, dmg * ctx.bookData.castMultiplier[empowered ? "empowered" : "normal"], {
      direct: true,
      empowered,
      from: ctx.player,
      kind: "storm",
      critical,
    });
    ctx.chain(
      t,
      dmg * 0.78,
      ctx.combatValue("chain.count", { empoweredChain: empowered ? 2 : 0 }),
    );
  },
  ultimate(ctx) {
    for (const e of ctx.enemies.filter((e) => !e.dead).slice(0, 5)) {
      ctx.strikeDown(e, 48 * ctx.damageMultiplier());
    }
    ctx.addField(
      "storm",
      ctx.player.x,
      ctx.player.y,
      210,
      ctx.ultimateTime,
      true,
    );
  },
  dash(ctx, from) {
    const e = ctx.nearest(from, new Set(), 210);
    if (e) {
      ctx.arc(from, e, "#ffe2a8", 2.5, 0.3);
      ctx.damage(e, 18, 1, false);
    }
  },
  afterCast(ctx, t, dmg) {
    if (ctx.ultimateTime > 0) {
      const list = ctx.enemies
        .filter((e) => !e.dead)
        .sort((a, b) => dist(a, t) - dist(b, t))
        .slice(0, ctx.stats.ultimateChain ? 3 : 1);
      list.forEach((e, i) =>
        ctx.schedule(i * 0.1, () => {
          if (!e.dead) {
            ctx.strikeDown(e, dmg * 0.7);
            if (ctx.stats.ultimateChain)
              ctx.player.shield = Math.min(60, ctx.player.shield + 2);
          }
        }),
      );
    }
  },
};
export default behavior;
