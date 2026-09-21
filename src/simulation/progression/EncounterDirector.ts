import type { CombatRuntime } from "../Runtime.ts";
import type { Route } from "../../contracts/game.ts";
import { difficulty } from "./difficulty.ts";
import { pick } from "../../shared/math.ts";
import { assaultDirections } from "../../shared/assault.ts";
type Context = Pick<
  CombatRuntime,
  | "pendingRequiredTasks"
  | "domainEvents"
  | "roomVisit"
  | "aimKeys"
  | "allowedEnemies"
  | "blasts"
  | "boss"
  | "bossName"
  | "bossRoom"
  | "bullets"
  | "campaign"
  | "cancel"
  | "chapter"
  | "chapterName"
  | "clearBullets"
  | "clearDelay"
  | "content"
  | "emit"
  | "enemies"
  | "findSafe"
  | "hitStop"
  | "counterSlowTime"
  | "lasers"
  | "loopCount"
  | "mode"
  | "nodeClock"
  | "nodes"
  | "payBloodPrice"
  | "player"
  | "postCombat"
  | "precisionTime"
  | "pressure"
  | "resetArrays"
  | "rng"
  | "roomDuration"
  | "roomEnded"
  | "roomKills"
  | "roomMod"
  | "roomNumber"
  | "roomQuota"
  | "roomTime"
  | "safePoint"
  | "setState"
  | "spawnBoss"
  | "spawnClock"
  | "spawnEnemy"
  | "spawnNode"
  | "spawned"
  | "sound"
  | "spiritTime"
  | "awakenedSpirits"
  | "stage"
  | "tasks"
  | "ultimateTime"
  | "upgradeAt"
  | "wave"
  | "assaultDirection"
  | "waveCount"
  | "waveRest"
  | "waveWaiting"
>;
export function beginRoom(this: Context, route: Route = { type: "normal" }) {
  this.sound.chapter();
  const progress = this.campaign.at(this.stage);
  this.roomVisit++;
  this.chapter = progress.chapter;
  this.loopCount = progress.loop;
  this.roomNumber = progress.roomNumber;
  this.waveCount = progress.room.waves;
  this.roomMod = route.type || "normal";
  this.roomTime = 0;
  this.upgradeAt = 0;
  this.roomEnded = false;
  this.resetArrays();
  this.cancel(false);
  this.player.x = 640;
  this.player.y = 400;
  this.player.vx = 0;
  this.player.vy = 0;
  this.player.dashState = null;
  this.player.parryTime = 0;
  this.player.parryCooldown = 0;
  this.player.parrySuccess = false;
  this.player.invuln = 1.5;
  this.player.dash = Math.max(this.player.dash, 1);
  this.spiritTime = 0;
  this.awakenedSpirits = 0;
  this.ultimateTime = 0;
  this.hitStop = 0;
  this.counterSlowTime = 0;
  this.aimKeys = {};
  this.precisionTime = 0;
  this.payBloodPrice();
  this.pressure = difficulty(
    this.mode,
    this.stage,
    0,
    this.roomMod === "elite",
    this.campaign.at(this.stage),
  );
  this.spawnClock = progress.room.spawnDelay ?? (this.stage === 0 ? 3.6 : 2.4);
  this.nodeClock = progress.room.nodeInterval ?? 6;
  this.spawned = 0;
  this.roomKills = 0;
  this.waveRest = 0;
  this.waveWaiting = false;
  this.roomQuota = progress.room.quota ?? this.pressure.quota;
  this.roomDuration = Math.round(
    this.roomQuota * this.pressure.interval * 0.95,
  );
  this.clearDelay = 0;
  this.bossRoom = progress.room.boss;
  this.boss = null;
  this.wave = 1;
  this.assaultDirection = this.bossRoom ? 0 : Math.floor(this.rng() * 8);
  if (this.bossRoom) {
    this.spawnBoss();
    this.roomQuota = 0;
  } else {
    const n = this.mode.rank < 2 ? 1 : Math.min(3, this.mode.rank);
    for (let i = 0; i < Math.min(n, this.roomQuota); i++) {
      this.spawnEnemy(
        (progress.room.opening ?? progress.room.enemies)[
          i % (progress.room.opening ?? progress.room.enemies).length
        ],
      );
      this.spawned++;
    }
  }
  this.safePoint = null;
  this.domainEvents.publish({
    type: "room",
    room: progress.room.id,
    visit: this.roomVisit,
  });
  this.setState("playing");
  this.emit("banner", {
    title: this.bossRoom ? this.bossName : this.chapterName,
    sub: `${this.loopCount ? "LOOP " + (this.loopCount + 1) + " / " : ""}CHAPTER 0${this.chapter + 1} / ${this.bossRoom ? "BOSS ENCOUNTER" : this.mode.name + " · 第一波"}`,
  });
  this.emit("hud");
}

export function updateEncounter(this: Context, dt: number) {
  if (!this.bossRoom && !this.roomEnded) {
    const waveLimit = Math.ceil((this.roomQuota * this.wave) / this.waveCount);
    if (
      this.wave < this.waveCount &&
      this.spawned >= waveLimit &&
      !this.enemies.some((e) => !e.dead && e.countsForClear !== false) &&
      !this.pendingRequiredTasks &&
      !this.waveWaiting
    ) {
      this.waveWaiting = true;
      this.waveRest = Math.max(1.8, 4 - this.mode.rank * 0.5);
      this.bullets = [];
      this.lasers = [];
      this.blasts = [];
      this.emit("banner", { title: "墨潮暂歇", sub: "下一波即将到来" });
    }
    if (this.waveWaiting) {
      this.waveRest -= dt;
      if (this.waveRest <= 0) {
        this.waveWaiting = false;
        this.wave++;
        this.assaultDirection = Math.floor(this.rng() * 8);
        this.spawnClock = 0.8;
        this.emit("banner", {
          title: this.wave === 2 ? "墨潮涌动" : "最后一波",
          sub: `第 ${this.wave} 波 · ${assaultDirections[this.assaultDirection]}侧来袭`,
        });
      }
    }
    this.spawnClock -= dt;
    if (
      !this.waveWaiting &&
      this.spawnClock <= 0 &&
      this.spawned < Math.ceil((this.roomQuota * this.wave) / this.waveCount) &&
      this.enemies.filter((e) => !e.dead).length < this.pressure.cap
    ) {
      const batch =
        1 +
        (this.mode.rank >= 2 && this.wave >= 2 ? 1 : 0) +
        (this.chapter >= 1 && this.mode.rank >= 1 ? 1 : 0) +
        (this.chapter >= 2 && this.mode.rank >= 3 ? 1 : 0) +
        (this.wave === this.waveCount && this.mode.rank >= 3 ? 1 : 0);
      for (
        let i = 0;
        i < batch &&
        this.spawned < Math.ceil((this.roomQuota * this.wave) / this.waveCount);
        i++
      ) {
        let allowed = this.allowedEnemies().filter(
          (type) =>
            this.enemies.filter((e) => !e.dead && e.type === type).length <
            (this.content.enemies[type].behavior.spawnLimit ?? Infinity),
        );
        if (!allowed.length) break;
        const e = this.spawnEnemy(pick(allowed, this.rng));
        if (e) this.spawned++;
      }
      this.spawnClock = this.pressure.interval;
    }
    if (
      !this.waveWaiting &&
      !this.enemies.some((e) => !e.dead && e.countsForClear !== false) &&
      !this.pendingRequiredTasks &&
      this.roomTime > 4
    )
      this.spawnClock = Math.min(this.spawnClock, 0.8);
  }
  this.nodeClock -= dt;
  if (this.nodeClock <= 0 && !this.roomEnded) {
    this.spawnNode(this.rng() < 0.65 ? "rune" : "ink", this.boss);
    this.nodeClock =
      this.campaign.at(this.stage).room.nodeInterval ?? 10 + this.rng() * 4;
  }
}

export function finishEncounter(this: Context, dt: number) {
  if (
    !this.bossRoom &&
    !this.roomEnded &&
    this.spawned >= this.roomQuota &&
    !this.pendingRequiredTasks &&
    !this.enemies.some((e) => e.countsForClear !== false)
  ) {
    this.roomEnded = true;
    this.clearDelay = 0.9;
    this.clearBullets(640, 400, 1800);
    this.lasers = [];
    this.blasts = [];
    this.tasks = [];
    this.nodes = [];
    this.cancel();
    this.emit("banner", {
      title: "这一页，已被改写",
      sub: "ALL WAVES CLEARED",
    });
  }
  if (this.roomEnded) {
    this.clearDelay -= dt;
    if (this.clearDelay <= 0) {
      this.postCombat(true);
      return true;
    }
  }

  return false;
}
