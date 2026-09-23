import { useEffect, useMemo, useRef, useState } from "react";
import type { BookId } from "../contracts/game.ts";
import type { GraphNodeState, GraphProjection } from "../contracts/graph.ts";
import type { TalentLoadout, TalentNode } from "../contracts/talents.ts";
import { TALENT_GRAPH } from "../content/graphs.ts";
import { TALENT_LAYOUT } from "../generated/graph-layouts.ts";
import { TALENT_BOOKS, TALENT_BY_ID, TALENT_NODES } from "../content/talents.ts";
import { removeTalent, resolveTalents, secondaryBookCandidates, talentNeighbors, talentRoute } from "../shared/talents.ts";
import { Button, Select } from "./components";
import { GraphViewport } from "./GraphViewport";
import { C } from "./storage";
import "./talents.css";

const capabilityNames: Record<string, string> = { cold: "积累寒气", heat: "积累热量", conduction: "积累电荷", carrier: "保存法术", guard: "用法术防御", release: "释放剩余法术", recovery: "回收法力" };
const MAX_KEYSTONES = 2;

function talentIcon(node: import('../contracts/graph.ts').GraphNode, size: number) {
  const r = size * .64;
  if (node.kind === 'root') return <g className="talent-book-sigil">
    <path d={`M${-r},${-r} Q${-r / 2},${-r * 1.3} 0,${-r * .65} Q${r / 2},${-r * 1.3} ${r},${-r} V${r} Q${r / 2},${r * .7} 0,${r * 1.1} Q${-r / 2},${r * .7} ${-r},${r} Z M0,${-r * .65} V${r * 1.1}`} />
    {node.region === 'frost' ? <path d={`M${-r * .7},0 H${r * .7} M0,${-r * .5} V${r * .6} M${-r * .4},${-r * .4} L${r * .4},${r * .4} M${r * .4},${-r * .4} L${-r * .4},${r * .4}`} /> :
      node.region === 'storm' ? <path d={`M${r * .3},${-r * .5} L${-r * .35},${r * .1} H${r * .25} L${-r * .25},${r * .65}`} /> :
      node.region === 'flame' ? <path d={`M0,${-r * .6} Q${-r},${r * .5} 0,${r * .65} Q${r * .7},${r * .4} 0,${-r * .6} Z`} /> :
      <path d={`M${-r * .55},0 Q0,${-r * .7} ${r * .55},0 Q0,${r * .7} ${-r * .55},0 Z`} />}
  </g>;
  const tags = node.tags.join(' '), s = size * .6;
  if (/carrierGuard|guardEfficiency|carrierRetain/.test(tags)) return <path d={`M0,${-s} L${s},${-s * .6} V0 Q${s * .7},${s * .7} 0,${s} Q${-s * .7},${s * .7} ${-s},0 V${-s * .6} Z M0,${-s * .5} V${s * .45}`} />;
  if (/chain|conduction|Relay/.test(tags)) return <path d={`M${s * .4},${-s} L${-s * .6},${s * .15} H${s * .25} L${-s * .3},${s} M${-s},${-s * .6} L${-s * .65},${-s * .3} M${s * .65},${s * .3} L${s},${s * .6}`} />;
  if (/heat|burn|thermal/.test(tags)) return <path d={`M0,${-s} C${s * .15},${-s * .1} ${s},${-s * .1} ${s * .65},${s * .55} Q0,${s * 1.2} ${-s * .6},${s * .55} C${-s},0 ${-s * .3},0 0,${-s} Z M0,0 Q${-s * .4},${s * .55} 0,${s * .6}`} />;
  if (/cold|crystal/.test(tags)) return <path d={`M0,${-s} L${s * .65},0 L0,${s} L${-s * .65},0 Z M0,${-s} V${s} M${-s * .65},0 H${s * .65}`} />;
  if (/fragment|forkPayload|markSpread/.test(tags)) return <path d={`M0,${-s} L${s * .28},${-s * .5} L0,0 L${-s * .28},${-s * .5} Z M${-s * .65},0 L${-s * .35},${s * .5} L${-s * .65},${s} L${-s},${s * .5} Z M${s * .65},0 L${s},${s * .5} L${s * .65},${s} L${s * .35},${s * .5} Z`} />;
  if (/recovery|Recovery|materialConserve|reserve/.test(tags)) return <path d={`M${s * .8},0 A${s * .8},${s * .8} 0 1 0 0,${s * .8} M${s * .35},${-s * .3} L${s * .8},0 L${s},${-s * .5} M0,${-s * .35} V${s * .35} M${-s * .35},0 H${s * .35}`} />;
  if (/copy|carrier|paper|summon|markCarrier/.test(tags)) return <path d={`M${-s * .5},${-s} H${s * .8} V${s * .55} H${-s * .5} Z M${-s * .8},${-s * .55} V${s * .9} H${s * .4} M${-s * .2},${-s * .45} H${s * .45} M${-s * .2},0 H${s * .25}`} />;
  return <g><path d={`M0,${-s} V${s} M${-s},0 H${s}`} /><circle r={s * .5} /></g>;
}

export function TalentPanel({ book, onBook, loadout, budget, characters, godMode, onChange, onClearGod }: {
  book: BookId;
  onBook: (book: BookId) => void;
  loadout: TalentLoadout;
  budget: number;
  characters: number;
  godMode: boolean;
  onChange: (loadout: TalentLoadout) => void;
  onClearGod: () => void;
}) {
  const [selected, setSelected] = useState(`${book}-root`);
  const detailRef = useRef<HTMLElement>(null);
  const [detailWidth, setDetailWidth] = useState(340);
  useEffect(() => {
    const detail = detailRef.current;
    if (!detail) return;
    const observer = new ResizeObserver(() => setDetailWidth(detail.getBoundingClientRect().width + 48));
    observer.observe(detail);
    return () => observer.disconnect();
  }, []);
  const resolved = useMemo(() => resolveTalents(book, loadout.allocated, budget, godMode), [book, loadout.allocated, budget, godMode]);
  const active = useMemo(() => new Set(resolved.allocated), [resolved.allocated]);
  const node = TALENT_BY_ID[selected] ?? TALENT_BY_ID[`${book}-root`];
  useEffect(() => {
    const scroll = detailRef.current?.querySelector('.talent-detail-scroll');
    if (scroll) scroll.scrollTop = 0;
  }, [node.id]);
  const isRoot = node.root === book;
  const preview = useMemo(() => resolveTalents(book, [...resolved.allocated, node.id], budget, godMode), [book, resolved.allocated, node.id, budget, godMode]);
  const available = !active.has(node.id) && preview.allocated.includes(node.id) && resolved.allocated.every(id => preview.allocated.includes(id));
  const removal = useMemo(() => removeTalent(book, resolved.allocated, node.id, budget, godMode), [book, resolved.allocated, node.id, budget, godMode]);
  const removed = resolved.allocated.length - removal.length;
  const candidates = useMemo(() => secondaryBookCandidates(book, resolved.allocated, budget, godMode), [book, resolved, budget, godMode]);
  const exclusives = useMemo(() => new Set(TALENT_NODES.filter(item => active.has(item.id) && item.exclusive).map(item => item.exclusive)), [active]);
  const keystones = useMemo(() => TALENT_NODES.filter(item => active.has(item.id) && item.kind === "keystone").length, [active]);
  const path = useMemo(() => talentRoute(book, node.id, resolved.allocated), [book, node.id, resolved.allocated]);
  const pathToBuy = path.filter(id => !active.has(id));
  const pathCost = pathToBuy.reduce((sum, id) => sum + (TALENT_BY_ID[id]?.cost ?? 0), 0);
  const reasonFor = (item: TalentNode, canBuy: boolean): string => {
    if (active.has(item.id)) return "已点亮";
    if (item.exclusive && exclusives.has(item.exclusive)) return `与已选的${TALENT_NODES.filter(candidate => active.has(candidate.id) && candidate.exclusive === item.exclusive).map(candidate => candidate.name).join("、")}互斥`;
    if (item.kind === "keystone" && keystones >= MAX_KEYSTONES) return `关键节点最多点亮 ${MAX_KEYSTONES} 个`;
    const prerequisites = item.requiresNodes?.filter(id => !active.has(id)) ?? [];
    if (prerequisites.length) return `需要先点亮${prerequisites.map(id => TALENT_BY_ID[id]?.name ?? id).join("、")}`;
    const lacking = item.requires?.filter(capability => !resolved.capabilities.includes(capability)) ?? [];
    if (lacking.length) return `需要先学会${lacking.map(value => capabilityNames[value] ?? value).join("、")}`;
    if (!talentNeighbors(item.id).some(id => active.has(id))) return "尚无已点亮的相邻节点";
    if (!godMode && resolved.spent + item.cost > budget) return `还需 ${resolved.spent + item.cost - budget} 点天赋点`;
    return canBuy ? "可以点亮" : "当前配置不满足前置条件";
  };
  const reason = isRoot ? "主书起点已自动点亮。" : active.has(node.id)
    ? `撤回将返还点数${removed > 1 ? `，并撤回 ${removed - 1} 个失去连接或能力来源的节点` : ""}。`
    : `${reasonFor(node, available)}。`;
  const projection = useMemo<GraphProjection>(() => {
    const states: Record<string, GraphNodeState> = {}, reasons: Record<string, string> = {};
    for (const item of TALENT_NODES) {
      if (active.has(item.id)) { states[item.id] = "active"; continue; }
      const trial = resolveTalents(book, [...resolved.allocated, item.id], budget, godMode);
      const canBuy = trial.allocated.includes(item.id) && resolved.allocated.every(id => trial.allocated.includes(id));
      states[item.id] = item.exclusive && exclusives.has(item.exclusive) ? "excluded" : canBuy ? "available" : "locked";
      reasons[item.id] = reasonFor(item, canBuy);
    }
    return { states, reasons };
  }, [active, book, resolved, budget, godMode, exclusives, keystones]);

  return <div className="talent-panel">
    <div className="talent-toolbar">
      <div><strong>{godMode ? "GOD MODE · 自由分配" : `天赋点 ${budget - resolved.spent} / ${budget}`}</strong>
        <span>{godMode ? "独立配置" : `累计有效字符 ${characters.toLocaleString()}${budget < 24 ? ` · 再写 ${120 - characters % 120} 字获得下一点` : " · 已达点数上限"}`}</span></div>
      {candidates.length > 0 && <div className="talent-binding"><Select id="talentSecondary" word="secondary" label="副书" value={loadout.secondaryBook ?? ""} onChange={value => onChange({ ...loadout, secondaryBook: value ? value as BookId : undefined })} options={[{ value: "", label: "暂不选择" }, ...candidates.map(id => ({ value: id, label: C.BOOKS[id].name }))]} /></div>}
      <div className="talent-books" aria-label="主书起点">{TALENT_BOOKS.map(id => <Button key={id} word={`root${id}`} aria-pressed={book === id} className={book === id ? "selected" : ""} onClick={() => { onBook(id); setSelected(`${id}-root`); }}>{C.BOOKS[id].short}</Button>)}</div>
    </div>
    <div className="talent-workspace">
      <div className="talent-map-region"><GraphViewport definition={TALENT_GRAPH} layout={TALENT_LAYOUT} projection={{ ...projection, highlighted: path }} selectedId={node.id} onSelect={setSelected} rootId={`${book}-root`} obscuredRight={detailWidth} renderIcon={talentIcon} label="天赋图谱" /></div>
      <aside className="talent-detail" ref={detailRef} aria-label="天赋详情" style={{ '--talent-color': node.school === 'shared' ? '#d9c596' : C.BOOKS[node.school].color } as React.CSSProperties}>
        <div className="talent-detail-scroll">
          <span className="talent-school">{node.school === "shared" ? "跨书天赋" : C.BOOKS[node.school].name} · {isRoot ? "免费起点" : `${node.cost} 点`}</span>
          <h3>{node.name}</h3><p>{node.description}</p><p className="talent-status" role="status">{reason}</p>
          {!active.has(node.id) && pathToBuy.length > 1 && <div className="talent-path-preview"><h4>可行路线 · {pathCost} 点</h4><ol>{pathToBuy.map(id => <li key={id}><button type="button" onClick={() => setSelected(id)}>{TALENT_BY_ID[id]?.name ?? id}</button></li>)}</ol></div>}
          <div className="talent-connections"><h4>相邻天赋</h4>{talentNeighbors(node.id).map(id => <button key={id} type="button" onClick={() => setSelected(id)}>{TALENT_BY_ID[id]?.name ?? id}<span>{active.has(id) ? "已点亮" : `${TALENT_BY_ID[id]?.cost} 点`}</span></button>)}</div>
        </div>
        <Button word="allocate" variant="primary" disabled={isRoot || (!active.has(node.id) && !available)} onClick={() => onChange({ ...loadout, allocated: active.has(node.id) ? removal : preview.allocated })}>{active.has(node.id) ? "撤回天赋" : "点亮天赋"}</Button>
      </aside>
    </div>
    <div className="modal-footer talent-footer"><span>天赋自动保存 · 起点须连通 · 可随时撤回重配</span>{godMode && <Button word="cleargod" variant="danger" onClick={onClearGod}>清理 God Mode 数据</Button>}</div>
  </div>;
}
