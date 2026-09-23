import { useMemo, useState } from "react";
import type { BookId } from "../contracts/game.ts";
import type { GraphNodeState, GraphProjection } from "../contracts/graph.ts";
import type { TalentLoadout, TalentNode } from "../contracts/talents.ts";
import { TALENT_GRAPH } from "../content/graphs.ts";
import { TALENT_LAYOUT } from "../generated/graph-layouts.ts";
import { TALENT_BOOKS, TALENT_BY_ID, TALENT_NODES } from "../content/talents.ts";
import { removeTalent, resolveTalents, secondaryBookCandidates, talentNeighbors } from "../shared/talents.ts";
import { Button, Select } from "./components";
import { GraphViewport } from "./GraphViewport";
import { C } from "./storage";
import "./talents.css";

const capabilityNames: Record<string, string> = { cold: "寒气", heat: "热性", conduction: "传导", carrier: "承载", guard: "防御", release: "释放", recovery: "回收" };
const MAX_KEYSTONES = 2;

function shortestPath(target: string, active: Set<string>): string[] {
  const pending = [...active].map(id => [id]);
  const seen = new Set(active);
  for (let i = 0; i < pending.length; i++) {
    const path = pending[i], last = path[path.length - 1];
    if (last === target) return path;
    for (const next of talentNeighbors(last)) if (!seen.has(next)) { seen.add(next); pending.push([...path, next]); }
  }
  return [];
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
  const resolved = useMemo(() => resolveTalents(book, loadout.allocated, budget, godMode), [book, loadout.allocated, budget, godMode]);
  const active = useMemo(() => new Set(resolved.allocated), [resolved.allocated]);
  const node = TALENT_BY_ID[selected] ?? TALENT_BY_ID[`${book}-root`];
  const isRoot = node.root === book;
  const preview = useMemo(() => resolveTalents(book, [...resolved.allocated, node.id], budget, godMode), [book, resolved.allocated, node.id, budget, godMode]);
  const available = !active.has(node.id) && preview.allocated.includes(node.id) && resolved.allocated.every(id => preview.allocated.includes(id));
  const removal = useMemo(() => removeTalent(book, resolved.allocated, node.id, budget, godMode), [book, resolved.allocated, node.id, budget, godMode]);
  const removed = resolved.allocated.length - removal.length;
  const candidates = secondaryBookCandidates(book, resolved.allocated, budget, godMode);
  const exclusives = new Set(TALENT_NODES.filter(item => active.has(item.id) && item.exclusive).map(item => item.exclusive));
  const keystones = TALENT_NODES.filter(item => active.has(item.id) && item.kind === "keystone").length;
  const missing = node.requires?.filter(capability => !resolved.capabilities.includes(capability)) ?? [];
  const path = useMemo(() => shortestPath(node.id, active), [node.id, active]);
  const pathToBuy = path.filter(id => !active.has(id));
  const pathCost = pathToBuy.reduce((sum, id) => sum + (TALENT_BY_ID[id]?.cost ?? 0), 0);
  const reasonFor = (item: TalentNode, canBuy: boolean): string => {
    if (active.has(item.id)) return "已点亮";
    if (item.exclusive && exclusives.has(item.exclusive)) return `与已选的${TALENT_NODES.filter(candidate => active.has(candidate.id) && candidate.exclusive === item.exclusive).map(candidate => candidate.name).join("、")}互斥`;
    if (item.kind === "keystone" && keystones >= MAX_KEYSTONES) return `关键节点最多点亮 ${MAX_KEYSTONES} 个`;
    const prerequisites = item.requiresNodes?.filter(id => !active.has(id)) ?? [];
    if (prerequisites.length) return `需要先点亮${prerequisites.map(id => TALENT_BY_ID[id]?.name ?? id).join("、")}`;
    const lacking = item.requires?.filter(capability => !resolved.capabilities.includes(capability)) ?? [];
    if (lacking.length) return `需要${lacking.map(value => capabilityNames[value] ?? value).join("、")}能力`;
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
    return { states, reasons, highlighted: pathToBuy };
  }, [active, book, resolved, budget, godMode, exclusives, keystones, pathToBuy]);

  return <div className="talent-panel">
    <div className="talent-toolbar">
      <div><strong>{godMode ? "GOD MODE · 自由分配" : `天赋点 ${budget - resolved.spent} / ${budget}`}</strong>
        <span>{godMode ? "独立配置" : `累计有效字符 ${characters.toLocaleString()}${budget < 24 ? ` · 再写 ${120 - characters % 120} 字获得下一点` : " · 已达点数上限"}`}</span></div>
      <div className="talent-books" aria-label="主书起点">{TALENT_BOOKS.map(id => <Button key={id} word={`root${id}`} aria-pressed={book === id} className={book === id ? "selected" : ""} onClick={() => { onBook(id); setSelected(`${id}-root`); }}>{C.BOOKS[id].short}</Button>)}</div>
    </div>
    <div className="talent-workspace">
      <div className="talent-map-region"><GraphViewport definition={TALENT_GRAPH} layout={TALENT_LAYOUT} projection={projection} selectedId={node.id} onSelect={setSelected} rootId={`${book}-root`} label="天赋图谱" /></div>
      <aside className="talent-detail" aria-label="天赋详情">
        <div className="talent-detail-scroll">
          <span className="talent-school">{node.school === "shared" ? "共用书脊" : C.BOOKS[node.school].name} · {isRoot ? "免费起点" : `${node.cost} 点`}</span>
          <h3>{node.name}</h3><p>{node.description}</p><p className="talent-status" role="status">{reason}</p>
          {!active.has(node.id) && pathToBuy.length > 1 && <div className="talent-path-preview"><h4>抵达路径 · {pathCost} 点</h4><p>{pathToBuy.map(id => TALENT_BY_ID[id]?.name ?? id).join(" → ")}</p><p>沿路径逐个点亮；每一步均由天赋规则校验。</p></div>}
          {missing.length > 0 && <p className="talent-requirements">需要能力：{missing.map(value => capabilityNames[value] ?? value).join("、")}</p>}
          <div className="talent-binding"><h4>出征副书</h4>{candidates.length ? <Select id="talentSecondary" word="secondary" label="合订法书" value={loadout.secondaryBook ?? ""} onChange={value => onChange({ ...loadout, secondaryBook: value ? value as BookId : undefined })} options={[{ value: "", label: "暂不合订" }, ...candidates.map(id => ({ value: id, label: C.BOOKS[id].name }))]} /> : <p>点亮合订后，可选择另一种法书的副术材料。</p>}</div>
          <div className="talent-current"><h4>已点亮 · {resolved.allocated.length} 节点</h4><p>{resolved.allocated.map(id => TALENT_BY_ID[id]?.name ?? id).join(" · ")}</p></div>
        </div>
        <Button word="allocate" variant="primary" disabled={isRoot || (!active.has(node.id) && !available)} onClick={() => onChange({ ...loadout, allocated: active.has(node.id) ? removal : preview.allocated })}>{active.has(node.id) ? "撤回天赋" : "点亮天赋"}</Button>
      </aside>
    </div>
    <div className="modal-footer talent-footer"><span>天赋自动保存 · 起点须连通 · 可随时撤回重配</span>{godMode && <Button word="cleargod" variant="danger" onClick={onClearGod}>清理 God Mode 数据</Button>}</div>
  </div>;
}
