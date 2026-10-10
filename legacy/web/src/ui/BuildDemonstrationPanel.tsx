import { useEffect, useRef, useState } from 'react';
import type { BuildExample, DemonstrationHandle, DemonstrationMetrics, DemonstrationSnapshot } from '../contracts/build-examples.ts';
import './build-demonstration.css';

const round = (value: number) => Math.round(value).toLocaleString();
const families: Record<string, string> = { copy: '复写', binding: '装订', crystal: '晶壳', thermal: '炉心', conduction: '电路', geometry: '几何', reserve: '储备', fragments: '分合', transport: '运输', letters: '词形', defense: '护持', focus: '独卷' };
const scopes = { room: '本房', chapter: '本章', run: '本局' };
const recordStates: Record<string, string> = { active: '生效中', pending: '待清房', expired: '已到期', kept: '已保留', applied: '已执行' };
function Measures({ title, data }: { title: string; data?: DemonstrationMetrics }) {
  return <div className="build-demo-measures">
    <h4>{title}</h4>
    {data ? <dl>
      <div><dt>施法 / 伤害</dt><dd>{data.casts} / {round(data.damage)}</dd></div>
      <div><dt>人工字符</dt><dd>{data.manualCharacters}</dd></div>
      <div><dt>复写创建 / 释放</dt><dd>{data.pagesCreated} / {data.pagesReleased}</dd></div>
      <div><dt>护页拦截 / 回收热量</dt><dd>{data.pagesBlocked} / {round(data.recoveredHeat)}</dd></div>
      <div><dt>击破 / 生命 / 护盾</dt><dd>{data.kills} / {round(data.health)} / {round(data.shield)}</dd></div>
      <div><dt>当前房 / 剩余法术 / 载页</dt><dd>{data.roomVisit} / {data.remainingShots} / {data.remainingPages}</dd></div>
    </dl> : <p>当前事件条件不足，无法生成对照。</p>}
  </div>;
}

export function BuildDemonstrationPanel() {
  const [examples, setExamples] = useState<readonly BuildExample[]>([]);
  const [selected, setSelected] = useState('');
  const [snapshot, setSnapshot] = useState<DemonstrationSnapshot | null>(null);
  const [error, setError] = useState('');
  const handle = useRef<DemonstrationHandle | null>(null);
  const timer = useRef<ReturnType<typeof setInterval> | null>(null);
  const mounted = useRef(true);
  const request = useRef(0);
  const stop = () => {
    request.current++;
    if (timer.current) clearInterval(timer.current);
    timer.current = null;
    if (handle.current) { handle.current.stop(); setSnapshot(handle.current.snapshot()); handle.current = null; }
  };
  useEffect(() => {
    let active = true;
    mounted.current = true;
    import('../bootstrap/build-demonstration.ts').then(module => {
      if (!active) return;
      setExamples(module.buildExamples);
      setSelected(current => current || module.buildExamples[0]?.id || '');
    }).catch(cause => { if (active) setError(String(cause)); });
    return () => {
      active = false;
      mounted.current = false;
      request.current++;
      if (timer.current) clearInterval(timer.current);
      handle.current?.destroy();
      timer.current = null; handle.current = null;
    };
  }, []);
  const start = async () => {
    stop(); setError(''); setSnapshot(null);
    const serial = ++request.current;
    try {
      const module = await import('../bootstrap/build-demonstration.ts');
      if (!mounted.current || serial !== request.current) return;
      const current = module.createBuildDemonstration(selected);
      handle.current = current;
      setSnapshot(current.snapshot());
      timer.current = setInterval(() => {
        try {
          const next = handle.current?.step(.05);
          if (next) setSnapshot(next);
          if (next && !next.running) {
            if (timer.current) clearInterval(timer.current);
            timer.current = null; handle.current = null;
          }
        } catch (cause) {
          if (timer.current) clearInterval(timer.current);
          timer.current = null;
          try { handle.current?.destroy(); }
          catch { /* Preserve the original step error. */ }
          handle.current = null;
          setError(cause instanceof Error ? cause.message : String(cause));
        }
      }, 50);
    } catch (cause) { setError(cause instanceof Error ? cause.message : String(cause)); }
  };
  const example = examples.find(item => item.id === selected);
  return <section className="build-demonstration" aria-label="构筑学习演示">
    <header><h3>构筑札记 · 实战演示</h3><p>选一条学习路线，以固定词页和输入节奏观察规则怎样工作。</p></header>
    <div className="build-demo-picker" role="list" aria-label="构筑样本">
      {examples.map(item => <button type="button" role="listitem" key={item.id} className={item.id === selected ? 'selected' : ''} onClick={() => { stop(); setSnapshot(null); setSelected(item.id); }} aria-current={item.id === selected ? 'true' : undefined}>{item.title}<small>{families[item.family] ?? item.family}</small></button>)}
    </div>
    {example && <div className="build-demo-description">
      <p><strong>用途</strong>{example.purpose}</p><p><strong>代价</strong>{example.tradeoff}</p><p><strong>事件转向</strong>{example.eventChange}</p>
    </div>}
    <div className="build-demo-actions">
      <button type="button" onClick={start}>{snapshot ? '重置演示' : '开始演示'}</button>
      <button type="button" onClick={stop} disabled={!snapshot?.running}>停止</button>
      {snapshot && <span>{snapshot.elapsed.toFixed(1)} 秒 · {snapshot.running ? '演示中' : '已停止'}</span>}
    </div>
    {error && <p className="build-demo-error" role="alert">{error}</p>}
    {snapshot && <>
      <p className="build-demo-event">事件：{snapshot.eventStatus}{snapshot.eventApplied ? ` · 已采纳 · ${snapshot.eventScope ? scopes[snapshot.eventScope] : ''} · ${recordStates[snapshot.eventRecordStatus ?? ''] ?? '已执行'}` : ' · 本次无法比较'}</p>
      <p className="build-demo-build">天赋：{snapshot.talentNames.join(' · ')}</p>
      <p className="build-demo-build">持有：{snapshot.heldRelicNames.join(' · ')}{snapshot.revisedRelicNames ? `　→　事件后：${snapshot.revisedRelicNames.join(' · ')}` : ''}</p>
      <div className="build-demo-comparison"><Measures title="原构筑" data={snapshot.baseline} /><Measures title="事件修订后" data={snapshot.revised} /></div>
    </>}
  </section>;
}
