import type { BookId } from "../contracts/game.ts";
import type { CombatStat } from "../contracts/stats.ts";
import type { CombatCapability } from "../contracts/combat-weave.ts";
import type { TalentLoadout } from "../contracts/talents.ts";
import { TALENT_BOOKS, TALENT_NODES } from "../content/talents.ts";

export const MAX_TALENT_POINTS = 24;
export const MAX_KEYSTONES = 2;
export const talentBudget = (value: number) => Number.isFinite(value) ? Math.max(0, Math.min(MAX_TALENT_POINTS, Math.floor(value))) : 0;
const adjacent = new Map(TALENT_NODES.map(node => [node.id, new Set(node.links)]));
for (const node of TALENT_NODES) for (const id of node.links) adjacent.get(id)?.add(node.id);

export function resolveTalents(book: string, allocated: readonly string[], budget: number, godMode = false): {
  allocated: string[]; spent: number; grants: Partial<Record<CombatStat, number>>; capabilities: CombatCapability[];
} {
  const root = TALENT_NODES.find(node => node.root === book);
  if (!root) return { allocated: [], spent: 0, grants: {}, capabilities: [] };
  const candidates = new Set(Array.isArray(allocated) ? allocated.filter(id => typeof id === "string") : []);
  const selected = new Set([root.id]);
  const capabilities = new Set<CombatCapability>(root.capabilities);
  const groups = new Set<string>();
  const grants: Partial<Record<CombatStat, number>> = { ...root.grants };
  const limit = godMode ? Infinity : talentBudget(budget);
  let spent = 0, keystones = 0, changed = true;
  while (changed) {
    changed = false;
    for (const node of TALENT_NODES) {
      if (!candidates.has(node.id) || selected.has(node.id) || spent + node.cost > limit) continue;
      if (![...adjacent.get(node.id)!].some(id => selected.has(id))) continue;
      if (node.exclusive && groups.has(node.exclusive)) continue;
      if (node.kind === 'keystone' && keystones >= MAX_KEYSTONES) continue;
      if (node.requires?.some(capability => !capabilities.has(capability))) continue;
      if (node.requiresNodes?.some(id => !selected.has(id))) continue;
      selected.add(node.id);
      spent += node.cost;
      if (node.kind === 'keystone') keystones++;
      if (node.exclusive) groups.add(node.exclusive);
      for (const capability of node.capabilities ?? []) capabilities.add(capability);
      for (const [stat, amount] of Object.entries(node.grants ?? {})) {
        const key = stat as CombatStat;
        grants[key] = (grants[key] ?? 0) + amount;
      }
      changed = true;
    }
  }
  return { allocated: TALENT_NODES.filter(node => selected.has(node.id)).map(node => node.id), spent, grants, capabilities: [...capabilities].sort() };
}

export const talentNeighbors = (id: string): readonly string[] => [...(adjacent.get(id) ?? [])];

/** A cost-ordered, executable route, checked one purchase at a time. The route
 * may exceed today's budget, but never bypasses prerequisites or exclusions. */
export function talentRoute(book: string, target: string, allocated: readonly string[]): string[] {
  const active = resolveTalents(book, allocated, 0, true).allocated;
  const pending = active.map(id => ({ path: [id], cost: 0 }));
  const visited = new Set<string>();
  const byId = new Map(TALENT_NODES.map(node => [node.id, node]));
  while (pending.length) {
    pending.sort((a, b) => a.cost - b.cost || a.path.join('/').localeCompare(b.path.join('/'), 'en'));
    const { path, cost } = pending.shift()!, last = path[path.length - 1];
    if (last === target) return path;
    if (visited.has(last)) continue;
    visited.add(last);
    for (const next of talentNeighbors(last)) {
      if (visited.has(next) || active.includes(next)) continue;
      const proposed = [...active, ...path, next];
      const trial = resolveTalents(book, proposed, 0, true);
      if (proposed.every(id => trial.allocated.includes(id))) pending.push({ path: [...path, next], cost: cost + byId.get(next)!.cost });
    }
  }
  return [];
}

export function removeTalent(book: string, allocated: readonly string[], id: string, budget: number, godMode = false): string[] {
  return resolveTalents(book, allocated.filter(value => value !== id), budget, godMode).allocated;
}

export function secondaryBookCandidates(book: string, allocated: readonly string[], budget: number, godMode = false): BookId[] {
  const resolved = resolveTalents(book, allocated, budget, godMode);
  return resolved.grants.secondaryBinding ? TALENT_BOOKS.filter(id => id !== book) : [];
}

export function resolveTalentLoadout(book: BookId, loadout: Partial<TalentLoadout> | undefined, budget: number, godMode = false): TalentLoadout {
  const allocated = resolveTalents(book, loadout?.allocated ?? [], budget, godMode).allocated;
  const secondaryBook = secondaryBookCandidates(book, allocated, budget, godMode).find(id => id === loadout?.secondaryBook);
  return secondaryBook ? { allocated, secondaryBook } : { allocated };
}
