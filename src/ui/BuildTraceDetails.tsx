import type { Report } from '../contracts/game.ts';
import type { BuildTraceEntry } from '../contracts/build-trace.ts';
import { BOOKS } from '../content/catalog.ts';
import './build-trace.css';

const labels: Record<BuildTraceEntry['kind'], string> = { cast: '人工发动', copy: '复写付费', store: '入页保存', split: '份额分配', relay: '载体中继', hit: '命中交付', guard: '护持消耗', release: '载体出口', recover: '余量入库', loss: '资源消散' };
const reasons: Record<string, string> = {
  'processing-loss': '首次加工损耗',
  'manual-characters': '完词供给', 'character-funded-copy': '人工额度复写', 'mark-funded-copy': '标记收益转入复写',
  'carrier-page': '片段入页', 'merge-payload': '兼容载荷归并', 'crystal-shell': '主术份额转入晶壳',
  'fragment-allocation': '本体分出碎片', 'conduction-allocation': '本体分出电性份额', 'conduction-to-carrier': '电性份额转交载体',
  'paid-payload': '本次支付的命中份额', 'carrier-guard-paid': '扣除护持成本', 'carrier-payload-release': '正常出口交付',
  'thermal-payload-release': '受热提前交付', 'guard-residual-release': '护持后交出余载', 'paper-recovery': '未用纸页折损回收',
  'miss-recovery': '失靶余额折损回收', 'reserve-unused': '无目标的储备退回', 'burn-expired-recovery': '到期灼烧余量回收',
  'burn-extracted': '抽取未来灼烧', 'burn-death-recovery': '死亡目标余量回收', 'room-clear-pending': '清房终结待发主术',
  'room-clear-supply': '清房终结未用供给', 'room-clear-heat': '清房散失储备', 'room-change-heat': '跨房未保留储备',
  'capacity-shrink-heat': '容量缩小溢出', 'bank-capacity': '储备满容量拒收', 'burn-capacity': '灼烧贡献满容量拒收',
  'burn-expired': '灼烧到期余额消散', 'burn-extraction-discount': '抽取折损', 'burn-death-discount': '死亡回收折损',
  'copy-capacity-or-supply': '容量或供给不足', 'crystal-capacity': '晶壳容量不足', 'page-room-clear': '清房终结载荷',
  'guard-balance-expired': '护持余量终结', 'page-expired': '载体到期', 'packet-miss': '片段失去接收者',
  'pending-overwritten': '新主术接替待发主术', 'pending-room-change': '待发主术跨房终结', 'pending-expired': '待发主术到期',
};
function sourceName(id: string, report: Report): string {
  const split = id.indexOf(':'), kind = id.slice(0, split), key = id.slice(split + 1);
  if (kind === 'book') return Object.values(BOOKS).find(book => book.id === key)?.name ?? key;
  if (kind === 'talent') return report.talentNames?.[key] ?? key;
  if (kind === 'relic') return report.relicDefinitions?.[key]?.name ?? key;
  if (kind === 'event') return report.buildEvents?.find(event => event.id === key)?.name ?? key;
  return id;
}
export function BuildTraceDetails({ report }: { report: Report }) {
  const trace = report.buildTrace;
  if (!trace?.entries.length) return null;
  return <details className="build-trace"><summary>法术流转 · 最近 {trace.entries.length} 条回执</summary>
    <p>威力数值记录片段的支付与转交；构筑来源按发动时保存。{trace.omitted > 0 && `更早的 ${trace.omitted} 条已从明细中略去。`}</p>
    <ol className="build-trace-entries">{[...trace.entries].reverse().map(entry => <li key={entry.sequence}>
      <strong>{labels[entry.kind]}</strong><span>第 {entry.room} 节{entry.rootId !== null ? ` · 发动 ${entry.rootId}` : ''}{entry.packetId !== null ? ` · 片段 ${entry.packetId}` : ''}</span>
      <span>{entry.power !== 0 ? `威力 ${Math.round(entry.power * 100) / 100}` : ''}{entry.heat !== 0 ? ` · 热量 ${Math.round(entry.heat * 100) / 100}` : ''}</span>
      <small>{reasons[entry.reason] ?? labels[entry.kind]} · 构筑来源：{entry.sourceIds.map(id => sourceName(id, report)).join(' · ') || '既存余额'}</small>
    </li>)}</ol>
  </details>;
}
