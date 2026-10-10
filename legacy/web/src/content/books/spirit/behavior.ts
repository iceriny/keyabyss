import type { BookBehavior } from "../../../content-sdk/BookBehavior.ts";
const dist = (a: { x: number; y: number }, b: { x: number; y: number }) =>
  Math.hypot(a.x - b.x, a.y - b.y);
const behavior: BookBehavior = {
  counterHit(ctx, t, damage) {
    t.mark = Math.max(t.mark, 8);
    ctx.focusId = t.id;
    ctx.spiritTime = Math.min(18, ctx.spiritTime + 2);
    ctx.strike(t, damage, {
      kind: "paper",
      direct: false,
      depth: 1,
      from: ctx.player,
    });
  },
  cold: 0,
  shatter: false,
  nativeChain: false,
  summons: true,
  duration: (ctx) => 8,
  cast(ctx, t, dmg, empowered, critical) {
    ctx.focusId = t.id;
    t.mark = 8;
    ctx.launchShot(ctx.player, t, "paper", dmg * ctx.bookData.castMultiplier.normal, {
      direct: true,
      refreshWord: true,
      empowered,
      critical,
    });
    if (empowered) {
      ctx.schedule(0.09, () => ctx.crossSlash(t, dmg * 0.6));
      if (ctx.stats.summonLegion) ctx.spirits.forEach((s) => (s.cooldown = 0));
    }
  },
  ultimate(ctx) {
    ctx.spiritTime = 18;
    ctx.awakenedSpirits = Math.min(ctx.combatValue("summon.capacity"), ctx.awakenedSpirits + 4);
    ctx.spirits.forEach((s) => (s.cooldown = 0));
    ctx.explode(
      ctx.player.x,
      ctx.player.y,
      280,
      65 * ctx.damageMultiplier(),
      null,
      1,
      "#d9b7ff",
    );
    ctx.fx.push({
      type: "slash",
      x: ctx.player.x,
      y: ctx.player.y,
      r: 245,
      angle: 0,
      color: "#dec6ff",
      life: 0.6,
      max: 0.6,
    });
  },
  dash(ctx, from) {
    ctx.decoy = { x: ctx.player.x, y: ctx.player.y, life: 1 };
  },
};
export default behavior;
