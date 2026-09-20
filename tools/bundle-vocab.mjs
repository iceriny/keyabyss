/** Rebuild offline assets from independent JSON dictionaries; no word literals in game code. */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";
import { createRequire } from "node:module";
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const require = createRequire(import.meta.url),
  C = require("../src/vocabulary/index.ts");
const dir = path.join(root, "data");
const manifest = JSON.parse(
  fs.readFileSync(path.join(dir, "sources.json"), "utf8"),
);
const order = [
  "primary1",
  "primary2",
  "primary3",
  "primary4",
  "primary5",
  "primary6",
  "junior",
  "senior",
  "cet4",
  "cet6",
  "cpp",
  "extension",
];
const books = manifest.books
  .map((meta) => {
    const b = JSON.parse(
      fs.readFileSync(path.join(dir, meta.id + ".json"), "utf8"),
    );
    const n = C.normalize(b.words);
    if (!n.words.length) throw Error(`Empty dictionary: ${b.id}`);
    if (n.invalid.length || n.duplicates)
      throw Error(
        `Invalid or duplicate entries in data/${b.id}.json; normalize it first.`,
      );
    if (b.upstreamFile && b.snapshot !== "complete")
      throw Error(
        `Incomplete dictionary ${b.id}; run npm run sync-vocab first.`,
      );
    return b;
  })
  .sort((a, b) => order.indexOf(a.id) - order.indexOf(b.id));
const assetDir = path.join(root, "public", "word");
fs.mkdirSync(assetDir, { recursive: true });
for (const file of fs.readdirSync(assetDir))
  if (/^vocab-[a-z0-9]+-[a-f0-9]{8}\.js$/.test(file))
    fs.unlinkSync(path.join(assetDir, file));
const oldAssets = path.join(root, "public", "assets");
if (fs.existsSync(oldAssets))
  for (const file of fs.readdirSync(oldAssets))
    if (/^vocab-[a-z0-9]+-[a-f0-9]{8}\.js$/.test(file))
      fs.unlinkSync(path.join(oldAssets, file));
const index = books.map(({ words, ...meta }) => {
  const normalized = C.normalize(words).words;
  const payload = normalized.map((w) => (w.meaning ? w : w.word));
  const body =
    "window.KA_WORDS??={};window.KA_WORDS[" +
    JSON.stringify(meta.id) +
    "]=" +
    JSON.stringify(payload) +
    ";\n";
  const name =
    "vocab-" +
    meta.id +
    "-" +
    createHash("sha256").update(body).digest("hex").slice(0, 8) +
    ".js";
  fs.writeFileSync(path.join(assetDir, name), body);
  fs.writeFileSync(
    path.join(assetDir, meta.id + ".json"),
    JSON.stringify({ ...meta, count: normalized.length, words: normalized }) +
      "\n",
  );
  return {
    ...meta,
    words: normalized.slice(0, 32),
    count: normalized.length,
    asset: "./word/" + name,
  };
});
fs.writeFileSync(
  path.join(dir, "vocab-index.js"),
  "/* Generated metadata and previews only; complete dictionaries load on demand. */\nwindow.KAVOCAB=" +
    JSON.stringify({ schemaVersion: 2, books: index }) +
    ";\n",
);
fs.writeFileSync(
  path.join(dir, "sources.json"),
  JSON.stringify(
    {
      ...manifest,
      books: books.map(({ words, ...b }) => ({ ...b, count: words.length })),
    },
    null,
    2,
  ) + "\n",
);
console.log(
  `Bundled ${books.length} dictionaries / ${books.reduce((n, b) => n + b.words.length, 0).toLocaleString()} entries (overlap between dictionaries possible).`,
);
