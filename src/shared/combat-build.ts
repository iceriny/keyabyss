import type { CombatStats } from '../contracts/stats.ts';
import type { BuildProgram, SpellBlueprint, SpellElement, SpellShape } from '../contracts/combat-weave.ts';

const implemented = new Set([
  'carrierCapacity', 'copyEfficiency', 'materialRate', 'heatCapacity', 'recoveryEfficiency',
  'recoveryExtract', 'fragmentCount', 'fragmentShare', 'chainCount', 'chainShare',
  'chainReach', 'carrierLifetime', 'carrierDelay', 'thermalRelease', 'carrierRetain',
  'carrierRelay', 'crystalStorage', 'mergePayload', 'markCarrier', 'markSpread',
  'summonTransport', 'singleFrost', 'singleFlame', 'singleStorm', 'singleSpirit',
  'copyInheritance', 'guardEfficiency', 'reactionEfficiency', 'paperRecovery', 'missRecovery',
  'guardNewest', 'reservePersist', 'payloadPierce', 'spellPower',
  'reserveThreshold', 'copyCadence', 'secondaryBinding', 'singleFocus', 'carrierRelease',
  'carrierGuard', 'heatRecovery', 'crystalPayload', 'heatPayload', 'conductionPayload',
  'copyPages', 'swiftBinding', 'scatterPages', 'heavyPages', 'materialConserve',
  'concentrate', 'forkPayload',
]);
const newStats = new Set([
  'carrierCapacity', 'copyEfficiency', 'materialRate', 'heatCapacity', 'recoveryEfficiency',
  'recoveryExtract', 'fragmentCount', 'fragmentShare', 'chainCount', 'chainShare',
  'chainReach', 'carrierLifetime', 'carrierDelay', 'thermalRelease', 'carrierRetain',
  'carrierRelay', 'crystalStorage', 'mergePayload', 'concentrate', 'forkPayload',
  'guardNewest', 'reservePersist', 'payloadPierce', 'markCarrier', 'markSpread',
  'summonTransport', 'singleFrost', 'singleFlame', 'singleStorm', 'singleSpirit',
  'copyInheritance', 'guardEfficiency', 'spellPower', 'materialConserve',
  'reactionEfficiency', 'paperRecovery', 'missRecovery', 'reserveThreshold', 'copyCadence',
]);
const clamp = (value: number, low: number, high: number) => Math.min(high, Math.max(low, Number.isFinite(value) ? value : 0));

/** Pure, immutable rule snapshot. Numeric combat stats remain in the regular damage system. */
export function compileBuild(input: { stats: CombatStats; element: SpellElement; secondary?: SpellElement; nativeChain?: number }): BuildProgram {
  const s = input.stats;
  const shape: SpellShape = input.element === 'ice' ? 'pierce' : input.element === 'fire' ? 'burst' : input.element === 'storm' ? 'chain' : 'blade';
  const active = Object.entries(s).filter(([, n]) => n !== 0).map(([key]) => key);
  const secondary = s.secondaryBinding && !s.singleFocus ? input.secondary : undefined;
  const singleFrost = !!s.singleFocus && input.element === 'ice' && !!s.singleFrost;
  const singleFlame = !!s.singleFocus && input.element === 'fire' && !!s.singleFlame;
  const singleStorm = !!s.singleFocus && input.element === 'storm' && !!s.singleStorm;
  const singleSpirit = !!s.singleFocus && input.element === 'paper' && !!s.singleSpirit;
  const nativeSegments = Math.max(1, Math.floor(input.nativeChain || 1) - (singleStorm ? 1 : 0));
  const blueprint: SpellBlueprint = Object.freeze({
    element: input.element, shape,
    operations: Object.freeze([
      ...(shape === 'pierce' ? ['pierce'] as const : []),
      ...(shape === 'chain' ? ['conduct'] as const : []),
      ...(shape === 'burst' ? ['burn'] as const : []),
      'split', 'store', 'release',
    ] as const), nativeSegments,
  });
  const heavy = !!s.heavyPages, scatter = !!s.scatterPages;
  const baseCapacity = heavy ? 1 : scatter ? 6 : s.copyPages >= 2 ? 3 : 1;
  return Object.freeze({
    blueprint, secondary,
    materialRate: clamp(1 + s.materialRate, 0, 4),
    processingRetention: clamp(.85 + s.materialConserve, .3, 1),
    copyRate: clamp((s.copyPages + (secondary === 'paper' ? 1 : 0)) * (scatter ? 2 : 1), 0, 8),
    copyCost: clamp(12 - s.copyCadence - (s.swiftBinding ? 4 : 0), 3, 24),
    carrierCapacity: clamp(baseCapacity + s.carrierCapacity + (singleSpirit ? 2 : 0), 0, 16),
    carrierLife: clamp((s.swiftBinding ? 1 : 5) + s.carrierLifetime, .2, 20),
    carrierDelay: clamp((s.swiftBinding ? .5 : 1.8) + s.carrierDelay, 0, 20),
    carrierRelease: !!s.carrierRelease,
    carrierGuard: !!s.carrierGuard,
    carrierRetain: !!s.carrierRetain,
    carrierRelay: !!s.carrierRelay,
    crystalStorage: !!s.crystalStorage,
    mergePayload: !!s.mergePayload,
    guardNewest: !!s.guardNewest,
    guardEfficiency: clamp(s.guardEfficiency, 0, .9),
    thermalRelease: !!s.thermalRelease,
    fragmentCount: clamp(Math.floor(3 + s.fragmentCount + s.forkPayload - s.concentrate - (singleFrost ? 1 : 0)), 0, 16),
    fragmentShare: clamp(.45 + s.fragmentShare, 0, .8),
    chainCount: clamp(Math.floor(2 + s.chainCount + s.forkPayload + (shape === 'chain' ? nativeSegments - 1 : 0) - s.concentrate - (singleStorm ? 1 : 0)), 0, 16),
    chainShare: clamp(.4 + s.chainShare, 0, .8),
    chainReach: clamp(340 + s.chainReach, 0, 1200),
    recoveryRate: clamp(.2 + .15 * s.heatRecovery + s.recoveryEfficiency, 0, .85),
    recoveryEligible: s.heatRecovery > 0 || singleFlame,
    recoveryCapacity: clamp(20 + 40 * s.heatRecovery + s.heatCapacity, 0, 1000),
    recoveryExtract: !!s.recoveryExtract || singleFlame,
    reservePersist: !!s.reservePersist,
    reserveThreshold: Math.max(0, s.reserveThreshold + (singleFlame ? 5 : 0)),
    spellPower: clamp(1 + s.spellPower, 0, 8),
    copyInheritance: !!s.copyInheritance,
    reactionEfficiency: clamp(s.reactionEfficiency, -.9, 2),
    paperRecovery: !!s.paperRecovery,
    missRecovery: !!s.missRecovery,
    markCarrier: !!s.markCarrier,
    markSpread: !!s.markSpread,
    summonTransport: !!s.summonTransport || singleSpirit,
    payloadPierce: clamp(Math.floor(s.payloadPierce + (singleFrost ? 2 : 0)), 0, 12),
    sources: Object.freeze(active.filter(key => implemented.has(key))),
    unimplemented: Object.freeze(active.filter(key => newStats.has(key) && !implemented.has(key))),
  });
}
