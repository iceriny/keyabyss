import { ruleStages, BUILD_RULE_VERSION } from '../../contracts/build-rules.ts';
import type { BuildContribution, BuildOverride, BuildSnapshot, CapabilityId, CompiledRule, CompiledRuleProgram,
  Condition, ConditionState, ModeChoice, NumericDefinition, PermitId, RuleDefinition, RuleRegistry } from '../../contracts/build-rules.ts';
import type { BuildDiagnostic, Decision } from '../../contracts/build-resources.ts';
import { capabilities, evaluateCondition, validateCondition } from './conditions.ts';
import { validateOperation } from './operations.ts';

const idPattern = /^[A-Za-z][A-Za-z0-9:._-]*$/;
function freeze<T>(value: T): T {
  if (value && typeof value === 'object' && !Object.isFrozen(value)) {
    for (const nested of Object.values(value)) freeze(nested);
    Object.freeze(value);
  }
  return value;
}
function references(condition: Condition): { talents: string[]; relics: string[]; permits: PermitId[]; modes: ModeChoice[] } {
  const found = { talents: [] as string[], relics: [] as string[], permits: [] as PermitId[], modes: [] as ModeChoice[] };
  const visit = (c: Condition) => {
    if ('all' in c) c.all.forEach(visit);
    else if ('any' in c) c.any.forEach(visit);
    else if ('not' in c) visit(c.not);
    else if ('allocated' in c) found.talents.push(c.allocated);
    else if ('owned' in c) found.relics.push(c.owned);
    else if ('permit' in c) found.permits.push(c.permit);
    else if ('mode' in c) found.modes.push({ slot: c.mode, value: c.value });
  };
  visit(condition); return found;
}

/** Whole-catalog validation also checks definitions absent from the current player's build. */
export function validateRuleRegistry(registry: RuleRegistry): readonly BuildDiagnostic[] {
  const errors: BuildDiagnostic[] = [];
  const fail = (id: string, path: string, message: string, code: BuildDiagnostic['code'] = 'INVALID_DEFINITION') => errors.push({ code, definitionId: id, path, message });
  if (registry.version !== BUILD_RULE_VERSION) fail('registry', 'version', 'Unsupported rule version');
  for (const [slot, value] of Object.entries(registry.modeDefaults ?? {}))
    if (!registry.modeSlots[slot]?.includes(value)) fail('registry', 'modeDefaults', 'Unknown default mode');
  for (const [key, stat] of Object.entries(registry.numerics)) {
    if (key !== stat.id || !idPattern.test(key)) fail(key, 'id', 'Invalid numeric ID');
    if (![stat.base, stat.min, stat.max].every(Number.isFinite) || stat.base < stat.min || stat.base > stat.max
        || stat.min > stat.max || Math.max(Math.abs(stat.min), Math.abs(stat.max)) > Number.MAX_SAFE_INTEGER
        || (stat.integer && ![stat.min, stat.max, stat.base].every(Number.isSafeInteger))) fail(key, 'range', 'Invalid numeric range');
    if (!ruleStages.includes(stat.stage) || !['ratio', 'count', 'ticks', 'distance', 'power', 'work', 'cold', 'heat', 'charge', 'opportunity'].includes(stat.unit)) fail(key, 'unit', 'Unregistered numeric unit/stage');
    if (new Set(stat.multiplierPools).size !== stat.multiplierPools.length || stat.multiplierPools.some(pool => !idPattern.test(pool) || pool === 'add')) fail(key, 'multiplierPools', 'Invalid multiplier pools');
  }
  const allPermits = new Set(Object.values(registry.talents).flatMap(t => t.permits));
  const checkCondition = (id: string, condition: Condition, context: 'purchase' | 'acquisition' | 'runtime') => {
    const problems = validateCondition(condition, context, id); errors.push(...problems);
    if (problems.length) return;
    const refs = references(condition);
    for (const talent of refs.talents) if (!Object.hasOwn(registry.talents, talent)) fail(id, 'condition', `Unknown talent ${talent}`, 'UNKNOWN_DEFINITION');
    for (const relic of refs.relics) if (!Object.hasOwn(registry.relics, relic)) fail(id, 'condition', `Unknown relic ${relic}`, 'UNKNOWN_DEFINITION');
    for (const permit of refs.permits) if (!allPermits.has(permit)) fail(id, 'condition', `Unknown permit ${permit}`, 'UNKNOWN_DEFINITION');
    for (const mode of refs.modes) if (!registry.modeSlots[mode.slot]?.includes(mode.value)) fail(id, 'condition', `Unknown mode ${mode.slot}:${mode.value}`, 'UNKNOWN_DEFINITION');
  };
  for (const [key, rule] of Object.entries(registry.rules)) {
    if (key !== rule.id || !idPattern.test(key)) fail(key, 'id', 'Invalid rule ID');
    checkCondition(key, rule.when, 'runtime');
    errors.push(...validateOperation(rule, registry.numerics));
    if (!!rule.modeSlot !== !!rule.modeValue || (rule.modeSlot && !registry.modeSlots[rule.modeSlot]?.includes(rule.modeValue!))) fail(key, 'modeSlot', 'Unknown rule mode');
    for (const dependency of rule.after ?? []) {
      const before = registry.rules[dependency];
      if (!before) fail(key, 'after', `Unknown rule ${dependency}`, 'UNKNOWN_DEFINITION');
      else if (ruleStages.indexOf(before.stage) > ruleStages.indexOf(rule.stage)) fail(key, 'after', 'Rule depends on a later stage', 'INVALID_RULE_ORDER');
    }
  }
  const checkContribution = (id: string, contribution: BuildContribution) => {
    errors.push(...validateSupplyDirections(id, contribution, registry));
    if (new Set(contribution.rules).size !== contribution.rules.length) fail(id, 'rules', 'Repeated rule in one definition');
    for (const rule of contribution.rules) if (!Object.hasOwn(registry.rules, rule)) fail(id, 'rules', `Unknown rule ${rule}`, 'UNKNOWN_DEFINITION');
    for (const capability of contribution.capabilities) if (!(capabilities as readonly string[]).includes(capability)) fail(id, 'capabilities', 'Unknown capability');
    for (const modifier of contribution.modifiers) {
      const stat = registry.numerics[modifier.stat];
      if (!stat) { fail(id, 'modifiers', `Unknown numeric ${modifier.stat}`, 'UNKNOWN_DEFINITION'); continue; }
      if (!Number.isFinite(modifier.value) || Math.abs(modifier.value) > Number.MAX_SAFE_INTEGER) fail(id, 'modifiers', 'Invalid numeric value');
      if (modifier.pool === 'add') {
        if (modifier.unit !== stat.unit || (stat.integer && !Number.isSafeInteger(modifier.value))) fail(id, 'modifiers', 'Additive modifier has incompatible units', 'INVALID_UNIT');
      } else if (modifier.unit !== 'ratio' || !stat.multiplierPools.includes(modifier.pool)) fail(id, 'modifiers', 'Unknown or dimensional multiplier pool', 'INVALID_UNIT');
    }
    for (const mode of contribution.modes) if (!registry.modeSlots[mode.slot]?.includes(mode.value)) fail(id, 'modes', 'Unknown mode choice');
  };
  for (const [book, contribution] of Object.entries(registry.books)) checkContribution(`book:${book}`, contribution);
  for (const book of ['flame', 'storm', 'frost', 'spirit']) if (!Object.hasOwn(registry.books, book)) fail(book, 'books', 'Missing native book rules');
  for (const [key, talent] of Object.entries(registry.talents)) {
    if (key !== talent.id || !idPattern.test(key) || !Number.isSafeInteger(talent.cost) || talent.cost < 0) fail(key, 'id/cost', 'Invalid talent identity/cost');
    checkCondition(key, talent.purchaseRequires, 'purchase'); checkContribution(key, talent);
    if (talent.permits.some(permit => permit !== `permit:talent:${talent.id}`)) fail(key, 'permits', 'Talent may issue only its own permit');
    for (const [slot, choices] of Object.entries(talent.selectableModes ?? {})) {
      if (!choices.length || new Set(choices).size !== choices.length || choices.some(v => !registry.modeSlots[slot]?.includes(v))) fail(key, 'selectableModes', 'Invalid selectable modes');
    }
  }
  for (const [key, relic] of Object.entries(registry.relics)) {
    if (key !== relic.id || !idPattern.test(key) || !Number.isSafeInteger(relic.maxLevel) || relic.maxLevel < 1) fail(key, 'id/maxLevel', 'Invalid relic identity/levels');
    checkCondition(key, relic.eligibility, 'acquisition'); checkContribution(key, relic);
    for (const permit of relic.permitsAll) if (!allPermits.has(permit)) fail(key, 'permitsAll', `Unknown permit ${permit}`, 'UNKNOWN_DEFINITION');
    for (const parent of relic.evolutionFrom ?? []) if (parent === key || !Object.hasOwn(registry.relics, parent)) fail(key, 'evolutionFrom', 'Unknown or self evolution');
  }
  // A dependency cycle is invalid even if none of its rules are currently equipped.
  for (const [oldId, id] of Object.entries(registry.legacyRelicIds ?? {})) {
    if (!idPattern.test(oldId) || !Object.hasOwn(registry.relics, id)) fail(oldId, 'legacyRelicIds', 'Unknown relic migration target');
  }
  errors.push(...orderRules(Object.values(registry.rules)).errors);
  return errors;
}

function orderRules(rules: readonly RuleDefinition[]): { rules: RuleDefinition[]; errors: BuildDiagnostic[] } {
  const ordered: RuleDefinition[] = [], errors: BuildDiagnostic[] = [];
  const present = new Set(rules.map(rule => rule.id));
  for (const stage of ruleStages) {
    const remaining = rules.filter(rule => rule.stage === stage).sort((a, b) => a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
    while (remaining.length) {
      const index = remaining.findIndex(rule => (rule.after ?? []).every(id => !present.has(id) || ordered.some(before => before.id === id)));
      if (index < 0) { errors.push({ code: 'UNBOUNDED_RULE_CYCLE', path: 'after', message: `Cyclic rule order: ${remaining.map(r => r.id).join(', ')}` }); break; }
      ordered.push(remaining.splice(index, 1)[0]);
    }
  }
  return { rules: ordered, errors };
}

type Sourced = { id: string; contribution: BuildContribution; level: number };
function compileNumerics(registry: RuleRegistry, sources: readonly Sourced[], errors: BuildDiagnostic[]): Record<string, number> {
  const result: Record<string, number> = {};
  for (const stat of Object.values(registry.numerics)) {
    let value = stat.base;
    const multipliers = new Map(stat.multiplierPools.map(pool => [pool, 1]));
    for (const source of sources) for (const modifier of source.contribution.modifiers) {
      if (modifier.stat !== stat.id) continue;
      if (modifier.pool === 'add') value += modifier.value * source.level;
      else multipliers.set(modifier.pool, multipliers.get(modifier.pool)! + modifier.value * source.level);
    }
    for (const factor of multipliers.values()) {
      if (factor < 0) errors.push({ code: 'INVALID_QUANTITY', definitionId: stat.id, message: 'Multiplier pool cannot reverse a resource quantity' });
      value *= factor;
    }
    if (!Number.isFinite(value) || Math.abs(value) > Number.MAX_SAFE_INTEGER) errors.push({ code: 'INVALID_QUANTITY', definitionId: stat.id, message: 'Numeric pool overflow' });
    result[stat.id] = stat.integer ? Math.floor(Math.max(stat.min, Math.min(stat.max, value))) : Math.max(stat.min, Math.min(stat.max, value));
  }
  return result;
}

/** Reusable compiler validates the catalog once, then only recompiles at build transaction boundaries. */
export function createRuleCompiler(input: RuleRegistry): Decision<{ compile(snapshot: BuildSnapshot): Decision<CompiledRuleProgram> }> {
  const registry = freeze(structuredClone(input));
  const errors = validateRuleRegistry(registry);
  if (errors.length) return { ok: false, errors };
  return { ok: true, value: Object.freeze({ compile: (snapshot: BuildSnapshot) => compileSnapshot(registry, snapshot) }) };
}

function compileSnapshot(registry: RuleRegistry, snapshot: BuildSnapshot): Decision<CompiledRuleProgram> {
  const errors: BuildDiagnostic[] = [];
  const fail = (code: BuildDiagnostic['code'], definitionId: string, message: string) => errors.push({ code, definitionId, message });
  if (snapshot.version !== registry.version || !Object.hasOwn(registry.books, snapshot.mainBook)
      || !Number.isSafeInteger(snapshot.revision) || snapshot.revision < 0) return { ok: false, errors: [{ code: 'INVALID_DEFINITION', message: 'Invalid build snapshot version, book or revision' }] };
  if (new Set(snapshot.allocated).size !== snapshot.allocated.length) fail('INVALID_ALLOCATION', 'allocation', 'Duplicate allocated talent');
  const sources: Sourced[] = [{ id: `book:${snapshot.mainBook}`, contribution: registry.books[snapshot.mainBook], level: 1 }];
  const talentCapabilities = new Set<CapabilityId>(registry.books[snapshot.mainBook].capabilities);
  const allCapabilities = new Set<CapabilityId>(talentCapabilities), permits = new Set<PermitId>();
  const allocated = new Set<string>();
  const pending = [...new Set(snapshot.allocated)].sort();
  for (const id of pending) if (!Object.hasOwn(registry.talents, id)) fail('UNKNOWN_DEFINITION', id, 'Unknown allocated talent');
  if (errors.length) return { ok: false, errors };
  const state: ConditionState = { mainBook: snapshot.mainBook, allocated, permits, owned: {}, buildCapabilities: allCapabilities, talentCapabilities };
  while (pending.length) {
    const i = pending.findIndex(id => evaluateCondition(registry.talents[id].purchaseRequires, state));
    if (i < 0) { fail('INVALID_ALLOCATION', pending.join(','), 'Talents have no legal prerequisite acquisition order'); break; }
    const talent = registry.talents[pending.splice(i, 1)[0]];
    allocated.add(talent.id);
    talent.capabilities.forEach(c => { talentCapabilities.add(c); allCapabilities.add(c); });
    talent.permits.forEach(p => permits.add(p));
    sources.push({ id: talent.id, contribution: talent, level: 1 });
  }
  for (const id of allocated) if (!evaluateCondition(registry.talents[id].purchaseRequires, state)) fail('INVALID_ALLOCATION', id, 'Final allocation violates a prerequisite or exclusion');
  const activeAssets = snapshot.assets.filter(asset => asset.state === 'owned' || asset.state === 'leased');
  const assetInstances = new Set<string>(), levels = new Map<string, number>();
  for (const asset of snapshot.assets) {
    if (assetInstances.has(asset.instanceId)) fail('INVALID_DEFINITION', asset.instanceId, 'Duplicate asset instance');
    assetInstances.add(asset.instanceId);
    if (!['owned', 'leased', 'pledged', 'returned', 'replaced'].includes(asset.state)) fail('INVALID_DEFINITION', asset.instanceId, 'Unknown asset state');
  }
  for (const asset of activeAssets) {
    const relic = registry.relics[asset.definitionId];
    if (!relic) { fail('UNKNOWN_DEFINITION', asset.definitionId, 'Unknown owned relic'); continue; }
    if (!Number.isSafeInteger(asset.level) || asset.level < 1) { fail('INVALID_DEFINITION', asset.instanceId, 'Invalid asset level'); continue; }
    levels.set(relic.id, (levels.get(relic.id) ?? 0) + asset.level);
    if (levels.get(relic.id)! > relic.maxLevel) fail('INVALID_DEFINITION', relic.id, 'Asset exceeds maximum total level');
    if (asset.state === 'owned' && relic.permitsAll.some(p => !permits.has(p))) fail('MISSING_PERMIT', relic.id, 'Permanent relic lacks its departure talent permit');
    sources.push({ id: `asset:${asset.instanceId}`, contribution: relic, level: asset.level });
    relic.capabilities.forEach(c => allCapabilities.add(c));
  }
  const baseModes: Record<string, string> = {}, modes: Record<string, string> = {};
  const addMode = (target: Record<string, string>, mode: ModeChoice, id: string) => {
    if (!registry.modeSlots[mode.slot]?.includes(mode.value)) fail('INVALID_DEFINITION', id, `Unknown mode ${mode.slot}:${mode.value}`);
    else if (target[mode.slot] && target[mode.slot] !== mode.value) fail('MODE_CONFLICT', id, `Conflicting choices for ${mode.slot}`);
    else target[mode.slot] = mode.value;
  };
  for (const source of sources) source.contribution.modes.forEach(mode => addMode(baseModes, mode, source.id));
  const selectable: Record<string, Set<string>> = {};
  for (const id of allocated) for (const [slot, choices] of Object.entries(registry.talents[id].selectableModes ?? {})) {
    selectable[slot] ??= new Set(); choices.forEach(choice => selectable[slot].add(choice));
  }
  for (const [slot, value] of Object.entries(snapshot.selectedModes)) {
    if (!selectable[slot]?.has(value)) fail('INVALID_ALLOCATION', slot, 'Mode selection is not provided by allocated talents');
    else addMode(baseModes, { slot, value }, slot);
  }
  for (const slot of Object.keys(selectable)) if (!snapshot.selectedModes[slot]) fail('INVALID_ALLOCATION', slot, 'Required mode selection is missing');
  Object.assign(modes, baseModes);
  for (const [slot, value] of Object.entries(registry.modeDefaults ?? {})) if (!Object.hasOwn(modes, slot)) modes[slot] = value;
  const shadowed = new Set<string>(), overrideIds = new Set<string>();
  for (const override of snapshot.overrides) {
    if (overrideIds.has(override.id)) fail('INVALID_DEFINITION', override.id, 'Duplicate override');
    overrideIds.add(override.id);
    errors.push(...validateOverride(override, registry));
    for (const slot of override.shadows) {
      if (shadowed.has(slot)) fail('MODE_CONFLICT', override.id, `Multiple overrides shadow ${slot}`);
      shadowed.add(slot); delete modes[slot];
    }
    for (const mode of override.modes) addMode(modes, mode, override.id);
    override.capabilities.forEach(c => allCapabilities.add(c));
    sources.push({ id: `event:${override.id}`, contribution: override, level: 1 });
  }
  if (errors.length) return { ok: false, errors };
  sources.sort((a, b) => a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
  const numerics = compileNumerics(registry, sources, errors);
  const ruleSources = new Map<string, string[]>();
  for (const source of sources) for (const id of source.contribution.rules) {
    const rule = registry.rules[id];
    if (rule.modeSlot && modes[rule.modeSlot] !== rule.modeValue) continue;
    const ids = ruleSources.get(id) ?? []; ids.push(source.id); ruleSources.set(id, ids);
  }
  const ordered = orderRules([...ruleSources.keys()].map(id => registry.rules[id])); errors.push(...ordered.errors);
  for (const kind of ['primary', 'work']) {
    const incomes = ordered.rules.filter(rule => rule.operation.op === 'Supply' && rule.operation.incomeKind === kind);
    if (incomes.length > 1) fail('INVALID_DEFINITION', 'income', `Multiple ${kind} suppliers would duplicate one receipt's income`);
  }
  if (errors.length) return { ok: false, errors };
  const rules: CompiledRule[] = ordered.rules.map(definition => {
    const sourceIds = new Set(ruleSources.get(definition.id));
    if (definition.operation.op === 'Supply' && definition.operation.incomeKind === 'work') {
      const weights = { ...definition.operation.distributionWeights };
      for (const source of sources) for (const direction of source.contribution.supplyDirections ?? []) {
        if (direction.modeSlot && modes[direction.modeSlot] !== direction.modeValue) continue;
        weights[direction.resource] = Math.max(weights[direction.resource] ?? 0, direction.weight);
        sourceIds.add(source.id);
      }
      const total = Object.values(weights).reduce((sum, weight) => sum + weight, 0);
      definition = { ...definition, operation: { ...definition.operation,
        distributionWeights: Object.fromEntries(Object.entries(weights).map(([id, weight]) => [id, weight / total])) } };
    }
    return { definition, sourceIds: [...sourceIds].sort() };
  });
  const byStage = { income: [], assemble: [], dispatch: [], prepareHit: [], commitHit: [], afterHit: [], finish: [] } as Record<RuleDefinition['stage'], CompiledRule[]>;
  const byEvent: Partial<Record<RuleDefinition['event'], CompiledRule[]>> = {};
  const claimsPerUnit = { receipt: 0, lot: 0, object: 0, enemyProjectile: 0 };
  for (const rule of rules) {
    (byEvent[rule.definition.event] ??= []).push(rule);
    byStage[rule.definition.stage].push(rule);
    claimsPerUnit[rule.definition.repeat.unit] += rule.definition.repeat.limit;
  }
  return { ok: true, value: freeze({ version: registry.version, revision: snapshot.revision, mainBook: snapshot.mainBook,
    allocated: [...allocated].sort(), owned: Object.fromEntries(levels),
    rules, byStage, byEvent, numerics, modes, permits: [...permits].sort(), capabilities: [...allCapabilities].sort(),
    talentCapabilities: [...talentCapabilities].sort(), claimsPerUnit, diagnostics: [] }) };
}

function validateOverride(override: BuildOverride, registry: RuleRegistry): BuildDiagnostic[] {
  const errors: BuildDiagnostic[] = [...validateSupplyDirections(override.id, override, registry)];
  const fail = (message: string) => errors.push({ code: 'INVALID_DEFINITION' as const, definitionId: override.id, message });
  if (!idPattern.test(override.id) || !['room', 'chapter', 'run'].includes(override.scope) || !Number.isSafeInteger(override.expiresAfter) || override.expiresAfter < 0) fail('Invalid override identity or lifetime');
  for (const slot of override.shadows) if (!Object.hasOwn(registry.modeSlots, slot) || !override.modes.some(mode => mode.slot === slot)) fail('Shadow must replace a registered mode slot');
  for (const rule of override.rules) if (!Object.hasOwn(registry.rules, rule)) fail(`Unknown override rule ${rule}`);
  for (const capability of override.capabilities) if (!(capabilities as readonly string[]).includes(capability)) fail('Unknown override capability');
  for (const modifier of override.modifiers) {
    const stat: NumericDefinition | undefined = registry.numerics[modifier.stat];
    if (!stat || !Number.isFinite(modifier.value) || (modifier.pool === 'add' ? modifier.unit !== stat.unit || (stat.integer && !Number.isSafeInteger(modifier.value))
        : modifier.unit !== 'ratio' || !stat.multiplierPools.includes(modifier.pool))) fail('Invalid override numeric pool');
  }
  return errors;
}

function validateSupplyDirections(id: string, contribution: BuildContribution, registry: RuleRegistry): BuildDiagnostic[] {
  const errors: BuildDiagnostic[] = [];
  for (const direction of contribution.supplyDirections ?? []) {
    if (!['power', 'work', 'cold', 'heat', 'charge', 'opportunity'].includes(direction.resource)
      || !Number.isFinite(direction.weight) || direction.weight <= 0 || direction.weight > 1_000_000
      || Object.keys(direction).some(key => !['resource', 'weight', 'modeSlot', 'modeValue'].includes(key))
      || !!direction.modeSlot !== !!direction.modeValue
      || (direction.modeSlot && !registry.modeSlots[direction.modeSlot]?.includes(direction.modeValue!)))
      errors.push({ code: 'INVALID_DEFINITION', definitionId: id, path: 'supplyDirections', message: 'Invalid auxiliary supply direction or mode' });
  }
  return errors;
}
