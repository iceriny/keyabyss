import type { NativeSpellDefinition } from '../../contracts/native-spells.ts';
import type { BuildDiagnostic } from '../../contracts/build-resources.ts';
import { RESOURCE_SCALE } from '../../contracts/build-resources.ts';

/** Validate native loops and timers alongside the declarative rule catalog. */
export function validateNativeSpell(id: string, pattern: NativeSpellDefinition): readonly BuildDiagnostic[] {
  const errors: BuildDiagnostic[] = [];
  const check = (valid: boolean, path: string) => {
    if (!valid) errors.push({ code: 'INVALID_DEFINITION', definitionId: id, path, message: `Invalid native spell ${path}` });
  };
  const count = (n: number, min: number, max: number) => Number.isSafeInteger(n) && n >= min && n <= max;
  const ratio = (n: number) => Number.isFinite(n) && n >= 0 && n <= 1;
  check(['shot', 'chain', 'pierce', 'burst', 'blade'].includes(pattern.shape), 'shape');
  check(['ice', 'fire', 'storm', 'paper'].includes(pattern.element), 'element');
  check(Array.isArray(pattern.hitCounts) && pattern.hitCounts.length === 2 && pattern.hitCounts.every(n => count(n, 1, 64)), 'hitCounts');
  check(ratio(pattern.hitRetention) && pattern.hitRetention > 0, 'hitRetention');
  check(ratio(pattern.ongoingShare) && ratio(pattern.splashShare) && pattern.ongoingShare + pattern.splashShare < 1, 'allocation');
  check(count(pattern.ongoingTicks, pattern.ongoingShare ? 1 : 0, 72000)
    && count(pattern.ongoingApplications, pattern.ongoingShare ? 1 : 0, 1024)
    && pattern.ongoingApplications <= pattern.ongoingTicks, 'ongoing');
  check(Number.isFinite(pattern.splashRadius) && pattern.splashRadius >= 0 && pattern.splashRadius <= 10000, 'splashRadius');
  if (pattern.summon) {
    check(Number.isFinite(pattern.summon.workCost) && pattern.summon.workCost >= 1 / RESOURCE_SCALE
      && pattern.summon.workCost <= 10000, 'summon.workCost');
    check(ratio(pattern.summon.powerFactor) && pattern.summon.powerFactor > 0, 'summon.powerFactor');
    check(count(pattern.summon.capacity, 1, 64), 'summon.capacity');
  }
  return errors;
}
