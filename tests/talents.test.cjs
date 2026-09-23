const test = require("node:test");
const assert = require("node:assert/strict");
const { TALENT_BOOKS, TALENT_NODES } = require("../src/content/talents.ts");
const { resolveTalents, removeTalent, resolveTalentLoadout, secondaryBookCandidates } = require("../src/shared/talents.ts");
const { emptyTalentProgress, earnedTalentPoints, settleTalentProgress, readTalentProgress, readGodTalents, updateTalentLoadout } = require("../src/application/talentProgression.ts");
const { clearGodModeArchive, emptyCareer, settleRun } = require("../src/application/runArchive.ts");
const { StorageAdapter } = require("../src/platform/StorageAdapter.ts");

const report = (overrides = {}) => ({ runId: "run-a", settlementId: "run-a:0", loop: 0, manualCharacters: 125, godMode: false, book: "frost", mode: "normal", seed: "SEED", endedAt: "2026-09-23", outcome: "defeat", win: false, kills: 4, casts: 12, elapsed: 30, words: {}, relics: {}, ...overrides });
const all = TALENT_NODES.map(node => node.id);

test("each book grants its own free root without numerical grants", () => {
  for (const book of TALENT_BOOKS) {
    const result = resolveTalents(book, [], 0);
    assert.deepEqual(result.allocated, [`${book}-root`]);
    assert.equal(result.spent, 0);
    assert.deepEqual(result.grants, {});
    assert.equal(result.capabilities.length, 1);
  }
  assert.deepEqual(resolveTalents("unknown", all, 24).allocated, []);
});

test("unknown, duplicate, disconnected and malformed nodes cannot add power", () => {
  const result = resolveTalents("frost", ["cold-ink", "cold-ink", "missing", "branch", "echo", 123], 2);
  assert.deepEqual(result.allocated, ["frost-root", "cold-ink"]);
  assert.deepEqual(result.grants, { coldStacks: 1 });
  assert.equal(result.spent, 1);
  assert.deepEqual(resolveTalents("frost", { bad: true }, 24).allocated, ["frost-root"]);
});

test("budget is finite, integer and capped; God still validates graph and exclusivity", () => {
  for (const budget of [NaN, Infinity, -1, 0]) assert.equal(resolveTalents("frost", all, budget).spent, 0);
  assert.equal(resolveTalents("frost", ["cold-ink", "crystal"], 1.9).spent, 1);
  assert.deepEqual(resolveTalents("frost", all, 10000), resolveTalents("frost", all, 24));
  const god = resolveTalents("frost", all, 0, true);
  assert.ok(god.spent > 2);
  assert.ok(god.grants.secondaryBinding);
  assert.equal(god.grants.singleFocus, undefined);
  assert.deepEqual(resolveTalents("frost", ["echo"], 0, true).allocated, ["frost-root"]);
});

test("node ordering never changes the validated set or grants", () => {
  for (const book of TALENT_BOOKS) for (const budget of [2, 5, 9, 24]) {
    const baseline = resolveTalents(book, all, budget);
    assert.deepEqual(resolveTalents(book, [...all].reverse(), budget), baseline);
    assert.deepEqual(resolveTalents(book, [...all.slice(8), ...all.slice(0, 8)], budget), baseline);
  }
});

test("the one graph is traversable from every root and crosses elements", () => {
  for (const book of TALENT_BOOKS) {
    const result = resolveTalents(book, all, 24);
    assert.equal(result.allocated.length, all.length - 1);
    assert.ok(result.capabilities.includes("cold"));
    assert.ok(result.capabilities.includes("carrier"));
    assert.ok(result.capabilities.includes("release"));
  }
});

test("withdrawing a bridge removes disconnected dependent nodes and refunds them", () => {
  const chain = ["cold-ink", "crystal", "binding", "paper-carrier", "echo"];
  const before = resolveTalents("frost", chain, 24);
  assert.equal(before.grants.carrierRelease, 1);
  const after = removeTalent("frost", before.allocated, "crystal", 24);
  assert.deepEqual(after, ["frost-root", "cold-ink"]);
  assert.deepEqual(removeTalent("frost", [], "frost-root", 24), ["frost-root"]);
});

test("release and defense require an actual carrier capability", () => {
  const noCarrier = resolveTalents("frost", ["rime", "paper-ward"], 24);
  assert.equal(noCarrier.grants.carrierGuard, undefined);
  const carrier = resolveTalents("spirit", ["paper-ward", "copy-page", "paper-carrier", "echo"], 24);
  assert.equal(carrier.grants.carrierGuard, 1);
  assert.equal(carrier.grants.carrierRelease, 1);
});

test("switching main books revalidates connectivity and binding gates secondary candidates", () => {
  const frost = ["cold-ink", "crystal", "binding"];
  assert.deepEqual(secondaryBookCandidates("frost", frost, 4).sort(), ["flame", "spirit", "storm"]);
  assert.deepEqual(secondaryBookCandidates("frost", frost, 2), []);
  assert.deepEqual(secondaryBookCandidates("frost", ["cold-ink", "crystal", "focus"], 4), []);
  assert.deepEqual(resolveTalentLoadout("storm", { allocated: frost, secondaryBook: "flame" }, 24), { allocated: ["storm-root"] });
  assert.equal(resolveTalentLoadout("frost", { allocated: frost, secondaryBook: "frost" }, 24).secondaryBook, undefined);
  assert.equal(resolveTalentLoadout("frost", { allocated: frost, secondaryBook: "flame" }, 24).secondaryBook, "flame");
});

test("ordinary progress starts at two, earns one per 120 completed characters and stops at 24", () => {
  assert.equal(earnedTalentPoints(0), 2);
  assert.equal(earnedTalentPoints(119), 2);
  assert.equal(earnedTalentPoints(120), 3);
  assert.equal(earnedTalentPoints(2640), 24);
  assert.equal(earnedTalentPoints(100000), 24);
  assert.equal(earnedTalentPoints(NaN), 2);
  const first = settleTalentProgress(emptyTalentProgress(), report());
  assert.equal(first.progress.manualCharacters, 125);
  assert.deepEqual(first.receipt, { characters: 125, points: 1 });
});

test("duplicate settlements, alternate IDs and cumulative later loops cannot double award", () => {
  const initial = settleTalentProgress(emptyTalentProgress(), report()).progress;
  assert.equal(settleTalentProgress(initial, report()).progress, initial);
  const same = settleTalentProgress(initial, report({ settlementId: "run-a:other" }));
  assert.deepEqual(same.receipt, { characters: 0, points: 0 });
  const next = settleTalentProgress(same.progress, report({ settlementId: "run-a:1", loop: 1, manualCharacters: 250 }));
  assert.equal(next.progress.manualCharacters, 250);
  assert.deepEqual(next.receipt, { characters: 125, points: 1 });
  const stale = settleTalentProgress(next.progress, report({ settlementId: "stale", manualCharacters: 70 }));
  assert.equal(stale.progress.byRun["run-a"], 250);
  assert.equal(stale.progress.manualCharacters, 250);
});

test("abandoned characters count; God and legacy reports cannot touch normal progression", () => {
  const initial = emptyTalentProgress();
  assert.equal(settleTalentProgress(initial, report({ godMode: true, manualCharacters: 9999 })).progress, initial);
  assert.equal(settleTalentProgress(initial, report({ manualCharacters: undefined, correct: 9999 })).progress, initial);
  assert.equal(settleTalentProgress(initial, report({ manualCharacters: Infinity })).progress, initial);
  const abandoned = settleTalentProgress(initial, report({ outcome: "abandoned" }));
  assert.equal(abandoned.progress.manualCharacters, 125);
  const second = settleTalentProgress(abandoned.progress, report({ runId: "run-b", settlementId: "run-b:0", manualCharacters: 115 }));
  assert.equal(second.progress.manualCharacters, 240);
});

test("normal and God loadouts persist separately through the versioned storage adapter", () => {
  const values = new Map();
  const storage = new StorageAdapter(() => ({ getItem: key => values.get(key) ?? null, setItem: (key, value) => values.set(key, value) }));
  const normal = updateTalentLoadout(emptyTalentProgress(), "frost", { allocated: all }, 2);
  storage.save("talents", normal);
  storage.save("talents-god", { version: 1, byBook: { flame: { allocated: all, secondaryBook: "storm" } } });
  assert.equal(readTalentProgress(storage).byBook.frost.allocated.length, 3);
  assert.equal(readGodTalents(storage).byBook.flame.allocated.length, 19);
  assert.equal(readGodTalents(storage).byBook.flame.secondaryBook, "storm");
  storage.save("talents-god", { version: 1, byBook: {} });
  assert.deepEqual(readTalentProgress(storage), normal);
  assert.equal(JSON.parse(values.get("keyabyss.talents")).schema, "keyabyss");
});

test("God archive cleanup preserves ordinary reports, checkpoints, career and shared run identities", () => {
  const normal = report(), god = report({ runId: "god-run", settlementId: "god:0", godMode: true });
  const career = emptyCareer();
  const checkpoint = { loop: 0, kills: 4, casts: 12, elapsed: 30 };
  const archive = { version: 1, records: [god, normal, report({ godMode: true, settlementId: "mixed" })], career, checkpoints: { "god-run": checkpoint, "run-a": checkpoint, older: checkpoint } };
  const cleaned = clearGodModeArchive(archive);
  assert.deepEqual(cleaned.records, [normal]);
  assert.deepEqual(Object.keys(cleaned.checkpoints), ["run-a", "older"]);
  assert.equal(cleaned.career, career);
  assert.equal(archive.records.length, 3);
  assert.equal(clearGodModeArchive(cleaned), cleaned);
});

test("God career stays isolated and cleanup finds checkpoints beyond the 50-report window", () => {
  let archive = { version: 1, records: [], career: emptyCareer(), checkpoints: {} };
  archive = settleRun(archive, report());
  const ordinaryCareer = archive.career;
  for (let i = 0; i < 60; i++) archive = settleRun(archive, report({ runId: `god-${i}`, settlementId: `god-${i}:0`, godMode: true }));
  archive = settleRun(archive, report({ runId: "run-b", settlementId: "run-b:0" }));
  assert.equal(archive.records.length, 50);
  assert.equal(archive.godCareer.settlements, 60);
  assert.equal(archive.godCareer.kills, 240);
  assert.equal(archive.career.kills, ordinaryCareer.kills * 2);
  assert.equal(archive.career.settlements, 2);
  assert.equal(Object.keys(archive.checkpoints).length, 62);
  assert.equal(archive.checkpoints["god-0"].godMode, true);
  const before = archive.career;
  const cleaned = clearGodModeArchive(archive);
  assert.equal(cleaned.career, before);
  assert.equal(cleaned.godCareer, undefined);
  assert.equal(cleaned.records.length, 1);
  assert.equal(cleaned.records[0].runId, "run-b");
  assert.deepEqual(Object.keys(cleaned.checkpoints), ["run-a", "run-b"]);
});

test("God loop increments only God career and never invokes ordinary progression policy", () => {
  const initial = { version: 1, records: [], career: emptyCareer(), checkpoints: {} };
  const policy = () => assert.fail("God report reached ordinary progression policy");
  const first = settleRun(initial, report({ godMode: true, win: true, outcome: "victory" }), policy);
  const next = settleRun(first, report({ godMode: true, settlementId: "run-a:1", loop: 1, kills: 10, casts: 20, elapsed: 60 }), policy);
  assert.equal(next.career, initial.career);
  assert.equal(next.godCareer.kills, 10);
  assert.equal(next.godCareer.casts, 20);
  assert.equal(next.godCareer.elapsed, 60);
  assert.equal(next.godCareer.settlements, 2);
});
