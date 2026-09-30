import type { BuildProgram, SpellBlueprint, SpellPacket, SpellResources, SpellRoot, SpellSource } from '../../contracts/combat-weave.ts';

let packetSequence = 0;
export const resources = (power = 0): SpellResources => ({ power, cold: 0, heat: 0, charge: 0, copy: 0 });

export function createPacket(root: SpellRoot, program: BuildProgram, source: SpellSource,
  balances: SpellResources, owner: string, depth = 0, blueprint: SpellBlueprint = program.blueprint): SpellPacket {
  return { id: ++packetSequence, root, rootId: root.id, room: root.room, source,
    blueprint, program, owner, depth, resources: balances,
    history: new Set(), remainingLife: 20, reserve: 0,
    hitBudget: source === 'manual' ? Math.max(1, program.blueprint.nativeSegments) : 1,
    hitsCommitted: 0, lastHitPower: 0, spent: false };
}

/** Transfer a fraction of every material. Neither packet can spend the other's balance. */
export function splitPacket(parent: SpellPacket, fraction: number, source: SpellSource, owner: string,
  reactionEfficiency = 0): SpellPacket | undefined {
  if (parent.spent || parent.depth >= 8 || fraction <= 0 || parent.resources.power <= 0) return undefined;
  const child = resources();
  for (const key of Object.keys(child) as (keyof SpellResources)[]) {
    child[key] = parent.resources[key] * Math.min(1, fraction);
    parent.resources[key] -= child[key];
  }
  const alreadyProcessed = parent.history.has('processing:applied');
  if (!alreadyProcessed) child.power *= parent.program.processingRetention;
  const alreadyBoosted = [...parent.history].some(event => event.startsWith('reactionEfficiency:'));
  if (reactionEfficiency && !alreadyBoosted) child.power *= Math.max(0, 1 + reactionEfficiency);
  const packet = createPacket(parent.root, parent.program, source, child, owner, parent.depth + 1);
  packet.history.add('processing:applied');
  if (reactionEfficiency) packet.history.add(alreadyBoosted
    ? `reactionEfficiency:inherited:${parent.id}` : `reactionEfficiency:${parent.id}`);
  return packet;
}

export function claim(packet: SpellPacket, operation: string): boolean {
  if (packet.spent || packet.history.has(operation) || packet.room !== packet.root.room) return false;
  packet.history.add(operation);
  packet.root.executions++;
  return true;
}

export function claimCarrier(page: { exit?: string }, exit: 'attack' | 'guard' | 'thermal' | 'expiry' | 'clear'): boolean {
  if (page.exit) return false;
  page.exit = exit;
  return true;
}
