import type { RuntimeSpellRelay, SpellPosition } from '../../contracts/build-runtime.ts';

export interface SpellRelayPath {
  readonly relays: readonly RuntimeSpellRelay[];
  readonly distance: number;
}

/** Fewer paid relays first, then actual path length, then stable object identities. */
export function compareRelayPaths(a: SpellRelayPath, b: SpellRelayPath): number {
  const cost = a.relays.length - b.relays.length || a.distance - b.distance;
  if (cost) return cost;
  for (let i = 0; i < a.relays.length; i++) {
    const order = a.relays[i].objectId - b.relays[i].objectId;
    if (order) return order;
  }
  return 0;
}

/** Bounded Dijkstra over actual outgoing ranges; no random ordering or all-path enumeration. */
export function findRelayPaths(from: SpellPosition, firstRange: number,
  candidates: readonly RuntimeSpellRelay[], maxRelays: number, maxSourceHops = 0): readonly SpellRelayPath[] {
  const fieldCount = candidates.reduce((count, relay) => count + Number(!!relay.sourceCharge), 0);
  const budget = Math.max(0, Math.min(maxRelays, fieldCount, Math.floor(maxSourceHops))), width = budget + 1;
  // Keep a label per source-paid hop count: a shorter costly route must not hide a funded detour.
  const best: (SpellRelayPath | undefined)[] = Array(candidates.length * width);
  candidates.forEach((relay, index) => {
    const distance = Math.hypot(relay.position.x - from.x, relay.position.y - from.y);
    const cost = Number(!!relay.sourceCharge);
    if (distance <= firstRange && cost <= budget) best[index * width + cost] = { relays: [relay], distance };
  });
  const visited = new Set<number>(), result: SpellRelayPath[] = [];
  while (visited.size < best.length) {
    let index = -1;
    for (let i = 0; i < best.length; i++) if (!visited.has(i) && best[i]
      && (index === -1 || compareRelayPaths(best[i]!, best[index]!) < 0)) index = i;
    if (index === -1) break;
    visited.add(index);
    const current = best[index]!, last = candidates[Math.floor(index / width)], spent = index % width;
    result.push(current);
    if (current.relays.length >= maxRelays) continue;
    for (let i = 0; i < candidates.length; i++) {
      const next = candidates[i], distance = Math.hypot(next.position.x - last.position.x, next.position.y - last.position.y);
      if (distance > last.maxDistance) continue;
      const cost = spent + Number(!!next.sourceCharge), nextIndex = i * width + cost;
      if (cost > budget || visited.has(nextIndex) || current.relays.some(relay => relay.objectId === next.objectId)) continue;
      const length = current.relays.length + 1, total = current.distance + distance, old = best[nextIndex];
      if (old && (old.relays.length < length || old.relays.length === length && old.distance < total)) continue;
      const path = { relays: [...current.relays, next], distance: total };
      let dominated = false;
      for (let cheaper = 0; cheaper <= cost; cheaper++) {
        const alternative = best[i * width + cheaper];
        if (alternative && compareRelayPaths(alternative, path) <= 0) { dominated = true; break; }
      }
      if (!dominated) best[nextIndex] = path;
    }
  }
  return result;
}
