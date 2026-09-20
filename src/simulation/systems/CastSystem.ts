import { summonCapacity } from "../../shared/summons.ts";
import type { RelicContext } from "../RelicRules.ts";
import type { BookAbilityContext } from "../../content-sdk/BookBehavior.ts";

import type { Point, CombatTarget } from "../../combat/model.ts";
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
  | "domainEvents"
  | "roomVisit"
  | "godMode"
  | "stats"
  | "addResonance"
  | "afterCast"
  | "autofill"
  | "book"
  | "bookBehavior"
  | "bookCounter"
  | "bookData"
  | "burst"
  | "casts"
  | "chain"
  | "clearBullets"
  | "combo"
  | "comboTimer"
  | "damageMultiplier"
  | "emit"
  | "floating"
  | "hitStop"
  | "launchShot"
  | "manual"
  | "maxCombo"
  | "nearest"
  | "perfectWords"
  | "player"
  | "reflectionBoost"
  | "relicRules"
  | "relics"
  | "resonance"
  | "ring"
  | "shake"
  | "sound"
  | "spiritTime"
  | "state"
  | "triggerNode"
  | "ultTick"
  | "ultimateTime"
  | "ultimates"
  | "wordFor"
  | "wordStats"
  | keyof BookAbilityContext
  | keyof RelicContext
>;

export function cast(
  this: Context,
  t: CombatTarget,
  perfect = true,
  auto = false,
) {
  if (!t || t.dead || t.wordPending || this.state !== "playing") return;
  const word = t.word;
  this.domainEvents.publish({ type: "cast", entity: t.id, word });
  this.casts++;
  this.combo++;
  this.comboTimer = 5;
  this.maxCombo = Math.max(this.combo, this.maxCombo);
  if (!t.kind) this.bookCounter++;
  this.perfectWords = perfect ? this.perfectWords + 1 : 0;
  const empowered = !t.kind && this.bookCounter % this.bookData.cycle === 0;
  this.sound.cast(this.bookData.audio, empowered, this.player);
  this.player.recoil = empowered ? 0.7 : 0.45;
  this.player.lean = Math.atan2(t.y - this.player.y, t.x - this.player.x);
  this.shake = Math.max(this.shake, empowered ? 5 : 2);
  this.ring(
    this.player.x,
    this.player.y - 8,
    empowered ? 65 : 40,
    this.bookData.color,
    0.27,
  );
  const stat =
    this.wordStats[word] ||
    (this.wordStats[word] = { done: 0, errors: 0, meaning: t.meaning });
  stat.done++;
  if (!auto) {
    this.manual++;
    if (this.stats.autofillCadence && this.manual % 4 === 0) {
      this.autofill = true;
      this.emit("toast", "羽毛笔就绪 · 下一词前两字母即可补全");
    }
  }
  this.addResonance((perfect ? 8 : 6) * (this.stats.resonanceHaste ? 1.35 : 1));
  if (this.bookBehavior.summons) this.awakenedSpirits = Math.min(summonCapacity(true, this.stats, this.ultimateTime), (this.spiritTime > 0 ? this.awakenedSpirits : 0) + 1);
  if (
    this.bookBehavior.summons ||
    this.stats.summonStacks ||
    this.stats.summonBond
  )
    this.spiritTime = Math.min(
      18,
      this.spiritTime +
        4 +
        (this.stats.summonStacks || 0) +
        (this.stats.summonBond || 0) * 2,
    );
  if (t.kind) {
    this.triggerNode(t);
    this.afterCast(t, perfect);
    return;
  }
  let dmg = (35 + word.length * 5.4) * this.damageMultiplier();
  if (word.length <= 4 && this.stats.shortWordDamage) {
    dmg *= 1 + 0.6 * this.stats.shortWordDamage;
    this.player.dash = Math.min(this.player.maxDash, this.player.dash + 0.1);
  }
  if (word.length >= 7 && this.stats.longWordDamage) {
    dmg *= 1 + 0.75 * this.stats.longWordDamage;
    this.clearBullets(t.x, t.y, 105);
  }
  if (perfect) dmg *= 1.08 + (this.stats.perfectDamage || 0) * 0.35;
  dmg *= 1 + Math.min(this.combo, 10) * 0.025 * (this.stats.comboPower ? 2 : 1);
  let critical = !!this.stats.criticalCadence && this.casts % 4 === 0;
  if (critical) {
    dmg *= 2;
    this.floating(t.x, t.y - 68, "暴击", this.bookData.color, 21);
  }
  if (this.reflectionBoost) {
    dmg *= 2;
    this.reflectionBoost = false;
  }
  this.bookBehavior.cast(this, t, dmg, empowered, critical);
  if (this.stats.chainTargets && !this.bookBehavior.nativeChain)
    this.chain(t, dmg * 0.45, this.stats.chainTargets);
  if (this.stats.echoCast && this.casts % 3 === 0) {
    const other = this.nearest(t, new Set([t.id]));
    if (other)
      this.launchShot(this.player, other, "echo", dmg * 0.65, {
        direct: false,
      });
  }
  this.bookBehavior.afterCast?.(this, t, dmg);
  this.afterCast(t, perfect);
  if (!t.dead && !t.wordPending) Object.assign(t, this.wordFor(t.boss, t));
}

export function afterCast(this: Context, t: CombatTarget, perfect: boolean) {
  this.relicRules.run("afterCast", this, { perfect });
  if (perfect && this.combo % 10 === 0) {
    this.floating(
      this.player.x,
      this.player.y - 83,
      `${this.combo} 连笔`,
      this.bookData.color,
      22,
    );
    this.emit("toast", `${this.combo} 连笔 · 施法伤害正在提高`);
  }
  this.emit("hud");
}

export function ultimate(this: Context) {
  if (!this.godMode && this.resonance < 100) {
    this.emit(
      "toast",
      `终式 ${Math.floor(this.resonance)}% · 完词、擦弹与极限闪避积攒共鸣`,
    );
    return;
  }
  this.resonance = this.godMode ? 100 : 0;
  this.ultimates++;
  this.ultimateTime = this.bookBehavior.duration(this);
  this.ultTick = 0.12;
  this.player.invuln = Math.max(this.player.invuln, 0.65);
  this.shake = 10;
  this.hitStop = 0.055;
  this.clearBullets(this.player.x, this.player.y, 260);
  this.burst(
    this.player.x,
    this.player.y,
    310,
    this.bookData.color,
    "ultimate",
  );
  this.sound.ultimate(this.bookData.audio, this.player);
  this.emit("banner", {
    title: this.bookData.ultimate,
    sub: "RESONANCE / " + this.bookData.short + "终式",
  });
  this.bookBehavior.ultimate(this);
  this.emit("hud");
}

export function addResonance(this: Context, n: number) {
  if (this.ultimateTime > 0) return;
  const before = this.resonance;
  this.resonance = clamp(this.resonance + n, 0, 100);
  if (before < 100 && this.resonance >= 100) {
    this.emit("toast", `终式就绪 · 按 Shift 释放「${this.bookData.ultimate}」`);
    this.sound.ready();
  }
}
