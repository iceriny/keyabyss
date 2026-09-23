import { enemyInCombat } from "../../shared/arena.ts";
import { chooseEnemyWord } from "./EliteWords.ts";
import { directionKeys, dodgeDirection } from "../../shared/defense.ts";
import type { Point, CombatTarget } from "../../combat/model.ts";
import * as C from "../../shared/math.ts";
import { displayBoundary, playableLength } from "../../vocabulary/index.ts";

const { clamp, pick, random, hash } = C;
const W = 1280,
  H = 800,
  TAU = Math.PI * 2,
  ENTITY_SCALE = 0.66;
const dist = (a: Point, b: Point) => Math.hypot(a.x - b.x, a.y - b.y);

import type { CombatRuntime } from "../Runtime.ts";
type Context = Pick<
  CombatRuntime,
  | "arena"
  | "enemyProfile"
  | "eliteProfile"
  | "aimKeys"
  | "autofill"
  | "bookData"
  | "bullets"
  | "cancel"
  | "cast"
  | "castError"
  | "chapter"
  | "chargePulse"
  | "combo"
  | "config"
  | "correct"
  | "cycle"
  | "dodge"
  | "parry"
  | "emit"
  | "enemies"
  | "errors"
  | "findSafe"
  | "loopCount"
  | "mode"
  | "nodes"
  | "perfectWords"
  | "player"
  | "pool"
  | "postCombat"
  | "precisionTime"
  | "prefix"
  | "priority"
  | "rng"
  | "safePoint"
  | "sound"
  | "sparks"
  | "state"
  | "target"
  | "targets"
  | "typedTotal"
  | "ultimate"
  | "wordStats"
>;

export function wordFor(
  this: Context,
  extra = false,
  exclude: CombatTarget | null = null,
) {
  const preference = exclude && !exclude.kind
    ? this.eliteProfile(exclude)?.wordPreference
    : undefined;
  return chooseEnemyWord(this, extra, exclude, preference);
}

export function targets(this: Context) {
  return [...this.enemies, ...this.nodes].filter(
    (t) => !t.dead && !t.wordPending,
  );
}

function selectable(ctx: Context, target: CombatTarget) {
  return !!target.kind || enemyInCombat(ctx.arena, target);
}
function retainLock(target: CombatTarget | null) {
  if (target && !target.kind) target.combatLocked = true;
}

export function priority(this: Context, t: CombatTarget) {
  return (
    dist(t, this.player) +
    (t.kind === "rune" && this.bullets.length > 14 ? -140 : 0) +
    (t.boss ? 80 : 0) +
    (t.grace > 0.4 ? 80 : 0) +
    (t.kind ? 0 : (this.enemyProfile(t).targetingPriority ?? 0)) +
    (t.pendingHits ? 90 : 0)
  );
}

export function input(this: Context, key: string) {
  if (this.state !== "playing") return false;
  if (key === " ") {
    this.parry();
    return true;
  }
  if (key === "Shift") {
    this.ultimate();
    return true;
  }
  if (directionKeys[key] || key === 'Alt') {
    this.aimKeys = key === 'Alt' ? {} : { [key]: true };
    this.dodge();
    this.aimKeys = {};
    return true;
  }
  if (key === "Backspace") {
    this.cancel();
    return true;
  }
  if (key === "Tab") {
    this.cycle();
    return true;
  }
  if (key.length !== 1 || !/[a-zA-Z0-9_'\-]/.test(key)) return false;
  key = key.toLowerCase();
  this.typedTotal++;
  this.sound.key(playableLength(this.prefix) + 1, this.bookData.audio);
  if (!this.target || (this.target.dead && (!this.prefix || this.target.kind))) {
    this.target = null;
    this.prefix = "";
    const matches = this.targets()
      .filter((t) => selectable(this, t) && t.word[0] === key)
      .sort((a, b) => this.priority(a) - this.priority(b));
    if (matches.length) {
      this.target = matches[0];
      this.castError = false;
    }
  }
  if (this.target && !this.target.dead && this.target.word[this.prefix.length] !== key) {
    // Resolve shared initials from the typed prefix; no token is rewritten mid-input.
    const alternatives = this.targets()
      .filter((t) => selectable(this, t) && t.word.startsWith(this.prefix + key))
      .sort((a, b) => this.priority(a) - this.priority(b));
    if (alternatives.length) this.target = alternatives[0];
  }
  if (!this.target || this.target.word[this.prefix.length] !== key) {
    this.errors++;
    this.castError = true;
    this.perfectWords = 0;
    this.combo = Math.max(0, this.combo - 1);
    this.sound.wrong();
    this.emit("mistake");
    if (this.target) {
      const st =
        this.wordStats[this.target.word] ||
        (this.wordStats[this.target.word] = {
          done: 0,
          errors: 0,
          meaning: this.target.meaning,
        });
      st.errors++;
    }
    return true;
  }
  retainLock(this.target);
  this.correct++;
  this.prefix = this.target.word.slice(0, displayBoundary(this.target.word, playableLength(this.prefix) + 1));
  this.player.recoil = Math.max(this.player.recoil, 0.1);
  this.chargePulse = 1;
  this.sparks(this.player.x, this.player.y - 17, 2, this.bookData.color, 45);
  this.emit("hud");
  const auto =
    this.autofill && playableLength(this.prefix) >= 2 && playableLength(this.target.word) > 2;
  if (this.prefix === this.target.word || auto) {
    const t = this.target,
      perfect = !this.castError,
      manualChars = playableLength(this.prefix),
      continuation = t.dead && !t.kind;
    if (auto) this.autofill = false;
    this.cancel(false);
    this.cast(t, perfect, auto, manualChars, continuation);
    this.postCombat();
  }
  return true;
}

export function cycle(this: Context, direction = 1) {
  if (this.target?.dead && !this.target.kind && this.prefix) return;
  const prefix = this.prefix || "";
  const list = this.targets()
    .filter((t) => selectable(this, t) && (!prefix || t.word.startsWith(prefix)))
    .sort((a, b) => this.priority(a) - this.priority(b));
  if (!list.length) return;
  const index = this.target ? list.indexOf(this.target) : -1;
  this.target =
    list[
      index < 0
        ? direction < 0
          ? list.length - 1
          : 0
        : (index + direction + list.length) % list.length
    ];
  retainLock(this.target);
  if (!prefix) this.castError = false;
  this.emit("hud");
}

export function clickTarget(
  this: Context,
  x: number,
  y: number,
  targetId?: number,
) {
  if (this.state !== "playing") return;
  const t =
    this.targets().filter((t) => selectable(this, t)).find((t) => t.id === targetId) ||
    this.targets().filter((t) => selectable(this, t)).find((t) => Math.hypot(x - t.x, y - t.y) < t.r + 10);
  if (t) {
    this.cancel(false);
    this.target = t;
    retainLock(t);
    this.emit("hud");
  }
}

export function cancel(this: Context, notify = true) {
  this.target = null;
  this.prefix = "";
  this.castError = false;
  if (notify) this.emit("hud");
}

export function releaseKey(this: Context, key: string) {
  delete this.aimKeys[key.length === 1 ? key.toLowerCase() : key];
  const d = dodgeDirection(this.aimKeys);
  this.safePoint = d.x || d.y ? this.findSafe() : null;
}
