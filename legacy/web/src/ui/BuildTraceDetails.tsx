import type { Report } from '../contracts/game.ts';
import type { BuildTraceEntry } from '../contracts/build-trace.ts';
import { BOOKS } from '../content/catalog.ts';
import './build-trace.css';

const labels: Record<BuildTraceEntry['kind'], string> = { cast: '施法', copy: '复写', store: '保存法术', split: '分出法术', relay: '传递法术', hit: '命中', guard: '抵挡攻击', release: '释放法术', recover: '补充储备', loss: '力量消散' };
const reasons: Record<string, string> = {
  'processing-loss': '复写或分裂时损耗',
  'manual-characters': '完成咒文', 'character-funded-copy': '消耗积攒的输入进度', 'mark-funded-copy': '用字母奖励复写',
  'carrier-page': '将法术保存在纸页中', 'merge-payload': '合并已保存的法术', 'crystal-shell': '将部分主术保存在冰晶中',
  'fragment-allocation': '分出碎片', 'conduction-allocation': '分出用于连锁的威力', 'conduction-to-carrier': '经过已保存的法术继续传递',
  'paid-payload': '本次命中使用的威力', 'carrier-guard-paid': '用法术威力抵挡攻击', 'carrier-payload-release': '等待结束，释放法术',
  'thermal-payload-release': '受热后提前释放', 'guard-residual-release': '抵挡攻击后释放剩余法术', 'paper-recovery': '回收未用的纸页法术',
  'miss-recovery': '目标消失后回收剩余法术', 'reserve-unused': '没有目标，退回储备', 'burn-expired-recovery': '回收未生效的灼烧',
  'burn-extracted': '提前收回部分灼烧', 'burn-death-recovery': '目标死亡后回收剩余灼烧', 'room-clear-pending': '清房后结束待发法术',
  'room-clear-supply': '清房后未用的材料消散', 'room-clear-heat': '清房时损失储备', 'room-change-heat': '进入下一房时未保留储备',
  'capacity-shrink-heat': '储备上限降低，多余部分消散', 'bank-capacity': '储备已满', 'burn-capacity': '灼烧已达到上限',
  'burn-expired': '灼烧到期，剩余力量消散', 'burn-extraction-discount': '提前收回时损耗', 'burn-death-discount': '死亡回收时损耗',
  'copy-capacity-or-supply': '保存空间或复写进度不足', 'crystal-capacity': '没有空位保存冰晶', 'page-room-clear': '清房后已保存的法术消散',
  'guard-balance-expired': '防御后剩余力量消散', 'page-expired': '保存时间结束', 'packet-miss': '法术失去目标',
  'pending-overwritten': '待发法术被新的主术替换', 'pending-room-change': '进入下一房，待发法术结束', 'pending-expired': '待发法术等待超时',
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
  return <details className="build-trace"><summary>法术记录 · 最近 {trace.entries.length} 条</summary>
    <p>查看法术用于攻击、防御和回收的实际情况，以及当时生效的天赋与遗物。{trace.omitted > 0 && `更早的 ${trace.omitted} 条已从明细中略去。`}</p>
    <ol className="build-trace-entries">{[...trace.entries].reverse().map(entry => <li key={entry.sequence}>
      <strong>{labels[entry.kind]}</strong><span>第 {entry.room} 节{entry.rootId !== null ? ` · 第 ${entry.rootId} 次施法` : ''}</span>
      <span>{entry.power !== 0 ? `威力 ${Math.round(entry.power * 100) / 100}` : ''}{entry.heat !== 0 ? ` · 储备 ${Math.round(entry.heat * 100) / 100}` : ''}</span>
      <small>{reasons[entry.reason] ?? labels[entry.kind]} · 相关效果：{entry.sourceIds.map(id => sourceName(id, report)).join(' · ') || '之前保存的力量'}</small>
    </li>)}</ol>
  </details>;
}
