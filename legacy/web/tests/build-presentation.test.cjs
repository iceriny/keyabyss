const { test } = require('node:test');
const assert = require('node:assert/strict');
const { TALENT_PRESENTATION, RELIC_PRESENTATION } = require('../src/content/build/presentation.ts');
const { BUILD_CONCEPTS } = require('../src/content/build/semantics.ts');
const { NATIVE_RULES } = require('../src/content/build/native.ts');
const { createSemanticVocabulary } = require('../src/shared/build/semantics.ts');

const ids = (prefix, first, last) => Array.from({ length: last - first + 1 }, (_, index) => `${prefix}${String(first + index).padStart(2, '0')}`);
const relicIds = (first, last) => Array.from({ length: last - first + 1 }, (_, index) => `R${String(first + index).padStart(3, '0')}`);
const numericCounts = [6,5,5,5,5,6,5,4,4,4,4,3,3,5,5,4,3,4,4,5,5,3,4,3,3,3,3,3,3,3];
const numericIds = numericCounts.flatMap((count, index) => Array.from({ length: count }, (_, copy) => `N${String(index + 1).padStart(2, '0')}-${String(copy + 1).padStart(2, '0')}`));
const expectedTalentIds = ['B-frost', 'B-flame', 'B-storm', 'B-spirit', ...ids('T', 1, 60), ...ids('K', 1, 20), ...numericIds];
const expectedRelicIds = [...relicIds(1, 58), 'R066', ...relicIds(69, 180)];
const vocabulary = createSemanticVocabulary(BUILD_CONCEPTS, ['flame', 'storm', 'frost', 'spirit']);

test('build presentation covers the exact candidate catalog with readable immutable fields', () => {
  assert.equal(numericIds.length, 122);
  for (const [catalog, expected] of [[TALENT_PRESENTATION, expectedTalentIds], [RELIC_PRESENTATION, expectedRelicIds]]) {
    assert.deepEqual(Object.keys(catalog).sort(), expected.sort());
    assert.ok(Object.isFrozen(catalog));
    for (const [id, item] of Object.entries(catalog)) {
      assert.equal(item.id, id);
      assert.ok(item.name.trim(), `${id} name`);
      assert.ok(item.description.trim(), `${id} description`);
      assert.ok(item.drawback.trim(), `${id} drawback`);
      assert.ok(Object.isFrozen(item) && Object.isFrozen(item.requirements) && Object.isFrozen(item.concepts), `${id} immutable`);
      assert.ok(item.requirements.every(value => value.trim()), `${id} requirements`);
      assert.ok(item.concepts.length && item.concepts.every(value => value.trim()), `${id} concepts`);
      const normalized = vocabulary.normalize(Object.fromEntries(item.concepts.map(value => [value, 1])));
      assert.equal(normalized.ok, true, `${id}: ${JSON.stringify(normalized.errors)}`);
    }
  }
  assert.match(TALENT_PRESENTATION.T57.description, /10%/);
  assert.match(TALENT_PRESENTATION['N26-01'].drawback, /不增加伤害总量、次数/);
  assert.match(RELIC_PRESENTATION.R168.description, /真正释放时/);
  assert.match(RELIC_PRESENTATION.R170.drawback, /守旧、护新/);
  assert.match(RELIC_PRESENTATION.R177.drawback, /更多保存空间/);
});

test('registered mechanical content uses the same semantic vocabulary as its presentation', () => {
  for (const item of [...Object.values(NATIVE_RULES.talents), ...Object.values(NATIVE_RULES.relics)]) {
    const result = vocabulary.normalize(item.semantic.concepts);
    assert.equal(result.ok, true, `${item.id}: ${JSON.stringify(result.errors)}`);
  }
});
