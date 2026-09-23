import { useState, type CSSProperties } from "react";
import type { BookId } from "../contracts/game.ts";
import type { TalentLoadout } from "../contracts/talents.ts";
import { TALENT_BOOKS, TALENT_BY_ID, TALENT_NODES } from "../content/talents.ts";
import { removeTalent, resolveTalents, secondaryBookCandidates, talentNeighbors } from "../shared/talents.ts";
import { Button, Select } from "./components";
import { C } from "./storage";
import "./talents.css";

const edges = TALENT_NODES.flatMap(node => node.links.map(id => [node, TALENT_BY_ID[id]] as const));

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
  const [zoom, setZoom] = useState(.85);
  const resolved = resolveTalents(book, loadout.allocated, budget, godMode);
  const active = new Set(resolved.allocated);
  const node = TALENT_BY_ID[selected] ?? TALENT_BY_ID[`${book}-root`];
  const isRoot = node.root === book;
  const preview = resolveTalents(book, [...resolved.allocated, node.id], budget, godMode);
  const available = !active.has(node.id) && preview.allocated.includes(node.id) && resolved.allocated.every(id => preview.allocated.includes(id));
  const removal = removeTalent(book, resolved.allocated, node.id, budget, godMode);
  const removed = resolved.allocated.length - removal.length;
  const candidates = secondaryBookCandidates(book, resolved.allocated, budget, godMode);
  const missing = node.requires?.filter(capability => !resolved.capabilities.includes(capability));
  const capabilityNames = { cold: "寒气", heat: "热性", conduction: "传导", carrier: "承载", guard: "防御", release: "释放", recovery: "回收" };
  const reason = isRoot ? "主书起点已自动点亮。" : active.has(node.id) ? `撤回将返还点数${removed > 1 ? `，并撤回 ${removed - 1} 个失去连接或能力来源的节点` : ""}。`
    : missing?.length ? `需要${missing.map(value => capabilityNames[value]).join("、")}能力。`
    : !talentNeighbors(node.id).some(id => active.has(id)) ? "先点亮与它相连的节点。"
    : node.exclusive && (resolved.grants.secondaryBinding || resolved.grants.singleFocus) ? "合订与独卷只能选择其一。"
    : !available ? "可用点数不足。" : "可以沿此节点继续展开。";
  return <div className="talent-panel">
    <div className="talent-toolbar">
      <div><strong>{godMode ? "GOD MODE · 自由分配" : `天赋点 ${budget - resolved.spent} / ${budget}`}</strong>
        <span>{godMode ? "独立配置" : `累计有效字符 ${characters.toLocaleString()}${budget < 24 ? ` · 再写 ${120 - characters % 120} 字获得下一点` : " · 已达点数上限"}`}</span></div>
      <div className="talent-books" aria-label="主书起点">{TALENT_BOOKS.map(id => <Button key={id} word={`root${id}`} aria-pressed={book === id} className={book === id ? "selected" : ""} onClick={() => { onBook(id); setSelected(`${id}-root`); }}>{C.BOOKS[id].short}</Button>)}</div>
    </div>
    <div className="talent-workspace">
      <div className="talent-map-region">
        <div className="talent-map-tools"><span>滚动浏览 · 选择节点查看详情</span><Button word="zoomout" aria-label="缩小天赋图" onClick={() => setZoom(value => Math.max(.6, value - .15))}>−</Button><span>{Math.round(zoom * 100)}%</span><Button word="zoomin" aria-label="放大天赋图" onClick={() => setZoom(value => Math.min(1.8, value + .15))}>＋</Button><Button word="fit" onClick={() => setZoom(.85)}>复位</Button></div>
        <div className="talent-map-scroll" tabIndex={0} aria-label="天赋图滚动区域">
          <svg className="talent-map" viewBox="0 0 860 530" style={{ width: 860 * zoom, height: 530 * zoom }} aria-label="跨元素天赋图">
            {edges.map(([from, to]) => <line key={`${from.id}-${to.id}`} x1={from.x} y1={from.y} x2={to.x} y2={to.y} className={active.has(from.id) && active.has(to.id) ? "talent-edge active" : "talent-edge"} />)}
            {TALENT_NODES.map((item, index) => {
              const owned = active.has(item.id), current = item.id === node.id;
              return <g key={item.id} transform={`translate(${item.x} ${item.y})`} className={`talent-node${owned ? " active" : ""}${current ? " inspected" : ""}${item.root === book ? " main-root" : ""}`} style={{ "--talent-color": item.school === "shared" ? "#e5cea0" : C.BOOKS[item.school].color } as CSSProperties} role="button" tabIndex={0} data-nav-order={110 + index} aria-label={`${item.name}，${owned ? "已点亮" : `${item.cost} 点`}，${item.description}`} aria-pressed={owned} onClick={() => setSelected(item.id)} onFocus={() => setSelected(item.id)} onKeyDown={event => { if (event.key === "Enter" || event.key === " ") { event.preventDefault(); event.stopPropagation(); setSelected(item.id); } }}>
                <circle r={item.root ? 22 : 15} /><path d={item.root ? "M-9 0 L0 -9 L9 0 L0 9 Z" : "M-5 0 H5 M0 -5 V5"} />
                <text y={item.root ? 44 : 36} textAnchor="middle">{item.name}</text>
              </g>;
            })}
          </svg>
        </div>
      </div>
      <aside className="talent-detail" aria-label="天赋详情">
        <div className="talent-detail-scroll">
          <span className="talent-school">{node.school === "shared" ? "共用书脊" : C.BOOKS[node.school].name} · {isRoot ? "免费起点" : `${node.cost} 点`}</span>
          <h3>{node.name}</h3><p>{node.description}</p><p className="talent-status" role="status">{reason}</p>
          <div className="talent-binding"><h4>出征副书</h4>{candidates.length ? <Select id="talentSecondary" word="secondary" label="合订法书" value={loadout.secondaryBook ?? ""} onChange={value => onChange({ ...loadout, secondaryBook: value ? value as BookId : undefined })} options={[{ value: "", label: "暂不合订" }, ...candidates.map(id => ({ value: id, label: C.BOOKS[id].name }))]} /> : <p>点亮合订后，可选择另一种法书的副术材料。</p>}</div>
          <div className="talent-current"><h4>已点亮 · {resolved.allocated.length} 节点</h4><p>{resolved.allocated.map(id => TALENT_BY_ID[id].name).join(" · ")}</p></div>
        </div>
        <Button word="allocate" variant="primary" disabled={isRoot || (!active.has(node.id) && !available)} onClick={() => onChange({ ...loadout, allocated: active.has(node.id) ? removal : preview.allocated })}>{active.has(node.id) ? "撤回天赋" : "点亮天赋"}</Button>
      </aside>
    </div>
    <div className="modal-footer talent-footer"><span>天赋自动保存 · 起点须连通 · 可随时撤回重配</span>{godMode && <Button word="cleargod" variant="danger" onClick={onClearGod}>清理 God Mode 数据</Button>}</div>
  </div>;
}
