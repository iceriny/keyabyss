import { useState, type CSSProperties } from "react";
import type { Report } from "../contracts/game.ts";
import type { RunArchive } from "../contracts/progression.ts";
import type { SessionView } from "../contracts/session.ts";
import { C, download, fmt } from "./storage";
import { Button, Stat } from "./components";
import { Tooltip } from "./Tooltip";
import { Sigil } from "./Sigil";

export const outcomeName = (r: Report) => r.win ? "胜利" : r.outcome === "abandoned" ? "主动结束" : "战败";
const stageLabel = (r: Report) => `第 ${(r.loop ?? 0) + 1} 周目 · 第 ${r.chapter ?? 1} 章${r.room ? ` · 第 ${r.room} / ${r.roomCount ?? "—"} 节` : ""}`;
const dateLabel = (r: Report) => r.endedAt ? new Date(r.endedAt).toLocaleString("zh-CN", { hour12: false }) : "早期战报 · 时间未记录";

function ReportDetails({ report, compact = false }: { report: Report; compact?: boolean }) {
  const mistakes = Object.entries(report.words ?? {}).filter(([, s]) => s.errors > 0).sort((a,b) => b[1].errors-a[1].errors).slice(0,12);
  const relics = Object.entries(report.relics ?? {});
  return <div className={`report-details ${compact ? "compact" : ""}`}>
    <div className="report-stage">
      <span>{stageLabel(report)}</span>
      <strong>{report.chapterName ?? "咒典远征"}</strong>
      <span>{report.bossRoom ? `${report.bossName ?? "守页者"} · 阶段 ${report.bossPhase ?? 1}` : report.wave ? `第 ${report.wave} / ${report.waveCount ?? "—"} 波` : `阶段 ${(report.stage ?? 0) + 1}`}
        {report.level ? ` · 咒术等级 ${report.level}` : ""}{report.godMode ? " · GOD MODE" : ""}</span>
    </div>
    <div className="stats-grid report-stats">
      <Stat label="击破敌人" value={report.kills} />
      <Stat label="最高连笔" value={report.maxCombo} />
      <Stat label="准确率" value={`${(report.accuracy * 100).toFixed(1)}%`} />
      <Stat label="每分钟词数" value={Math.round(report.wpm)} />
      <Stat label="战斗时长" value={fmt(report.elapsed)} />
      <Stat label="施法次数" value={report.casts} />
    </div>
    <dl className="report-tactics">
      <div><dt>总伤害</dt><dd>{report.damage?.toLocaleString() ?? "—"}</dd></div>
      <div><dt>闪避 / 完美</dt><dd>{report.dashes ?? 0} / {report.perfectDodges ?? 0}</dd></div>
      <div><dt>弹反 / 终式</dt><dd>{report.reflections ?? 0} / {report.ultimates ?? 0}</dd></div>
      <div><dt>正确 / 错误输入</dt><dd>{report.correct ?? "—"} / {report.errors ?? "—"}</dd></div>
    </dl>
    <div className="report-columns">
      <section><h3>此行构筑 <small>{relics.length} 件遗物</small></h3>
        <div className="report-relics" data-prose>{relics.length ? relics.map(([id, rank]) => { const relic = C.RELICS.find(r => r.id === id); return <span key={id}>{relic ? <Tooltip title={relic.name} description={relic.desc} category="遗物" term={id}>{relic.name}</Tooltip> : id} <b>×{rank}</b></span>; }) : <p>此行尚未获得遗物。</p>}</div>
      </section>
      <section><h3>待重写的词 <small>按错误次数排列</small></h3>
        <div className="report-mistakes">{mistakes.length ? mistakes.map(([word, stat]) => <span key={word} title={stat.meaning}>{word} <b>×{stat.errors}</b></span>) : <p>{report.schemaVersion ? "本局没有错误词记录。" : "早期战报未保留逐词明细。"}</p>}</div>
      </section>
    </div>
    <div className="report-provenance"><span>{C.BOOKS[report.book]?.name ?? report.book} · {C.MODES[report.mode]?.name ?? report.mode} · {report.vocab}</span><span>种子 {report.seed} · v{report.version}</span></div>
  </div>;
}

export function ResultPanel({ report, game, onRetry, onHistory }: { report: Report; game: SessionView; onRetry: () => void; onHistory: () => void }) {
  const abandoned = report.outcome === "abandoned";
  return <div className="run-result" data-outcome={report.win ? "victory" : abandoned ? "abandoned" : "defeat"}>
    <div className="panel-scroll result-content">
    <header className="outcome-intro">
      <div className="outcome-seal" aria-hidden="true"><Sigil /><span>{report.win ? "成" : abandoned ? "归" : "殁"}</span></div>
      <div><span className="outcome-eyebrow">{report.win ? "THE CHRONICLE REWRITTEN" : abandoned ? "RETURN TO THE ARCHIVE" : "THE INK FALLS SILENT"}</span>
        <p>{report.win ? "终页封印已破，此行墨迹长存。" : abandoned ? "合上这一页，带着所学重返书库。" : "此页止于此刻，未竟之言留待下一次书写。"}</p>
      </div>
      <span className="outcome-stamp">{outcomeName(report)}<small>{dateLabel(report)}</small></span>
    </header>
    <ReportDetails report={report} />
    </div>
    <div className="modal-footer outcome-actions">
      <Button word="home" onClick={() => game.home()}>返回书库</Button>
      <Button word="history" onClick={onHistory}>远征记录</Button>
      <Button word="report" onClick={() => download(report, "keyabyss-report.json")}>导出战报</Button>
      {report.win ? <Button word="next" variant="primary" onClick={() => game.continueLoop()}>下一周目 →</Button>
        : <Button word="retry" variant="primary" onClick={onRetry}>再写一局 →</Button>}
    </div>
  </div>;
}

export function OutcomeEffects() {
  return <div className="outcome-effects" aria-hidden="true">
    <div className="outcome-wave" /><div className="outcome-wave echo" /><div className="outcome-flare" />
    {Array.from({ length: 24 }, (_, i) => <i key={i} style={{ "--particle": i, "--delay": `${(i * 7 % 13) * .045}s` } as CSSProperties} />)}
  </div>;
}

export function HistoryPanel({ archive }: { archive: RunArchive }) {
  const [selected, setSelected] = useState(0);
  const report = archive.records[selected];
  return <div className="run-history">
    <div className="history-summary"><span>远征留痕 · 最近 {archive.records.length} / 50 份战报</span><span>新档案累计：{archive.career.victories} 次通关 · {archive.career.kills.toLocaleString()} 次击破 · {fmt(archive.career.elapsed)}</span></div>
    {!report ? <div className="history-empty"><strong>书页尚未留下墨迹</strong><p>完成一次远征后，阶段、构筑与施法记录将在这里保存。</p></div> : <div className="history-layout">
      <nav className="history-list" aria-label="历史战报">{archive.records.map((entry, i) => <Button key={entry.settlementId ?? i} word={`entry${i+1}`} className={`history-entry ${i===selected ? "selected" : ""}`} onClick={() => setSelected(i)} aria-pressed={i===selected}>
        <span className={`history-outcome ${entry.win ? "won" : "lost"}`}>{outcomeName(entry)}</span><strong>{C.BOOKS[entry.book]?.name ?? entry.book}</strong>
        <span>{stageLabel(entry)}</span><small>{dateLabel(entry)}</small>
      </Button>)}</nav>
      <article className="history-detail" aria-label="战报详情" key={report.settlementId}>
        <ReportDetails report={report} compact />
        <Button word="export" onClick={() => download(report, "keyabyss-history-report.json")}>导出这份战报</Button>
      </article>
    </div>}
  </div>;
}
