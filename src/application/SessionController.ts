import type { Game } from "../game.ts";
import type {
  GameCommand,
  HudSnapshot,
  SessionView,
} from "../contracts/session.ts";
import type { Config, Settings } from "../contracts/game.ts";
import { prepareBattle } from "../loading.ts";

export interface SessionController extends HudSnapshot {}
/** Transitional application facade. UI receives copies and commands, never the mutable simulation. */
export class SessionController implements SessionView {
  readonly #game: Game;
  readonly #listeners = new Set<() => void>();
  #snapshot: HudSnapshot;
  #stamp = "";
  #offer = new Set<string>();
  #disposed = false;
  readonly #release: () => void;
  constructor(game: Game) {
    this.#game = game;
    this.#snapshot = this.read();
    this.#stamp = JSON.stringify(this.#snapshot);
    for (const key of Object.keys(this.#snapshot))
      Object.defineProperty(this, key, {
        enumerable: true,
        get: () => Reflect.get(this.#snapshot, key),
      });
    const hud = game.events.hud,
      upgrade = game.events.upgrade,
      route = game.events.route;
    const onHud = () => {
      hud?.();
      this.publish();
    };
    const onUpgrade: NonNullable<Game["events"]["upgrade"]> = (choices) => {
      this.#offer = new Set(choices.map((c) => c.id));
      this.publish();
      upgrade?.(choices);
    };
    const onRoute: NonNullable<Game["events"]["route"]> = (info) => {
      this.publish();
      route?.(info);
    };
    game.events.hud = onHud;
    game.events.upgrade = onUpgrade;
    game.events.route = onRoute;
    this.#release = () => {
      if (game.events.hud === onHud) game.events.hud = hud;
      if (game.events.upgrade === onUpgrade) game.events.upgrade = upgrade;
      if (game.events.route === onRoute) game.events.route = route;
    };
  }
  private read(): HudSnapshot {
    const g = this.#game,
      p = g.player;
    return Object.freeze({
      state: g.state,
      godMode: g.godMode,
      book: g.book || "frost",
      player: Object.freeze({
        hp: p.hp,
        maxHp: p.maxHp,
        shield: p.shield,
        dash: p.dash,
        maxDash: p.maxDash,
        parryTime: p.parryTime,
        parryCooldown: p.parryCooldown,
        invuln: p.invuln,
      }),
      bookData: g.bookData || g.content.books.frost,
      mode: g.mode || g.content.modes.normal,
      target: g.target
        ? Object.freeze({
            word: g.target.word,
            meaning: g.target.meaning,
            dead: g.target.dead,
          })
        : null,
      boss: g.boss
        ? Object.freeze({
            hp: g.boss.hp,
            maxHp: g.boss.maxHp,
            phase: g.boss.phase,
            dead: g.boss.dead,
          })
        : null,
      relics: Object.freeze({ ...g.relics }),
      prefix: g.prefix || "",
      chapterName: g.chapterName,
      bossName: g.bossName,
      nextRoomIsBoss: g.nextRoomIsBoss,
      chapter: g.chapter || 0,
      roomNumber: g.roomNumber || 0,
      roomCount: g.roomCount,
      bossRoom: !!g.bossRoom,
      wave: g.wave || 1,
      assaultDirection: g.assaultDirection,
      waveCount: g.waveCount,
      spawned: g.spawned || 0,
      roomQuota: g.roomQuota || 0,
      elapsed: g.elapsed || 0,
      kills: g.kills || 0,
      combo: g.combo || 0,
      bookCounter: g.bookCounter || 0,
      level: g.level || 1,
      xp: g.xp || 0,
      nextXP: g.nextXP || 27,
      precisionTime: g.precisionTime || 0,
      resonance: g.resonance || 0,
      ultimateTime: g.ultimateTime || 0,
      rerolls: g.rerolls || 0,
      stage: g.stage || 0,
      loopCount: g.loopCount || 0,
    });
  }
  private publish() {
    const snapshot = this.read(),
      stamp = JSON.stringify(snapshot);
    if (stamp === this.#stamp) return;
    this.#snapshot = snapshot;
    this.#stamp = stamp;
    for (const listener of this.#listeners) listener();
  }
  getSnapshot = () => this.#snapshot;
  subscribe = (listener: () => void) => {
    this.#listeners.add(listener);
    return () => {
      this.#listeners.delete(listener);
    };
  };
  dispatch(command: GameCommand): boolean {
    if (this.#disposed) return false;
    const g = this.#game;
    let accepted = true;
    switch (command.type) {
      case "god-mode":
        g.activateGodMode();
        break;
      case "input":
        accepted = !!g.input(command.key);
        break;
      case "release":
        g.releaseKey(command.key);
        break;
      case "cycle":
        if (g.state !== "playing") return false;
        g.cycle(command.direction);
        break;
      case "pause":
        if (g.state !== "playing") return false;
        g.pause();
        break;
      case "resume":
        if (g.state !== "paused") return false;
        g.resume();
        break;
      case "home":
        g.home();
        break;
      case "quit":
        if (!["playing", "paused", "upgrade", "route"].includes(g.state))
          return false;
        g.end(false, "abandoned");
        break;
      case "continue":
        if (g.state !== "result" || !g.lastWin) return false;
        g.continueLoop();
        break;
      case "reroll":
        g.rerollUpgrade();
        break;
      case "upgrade":
        if (!this.#offer.has(command.id) || g.state !== "upgrade") return false;
        this.#offer.clear();
        g.chooseUpgrade(command.id);
        break;
      case "route": {
        const route = g.content.routes.find((r) => r.id === command.id);
        if (
          !route ||
          g.state !== "route" ||
          !g.routeOffers.some((offer) => offer.id === route.id)
        )
          return false;
        g.chooseRoute(route);
        break;
      }
    }
    this.publish();
    return accepted;
  }
  dispose() {
    if (this.#disposed) return;
    this.#disposed = true;
    this.#release();
    this.#listeners.clear();
    this.#offer.clear();
  }
  start(config: Config) {
    this.#offer.clear();
    this.#game.start(config);
    this.#game.sound.update(this.#game.player, this.#game.state, document.hidden);
    this.publish();
  }
  async prepare(stage?: (label: string) => void, book?: import('../contracts/game.ts').BookId) {
    await Promise.all([prepareBattle(this.#game, stage), this.#game.sound.prepare(book ?? 'ui')]);
  }
  applySettings(settings: Settings) {
    const g = this.#game;
    g.options = { ...settings, fx: Math.max(0.25, Number(settings.fx) || 0.3) };
    g.sound.enabled = settings.sound;
    g.sound.volume = Math.max(0, Math.min(1, Number(settings.volume) || 0));
    g.sound.music = settings.music;
    g.sound.sfxVolume = settings.sfxVolume ?? 1;
    g.invalidate();
    this.publish();
  }
  unlockAudio() {
    this.#game.sound.init();
  }
  setMenuScene(frame: import('../contracts/menu-scene.ts').MenuSceneFrame | null) {
    this.#game.menuScene = frame;
    this.#game.renderDirty = true;
  }
  playUISound(kind: import('../contracts/audio.ts').UISound) {
    this.#game.sound.ui(kind);
  }
  input(key: string) {
    return this.dispatch({ type: "input", key });
  }
  releaseKey(key: string) {
    this.dispatch({ type: "release", key });
  }
  cycle(direction = 1) {
    this.dispatch({ type: "cycle", direction });
  }
  pause() {
    this.dispatch({ type: "pause" });
  }
  resume() {
    this.dispatch({ type: "resume" });
  }
  home() {
    this.dispatch({ type: "home" });
  }
  end(_win: boolean) {
    this.dispatch({ type: "quit" });
  }
  continueLoop() {
    this.dispatch({ type: "continue" });
  }
  rerollUpgrade() {
    this.dispatch({ type: "reroll" });
  }
  chooseUpgrade(id: string) {
    this.dispatch({ type: "upgrade", id });
  }
  chooseRoute(id: string) {
    this.dispatch({ type: "route", id });
  }
}
