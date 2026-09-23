import type { Enemy, Point, SpellOptions } from '../../combat/model.ts';
import type { CarrierPage, LetterMote, SpellPayload, SpellRoot, WeaveSummary } from '../../contracts/combat-weave.ts';
import type { BookAbilityContext } from '../../content-sdk/BookBehavior.ts';
import type { Config, GameState } from '../../contracts/game.ts';
import type { SimulationContent } from '../../contracts/SimulationContent.ts';

export interface WeaveContext extends Pick<BookAbilityContext,
  'stats' | 'bookData' | 'player' | 'enemies' | 'nearest' | 'launchShot' | 'strike' |
  'applyBurn' | 'applyCold' | 'damage' | 'arc'> {
  readonly roomVisit: number;
  readonly roomEnded: boolean;
  readonly state: GameState;
  readonly config: Config;
  readonly content: SimulationContent;
  canEnemyAct(enemy: Enemy): boolean;
  burst(x: number, y: number, radius: number, color: string, kind?: string): void;
  ring(x: number, y: number, radius: number, color: string, life?: number): void;
}
interface HitReceipt extends Point {
  readonly payload: SpellPayload;
  readonly damage: number;
  readonly crystal: boolean;
  readonly heat: boolean;
  readonly conduction: boolean;
  readonly reserve: number;
  readonly target: number;
}

/** Explicit, synchronous rules. Only paid input can create supply or carriers. */
export class WeaveSystem {
  readonly pages: CarrierPage[] = [];
  readonly letters: LetterMote[] = [];
  private active?: SpellPayload;
  private sequence = 0;
  private pageSequence = 0;
  private supply: Record<string, number> = {};
  private pending?: { room: number; origin: Point; payload: SpellPayload; release: (target: Enemy) => void };
  heat = 0;
  private counts = { manualCharacters: 0, pagesCreated: 0, pagesReleased: 0, pagesBlocked: 0, fragments: 0, recoveredHeat: 0 };

  get summary(): WeaveSummary { return { ...this.counts }; }

  resetRoom() {
    this.pages.length = 0;
    this.letters.length = 0;
    this.pending = undefined;
    this.active = undefined;
  }
  reset() {
    this.resetRoom();
    this.sequence = this.pageSequence = this.heat = 0;
    this.supply = {};
    this.counts = { manualCharacters: 0, pagesCreated: 0, pagesReleased: 0, pagesBlocked: 0, fragments: 0, recoveredHeat: 0 };
  }
  capture(options: SpellOptions): SpellPayload | undefined {
    if (options.weave) return options.weave;
    if (!this.active) return undefined;
    return options.direct ? this.active : { ...this.active, source: 'derived', depth: this.active.depth + 1 };
  }
  private run(payload: SpellPayload, release: () => void) {
    const previous = this.active;
    this.active = payload;
    try { release(); } finally { this.active = previous; }
  }
  private fund(key: string, letters: number, cost: number, capacity = 3) {
    this.supply[key] = Math.min(cost * capacity, (this.supply[key] ?? 0) + letters);
  }
  private spend(key: string, cost: number) {
    if ((this.supply[key] ?? 0) < cost) return false;
    this.supply[key] -= cost;
    return true;
  }
  private nearest(ctx: WeaveContext, origin: Point, excluded = new Set<number>(), radius = Infinity) {
    let result: Enemy | undefined, best = radius * radius;
    for (const enemy of ctx.enemies) {
      if (!ctx.canEnemyAct(enemy) || excluded.has(enemy.id)) continue;
      const d = (enemy.x - origin.x) ** 2 + (enemy.y - origin.y) ** 2;
      if (d < best) { best = d; result = enemy; }
    }
    return result;
  }
  cast(ctx: WeaveContext, original: Enemy, damage: number, manualChars: number, release: (target: Enemy) => void) {
    const letters = Number.isFinite(manualChars) ? Math.max(0, Math.min(original.word.length, Math.floor(manualChars))) : 0;
    this.counts.manualCharacters += letters;
    const secondary = ctx.stats.secondaryBinding && !ctx.stats.singleFocus && ctx.config.secondaryBook !== ctx.config.book
      ? ctx.content.books[ctx.config.secondaryBook ?? '']?.combat?.element : undefined;
    const material = (key: string, enabled: boolean) => {
      if (!enabled) return false;
      this.fund(key, letters, 12);
      return this.spend(key, 12);
    };
    const secondaryReady = material('secondary', !!secondary);
    const heat = material('heat', !!ctx.stats.heatPayload) || (secondaryReady && secondary === 'fire');
    const conduction = material('conduction', !!ctx.stats.conductionPayload) || (secondaryReady && secondary === 'storm');
    const reserve = Math.min(this.heat, 10 + 20 * ctx.stats.heatRecovery);
    this.heat -= reserve;
    const root: SpellRoot = {
      id: ++this.sequence, room: ctx.roomVisit, remaining: 32, primaryClaimed: false,
      crystal: !!ctx.stats.crystalPayload || (secondaryReady && secondary === 'ice'),
      heat, conduction, reserve,
    };
    const payload: SpellPayload = { root, source: 'manual', depth: 0 };
    const recipient = !original.dead && ctx.canEnemyAct(original) ? original : this.nearest(ctx, original);
    if (recipient) this.run(payload, () => release(recipient));
    else this.pending = { room: ctx.roomVisit, origin: { x: original.x, y: original.y }, payload, release };
    if (ctx.roomEnded) return;

    const copy = ctx.stats.copyPages || (ctx.bookData.combat?.capabilities?.includes('carrier') ? 1 : 0);
    if (copy) {
      const cost = ctx.stats.swiftBinding ? 8 : 12;
      this.fund('copy', letters, cost);
      // Capacity limits spending too: cached input is used by the next manual cast.
      while (this.pages.length < this.capacity(ctx) && this.spend('copy', cost))
        this.createPages(ctx, damage, payload);
    }
    if (secondaryReady && secondary === 'paper' && this.pages.length < this.capacity(ctx))
      this.createPages(ctx, damage, payload);
  }
  private capacity(ctx: WeaveContext) {
    return ctx.stats.heavyPages ? 1 : ctx.stats.scatterPages ? 6 : ctx.stats.copyPages >= 2 ? 3 : 1;
  }
  private createPages(ctx: WeaveContext, damage: number, parent: SpellPayload) {
    const count = ctx.stats.scatterPages ? 2 : 1;
    const factor = ctx.stats.heavyPages ? .7 : ctx.stats.scatterPages ? .25 : .35;
    for (let i = 0; i < count && this.pages.length < this.capacity(ctx); i++) {
      if (parent.root.remaining <= 0) break;
      parent.root.remaining--;
      this.pages.push({ id: ++this.pageSequence, x: ctx.player.x, y: ctx.player.y,
        element: ctx.bookData.combat?.element ?? 'paper', damage: damage * factor,
        payload: { root: parent.root, source: 'carrier', depth: 1 },
        age: 0, life: ctx.stats.swiftBinding ? 1 : 5 });
      this.counts.pagesCreated++;
    }
    ctx.ring(ctx.player.x, ctx.player.y, 48, '#d8c7ff', .3);
  }
  update(ctx: WeaveContext, dt: number) {
    if (ctx.roomEnded || ctx.state !== 'playing') { if (ctx.roomEnded) this.resetRoom(); return; }
    this.updateLetters(ctx, dt);
    if (this.pending) {
      const pending = this.pending;
      if (pending.room !== ctx.roomVisit) this.pending = undefined;
      else {
        const target = this.nearest(ctx, pending.origin);
        if (target) { this.pending = undefined; this.run(pending.payload, () => pending.release(target)); }
      }
    }
    for (let i = this.pages.length - 1; i >= 0; i--) {
      const page = this.pages[i];
      page.age += dt;
      page.life -= dt;
      const angle = page.id * 2.4 + page.age * .8;
      page.x = ctx.player.x + Math.cos(angle) * (38 + page.id % 2 * 12);
      page.y = ctx.player.y - 10 + Math.sin(angle) * 27;
      if (page.payload.root.room !== ctx.roomVisit) { this.pages.splice(i, 1); continue; }
      const expired = page.life <= 0;
      const target = (expired || page.age >= 1.8) ? this.nearest(ctx, page) : undefined;
      if (expired || (page.age >= 1.8 && target)) {
        this.pages.splice(i, 1);
        if (!expired || ctx.stats.carrierRelease) this.releasePage(ctx, page, target);
      }
    }
  }
  /** Invoked only for a colliding ordinary enemy bullet, after dodge/parry checks. */
  block(ctx: WeaveContext): boolean {
    if (!ctx.stats.carrierGuard || !this.pages.length || ctx.roomEnded) return false;
    const page = this.pages.shift()!;
    this.counts.pagesBlocked++;
    ctx.burst(page.x, page.y, 42, '#d8c7ff', 'shard');
    if (ctx.stats.carrierRelease) this.releasePage(ctx, page, this.nearest(ctx, page));
    return true;
  }
  private releasePage(ctx: WeaveContext, page: CarrierPage, target?: Enemy) {
    if (!target || page.payload.root.room !== ctx.roomVisit || page.payload.root.remaining <= 0) return;
    this.counts.pagesReleased++;
    if (page.element === 'storm') {
      ctx.arc(page, target, '#ffe2a6', 3, .3);
      ctx.strike(target, page.damage, { kind: page.element, direct: false, from: page, weave: page.payload, depth: 1 });
    } else ctx.launchShot(page, target, page.element, page.damage, { direct: false, weave: page.payload, depth: 1 });
  }
  beforeHit(ctx: WeaveContext, enemy: Enemy, damage: number, opts: SpellOptions): HitReceipt | undefined {
    const payload = opts.weave;
    if (!payload) return undefined;
    const root = payload.root;
    if (root.room !== ctx.roomVisit || root.remaining <= 0 || payload.depth > 6) return undefined;
    root.remaining--;
    const primary = payload.source === 'manual' && !root.primaryClaimed;
    if (primary) root.primaryClaimed = true;
    const crystal = !!primary && (root.crystal || opts.kind === 'ice');
    const heat = !!primary && (root.heat || opts.kind === 'fire');
    if (primary && root.crystal) ctx.applyCold(enemy, 30);
    if (primary && root.heat) ctx.applyBurn(enemy, 1, 0);
    if (primary && enemy.burn && ctx.stats.heatRecovery) {
      // Native and attached burn have already been installed before the damage commit.
      const burn = enemy.burn;
      burn.recoverable = burn.damage * (opts.empowered ? 2 : 1) * Math.max(0, Math.floor((burn.life - burn.tick + 1e-8) / .5) + 1);
    }
    return { x: enemy.x, y: enemy.y, target: enemy.id, payload, damage,
      crystal, heat, conduction: !!primary && root.conduction, reserve: primary ? root.reserve : 0 };
  }
  accepts(ctx: WeaveContext, payload?: SpellPayload) {
    return !payload || (payload.root.room === ctx.roomVisit && payload.root.remaining > 0 && payload.depth <= 6);
  }
  afterHit(ctx: WeaveContext, receipt?: HitReceipt) {
    if (!receipt || ctx.roomEnded) return;
    const { payload, damage } = receipt;
    const root = payload.root;
    const excluded = new Set([receipt.target]);
    if (receipt.reserve > 0) {
      const original = ctx.enemies.find(e => e.id === receipt.target && !e.dead);
      const target = original ?? this.nearest(ctx, receipt);
      if (target) ctx.damage(target, receipt.reserve, 1, false, receipt);
      else this.heat = Math.min(20 + 40 * ctx.stats.heatRecovery, this.heat + receipt.reserve);
    }
    if (receipt.crystal && receipt.heat) {
      // Eligibility is on the hit receipt, so lethal primary damage cannot swallow it.
      for (let i = 0; i < 3; i++) {
        const target = this.nearest(ctx, receipt, excluded, 420);
        if (!target || root.remaining <= 0) break;
        excluded.add(target.id);
        ctx.launchShot(receipt, target, 'fire', damage * .15, {
          direct: false, depth: 1, weave: { root, source: 'fragment', depth: payload.depth + 1 },
        });
        this.counts.fragments++;
      }
    }
    if (receipt.conduction) {
      const seen = new Set([receipt.target]);
      let from: Point = receipt;
      for (let i = 0; i < 2; i++) {
        const target = this.nearest(ctx, from, seen, 340);
        if (!target || root.remaining <= 0) break;
        seen.add(target.id);
        ctx.arc(from, target, '#ffe2a6', 3.5, .32);
        ctx.strike(target, damage * .2, { kind: 'storm', from, direct: false, depth: 1,
          weave: { root, source: 'conduction', depth: payload.depth + 1 } });
        from = target;
      }
    }
  }
  recover(ctx: Pick<WeaveContext, 'stats'>, enemy: Enemy) {
    const burn = enemy.burn;
    if (!burn || !ctx.stats.heatRecovery || !burn.recoverable) return;
    const remaining = burn.damage * burn.stacks * Math.max(0, Math.floor((burn.life - burn.tick + 1e-8) / .5) + 1);
    const recovered = Math.min(remaining, burn.recoverable) * Math.min(.5, .2 + .15 * ctx.stats.heatRecovery);
    const before = this.heat;
    this.heat = Math.min(20 + 40 * ctx.stats.heatRecovery, this.heat + recovered);
    this.counts.recoveredHeat += this.heat - before;
    burn.recoverable = 0;
  }

  scatter(ctx: Pick<WeaveContext, 'stats' | 'enemies' | 'canEnemyAct'> & { fxRng(): number }, origin: Enemy, prefix: string) {
    if (!ctx.stats.letterScatter || !prefix) return;
    for (const letter of prefix) {
      if (!/[a-z]/.test(letter) || this.letters.length >= 72) continue;
      let recipient: Enemy | undefined, index = -1, best = Infinity;
      for (const enemy of ctx.enemies) {
        if (enemy === origin || !ctx.canEnemyAct(enemy)) continue;
        const slot = [...enemy.word].findIndex((c, i) => c === letter &&
          !(enemy.letterMarks?.word === enemy.word && enemy.letterMarks.positions.includes(i)) &&
          !this.letters.some(m => m.targetId === enemy.id && m.word === enemy.word && m.index === i));
        if (slot < 0) continue;
        const d = (enemy.x - origin.x) ** 2 + (enemy.y - origin.y) ** 2;
        if (d < best) { best = d; recipient = enemy; index = slot; }
      }
      if (!recipient) continue;
      const seed = ctx.fxRng() * Math.PI * 2;
      this.letters.push({ x: origin.x, y: origin.y - 30, start: { x: origin.x, y: origin.y - 30 },
        control: { x: origin.x + Math.cos(seed) * 140, y: origin.y - 30 + Math.sin(seed) * 140 },
        letter, targetId: recipient.id, word: recipient.word, index, age: 0, seed });
    }
  }
  private updateLetters(ctx: WeaveContext, dt: number) {
    for (let i = this.letters.length - 1; i >= 0; i--) {
      const mote = this.letters[i];
      const target = ctx.enemies.find(e => e.id === mote.targetId && !e.dead && e.word === mote.word);
      if (!target) { this.letters.splice(i, 1); continue; }
      mote.age += dt;
      const t = Math.min(1, mote.age / 1.15), u = 1 - t;
      const noise = Math.sin(Math.PI * t) * Math.sin(mote.seed + t * 5) * 13;
      mote.x = u * u * mote.start.x + 2 * u * t * mote.control.x + t * t * target.x + noise;
      mote.y = u * u * mote.start.y + 2 * u * t * mote.control.y + t * t * (target.y - 30) - noise;
      if (t === 1) {
        if (target.letterMarks?.word !== target.word) target.letterMarks = { word: target.word, positions: [] };
        if (!target.letterMarks!.positions.includes(mote.index)) target.letterMarks!.positions.push(mote.index);
        this.letters.splice(i, 1);
      }
    }
  }
  letterMultiplier(target: Enemy, manualChars: number) {
    const marks = target.letterMarks;
    if (!marks || marks.word !== target.word) return 1;
    const count = marks.positions.filter(index => index < manualChars).length;
    target.letterMarks = undefined;
    return 1 + count * .15;
  }
}
