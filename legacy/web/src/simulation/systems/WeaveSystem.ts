import type { Enemy, Point, SpellOptions } from '../../combat/model.ts';
import type { CarrierPage, LetterMote, SpellPayload, SpellRoot, WeaveSummary } from '../../contracts/combat-weave.ts';
import type { BookAbilityContext } from '../../content-sdk/BookBehavior.ts';
import type { Config, GameState } from '../../contracts/game.ts';
import type { SimulationContent } from '../../contracts/SimulationContent.ts';
import { compileBuild } from '../../shared/combat-build.ts';
import { createPacket, splitPacket, claim, claimCarrier, resources } from '../spells/packets.ts';
import type { BuildProgram, SpellElement, SpellPacket } from '../../contracts/combat-weave.ts';
import type { BuildTrace, BuildTraceEntry } from '../../contracts/build-trace.ts';
import type { BurnContribution } from '../../contracts/spell-packets.ts';

export interface WeaveContext extends Pick<BookAbilityContext,
  'stats' | 'bookData' | 'player' | 'enemies' | 'nearest' | 'launchShot' | 'strike' |
  'applyBurn' | 'applyCold' | 'damage' | 'arc' | 'spirits'> {
  readonly roomVisit: number;
  readonly roomEnded: boolean;
  readonly state: GameState;
  readonly config: Config;
  readonly content: SimulationContent;
  readonly buildSourceIds?: readonly string[];
  canEnemyAct(enemy: Enemy): boolean;
  burst(x: number, y: number, radius: number, color: string, kind?: string): void;
  ring(x: number, y: number, radius: number, color: string, life?: number): void;
}
interface HitReceipt extends Point {
  readonly payload: SpellPayload;
  readonly damage: number;
  readonly fragments: readonly SpellPacket[];
  readonly conduction: readonly SpellPacket[];
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
  private program?: BuildProgram;
  private programKey = '';
  private buildRoom = 0;
  private lastManualTarget?: { room: number; enemy: Enemy };
  private markPowerReady = 0;
  private markPowerNext = 0;
  private pending?: { room: number; origin: Point; payload: SpellPayload; release: (target: Enemy) => void; life: number };
  heat = 0;
  private counts = { manualCharacters: 0, pagesCreated: 0, pagesReleased: 0, pagesBlocked: 0, fragments: 0, recoveredHeat: 0, rejectedPages: 0, rejectedBurn: 0, lostPower: 0, lostHeat: 0, lostMaterial: 0, lostSupply: 0, lostBurn: 0 };
  private traceEntries: BuildTraceEntry[] = [];
  private traceSequence = 0;
  private traceOmitted = 0;

  get summary(): WeaveSummary { return { ...this.counts }; }
  get trace(): BuildTrace { return Object.freeze({ entries: Object.freeze(this.traceEntries.slice()), omitted: this.traceOmitted }); }
  private record(kind: BuildTraceEntry['kind'], reason: string, power = 0, heat = 0,
    packet?: SpellPacket, origin?: Pick<BuildTraceEntry, 'room' | 'rootId' | 'packetId' | 'sourceIds'>) {
    const entry: BuildTraceEntry = Object.freeze({ sequence: ++this.traceSequence,
      room: origin?.room ?? packet?.room ?? this.buildRoom,
      rootId: origin?.rootId ?? packet?.rootId ?? null,
      packetId: origin?.packetId ?? packet?.id ?? null,
      kind, power, heat,
      sourceIds: Object.freeze([...(origin?.sourceIds ?? packet?.root.sourceIds ?? [])]), reason });
    if (this.traceEntries.length === 128) { this.traceEntries.shift(); this.traceOmitted++; }
    this.traceEntries.push(entry);
  }
  private burnOrigin(contribution: BurnContribution) {
    return { room: this.buildRoom, rootId: contribution.rootId,
      packetId: contribution.packetId, sourceIds: contribution.sourceIds ?? [] };
  }

  resetRoom() {
    for (const page of this.pages) this.finishPage(page, 'clear');
    this.pages.length = 0;
    this.letters.length = 0;
    if (this.pending) {
      this.record('loss', 'room-clear-pending', this.pending.payload.resources.power, 0, this.pending.payload);
      this.counts.lostPower += this.pending.payload.resources.power;
      const r = this.pending.payload.resources;
      this.counts.lostMaterial += r.cold + r.heat + r.charge + r.copy;
      this.pending.payload.spent = true;
    }
    this.pending = undefined;
    const lostSupply = Object.values(this.supply).reduce((sum, amount) => sum + amount, 0);
    this.counts.lostSupply += lostSupply;
    if (lostSupply > 0) this.record('loss', 'room-clear-supply', 0, 0);
    this.supply = {};
    this.active = undefined;
    this.lastManualTarget = undefined;
    this.markPowerReady = this.markPowerNext = 0;
    if (!this.program?.reservePersist) {
      if (this.heat > 0) this.record('loss', 'room-clear-heat', 0, this.heat);
      this.counts.lostHeat += this.heat; this.heat = 0;
    }
  }
  reset() {
    this.resetRoom();
    this.sequence = this.pageSequence = this.heat = 0;
    this.supply = {};
    this.program = undefined; this.programKey = ''; this.buildRoom = 0;
    this.counts = { manualCharacters: 0, pagesCreated: 0, pagesReleased: 0, pagesBlocked: 0, fragments: 0, recoveredHeat: 0, rejectedPages: 0, rejectedBurn: 0, lostPower: 0, lostHeat: 0, lostMaterial: 0, lostSupply: 0, lostBurn: 0 };
    this.traceEntries = []; this.traceSequence = this.traceOmitted = 0;
  }
  capture(options: SpellOptions): SpellPayload | undefined {
    if (options.weave) return options.weave;
    if (!this.active) return undefined;
    return options.direct ? this.active : undefined;
  }
  reserveHits(packet: SpellPacket | undefined, count: number) {
    if (!packet || packet.spent) return;
    const required = Math.max(packet.hitBudget, Math.floor(count));
    const additional = required - packet.hitBudget;
    packet.hitBudget = required;
    packet.root.executionLimit += additional;
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
  private build(ctx: WeaveContext): BuildProgram {
    const secondary = ctx.stats.secondaryBinding && !ctx.stats.singleFocus && ctx.config.secondaryBook !== ctx.config.book
      ? ctx.content.books[ctx.config.secondaryBook ?? '']?.combat?.element : undefined;
    const element = (ctx.bookData.combat?.element ?? 'paper') as SpellElement;
    const key = JSON.stringify([ctx.stats, element, secondary, ctx.bookData.combat?.nativeChain]);
    if (key !== this.programKey || !this.program) {
      this.program = compileBuild({ stats: ctx.stats, element, secondary, nativeChain: ctx.bookData.combat?.nativeChain });
      this.programKey = key;
    }
    return this.program;
  }
  /** Refresh the current build while preserving the snapshot on every paid packet. */
  syncBuild(ctx: WeaveContext): void {
    const program = this.build(ctx);
    if (this.buildRoom && this.buildRoom !== ctx.roomVisit && !program.reservePersist) {
      if (this.heat > 0) this.record('loss', 'room-change-heat', 0, this.heat);
      this.counts.lostHeat += this.heat;
      this.heat = 0;
    }
    this.buildRoom = ctx.roomVisit;
    if (this.heat > program.recoveryCapacity) {
      this.record('loss', 'capacity-shrink-heat', 0, this.heat - program.recoveryCapacity);
      this.counts.lostHeat += this.heat - program.recoveryCapacity;
      this.heat = program.recoveryCapacity;
    }
  }
  private bank(program: BuildProgram, amount: number, reason = 'reserve-bank', packet?: SpellPacket,
    origin?: Pick<BuildTraceEntry, 'room' | 'rootId' | 'packetId' | 'sourceIds'>) {
    if (amount <= 0) return;
    const accepted = Math.min(amount, Math.max(0, program.recoveryCapacity - this.heat));
    this.heat += accepted;
    this.counts.recoveredHeat += accepted;
    this.counts.lostHeat += amount - accepted;
    if (accepted > 0) this.record('recover', reason, 0, accepted, packet, origin);
    if (amount > accepted) this.record('loss', 'bank-capacity', 0, amount - accepted, packet, origin);
  }
  recordRejectedBurn(amount: number, source?: SpellPacket) {
    this.counts.rejectedBurn += Math.max(0, amount);
    if (amount > 0) this.record('loss', 'burn-capacity', 0, 0, source);
  }
  settleExpiredBurn(ctx: Pick<WeaveContext, 'stats'>, balance: number, recoverable: boolean, rate: number,
    contribution?: BurnContribution) {
    if (balance <= 0) return;
    const recovered = recoverable ? balance * Math.max(0, Math.min(1, rate)) : 0;
    this.counts.lostBurn += balance - recovered;
    const origin = contribution ? this.burnOrigin(contribution) : undefined;
    if (balance > recovered) this.record('loss', 'burn-expired', balance - recovered, 0, undefined, origin);
    if (recovered > 0) this.bank(this.program ?? compileBuild({ stats: ctx.stats, element: 'paper' }),
      recovered, 'burn-expired-recovery', undefined, origin);
  }
  private extract(ctx: WeaveContext, program: BuildProgram) {
    const last = this.lastManualTarget;
    if (!program.recoveryExtract || !last || last.room !== ctx.roomVisit || last.enemy.dead || !last.enemy.burn) return;
    const burn = last.enemy.burn;
    for (const contribution of burn.contributions ?? []) {
      if (!contribution.recoverable || contribution.balance <= 0) continue;
      const gross = contribution.balance * .35;
      contribution.balance -= gross;
      const recovered = gross * contribution.recoveryRate;
      this.counts.lostBurn += gross - recovered;
      const origin = this.burnOrigin(contribution);
      if (gross > recovered) this.record('loss', 'burn-extraction-discount', gross - recovered, 0, undefined, origin);
      this.bank(program, recovered, 'burn-extracted', undefined, origin);
    }
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
    this.syncBuild(ctx);
    const program = this.program!;
    const secondary = program.secondary;
    const markPower = this.markPowerReady;
    this.markPowerReady = this.markPowerNext;
    this.markPowerNext = 0;
    const material = (key: string, level: number) => {
      const count = Math.max(0, Math.floor(level));
      if (!count) return 0;
      this.fund(key, letters * program.materialRate * count, 12);
      let received = 0;
      while (received < count && this.spend(key, 12)) received++;
      return received;
    };
    const secondaryReady = material('secondary', secondary ? 1 : 0);
    const cold = material('cold', ctx.stats.crystalPayload) + (secondaryReady && secondary === 'ice' ? 1 : 0);
    const heat = material('heat', ctx.stats.heatPayload) + (secondaryReady && secondary === 'fire' ? 1 : 0);
    const conduction = material('conduction', ctx.stats.conductionPayload) + (secondaryReady && secondary === 'storm' ? 1 : 0);
    const crystal = material('crystalStorage', ctx.stats.crystalStorage);
    const reserve = this.heat >= program.reserveThreshold ? Math.min(this.heat, 10 + 20 * ctx.stats.heatRecovery) : 0;
    this.heat -= reserve;
    // Extraction happens after this cast's reserve claim; it becomes usable next word.
    this.extract(ctx, program);
    const free = Math.max(0, program.carrierCapacity - this.pages.length);
    const mergeRoom = this.compatible(program) ? 4 - this.compatible(program)!.payloads.length : 0;
    const copySlots = Math.max(0, Math.min(free + mergeRoom, Math.floor(program.copyRate)));
    if (program.copyRate > 0) this.fund('copy', letters * program.copyRate, program.copyCost, 8);
    let copies = 0;
    while (copies < copySlots && this.spend('copy', program.copyCost)) copies++;
    const fragmentEligible = cold && heat;
    const fragmentCount = fragmentEligible ? program.fragmentCount : 0;
    const chainCount = conduction ? program.chainCount : 0;
    const root: SpellRoot = {
      id: ++this.sequence, room: ctx.roomVisit, manualCharacters: letters, basePower: Math.max(0, damage),
      sourceIds: Object.freeze([...(ctx.buildSourceIds ?? [])]),
      executionLimit: Math.max(1, 2 + program.blueprint.nativeSegments + program.payloadPierce +
        copies * (3 + program.payloadPierce + fragmentCount + chainCount) + fragmentCount + chainCount), executions: 0,
    };
    const balance = resources(Math.max(0, damage * program.spellPower));
    balance.cold = cold; balance.heat = heat; balance.charge = conduction;
    balance.copy = copies;
    const payload = createPacket(root, program, 'manual', balance, 'manual');
    this.record('cast', 'manual-characters', balance.power, reserve, payload);
    payload.reserve = reserve;
    const copyMultiplier = Math.max(0, 1 + ctx.stats.copyEfficiency + program.reactionEfficiency);
    const pagePower = damage * program.spellPower *
      (ctx.stats.heavyPages ? .7 : ctx.stats.scatterPages ? .25 : .35) *
      copyMultiplier;
    for (let i = 0; i < copies; i++) this.createPage(ctx, program, pagePower + (i === 0 ? markPower * copyMultiplier : 0), payload);
    if (!copies && markPower > 0) this.createPage(ctx, program, markPower * copyMultiplier, payload, true);
    for (let i = 0; i < crystal; i++) this.createCrystal(ctx, program, payload);
    const recipient = !original.dead && ctx.canEnemyAct(original) ? original : this.nearest(ctx, original);
    if (recipient) this.run(payload, () => release(recipient));
    else {
      if (this.pending) this.miss(this.pending.payload, ctx.roomVisit, 'pending-overwritten');
      payload.remainingLife = 4;
      this.pending = { room: ctx.roomVisit, origin: { x: original.x, y: original.y }, payload, release, life: 4 };
    }
  }
  private compatible(program: BuildProgram) {
    if (!program.mergePayload) return undefined;
    return this.pages.find(page => !page.exit && page.transportedBy === undefined && page.payloads.length < 4 &&
      page.element === program.blueprint.element && page.payload.blueprint.shape === program.blueprint.shape &&
      page.payload.program.carrierGuard === program.carrierGuard &&
      page.payload.program.carrierRelease === program.carrierRelease &&
      page.payload.program.thermalRelease === program.thermalRelease &&
      page.payload.program.carrierRetain === program.carrierRetain &&
      page.payload.program.summonTransport === program.summonTransport);
  }
  private canStore(program: BuildProgram) {
    return this.pages.length < program.carrierCapacity || !!this.compatible(program);
  }
  private divide(parent: SpellPacket, fraction: number, source: SpellPacket['source'], owner: string) {
    const raw = parent.resources.power * Math.min(1, fraction);
    const retention = parent.history.has('processing:applied') ? 1 : parent.program.processingRetention;
    const packet = splitPacket(parent, fraction, source, owner, parent.program.reactionEfficiency);
    if (packet) {
      const loss = raw * (1 - retention);
      if (loss > 0) {
        this.counts.lostPower += loss;
        this.record('loss', 'processing-loss', loss, 0, packet);
      }
    }
    return packet;
  }
  private registerPage(ctx: WeaveContext, packet: SpellPacket) {
    const merged = this.compatible(packet.program);
    let payloads = [packet], x = ctx.player.x, y = ctx.player.y, life = packet.program.carrierLife;
    if (merged) {
      this.pages.splice(this.pages.indexOf(merged), 1);
      claimCarrier(merged, 'clear');
      payloads = [...merged.payloads, packet];
      this.record('store', 'merge-payload', packet.resources.power, 0, packet);
      x = merged.x; y = merged.y; life = Math.max(life, merged.life);
    }
    const id = ++this.pageSequence;
    for (const part of payloads) part.owner = `page:${id}`;
    const power = payloads.reduce((sum, part) => sum + part.resources.power, 0);
    this.pages.push({ id, x, y, element: packet.blueprint.element, damage: power,
      payload: packet, payloads, guardBalance: power * .4, age: 0, life });
    this.counts.pagesCreated++;
    this.record('store', 'carrier-page', packet.resources.power, 0, packet);
    ctx.ring(x, y, 48, '#d8c7ff', .3);
  }
  private createPage(ctx: WeaveContext, program: BuildProgram, power: number, parent: SpellPacket, paidByMark = false) {
    if (!this.canStore(program) || power <= 0 || (!paidByMark && parent.resources.copy < 1)) {
      this.counts.rejectedPages++; this.counts.lostPower += Math.max(0, power);
      this.record('loss', 'copy-capacity-or-supply', 0, 0, parent); return;
    }
    if (!paidByMark) parent.resources.copy--;
    const loss = power * (1 - program.processingRetention);
    const retainedPower = power - loss;
    const balance = resources(retainedPower);
    if (program.copyInheritance) {
      for (const key of ['cold', 'heat', 'charge'] as const) {
        balance[key] = parent.resources[key] / (1 + Math.max(1, program.carrierCapacity - this.pages.length));
        parent.resources[key] -= balance[key];
      }
    }
    const blueprint = program.copyInheritance ? program.blueprint : {
      ...program.blueprint,
      operations: program.blueprint.operations.filter(operation => operation !== 'split' && operation !== 'store'),
    };
    const packet = createPacket(parent.root, program, 'carrier', balance, `page:${this.pageSequence + 1}`, 1, blueprint);
    packet.history.add('processing:applied');
    if (loss > 0) {
      this.counts.lostPower += loss;
      this.record('loss', 'processing-loss', loss, 0, packet);
    }
    this.record('copy', paidByMark ? 'mark-funded-copy' : 'character-funded-copy', retainedPower, 0, packet);
    if (program.reactionEfficiency) packet.history.add(`reactionEfficiency:copy:${parent.id}`);
    this.registerPage(ctx, packet);
  }
  private createCrystal(ctx: WeaveContext, program: BuildProgram, parent: SpellPacket) {
    if (!this.canStore(program)) {
      this.counts.rejectedPages++; this.counts.lostMaterial++;
      this.record('loss', 'crystal-capacity', 0, 0, parent); return;
    }
    const packet = this.divide(parent, .25, 'carrier', `crystal:${this.pageSequence + 1}`);
    if (packet) { this.record('split', 'crystal-shell', packet.resources.power, 0, packet); this.registerPage(ctx, packet); }
  }
  private finishPage(page: CarrierPage, exit: 'expiry' | 'clear' | 'guard') {
    if (page.exit && page.exit !== exit && page.exit !== 'guard') return;
    const guarded = page.exit === 'guard';
    if (!page.exit) claimCarrier(page, exit);
    for (const packet of page.payloads) {
      if (packet.spent) continue;
      const power = packet.resources.power;
      if (!guarded && exit !== 'guard' && packet.program.paperRecovery && packet.source !== 'recovered')
        this.bank(this.program ?? packet.program, power * .2, 'paper-recovery', packet);
      else this.counts.lostPower += power;
      const lostPower = power * (!guarded && exit !== 'guard' && packet.program.paperRecovery && packet.source !== 'recovered' ? .8 : 1);
      if (lostPower < power) this.counts.lostPower += lostPower;
      if (lostPower > 0) this.record('loss', exit === 'clear' ? 'page-room-clear' :
        exit === 'guard' ? 'guard-balance-expired' : 'page-expired', lostPower, 0, packet);
      packet.resources.power = 0;
      this.counts.lostMaterial += packet.resources.cold + packet.resources.heat + packet.resources.charge + packet.resources.copy;
      packet.resources.cold = packet.resources.heat = packet.resources.charge = packet.resources.copy = 0;
      packet.spent = true;
    }
  }
  miss(packet?: SpellPacket, room?: number, reason = 'packet-miss') {
    if (!packet || packet.spent || packet.history.has('miss')) return;
    packet.history.add('miss');
    const remaining = packet.resources.power;
    packet.resources.power = 0;
    this.counts.lostMaterial += packet.resources.cold + packet.resources.heat + packet.resources.charge + packet.resources.copy;
    packet.resources.cold = packet.resources.heat = packet.resources.charge = packet.resources.copy = 0;
    packet.spent = true;
    if ((room === undefined || room === packet.room) && packet.program.missRecovery && packet.source !== 'recovered')
      this.bank(this.program ?? packet.program, remaining * .2, 'miss-recovery', packet);
    else this.counts.lostPower += remaining;
    const lostPower = remaining * ((room === undefined || room === packet.room) && packet.program.missRecovery && packet.source !== 'recovered' ? .8 : 1);
    if (lostPower < remaining) this.counts.lostPower += lostPower;
    if (lostPower > 0) this.record('loss', reason, lostPower, 0, packet);
  }
  assignTransport(spirit: Point & { i: number }, room: number): number | undefined {
    const page = this.pages.find(candidate => !candidate.exit && candidate.transportedBy === undefined &&
      candidate.payload.program.summonTransport && candidate.payload.room === room &&
      Math.hypot(candidate.x - spirit.x, candidate.y - spirit.y) <= 140);
    if (!page) return undefined;
    page.transportedBy = spirit.i;
    return page.id;
  }
  cancelTransport(pageId: number) {
    const page = this.pages.find(candidate => candidate.id === pageId);
    if (page) page.transportedBy = undefined;
  }
  releaseTransport(ctx: WeaveContext, pageId: number, target: Enemy) {
    const index = this.pages.findIndex(page => page.id === pageId && page.transportedBy !== undefined && !page.exit);
    if (index < 0) return;
    const page = this.pages.splice(index, 1)[0];
    if (claimCarrier(page, 'attack')) this.releasePage(ctx, page, target);
  }
  update(ctx: WeaveContext, dt: number) {
    if (ctx.roomEnded || ctx.state !== 'playing') { if (ctx.roomEnded) this.resetRoom(); return; }
    this.updateLetters(ctx, dt);
    if (this.pending) {
      const pending = this.pending;
      if (pending.room !== ctx.roomVisit) { this.miss(pending.payload, ctx.roomVisit, 'pending-room-change'); this.pending = undefined; }
      else {
        pending.life -= dt;
        pending.payload.remainingLife = pending.life;
        if (pending.life <= 0) { this.miss(pending.payload, ctx.roomVisit, 'pending-expired'); this.pending = undefined; }
        else {
          const target = this.nearest(ctx, pending.origin);
          if (target) { this.pending = undefined; this.run(pending.payload, () => pending.release(target)); }
        }
      }
    }
    for (let i = this.pages.length - 1; i >= 0; i--) {
      const page = this.pages[i];
      page.age += dt;
      page.life -= dt;
      const angle = page.id * 2.4 + page.age * .8;
      const carrier = page.transportedBy === undefined ? undefined : ctx.spirits.find(s => s.i === page.transportedBy);
      if (carrier) { page.x = carrier.x; page.y = carrier.y; }
      else {
        page.transportedBy = undefined;
        page.x = ctx.player.x + Math.cos(angle) * (38 + page.id % 2 * 12);
        page.y = ctx.player.y - 10 + Math.sin(angle) * 27;
      }
      if (page.payload.room !== ctx.roomVisit) { this.finishPage(page, 'clear'); this.pages.splice(i, 1); continue; }
      const expired = page.life <= 0;
      const thermal = page.payload.program.thermalRelease && page.payloads.some(p => p.resources.heat > 0) &&
        page.age >= page.payload.program.carrierDelay * .5;
      const attackAge = page.payload.program.carrierRetain
        ? Math.max(page.payload.program.carrierDelay, page.payload.program.carrierLife * .85)
        : page.payload.program.carrierDelay;
      const target = (expired || thermal || page.age >= attackAge) ? this.nearest(ctx, page) : undefined;
      if (expired || (!page.exit && page.transportedBy === undefined &&
        ((page.age >= attackAge && target) || (thermal && target)))) {
        this.pages.splice(i, 1);
        const exit = expired ? 'expiry' : thermal ? 'thermal' : 'attack';
        if (!page.exit && claimCarrier(page, exit)) {
          if (target && (!expired || page.payload.program.carrierRelease)) this.releasePage(ctx, page, target);
          else this.finishPage(page, 'expiry');
        } else this.finishPage(page, page.exit === 'guard' ? 'guard' : 'expiry');
      }
    }
  }
  /** Invoked only for a colliding ordinary enemy bullet, after dodge/parry checks. */
  block(ctx: WeaveContext): boolean {
    if (!this.pages.length || ctx.roomEnded) return false;
    const eligible = this.pages.filter(page => page.payload.program.carrierGuard &&
      (page.exit === undefined || page.exit === 'guard') && page.guardBalance > 0);
    if (!eligible.length) return false;
    const page = ctx.stats.guardNewest ? eligible[eligible.length - 1] : eligible[0];
    if (!page.exit && !claimCarrier(page, 'guard')) return false;
    const total = page.payloads.reduce((sum, packet) => sum + packet.resources.power, 0);
    const cost = Math.min(page.guardBalance, Math.max(1, page.damage * .2) * (1 - page.payload.program.guardEfficiency));
    for (const packet of page.payloads) {
      const paid = total > 0 ? cost * packet.resources.power / total : 0;
      packet.resources.power = Math.max(0, packet.resources.power - paid);
      if (paid > 0) this.record('guard', 'carrier-guard-paid', paid, 0, packet);
    }
    page.guardBalance = Math.max(0, page.guardBalance - cost);
    this.counts.pagesBlocked++;
    ctx.burst(page.x, page.y, 42, '#d8c7ff', 'shard');
    if (page.payload.program.carrierRelease) {
      this.pages.splice(this.pages.indexOf(page), 1);
      const target = this.nearest(ctx, page);
      if (target) this.releasePage(ctx, page, target);
      else this.finishPage(page, 'guard');
    } else if (page.guardBalance <= 1e-8) {
      this.pages.splice(this.pages.indexOf(page), 1);
      this.finishPage(page, 'guard');
    }
    return true;
  }
  private releasePage(ctx: WeaveContext, page: CarrierPage, target?: Enemy) {
    if (!target || page.payload.room !== ctx.roomVisit) return;
    this.counts.pagesReleased++;
    for (const packet of page.payloads) {
      if (!claim(packet, 'release') || packet.resources.power <= 0) continue;
      this.record('release', page.exit === 'guard' ? 'guard-residual-release' :
        page.exit === 'thermal' ? 'thermal-payload-release' : 'carrier-payload-release',
        packet.resources.power, 0, packet);
      const shape = packet.blueprint.shape;
      const damage = packet.resources.power;
      if (shape === 'chain') {
        ctx.arc(page, target, '#ffe2a6', 3, .3);
        ctx.strike(target, damage, { kind: packet.blueprint.element, direct: false, from: page, weave: packet, depth: 1 });
        if (!packet.hitsCommitted) this.miss(packet, ctx.roomVisit);
      } else if (shape === 'blade') {
        ctx.arc(page, target, '#e9d8ff', 5, .25);
        ctx.strike(target, damage, { kind: 'blade', direct: false, from: page, weave: packet, depth: 1 });
        if (!packet.hitsCommitted) this.miss(packet, ctx.roomVisit);
      } else ctx.launchShot(page, target, packet.blueprint.element, damage, {
        direct: false, weave: packet, depth: 1,
        pierce: shape === 'pierce' ? packet.program.payloadPierce + 1 : undefined,
      });
    }
  }
  beforeHit(ctx: WeaveContext, enemy: Enemy, damage: number, opts: SpellOptions): HitReceipt | undefined {
    const payload = opts.weave;
    if (!payload) return undefined;
    if (!this.accepts(ctx, payload) || !claim(payload, `hit:${enemy.id}`)) return undefined;
    const availablePower = payload.resources.power;
    if (payload.source === 'manual' && opts.direct) this.lastManualTarget = { room: ctx.roomVisit, enemy };
    const cold = payload.resources.cold;
    const heat = payload.resources.heat;
    const charge = payload.resources.charge;
    payload.resources.cold = payload.resources.heat = payload.resources.charge = 0;
    const fragments: SpellPacket[] = [];
    const conduction: SpellPacket[] = [];
    const fragmentCount = cold > 0 && heat > 0 ? payload.program.fragmentCount : 0;
    const chainCount = charge > 0 ? payload.program.chainCount + Math.max(0, Math.floor(charge) - 1) :
      payload.source === 'carrier' && payload.blueprint.shape === 'chain' ? payload.blueprint.nativeSegments - 1 : 0;
    const fragmentPool = fragmentCount ? payload.program.fragmentShare : 0;
    const chainPool = chainCount ? payload.program.chainShare * (1 - fragmentPool) : 0;
    for (let i = 0; i < fragmentCount; i++) {
      const fragment = this.divide(payload, fragmentPool / (fragmentCount * Math.max(.01, 1 - i * fragmentPool / fragmentCount)),
        'fragment', `fragment:${i}`);
      if (fragment) { fragments.push(fragment); this.record('split', 'fragment-allocation', fragment.resources.power, 0, fragment); }
    }
    for (let i = 0; i < chainCount; i++) {
      const packet = this.divide(payload, chainPool / (chainCount * Math.max(.01, 1 - fragmentPool - i * chainPool / chainCount)),
        'conduction', `chain:${i}`);
      if (packet) { conduction.push(packet); this.record('split', 'conduction-allocation', packet.resources.power, 0, packet); }
    }
    const reserve = payload.reserve;
    payload.reserve = 0;
    const remainingHits = Math.max(1, payload.hitBudget - payload.hitsCommitted);
    const committedPower = payload.resources.power / remainingHits;
    payload.resources.power -= committedPower;
    payload.hitsCommitted++;
    payload.lastHitPower = committedPower;
    this.record('hit', 'paid-payload', committedPower, 0, payload);
    if (cold > 0 && !enemy.dead) ctx.applyCold(enemy, 30 * cold);
    if (heat > 0 && !enemy.dead) ctx.applyBurn(enemy, Math.max(1, Math.floor(heat)), 0, payload);
    const denominator = opts.weavePowerAtLaunch ?? availablePower;
    const committedDamage = denominator > 0 ? damage * committedPower / denominator : 0;
    return { x: enemy.x, y: enemy.y, target: enemy.id, payload, damage: committedDamage,
      fragments, conduction, reserve };
  }
  accepts(ctx: WeaveContext, payload?: SpellPayload) {
    return !payload || (payload.room === ctx.roomVisit && !payload.spent && payload.depth <= 8 &&
      payload.hitsCommitted < payload.hitBudget);
  }
  afterHit(ctx: WeaveContext, receipt?: HitReceipt) {
    if (!receipt) return;
    const { payload } = receipt;
    const excluded = new Set([receipt.target]);
    if (receipt.reserve > 0) {
      const original = ctx.enemies.find(e => e.id === receipt.target && !e.dead);
      const target = original ?? this.nearest(ctx, receipt);
      if (target) ctx.damage(target, receipt.reserve, 1, false, receipt);
      else this.bank(payload.program, receipt.reserve, 'reserve-unused', payload);
    }
    if (receipt.fragments.length) {
      for (const fragment of receipt.fragments) {
        const target = this.nearest(ctx, receipt, excluded, 420) ??
          ctx.enemies.find(e => e.id === receipt.target && !e.dead);
        if (!target) { this.miss(fragment, ctx.roomVisit); continue; }
        excluded.add(target.id);
        ctx.launchShot(receipt, target, 'fire', fragment.resources.power, {
          direct: false, depth: fragment.depth, weave: fragment,
        });
        this.counts.fragments++;
      }
    }
    if (receipt.conduction.length) {
      const seen = new Set([receipt.target]);
      let from: Point = receipt;
      for (const packet of receipt.conduction) {
        const relay = payload.program.carrierRelay && this.pages.find(page => !page.exit &&
          page.transportedBy === undefined && page.payloads.length < 4 && page.payload.room === packet.room &&
          !page.payloads.some(part => part.history.has(`relay:${packet.rootId}`)) &&
          Math.hypot(page.x - from.x, page.y - from.y) <= payload.program.chainReach);
        if (relay) {
          relay.payloads[0].history.add(`relay:${packet.rootId}`);
          packet.history.add(`carrierRelay:${relay.id}`);
          packet.owner = `page:${relay.id}`;
          relay.payloads.push(packet);
          relay.damage += packet.resources.power;
          relay.guardBalance += packet.resources.power * .4;
          this.record('relay', 'conduction-to-carrier', packet.resources.power, 0, packet);
          from = relay;
          continue;
        }
        const target = this.nearest(ctx, from, seen, payload.program.chainReach) ??
          ctx.enemies.find(e => e.id === receipt.target && !e.dead);
        if (!target) { this.miss(packet, ctx.roomVisit); continue; }
        seen.add(target.id);
        ctx.arc(from, target, '#ffe2a6', 3.5, .32);
        ctx.strike(target, packet.resources.power, { kind: 'storm', from, direct: false, depth: packet.depth, weave: packet });
        from = target;
      }
    }
    if (payload.hitsCommitted >= payload.hitBudget) payload.spent = true;
  }
  recover(ctx: Pick<WeaveContext, 'stats'>, enemy: Enemy) {
    const burn = enemy.burn;
    if (!burn) return;
    const program = this.program ?? compileBuild({ stats: ctx.stats, element: 'paper' });
    for (const contribution of burn.contributions ?? []) {
      const gross = contribution.balance;
      contribution.balance = 0;
      if (gross <= 0) continue;
      const recovered = contribution.recoverable ? gross * contribution.recoveryRate : 0;
      const origin = this.burnOrigin(contribution);
      this.counts.lostBurn += gross - recovered;
      if (gross > recovered) this.record('loss', 'burn-death-discount', gross - recovered, 0, undefined, origin);
      this.bank(program, recovered, 'burn-death-recovery', undefined, origin);
    }
  }

  scatter(ctx: Pick<WeaveContext, 'stats' | 'enemies' | 'canEnemyAct'> & { fxRng(): number }, origin: Enemy, prefix: string) {
    if (!ctx.stats.letterScatter || !prefix) return;
    const assigned = new Map<number, number>();
    for (const letter of prefix) {
      if (!/[a-z]/.test(letter) || this.letters.length >= 72) continue;
      let recipient: Enemy | undefined, index = -1, best = Infinity, bestCoverage = Infinity;
      for (const enemy of ctx.enemies) {
        if (enemy === origin || !ctx.canEnemyAct(enemy)) continue;
        const slot = [...enemy.word].findIndex((c, i) => c === letter &&
          !(enemy.letterMarks?.word === enemy.word && enemy.letterMarks.positions.includes(i)) &&
          !this.letters.some(m => m.targetId === enemy.id && m.word === enemy.word && m.index === i));
        if (slot < 0) continue;
        const coverage = ctx.stats.markSpread ? (assigned.get(enemy.id) ?? 0) +
          (enemy.letterMarks?.word === enemy.word ? enemy.letterMarks.positions.length : 0) : 0;
        const d = (enemy.x - origin.x) ** 2 + (enemy.y - origin.y) ** 2;
        if (coverage < bestCoverage || (coverage === bestCoverage && d < best)) {
          bestCoverage = coverage; best = d; recipient = enemy; index = slot;
        }
      }
      if (!recipient) continue;
      assigned.set(recipient.id, (assigned.get(recipient.id) ?? 0) + 1);
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
  letterMultiplier(target: Enemy, manualChars: number, markCarrier = false, paidPower = 0) {
    const marks = target.letterMarks;
    if (!marks || marks.word !== target.word) return 1;
    const count = marks.positions.filter(index => index < manualChars).length;
    target.letterMarks = undefined;
    if (markCarrier) this.markPowerNext += Math.max(0, paidPower) * count * .075;
    return 1 + count * (markCarrier ? .075 : .15);
  }
}
