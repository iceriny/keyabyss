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
  | "combatValue"
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
  | "relics"
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
  | "weaveCast"
  | "weave"
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
  manualChars?: number,
  continuation = false,
) {
  if (!t || (t.dead && (!continuation || t.kind)) || t.wordPending || this.state !== "playing") return;
  const word = t.word;
  this.domainEvents.publish({ type: "cast", entity: t.id, word });
  this.casts++;
  this.combo++;
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
  if (this.bookBehavior.summons) this.awakenedSpirits = Math.min(this.combatValue("summon.capacity"), (this.spiritTime > 0 ? this.awakenedSpirits : 0) + 1);
  if (
    this.bookBehavior.summons ||
    this.stats.summonStacks ||
    this.stats.summonBond
  )
    this.spiritTime = Math.min(
      18,
      this.spiritTime +
        this.combatValue("summon.duration"),
    );
  if (t.kind) {
    this.triggerNode(t);
    this.afterCast(t, perfect);
    return;
  }
  const shortWord = this.relicRules.wordModifierApplies(this.relics, "shortWordDamage", word.length);
  const longWord = this.relicRules.wordModifierApplies(this.relics, "longWordDamage", word.length);
  let dmg = this.combatValue("cast.base", {
    wordLength: word.length, shortWord: Number(shortWord),
    longWord: Number(longWord), perfect: Number(perfect),
  });
  if (shortWord) {
    this.player.dash = Math.min(this.player.maxDash, this.player.dash + 0.1);
  }
  if (longWord) {
    this.clearBullets(t.x, t.y, 105);
  }
  let critical = !!this.stats.criticalCadence && this.casts % 4 === 0;
  if (critical) {
    dmg *= this.combatValue("crit.multiplier");
    this.floating(t.x, t.y - 68, "暴击", this.bookData.color, 21);
  }
  if (this.reflectionBoost) {
    dmg *= 2;
    this.reflectionBoost = false;
  }
  dmg *= (this.stats.singleFocus ? 1.3 : 1) * this.weave.letterMultiplier(t, manualChars ?? (auto ? 0 : word.length));
  const echoCast = this.stats.echoCast && this.casts % 3 === 0;
  this.weaveCast(t, dmg, manualChars ?? (auto ? 0 : word.length), (recipient) => {
    this.bookBehavior.cast(this, recipient, dmg, empowered, critical);
    if (this.stats.chainTargets && !this.bookBehavior.nativeChain)
      this.chain(recipient, dmg * 0.45, this.stats.chainTargets);
    if (echoCast) {
      const other = this.nearest(recipient, new Set([recipient.id]));
      if (other)
        this.launchShot(this.player, other, "echo", this.combatValue("echo.damage", { castBase: dmg }), {
          direct: false,
        });
    }
    this.bookBehavior.afterCast?.(this, recipient, dmg);
    if (!recipient.dead && !recipient.wordPending)
      Object.assign(recipient, this.wordFor(recipient.boss, recipient));
  });
  this.afterCast(t, perfect);
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
