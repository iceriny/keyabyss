import type { GraphBounds, GraphDefinition, GraphDiagnostic, GraphLayout, GraphNode, GraphNodeLayout, GraphPoint, GraphRelation, GraphRegionLayout } from '../contracts/graph.ts';

// Bump this when the geometry or routing rules change. Content changes use GraphDefinition.version.
const LAYOUT_VERSION = 2;
const RADIUS = 25;
const LABEL_WIDTH = 176;
const LABEL_HEIGHT = 32;
const LABEL_ENVELOPE_HEIGHT = RADIUS + (RADIUS + 9 + LABEL_HEIGHT);
const LABEL_DIAGONAL = Math.hypot(LABEL_WIDTH, LABEL_ENVELOPE_HEIGHT);
const NODE_SPACING = Math.ceil(LABEL_DIAGONAL) + 48;
const RING_STEP = NODE_SPACING + 48;
const REGION_GAP = 320;
const REGION_PAD = 130;
const CELL = 32;
const INDEX_CELL = 256;
const CLEARANCE = 8;
const kinds = new Set(['root', 'path', 'rule', 'keystone', 'relic', 'event', 'junction']);
const relationKinds = new Set(['path', 'requires', 'evolution', 'excludes', 'connection', 'event']);
const compare = (a: string, b: string): number => a < b ? -1 : a > b ? 1 : 0;
const quantize = (value: number): number => Math.round(value * 4) / 4;
const rect = (x: number, y: number, width: number, height: number): GraphBounds => ({ x: quantize(x), y: quantize(y), width: quantize(width), height: quantize(height) });
const overlap = (a: GraphBounds, b: GraphBounds): boolean => a.x < b.x + b.width && a.x + a.width > b.x && a.y < b.y + b.height && a.y + a.height > b.y;
const cellKey = (x: number, y: number): string => `${x},${y}`;
const nodeBody = (node: GraphNodeLayout): GraphBounds => rect(node.x - node.radius, node.y - node.radius, node.radius * 2, node.radius * 2);
const inflate = (bounds: GraphBounds, amount: number): GraphBounds => rect(bounds.x - amount, bounds.y - amount, bounds.width + amount * 2, bounds.height + amount * 2);
const obstacles = (node: GraphNodeLayout): GraphBounds[] => [inflate(nodeBody(node), CLEARANCE), inflate(node.labelBounds, CLEARANCE)];
const stable = <T extends { id: string }>(items: readonly T[]): T[] => [...items].sort((a, b) => compare(a.id, b.id));

function validate(definition: GraphDefinition): { nodes: GraphNode[]; relations: GraphRelation[]; regions: GraphDefinition['regions'] } {
  if (!definition.id || !Number.isSafeInteger(definition.version) || definition.version < 0) throw Error(`Invalid graph id/version: ${definition.id}`);
  const nodes = stable(definition.nodes);
  const relations = stable(definition.relations);
  const regions = stable(definition.regions);
  for (const [kind, items] of [['node', nodes], ['relation', relations], ['region', regions]] as const) {
    for (let i = 0; i < items.length; i++) {
      if (!items[i].id || (i && items[i].id === items[i - 1].id)) throw Error(`Invalid or duplicate ${kind} id: ${items[i].id}`);
    }
  }
  const nodeIds = new Set(nodes.map(node => node.id));
  const regionIds = new Set(regions.map(region => region.id));
  for (const node of nodes) {
    if (!regionIds.has(node.region)) throw Error(`Node ${node.id} references invalid region ${node.region}`);
    if (!node.family || !node.name || !node.definitionId || !kinds.has(node.kind)) throw Error(`Invalid node ${node.id}`);
    if (!Number.isFinite(node.cost) || node.cost < 0) throw Error(`Invalid cost for node ${node.id}`);
    if (node.condition !== undefined && node.condition !== 'all' && node.condition !== 'any') throw Error(`Invalid condition for node ${node.id}`);
  }
  for (const relation of relations) {
    if (!relationKinds.has(relation.kind) || !nodeIds.has(relation.source) || !nodeIds.has(relation.target)) throw Error(`Invalid relation ${relation.id}: ${relation.source} -> ${relation.target}`);
  }
  return { nodes, relations, regions };
}

// Tarjan condensation keeps directed cycles together instead of letting a relaxation loop drift.
function levels(nodes: readonly GraphNode[], relations: readonly GraphRelation[]): Map<string, number> {
  const ids = nodes.map(node => node.id);
  const adjacency = new Map(ids.map(id => [id, [] as string[]]));
  const pathNeighbors = new Map(ids.map(id => [id, [] as string[]]));
  for (const edge of relations) if (edge.kind === 'path') {
    pathNeighbors.get(edge.source)!.push(edge.target);
    pathNeighbors.get(edge.target)!.push(edge.source);
  }
  const rootDistance = new Map<string, number>();
  const pending = nodes.filter(node => node.kind === 'root').map(node => node.id);
  pending.forEach(id => rootDistance.set(id, 0));
  for (let head = 0; head < pending.length; head++) {
    const source = pending[head];
    for (const target of pathNeighbors.get(source)!.sort(compare)) if (!rootDistance.has(target)) {
      rootDistance.set(target, rootDistance.get(source)! + 1);
      pending.push(target);
    }
  }
  for (const edge of relations) {
    if (edge.kind === 'requires' || edge.kind === 'evolution') adjacency.get(edge.source)!.push(edge.target);
    if (edge.kind !== 'path') continue;
    const sourceDistance = rootDistance.get(edge.source), targetDistance = rootDistance.get(edge.target);
    if (sourceDistance !== undefined && targetDistance !== undefined) {
      if (sourceDistance < targetDistance) adjacency.get(edge.source)!.push(edge.target);
      else if (targetDistance < sourceDistance) adjacency.get(edge.target)!.push(edge.source);
    } else adjacency.get(edge.source)!.push(edge.target);
  }
  for (const children of adjacency.values()) children.sort(compare);
  let next = 0;
  const order = new Map<string, number>();
  const low = new Map<string, number>();
  const stack: string[] = [];
  const onStack = new Set<string>();
  const components: string[][] = [];
  function visit(id: string): void {
    order.set(id, next); low.set(id, next++); stack.push(id); onStack.add(id);
    for (const child of adjacency.get(id)!) {
      if (!order.has(child)) { visit(child); low.set(id, Math.min(low.get(id)!, low.get(child)!)); }
      else if (onStack.has(child)) low.set(id, Math.min(low.get(id)!, order.get(child)!));
    }
    if (low.get(id) === order.get(id)) {
      const component: string[] = [];
      let member: string;
      do { member = stack.pop()!; onStack.delete(member); component.push(member); } while (member !== id);
      components.push(component.sort(compare));
    }
  }
  for (const id of ids) if (!order.has(id)) visit(id);
  const componentOf = new Map<string, number>();
  components.forEach((component, index) => component.forEach(id => componentOf.set(id, index)));
  const incoming = components.map(() => new Set<number>());
  for (const [source, children] of adjacency) for (const target of children) {
    const from = componentOf.get(source)!; const to = componentOf.get(target)!;
    if (from !== to) incoming[to].add(from);
  }
  const rank = new Map<number, number>();
  function resolve(index: number): number {
    if (rank.has(index)) return rank.get(index)!;
    const value = incoming[index].size ? 1 + Math.max(...[...incoming[index]].map(resolve)) : 0;
    rank.set(index, value); return value;
  }
  components.forEach((_, index) => resolve(index));
  return new Map(ids.map(id => [id, rank.get(componentOf.get(id)!)!]));
}

interface RegionPlan { id: string; positions: Map<string, GraphPoint>; bounds: GraphBounds; radius: number; hasRoot: boolean }
function radiusForChord(count: number, spacing: number): number {
  return count < 2 ? 0 : spacing / (2 * Math.sin(Math.PI / count));
}
function regionPlan(id: string, nodes: readonly GraphNode[], ranks: Map<string, number>): RegionPlan {
  const positions = new Map<string, GraphPoint>();
  const ordered = [...nodes].sort((a, b) => (ranks.get(a.id)! - ranks.get(b.id)!) || compare(a.family, b.family) || compare(a.id, b.id));
  const anchor = ordered.find(node => node.kind === 'root') ?? ordered[0];
  if (anchor) positions.set(anchor.id, { x: 0, y: 0 });
  const remaining = ordered.filter(node => node !== anchor);
  const levelOrder = [...new Set(remaining.map(node => ranks.get(node.id)!).sort((a, b) => a - b))];
  const bands = new Map<number, GraphNode[]>();
  const ordinaryBands = Math.max(0, Math.ceil(levelOrder.length / 3) - 1);
  for (const node of remaining) {
    const layer = Math.floor(levelOrder.indexOf(ranks.get(node.id)!) / 3);
    // Keystone and junction silhouettes sit beyond their ordinary path layer.
    const band = node.kind === 'keystone' || node.kind === 'junction' ? Math.max(layer, ordinaryBands + 1) : layer;
    if (!bands.has(band)) bands.set(band, []);
    bands.get(band)!.push(node);
  }
  let previousRadius = 0;
  for (const band of [...bands.keys()].sort((a, b) => a - b)) {
    const members = bands.get(band)!.sort((a, b) => compare(a.family, b.family) || (ranks.get(a.id)! - ranks.get(b.id)!) || compare(a.id, b.id));
    // The chord and radial gap exceed the full node-plus-label diagonal after quantization.
    const radius = Math.max(RING_STEP, previousRadius + RING_STEP, radiusForChord(members.length, NODE_SPACING));
    members.forEach((node, index) => {
      const angle = -Math.PI / 2 + 2 * Math.PI * index / members.length;
      positions.set(node.id, { x: quantize(Math.cos(angle) * radius), y: quantize(Math.sin(angle) * radius) });
    });
    previousRadius = radius;
  }
  const envelope = Math.hypot(LABEL_WIDTH / 2, RADIUS + 9 + LABEL_HEIGHT);
  const radius = Math.max(REGION_PAD, ...[...positions.values()].map(point => Math.hypot(point.x, point.y) + envelope + REGION_PAD));
  return { id, positions, bounds: rect(-radius, -radius, radius * 2, radius * 2), radius, hasRoot: nodes.some(node => node.kind === 'root') };
}

function hash(value: unknown): string {
  const serialized = JSON.stringify(value);
  let result = 2166136261;
  for (let i = 0; i < serialized.length; i++) { result ^= serialized.charCodeAt(i); result = Math.imul(result, 16777619); }
  return (result >>> 0).toString(16).padStart(8, '0');
}

function clearSegment(a: GraphPoint, b: GraphPoint, boxes: readonly GraphBounds[]): boolean {
  for (const box of boxes) {
    if (a.x === b.x && a.x >= box.x && a.x <= box.x + box.width && Math.max(a.y, b.y) >= box.y && Math.min(a.y, b.y) <= box.y + box.height) return false;
    if (a.y === b.y && a.y >= box.y && a.y <= box.y + box.height && Math.max(a.x, b.x) >= box.x && Math.min(a.x, b.x) <= box.x + box.width) return false;
  }
  return true;
}

interface SearchCell { x: number; y: number; cost: number; estimate: number }
const cellOrder = (a: SearchCell, b: SearchCell): number => a.estimate - b.estimate || a.cost - b.cost || a.x - b.x || a.y - b.y;
class MinHeap {
  private readonly values: SearchCell[] = [];
  get length(): number { return this.values.length; }
  push(value: SearchCell): void {
    const data = this.values; let index = data.length; data.push(value);
    while (index > 0) {
      const parent = (index - 1) >> 1;
      if (cellOrder(data[parent], value) <= 0) break;
      data[index] = data[parent]; index = parent;
    }
    data[index] = value;
  }
  pop(): SearchCell {
    const data = this.values; const result = data[0]; const tail = data.pop()!;
    if (data.length) {
      let index = 0;
      while (index * 2 + 1 < data.length) {
        let child = index * 2 + 1;
        if (child + 1 < data.length && cellOrder(data[child + 1], data[child]) < 0) child++;
        if (cellOrder(tail, data[child]) <= 0) break;
        data[index] = data[child]; index = child;
      }
      data[index] = tail;
    }
    return result;
  }
}

function route(layout: GraphLayout, relation: GraphRelation): { points: GraphPoint[]; diagnostic?: GraphDiagnostic } {
  const source = layout.nodes[relation.source]; const target = layout.nodes[relation.target];
  if (!source || !target) throw Error(`Invalid relation ${relation.id}: ${relation.source} -> ${relation.target}`);
  if (source === target) return { points: [{ x: source.x + RADIUS, y: source.y }, { x: source.x + RADIUS + 64, y: source.y }, { x: source.x + RADIUS + 64, y: source.y - 72 }, { x: source.x, y: source.y - 72 }, { x: source.x, y: source.y - RADIUS }] };
  const direction = target.x >= source.x ? 1 : -1;
  const start = { x: source.x + direction * (RADIUS + 12), y: source.y };
  const end = { x: target.x - direction * (RADIUS + 12), y: target.y };
  const startCell = { x: Math.round(start.x / CELL), y: Math.round(start.y / CELL) };
  const endCell = { x: Math.round(end.x / CELL), y: Math.round(end.y / CELL) };
  const point = (x: number, y: number): GraphPoint => ({ x: x * CELL, y: y * CELL });
  const allBoxes = Object.values(layout.nodes).flatMap(obstacles);
  const local = rect(Math.min(start.x, end.x) - 320, Math.min(start.y, end.y) - 320, Math.abs(start.x - end.x) + 640, Math.abs(start.y - end.y) + 640);
  const boxes = allBoxes.filter(box => overlap(box, local));
  const blocked = new Set<string>();
  for (const box of boxes) {
    for (let x = Math.ceil(box.x / CELL); x <= Math.floor((box.x + box.width) / CELL); x++)
      for (let y = Math.ceil(box.y / CELL); y <= Math.floor((box.y + box.height) / CELL); y++) blocked.add(cellKey(x, y));
  }
  const first = cellKey(startCell.x, startCell.y); const last = cellKey(endCell.x, endCell.y);
  blocked.delete(first); blocked.delete(last);
  const minX = Math.floor(local.x / CELL), maxX = Math.ceil((local.x + local.width) / CELL);
  const minY = Math.floor(local.y / CELL), maxY = Math.ceil((local.y + local.height) / CELL);
  const queue = new MinHeap();
  queue.push({ ...startCell, cost: 0, estimate: Math.abs(startCell.x - endCell.x) + Math.abs(startCell.y - endCell.y) });
  const distance = new Map([[first, 0]]); const previous = new Map<string, string>();
  const moves = [[1, 0], [0, -1], [0, 1], [-1, 0]];
  let found = false;
  while (queue.length) {
    const current = queue.pop(); const key = cellKey(current.x, current.y);
    if (current.cost !== distance.get(key)) continue;
    if (key === last) { found = true; break; }
    for (const [dx, dy] of moves) {
      const x = current.x + dx, y = current.y + dy, nextKey = cellKey(x, y);
      if (x < minX || x > maxX || y < minY || y > maxY || blocked.has(nextKey)) continue;
      const cost = current.cost + 1;
      if (cost >= (distance.get(nextKey) ?? Infinity)) continue;
      distance.set(nextKey, cost); previous.set(nextKey, key);
      queue.push({ x, y, cost, estimate: cost + Math.abs(x - endCell.x) + Math.abs(y - endCell.y) });
    }
  }
  if (!found) return { points: [start, end], diagnostic: { code: 'route-unresolved', ids: [relation.id, relation.source, relation.target], message: `No clear route for ${relation.id}` } };
  const cells: GraphPoint[] = [];
  let cursor = last;
  while (cursor !== first) { const [x, y] = cursor.split(',').map(Number); cells.push(point(x, y)); cursor = previous.get(cursor)!; }
  cells.push(point(startCell.x, startCell.y)); cells.reverse();
  const condensed: GraphPoint[] = [];
  for (const current of cells) {
    const n = condensed.length;
    if (n >= 2 && (condensed[n - 2].x === condensed[n - 1].x && condensed[n - 1].x === current.x || condensed[n - 2].y === condensed[n - 1].y && condensed[n - 1].y === current.y)) condensed[n - 1] = current;
    else condensed.push(current);
  }
  const firstGrid = condensed[0], lastGrid = condensed[condensed.length - 1];
  const points = [start, { x: firstGrid.x, y: start.y }, ...condensed, { x: lastGrid.x, y: end.y }, end];
  const foreignBoxes = Object.entries(layout.nodes).filter(([id]) => id !== relation.source && id !== relation.target).flatMap(([, node]) => obstacles(node));
  const endpointLabels = [inflate(source.labelBounds, CLEARANCE), inflate(target.labelBounds, CLEARANCE)];
  const conflict = points.some((current, index) => index > 0 && !clearSegment(points[index - 1], current, [...foreignBoxes, ...endpointLabels]));
  return { points, diagnostic: conflict ? { code: 'route-clearance', ids: [relation.id, relation.source, relation.target], message: `Route ${relation.id} crosses another node or label` } : undefined };
}

export function routeGraphRelations(layout: GraphLayout, relations: readonly GraphRelation[]): Readonly<Record<string, readonly GraphPoint[]>> {
  const result: Record<string, readonly GraphPoint[]> = Object.create(null);
  const sorted = stable(relations);
  for (let i = 0; i < sorted.length; i++) {
    const edge = sorted[i];
    if (!edge.id || (i && edge.id === sorted[i - 1].id)) throw Error(`Duplicate relation id: ${edge.id}`);
    result[edge.id] = route(layout, edge).points;
  }
  return result;
}

export function visibleGraphNodes(layout: GraphLayout, bounds: GraphBounds): readonly string[] {
  if (![bounds.x, bounds.y, bounds.width, bounds.height].every(Number.isFinite) || bounds.width < 0 || bounds.height < 0) throw Error('Invalid viewport bounds');
  const ids = new Set<string>();
  for (let col = Math.floor(bounds.x / layout.cellSize); col <= Math.floor((bounds.x + bounds.width) / layout.cellSize); col++)
    for (let row = Math.floor(bounds.y / layout.cellSize); row <= Math.floor((bounds.y + bounds.height) / layout.cellSize); row++)
      for (const id of layout.spatialIndex[cellKey(col, row)] ?? []) ids.add(id);
  return [...ids].filter(id => overlap(nodeBody(layout.nodes[id]), bounds) || overlap(layout.nodes[id].labelBounds, bounds)).sort(compare);
}

export function generateGraphLayout(definition: GraphDefinition): GraphLayout {
  const { nodes, relations, regions } = validate(definition);
  const ranks = levels(nodes, relations);
  const byRegion = new Map(regions.map(region => [region.id, [] as GraphNode[]]));
  for (const node of nodes) byRegion.get(node.region)!.push(node);
  const plans = regions.map(region => regionPlan(region.id, byRegion.get(region.id)!, ranks));
  const inner = plans.filter(plan => plan.hasRoot);
  const outer = plans.filter(plan => !plan.hasRoot);
  const innerMax = Math.max(0, ...inner.map(plan => plan.radius));
  const outerMax = Math.max(0, ...outer.map(plan => plan.radius));
  const innerRadius = inner.length <= 1 ? 0 : Math.max(innerMax + REGION_GAP, radiusForChord(inner.length, innerMax * 2 + REGION_GAP));
  const outerRadius = outer.length <= 1 && !inner.length ? 0 : Math.max(
    radiusForChord(outer.length, outerMax * 2 + REGION_GAP),
    inner.length && outer.length ? innerRadius + innerMax + outerMax + REGION_GAP : 0,
  );
  const nodeLayouts: Record<string, GraphNodeLayout> = Object.create(null);
  const regionLayouts: Record<string, GraphRegionLayout> = Object.create(null);
  function placeBand(band: readonly RegionPlan[], radius: number): void {
    band.forEach((plan, index) => {
      const angle = -Math.PI / 2 + 2 * Math.PI * index / band.length;
      const center = { x: quantize(Math.cos(angle) * radius), y: quantize(Math.sin(angle) * radius) };
      const bounds = rect(center.x + plan.bounds.x, center.y + plan.bounds.y, plan.bounds.width, plan.bounds.height);
      regionLayouts[plan.id] = { bounds, center };
      for (const [id, relative] of plan.positions) {
        const x = quantize(center.x + relative.x), y = quantize(center.y + relative.y);
        nodeLayouts[id] = { x, y, radius: RADIUS, labelBounds: rect(x - LABEL_WIDTH / 2, y + RADIUS + 9, LABEL_WIDTH, LABEL_HEIGHT) };
      }
    });
  }
  placeBand(inner, innerRadius);
  placeBand(outer, outerRadius);
  const placed = Object.keys(nodeLayouts).sort(compare);
  for (let i = 0; i < placed.length; i++) for (let j = i + 1; j < placed.length; j++) {
    const a = nodeLayouts[placed[i]], b = nodeLayouts[placed[j]];
    if (overlap(nodeBody(a), nodeBody(b)) || overlap(nodeBody(a), b.labelBounds) || overlap(a.labelBounds, nodeBody(b)) || overlap(a.labelBounds, b.labelBounds))
      throw Error(`Layout collision between ${placed[i]} and ${placed[j]}`);
  }
  const regionBoxes = Object.values(regionLayouts).map(shape => shape.bounds);
  const worldMinX = Math.min(0, ...regionBoxes.map(box => box.x));
  const worldMinY = Math.min(0, ...regionBoxes.map(box => box.y));
  const worldMaxX = Math.max(0, ...regionBoxes.map(box => box.x + box.width));
  const worldMaxY = Math.max(0, ...regionBoxes.map(box => box.y + box.height));
  const spatialIndex: Record<string, string[]> = Object.create(null);
  for (const id of Object.keys(nodeLayouts).sort(compare)) {
    const node = nodeLayouts[id];
    const body = nodeBody(node);
    const total = rect(Math.min(body.x, node.labelBounds.x), Math.min(body.y, node.labelBounds.y), Math.max(body.x + body.width, node.labelBounds.x + node.labelBounds.width) - Math.min(body.x, node.labelBounds.x), Math.max(body.y + body.height, node.labelBounds.y + node.labelBounds.height) - Math.min(body.y, node.labelBounds.y));
    for (let col = Math.floor(total.x / INDEX_CELL); col <= Math.floor((total.x + total.width) / INDEX_CELL); col++)
      for (let row = Math.floor(total.y / INDEX_CELL); row <= Math.floor((total.y + total.height) / INDEX_CELL); row++) {
        const key = cellKey(col, row);
        (spatialIndex[key] ??= []).push(id);
      }
  }
  const base: GraphLayout = { graphId: definition.id, graphVersion: definition.version, layoutVersion: LAYOUT_VERSION, hash: '', bounds: rect(worldMinX, worldMinY, worldMaxX - worldMinX, worldMaxY - worldMinY), nodes: nodeLayouts, regions: regionLayouts, routes: {}, spatialIndex, cellSize: INDEX_CELL, diagnostics: [] };
  const routes: Record<string, readonly GraphPoint[]> = Object.create(null);
  const diagnostics: GraphDiagnostic[] = [];
  for (const edge of relations) {
    const result = route(base, edge);
    routes[edge.id] = result.points;
    if (result.diagnostic) diagnostics.push(result.diagnostic);
  }
  const routedPoints = Object.values(routes).flat();
  const routeMinX = Math.min(worldMinX, ...routedPoints.map(point => point.x));
  const routeMinY = Math.min(worldMinY, ...routedPoints.map(point => point.y));
  const routeMaxX = Math.max(worldMaxX, ...routedPoints.map(point => point.x));
  const routeMaxY = Math.max(worldMaxY, ...routedPoints.map(point => point.y));
  const layout = { ...base, bounds: rect(routeMinX, routeMinY, routeMaxX - routeMinX, routeMaxY - routeMinY), routes, diagnostics };
  return { ...layout, hash: hash([definition.id, definition.version, LAYOUT_VERSION, nodeLayouts, regionLayouts, routes]) };
}
