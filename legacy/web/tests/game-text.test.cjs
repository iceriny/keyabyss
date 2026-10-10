const test = require("node:test");
const assert = require("node:assert/strict");
const { createTextTokenizer } = require("../src/shared/game-text.ts");
const { TERMS, GLOSSARY, glossaryById } = require("../src/content/glossary.ts");
const { BOOKS, RELICS, TYPES } = require("../src/content/catalog.ts");
const { DEFENSE } = require("../src/shared/defense.ts");
const tokenize = createTextTokenizer(GLOSSARY);

test("rich text uses longest terms, aliases and preserves original text", () => {
  const text =
    "直接施法 +35%，闪避充能 2 次；三层导电、四名敌人、0.24 秒 / 1,906 / −8 / ∞";
  const tokens = tokenize(text);
  assert.equal(tokens.map((t) => t.value).join(""), text);
  assert.equal(tokens.find((t) => t.kind === "term").id, "direct");
  assert.ok(tokens.some((t) => t.id === "charge"));
  for (const n of ["+35%", "2", "三", "四", "0.24", "1,906", "−8", "∞"])
    assert.ok(
      tokens.some((t) => t.kind === "number" && t.value === n),
      n,
    );
  assert.equal(tokenize("大招")[0].id, "ultimate");
  assert.equal(tokenize("寒墨之书")[0].id, "book-frost");
  assert.ok(!tokenize("一旦失败").some((t) => t.kind === "number"));
});
test("raw markup stays text, tooltip mode prevents recursion, cache stays correct after turnover", () => {
  const literal = "<img src=x onerror=alert(1)> 弹反";
  assert.equal(
    tokenize(literal)
      .map((t) => t.value)
      .join(""),
    literal,
  );
  assert.ok(!tokenize(literal, false).some((t) => t.kind === "term"));
  const expected = tokenize("弹反 0.24 秒");
  for (let i = 0; i < 900; i++) tokenize(`剩余 ${i}.5 秒`);
  assert.deepEqual(tokenize("弹反 0.24 秒"), expected);
});
test("codex and tooltips share named content and unique term identities", () => {
  assert.equal(new Set(GLOSSARY.map((t) => t.id)).size, GLOSSARY.length);
  for (const b of Object.values(BOOKS))
    assert.equal(glossaryById.get(`book-${b.id}`).description, b.detail);
  for (const r of RELICS)
    assert.ok(glossaryById.get(`relic-${r.id}`).description.startsWith(r.desc));
  for (const [id, e] of Object.entries(TYPES))
    assert.equal(glossaryById.get(`enemy-${id}`).description, e.tip);
  assert.ok(TERMS.length > 40);
  assert.ok(
    glossaryById.get("parry").description.includes(String(DEFENSE.window)),
  );
  for (const entry of TERMS) assert.equal(glossaryById.get(entry.id), entry);
});
