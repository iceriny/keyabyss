import { DEFENSE } from "../../shared/defense.ts";
import { WordReservations } from "../targeting/WordReservations.ts";

import type {
  Point,
  Enemy,
  BulletOptions,
  Shot,
  SpellOptions,
} from "../../combat/model.ts";
import * as C from "../../shared/math.ts";

const { clamp, pick, random, hash } = C;
const W = 1280,
  H = 800,
  TAU = Math.PI * 2,
  ENTITY_SCALE = 0.66;
const dist = (a: Point, b: Point) => Math.hypot(a.x - b.x, a.y - b.y);

import type { CombatRuntime } from "../Runtime.ts";
type Context = Pick<
  CombatRuntime,
  | "canEnemyAct"
  | "inAttackRange"
  | "reflectBullet"
  | "counterHit"
  | "stats"
  | "addResonance"
  | "arena"
  | "blasts"
  | "book"
  | "bullet"
  | "bullets"
  | "burst"
  | "chapter"
  | "decoy"
  | "enemies"
  | "fields"
  | "fxRng"
  | "grazes"
  | "hurt"
  | "lasers"
  | "mode"
  | "nearest"
  | "nodes"
  | "player"
  | "pool"
  | "pressure"
  | "releaseShot"
  | "ring"
  | "rng"
  | "shake"
  | "shots"
  | "sound"
  | "sparks"
  | "spawnNode"
  | "strike"
  | "target"
  | "wordFor"
>;

export function launchShot(
  this: Context,
  from: Point,
  target: Enemy | undefined,
  kind: string,
  dmg: number,
  opts: SpellOptions = {},
) {
  if (this.shots.length >= 110 || !target || target.dead) return;
  const angle = Math.atan2(target.y - from.y, target.x - from.x),
    speed =
      kind === "ice"
        ? opts.empowered
          ? 1080
          : 920
        : kind === "blade"
          ? 890
          : 740;
  const s: Shot = {
    reserved: false,
    x: from.x,
    y: from.y - 9,
    px: from.x,
    py: from.y - 9,
    vx: Math.cos(angle) * speed,
    vy: Math.sin(angle) * speed,
    speed,
    kind,
    targetId: target.id,
    homing: true,
    age: 0,
    life: kind === "ice" ? 1.65 : 2.1,
    r: kind === "ice" ? (opts.empowered ? 12 : 7) : 5,
    dmg,
    pierce: opts.pierce || 0,
    hits: new Set<number>(),
    trail: [],
    dead: false,
    seed: this.fxRng(),
    ...opts,
  };
  WordReservations.reserve(s, target, !!opts.refreshWord);
  this.shots.push(s);
}

export function releaseShot(this: Context, s: Shot) {
  WordReservations.release(s, this.enemies, (t) =>
    Object.assign(t, this.wordFor(t.boss, t)),
  );
}

export function updateShots(this: Context, dt: number) {
  for (const s of this.shots) {
    if (s.dead) continue;
    s.age += dt;
    s.life -= dt;
    s.px = s.x;
    s.py = s.y;
    let target = this.enemies.find((e) => !e.dead && e.id === s.targetId);
    if (!target && s.homing) {
      this.releaseShot(s);
      target = this.nearest(s, s.hits);
      if (target) {
        s.targetId = target.id;
        s.reserved = true;
        target.pendingHits = (target.pendingHits || 0) + 1;
      } else {
        s.dead = true;
        continue;
      }
    }
    if (target && s.homing) {
      const angle = Math.atan2(target.y - s.y, target.x - s.x),
        turn = s.kind === "ice" ? 17 : 12;
      const desired = Math.atan2(s.vy, s.vx),
        delta = Math.atan2(
          Math.sin(angle - desired),
          Math.cos(angle - desired),
        ),
        a = desired + delta * Math.min(1, dt * turn);
      s.vx = Math.cos(a) * s.speed;
      s.vy = Math.sin(a) * s.speed;
    }
    s.x += s.vx * dt;
    s.y += s.vy * dt;
    s.trail.push({ x: s.x, y: s.y });
    if (s.trail.length > 9) s.trail.shift();
    const candidates = this.enemies
      .filter(
        (e) =>
          !e.dead &&
          !s.hits.has(e.id) &&
          C.segmentDistance(s.px, s.py, s.x, s.y, e.x, e.y) < s.r + e.r,
      )
      .sort(
        (a, b) => dist(a, { x: s.px, y: s.py }) - dist(b, { x: s.px, y: s.py }),
      );
    for (const e of candidates) {
      const primary = e.id === s.targetId;
      s.hits.add(e.id);
      this.strike(e, s.dmg * (primary ? 1 : 0.67), {
        kind: s.kind === "echo" ? this.book : s.kind,
        direct: s.direct && primary,
        empowered: s.empowered,
        critical: s.critical,
        from: { x: s.px - s.vx * 0.08, y: s.py - s.vy * 0.08 },
        depth: s.depth || 0,
      });
      if (primary) {
        this.releaseShot(s);
        s.homing = false;
      }
      if (s.kind !== "ice" || (s.pierce <= 0 && !s.homing)) {
        s.dead = true;
        break;
      }
      s.pierce--;
    }
    if (
      s.x < this.arena.l - 45 ||
      s.x > this.arena.r + 45 ||
      s.y < this.arena.t - 45 ||
      s.y > this.arena.b + 45 ||
      s.life <= 0
    )
      s.dead = true;
    if (s.dead) this.releaseShot(s);
  }
}

export function bullet(
  this: Context,
  x: number,
  y: number,
  a: number,
  speed: number,
  color: string,
  extra: BulletOptions = {},
) {
  if (
    extra.source != null &&
    !this.enemies.some(
      (e) =>
        e.id === extra.source && this.canEnemyAct(e) && this.inAttackRange(e),
    )
  )
    return null;
  if (this.bullets.length >= 650) return null;
  const b = {
    x,
    y,
    px: x,
    py: y,
    vx: Math.cos(a) * speed,
    vy: Math.sin(a) * speed,
    r: extra.heavy ? 7 : 4.5,
    life: 8,
    age: 0,
    dead: false,
    color,
    grazed: false,
    ...extra,
  };
  this.bullets.push(b);
  return b;
}

export function fire(
  this: Context,
  e: Enemy,
  pattern = "fan",
  extra: BulletOptions = {},
) {
  if (!this.canEnemyAct(e) || !this.inAttackRange(e)) return;
  const p = this.decoy && this.decoy.life > 0 ? this.decoy : this.player,
    angle = Math.atan2(p.y - e.y, p.x - e.x),
    rank = this.mode.rank;
  const speed =
    (83 + this.chapter * 12) * (this.pressure?.speed || 1) * (extra.speed || 1);
  const count =
    pattern === "ring"
      ? 10 + this.chapter * 3 + rank
      : pattern === "single"
        ? 1
        : 3 + Math.min(3, this.chapter + Math.floor(rank / 2));
  const gap = Math.floor(this.rng() * Math.max(1, count));
  for (let i = 0; i < count; i++) {
    if (pattern === "ring" && (i === gap || i === (gap + 1) % count)) continue;
    const a =
      pattern === "ring"
        ? (i / count) * TAU + e.age * 0.14
        : angle + (i - (count - 1) / 2) * 0.145;
    this.bullet(
      e.x,
      e.y,
      a,
      speed,
      pattern === "ring" ? "#f59dd1" : "#ffb197",
      { source: e.id, ...extra },
    );
  }
  this.ring(e.x, e.y, e.r + 10, "#f1a4a6", 0.3);
  if (
    (pattern === "ring" || this.rng() < 0.2) &&
    this.nodes.filter((n) => !n.dead && n.kind === "rune").length < 2
  )
    this.spawnNode("rune", e);
}

export function laser(this: Context, e: Enemy | null, boss = false) {
  if (e && (!this.canEnemyAct(e) || !this.inAttackRange(e))) return;
  if (this.lasers.length >= 5) return;
  const vertical = this.rng() < 0.5,
    pos = vertical ? this.player.x : this.player.y;
  const warning = Math.max(
    0.92,
    (1.5 + Math.min(this.pool.shortest, 8) * 0.085) *
      (this.pressure?.warning || 1),
  );
  this.lasers.push({
    vertical,
    pos,
    width: boss ? 20 : 13,
    warning,
    warningMax: warning,
    active: 0.48,
    age: 0,
    dead: false,
    source: e?.id,
  });
  if (boss && this.chapter > 0)
    this.lasers.push({
      vertical: !vertical,
      pos: vertical
        ? clamp(this.player.y - 100, 245, 595)
        : clamp(this.player.x + 155, 200, 1080),
      width: 15,
      warning: warning + 0.4,
      warningMax: warning + 0.4,
      active: 0.42,
      age: 0,
      dead: false,
      source: e?.id,
    });
  this.spawnNode("rune", e);
}

export function makeBlast(
  this: Context,
  x: number,
  y: number,
  r: number,
  warning = 1.2,
  source: number | null = null,
  ring = true,
) {
  if (
    source != null &&
    !this.enemies.some(
      (e) => e.id === source && this.canEnemyAct(e) && this.inAttackRange(e),
    )
  )
    return;
  if (this.blasts.length >= 9) return;
  this.blasts.push({
    x: clamp(x, this.arena.l + 20, this.arena.r - 20),
    y: clamp(y, this.arena.t + 20, this.arena.b - 20),
    r,
    warning,
    max: warning,
    life: 0.35,
    dead: false,
    fired: false,
    source,
    ring,
  });
}

export function clearBullets(this: Context, x: number, y: number, r: number) {
  let count = 0;
  for (const b of this.bullets) {
    if (!b.dead && !b.reflected && Math.hypot(b.x - x, b.y - y) < r) {
      b.dead = true;
      count++;
      if (count % 3 === 0) this.sparks(b.x, b.y, 2, "#98ddc7", 25);
    }
  }
  return count;
}

export function updateBullets(this: Context, dt: number) {
  const p = this.player,
    bookSlow = this.target && this.stats.aimingSlow ? 0.82 : 1;
  for (const b of this.bullets) {
    if (b.dead) continue;
    b.age = (b.age || 0) + dt;
    b.px = b.x;
    b.py = b.y;
    let factor = b.reflected ? 1 : bookSlow;
    if (
      !b.reflected &&
      this.fields.some((f) => f.kind === "frost" && dist(f, b) < f.r)
    )
      factor *= 0.63;
    if (b.curve) {
      const a = Math.atan2(b.vy, b.vx) + b.curve * dt,
        v = Math.hypot(b.vx, b.vy);
      b.vx = Math.cos(a) * v;
      b.vy = Math.sin(a) * v;
    }
    if (b.accel && b.age < 2) {
      const m = Math.pow(b.accel, dt);
      b.vx *= m;
      b.vy *= m;
    }
    b.x += b.vx * dt * factor;
    b.y += b.vy * dt * factor;
    b.life -= dt;
    if (b.reflected) {
      const length2 = (b.x - b.px) ** 2 + (b.y - b.py) ** 2 || 1;
      const along = (e: Enemy) =>
        ((e.x - b.px) * (b.x - b.px) + (e.y - b.py) * (b.y - b.py)) / length2;
      const hit = this.enemies
        .filter(
          (e) =>
            !e.dead &&
            C.segmentDistance(b.px, b.py, b.x, b.y, e.x, e.y) < e.r + b.r,
        )
        .sort((a, b) => along(a) - along(b))[0];
      if (hit) {
        this.counterHit(hit, DEFENSE.damage * (b.heavy ? 1.25 : 1));
        b.dead = true;
      }
      if (b.life <= 0) b.dead = true;
      continue;
    }
    const d = C.segmentDistance(b.px, b.py, b.x, b.y, p.x, p.y);
    if (p.parryTime > 0 && d < DEFENSE.radius + b.r) {
      this.reflectBullet(b);
      continue;
    }
    if (d < b.r + p.r) {
      if (p.invuln <= 0) {
        this.hurt((b.heavy ? 16 : 11) * this.pressure.damage, {
          x: b.px,
          y: b.py,
        });
        b.dead = true;
      }
    } else if (d < b.r + 30 && !b.grazed) {
      b.grazed = true;
      this.grazes++;
      this.addResonance(this.stats.grazeCharge ? 1.4 : 0.7);
      if (this.stats.grazeCharge) p.shield = Math.min(60, p.shield + 0.6);
      this.sparks(p.x, p.y, 2, "#f3dfa0", 45);
    }
    if (
      b.x < this.arena.l - 20 ||
      b.x > this.arena.r + 20 ||
      b.y < this.arena.t - 20 ||
      b.y > this.arena.b + 20 ||
      b.life <= 0
    )
      b.dead = true;
  }
}

export function updateHazards(this: Context, dt: number) {
  const p = this.player;
  for (const l of this.lasers) {
    if (l.dead) continue;
    if (
      l.source != null &&
      !this.enemies.some((e) => e.id === l.source && this.canEnemyAct(e))
    ) {
      l.dead = true;
      continue;
    }
    l.age += dt;
    if (l.warning > 0) {
      if (l.source && !this.enemies.some((e) => !e.dead && e.id === l.source)) {
        l.dead = true;
        continue;
      }
      l.warning -= dt;
      if (l.warning <= 0) {
        this.sound.laser(l.vertical ? { x: l.pos, y: p.y } : { x: p.x, y: l.pos });
        this.shake = Math.max(this.shake, 3);
      }
    } else {
      l.active -= dt;
      const d = l.vertical ? Math.abs(p.x - l.pos) : Math.abs(p.y - l.pos);
      if (d < l.width + p.r) this.hurt(23 * this.pressure.damage);
      if (l.active <= 0) l.dead = true;
    }
  }
  for (const b of this.blasts) {
    if (b.dead) continue;
    if (
      b.source != null &&
      !this.enemies.some((e) => e.id === b.source && this.canEnemyAct(e))
    ) {
      b.dead = true;
      continue;
    }
    if (b.warning > 0) {
      if (b.source && !this.enemies.some((e) => e.id === b.source && !e.dead)) {
        b.dead = true;
        continue;
      }
      b.warning -= dt;
    } else {
      if (!b.fired) {
        b.fired = true;
        this.burst(b.x, b.y, b.r, "#ff9fa4", "shock");
        this.sound.impact("blast", 1, b);
        if (dist(p, b) < b.r + p.r) this.hurt(23 * this.pressure.damage, b);
        if (b.ring)
          for (let i = 0; i < 10; i++)
            this.bullet(
              b.x,
              b.y,
              (i / 10) * TAU,
              95 * this.pressure.speed,
              "#f3a3b5",
            );
      }
      b.life -= dt;
      if (b.life <= 0) b.dead = true;
    }
  }
}
