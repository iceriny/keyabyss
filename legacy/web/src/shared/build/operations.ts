import type { BuildDiagnostic } from '../../contracts/build-resources.ts';
import type { NumericDefinition, ObjectKind, OperationDefinition, Quantity, QuantityUnit, RuleDefinition, RuleEvent, RuleStage } from '../../contracts/build-rules.ts';
import { analyzeQuantity } from './quantities.ts';

export const eventStages: Readonly<Record<RuleEvent, readonly RuleStage[]>> = {
  'manual.complete': ['income', 'assemble', 'dispatch'], 'word.interrupted': ['income'], 'spell.assemble': ['assemble'], 'spell.dispatch': ['dispatch'],
  'hit.prepare': ['prepareHit'], 'hit.commit': ['commitHit'], 'hit.after': ['afterHit'],
  'shell.assemble': ['assemble'], 'shell.heat': ['prepareHit', 'afterHit'], 'shell.fracture': ['afterHit'], 'shell.finish': ['finish'], 'status.start': ['prepareHit'], 'status.contact': ['prepareHit'], 'status.tick': ['commitHit'],
  'status.finish': ['finish'], 'status.death': ['finish'], 'status.extract': ['assemble'], 'spell.finish': ['finish'], 'route.finish': ['finish'], 'projectile.intercept': ['prepareHit', 'commitHit'],
  'letter.match': ['income', 'assemble'], 'field.apply': ['commitHit'], 'field.relay': ['commitHit'], 'field.finish': ['finish'], 'room.finish': ['finish'], 'transport.finish': ['finish'],
};
const operationStages: Record<OperationDefinition['op'], readonly RuleStage[]> = {
  Supply: ['income'], Attach: ['assemble'], Allocate: ['assemble', 'prepareHit'], Store: ['assemble', 'dispatch'],
  Transfer: ['dispatch', 'afterHit', 'finish'], Heat: ['prepareHit', 'afterHit'], Fracture: ['afterHit', 'finish'],
  Release: ['finish'], Copy: ['assemble'], Merge: ['assemble', 'dispatch'], Recover: ['income', 'assemble', 'afterHit', 'finish'],
  Guard: ['prepareHit', 'commitHit'], Convert: ['income', 'assemble', 'finish'], Mark: ['income', 'afterHit'], Field: ['dispatch', 'prepareHit', 'afterHit'],
  Ongoing: ['prepareHit'],
};
const eventTargets: Record<RuleEvent, readonly ObjectKind[]> = {
  'manual.complete': ['spell'], 'word.interrupted': ['spell'], 'spell.assemble': ['spell'], 'spell.dispatch': ['spell'],
  'hit.prepare': ['spell'], 'hit.commit': ['spell', 'status', 'field'], 'hit.after': ['spell'],
  'shell.assemble': ['shell'], 'shell.heat': ['shell'], 'shell.fracture': ['shell'], 'shell.finish': ['shell'], 'status.tick': ['status'], 'status.finish': ['status'],
  'status.start': ['status'], 'status.contact': ['status'], 'status.death': ['status'], 'status.extract': ['status'], 'spell.finish': ['spell'], 'route.finish': ['spell'],
  'projectile.intercept': ['projectile', 'shell'], 'letter.match': ['spell'], 'field.apply': ['field'], 'field.relay': ['field'],
  'field.finish': ['field'], 'room.finish': ['spell', 'shell', 'status', 'field', 'reserve', 'letter'], 'transport.finish': ['shell'],
};
const targets = ['original', 'nearest', 'strongest', 'farthest', 'nextUnhit', 'player'];
const lots = ['self', 'stored', 'unspent', 'ongoing', 'reserve'];
const resources = ['power', 'work', 'cold', 'heat', 'charge', 'opportunity'];
const noTarget = ['waitOnce', 'recover', 'lose'];
const operationFields: Record<OperationDefinition['op'], readonly string[]> = {
  Supply: ['incomeKind', 'receiptKind', 'amountPerHumanCharacter', 'distributionWeights'],
  Attach: ['lotSelector', 'targetSelector', 'resource', 'amount'], Allocate: ['sourceLot', 'shares', 'maxChildren', 'remainderPolicy'],
  Store: ['shellArchetype', 'capacityUnits', 'releaseDelayTicks', 'lifeTicks', 'onNoCapacity'],
  Transfer: ['targetPolicy', 'maxDistance', 'hopCost', 'maxHops', 'onNoTarget'], Heat: ['thermalLot', 'shellSelector', 'amount', 'threshold', 'heatMode'],
  Fracture: ['integrityCost', 'allocationPattern', 'maxPieces', 'trigger'], Release: ['unspentLotSelector', 'targetPolicy', 'exitClaim', 'onNoTarget'],
  Copy: ['templateSelector', 'workCost', 'fundedPowerFactor', 'inheritMask', 'maxCopies'], Merge: ['compatibilityKey', 'sameRoot', 'maxInputs', 'waitTicks', 'outputPolicy'],
  Recover: ['remainingSelector', 'retention', 'capacityKey', 'reuseAfter'], Guard: ['projectileClass', 'selectionOrder', 'powerPerBlockedUnit', 'reserveShare', 'projectileClaim'],
  Convert: ['fromComponent', 'toComponent', 'share', 'rate', 'conversionStage'], Mark: ['positionSelector', 'matchPolicy', 'maxPositions', 'rewardAllocation', 'humanReceiptClaim'],
  Field: ['shape', 'radius', 'lifeTicks', 'maxApplications', 'lotAllocation', 'onFinish'],
  Ongoing: ['action'],
};

/** Each case is a registered engine operation, not a content-provided executable callback. */
export function validateOperation(rule: RuleDefinition, numerics: Readonly<Record<string, NumericDefinition>>): BuildDiagnostic[] {
  const errors: BuildDiagnostic[] = [];
  const fail = (path: string, message: string, code: BuildDiagnostic['code'] = 'INVALID_DEFINITION') => errors.push({ code, definitionId: rule.id, path, message });
  const q = (value: Quantity, unit: QuantityUnit, path: string, min = 0, max = Number.MAX_SAFE_INTEGER) => {
    const result = analyzeQuantity(value, numerics, rule.id);
    if (!result.ok) { errors.push(...result.errors.map(e => ({ ...e, path: `${path}.${e.path}` }))); return; }
    if (result.value.unit !== unit) fail(path, `Expected ${unit}, got ${result.value.unit}`, 'INVALID_UNIT');
    if (result.value.min < min || result.value.max > max) fail(path, `Quantity range must remain within [${min}, ${max}]`, 'INVALID_QUANTITY');
  };
  const choice = (value: unknown, values: readonly unknown[], path: string) => { if (!values.includes(value)) fail(path, 'Unknown operation option'); };
  const op = rule.operation;
  if (!op || !Object.hasOwn(operationStages, op.op)) { fail('operation', 'Unknown or unimplemented operation'); return errors; }
  const optionalFields = op.op === 'Store' ? ['share', 'retention'] : op.op === 'Copy' ? ['storage']
    : op.op === 'Recover' ? ['resource', 'share'] : op.op === 'Attach' ? ['reserveShare', 'reserveLimit', 'reserveBurst']
    : op.op === 'Allocate' ? ['resourceShares', 'shape', 'applications'] : op.op === 'Field' ? ['share', 'resourceShares']
    : op.op === 'Mark' ? ['opportunityCost', 'maxPerWord', 'rewardPlan'] : op.op === 'Guard' ? ['maxInputs'] : [];
  const requiredFields = op.op === 'Ongoing' ? ['action', ...(op.action === 'advance' ? ['applications'] : ['coldCost', 'extraTicks', 'maxDelayTicks'])]
    : operationFields[op.op];
  if (Object.keys(op).some(key => key !== 'op' && !requiredFields.includes(key) && !optionalFields.includes(key))
      || requiredFields.some(key => !Object.hasOwn(op, key))) fail('operation', 'Unknown or missing operation field');
  if (!eventStages[rule.event]?.includes(rule.stage) || !operationStages[op.op].includes(rule.stage)) fail('stage', 'Operation/event is unavailable at this stage');
  if (!eventTargets[rule.event]?.includes(rule.targetKind)) fail('targetKind', 'Event and object kind do not match');
  if (!Number.isSafeInteger(rule.repeat?.limit) || rule.repeat.limit < 1 || rule.repeat.limit > 64
      || !['receipt', 'lot', 'object', 'enemyProjectile'].includes(rule.repeat?.unit)) {
    fail('repeat', 'A finite claim unit and limit in [1,64] are required', 'UNBOUNDED_RULE_CYCLE'); return errors;
  }
  choice(rule.inherit, ['never', 'shape', 'paidProcessing'], 'inherit');
  if (!Array.isArray(rule.resourceCost)) fail('resourceCost', 'Expected typed resource costs');
  else for (const [i, cost] of rule.resourceCost.entries()) {
    choice(cost.resource, resources, `resourceCost[${i}].resource`);
    q(cost.amount, cost.resource, `resourceCost[${i}].amount`);
  }
  switch (op.op) {
    case 'Supply': {
      choice(op.incomeKind, ['primary', 'work'], 'incomeKind');
      if (op.receiptKind !== 'manual' || rule.event !== 'manual.complete' || rule.repeat.unit !== 'receipt' || rule.inherit !== 'never') fail('Supply', 'Income requires a unique human completion receipt');
      if (rule.repeat.limit !== 1 || rule.resourceCost.length) fail('Supply', 'One atomic receipt cannot repeat or charge itself');
      q(op.amountPerHumanCharacter, op.incomeKind === 'primary' ? 'power' : 'work', 'amountPerHumanCharacter', 0, 1024 * 1_000_000);
      const weights = Object.entries(op.distributionWeights ?? {});
      if (!weights.length || weights.some(([resource, weight]) => !resources.includes(resource) || !Number.isFinite(weight) || weight < 0)
          || Math.abs(weights.reduce((sum, [, weight]) => sum + weight, 0) - 1) > 1e-10) fail('distributionWeights', 'Income allocation weights must sum to one');
      if (op.incomeKind === 'primary' && weights.some(([key]) => key !== 'power')) fail('distributionWeights', 'Primary power is allocated only to its power account');
      break;
    }
    case 'Attach':
      choice(op.lotSelector, lots, 'lotSelector'); choice(op.targetSelector, ['spell', 'shell', 'status', 'field', 'reserve'], 'targetSelector');
      if (op.reserveShare !== undefined) q(op.reserveShare, 'ratio', 'reserveShare', Number.EPSILON, 1);
      if (op.reserveLimit !== undefined) q(op.reserveLimit, 'power', 'reserveLimit', 1);
      if ((op.reserveShare !== undefined || op.reserveLimit !== undefined) && op.lotSelector !== 'reserve') fail('reserveShare', 'Reserve policy requires the reserve selector');
      if (op.reserveBurst !== undefined) {
        const burst = op.reserveBurst, fields = ['minimumTargetRatio', 'share', 'totalLimit', 'cooldownManuals'];
        if (op.lotSelector !== 'reserve' || op.reserveLimit === undefined || !burst || typeof burst !== 'object' || Array.isArray(burst)
          || Object.keys(burst).some(key => !fields.includes(key)) || fields.some(key => !Object.hasOwn(burst, key)))
          fail('reserveBurst', 'Burst requires a complete reserve policy and a shared normal limit');
        else {
          q(burst.minimumTargetRatio, 'ratio', 'reserveBurst.minimumTargetRatio', 1, 1_000_000);
          q(burst.share, 'ratio', 'reserveBurst.share', Number.EPSILON, 1);
          q(burst.totalLimit, 'power', 'reserveBurst.totalLimit', 1, 1024 * 1_000_000_000);
          q(burst.cooldownManuals, 'count', 'reserveBurst.cooldownManuals', 1, 64);
        }
      }
      if (op.lotSelector === 'reserve' && (op.targetSelector !== 'spell' || op.resource === 'work' || op.resource === 'opportunity'))
        fail('lotSelector', 'Reserves attach material or power only to a later manual spell');
      choice(op.resource, resources, 'resource'); q(op.amount, op.resource, 'amount'); break;
    case 'Allocate':
      choice(op.sourceLot, lots, 'sourceLot'); choice(op.remainderPolicy, ['parent', 'firstChild', 'loss'], 'remainderPolicy');
      if (op.shape !== undefined) choice(op.shape, ['shot', 'chain', 'pierce', 'burst', 'blade'], 'shape');
      if (op.applications !== undefined) q(op.applications, 'count', 'applications', 1, 64);
      if (op.resourceShares !== undefined && (!op.resourceShares || typeof op.resourceShares !== 'object' || Array.isArray(op.resourceShares)
          || Object.entries(op.resourceShares).some(([resource, shares]) => !resources.includes(resource) || !Array.isArray(shares)
            || shares.length !== op.shares?.length || Array.from(shares).some(n => !Number.isFinite(n) || n < 0 || n > 1)
            || shares.reduce((a, b) => a + b, 0) > 1 + 1e-10))) fail('resourceShares', 'Material shares must fit the same children and source balance');
      if (!Number.isSafeInteger(op.maxChildren) || op.maxChildren < 1 || op.maxChildren > 64 || !Array.isArray(op.shares)
          || !op.shares.length || op.shares.length > op.maxChildren || Array.from(op.shares).some(n => !Number.isFinite(n) || n <= 0)
          || op.shares.reduce((a, b) => a + b, 0) > 1 + 1e-10) fail('shares', 'Splits require finite positive shares within the parent balance');
      break;
    case 'Store':
      choice(op.shellArchetype, ['crystal', 'paper'], 'shellArchetype'); choice(op.onNoCapacity, ['retain', 'lose'], 'onNoCapacity');
      if (op.share !== undefined) q(op.share, 'ratio', 'share', Number.EPSILON, 1);
      if (op.retention !== undefined) q(op.retention, 'ratio', 'retention', Number.EPSILON, 1);
      q(op.capacityUnits, 'count', 'capacityUnits', 1, 64); q(op.releaseDelayTicks, 'ticks', 'releaseDelayTicks', 0, 72000);
      q(op.lifeTicks, 'ticks', 'lifeTicks', 1, 72000); break;
    case 'Transfer':
      choice(op.targetPolicy, targets, 'targetPolicy'); choice(op.onNoTarget, noTarget, 'onNoTarget');
      q(op.maxDistance, 'distance', 'maxDistance', 0, 10000); q(op.hopCost, 'charge', 'hopCost', 1);
      q(op.maxHops, 'count', 'maxHops', 1, 32); break;
    case 'Heat':
      choice(op.thermalLot, lots, 'thermalLot'); choice(op.shellSelector, ['self', 'nearest'], 'shellSelector'); choice(op.heatMode, ['open', 'retain', 'fracture'], 'heatMode');
      q(op.amount, 'heat', 'amount', 1); q(op.threshold, 'heat', 'threshold', 1); break;
    case 'Fracture':
      choice(op.allocationPattern, ['radial', 'aimed'], 'allocationPattern'); choice(op.trigger, ['hit', 'heat', 'finish'], 'trigger');
      if ((op.trigger === 'heat' && rule.event !== 'shell.fracture') || (op.trigger === 'hit' && rule.event !== 'hit.after')
        || (op.trigger === 'finish' && !['shell.finish', 'room.finish'].includes(rule.event))) fail('trigger', 'Fracture trigger and event must agree');
      q(op.integrityCost, 'count', 'integrityCost', 1); q(op.maxPieces, 'count', 'maxPieces', 1, 64); break;
    case 'Release':
      choice(op.unspentLotSelector, ['unspent'], 'unspentLotSelector'); choice(op.targetPolicy, targets, 'targetPolicy'); choice(op.exitClaim, ['close'], 'exitClaim');
      choice(op.onNoTarget, noTarget, 'onNoTarget'); break;
    case 'Copy':
      choice(op.templateSelector, ['manualSpell', 'storedSpell'], 'templateSelector'); q(op.workCost, 'work', 'workCost', 1);
      q(op.fundedPowerFactor, 'ratio', 'fundedPowerFactor', 0, 1); q(op.maxCopies, 'count', 'maxCopies', 1, 32);
      if (!Array.isArray(op.inheritMask) || new Set(op.inheritMask).size !== op.inheritMask.length || op.inheritMask.some(v => !['shape', 'cold', 'heat', 'charge'].includes(v))) fail('inheritMask', 'Copy inherits only registered shape/material properties');
      if (rule.inherit === 'shape') fail('inherit', 'Executing a copy requires paid processing');
      if (op.storage !== undefined) {
        const storage = op.storage;
        if (!storage || Object.keys(storage).some(key => !['shellArchetype', 'capacityUnits', 'releaseDelayTicks', 'lifeTicks'].includes(key))) {
          fail('storage', 'Invalid stored copy output'); break;
        }
        choice(storage.shellArchetype, ['crystal', 'paper'], 'storage.shellArchetype');
        q(storage.capacityUnits, 'count', 'storage.capacityUnits', 1, 64);
        q(storage.releaseDelayTicks, 'ticks', 'storage.releaseDelayTicks', 0, 72000);
        q(storage.lifeTicks, 'ticks', 'storage.lifeTicks', 1, 72000);
      }
      break;
    case 'Merge':
      choice(op.compatibilityKey, ['shapeAndTarget'], 'compatibilityKey'); choice(op.outputPolicy, ['concentrate', 'preserveShape'], 'outputPolicy');
      if (op.sameRoot !== true) fail('sameRoot', 'Cross-receipt Merge is not enabled');
      if (!['spell', 'shell'].includes(rule.targetKind)) fail('targetKind', 'Merge requires an unlaunched spell or stored shell');
      q(op.maxInputs, 'count', 'maxInputs', 2, 64); q(op.waitTicks, 'ticks', 'waitTicks', 0, 72000); break;
    case 'Recover': {
      choice(op.remainingSelector, ['self', 'stored', 'unspent', 'ongoing'], 'remainingSelector'); choice(op.reuseAfter, ['nextManual', 'nextRoom'], 'reuseAfter');
      if (op.resource !== undefined) choice(op.resource, ['power', 'cold', 'heat', 'charge'], 'resource');
      if (op.share !== undefined) q(op.share, 'ratio', 'share', Number.EPSILON, 1);
      q(op.retention, 'ratio', 'retention', 0, .7);
      const capacity = numerics[op.capacityKey];
      if (!capacity || capacity.unit !== 'power' || capacity.min < 0) fail('capacityKey', 'Recovery requires a registered power capacity');
      break;
    }
    case 'Guard':
      choice(op.projectileClass, ['reflectable'], 'projectileClass'); choice(op.selectionOrder, ['oldest', 'newest'], 'selectionOrder'); choice(op.projectileClaim, ['once'], 'projectileClaim');
      if (op.maxInputs !== undefined) q(op.maxInputs, 'count', 'maxInputs', 1, 8);
      q(op.powerPerBlockedUnit, 'ratio', 'powerPerBlockedUnit', Number.EPSILON, 16); q(op.reserveShare, 'ratio', 'reserveShare', 0, 1); break;
    case 'Convert':
      choice(op.fromComponent, resources, 'fromComponent'); choice(op.toComponent, resources, 'toComponent');
      if (op.fromComponent === op.toComponent || op.conversionStage !== rule.stage) fail('conversionStage', 'Conversion requires distinct units and its registered stage');
      if (op.toComponent === 'work') fail('toComponent', 'Work comes from the human income allocation, never recycled conversion');
      if (op.fromComponent === 'opportunity' || op.toComponent === 'opportunity') fail('toComponent', 'Only real input can redeem an earned character opportunity');
      q(op.share, 'ratio', 'share', 0, 1); q(op.rate, 'ratio', 'rate', Number.EPSILON, 16); break;
    case 'Mark': {
      if (rule.repeat.unit !== 'receipt' || rule.repeat.limit !== 1 || rule.inherit !== 'never'
        || rule.resourceCost.some(cost => cost.resource !== 'work')) fail('Mark', 'Character marking consumes earned opportunities once per root, with optional work fees');
      choice(op.positionSelector, ['nextWord', 'nearbyWords'], 'positionSelector'); choice(op.matchPolicy, ['manualOnly'], 'matchPolicy');
      choice(op.rewardAllocation, ['power', 'work', 'guard'], 'rewardAllocation'); choice(op.humanReceiptClaim, ['once'], 'humanReceiptClaim');
      q(op.maxPositions, 'count', 'maxPositions', 1, 64);
      if (op.opportunityCost !== undefined) q(op.opportunityCost, 'opportunity', 'opportunityCost', 1, 64 * 1024);
      if (op.maxPerWord !== undefined) q(op.maxPerWord, 'count', 'maxPerWord', 1, 72);
      if ((op.opportunityCost !== undefined || op.maxPerWord !== undefined) && !op.rewardPlan)
        fail('rewardPlan', 'Explicit opportunity policies require a frozen power reward plan');
      if (op.rewardPlan !== undefined) {
        const plan = op.rewardPlan, fields = ['storedShare', 'workShare', 'storedRetention', 'workRetention', 'capacityUnits', 'releaseDelayTicks', 'lifeTicks', 'inheritShape'];
        if (op.rewardAllocation !== 'power' || !plan || typeof plan !== 'object' || Array.isArray(plan)
          || Object.keys(plan).some(key => !fields.includes(key)) || fields.some(key => !Object.hasOwn(plan, key))) {
          fail('rewardPlan', 'A split power reward requires a complete typed allocation'); break;
        }
        q(plan.storedShare, 'ratio', 'rewardPlan.storedShare', 0, 1); q(plan.workShare, 'ratio', 'rewardPlan.workShare', 0, 1);
        q({ add: [plan.storedShare, plan.workShare] }, 'ratio', 'rewardPlan.totalShare', 0, 1);
        q(plan.storedRetention, 'ratio', 'rewardPlan.storedRetention', 0, 1); q(plan.workRetention, 'ratio', 'rewardPlan.workRetention', 0, 1);
        q(plan.capacityUnits, 'count', 'rewardPlan.capacityUnits', 1, 64); q(plan.releaseDelayTicks, 'ticks', 'rewardPlan.releaseDelayTicks', 1, 72000);
        q(plan.lifeTicks, 'ticks', 'rewardPlan.lifeTicks', 1, 72000); choice(plan.inheritShape, [true, false], 'rewardPlan.inheritShape');
      }
      break;
    }
    case 'Field':
      choice(op.shape, ['circle', 'trail'], 'shape'); choice(op.lotAllocation, ['equal', 'onContact'], 'lotAllocation'); choice(op.onFinish, ['recover', 'lose'], 'onFinish');
      if (op.share !== undefined) q(op.share, 'ratio', 'share', 0, 1);
      if (op.resourceShares !== undefined && (!op.resourceShares || typeof op.resourceShares !== 'object' || Array.isArray(op.resourceShares)
        || ![Object.prototype, null].includes(Object.getPrototypeOf(op.resourceShares))
        || Object.entries(op.resourceShares).some(([key, share]) => !resources.includes(key) || !Number.isFinite(share) || share < 0 || share > 1)))
        fail('resourceShares', 'Expected known materials with fractions in [0,1]');
      q(op.radius, 'distance', 'radius', 1, 10000); q(op.lifeTicks, 'ticks', 'lifeTicks', 1, 72000); q(op.maxApplications, 'count', 'maxApplications', 1, 1024); break;
    case 'Ongoing':
      choice(op.action, ['advance', 'delay'], 'action');
      if (rule.targetKind !== 'status' || !['status.start', 'status.contact'].includes(rule.event)) fail('targetKind', 'Ongoing processing requires an owned status boundary');
      if (op.action === 'advance') q(op.applications, 'count', 'applications', 1, 64);
      else if (op.action === 'delay') {
        q(op.coldCost, 'cold', 'coldCost', 1, 1024 * 1_000_000);
        q(op.extraTicks, 'ticks', 'extraTicks', 1, 72000); q(op.maxDelayTicks, 'ticks', 'maxDelayTicks', 1, 72000);
      }
      break;
  }
  return errors;
}
