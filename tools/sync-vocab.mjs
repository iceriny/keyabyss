/** Explicit maintenance: download complete source files, never truncate. Build remains offline. */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";
import { parseImport, normalize } from "../src/vocabulary/index.ts";
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const manifest = JSON.parse(
  fs.readFileSync(path.join(root, "data/sources.json"), "utf8"),
);
const fullSources = {
  primary1: ["PEP_SL_XiaoXue1_1_t.json", "PEP_SL_XiaoXue1_2_t.json"],
  primary2: ["PEP_SL_XiaoXue2_1_t.json", "PEP_SL_XiaoXue2_2_t.json"],
  ...Object.fromEntries(
    [3, 4, 5, 6].map((n) => [
      "primary" + n,
      [`PEPXiaoXue${n}_1_T.json`, `PEPXiaoXue${n}_2_T.json`],
    ]),
  ),
  junior: [
    "PEPChuZhong7_1_T.json",
    "PEPChuZhong7_2_T.json",
    "PEPChuZhong8_1_T.json",
    "PEPChuZhong8_2_T.json",
    "PEPChuZhong9_1_T.json",
  ],
  senior: Array.from({ length: 11 }, (_, i) => `PEPGaoZhong_${i + 1}_T.json`),
  cet4: ["CET4_T.json"],
  cet6: ["CET6_T.json"],
};
const titles = {
  primary1: "小学一年级 · 全册",
  primary2: "小学二年级 · 全册",
  primary3: "小学三年级 · 全册",
  primary4: "小学四年级 · 全册",
  primary5: "小学五年级 · 全册",
  primary6: "小学六年级 · 全册",
  junior: "初中英语 · 全套教材",
  senior: "高中英语 · 全套教材",
  cet4: "大学英语四级 · 完整词表",
  cet6: "大学英语六级 · 完整词表",
};
const ids = process.argv.slice(2);
for (const id of ids)
  if (!fullSources[id]) throw Error("Unknown upstream vocabulary: " + id);
const books = manifest.books.filter(
  (b) => fullSources[b.id] && (!ids.length || ids.includes(b.id)),
);
let failures = 0;
for (const [i, b] of books.entries()) {
  try {
    const sources = [],
      words = [],
      excluded = [];
    let raw = 0,
      duplicates = 0;
    for (const file of fullSources[b.id]) {
      let body, sourceURL;
      for (const url of [
        `https://raw.githubusercontent.com/RealKai42/qwerty-learner/master/public/dicts/${file}`,
        `https://cdn.jsdelivr.net/gh/RealKai42/qwerty-learner@master/public/dicts/${file}`,
      ]) {
        try {
          const r = await fetch(url, { signal: AbortSignal.timeout(20000) });
          if (!r.ok) throw Error("HTTP " + r.status);
          body = await r.text();
          sourceURL = url;
          break;
        } catch (e) {
          console.warn(file + ": " + e.message);
        }
      }
      if (!body)
        throw Error(
          "Source failed: " +
            file +
            "; preserving existing complete dictionary.",
        );
      const n = parseImport(body, file);
      words.push(...n.words);
      excluded.push(...n.invalid);
      raw += n.raw;
      duplicates += n.duplicates;
      sources.push({
        file,
        url: sourceURL,
        sha256: createHash("sha256").update(body).digest("hex"),
        records: n.raw,
      });
    }
    const n = normalize(words);
    duplicates += n.duplicates;
    const result = {
      ...b,
      title: titles[b.id],
      description:
        titles[b.id] + "；保留源中文释义，完整同步后过滤不支持的短语并去重。",
      snapshot: "complete",
      sourceBlob: null,
      sourcePath: undefined,
      upstreamFile: fullSources[b.id][0],
      upstreamFiles: fullSources[b.id],
      sources,
      retrievedAt: new Date().toISOString(),
      scope: `完整同步 ${sources.length} 个源文件；原始 ${raw} 条，过滤 ${excluded.length} 条，去重 ${duplicates} 条。`,
      sourceRecords: raw,
      excluded,
      duplicates,
      count: n.words.length,
      words: n.words,
    };
    const dest = path.join(root, "data", b.id + ".json");
    fs.writeFileSync(dest + ".tmp", JSON.stringify(result, null, 2) + "\n");
    fs.renameSync(dest + ".tmp", dest);
    console.log(
      `[${i + 1}/${books.length}] ${b.id}: ${n.words.length} words / ${sources.length} complete source files.`,
    );
  } catch (e) {
    failures++;
    console.error(b.id + ": " + e.message);
  }
}
await import("./bundle-vocab.mjs");
if (failures) process.exitCode = 1;
