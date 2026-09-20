export interface TextTerm {
  id: string;
  name: string;
  aliases?: readonly string[];
}
export interface TextToken {
  kind: "text" | "number" | "term";
  value: string;
  id?: string;
}

// Longest-match trie: text scanning does not loop through the whole glossary.
export function createTextTokenizer(entries: readonly TextTerm[]) {
  interface Trie {
    next: Map<string, Trie>;
    id?: string;
  }
  const root: Trie = { next: new Map() };
  for (const entry of entries)
    for (const name of [entry.name, ...(entry.aliases ?? [])]) {
      let node = root;
      for (const char of name) {
        if (!node.next.has(char)) node.next.set(char, { next: new Map() });
        node = node.next.get(char)!;
      }
      node.id ??= entry.id;
    }
  const number =
    /(?:[+−-]?(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d+)?(?:[%％]|倍)?|∞|[零〇一二两三四五六七八九十百千万]+(?=[层只次秒名个点词章场道枚代倍]))/uy;
  const cache = new Map<string, readonly TextToken[]>();
  return (text: string, terms = true): readonly TextToken[] => {
    const key = `${terms ? 1 : 0}:${text}`;
    const cached = cache.get(key);
    if (cached) return cached;
    const tokens: TextToken[] = [];
    const push = (token: TextToken) => {
      const last = tokens.at(-1);
      if (token.kind === "text" && last?.kind === "text")
        last.value += token.value;
      else tokens.push(token);
    };
    for (let i = 0; i < text.length;) {
      let node = root,
        found: { id: string; end: number } | undefined;
      if (terms)
        for (let j = i; j < text.length; j++) {
          const next = node.next.get(text[j]);
          if (!next) break;
          node = next;
          if (node.id) found = { id: node.id, end: j + 1 };
        }
      if (found) {
        push({ kind: "term", id: found.id, value: text.slice(i, found.end) });
        i = found.end;
        continue;
      }
      number.lastIndex = i;
      const numeric = number.exec(text);
      if (numeric) {
        push({ kind: "number", value: numeric[0] });
        i += numeric[0].length;
      } else {
        push({ kind: "text", value: text[i] });
        i++;
      }
    }
    // Bounded FIFO cache avoids retaining changing timers or imported vocabulary forever.
    if (cache.size >= 512) cache.delete(cache.keys().next().value!);
    cache.set(key, tokens);
    return tokens;
  };
}
