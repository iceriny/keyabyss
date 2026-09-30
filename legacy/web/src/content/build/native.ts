import { RESOURCE_SCALE } from '../../contracts/build-resources.ts';
import type { RuleDefinition, RuleRegistry } from '../../contracts/build-rules.ts';
import { LETTER_CONTENT } from './letters.ts';
import { STORAGE_CONTENT } from './storage.ts';
import { GUARD_CONTENT } from './guard.ts';
import { THERMAL_CONTENT } from './thermal.ts';
import { RESERVE_CONTENT } from './reserve.ts';
import { ROUTING_CONTENT, ROUTING_ENTRY } from './routing.ts';
import { TARGETING_CONTENT } from './targeting.ts';
import { FIELD_CONTENT, COLD_FIELD_ENTRY } from './fields.ts';
import { COLD_CONTENT, COLD_ENTRY } from './cold.ts';
import { ONGOING_CONTENT } from './ongoing.ts';
import { MERGING_CONTENT } from './merging.ts';
import { TRANSPORT_CONTENT } from './transport.ts';

const supply = (kind: 'primary' | 'work'): RuleDefinition => ({ id: `input.${kind}`, stage: 'income', event: 'manual.complete',
  targetKind: 'spell', when: { all: [] }, operation: { op: 'Supply', incomeKind: kind, receiptKind: 'manual',
    amountPerHumanCharacter: { stat: `input.${kind}.perCharacter` }, distributionWeights: kind === 'primary' ? { power: 1 } : { work: 1 } },
  resourceCost: [], inherit: 'never', repeat: { unit: 'receipt', limit: 1 } });
const native = Object.freeze({ rules: ['input.primary', 'input.work', 'native.shell-release', 'routing.transfer'], capabilities: [], modifiers: [], modes: [] });
const release: RuleDefinition = { id: 'native.shell-release', stage: 'finish', event: 'shell.finish', targetKind: 'shell',
  when: { any: ['release', 'thermal', 'fracture'].map(value => ({ objectProperty: 'endReason', comparison: 'eq', value })) },
  operation: { op: 'Release', unspentLotSelector: 'unspent', targetPolicy: 'original', exitClaim: 'close', onNoTarget: 'waitOnce' },
  resourceCost: [], inherit: 'paidProcessing', repeat: { unit: 'object', limit: 1 }, after: ['fracture.finish', 'storage.echo'] };
/** One input budget across all books; geometry redistributes it and new entrances share auxiliary income. */
export const NATIVE_RULES: RuleRegistry = Object.freeze<RuleRegistry>({ version: 1,
  rules: { ...LETTER_CONTENT.rules, ...STORAGE_CONTENT.rules, ...GUARD_CONTENT.rules, ...THERMAL_CONTENT.rules, ...RESERVE_CONTENT.rules,
    ...ROUTING_CONTENT.rules, ...FIELD_CONTENT.rules, ...COLD_CONTENT.rules, ...ONGOING_CONTENT.rules, ...MERGING_CONTENT.rules,
    'input.primary': supply('primary'), 'input.work': supply('work'), 'native.shell-release': release },
  numerics: {
    ...LETTER_CONTENT.numerics,
    ...STORAGE_CONTENT.numerics,
    ...GUARD_CONTENT.numerics,
    ...THERMAL_CONTENT.numerics,
    ...RESERVE_CONTENT.numerics,
    ...ROUTING_CONTENT.numerics,
    ...TARGETING_CONTENT.numerics,
    ...FIELD_CONTENT.numerics,
    ...COLD_CONTENT.numerics, ...ONGOING_CONTENT.numerics, ...MERGING_CONTENT.numerics, ...TRANSPORT_CONTENT.numerics,
    'input.primary.perCharacter': { id: 'input.primary.perCharacter', unit: 'power', base: 12 * RESOURCE_SCALE,
      min: 1, max: 120 * RESOURCE_SCALE, integer: true, stage: 'income', multiplierPools: ['efficiency'] },
    'input.work.perCharacter': { id: 'input.work.perCharacter', unit: 'work', base: RESOURCE_SCALE,
      min: 1, max: 10 * RESOURCE_SCALE, integer: true, stage: 'income', multiplierPools: ['efficiency'] },
  }, talents: { ...LETTER_CONTENT.talents, ...STORAGE_CONTENT.talents, ...GUARD_CONTENT.talents, ...THERMAL_CONTENT.talents, ...RESERVE_CONTENT.talents, ...ROUTING_CONTENT.talents, ...TARGETING_CONTENT.talents, ...FIELD_CONTENT.talents, ...COLD_CONTENT.talents, ...MERGING_CONTENT.talents, ...TRANSPORT_CONTENT.talents },
  relics: { ...LETTER_CONTENT.relics, ...STORAGE_CONTENT.relics, ...GUARD_CONTENT.relics, ...THERMAL_CONTENT.relics, ...RESERVE_CONTENT.relics, ...ROUTING_CONTENT.relics, ...TARGETING_CONTENT.relics, ...FIELD_CONTENT.relics, ...COLD_CONTENT.relics, ...ONGOING_CONTENT.relics, ...MERGING_CONTENT.relics, ...TRANSPORT_CONTENT.relics },
  legacyRelicIds: { ...LETTER_CONTENT.legacyRelicIds, ...STORAGE_CONTENT.legacyRelicIds, ...GUARD_CONTENT.legacyRelicIds, ...THERMAL_CONTENT.legacyRelicIds, ...COLD_CONTENT.legacyRelicIds, ...ONGOING_CONTENT.legacyRelicIds, ...TRANSPORT_CONTENT.legacyRelicIds },
  modeSlots: { ...LETTER_CONTENT.modeSlots, ...STORAGE_CONTENT.modeSlots, ...GUARD_CONTENT.modeSlots, ...THERMAL_CONTENT.modeSlots, ...RESERVE_CONTENT.modeSlots, ...TARGETING_CONTENT.modeSlots, ...FIELD_CONTENT.modeSlots, ...TRANSPORT_CONTENT.modeSlots, ...ROUTING_CONTENT.modeSlots },
  modeDefaults: { ...LETTER_CONTENT.modeDefaults, ...GUARD_CONTENT.modeDefaults, ...THERMAL_CONTENT.modeDefaults, ...RESERVE_CONTENT.modeDefaults, ...TRANSPORT_CONTENT.modeDefaults, ...ROUTING_CONTENT.modeDefaults },
  books: { frost: { ...native, rules: [...native.rules, ...COLD_ENTRY.rules, ...COLD_FIELD_ENTRY.rules], capabilities: ['cold', 'field'] },
    flame: { ...native, capabilities: ['heat', 'ongoing'], supplyDirections: [{ resource: 'heat', weight: 1 }] },
    storm: { ...native, capabilities: ROUTING_ENTRY.capabilities, supplyDirections: ROUTING_ENTRY.supplyDirections },
    spirit: { ...native, capabilities: ['copy', 'summon'], modifiers: [{ stat: 'summon.capacity', pool: 'add', unit: 'count', value: 2 }] } } });
