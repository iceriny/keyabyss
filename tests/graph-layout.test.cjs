const test = require('node:test');
const assert = require('node:assert/strict');
const { TALENT_GRAPH, RELIC_GRAPH } = require('../src/content/graphs.ts');
const { TALENT_LAYOUT, RELIC_LAYOUT } = require('../src/generated/graph-layouts.ts');
const { generateGraphLayout, visibleGraphNodes } = require('../src/shared/graph-layout.ts');

for (const [definition, generated] of [[TALENT_GRAPH, TALENT_LAYOUT], [RELIC_GRAPH, RELIC_LAYOUT]]) {
  test(`${definition.id}: generated geometry is deterministic regardless of registration order`, () => {
    const reordered = { ...definition, nodes: [...definition.nodes].reverse(),
      relations: [...definition.relations].reverse(), regions: [...definition.regions].reverse() };
    const actual = generateGraphLayout(reordered);
    // The artifact is JSON; prototype-less internal lookup maps serialize as objects.
    assert.deepEqual(JSON.parse(JSON.stringify(actual)), generated);
    assert.deepEqual(actual.diagnostics, []);
    assert.equal(Object.keys(actual.nodes).length, definition.nodes.length);
    assert.equal(Object.keys(actual.routes).length, definition.relations.length);
    for (const route of Object.values(actual.routes)) {
      assert.ok(route.length >= 2);
      assert.ok(route.every(point => Number.isFinite(point.x) && Number.isFinite(point.y)));
    }
  });
  test(`${definition.id}: spatial culling retains all nodes in the world and each visible label`, () => {
    assert.deepEqual([...visibleGraphNodes(generated, generated.bounds)].sort(), definition.nodes.map(node => node.id).sort());
    for (const [id, node] of Object.entries(generated.nodes)) {
      assert.ok(visibleGraphNodes(generated, node.labelBounds).includes(id), id);
    }
    const bounds = generated.bounds;
    assert.deepEqual(visibleGraphNodes(generated, { x: bounds.x - 1000, y: bounds.y - 1000, width: 1, height: 1 }), []);
  });
}

test('graph generation rejects duplicate nodes and dangling dependencies', () => {
  assert.throws(() => generateGraphLayout({ ...TALENT_GRAPH, nodes: [...TALENT_GRAPH.nodes, TALENT_GRAPH.nodes[0]] }), /duplicate node/);
  assert.throws(() => generateGraphLayout({ ...TALENT_GRAPH, relations: [{ id: 'bad', source: TALENT_GRAPH.nodes[0].id, target: 'missing', kind: 'requires' }] }), /Invalid relation/);
});

test('rooted graph has one central book core and bounded whole-world queries', () => {
  const roots = TALENT_GRAPH.nodes.filter(node => node.kind === 'root');
  const radii = roots.map(node => Math.hypot(TALENT_LAYOUT.nodes[node.id].x, TALENT_LAYOUT.nodes[node.id].y));
  assert.equal(roots.length, 4);
  assert.ok(Math.max(...radii) - Math.min(...radii) < 1);
  for (const node of TALENT_GRAPH.nodes.filter(node => node.kind !== 'root'))
    assert.ok(Math.hypot(TALENT_LAYOUT.nodes[node.id].x, TALENT_LAYOUT.nodes[node.id].y) > Math.max(...radii));
  assert.equal(visibleGraphNodes(TALENT_LAYOUT, {x:-1e12,y:-1e12,width:2e12,height:2e12}).length, TALENT_GRAPH.nodes.length);
});
