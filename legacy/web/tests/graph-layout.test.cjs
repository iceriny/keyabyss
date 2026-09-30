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

test('growth routes stay local and crossings do not overwhelm the network', () => {
  const paths = TALENT_GRAPH.relations.filter(e => e.kind === 'path');
  const side = (a,b,c) => (b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x);
  const crosses = (a,b,c,d) => side(a,b,c)*side(a,b,d)<0 && side(c,d,a)*side(c,d,b)<0;
  let intersections = 0;
  const lengths = paths.map(edge => {
    const points = TALENT_LAYOUT.routes[edge.id];
    return points.slice(1).reduce((sum,p,i) => sum + Math.hypot(p.x-points[i].x,p.y-points[i].y), 0);
  }).sort((a,b)=>a-b);
  for (let i=0;i<paths.length;i++) for (let j=i+1;j<paths.length;j++) {
    const a=paths[i],b=paths[j];
    if ([a.source,a.target].some(id=>id===b.source || id===b.target)) continue;
    const p=TALENT_LAYOUT.routes[a.id],q=TALENT_LAYOUT.routes[b.id];
    for(let x=1;x<p.length;x++) for(let y=1;y<q.length;y++)
      if(crosses(p[x-1],p[x],q[y-1],q[y])) intersections++;
  }
  assert.ok(intersections <= paths.length * .12, `${intersections} crossings / ${paths.length} paths`);
  assert.ok(lengths[Math.floor(lengths.length*.95)] < 1400, 'most paths should connect nearby nodes');
  console.log(JSON.stringify({growthPaths:paths.length, intersections, routeLengthP95:lengths[Math.floor(lengths.length*.95)]}));
});
