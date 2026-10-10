import { RESOURCE_SCALE as Q } from '../../contracts/build-resources.ts';
import type { BuildContribution, NumericDefinition, RelicDefinition, RuleDefinition, RuleRegistry, SemanticProfile } from '../../contracts/build-rules.ts';
import { RELIC_PRESENTATION } from './presentation.ts';

const empty: BuildContribution = { rules: [], capabilities: [], modifiers: [], modes: [] };
const semantic: SemanticProfile = { concepts: { duration: 1, recovery: .5, cold: .3 }, objectKinds: ['spell', 'status'],
  operationKinds: ['Ongoing'], inputProperties: ['power', 'cold'], outputProperties: ['unspent'], tradeoffKinds: ['delay', 'attack-allocation'] };
const stat = (id: string) => ({ stat: id });
const advance: RuleDefinition = { id: 'ongoing.advance', stage: 'prepareHit', event: 'status.contact', targetKind: 'status', when: { all: [] },
  operation: { op: 'Ongoing', action: 'advance', applications: stat('ongoing.advanceApplications') },
  resourceCost: [], inherit: 'paidProcessing', repeat: { unit: 'object', limit: 1 } };
const delay: RuleDefinition = { id: 'ongoing.delay', stage: 'prepareHit', event: 'status.contact', targetKind: 'status', when: { all: [] },
  operation: { op: 'Ongoing', action: 'delay', coldCost: stat('ongoing.delayColdQ'), extraTicks: stat('ongoing.delayTicks'), maxDelayTicks: stat('ongoing.delayLimit') },
  resourceCost: [], inherit: 'paidProcessing', repeat: { unit: 'object', limit: 1 }, after: [advance.id] };
const relic = (id: string, contribution: BuildContribution, extra: Partial<RelicDefinition> = {}): RelicDefinition => ({
  ...RELIC_PRESENTATION[id], ...contribution, id, maxLevel: 1, eligibility: { capability: 'ongoing', source: 'build' }, permitsAll: [],
  semantic, budget: { perOpportunity: 8, inherited: false }, ...extra });
const numeric = (id: string, unit: NumericDefinition['unit'], base: number, min: number, max: number): NumericDefinition => ({
  id, unit, base, min, max, integer: true, stage: 'prepareHit', multiplierPools: ['efficiency'] });
const numerics = [numeric('ongoing.advanceApplications', 'count', 2, 1, 8), numeric('ongoing.delayColdQ', 'cold', 12 * Q, Q, 128 * Q),
  numeric('ongoing.delayTicks', 'ticks', 120, 1, 600), numeric('ongoing.delayLimit', 'ticks', 120, 1, 600)];

export const ONGOING_CONTENT: Pick<RuleRegistry, 'rules' | 'relics' | 'numerics' | 'legacyRelicIds'> = {
  rules: { [advance.id]: advance, [delay.id]: delay }, numerics: Object.fromEntries(numerics.map(stat => [stat.id, stat])),
  relics: {
    R028: relic('R028', { ...empty, capabilities: ['ongoing'], modifiers: [
      { stat: 'ongoing.universal', pool: 'add', value: 1, unit: 'count' },
      { stat: 'ongoing.retention', pool: 'efficiency', value: .03, unit: 'ratio' },
    ] }, { maxLevel: 2, eligibility: { all: [] } }),
    R050: relic('R050', { ...empty, modifiers: [{ stat: 'ongoing.retention', pool: 'efficiency', value: .03, unit: 'ratio' }] }, { maxLevel: 3 }),
    R051: relic('R051', { ...empty, modifiers: [
      { stat: 'ongoing.lifeTicks', pool: 'add', value: 60, unit: 'ticks' },
      { stat: 'ongoing.applications', pool: 'add', value: 2, unit: 'count' },
    ] }, { maxLevel: 2 }),
    R165: relic('R165', { ...empty, rules: [advance.id] }, { permitsAll: ['permit:talent:T49'] }),
    R166: relic('R166', { ...empty, rules: [delay.id] }, { permitsAll: ['permit:talent:T04'],
      eligibility: { all: [{ capability: 'ongoing', source: 'build' }, { capability: 'cold', source: 'build' }] } }),
  },
  legacyRelicIds: { bleed: 'R028', cinder: 'R050', pitch: 'R051' },
};
