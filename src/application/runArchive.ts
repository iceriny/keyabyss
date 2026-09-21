import type { Report } from "../contracts/game.ts";
import type { CareerProfile, ProgressionPolicy, RunArchive } from "../contracts/progression.ts";
import type { StorageAdapter } from "../platform/StorageAdapter.ts";

export const HISTORY_LIMIT = 50;
export function emptyCareer(): CareerProfile {
  return { version: 1, settlements: 0, victories: 0, defeats: 0, abandoned: 0,
    kills: 0, casts: 0, elapsed: 0, talentRanks: {}, currencies: {} };
}
function validReport(value: unknown): value is Report {
  const r = value as Report | null;
  return !!r && typeof r === "object" && typeof r.win === "boolean"
    && typeof r.book === "string" && Number.isFinite(r.kills) && Number.isFinite(r.elapsed);
}
function normalizeReport(report: Report & { date?: string }, index: number): Report {
  return { ...report, words: report.words ?? {}, relics: report.relics ?? {},
    endedAt: report.endedAt ?? report.date,
    settlementId: report.settlementId ?? `legacy-${report.date ?? index}-${report.seed}` };
}
export function readRunArchive(storage: Pick<StorageAdapter, "read">): RunArchive {
  const saved = storage.read<RunArchive | null>("archive", null);
  if (saved?.version === 1 && Array.isArray(saved.records) && saved.career?.version === 1 && saved.checkpoints) {
    return { ...saved, records: saved.records.filter(validReport).map(normalizeReport).slice(0, HISTORY_LIMIT) };
  }
  const legacy = storage.read<unknown>("history", []);
  return { version: 1, records: (Array.isArray(legacy) ? legacy : []).filter(validReport).map(normalizeReport).slice(0, HISTORY_LIMIT),
    career: emptyCareer(), checkpoints: {} };
}

/** One storage write commits both history and career; failures leave both unchanged. */
export function settleRun(archive: RunArchive, report: Report, policy?: ProgressionPolicy): RunArchive {
  const id = report.settlementId ?? `${report.seed}:${report.endedAt ?? "legacy"}`;
  const runId = report.runId ?? id;
  const previous = archive.checkpoints[runId];
  const loop = report.loop ?? 0;
  if (archive.records.some(r => r.settlementId === id) || (previous && previous.loop >= loop)) return archive;
  const delta = {
    kills: Math.max(0, report.kills - (previous?.kills ?? 0)),
    casts: Math.max(0, report.casts - (previous?.casts ?? 0)),
    elapsed: Math.max(0, report.elapsed - (previous?.elapsed ?? 0)),
  };
  const outcome = report.outcome ?? (report.win ? "victory" : "defeat");
  const eligible = !report.godMode && outcome !== "abandoned";
  const career = structuredClone(archive.career);
  career.settlements++;
  career.victories += outcome === "victory" ? 1 : 0;
  career.defeats += outcome === "defeat" ? 1 : 0;
  career.abandoned += outcome === "abandoned" ? 1 : 0;
  career.kills += delta.kills; career.casts += delta.casts; career.elapsed += delta.elapsed;
  const record = structuredClone(report);
  record.settlementId = id;
  record.words = Object.fromEntries(Object.entries(record.words ?? {}).filter(([, s]) => s.errors > 0).sort((a,b) => b[1].errors - a[1].errors).slice(0,100));
  return {
    version: 1,
    records: [record, ...archive.records].slice(0, HISTORY_LIMIT),
    career: policy && eligible ? policy(career, { id, report: structuredClone(report), delta, eligible }) : career,
    checkpoints: { ...archive.checkpoints, [runId]: { loop, kills: report.kills, casts: report.casts, elapsed: report.elapsed } },
  };
}
