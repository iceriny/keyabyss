import { eligibleRelic } from "./EligibilityService.ts";
import type { RewardChoice } from "../../contracts/rewards.ts";
import type { RelicContext } from "../RelicRules.ts";
import type { Relic, Route } from "../../contracts/game.ts";

import type { Point } from "../../combat/model.ts";
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
  | "afterUpgrade"
  | "beginRoom"
  | "book"
  | "campaign"
  | "canUpgrade"
  | "cancel"
  | "completeRoom"
  | "content"
  | "emit"
  | "end"
  | "heal"
  | "lastWin"
  | "loopCount"
  | "pending"
  | "player"
  | "pool"
  | "queuedRoute"
  | "relicRules"
  | "relics"
  | "rerolls"
  | "rng"
  | "routeOffers"
  | "routeDestinations"
  | "setState"
  | "sound"
  | "stage"
  | "state"
  | "time"
  | "upgradeAt"
  | "upgradeChoices"
  | keyof RelicContext
>;

export function postCombat(this: Context, cleared = false) {
  if (this.state !== "playing") return;
  if (this.pending > 0) {
    if (!cleared && !this.upgradeAt) {
      this.upgradeAt = this.time + 0.32;
      this.player.invuln = Math.max(this.player.invuln, 0.32);
      return;
    }
    if (!cleared && this.time < this.upgradeAt) return;
    this.upgradeAt = 0;
    this.pending--;
    this.afterUpgrade = cleared ? "clear" : "play";
    this.setState("upgrade");
    this.sound.level();
    this.emit("upgrade", this.upgradeChoices());
    return;
  }
  if (cleared) this.completeRoom();
}

export function upgradeChoices(this: Context): RewardChoice[] {
  const available = this.content.relics.filter((r) => this.canUpgrade(r));
  if (!available.length)
    return [
      {
        id: "renewal",
        name: "余烬补给",
        tag: "补给",
        icon: "renewal",
        desc: "所有遗物均已满阶。恢复25生命，补充一次闪避充能。",
        kind: "supply",
        heal: 25,
        dash: 1,
      },
    ];
  return available
    .map((r) => ({
      r,
      score:
        this.rng() +
        (r.affinity?.includes(this.book) ? 0.19 : 0) +
        (r.rarity === "awaken" ? 0.8 : 0),
    }))
    .sort((a, b) => b.score - a.score)
    .slice(0, 3)
    .map((x) => x.r);
}

export function canUpgrade(
  this: Context,
  r: Pick<Relic, "id" | "max"> & Partial<Relic>,
) {
  return eligibleRelic(r, {
    book: this.book,
    levels: this.relics,
    shortest: this.pool.shortest,
    longest: this.pool.longest,
  });
}

export function chooseUpgrade(this: Context, id: string) {
  if (this.state !== "upgrade") return;
  const r =
    id === "renewal" ? undefined : this.content.relics.find((r) => r.id === id);
  if (id !== "renewal" && (!r || !this.canUpgrade(r))) return;
  if (id === "renewal" && this.content.relics.some((r) => this.canUpgrade(r)))
    return;
  if (id === "renewal") {
    this.heal(25);
    this.player.dash = Math.min(this.player.maxDash, this.player.dash + 1);
  } else this.relics[id] = (this.relics[id] || 0) + 1;
  if (id !== "renewal") this.relicRules.run("acquire", this, { id });
  this.sound.reward();
  this.emit("relics");
  if (r?.rarity === "awaken") this.emit("toast", `咒典觉醒 · ${r.name}`);
  const after = this.afterUpgrade;
  this.afterUpgrade = null;
  this.setState("playing");
  if (after === "route") {
    this.beginRoom(this.queuedRoute);
    return;
  }
  if (this.pending > 0) {
    this.pending--;
    this.afterUpgrade = after;
    this.setState("upgrade");
    this.emit("upgrade", this.upgradeChoices());
    return;
  }
  if (after === "clear") this.completeRoom();
  else this.emit("resume");
}

export function completeRoom(this: Context) {
  const successors = this.campaign.successors(this.stage);
  if (!successors.length) {
    this.end(true);
    return;
  }
  this.routeDestinations = {};
  this.stage = successors[0].stage;
  this.cancel(false);
  this.setState("route");
  const progress = this.campaign.at(this.stage);
  const ids =
    successors[0].route !== null
      ? successors.map((exit) => {
          this.routeDestinations[exit.route!] = exit.stage;
          return exit.route!;
        })
      : progress.room.routes.map((choice) =>
          typeof choice === "string"
            ? choice
            : choice[Math.floor(this.rng() * choice.length)],
        );
  this.routeOffers = Object.freeze(
    ids.map((id) => {
      const route = this.content.routes.find((r) => r.id === id);
      if (!route) throw new Error(`Unknown route ${id}`);
      return route;
    }),
  );
  this.emit("route", {
    chapter: progress.chapter,
    boss: progress.room.boss,
    cleared: progress.index,
    loop: this.loopCount,
    offers: this.routeOffers,
  });
}

export function chooseRoute(this: Context, route: Route) {
  if (this.state !== "route") return;
  if (route.id && this.routeDestinations[route.id] !== undefined)
    this.stage = this.routeDestinations[route.id];
  this.routeOffers = [];
  this.routeDestinations = {};
  this.queuedRoute = route;
  if (route.heal) this.heal(route.heal);
  if (route.hurt) this.player.hp = Math.max(1, this.player.hp - route.hurt);
  if (route.shield)
    this.player.shield = Math.min(50, this.player.shield + route.shield);
  if (route.relic) {
    this.afterUpgrade = "route";
    this.setState("upgrade");
    this.emit("upgrade", this.upgradeChoices());
    return;
  }
  this.beginRoom(route);
}

export function rerollUpgrade(this: Context) {
  if (this.state !== "upgrade" || this.rerolls <= 0) return;
  this.rerolls--;
  this.emit("upgrade", this.upgradeChoices());
}

export function continueLoop(this: Context) {
  if (this.state !== "result" || !this.lastWin) return;
  this.stage = this.campaign.nextLoop(this.stage);
  this.rerolls = Math.min(4, this.rerolls + 1);
  this.player.hp = Math.min(this.player.maxHp, this.player.hp + 30);
  this.pending = 0;
  this.beginRoom({ type: "normal" });
}
