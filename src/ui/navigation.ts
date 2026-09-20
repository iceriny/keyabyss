/** Game navigation order. Secondary actions remain available by pointer and word command. */
export function navigationOrder(word?: string) {
  if (!word || ["back", "import", "export", "delete", "full"].includes(word))
    return undefined;
  const primary: Record<string, number> = {
    start: 0,
    begin: 0,
    resume: 0,
    retry: 0,
    list: 10,
    frost: 10,
    storm: 11,
    spirit: 12,
    flame: 13,
    easy: 20,
    normal: 21,
    hard: 22,
    nightmare: 23,
    doom: 24,
    grow: 30,
    seed: 40,
    vocab: 60,
    codex: 61,
    help: 62,
    settings: 63,
  };
  return primary[word] ?? 100;
}
