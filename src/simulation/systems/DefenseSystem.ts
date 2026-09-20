import { DEFENSE } from "../../shared/defense.ts";
import type { Enemy, Bullet } from "../../combat/model.ts";
import type { BookAbilityContext } from "../../content-sdk/BookBehavior.ts";
import type { CombatRuntime } from "../Runtime.ts";
type Context = Pick<
  CombatRuntime,
  | keyof BookAbilityContext
  | "state"
  | "roomEnded"
  | "bookBehavior"
  | "bookData"
  | "burst"
  | "floating"
  | "sound"
  | "emit"
  | "addResonance"
  | "counterHit"
  | "parryFeedback"
  | "enemies"
  | "hitStop"
  | "counterSlowTime"
  | "shake"
>;

function counterPush(ctx: Context, e: Enemy, force: number, direct: boolean) {
  if (e.dead) return;
  const dx = e.x - ctx.player.x,
    dy = e.y - ctx.player.y;
  const distance = Math.hypot(dx, dy);
  const nx = distance > 0.01 ? dx / distance : 0,
    ny = distance > 0.01 ? dy / distance : -1;
  const velocity =
    (force * (e.boss ? 0.5 : 1)) / Math.max(0.85, Math.sqrt(e.mass || 1));
  const momentum = Math.max(velocity, e.ix * nx + e.iy * ny);
  e.ix = nx * momentum;
  e.iy = ny * momentum;
  e.vx = 0;
  e.vy = 0;
  e.charge = 0;
  e.windup = 0;
  e.counterPushTime = DEFENSE.pushDuration;
  e.impactTime = 0;
  e.stun = Math.max(e.stun, e.boss ? 0.4 : direct ? 1.2 : 0.7);
  e.shoot = Math.max(e.shoot, direct ? 2.4 : 1.4);
}

export function parry(this: Context) {
  const p = this.player;
  if (
    this.state !== "playing" ||
    this.roomEnded ||
    p.dashState ||
    p.parryCooldown > 0
  )
    return;
  p.parryTime = DEFENSE.window;
  p.parryCooldown = DEFENSE.cooldown * (this.stats.parryHaste ? 0.7 : 1);
  p.parrySuccess = false;
  this.sound.parryActivate(p);
  this.burst(p.x, p.y, DEFENSE.radius, "#b8e8df", "impact");
  this.emit("hud");
}
export function parryFeedback(this: Context) {
  if (this.player.parrySuccess) return;
  this.player.parrySuccess = true;
  this.addResonance(3);
  this.sound.reflect(this.player);
  this.burst(this.player.x, this.player.y, 115, "#d6ffe9", "parry");
  this.counterSlowTime = DEFENSE.slowDuration;
  for (const e of this.enemies) {
    const distance = Math.hypot(e.x - this.player.x, e.y - this.player.y);
    if (!e.dead && distance <= DEFENSE.pulseRadius + e.r)
      counterPush(
        this,
        e,
        DEFENSE.pulseKnockback *
          (1 - 0.25 * Math.min(1, distance / DEFENSE.pulseRadius)),
        false,
      );
  }
  this.shake = Math.max(this.shake, 3.5);
  this.floating(this.player.x, this.player.y - 48, "弹反", "#eaffcf", 19);
}
export function counterHit(this: Context, e: Enemy, damage = DEFENSE.damage) {
  if (this.stats.parryAffinity && this.bookBehavior.counterHit)
    this.bookBehavior.counterHit(this, e, damage);
  else this.damage(e, damage, 1, false, this.player);
}
export function parryContact(this: Context, e: Enemy): boolean {
  if (this.player.parryTime <= 0) return false;
  e.charge = 0;
  e.windup = 0;
  e.vx = 0;
  e.vy = 0;
  e.stun = Math.max(e.stun, e.boss ? 0.25 : 0.85);
  e.shoot = Math.max(e.shoot, 1.2);
  // Separate overlapping bodies before applying the impulse, including coincident centers.
  let dx = e.x - this.player.x,
    dy = e.y - this.player.y;
  if (Math.hypot(dx, dy) < 0.01) {
    dx = 0;
    dy = -1;
  }
  const n = Math.hypot(dx, dy),
    separation = e.r + this.player.r + 12;
  e.x = this.player.x + (dx / n) * separation;
  e.y = this.player.y + (dy / n) * separation;
  this.counterHit(e, DEFENSE.damage);
  this.parryFeedback();
  counterPush(this, e, DEFENSE.knockback, true);
  return true;
}
export function reflectBullet(this: Context, b: Bullet) {
  const source = this.enemies.find((e) => e.id === b.source && !e.dead);
  const dx = source ? source.x - b.x : -b.vx,
    dy = source ? source.y - b.y : -b.vy;
  const n = Math.hypot(dx, dy) || 1,
    speed = Math.max(360, Math.hypot(b.vx, b.vy) * 1.6);
  b.vx = (dx / n) * speed;
  b.vy = (dy / n) * speed;
  b.reflected = true;
  b.curve = 0;
  b.accel = 0;
  b.life = 3;
  b.color = this.stats.parryAffinity ? this.bookData.color : "#d8ffc6";
  this.parryFeedback();
}
