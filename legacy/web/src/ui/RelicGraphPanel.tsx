import { useMemo, useState } from "react";
import type { BookId } from "../contracts/game.ts";
import type { CombatCapability } from "../contracts/combat-weave.ts";
import type { Relic } from "../contracts/content.ts";
import type { GraphNode, GraphNodeState, GraphProjection } from "../contracts/graph.ts";
import type { SessionView } from "../contracts/session.ts";
import { RELICS, BOOKS } from "../content/catalog.ts";
import { RELIC_GRAPH, TALENT_GRAPH } from "../content/graphs.ts";
import { TALENT_NODES } from "../content/talents.ts";
import { RELIC_LAYOUT, TALENT_LAYOUT } from "../generated/graph-layouts.ts";
import { collectCapabilities } from "../shared/combat-capabilities.ts";
import { eligibleRelic } from "../shared/relic-eligibility.ts";
import { GraphViewport } from "./GraphViewport";
import { RelicIcon } from "./RelicIcon";
import { capabilityNames, describeRelic, RELIC_RARITIES, relicRarity } from "./relic-presentation.ts";
import "./relic-graph.css";

export interface RelatedGraphEvent { id: string; name: string; description: string; nodeIds: readonly string[] }
interface RelicGraphPanelProps {
  book: BookId;
  held?: Readonly<Record<string, number>>;
  game?: SessionView;
  formulas: boolean;
  relatedEvents?: readonly RelatedGraphEvent[];
  eligibility?: Readonly<Record<string, boolean>>;
  wordLengths?: Readonly<{ shortest: number; longest: number }>;
  talents?: readonly string[];
}
const relicById = new Map(RELICS.map(relic => [relic.id, relic]));
const talentById = new Map(TALENT_NODES.map(talent => [talent.id, talent]));
const talentGraphIds = new Set(TALENT_GRAPH.nodes.map(node => node.id));
const capabilityNodePrefix = "capability:";

function relatedTalentIds(relic: Relic): string[] {
  const stats = new Set(Object.keys(relic.grants ?? {}));
  const provides = new Set(relic.provides ?? []);
  const consumes = new Set([...(relic.needs ?? []), ...(relic.modifies ?? [])]);
  return TALENT_NODES.filter(talent => {
    if (!talentGraphIds.has(talent.id)) return false;
    const overlapGrant = Object.keys(talent.grants ?? {}).some(stat => stats.has(stat));
    const suppliesNeed = talent.capabilities?.some(capability => consumes.has(capability));
    const usesSupply = talent.requires?.some(capability => provides.has(capability));
    return overlapGrant || suppliesNeed || usesSupply;
  }).map(talent => talent.id);
}
function linkedReason(relic: Relic, talentId: string): string {
  const talent = talentById.get(talentId);
  if (!talent) return "";
  const relicStats = new Set(Object.keys(relic.grants ?? {}));
  const stats = Object.keys(talent.grants ?? {}).filter(stat => relicStats.has(stat));
  const need = talent.capabilities?.filter(capability => relic.needs?.includes(capability) || relic.modifies?.includes(capability)) ?? [];
  const supply = talent.requires?.filter(capability => relic.provides?.includes(capability)) ?? [];
  return [stats.length ? `共同强化 ${stats.join("、")}` : "", need.length ? `天赋提供 ${need.map(value => capabilityNames[value]).join("、")}` : "", supply.length ? `遗物提供 ${supply.map(value => capabilityNames[value]).join("、")}` : ""].filter(Boolean).join(" · ");
}
function requirements(relic: Relic): { id: string; level: number }[] {
  const required = new Map<string, number>();
  for (const id of relic.requires ?? []) required.set(id, Math.max(required.get(id) ?? 0, 1));
  for (const [id, level] of Object.entries(relic.requiresLevels ?? {})) required.set(id, Math.max(required.get(id) ?? 0, level));
  if (relic.evolution) required.set(relic.evolution.from, Math.max(required.get(relic.evolution.from) ?? 0, 1));
  return [...required].map(([id, level]) => ({ id, level }));
}
function requirementPath(relic: Relic): { id: string; level: number }[] {
  const ordered: { id: string; level: number }[] = [];
  const seen = new Map<string, number>();
  const visit = (item: Relic) => {
    for (const entry of requirements(item)) {
      const prior = seen.get(entry.id) ?? 0;
      if (prior >= entry.level) continue;
      seen.set(entry.id, entry.level);
      const ancestor = relicById.get(entry.id);
      if (ancestor) visit(ancestor);
      const index = ordered.findIndex(value => value.id === entry.id);
      if (index >= 0) ordered[index] = { id: entry.id, level: entry.level };
      else ordered.push(entry);
    }
  };
  visit(relic);
  return ordered;
}

export function RelicGraphPanel({ book, held, game, formulas, relatedEvents, eligibility, wordLengths, talents }: RelicGraphPanelProps) {
  const [selectedId, setSelectedId] = useState(() => {
    const initialLevels = held ?? game?.relics ?? {};
    return Object.keys(initialLevels).find(id => (initialLevels[id] ?? 0) > 0) ?? RELICS[0].id;
  });
  const [planned, setPlanned] = useState<ReadonlySet<string>>(() => new Set());
  const [talentDetailId, setTalentDetailId] = useState<string | null>(null);
  const [listMode, setListMode] = useState(false);
  const selectedRelic = relicById.get(selectedId);
  const selectedGraphNode = RELIC_GRAPH.nodes.find(node => node.id === selectedId);
  const levels = held ?? game?.relics ?? {};
  const capabilities = useMemo(() => game?.capabilities ?? collectCapabilities(BOOKS[book], RELICS, levels), [game?.capabilities, book, held]);
  const exactEligibility = useMemo(() => {
    if (eligibility) return eligibility;
    if (!game || !wordLengths) return undefined;
    return Object.fromEntries(RELICS.map(relic => [relic.id, eligibleRelic(relic, { book, levels, shortest: wordLengths.shortest, longest: wordLengths.longest, capabilities, definitions: RELICS, stats: game.buildStats })]));
  }, [eligibility, game, game?.buildStats, wordLengths, book, levels, capabilities]);
  const projection = useMemo<GraphProjection>(() => {
    const states: Record<string, GraphNodeState> = {}, reasons: Record<string, string> = {};
    for (const node of RELIC_GRAPH.nodes) {
      if (node.id.startsWith(capabilityNodePrefix)) {
        states[node.id] = capabilities.includes(node.definitionId as CombatCapability) && !!game ? "active" : "locked";
        continue;
      }
      const level = levels[node.id] ?? 0;
      states[node.id] = level > 0 ? "active" : exactEligibility?.[node.id] && game ? "available" : planned.has(node.id) ? "planned" : "locked";
      reasons[node.id] = level > 0 ? `本局持有 ${level} 级` : !game ? "图鉴规划；无进行中的远征" : exactEligibility ? exactEligibility[node.id] ? "符合本局领取资格；是否进入奖励候选仍由奖励流程决定" : "当前不符合领取资格" : "本局领取资格须结合词库与奖励候选判断";
    }
    return { states, reasons, highlighted: [...planned] };
  }, [capabilities, game, levels, exactEligibility, planned]);
  const choose = (id: string) => { setSelectedId(id); setTalentDetailId(null); };
  const required = selectedRelic ? requirements(selectedRelic) : [];
  const route = selectedRelic ? requirementPath(selectedRelic) : [];
  const relatedTalents = selectedRelic ? relatedTalentIds(selectedRelic) : [];
  const events = relatedEvents?.filter(event => event.nodeIds.includes(`relic:${selectedId}`) || !!talentDetailId && event.nodeIds.includes(`talent:${talentDetailId}`)) ?? [];
  const currentTalent = talentDetailId ? talentById.get(talentDetailId) : undefined;
  const talentProjection = useMemo<GraphProjection>(() => ({ states: Object.fromEntries(TALENT_NODES.map(node => [node.id, (talents?.includes(node.id) ? "active" : "locked") as GraphNodeState])), highlighted: relatedTalents }), [talents, relatedTalents]);
  const conflict = selectedRelic ? RELICS.filter(other => (levels[other.id] ?? 0) > 0 && (selectedRelic.excludes?.includes(other.id) || other.excludes?.includes(selectedRelic.id))) : [];
  const relationEntries = selectedRelic ? RELIC_GRAPH.relations.filter(relation => relation.source === selectedRelic.id || relation.target === selectedRelic.id) : [];

  return <div className="relic-graph-panel">
    <div className="relic-graph-heading"><div><strong>{held ? `行囊 · ${Object.values(levels).filter(level => level > 0).length} 种遗物` : "遗物谱系"}</strong><span>{held ? Object.values(levels).some(level => level > 0) ? "本局持有、能力与发展路线" : "本局尚无遗物，可查看发展路线" : "查看材料、演化与可规划路线"}</span></div><button type="button" onClick={() => setListMode(value => !value)} aria-pressed={listMode}>{listMode ? "返回图谱" : "名称索引"}</button></div>
    <div className="relic-graph-workspace">
      {listMode && <div className="relic-graph-list" aria-label="遗物名称索引">{RELICS.map(relic => <button key={relic.id} type="button" onClick={() => { choose(relic.id); setListMode(false); }}><RelicIcon id={relic.id} /><span>{relic.name}</span><small>{levels[relic.id] ? `${levels[relic.id]} 级` : relic.family ?? relic.tag}</small></button>)}</div>}
      <div className="relic-graph-map" style={{ display: listMode || currentTalent ? "none" : undefined }}><GraphViewport definition={RELIC_GRAPH} layout={RELIC_LAYOUT} projection={projection} selectedId={selectedId} onSelect={choose} label="遗物图谱" renderIcon={(node: GraphNode, size) => node.kind === "relic" ? <foreignObject x={-size * .62} y={-size * .62} width={size * 1.24} height={size * 1.24}><span className="relic-graph-node-icon"><RelicIcon id={node.id} /></span></foreignObject> : undefined} /></div>
      {currentTalent && !listMode && <div className="relic-graph-map"><GraphViewport definition={TALENT_GRAPH} layout={TALENT_LAYOUT} projection={talentProjection} selectedId={currentTalent.id} onSelect={setTalentDetailId} rootId={currentTalent.id} label="关联天赋图谱" /></div>}
      <aside className="relic-graph-detail" aria-label="遗物关系详情"><div className="relic-graph-detail-scroll">
        {currentTalent ? <><button className="relic-graph-back" type="button" onClick={() => setTalentDetailId(null)}>← 返回{selectedRelic?.name ?? "遗物"}</button><span className="relic-graph-eyebrow">关联天赋 · {currentTalent.school === "shared" ? "共用" : BOOKS[currentTalent.school].name}</span><h3>{currentTalent.name}</h3><p>{currentTalent.description}</p><p>{selectedRelic && linkedReason(selectedRelic, currentTalent.id)}</p>{events.length > 0 && <section><h4>事件关联</h4>{events.map(event => <p key={event.id}><strong>{event.name}</strong> · {event.description}</p>)}</section>}</> : selectedRelic ? <>
          <div className="relic-graph-identity"><RelicIcon id={selectedRelic.id} /><span className="relic-graph-eyebrow">{RELIC_RARITIES[relicRarity(selectedRelic)].label} · {selectedRelic.tag}{levels[selectedRelic.id] ? ` · 本局 ${levels[selectedRelic.id]} / ${selectedRelic.max} 级` : ""}</span></div>
          <h3>{selectedRelic.name}</h3><p>{describeRelic(selectedRelic, RELICS, game, formulas)}</p>
          <p className="relic-graph-state">{projection.reasons?.[selectedRelic.id]}</p>
          {required.length > 0 && <section><h4>取得前置</h4>{required.map(({ id, level }) => <button className="relic-graph-link" key={id} type="button" onClick={() => choose(id)}>{relicById.get(id)?.name ?? id} · 需 {level} 级{held && `，现有 ${levels[id] ?? 0} 级`}</button>)}</section>}
          {route.length > required.length && <section><h4>完整前置路线</h4>{route.map(({ id, level }, index) => <button className="relic-graph-link" key={id} type="button" onClick={() => choose(id)}>{index + 1}. {relicById.get(id)?.name ?? id} · {level} 级</button>)}</section>}
          {selectedRelic.evolution && <section><h4>演化</h4><p>由 <button className="relic-graph-inline" type="button" onClick={() => choose(selectedRelic.evolution!.from)}>{relicById.get(selectedRelic.evolution.from)?.name ?? selectedRelic.evolution.from}</button> 演化 · {selectedRelic.evolution.group}</p></section>}
          {(selectedRelic.excludes?.length || conflict.length > 0) && <section><h4>互斥</h4>{[...new Set([...(selectedRelic.excludes ?? []), ...conflict.map(item => item.id)])].map(id => <button className="relic-graph-link" key={id} type="button" onClick={() => choose(id)}>{relicById.get(id)?.name ?? id}{levels[id] ? " · 本局已持有" : ""}</button>)}</section>}
          {(selectedRelic.provides?.length || selectedRelic.needs?.length || selectedRelic.modifies?.length) && <section><h4>能力关系</h4>{selectedRelic.provides?.map(cap => <p key={`provide-${cap}`}>提供 {capabilityNames[cap]}</p>)}{selectedRelic.needs?.map(cap => <p key={`need-${cap}`}>需要 {capabilityNames[cap]}{game && !capabilities.includes(cap) ? " · 当前缺少" : ""}</p>)}{selectedRelic.modifies?.map(cap => <p key={`modify-${cap}`}>加工 {capabilityNames[cap]}</p>)}</section>}
          {relatedTalents.length > 0 && <section><h4>关联天赋</h4>{relatedTalents.map(id => <button className="relic-graph-link" key={id} type="button" onClick={() => setTalentDetailId(id)}>{talentById.get(id)?.name ?? id}{talents?.includes(id) && " · 已点亮"}<small>{linkedReason(selectedRelic, id)}</small></button>)}</section>}
          {events.length > 0 && <section><h4>事件关联</h4>{events.map(event => <p key={event.id}><strong>{event.name}</strong> · {event.description}</p>)}</section>}
          {relationEntries.length > 0 && <section><h4>图上关系</h4><p>{relationEntries.length} 条关系连接此节点，可用图谱中的「所选关系」聚焦查看。</p></section>}
        </> : selectedGraphNode ? <><span className="relic-graph-eyebrow">能力通道</span><h3>{selectedGraphNode.name}</h3><p>{selectedGraphNode.description}</p><p>{capabilities.includes(selectedGraphNode.definitionId as CombatCapability) && game ? "本局已具备此能力。" : "查看相连遗物以规划能力来源。"}</p></> : null}
      </div>
      {!currentTalent && selectedRelic && <button className="relic-graph-plan" type="button" aria-pressed={planned.has(selectedRelic.id)} onClick={() => setPlanned(previous => { const next = new Set(previous); if (next.has(selectedRelic.id)) next.delete(selectedRelic.id); else next.add(selectedRelic.id); return next; })}>{planned.has(selectedRelic.id) ? "取消规划" : "规划此遗物"}</button>}
      </aside>
    </div>
  </div>;
}
