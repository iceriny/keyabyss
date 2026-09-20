import type { Word } from "../contracts/game.ts";
type WordGroup = { initial: string; length: number; words: Word[] };
interface ImportedEntry {
  word?: unknown;
  name?: unknown;
  headWord?: unknown;
  text?: unknown;
  meaning?: unknown;
  translation?: unknown;
  trans?: unknown;
  content?: { word?: { content?: { trans?: { tranCn: string }[] } } };
}

function csv(text: string, sep = ",") {
  const rows: string[][] = [];
  let row: string[] = [],
    v = "",
    quoted = false;
  for (let i = 0; i < text.length; i++) {
    let c = text[i];
    if (c === '"') {
      if (quoted && text[i + 1] === '"') {
        v += '"';
        i++;
      } else quoted = !quoted;
    } else if (c === sep && !quoted) {
      row.push(v);
      v = "";
    } else if ((c === "\n" || c === "\r") && !quoted) {
      if (c === "\r" && text[i + 1] === "\n") i++;
      row.push(v);
      if (row.some((x) => x.trim())) rows.push(row);
      row = [];
      v = "";
    } else v += c;
  }
  if (quoted) throw Error("CSV 引号没有闭合，请检查文件。");
  row.push(v);
  if (row.some((x) => x.trim())) rows.push(row);
  return rows;
}
function normalize(entries: unknown) {
  if (!Array.isArray(entries))
    throw Error("词库需要是数组，或包含 words 数组的对象。");
  if (entries.length > 100000) throw Error("一次最多导入 100,000 条记录。");
  const words: Word[] = [],
    seen = new Set<string>(),
    invalid: string[] = [];
  let duplicates = 0;
  for (const value of entries) {
    const entry = value as string | unknown[] | ImportedEntry;
    let text: unknown = "",
      meaning: unknown = "";
    if (typeof entry === "string") text = entry;
    else if (Array.isArray(entry)) {
      text = entry[0];
      meaning = entry[1] || "";
    } else if (entry && typeof entry === "object") {
      text = entry.word ?? entry.name ?? entry.headWord ?? entry.text ?? "";
      meaning = entry.meaning ?? entry.translation ?? entry.trans ?? "";
      if (Array.isArray(meaning)) meaning = meaning.join("；");
      if (!meaning && entry.content?.word?.content?.trans)
        meaning = entry.content.word.content.trans
          .map((t) => t.tranCn)
          .join("；");
    }
    const normalizedText = String(text ?? "")
      .replace(/^\uFEFF/, "")
      .trim()
      .normalize("NFKC")
      .toLowerCase();
    if (!/^[a-z][a-z0-9_'\-]{0,23}$/.test(normalizedText)) {
      invalid.push(normalizedText.slice(0, 70));
      continue;
    }
    if (seen.has(normalizedText)) {
      duplicates++;
      continue;
    }
    seen.add(normalizedText);
    words.push({
      word: normalizedText,
      meaning: String(meaning ?? "").slice(0, 240),
    });
  }
  return {
    words,
    raw: entries.length,
    duplicates,
    invalid,
    initials: new Set(words.map((w) => w.word[0])).size,
  };
}
function parseImport(text: string, filename = "words.txt") {
  if (typeof text !== "string" || text.length > 5000000)
    throw Error("文件过大，请使用不超过 5 MB 的 UTF-8 文本。");
  text = text.replace(/^\uFEFF/, "").trim();
  if (!text) throw Error("词库是空的。");
  let entries,
    name = filename.replace(/\.[^.]+$/, "");
  if (/\.(json|jsonl)$/i.test(filename) || /^[\[{]/.test(text)) {
    try {
      const d = JSON.parse(text);
      entries = Array.isArray(d) ? d : (d.words ?? d.entries ?? d.data);
      if (!Array.isArray(d)) name = String(d.title ?? d.name ?? name);
    } catch (e) {
      if (/\.jsonl$/i.test(filename)) {
        try {
          entries = text
            .split(/\r?\n/)
            .filter(Boolean)
            .map((l) => JSON.parse(l));
        } catch {
          throw Error("JSONL 中有无法解析的行。");
        }
      } else throw Error("JSON 格式不正确：" + (e as Error).message);
    }
  } else {
    const lines = text
      .split(/\r?\n/)
      .filter((l) => l.trim() && !l.trim().startsWith("#"));
    const isCSV = /\.csv$/i.test(filename) || lines[0]?.includes(",");
    const tab = lines[0]?.includes("\t");
    if (isCSV || tab) {
      const rows = csv(lines.join("\n"), tab ? "\t" : ",");
      let wi = 0,
        mi = 1;
      const header = rows[0]?.map((x) => x.trim().toLowerCase()) || [];
      const wordHeaders = ["word", "name", "headword", "text", "单词", "词条"];
      const idx = header.findIndex((h) => wordHeaders.includes(h));
      if (idx >= 0) {
        wi = idx;
        mi = header.findIndex((h) =>
          ["meaning", "translation", "trans", "释义", "中文"].includes(h),
        );
        rows.shift();
      }
      entries = rows.map((r) => [r[wi], mi >= 0 ? r[mi] : ""]);
    } else entries = lines;
  }
  const out = normalize(entries);
  if (!out.words.length)
    throw Error(
      "没有可用词条。支持 1–24 位英文词、数字、下划线、连字符和英文撇号；短语暂不参与战斗。",
    );
  return { ...out, title: name.slice(0, 80) };
}
class WordPool {
  readonly words: Word[];
  readonly rng: () => number;
  readonly recent: string[] = [];
  readonly rangeCache = new Map<string, WordGroup[]>();
  readonly shortest: number;
  readonly longest: number;
  private readonly buckets: WordGroup[] = [];
  private readonly positions = new Map<
    string,
    { bucket: WordGroup; index: number }
  >();
  constructor(entries: unknown, rng = Math.random) {
    const n = normalize(entries);
    if (!n.words.length) throw Error("所选词库没有可用词条。");
    this.words = n.words;
    this.rng = rng;
    const index = new Map<string, WordGroup>();
    let shortest = 24,
      longest = 1;
    for (const word of this.words) {
      const length = word.word.length,
        initial = word.word[0],
        key = `${length}:${initial}`;
      let bucket = index.get(key);
      if (!bucket) {
        bucket = { initial, length, words: [] };
        index.set(key, bucket);
        this.buckets.push(bucket);
      }
      this.positions.set(word.word, { bucket, index: bucket.words.length });
      bucket.words.push(word);
      shortest = Math.min(shortest, length);
      longest = Math.max(longest, length);
    }
    this.shortest = shortest;
    this.longest = longest;
  }
  choose(
    targets: { word: string; dead?: boolean }[] = [],
    min = 1,
    max = 6,
  ): Word {
    // O(N) once at load; all later work is bounded by 24 * 26 buckets and live/recent words.
    // Exact rank sampling avoids rejection loops and any whole-dictionary exhaustion scan.
    min = Math.max(1, Math.min(24, Math.round(min)));
    max = Math.max(min, Math.min(24, Math.round(max)));
    const key = `${min}:${max}`;
    let groups = this.rangeCache.get(key);
    if (!groups) {
      const distance = (g: WordGroup) =>
        Math.max(min - g.length, 0, g.length - max);
      const best = this.buckets.reduce(
        (d, g) => Math.min(d, distance(g)),
        Infinity,
      );
      groups = this.buckets.filter((g) => distance(g) === best);
      this.rangeCache.set(key, groups);
    }
    const used = new Set<string>(),
      initials = new Set<string>();
    for (const target of targets)
      if (!target.dead) {
        used.add(target.word);
        initials.add(target.word[0]);
      }
    const unused = groups.filter((g) => !initials.has(g.initial));
    const draw = (
      candidates: WordGroup[],
      exclude?: Set<string>,
    ): Word | null => {
      const blocked = new Map<WordGroup, number[]>();
      for (const word of exclude ?? []) {
        const position = this.positions.get(word);
        if (!position) continue;
        let list = blocked.get(position.bucket);
        if (!list) {
          list = [];
          blocked.set(position.bucket, list);
        }
        list.push(position.index);
      }
      const count = candidates.reduce(
        (n, g) => n + g.words.length - (blocked.get(g)?.length ?? 0),
        0,
      );
      if (!count) return null;
      let rank = Math.floor(this.rng() * count);
      for (const group of candidates) {
        const excluded = blocked.get(group) ?? [];
        const size = group.words.length - excluded.length;
        if (rank >= size) {
          rank -= size;
          continue;
        }
        excluded.sort((a, b) => a - b);
        for (const index of excluded) {
          if (index <= rank) rank++;
          else break;
        }
        return group.words[rank];
      }
      return null;
    };
    const choice =
      draw(unused, new Set(this.recent)) ||
      draw(unused) ||
      draw(groups, used) ||
      draw(groups)!;
    this.recent.push(choice.word);
    if (this.recent.length > 15) this.recent.shift();
    return { ...choice };
  }
}

export { csv, normalize, parseImport, WordPool };
