import type { BuildDiagnostic } from '../../contracts/build-resources.ts';
import type { RuleEventResult, SpellRuleEvent, SpellRuleTarget } from '../../contracts/build-execution.ts';
import type { CounterId, RuleEvent, RuleStage, TargetPolicy } from '../../contracts/build-rules.ts';
import type { RuntimeDamageCommit, SpellCloseResult, SpellObject, SpellPosition } from '../../contracts/build-runtime.ts';
import { SpellRuleExecutor } from './SpellRuleExecutor.ts';

export interface SpellCombatPort {
  isAlive(targetId: number): boolean;
  target(object: SpellObject, policy: TargetPolicy): SpellRuleTarget | undefined;
  damage(commit: RuntimeDamageCommit): void;
  launch(object: SpellObject, target: SpellRuleTarget, from?: SpellPosition, via?: readonly SpellPosition[]): void;
  /** A paid destination can claim a bounded preference before another queued spell selects. */
  targetCommitted?(object: SpellObject, target: SpellRuleTarget): void;
  readonly flightLifeTicks: number;
  /** Native preparations move existing resources; they cannot create another input receipt. */
  prepareHit?(object: SpellObject, targetId: number, tick: number): readonly SpellObject[] | void;
  fieldTargets?(object: SpellObject): readonly SpellRuleTarget[];
  /** Current world facts combined with the input facts of this immutable spell root. */
  counters?(object: SpellObject): Readonly<Partial<Record<CounterId, number>>>;
  /** Native helpers share the work left after the primary's registered assembly. */
  afterAssembly?(object: SpellObject): void;
  /** Clear-room detection runs after paid immediate effects have been dispatched. */
  boundary(): void;
}

/** One authoritative hit/expiry boundary; rendering receives only successfully paid launches. */
export class SpellLifecycle {
  private sequence = 0;
  private inBoundary = false;
  private delivering = false;
  private readonly errors: BuildDiagnostic[] = [];
  private readonly assembled = new Set<number>();
  private readonly dispatched = new Set<number>();
  private readonly deliveries: { object: SpellObject; target: SpellRuleTarget; from?: SpellPosition; via?: readonly SpellPosition[] }[] = [];
  private readonly ongoing = new Map<number, { next: number; interval: number }>();
  private readonly pending = new Map<number, Readonly<Partial<Record<CounterId, number>>>>();
  private readonly destinations = new Map<number, SpellRuleTarget>();
  private readonly launchQueue: { id: number; tick: number }[] = [];
  private readonly queued = new Set<number>();
  private readonly intercepted = new Set<string>();
  private readonly heatedPairs = new Set<string>();
  private previousManualTarget?: number;
  readonly executor: SpellRuleExecutor;
  private readonly combat: SpellCombatPort;
  constructor(executor: SpellRuleExecutor, combat: SpellCombatPort) { this.executor = executor; this.combat = combat; }
  get diagnostics(): readonly BuildDiagnostic[] { return Object.freeze([...this.errors]); }

  start(objectId: number, tick: number, counters: Readonly<Partial<Record<CounterId, number>>> = {}, matchedCharacters = 0): void {
    this.boundary(() => {
      const object = this.executor.runtime.getObject(objectId);
      if (!object || object.derived || this.assembled.has(objectId)) return;
      const income = this.event(object, 'manual.complete', 'income', tick, counters);
      this.consume(income, tick, false, counters);
      // Income acknowledges the unchanged paid facts; completed matches belong to the subsequent stage.
      counters = { ...counters, matchedCharacters };
      if (matchedCharacters > 0) for (const stage of ['income', 'assemble'] as const)
        this.consume(this.event(object, 'letter.match', stage, tick, counters), tick, false, counters);
      if (this.previousManualTarget !== undefined && this.combat.isAlive(this.previousManualTarget)) {
        for (const status of this.executor.runtime.active('status')) if (status.targetId === this.previousManualTarget && tick < status.expiresAtTick)
          this.consume(this.event(status, 'status.extract', 'assemble', tick, counters), tick, false, counters);
      }
      this.previousManualTarget = object.targetId;
      this.assembleShells(tick, counters);
      this.queueLaunch(object, tick, counters);
    });
  }

  /** A collision can consume one eligible shell; partial interception leaves real incoming damage. */
  intercept(projectile: NonNullable<SpellRuleEvent['projectile']>, tick: number): number {
    if (!projectile.reflectable || this.intercepted.has(projectile.id)) return 0;
    let blocked = 0;
    this.boundary(() => {
      this.assembleShells(tick, {});
      const programs = new Set<SpellObject['program']>();
      for (const shell of this.executor.runtime.active('shell')) {
        if (shell.state !== 'stored' || shell.letter?.reward === 'guard' || tick >= shell.expiresAtTick || programs.has(shell.program)) continue;
        programs.add(shell.program);
        if (!shell.program.byEvent['projectile.intercept']?.length) continue;
        for (const stage of ['prepareHit', 'commitHit'] as const) {
          const result = this.executor.execute({ id: `lifecycle:${++this.sequence}`, subject: shell, event: 'projectile.intercept',
            stage, tick, projectile, counters: this.combat.counters?.(shell) ?? {} });
          this.errors.push(...result.errors); this.consume(result, tick);
          for (const outcome of result.outcomes) if ((outcome.result?.blockedPowerQ ?? 0) > 0) {
            blocked = outcome.result!.blockedPowerQ!; this.intercepted.add(projectile.id);
            for (const used of outcome.result!.objects) {
              const current = this.executor.runtime.getObject(used.id);
              if (current?.kind === 'shell' && current.state !== 'closed') this.finish(current, 'guard', tick, {});
            }
            return;
          }
        }
      }
    });
    return blocked;
  }

  hit(objectId: number, targetId: number, tick: number,
    counters: Readonly<Partial<Record<CounterId, number>>> = {}, position?: SpellPosition, share?: number): void {
    this.boundary(() => {
      const runtime = this.executor.runtime, before = runtime.getObject(objectId);
      if (!before || before.state !== 'flight' || tick < before.readyAtTick || tick >= before.expiresAtTick || !this.combat.isAlive(targetId)) return;
      // Existing effects keep their frozen rules. Only a real primary hit can pay to alter their timing.
      if (!before.derived) for (const status of runtime.active('status')) {
        if (status.targetId !== targetId || tick >= status.expiresAtTick) continue;
        this.tickStatus(status, tick, counters);
        const current = runtime.getObject(status.id);
        if (!current || current.state === 'closed' || !this.combat.isAlive(targetId)) continue;
        const result = this.executor.execute({ id: `lifecycle:${++this.sequence}`, subject: current, sourceObjectId: before.id,
          event: 'status.contact', stage: 'prepareHit', tick, counters: { ...counters, ...this.combat.counters?.(current) } });
        this.errors.push(...result.errors); this.consume(result, tick, false, counters);
      }
      if (!this.combat.isAlive(targetId)) { this.finish(before, 'miss', tick, counters); this.retireDeadStatuses(tick, counters); return; }
      this.heatContacts(before, tick, counters, position);
      const hitTarget = { id: targetId, ...(position ?? before.position) };
      const prepared = this.event(before, 'hit.prepare', 'prepareHit', tick, counters, undefined, undefined, hitTarget);
      const statuses = this.combat.prepareHit?.(before, targetId, tick) ?? [];
      for (const status of statuses) if (status.kind === 'status')
        this.consume(this.event(status, 'status.start', 'prepareHit', tick, counters, undefined, undefined, hitTarget), tick, false, counters);
      const ready = runtime.getObject(objectId);
      // Prepared children retain their resources even if this hit kills the original target.
      if (ready && ready.state !== 'closed' && runtime.ledger.getOwnedLots(objectId).length) {
        const committed = runtime.commitHit(objectId, targetId, position, share);
        if (!committed.ok) { this.errors.push(...committed.errors); return; }
        this.combat.damage(committed.value);
        this.consume(this.event(committed.value.object, 'hit.commit', 'commitHit', tick, counters), tick, false, counters);
        const after = this.event(committed.value.object, 'hit.after', 'afterHit', tick, counters);
        this.consume(after, tick, false, counters);
        const remainder = runtime.getObject(objectId);
        if (before.shape === 'chain' && remainder?.state === 'flight' && !after.outcomes.some(outcome => outcome.result?.flight))
          this.finish(remainder, 'routing', tick, counters);
      }
      this.consume(prepared, tick, false, counters);
      this.retireDeadStatuses(tick, counters);
    });
  }

  /** Called with simulation ticks; paused/menu time never advances these deadlines. */
  advance(tick: number, counters: Readonly<Partial<Record<CounterId, number>>> = {}): void {
    this.boundary(() => {
      this.assembleShells(tick, counters);
      for (const object of this.executor.runtime.active()) {
        if (object.kind === 'status') this.tickStatus(object, tick, counters);
        if (object.kind === 'field') this.tickField(object, tick, counters);
        if (this.executor.runtime.getObject(object.id)?.state === 'closed') { this.ongoing.delete(object.id); continue; }
        if (tick >= object.expiresAtTick) this.finish(object, 'expiry', tick, counters);
        else if (object.kind === 'shell' && object.state === 'stored' && tick >= object.readyAtTick) this.finish(object, 'release', tick, counters);
        else if (object.state === 'ready' && (object.targetWaitUsed || this.pending.has(object.id)) && tick >= object.readyAtTick)
          this.queueLaunch(object, tick, this.pending.get(object.id));
      }
      this.retireDeadStatuses(tick, counters);
    });
  }

  expire(objectId: number, tick: number, reason: 'expiry' | 'miss' = 'expiry'): void {
    this.boundary(() => {
      const object = this.executor.runtime.getObject(objectId);
      if (object && object.state !== 'closed') this.finish(object, reason, tick, {});
    });
  }

  /** Cargo arrives as its original finite spell, without running the primary assembly again. */
  deliverTransport(objectId: number, target: SpellRuleTarget, tick: number): void {
    this.boundary(() => {
      const object = this.executor.runtime.getObject(objectId);
      if (!object || object.kind !== 'spell' || object.state !== 'ready' || !this.combat.isAlive(target.id)) return;
      this.assembled.add(object.id);
      this.destinations.set(object.id, target);
      this.queueLaunch(object, tick, this.combat.counters?.(object));
    });
  }

  private tickStatus(initial: SpellObject, tick: number, counters: Readonly<Partial<Record<CounterId, number>>>): void {
    const runtime = this.executor.runtime;
    if (initial.targetId === undefined || !this.combat.isAlive(initial.targetId)) {
      this.finish(initial, 'death', tick, counters); this.ongoing.delete(initial.id); return;
    }
    while (true) {
      const object = runtime.getObject(initial.id);
      if (!object || object.state === 'closed' || !this.combat.isAlive(initial.targetId)) break;
      const due = object.status?.nextAtTick;
      if (due === undefined || due > tick || due > object.expiresAtTick || !runtime.ledger.getOwnedLots(object.id).length) break;
      const result = runtime.commitHit(object.id, initial.targetId);
      if (result.ok) {
        this.combat.damage(result.value);
        this.consume(this.event(result.value.object, 'status.tick', 'commitHit', due, counters), due, false, counters);
        if (runtime.getObject(initial.id)?.state === 'closed')
          this.consume(this.event(result.value.object, 'status.finish', 'finish', due, counters), due, false, counters);
      } else { this.errors.push(...result.errors); break; }
    }
  }

  clearRoom(tick: number, counters: Readonly<Partial<Record<CounterId, number>>> = {}): void {
    this.boundary(() => {
      this.retireDeadStatuses(tick, counters);
      for (const object of this.executor.runtime.active()) this.finish(object, 'room', tick, counters);
    });
  }

  private tickField(initial: SpellObject, tick: number, counters: Readonly<Partial<Record<CounterId, number>>>): void {
    if (!initial.field) return;
    const runtime = this.executor.runtime;
    let timer = this.ongoing.get(initial.id);
    if (!timer) {
      const interval = initial.field.intervalTicks;
      timer = { interval, next: Math.max(initial.readyAtTick, initial.createdAtTick + interval) };
      this.ongoing.set(initial.id, timer);
    }
    while (timer.next <= tick && timer.next <= initial.expiresAtTick) {
      const object = runtime.getObject(initial.id);
      if (!object || object.state === 'closed') break;
      const targets = this.combat.fieldTargets?.(object) ?? [];
      const due = timer.next; timer.next += timer.interval;
      if (!targets.length && object.field?.allocation === 'onContact') continue;
      const result = runtime.applyField(object.id, targets.map(target => target.id));
      if (!result.ok) { this.errors.push(...result.errors); break; }
      for (const commit of result.value.commits) this.combat.damage(commit);
      this.consume(this.event(result.value.object, 'field.apply', 'commitHit', due, counters), due, false, counters);
      if (result.value.object.state === 'closed')
        this.consume(this.event(result.value.object, 'field.finish', 'finish', due, counters), due, false, counters);
    }
  }

  private retireDeadStatuses(tick: number, counters: Readonly<Partial<Record<CounterId, number>>>): void {
    for (const object of this.executor.runtime.active('status')) if (object.targetId !== undefined && !this.combat.isAlive(object.targetId)) {
      this.finish(object, 'death', tick, counters); this.ongoing.delete(object.id);
    }
  }

  /** Stored outputs settle together after creation, before heat, interception or automatic release. */
  private assembleShells(tick: number, counters: Readonly<Partial<Record<CounterId, number>>>): void {
    const runtime = this.executor.runtime, queue = runtime.active('shell').map(shell => shell.id);
    for (let index = 0; index < queue.length; index++) {
      const shell = runtime.getObject(queue[index]);
      if (!shell || shell.state !== 'stored' || shell.letter || tick >= shell.expiresAtTick || this.assembled.has(shell.id)) continue;
      this.assembled.add(shell.id);
      if (!shell.program.byEvent['shell.assemble']?.length) continue;
      const result = this.event(shell, 'shell.assemble', 'assemble', tick, counters);
      this.consume(result, tick, false, counters);
      for (const outcome of result.outcomes) for (const created of outcome.result?.objects ?? [])
        if (created.kind === 'shell' && created.state === 'stored' && !this.assembled.has(created.id)) queue.push(created.id);
    }
  }

  private finish(subject: SpellObject, reason: SpellCloseResult['reason'], tick: number,
    counters: Readonly<Partial<Record<CounterId, number>>>): void {
    const runtime = this.executor.runtime;
    if (runtime.getObject(subject.id)?.state === 'closed') return;
    if (subject.state === 'carried' && reason !== 'room') reason = 'transport';
    this.pending.delete(subject.id);
    this.destinations.delete(subject.id);
    this.ongoing.delete(subject.id);
    if (subject.kind === 'letter' || subject.letter?.reward === 'guard' || subject.field?.onFinish === 'lose') {
      const discarded = runtime.discard(subject.id);
      if (!discarded.ok) this.errors.push(...discarded.errors);
      return;
    }
    let escrow = subject;
    if (subject.exitOf === undefined) {
      const closed = runtime.close(subject.id, reason, tick);
      if (!closed.ok) { this.errors.push(...closed.errors); return; }
      escrow = closed.value.escrow;
    }
    this.completeExit(subject, escrow, reason, tick, counters);
  }

  private completeExit(subject: SpellObject, escrow: SpellObject, reason: SpellCloseResult['reason'],
    tick: number, counters: Readonly<Partial<Record<CounterId, number>>>): void {
    const runtime = this.executor.runtime;
    if (reason === 'fracture') this.consume(this.event(subject, 'shell.fracture', 'afterHit', tick, counters, escrow.id), tick, false, counters);
    const name = reason === 'transport' || subject.state === 'carried' ? 'transport.finish' : reason === 'room' ? 'room.finish' : reason === 'routing' ? 'route.finish' : subject.kind === 'shell' ? 'shell.finish'
      : subject.kind === 'status' ? reason === 'death' ? 'status.death' : 'status.finish' : subject.kind === 'field' ? 'field.finish' : 'spell.finish';
    const finished = this.event(subject, name, 'finish', tick, counters, escrow.id, reason);
    // Room cleanup may recover already-paid resources, but never launch into the next room.
    this.consume(finished, tick, reason === 'room', counters);
    const remaining = runtime.getObject(escrow.id);
    if (!remaining || remaining.state === 'closed') return;
    if ((reason === 'release' || reason === 'thermal' || reason === 'fracture') && remaining.state === 'ready') this.queueLaunch(remaining, tick, counters);
    const final = runtime.getObject(escrow.id);
    const released = finished.outcomes.some(outcome => outcome.result?.flight?.object.id === escrow.id);
    if (final && final.state !== 'closed' && (reason === 'room'
      || (!released && !this.pending.has(final.id)))) {
      const discarded = runtime.discard(final.id);
      if (!discarded.ok) this.errors.push(...discarded.errors);
    }
  }

  /** Contacts occur at the cast origin and actual impact, using paid material rather than book names. */
  private heatContacts(source: SpellObject, tick: number, counters: Readonly<Partial<Record<CounterId, number>>>, position = source.position): void {
    const runtime = this.executor.runtime;
    if (!runtime.balance(source.id, 'heat')) return;
    const shells = runtime.active('shell').filter(shell => shell.letter?.reward !== 'guard' && tick < shell.expiresAtTick
      && shell.program.byEvent['shell.heat']?.length
      && Math.hypot(position.x - shell.position.x, position.y - shell.position.y) <= (shell.program.numerics['heat.reach'] ?? 96))
      .sort((a, b) => Math.hypot(a.position.x - position.x, a.position.y - position.y)
        - Math.hypot(b.position.x - position.x, b.position.y - position.y) || a.id - b.id);
    for (const initial of shells) {
      if (!runtime.balance(source.id, 'heat')) break;
      const key = `${source.id}:${initial.id}`;
      if (this.heatedPairs.has(key)) continue;
      for (const stage of ['prepareHit', 'afterHit'] as const) {
        const shell = runtime.getObject(initial.id);
        if (!shell || shell.state !== 'stored') break;
        const result = this.executor.execute({ id: `lifecycle:${++this.sequence}`, subject: shell, sourceObjectId: source.id,
          event: 'shell.heat', stage, tick, counters: { ...counters, ...this.combat.counters?.(shell) } });
        this.errors.push(...result.errors); this.consume(result, tick, false, counters);
        if (result.outcomes.some(outcome => outcome.status === 'applied')) { this.heatedPairs.add(key); break; }
      }
    }
  }

  private event(subject: SpellObject, event: RuleEvent, stage: RuleStage, tick: number,
    counters: Readonly<Partial<Record<CounterId, number>>>, unspentObjectId?: number, endReason?: SpellCloseResult['reason'], hitTarget?: SpellRuleTarget): RuleEventResult {
    const result = this.executor.execute({ id: `lifecycle:${++this.sequence}`, subject, event, stage, tick,
      counters: event === 'manual.complete' ? counters : { ...counters, ...this.combat.counters?.(subject) }, unspentObjectId, endReason, hitTarget });
    this.errors.push(...result.errors);
    return result;
  }
  private consume(result: RuleEventResult, tick: number, clearing = false,
    counters: Readonly<Partial<Record<CounterId, number>>> = {}): void {
    const runtime = this.executor.runtime;
    for (const outcome of result.outcomes) {
      const effect = outcome.result;
      if (!effect) continue;
      if (effect.damage) {
        this.combat.damage(effect.damage);
        const status = effect.damage.object;
        this.consume(this.event(status, 'status.tick', 'commitHit', tick, counters), tick, clearing, counters);
        if (status.state === 'closed') this.consume(this.event(status, 'status.finish', 'finish', tick, counters), tick, clearing, counters);
      }
      if (effect.closure) this.completeExit(effect.closure.subject, effect.closure.escrow,
        clearing ? 'room' : effect.closure.reason, tick, counters);
      for (const field of effect.relayedFields ?? []) {
        this.consume(this.event(field, 'field.relay', 'commitHit', tick, counters), tick, clearing, counters);
        if (field.state === 'closed') {
          this.ongoing.delete(field.id);
          this.consume(this.event(field, 'field.finish', 'finish', tick, counters), tick, clearing, counters);
        }
      }
      if (effect.flight) {
        if (!clearing && this.combat.isAlive(effect.flight.target.id)) {
          this.combat.targetCommitted?.(effect.flight.object, effect.flight.target);
          this.deliveries.push(effect.flight);
        }
        else if (runtime.getObject(effect.flight.object.id)?.state !== 'closed') runtime.discard(effect.flight.object.id);
      }
      for (const candidate of effect.objects) {
        const object = runtime.getObject(candidate.id);
        if (!object || object.state !== 'ready' || object.kind !== 'spell') continue;
        const destination = effect.destinations?.find(entry => entry.objectId === object.id);
        if (clearing || (destination && !destination.target)) runtime.discard(object.id);
        else {
          if (destination?.target) this.destinations.set(object.id, destination.target);
          this.queueLaunch(object, tick, counters);
        }
      }
    }
  }
  private queueLaunch(object: SpellObject, tick: number, counters: Readonly<Partial<Record<CounterId, number>>> = {}): void {
    if (object.state !== 'ready' || object.kind !== 'spell') return;
    if (!this.pending.has(object.id)) this.pending.set(object.id, Object.freeze({ ...counters }));
    if (tick < object.readyAtTick || this.queued.has(object.id)) return;
    this.queued.add(object.id); this.launchQueue.push({ id: object.id, tick });
  }
  private launch(object: SpellObject, tick: number, counters: Readonly<Partial<Record<CounterId, number>>> = {}): void {
    const runtime = this.executor.runtime;
    object = runtime.getObject(object.id) ?? object;
    if (object.state !== 'ready' || object.kind !== 'spell') return;
    if (tick < object.readyAtTick || tick >= object.expiresAtTick) return;
    if (!this.assembled.has(object.id)) {
      this.assembled.add(object.id);
      this.consume(this.event(object, 'spell.assemble', 'assemble', tick, counters), tick, false, counters);
      this.assembleShells(tick, counters);
      object = runtime.getObject(object.id)!;
      if (object.state === 'ready') this.heatContacts(object, tick, counters);
      if (!object.derived && runtime.getObject(object.id)?.state === 'ready') this.combat.afterAssembly?.(object);
    }
    if (object.state !== 'ready' || !runtime.ledger.getOwnedLots(object.id).length) return;
    if (!this.dispatched.has(object.id)) {
      this.dispatched.add(object.id);
      this.consume(this.event(object, 'spell.dispatch', 'dispatch', tick, counters), tick, false, counters);
      object = runtime.getObject(object.id)!;
    }
    if (object.state !== 'ready' || !runtime.ledger.getOwnedLots(object.id).length) return;
    const destination = this.destinations.get(object.id);
    if (destination && !this.combat.isAlive(destination.id)) { this.finish(object, 'expiry', tick, counters); return; }
    const target = destination ?? this.combat.target(object, object.targetPolicy);
    if (!target || !this.combat.isAlive(target.id)) {
      if (!object.targetWaitUsed) this.executor.runtime.waitForTarget(object.id, tick, this.combat.flightLifeTicks);
      return;
    }
    const flight = this.executor.runtime.dispatch(object.id, target.id, tick, this.combat.flightLifeTicks);
    if (flight.ok) {
      this.pending.delete(object.id); this.destinations.delete(object.id);
      this.combat.targetCommitted?.(flight.value.objects[0], target);
      this.deliveries.push({ object: flight.value.objects[0], target });
    }
    else this.errors.push(...flight.errors);
  }
  private boundary(action: () => void): void {
    if (this.inBoundary) throw new Error('Spell lifecycle cannot reenter a hit or room boundary');
    this.inBoundary = true;
    try {
      action();
      // Process new children iteratively. A sibling can close/merge a queued object before its turn.
      for (let index = 0; index < this.launchQueue.length; index++) {
        const request = this.launchQueue[index]; this.queued.delete(request.id);
        const object = this.executor.runtime.getObject(request.id);
        if (object?.state === 'ready') this.launch(object, request.tick, this.pending.get(request.id));
        if (this.executor.runtime.getObject(request.id)?.state !== 'ready') { this.pending.delete(request.id); this.destinations.delete(request.id); }
      }
    } finally { this.launchQueue.length = 0; this.queued.clear(); this.inBoundary = false; }
    // Synchronous lightning may hit immediately; deliver only outside the transaction boundary.
    if (this.delivering) return;
    this.delivering = true;
    try {
      for (let index = 0; index < this.deliveries.length; index++) {
        const delivery = this.deliveries[index];
        // Another paid child may have consumed/closed this delivery before its turn.
        if (this.executor.runtime.getObject(delivery.object.id)?.state === 'flight')
          this.combat.launch(delivery.object, delivery.target, delivery.from, delivery.via);
      }
    } finally { this.deliveries.length = 0; this.delivering = false; }
    this.combat.boundary();
  }
}
