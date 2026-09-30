import type { BuildEventChoice, BuildEventDefinition, BuildEventOffer, BuildEventRecord } from '../../contracts/build-events.ts';
import type { CombatStat, CombatStats } from '../../contracts/stats.ts';
import type { CombatCapability } from '../../contracts/combat-weave.ts';
import type { Relic } from '../../contracts/content.ts';

export interface BuildEventContext {
  readonly runId: string;
  readonly room: number;
  readonly chapter: number;
  readonly capabilities: readonly CombatCapability[];
  readonly talentGrants: Partial<CombatStats>;
  readonly talents: readonly string[];
  readonly talentSources: readonly import('../../contracts/talents.ts').TalentNode[];
  readonly relics: Readonly<Record<string, number>>;
  readonly definitions: readonly Relic[];
  readonly hp: number;
  readonly maxHp: number;
}
interface Pending { offer: BuildEventOffer; stamp: string; definition: BuildEventDefinition }
const fingerprint = (ctx: BuildEventContext) => JSON.stringify([ctx.runId, ctx.room, ctx.chapter, ctx.hp, ctx.maxHp, Object.entries(ctx.relics).sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0)]);
const immutableChoice = (choice: BuildEventChoice): BuildEventChoice => Object.freeze({ ...choice, grants: Object.freeze({ ...choice.grants }), nodeIds: Object.freeze([...choice.nodeIds]), ...(choice.replacement ? { replacement: Object.freeze({ ...choice.replacement }) } : {}) });

/** Frozen offers and atomic run-local changes. No account progression is written here. */
export class BuildEventSystem {
  private entries: BuildEventRecord[] = [];
  private pending?: Pending;
  private serial = 0;
  private debt = 0;
  private committed = new Set<string>();
  private trials = new Set<string>();
  get records(): readonly BuildEventRecord[] { return this.entries; }
  get offer(): BuildEventOffer | undefined { return this.pending?.offer; }
  get rewardDebt() { return this.debt; }
  get grants(): Partial<CombatStats> {
    const result: Partial<Record<CombatStat, number>> = {};
    for (const record of this.entries) if (record.active)
      for (const [stat, value] of Object.entries(record.choice.grants))
        result[stat as CombatStat] = (result[stat as CombatStat] ?? 0) + value!;
    return result;
  }
  reset() { this.entries = []; this.pending = undefined; this.serial = 0; this.debt = 0; this.committed.clear(); this.trials.clear(); }
  consumeRewardDebt(): boolean { if (this.debt <= 0) return false; this.debt--; return true; }
  pressure(room: number): number { return this.entries.filter(record => record.room === room).reduce((sum, record) => sum + record.choice.pressure, 0); }
  completeRoom(room: number) {
    this.entries = this.entries.map(record => {
      if (record.room !== room || !this.trials.has(record.id)) return record;
      this.trials.delete(record.id);
      return Object.freeze({ ...record, active: true, status: 'active' as const });
    });
  }
  advance(room: number, chapter: number) {
    this.entries = this.entries.map(record => {
      const expired = record.choice.scope === 'room' ? room > record.room : record.choice.scope === 'chapter' ? chapter !== record.chapter : false;
      return expired && record.active ? Object.freeze({ ...record, active: false, status: 'expired' as const }) : record;
    });
  }
  private replacement(definition: BuildEventDefinition, ctx: BuildEventContext) {
    if (!definition.evolve || !definition.family) return undefined;
    const variant = ctx.definitions.find(relic => relic.eventOnly && relic.family === definition.family);
    if (!variant?.evolution || ctx.relics[variant.id]) return undefined;
    const held = ctx.definitions.filter(relic => ctx.relics[relic.id] && (relic.id === variant.evolution!.from || relic.evolution?.group === variant.evolution!.group));
    held.sort((a, b) => (b.budget ?? 8) - (a.budget ?? 8) || (a.id < b.id ? -1 : 1));
    const from = held[0];
    return from ? { from: from.id, to: variant.id } : undefined;
  }
  open(definitions: readonly BuildEventDefinition[], ctx: BuildEventContext, rng: () => number): BuildEventOffer | undefined {
    if (this.pending) return this.pending.offer;
    const used = new Set(this.entries.map(record => record.definitionId));
    const eligible = definitions.filter(definition =>
      !used.has(definition.id) && ctx.maxHp - definition.maxHealthCost >= 25 &&
      (!definition.needs || definition.needs.every(capability => ctx.capabilities.includes(capability))) &&
      (!definition.talentStats || definition.talentStats.some(stat => (ctx.talentGrants[stat] ?? 0) > 0)) &&
      (!definition.evolve || !!this.replacement(definition, ctx)));
    if (!eligible.length) return undefined;
    const definition = eligible[Math.min(eligible.length - 1, Math.max(0, Math.floor(rng() * eligible.length)))];
    const replacement = this.replacement(definition, ctx);
    const id = `${ctx.runId}:event:${ctx.room}:${++this.serial}`;
    const relevant = ctx.definitions.filter(relic => ctx.relics[relic.id] && (definition.family === relic.family || Object.keys(definition.grants).some(stat => stat in (relic.grants ?? {})))).map(relic => relic.id);
    const talentIds = ctx.talentSources.filter(node => ctx.talents.includes(node.id) && (definition.talentStats?.some(stat => (node.grants?.[stat] ?? 0) > 0) || Object.keys(definition.grants).some(stat => stat in (node.grants ?? {})) || definition.needs?.some(cap => node.capabilities?.includes(cap)))).map(node => node.id);
    const primary: BuildEventChoice = immutableChoice({ id: 'rewrite', name: definition.kind === 'trial' ? '接受试炼' : '修订构筑', description: definition.description, scope: definition.scope, grants: definition.grants, maxHealthCost: definition.maxHealthCost, rewardDebt: definition.rewardDebt ?? 0, pressure: definition.pressure ?? 0, heal: 0, replacement, nodeIds: [...new Set([...relevant.map(id => `relic:${id}`), ...talentIds.map(id => `talent:${id}`), ...(replacement ? [`relic:${replacement.from}`, `relic:${replacement.to}`] : [])])] });
    const choices = [immutableChoice({ ...primary, activation: definition.kind === 'trial' ? 'after-room' : 'immediate' })];
    if (ctx.maxHp >= 28) choices.push(immutableChoice({ id: 'annotate', name: '校订本卷', description: '本局生命上限减少 3，法术威力提高 2%。', scope: 'run', grants: { spellPower: .02 }, maxHealthCost: 3, rewardDebt: 0, pressure: 0, heal: 0, nodeIds: [] }));
    choices.push(immutableChoice({ id: 'leave', name: '保留原稿', description: '保持当前构筑，继续下一页。', scope: 'run', grants: {}, maxHealthCost: 0, rewardDebt: 0, pressure: 0, heal: 0, nodeIds: [] }));
    const offer: BuildEventOffer = Object.freeze({ id, definitionId: definition.id, name: definition.name, description: definition.description, choices: Object.freeze(choices) });
    this.pending = { offer, definition, stamp: fingerprint(ctx) };
    return offer;
  }
  commit(offerId: string, choiceId: string, ctx: BuildEventContext): { choice: BuildEventChoice; relics: Record<string, number>; hp: number; maxHp: number } | undefined {
    const pending = this.pending;
    if (!pending || pending.offer.id !== offerId || this.committed.has(offerId) || fingerprint(ctx) !== pending.stamp) return undefined;
    const choice = pending.offer.choices.find(item => item.id === choiceId);
    if (!choice || ctx.maxHp - choice.maxHealthCost < 25) return undefined;
    const relics = { ...ctx.relics };
    if (choice.replacement) {
      const target = ctx.definitions.find(relic => relic.id === choice.replacement!.to);
      if (!relics[choice.replacement.from] || !target || relics[target.id]) return undefined;
      delete relics[choice.replacement.from];
      if (target.excludes?.some(id => relics[id]) || ctx.definitions.some(relic => relics[relic.id] && relic.excludes?.includes(target.id))) return undefined;
      relics[target.id] = 1;
    }
    const maxHp = ctx.maxHp - choice.maxHealthCost;
    const hp = Math.min(maxHp, ctx.hp + choice.heal);
    const trial = pending.definition.kind === 'trial' && choice.id === 'rewrite';
    const active = !trial && Object.keys(choice.grants).length > 0;
    const record: BuildEventRecord = Object.freeze({ id: offerId, definitionId: pending.definition.id, name: pending.definition.name, choice, room: ctx.room + 1, chapter: ctx.chapter, active, status: trial ? 'pending' : choice.id === 'leave' ? 'kept' : active ? 'active' : 'applied' });
    this.entries = [...this.entries, record];
    if (trial) this.trials.add(record.id);
    this.debt += choice.rewardDebt;
    this.committed.add(offerId);
    this.pending = undefined;
    return { choice, relics, hp, maxHp };
  }
}
