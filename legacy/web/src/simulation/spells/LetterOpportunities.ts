import { RESOURCE_SCALE } from '../../contracts/build-resources.ts';
import type { Decision } from '../../contracts/build-resources.ts';
import type { RuleExecutionContext } from '../../contracts/build-execution.ts';
import type { OperationDefinition } from '../../contracts/build-rules.ts';
import type { RuntimeMutation, SpellLetterBinding, SpellPosition, SpellWordSession } from '../../contracts/build-runtime.ts';
import type { LetterMote } from '../../contracts/combat-weave.ts';
import { displayBoundary } from '../../vocabulary/index.ts';
import { SpellResourceRuntime } from './SpellResourceRuntime.ts';

export interface OpportunityWord {
  readonly session: SpellWordSession;
  readonly position: SpellPosition;
  readonly entered: number;
}
const missing = (): Decision<never> => ({ ok: false, errors: [{ code: 'INSUFFICIENT_RESOURCE', message: 'No paid matching character opportunity' }] });
const key = (binding: SpellLetterBinding) => `${binding.session.targetId}:${binding.session.revision}:${binding.position}`;

/** World adapter for finite, paid letters. Word selection never changes a gameplay random stream. */
export class LetterOpportunities {
  private readonly runtime: SpellResourceRuntime;
  private readonly words: () => readonly OpportunityWord[];
  private readonly flights = new Map<number, { binding: string; born: number; mote: LetterMote }>();
  private flightView: readonly LetterMote[] = [];
  constructor(runtime: SpellResourceRuntime, words: () => readonly OpportunityWord[]) { this.runtime = runtime; this.words = words; }
  get motes(): readonly LetterMote[] { return this.flightView; }

  mark(context: RuleExecutionContext, operation: Extract<OperationDefinition, { op: 'Mark' }>): Decision<RuntimeMutation> {
    const input = context.event.interrupted ?? this.runtime.inputFor(context.object.id);
    if (!input?.session) return missing();
    const text = input.session.word.replace(/ /g, '');
    if (input.humanPositions.some(position => !Number.isSafeInteger(position) || position < 0 || position >= text.length)
      || new Set(input.humanPositions).size !== input.humanPositions.length) return missing();
    const available = this.runtime.ledger.getOwnedLots(0).filter(lot => lot.resource === 'opportunity' && lot.remainingUses > 0)
      .reduce((sum, lot) => sum + lot.quantityQ, 0);
    const cost = Math.floor(operation.opportunityCost ? context.quantity(operation.opportunityCost) : RESOURCE_SCALE);
    const maxPerWord = Math.floor(operation.maxPerWord ? context.quantity(operation.maxPerWord) : 72);
    const limit = Math.min(Math.floor(context.quantity(operation.maxPositions)), Math.floor(available / cost), 72 - this.runtime.active('letter').length);
    const origin = context.event.interrupted?.position ?? context.object.position;
    const occupied = new Set(this.runtime.active('letter').map(object => key(object.letter!.binding)));
    const candidates = this.words().filter(word => word.session.targetId !== input.session!.targetId);
    const bindings: SpellLetterBinding[] = [];
    let selectedTarget: number | undefined;
    for (const position of input.humanPositions) {
      if (bindings.length >= limit) break;
      const binding = this.choose(text[position], origin, candidates.filter(word => selectedTarget === undefined || word.session.targetId === selectedTarget),
        occupied, operation.positionSelector === 'nearbyWords', maxPerWord);
      if (!binding) continue;
      bindings.push(binding); occupied.add(key(binding));
      if (operation.positionSelector === 'nextWord') selectedTarget = binding.session.targetId;
    }
    if (!bindings.length) return missing();
    const fee = context.rule.definition.resourceCost.reduce((sum, cost) => sum + Math.ceil(context.quantity(cost.amount)), 0);
    const plan = operation.rewardPlan;
    return this.runtime.markLetters(context.object.id, bindings, context.event.tick,
      Math.floor(context.object.program.numerics['letters.lifeTicks'] ?? 600), operation.rewardAllocation,
      Math.floor(context.object.program.numerics['letters.powerPerUnitQ'] ?? 6 * RESOURCE_SCALE), fee, origin, plan ? {
        storedShare: context.quantity(plan.storedShare), workShare: context.quantity(plan.workShare),
        storedRetention: context.quantity(plan.storedRetention), workRetention: context.quantity(plan.workRetention),
        capacity: Math.floor(context.quantity(plan.capacityUnits)), delayTicks: Math.floor(context.quantity(plan.releaseDelayTicks)),
        lifeTicks: Math.floor(context.quantity(plan.lifeTicks)), inheritShape: plan.inheritShape,
        opportunityCostQ: cost, spread: operation.positionSelector === 'nearbyWords', maxPerWord,
      } : undefined);
  }

  /** Lost words may pass an existing opportunity onward, but no new token or lifetime is created. */
  moveLost(): void {
    const letters = this.runtime.active('letter');
    if (!letters.length) return;
    const words = this.words(), occupied = new Set(letters.map(object => key(object.letter!.binding)));
    for (const object of letters) {
      const binding = object.letter!.binding;
      if (words.some(word => word.session.targetId === binding.session.targetId && word.session.revision === binding.session.revision
        && word.session.word === binding.session.word)) continue;
      const rule = object.program.rules.find(rule => rule.definition.operation.op === 'Mark');
      if (!rule || rule.definition.operation.op !== 'Mark') continue;
      const plan = object.letter!.plan;
      const next = this.choose(binding.character, object.position, words, occupied,
        plan?.spread ?? rule.definition.operation.positionSelector === 'nearbyWords', plan?.maxPerWord ?? 72);
      if (!next) continue;
      if (this.runtime.moveLetter(object.id, next).ok) { occupied.delete(key(binding)); occupied.add(key(next)); }
    }
  }

  bindings(): readonly SpellLetterBinding[] { return this.runtime.active('letter').map(object => object.letter!.binding); }
  update(tick: number): void {
    const letters = this.runtime.active('letter');
    if (!letters.length) { this.flights.clear(); this.flightView = []; return; }
    const words = this.words(), view: LetterMote[] = [], active = new Set<number>();
    for (const object of letters) {
      const binding = object.letter!.binding, target = words.find(word => word.session.targetId === binding.session.targetId
        && word.session.revision === binding.session.revision && word.session.word === binding.session.word);
      if (!target) continue;
      active.add(object.id);
      let flight = this.flights.get(object.id);
      if (!flight || flight.binding !== key(binding)) {
        const seed = object.id * 2.399963229728653;
        const start = flight ? { x: flight.mote.x, y: flight.mote.y } : { x: object.position.x, y: object.position.y - 30 };
        flight = { binding: key(binding), born: tick, mote: { x: start.x, y: start.y, start,
          control: { x: start.x + Math.cos(seed) * 140, y: start.y + Math.sin(seed) * 140 }, seed, age: 0,
          letter: binding.character, targetId: binding.session.targetId, word: binding.session.word,
          index: displayBoundary(binding.session.word, binding.position) } };
        this.flights.set(object.id, flight);
      }
      const mote = flight.mote;
      mote.age = Math.max(0, (tick - flight.born) / 60);
      const t = Math.min(1, mote.age / 1.15), u = 1 - t;
      const noise = Math.sin(Math.PI * t) * Math.sin(mote.seed + t * 5) * 13;
      mote.x = u * u * mote.start.x + 2 * u * t * mote.control.x + t * t * target.position.x + noise;
      mote.y = u * u * mote.start.y + 2 * u * t * mote.control.y + t * t * (target.position.y - 30) - noise;
      if (t < 1) view.push(mote);
    }
    for (const id of this.flights.keys()) if (!active.has(id)) this.flights.delete(id);
    this.flightView = view;
  }

  private choose(character: string, origin: SpellPosition, words: readonly OpportunityWord[], occupied: ReadonlySet<string>, spread: boolean,
    maxPerWord: number): SpellLetterBinding | undefined {
    let best: { binding: SpellLetterBinding; coverage: number; distance: number } | undefined;
    for (const word of words) {
      const text = word.session.word.replace(/ /g, '');
      let coverage = 0, candidate: SpellLetterBinding | undefined;
      for (let position = 0; position < text.length; position++) {
        const binding = { session: word.session, position, character: text[position] };
        if (occupied.has(key(binding))) { coverage++; continue; }
        if (!candidate && position >= word.entered && text[position] === character) candidate = binding;
      }
      if (!candidate || coverage >= maxPerWord) continue;
      if (!spread) coverage = 0;
      const distance = Math.hypot(word.position.x - origin.x, word.position.y - origin.y);
      if (!best || coverage < best.coverage || (coverage === best.coverage && (distance < best.distance
        || (distance === best.distance && word.session.targetId < best.binding.session.targetId)))) best = { binding: candidate, coverage, distance };
    }
    return best?.binding;
  }
}
