import { RESOURCE_SCALE } from '../../contracts/build-resources.ts';
import type { BuildDiagnostic, Decision } from '../../contracts/build-resources.ts';
import type { CompiledRuleProgram, CounterId, TargetPolicy } from '../../contracts/build-rules.ts';
import type { CompletedWordInput, NativeSpellDefinition, SpellReference } from '../../contracts/native-spells.ts';
import type { RuntimeDamageCommit, RuntimeReserveHandoff, RuntimeSpellRelay, RuntimeTransportAssembly, SpellObject } from '../../contracts/build-runtime.ts';
import type { SpellRuleTarget } from '../../contracts/build-execution.ts';
import type { Bullet, Enemy, Field, Point } from '../../combat/model.ts';
import type { CombatRuntime } from '../Runtime.ts';
import { createRuleCompiler } from '../../shared/build/compile.ts';
import { validateNativeSpell } from '../../shared/build/native.ts';
import { mergeCompatible } from '../../shared/build/spell-merge.ts';
import { compareRelayPaths, findRelayPaths } from '../../shared/build/spell-routing.ts';
import type { SpellRelayPath } from '../../shared/build/spell-routing.ts';
import { displayBoundary, playableLength } from '../../vocabulary/index.ts';
import { SpellResourceRuntime } from './SpellResourceRuntime.ts';
import { ManualSpellIncome } from './ManualSpellIncome.ts';
import { SpellRuleExecutor } from './SpellRuleExecutor.ts';
import { SpellLifecycle } from './SpellLifecycle.ts';
import { LetterOpportunities } from './LetterOpportunities.ts';

type Context = Pick<CombatRuntime, 'content' | 'book' | 'bookData' | 'roomVisit' | 'time' | 'enemies' | 'player'
  | 'stats' | 'combatValue' | 'launchShot' | 'damage' | 'impulse' | 'impact' | 'applyCold' | 'burst'
  | 'arc' | 'canEnemyAct' | 'wordFor' | 'focusId' | 'config' | 'relics' | 'buildEvents' | 'roomEnded' | 'target' | 'prefix'
  | 'spiritTime' | 'awakenedSpirits' | 'spirits'>;
interface CastFacts {
  readonly pattern: NativeSpellDefinition;
  readonly originalTargetId: number;
  readonly empowered: boolean;
  readonly critical: boolean;
  readonly counters: Readonly<Partial<Record<CounterId, number>>>;
}
const TICKS_PER_SECOND = 60;
const toQ = (value: number) => Math.floor(value * RESOURCE_SCALE);

/** Adapts the live combat world to paid objects. Projectile code never supplies damage again. */
export class NativeSpellBattle {
  private readonly ctx: Context;
  private compiler?: ReturnType<typeof createRuleCompiler> extends Decision<infer T> ? T : never;
  private readonly programs = new Map<string, CompiledRuleProgram>();
  private facts = new Map<string, CastFacts>();
  private seen = new Map<number, Set<number>>();
  private rootTargets = new Map<string, { all: Set<number>; automatic: Set<number> }>();
  private plainShapes = new Set<number>();
  private summonQueue: number[] = [];
  private paidSummonCapacity = 0;
  private diagnosticsLog: BuildDiagnostic[] = [];
  private current?: { runtime: SpellResourceRuntime; lifecycle: SpellLifecycle; income: ManualSpellIncome; letters: LetterOpportunities; lastManual?: number };
  private pendingReserves?: RuntimeReserveHandoff;
  private syntheticSequence = 0;
  private humanCount = 0;
  private incomePowerQ = 0;
  private committedPowerQ = 0;
  private clearing = false;
  private hitSequence = 0;
  private projectileIds = new WeakMap<Bullet, string>();
  private markedTargets = new Set<number>();
  private savedView: readonly { id: number; element: NativeSpellDefinition['element']; material: 'crystal' | 'paper';
    x: number; y: number; life: number; age: number }[] = [];
  private fieldView: readonly Readonly<Field>[] = [];

  constructor(ctx: Context) {
    this.ctx = ctx;
    const invalid = Object.values(ctx.content.books).flatMap(book => book.nativeSpell ? validateNativeSpell(book.id, book.nativeSpell) : []);
    if (invalid.length) throw new Error(invalid.map(error => `${error.definitionId}: ${error.message}`).join('; '));
    if (ctx.content.buildRules) {
      const compiler = createRuleCompiler(ctx.content.buildRules);
      if (!compiler.ok) throw new Error(compiler.errors.map(error => error.message).join('; '));
      this.compiler = compiler.value;
    }
  }
  get enabled(): boolean {
    if (!this.compiler || !this.ctx.bookData?.nativeSpell || !Object.hasOwn(this.ctx.content.buildRules!.books, this.ctx.book)) return false;
    // Until catalog migration, choose one complete cast owner. Never silently drop an old ability.
    const registry = this.ctx.content.buildRules!;
    if (Object.entries(this.ctx.relics ?? {}).some(([id, level]) => level > 0 && !Object.hasOwn(registry.relics, registry.legacyRelicIds?.[id] ?? id))
      || this.ctx.buildEvents.records.some(record => record.active)) return false;
    const roots = this.ctx.content.talents?.filter(node => node.root === this.ctx.book).map(node => node.id) ?? [];
    return (this.ctx.config?.talents ?? []).every(id => roots.includes(id) || Object.hasOwn(registry.talents, id));
  }
  get runtime(): SpellResourceRuntime | undefined { return this.current?.runtime; }
  get letterMotes() { return this.current?.letters.motes ?? []; }
  get savedPages() { return this.savedView; }
  get fields() { return this.fieldView; }
  get summonCapacity(): number { return this.paidSummonCapacity; }
  get diagnostics(): readonly BuildDiagnostic[] {
    return [...this.diagnosticsLog, ...(this.current?.lifecycle.diagnostics ?? [])];
  }
  get summary() { return { manualCharacters: this.humanCount, incomePower: this.incomePowerQ / RESOURCE_SCALE,
    committedPower: this.committedPowerQ / RESOURCE_SCALE }; }
  private get tick(): number { return Math.max(0, Math.floor(this.ctx.time * TICKS_PER_SECOND + 1e-7)); }

  reset(): void {
    this.projectileIds = new WeakMap();
    this.current = undefined; this.pendingReserves = undefined; this.facts.clear(); this.seen.clear(); this.rootTargets.clear(); this.plainShapes.clear();
    this.summonQueue = []; this.paidSummonCapacity = 0; this.savedView = []; this.fieldView = [];
    this.ctx.player.spellShield = 0;
    this.markedTargets.clear();
    this.diagnosticsLog = []; this.syntheticSequence = this.humanCount = this.incomePowerQ = this.committedPowerQ = 0;
  }
  clearRoom(): void {
    if (!this.current || this.clearing) return;
    this.clearing = true; this.projectileIds = new WeakMap();
    try { this.current.lifecycle.clearRoom(this.tick); }
    finally { this.clearing = false; }
    this.diagnosticsLog.push(...this.current.lifecycle.diagnostics);
    const program = this.enabled ? this.program() : this.current.lastManual === undefined ? undefined
      : this.current.runtime.getObject(this.current.lastManual)?.program;
    const retention = program?.numerics['reserve.archiveRetention'] ?? 0;
    if (retention > 0) this.record(this.current.runtime.archiveReserves(retention, program!.numerics['reserve.capacityQ']));
    const handoff = this.record(this.current.runtime.exportReserves());
    if (handoff && (handoff.resources.lots.length || handoff.cooldownManuals)) this.pendingReserves = handoff;
    // No object reference from this room can resolve after the next room is opened.
    this.current = undefined; this.facts.clear(); this.seen.clear(); this.rootTargets.clear(); this.plainShapes.clear();
    this.summonQueue = []; this.paidSummonCapacity = 0; this.savedView = []; this.fieldView = [];
    this.ctx.player.spellShield = 0;
    this.markedTargets.clear();
    for (const enemy of this.ctx.enemies ?? []) { enemy.nativeBurn = undefined; enemy.nativeLetterMarks = undefined; }
  }
  private room() {
    if (this.current?.runtime.room === this.ctx.roomVisit) return this.current;
    this.clearRoom();
    const runtime = new SpellResourceRuntime(this.ctx.roomVisit);
    if (this.pendingReserves) {
      // Keep the ticket if validation fails; never silently replace it with a fresh income.
      if (!this.record(runtime.importReserves(this.pendingReserves))) return;
      this.pendingReserves = undefined;
    }
    const income = new ManualSpellIncome(runtime);
    const letters = new LetterOpportunities(runtime, () => this.ctx.enemies.filter(enemy => !enemy.dead && !enemy.wordPending
      && enemy.wordRevision && this.ctx.canEnemyAct(enemy)).map(enemy => ({
        session: { targetId: enemy.id, revision: enemy.wordRevision!, word: enemy.word }, position: { x: enemy.x, y: enemy.y },
        entered: this.ctx.target === enemy ? playableLength(this.ctx.prefix) : 0 } )));
    const executor = new SpellRuleExecutor(runtime, {
      flightLifeTicks: 126, selectTarget: (object, policy, distance) => this.target(object, policy, distance),
      selectRelay: (object, policy, distance, cost, tick) => this.relay(object, policy, distance, cost, tick),
      targetsWithin: (position, radius) => this.ctx.enemies.filter(enemy => !enemy.dead && this.ctx.canEnemyAct(enemy)
        && Math.hypot(enemy.x - position.x, enemy.y - position.y) <= radius),
      supply: (context, operation) => income.supply(context, operation), mark: (context, operation) => letters.mark(context, operation),
    });
    const lifecycle = new SpellLifecycle(executor, {
      flightLifeTicks: 126, isAlive: id => !!this.enemy(id), target: (object, policy) => this.target(object, policy),
      prepareHit: (object, target, tick) => this.prepare(object, target, tick),
      fieldTargets: object => this.fieldTargets(object),
      afterAssembly: object => this.supplySummons(object),
      counters: object => ({ ...this.facts.get(object.rootReceiptId)?.counters,
        healthShare: this.ctx.player.hp / this.ctx.player.maxHp, targetCount: this.ctx.enemies.filter(enemy => !enemy.dead).length,
        reserveQ: runtime.reserveUsageQ() }),
      damage: commit => this.damage(commit), launch: (object, target, from, via) => this.launch(object, target, from, via),
      targetCommitted: (object, target) => { this.rememberTarget(object, target.id, false); },
      // The simulation checks room completion after all systems finish this substep.
      boundary: () => {},
    });
    return this.current = { runtime, lifecycle, income, letters };
  }
  private program(): CompiledRuleProgram {
    const registry = this.ctx.content.buildRules!;
    const allocated = (this.ctx.config?.talents ?? []).filter(id => Object.hasOwn(registry.talents, id)).sort();
    const assets = Object.entries(this.ctx.relics ?? {}).filter(([, level]) => level > 0).sort(([a], [b]) => a < b ? -1 : 1)
      .map(([id, level]) => ({ instanceId: id, definitionId: registry.legacyRelicIds?.[id] ?? id, level, state: 'owned' as const }));
    const key = JSON.stringify([this.ctx.book, allocated, assets]);
    let program = this.programs.get(key);
    if (!program) {
      const result = this.compiler!.compile({ version: 1, revision: 1, mainBook: this.ctx.book,
        allocated, selectedModes: {}, assets, overrides: [] });
      if (!result.ok) throw new Error(result.errors.map(error => error.message).join('; '));
      program = result.value; this.programs.clear(); this.programs.set(key, program);
    }
    return program;
  }
  private record<T>(result: Decision<T>): T | undefined {
    if (result.ok) return result.value;
    this.diagnosticsLog.push(...result.errors); return undefined;
  }

  cast(target: Enemy, basePower: number, empowered: boolean, critical: boolean, manualCharacters: number,
    input?: CompletedWordInput): void {
    if (this.ctx.roomEnded) return;
    const definition = this.ctx.bookData.nativeSpell!;
    const pattern = Object.freeze({ ...definition, hitCounts: Object.freeze([...definition.hitCounts]) as readonly [number, number],
      ...(definition.summon ? { summon: Object.freeze({ ...definition.summon }) } : {}) });
    const wordLength = playableLength(input?.word ?? target.word);
    const positions = input?.humanPositions ?? Array.from({ length: Math.max(0, Math.min(wordLength, Math.floor(manualCharacters))) }, (_, i) => i);
    // An automatic invocation without a completed human input cannot earn another cast/work receipt.
    if (!positions.length) return;
    const room = this.room();
    if (!room) return;
    const receiptId = input?.id ?? `engine-word:${++this.syntheticSequence}`;
    const { normal, empowered: boosted } = this.ctx.bookData.castMultiplier;
    const mean = (normal * (this.ctx.bookData.cycle - 1) + boosted) / this.ctx.bookData.cycle;
    const quality = basePower / this.ctx.combatValue('cast.word', { wordLength });
    const primaryMultiplier = quality * (empowered ? boosted : normal) / mean * (1 + this.ctx.stats.spellPower);
    const program = this.program();
    const counts = Math.max(1, Math.min(64, pattern.hitCounts[empowered ? 1 : 0]
      + (pattern.shape === 'chain' ? (program.numerics['routing.targets'] ?? 3) - 3 : 0)));
    const counters = { humanCharacters: positions.length, wordLength, matchedCharacters: 0, healthShare: this.ctx.player.hp / this.ctx.player.maxHp,
      targetCount: this.ctx.enemies.filter(enemy => !enemy.dead).length };
    const before = room.runtime.manualCount;
    const object = this.record(room.income.accept({ id: receiptId, wordLength, humanPositions: positions,
      wordSession: (input?.wordRevision ?? target.wordRevision) ? { targetId: input?.targetId ?? target.id,
        revision: input?.wordRevision ?? target.wordRevision!, word: input?.word ?? target.word } : undefined,
      primaryMultiplier, program, shape: pattern.shape,
      position: this.ctx.player, targetId: target.id, tick: this.tick, lifeTicks: 240, applications: counts, processingUses: 8 }, counters));
    if (!object || room.runtime.manualCount === before) return;
    const targetPowerRatio = Math.min(1_000_000, Math.max(0, target.hp)
      / Math.max(1 / RESOURCE_SCALE, room.runtime.balance(object.id, 'power') / RESOURCE_SCALE));
    this.humanCount += positions.length; this.incomePowerQ += room.runtime.balance(object.id, 'power');
    room.lastManual = object.id;
    let matchedCharacters = 0;
    if (room.runtime.active('letter').length && room.runtime.inputFor(object.id)?.session) {
      const redeemed = room.runtime.redeemLetters(object.id, this.tick);
      if (!redeemed.ok && redeemed.errors[0]?.code !== 'INSUFFICIENT_RESOURCE') this.record(redeemed);
      if (redeemed.ok) matchedCharacters = redeemed.value.matchedCount;
    }
    this.facts.set(receiptId, { pattern, originalTargetId: target.id, empowered, critical, counters: { ...counters, matchedCharacters, targetPowerRatio } });
    if (pattern.element === 'paper') { target.mark = 8; this.ctx.focusId = target.id; }
    room.lifecycle.start(object.id, this.tick, counters, matchedCharacters);
    this.projectLetters();
  }

  private supplySummons(object: SpellObject): void {
    const room = this.current, program = object.program;
    if (!room || !program.capabilities.includes('summon')) { this.paidSummonCapacity = 0; return; }
    const n = program.numerics, pattern = this.facts.get(object.rootReceiptId)!.pattern;
    this.paidSummonCapacity = n['summon.capacity'];
    this.summonQueue = this.summonQueue.filter(id => {
      const spell = room.runtime.getObject(id);
      return spell?.state === 'ready' && this.tick < spell.expiresAtTick;
    });
    const cost = Math.max(1, Math.ceil((pattern.summon ? pattern.summon.workCost * RESOURCE_SCALE : n['summon.workCostQ'])
      * n['copy.workCostQ'] / (4 * RESOURCE_SCALE) / n['summon.efficiency']));
    const factor = Math.min(1, (pattern.summon?.powerFactor ?? n['summon.powerFactor']) * n['copy.powerFactor'] / .22);
    const capacity = Math.min(pattern.summon?.capacity ?? n['summon.queueCapacity'], n['summon.queueCapacity']);
    let funded = 0;
    while (room.runtime.balance(0, 'work') >= cost && this.summonQueue.length < capacity) {
      const copied = this.record(room.runtime.copy(object.id, cost, factor, program.allocated.includes('T20') ? ['shape'] : []));
      if (!copied) break;
      this.summonQueue.push(copied.objects[0].id); funded++;
    }
    if (funded) {
      this.ctx.awakenedSpirits = Math.min(this.paidSummonCapacity, (this.ctx.spiritTime > 0 ? this.ctx.awakenedSpirits : 0) + 1);
      this.ctx.spiritTime = Math.min(18, this.ctx.spiritTime + n['summon.activeTicks'] / TICKS_PER_SECOND);
    }
  }

  interrupted(enemy: Enemy, humanPositions: readonly number[]): void {
    const room = this.current;
    if (!room || room.lastManual === undefined || !enemy.wordRevision || !humanPositions.length) return;
    const subject = room.runtime.getObject(room.lastManual)!;
    const result = room.lifecycle.executor.execute({ id: `interrupt:${enemy.id}:${enemy.wordRevision}`, subject,
      event: 'word.interrupted', stage: 'income', tick: this.tick, counters: this.facts.get(subject.rootReceiptId)?.counters ?? {},
      interrupted: { session: { targetId: enemy.id, revision: enemy.wordRevision, word: enemy.word }, humanPositions,
        position: { x: enemy.x, y: enemy.y } } });
    this.diagnosticsLog.push(...result.errors);
    room.letters.moveLost(); this.projectLetters();
  }

  absorbDamage(amount: number): number {
    const runtime = this.current?.runtime;
    if (!runtime || !Number.isFinite(amount) || amount <= 0) return 0;
    let remaining = toQ(amount), blocked = 0;
    for (const shell of runtime.active('shell').filter(object => object.letter?.reward === 'guard' && this.tick < object.expiresAtTick)) {
      if (!remaining) break;
      const result = this.record(runtime.guard(shell.id, `shield:${++this.hitSequence}`, remaining));
      if (!result) continue;
      remaining -= result.blockedPowerQ; blocked += result.blockedPowerQ;
      if (!runtime.balance(shell.id, 'power')) this.record(runtime.discard(shell.id));
    }
    this.projectLetters(); return blocked / RESOURCE_SCALE;
  }

  private projectLetters(): void {
    const room = this.current;
    if (!room) return;
    room.letters.update(this.tick);
    const bindings = room.letters.bindings();
    const enemies = bindings.length || this.markedTargets.size ? new Map(this.ctx.enemies.map(enemy => [enemy.id, enemy])) : undefined;
    for (const id of this.markedTargets) { const enemy = enemies?.get(id); if (enemy) enemy.nativeLetterMarks = undefined; }
    this.markedTargets.clear();
    for (const binding of bindings) {
      const enemy = enemies?.get(binding.session.targetId);
      if (!enemy || enemy.wordRevision !== binding.session.revision || enemy.word !== binding.session.word) continue;
      if (!enemy.nativeLetterMarks) enemy.nativeLetterMarks = { word: enemy.word, positions: [] };
      enemy.nativeLetterMarks.positions.push(displayBoundary(enemy.word, binding.position));
      this.markedTargets.add(enemy.id);
    }
    this.ctx.player.spellShield = room.runtime.active('shell').filter(object => object.letter?.reward === 'guard' && this.tick < object.expiresAtTick)
      .reduce((sum, object) => sum + room.runtime.balance(object.id, 'power'), 0) / RESOURCE_SCALE;
    this.savedView = room.runtime.active('shell').filter(object => object.state === 'stored' && this.tick < object.expiresAtTick && object.letter?.reward !== 'guard')
      .map((object, index) => {
        const angle = object.id * 2.399963229728653, radius = 38 + Math.sqrt(index) * 13;
        return { id: -object.id, element: this.facts.get(object.rootReceiptId)!.pattern.element,
          material: object.properties.material === 'crystal' ? 'crystal' as const : 'paper' as const,
          x: object.position.x + Math.cos(angle) * radius, y: object.position.y + Math.sin(angle) * radius,
          life: (object.expiresAtTick - this.tick) / TICKS_PER_SECOND, age: (this.tick - object.createdAtTick) / TICKS_PER_SECOND };
      });
  }
  intercept(bullet: Bullet, amount: number): number {
    if (!this.current || this.ctx.roomEnded || bullet.dead || bullet.heavy || bullet.reflected || !Number.isFinite(amount) || amount <= 0) return 0;
    let id = this.projectileIds.get(bullet);
    if (!id) { id = `bullet:${++this.hitSequence}`; this.projectileIds.set(bullet, id); }
    const blocked = Math.min(amount, this.current.lifecycle.intercept({ id,
      powerQ: Math.ceil(amount * RESOURCE_SCALE), reflectable: true }, this.tick) / RESOURCE_SCALE);
    if (blocked > 0) {
      this.ctx.burst(this.ctx.player.x, this.ctx.player.y, 42, '#d8c7ff', 'shard');
      this.projectLetters();
    }
    return blocked;
  }
  /** A visible spirit takes a paid attack before starting its dive, preserving its original room. */
  takeSummon(targetId: number, actorId: number, position: Point): { spell?: SpellReference; cargo?: SpellReference } | undefined {
    const runtime = this.current?.runtime;
    if (!runtime || !this.enemy(targetId)) return;
    while (this.summonQueue.length) {
      const id = this.summonQueue.shift()!, object = runtime.getObject(id);
      if (!object || object.state !== 'ready' || this.tick >= object.expiresAtTick) continue;
      const candidates = runtime.active('shell').filter(shell => shell.state === 'stored' && !shell.letter
        && this.tick < shell.expiresAtTick && shell.program.capabilities.includes('transport')
        && (shell.program.modes['transport.mode'] !== 'solo' || actorId === 0)
        && Math.hypot(shell.position.x - position.x, shell.position.y - position.y) <= shell.program.numerics['transport.pickupRadius'])
        .sort((a, b) => {
          const aSolo = a.program.modes['transport.mode'] === 'solo', bSolo = b.program.modes['transport.mode'] === 'solo';
          return Number(bSolo) - Number(aSolo) || (aSolo ? runtime.balance(b.id, 'power') - runtime.balance(a.id, 'power')
            : Math.hypot(a.position.x - position.x, a.position.y - position.y) - Math.hypot(b.position.x - position.x, b.position.y - position.y)) || a.id - b.id;
        });
      for (const shell of candidates) {
        const assembly = this.transportAssembly(shell, candidates);
        let taken = runtime.startTransport(shell.id, id, actorId, this.tick, shell.program.numerics['transport.retention'], assembly);
        if (!taken.ok && assembly && taken.errors.every(error => error.code === 'INSUFFICIENT_RESOURCE'))
          taken = runtime.startTransport(shell.id, id, actorId, this.tick, shell.program.numerics['transport.retention']);
        if (taken.ok) {
          this.projectLetters();
          return { cargo: { room: runtime.room, objectId: taken.value.objects[0].id } };
        }
        if (taken.errors.some(error => error.code !== 'INSUFFICIENT_RESOURCE')) this.record(taken);
      }
      const flight = this.record(runtime.dispatch(id, targetId, this.tick, 126));
      if (flight) return { spell: { room: runtime.room, objectId: id } };
    }
  }

  private transportAssembly(shell: SpellObject, candidates: readonly SpellObject[]): RuntimeTransportAssembly | undefined {
    if (shell.program.modes['transport.mode'] !== 'fleet') return;
    const runtime = this.current!.runtime, n = shell.program.numerics, waitTicks = n['merge.waitTicks'];
    const eligible = (candidate: SpellObject) => mergeCompatible(shell, candidate)
      && runtime.ledger.getOwnedLots(candidate.id).length > 0
      && runtime.ledger.getOwnedLots(candidate.id).every(lot => lot.remainingUses >= 2 && !lot.ruleClaims['native.transport.merge']);
    if (!eligible(shell)) return;
    const objectIds: number[] = [];
    let ready = Math.max(this.tick, shell.readyAtTick), expiry = shell.expiresAtTick;
    for (const candidate of [shell, ...candidates.filter(item => item.id !== shell.id)]) {
      if (!eligible(candidate)) continue;
      const nextReady = Math.max(ready, candidate.readyAtTick), nextExpiry = Math.min(expiry, candidate.expiresAtTick);
      if (nextReady + waitTicks >= nextExpiry) continue;
      objectIds.push(candidate.id); ready = nextReady; expiry = nextExpiry;
      if (objectIds.length >= n['transport.mergeInputs']) break;
    }
    return objectIds.length >= 2 && objectIds[0] === shell.id ? { objectIds, waitTicks } : undefined;
  }

  private cargo(reference: SpellReference, actorId: number): SpellObject | undefined {
    const object = reference.room === this.ctx.roomVisit ? this.current?.runtime.getObject(reference.objectId) : undefined;
    return object?.state === 'carried' && object.transport?.actorId === actorId && this.tick < object.expiresAtTick ? object : undefined;
  }
  /** False keeps the spirit at contact until the cargo's original preparation has finished. */
  deliverTransport(reference: SpellReference, actorId: number, enemy: Enemy, position: Point): boolean {
    const object = this.cargo(reference, actorId);
    if (!object) return true;
    if (object.transport?.returning || enemy.dead || this.tick < object.readyAtTick) return false;
    const result = this.record(this.current!.runtime.deliverTransport(object.id, actorId, enemy.id, this.tick, position));
    if (!result) { this.cancelTransport(reference); return true; }
    this.current!.lifecycle.deliverTransport(object.id, enemy, this.tick);
    return true;
  }
  returnTransport(reference: SpellReference, actorId: number): boolean {
    const object = this.cargo(reference, actorId);
    if (!object) return false;
    if (!object.transportReturned && object.program.numerics['transport.return'] > 0) {
      const result = this.current!.runtime.beginTransportReturn(object.id, actorId, this.tick);
      if (result.ok) return true;
      this.record(result);
    }
    this.cancelTransport(reference); return false;
  }
  finishTransportReturn(reference: SpellReference, actorId: number, position: Point): void {
    const object = this.cargo(reference, actorId);
    if (!object) return;
    const n = object.program.numerics;
    const result = this.current!.runtime.returnTransport(object.id, actorId, this.tick, n['storage.capacity'],
      n['transport.returnRetention'], n['transport.returnWaitTicks'], position);
    if (!result.ok) {
      if (result.errors.some(error => !['RESOURCE_LIMIT', 'INSUFFICIENT_RESOURCE', 'STALE_RESOURCE_OWNER'].includes(error.code))) this.record(result);
      this.cancelTransport(reference);
    }
    this.projectLetters();
  }
  cancelTransport(reference?: SpellReference): void {
    if (reference?.room === this.ctx.roomVisit && this.current?.runtime.getObject(reference.objectId)?.state === 'carried')
      this.current.lifecycle.expire(reference.objectId, this.tick, 'miss');
  }
  accepts(reference: SpellReference): boolean {
    const object = reference.room === this.ctx.roomVisit && this.current?.runtime.getObject(reference.objectId);
    return !!object && object.state === 'flight';
  }
  hit(reference: SpellReference, enemy: Enemy, from: Point): void {
    if (!this.accepts(reference) || enemy.dead) return;
    const room = this.current!, object = room.runtime.getObject(reference.objectId)!;
    if (this.tick < object.readyAtTick || this.tick >= object.expiresAtTick || object.remainingApplications < 1) return;
    const seen = this.seen.get(object.id) ?? new Set<number>();
    if (seen.has(enemy.id)) return;
    seen.add(enemy.id); this.seen.set(object.id, seen);
    this.rememberTarget(object, enemy.id, true);
    const facts = this.facts.get(object.rootReceiptId)!;
    const count = object.remainingApplications, retention = object.shape === 'chain'
      ? object.program.numerics['routing.hitRetention'] ?? .78 : facts.pattern.hitRetention;
    let weight = 0;
    for (let i = 0; i < count; i++) weight += retention ** i;
    room.lifecycle.hit(object.id, enemy.id, this.tick, facts.counters, enemy, 1 / weight);
    this.projectFields();
    this.ctx.impulse(enemy, from, facts.pattern.element === 'ice' ? facts.empowered ? 530 : 300 : 150);
    this.ctx.impact(enemy.x, enemy.y, facts.pattern.element, facts.empowered || facts.critical ? 1.7 : 1, from);
  }
  miss(reference?: SpellReference): void {
    if (reference && this.accepts(reference)) this.current!.lifecycle.expire(reference.objectId, this.tick, 'miss');
  }
  advance(): void {
    if (!this.current) return;
    if (this.ctx.roomEnded) { this.clearRoom(); return; }
    this.current.lifecycle.advance(this.tick);
    this.current.letters.moveLost(); this.projectLetters();
    this.projectFields();
    const burns = new Map<number, { life: number; stacks: number }>();
    for (const status of this.current.runtime.active('status')) {
      if (status.targetId === undefined || status.properties.material !== 'heat') continue;
      const previous = burns.get(status.targetId);
      burns.set(status.targetId, { life: Math.max(previous?.life ?? 0, (status.expiresAtTick - this.tick) / TICKS_PER_SECOND),
        stacks: (previous?.stacks ?? 0) + 1 });
    }
    for (const enemy of this.ctx.enemies) enemy.nativeBurn = burns.get(enemy.id);
  }
  private enemy(id: number): Enemy | undefined { return this.ctx.enemies.find(enemy => enemy.id === id && !enemy.dead); }
  private rememberTarget(object: SpellObject, targetId: number, hit: boolean): void {
    const history = this.rootTargets.get(object.rootReceiptId) ?? { all: new Set<number>(), automatic: new Set<number>() };
    if (hit) history.all.add(targetId);
    if (object.derived || object.targetPolicy !== 'original') history.automatic.add(targetId);
    this.rootTargets.set(object.rootReceiptId, history);
  }
  private target(object: SpellObject, policy: TargetPolicy, maxDistance = Infinity, allowed?: ReadonlySet<number>): SpellRuleTarget | undefined {
    const seen = this.seen.get(object.id);
    const automatic = object.derived || policy !== 'original', numerics = object.program.numerics;
    const preferences = automatic && (policy === 'original' || policy === 'nextUnhit');
    const blind = preferences && object.program.modes['target.preference'] === 'blindNear';
    const strong = policy === 'strongest' || (preferences && !blind && numerics['target.strongest'] > 0);
    const radius = preferences ? Math.max(numerics['target.threatRadius'] ?? 0,
      object.exitOf === undefined ? 0 : numerics['target.exitThreatRadius'] ?? 0) : 0;
    const history = this.rootTargets.get(object.rootReceiptId);
    const original = this.facts.get(object.rootReceiptId)?.originalTargetId ?? object.targetId;
    const keepOriginal = policy === 'original' && !blind && (!strong || !history?.automatic.has(original!));
    const fresh = preferences && numerics['target.fresh'] > 0;
    let best: Enemy | undefined, bestRanks: readonly number[] = [];
    // A linear minimum keeps target queries bounded without sorting the enemy list for every hop.
    for (const enemy of this.ctx.enemies) {
      if (enemy.dead || !this.ctx.canEnemyAct(enemy) || seen?.has(enemy.id) || (allowed && !allowed.has(enemy.id))) continue;
      const distance = (enemy.x - object.position.x) ** 2 + (enemy.y - object.position.y) ** 2;
      if (distance > maxDistance * maxDistance) continue;
      const playerDistance = (enemy.x - this.ctx.player.x) ** 2 + (enemy.y - this.ctx.player.y) ** 2;
      const ranks = [radius > 0 && playerDistance > radius * radius ? 1 : 0, fresh && history?.all.has(enemy.id) ? 1 : 0,
        keepOriginal && enemy.id === original ? 0 : 1,
        strong ? -enemy.hp : (policy === 'farthest' ? -1 : 1) * (radius > 0 || blind ? playerDistance : distance), enemy.id];
      const difference = best ? ranks.findIndex((rank, index) => rank !== bestRanks[index]) : -1;
      if (!best || (difference >= 0 && ranks[difference] < bestRanks[difference])) { best = enemy; bestRanks = ranks; }
    }
    return best;
  }

  private relay(object: SpellObject, policy: TargetPolicy, maxDistance: number, chargeCostQ: number, tick: number):
    { relays: readonly RuntimeSpellRelay[]; target: SpellRuleTarget } | undefined {
    const runtime = this.current?.runtime;
    if (!runtime || object.shape !== 'chain' || object.state !== 'flight' || object.remainingApplications < 1
      || runtime.balance(object.id, 'charge') < chargeCostQ || runtime.ledger.getOwnedLots(object.id).some(lot => lot.remainingUses < 1)) return;
    const relays: RuntimeSpellRelay[] = [];
    const eligible = (shell: SpellObject, cost: number) => !shell.relayed && tick >= shell.createdAtTick && tick < shell.expiresAtTick
      && !shell.letter && !shell.status && runtime.balance(shell.id, 'charge') >= cost
      && runtime.ledger.getOwnedLots(shell.id).every(lot => lot.remainingUses >= 1 && !lot.ruleClaims['native.routing.relay']);
    for (const shell of runtime.active('shell')) {
      const n = shell.program.numerics;
      if (shell.state !== 'stored' || shell.field || !n['routing.shellRelay']) continue;
      const cost = Math.max(1, Math.floor(n['routing.hopCostQ'] / n['routing.chargeEfficiency'] / n['routing.shellEfficiency']));
      if (eligible(shell, cost)) relays.push({ objectId: shell.id, position: shell.position, chargeCostQ: cost, maxDistance: n['routing.distance'] });
    }
    for (const field of runtime.active('field')) {
      const n = field.program.numerics;
      const lots = runtime.ledger.getOwnedLots(field.id);
      if (field.state !== 'stored' || !field.field || !n['field.relay'] || field.remainingApplications < 1 || tick < field.readyAtTick
        || !eligible(field, 0) || !lots.length || lots.some(lot => lot.resource === 'work' || lot.resource === 'opportunity')) continue;
      relays.push({ objectId: field.id, position: field.position, chargeCostQ, sourceCharge: true,
        maxDistance: n['routing.distance'] * n['field.relayRange'] });
    }
    for (const spirit of this.ctx.spirits) {
      const reference = spirit.nativeCargo;
      if (!reference || reference.room !== runtime.room || spirit.mode !== 'dive' || !this.enemy(spirit.targetId ?? -1)) continue;
      const cargo = this.cargo(reference, spirit.i);
      if (!cargo || cargo.field || cargo.transport?.returning || !cargo.program.numerics['transport.relay']) continue;
      const n = cargo.program.numerics, cost = Math.max(1, Math.floor(n['routing.hopCostQ'] / n['routing.chargeEfficiency']));
      if (!eligible(cargo, cost)) continue;
      const relay: RuntimeSpellRelay = { objectId: cargo.id, actorId: spirit.i, position: { x: spirit.x, y: spirit.y },
        chargeCostQ: cost, maxDistance: n['routing.distance'] };
      relays.push(relay);
    }
    if (!relays.length) return;
    const paths = findRelayPaths(object.position, maxDistance, relays, object.program.numerics['routing.relayLimit'],
      Math.floor(runtime.balance(object.id, 'charge') / chargeCostQ) - 1);
    if (!paths.length) return;
    const reachable = new Set<number>();
    for (const enemy of this.ctx.enemies) if (!enemy.dead && paths.some(path => {
      const last = path.relays[path.relays.length - 1];
      return Math.hypot(enemy.x - last.position.x, enemy.y - last.position.y) <= last.maxDistance;
    })) reachable.add(enemy.id);
    const target = this.target(object, policy, Infinity, reachable);
    if (!target) return;
    let selected: SpellRelayPath | undefined;
    for (const path of paths) {
      const last = path.relays[path.relays.length - 1], distance = Math.hypot(target.x - last.position.x, target.y - last.position.y);
      if (distance > last.maxDistance) continue;
      const completed = { relays: path.relays, distance: path.distance + distance };
      if (!selected || compareRelayPaths(completed, selected) < 0) selected = completed;
    }
    return selected && { relays: selected.relays, target };
  }

  private launch(object: SpellObject, target: SpellRuleTarget, from: Point = object.position, via?: readonly Point[]): void {
    if (this.clearing) return;
    const facts = this.facts.get(object.rootReceiptId), enemy = this.enemy(target.id);
    if (!facts || !enemy) { this.miss({ room: this.ctx.roomVisit, objectId: object.id }); return; }
    const reference = { room: this.ctx.roomVisit, objectId: object.id };
    if (object.shape === 'chain') {
      let previous = from;
      for (const point of via ?? []) { this.ctx.arc(previous, point, '#ffe7ac', facts.empowered ? 8 : 5, .28); previous = point; }
      this.ctx.arc(previous, enemy, '#ffe7ac', facts.empowered ? 8 : 5, .36);
      this.hit(reference, enemy, previous);
      if (!object.derived && object.targetPolicy === 'original' && !enemy.dead && !enemy.wordPending)
        Object.assign(enemy, this.ctx.wordFor(enemy.boss, enemy));
      return;
    }
    this.ctx.launchShot(object.position, enemy, facts.pattern.element, 0, { spell: reference, direct: !object.derived,
      empowered: facts.empowered, critical: facts.critical, refreshWord: !object.derived,
      pierce: object.shape === 'pierce' ? object.remainingApplications - 1 : 0 });
  }
  private prepare(object: SpellObject, targetId: number, tick: number): readonly SpellObject[] {
    const facts = this.facts.get(object.rootReceiptId), target = this.enemy(targetId), runtime = this.current!.runtime;
    const statuses: SpellObject[] = [], hadHeat = runtime.balance(object.id, 'heat') > 0;
    // Material left after nearby shells have been heated is spent at impact, for every book.
    if (facts && target && hadHeat) this.record(runtime.convert(object.id, 'heat', 'power', 1,
      object.program.numerics['heat.powerPerUnit'] ?? 4, 1, 'native.heat-impact'));
    if (!facts || !target || this.plainShapes.has(object.id) || (object.derived && !object.inheritedShape)) return statuses;
    const pattern = facts.pattern;
    const share = pattern.ongoingShare > 0 ? pattern.ongoingShare
      : object.program.numerics['ongoing.universal'] > 0 || (hadHeat && object.program.modes['ongoing.entry'] === 'heat')
        ? object.program.numerics['ongoing.share'] : 0;
    let savedShare = 0;
    if (share > 0 && runtime.balance(object.id, 'power') > 0) {
      const stored = this.record(runtime.createFinite({ kind: 'status', fromObjectId: object.id, share,
        resourceShares: { cold: 0, heat: 0, charge: 0, work: 0, opportunity: 0 }, retention: object.program.numerics['ongoing.retention'],
        position: target, targetId, properties: { material: 'heat' }, tick, delayTicks: 0,
        lifeTicks: Math.max(1, Math.round((pattern.ongoingTicks || 240) * object.program.numerics['ongoing.lifeTicks'] / 240)),
        applications: Math.max(1, Math.round((pattern.ongoingApplications || 8) * object.program.numerics['ongoing.applications'] / 8)) }, 128));
      if (stored) { statuses.push(...stored.objects); savedShare = share; }
    }
    if (pattern.element !== 'fire') return statuses;
    const targets = this.ctx.enemies.filter(enemy => !enemy.dead && enemy.id !== targetId
      && Math.hypot(enemy.x - target.x, enemy.y - target.y) <= pattern.splashRadius).slice(0, 16);
    if (targets.length && pattern.splashShare > 0) {
      const share = Math.min(1, pattern.splashShare / (1 - savedShare));
      const split = this.record(runtime.allocate(object.id, targets.map(() => Math.floor(share / targets.length * 1e9) / 1e9)));
      split?.objects.forEach((child, index) => {
        this.plainShapes.add(child.id);
        const flight = this.record(runtime.dispatch(child.id, targets[index].id, tick, 126));
        if (flight) this.ctx.launchShot(target, targets[index], 'fire', 0, { spell: { room: runtime.room, objectId: child.id } });
      });
    }
    this.ctx.burst(target.x, target.y, pattern.splashRadius, '#ffb17f', 'fire');
    return statuses;
  }

  private fieldTargets(object: SpellObject): readonly SpellRuleTarget[] {
    const field = object.field;
    if (!field) return [];
    const from = field.from ?? object.position, dx = object.position.x - from.x, dy = object.position.y - from.y;
    const lengthSquared = dx * dx + dy * dy, radiusSquared = field.radius * field.radius;
    return this.ctx.enemies.filter(enemy => {
      if (enemy.dead || !this.ctx.canEnemyAct(enemy)) return false;
      const t = lengthSquared ? Math.max(0, Math.min(1, ((enemy.x - from.x) * dx + (enemy.y - from.y) * dy) / lengthSquared)) : 0;
      return (enemy.x - from.x - dx * t) ** 2 + (enemy.y - from.y - dy * t) ** 2 <= radiusSquared;
    }).sort((a, b) => a.id - b.id).slice(0, 64);
  }

  private projectFields(): void {
    const runtime = this.current?.runtime;
    if (!runtime) { this.fieldView = []; return; }
    this.fieldView = runtime.active('field').filter(object => object.field && this.tick < object.expiresAtTick).map(object => {
      const field = object.field!, totalTicks = object.expiresAtTick - object.createdAtTick;
      const kind = runtime.balance(object.id, 'cold') > 0 ? 'frost' : runtime.balance(object.id, 'power') > 0 ? 'fire' : 'storm';
      return Object.freeze({ kind, x: object.position.x, y: object.position.y, r: field.radius,
        life: (object.expiresAtTick - this.tick) / TICKS_PER_SECOND, max: totalTicks / TICKS_PER_SECOND,
        age: (this.tick - object.createdAtTick) / TICKS_PER_SECOND, ultimate: false,
        seed: (object.id * .61803398875) % 1, from: field.from,
        remainingShare: Math.min(1, object.remainingApplications / Math.max(1, object.program.numerics['field.applications'] ?? 8)) });
    });
  }
  private damage(commit: RuntimeDamageCommit): void {
    const enemy = this.enemy(commit.targetId);
    if (!enemy) return;
    this.committedPowerQ += commit.powerQ;
    if (commit.materials.cold) this.ctx.applyCold(enemy,
      commit.materials.cold / RESOURCE_SCALE * (commit.object.program.numerics['cold.efficiency'] ?? 1),
      (commit.object.program.numerics['cold.freezeTicks'] ?? 93) / TICKS_PER_SECOND);
    this.ctx.damage(enemy, commit.powerQ / RESOURCE_SCALE, commit.object.derived ? 1 : 0,
      !commit.object.derived, commit.object.position, { room: this.ctx.roomVisit, objectId: commit.object.id });
  }
}
