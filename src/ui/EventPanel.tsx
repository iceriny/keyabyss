import { useEffect, useState } from "react";
import type { BuildEventChoice, BuildEventOffer, BuildEventScope } from "../contracts/build-events.ts";
import type { CombatStat } from "../contracts/stats.ts";
import type { CombatCapability } from "../contracts/combat-weave.ts";
import { RELICS } from "../content/catalog.ts";
import { TALENT_NODES } from "../content/talents.ts";
import { Button } from "./components";
import "./event-panel.css";

const scopeNames: Record<BuildEventScope, string> = { room: "本房", chapter: "本章", run: "本局" };
const statNames: Partial<Record<CombatStat, string>> = {
  carrierCapacity: "载体容量", carrierDelay: "交付等待", carrierLifetime: "载体寿命", carrierRelay: "载体中继", carrierGuard: "护页出口", carrierRelease: "终结释放", carrierRetain: "防御留存", guardNewest: "新页优先", guardEfficiency: "护持效率",
  crystalPayload: "晶体载荷", crystalStorage: "晶壳封装", conductionPayload: "传导载荷", heatPayload: "热性载荷", heatCapacity: "热量容量", heatRecovery: "热量回收", recoveryEfficiency: "回收效率", recoveryExtract: "续写抽取", reserveThreshold: "储备阈值", reservePersist: "跨房储备",
  copyPages: "复写页", copyEfficiency: "复制折算", copyInheritance: "加工继承", copyCadence: "复写节奏", chainReach: "传导距离", chainShare: "传导份额", chainCount: "传导落点", fragmentCount: "碎片数量", fragmentShare: "碎片份额", forkPayload: "分发出口", mergePayload: "聚合出口", concentrate: "集中交付", payloadPierce: "载荷穿透",
  thermalRelease: "热性释放", paperRecovery: "纸页回收", missRecovery: "失靶回收", materialConserve: "材料保留", materialRate: "材料供给", reactionEfficiency: "加工折算", markCarrier: "标记承载", markSpread: "标记分发", letterScatter: "散字规则", spellPower: "法术威力", summonTransport: "纸灵运输",
};
const nodeNames = new Map(RELICS.map(node => [node.id, node.name]));
const referenceNames = new Map<string, string>([...RELICS.map(node => [`relic:${node.id}`, `遗物·${node.name}`] as const), ...TALENT_NODES.map(node => [`talent:${node.id}`, `天赋·${node.name}`] as const)]);
const capabilityNames: Record<CombatCapability, string> = { cold: "晶体与寒气", heat: "热性材料", conduction: "电性传导", carrier: "法术承载", guard: "防御出口", release: "终结释放", recovery: "剩余回收" };
const grantCapability: Partial<Record<CombatStat, CombatCapability>> = { crystalPayload: "cold", heatPayload: "heat", conductionPayload: "conduction", copyPages: "carrier", crystalStorage: "carrier", carrierGuard: "guard", carrierRelease: "release", heatRecovery: "recovery", paperRecovery: "recovery" };
function nodeCapabilities(id: string): readonly CombatCapability[] {
  return RELICS.find(relic => relic.id === id)?.provides ?? TALENT_NODES.find(talent => talent.id === id)?.capabilities ?? [];
}
const signed = (value: number) => `${value > 0 ? "+" : ""}${Number.isInteger(value) ? value : Math.round(value * 1000) / 1000}`;
const ratios = new Set<CombatStat>(['copyEfficiency', 'materialRate', 'materialConserve', 'reactionEfficiency', 'recoveryEfficiency', 'fragmentShare', 'chainShare', 'spellPower', 'guardEfficiency']);
const amount = (stat: CombatStat, value: number) => ratios.has(stat) ? `${signed(value * 100)}%` : signed(value);

function EffectSummary({ choice }: { choice: BuildEventChoice }) {
  const grants = Object.entries(choice.grants).filter(([, value]) => value !== undefined && value !== 0) as [CombatStat, number][];
  const losses = grants.filter(([, value]) => value < 0), gains = grants.filter(([, value]) => value > 0);
  const supplied = [...new Set(gains.map(([stat]) => grantCapability[stat]).filter((value): value is CombatCapability => !!value))];
  return <div className="event-effects">
    <div><h4>先付代价与压力</h4>
      {choice.maxHealthCost > 0 && <p>本局生命上限 −{choice.maxHealthCost}</p>}
      {choice.rewardDebt > 0 && <p>后续普通奖励减少 {choice.rewardDebt} 次</p>}
      {choice.pressure > 0 && <p>下一房压力 +{Math.round(choice.pressure * 100)}%</p>}
      {losses.map(([stat, value]) => <p key={stat}>{statNames[stat] ?? stat} {amount(stat, value)}</p>)}
      {choice.replacement && <><p>失去：{nodeNames.get(choice.replacement.from) ?? choice.replacement.from}</p>{nodeCapabilities(choice.replacement.from).length > 0 && <p>原节点能力：{nodeCapabilities(choice.replacement.from).map(value => capabilityNames[value]).join("、")}</p>}</>}
      {!choice.maxHealthCost && !choice.rewardDebt && !choice.pressure && !losses.length && !choice.replacement && <p>无即时资源代价</p>}
    </div>
    <div><h4>{choice.activation === 'after-room' ? '通过下一房后获得' : '选择后获得'}</h4>
      {choice.heal > 0 && <p>恢复生命 +{choice.heal}</p>}
      {gains.map(([stat, value]) => <p key={stat}>{statNames[stat] ?? stat} {amount(stat, value)}</p>)}
      {supplied.length > 0 && <p>新增能力来源：{supplied.map(value => capabilityNames[value]).join("、")}</p>}
      {choice.replacement && <><p>获得：{nodeNames.get(choice.replacement.to) ?? choice.replacement.to}</p>{nodeCapabilities(choice.replacement.to).length > 0 && <p>新节点能力：{nodeCapabilities(choice.replacement.to).map(value => capabilityNames[value]).join("、")}</p>}</>}
      {choice.nodeIds.length > 0 && <p>作用节点：{choice.nodeIds.map(id => referenceNames.get(id) ?? id).join(" · ")}</p>}
      {!choice.heal && !gains.length && !choice.replacement && !choice.nodeIds.length && <p>保留当前构筑</p>}
    </div>
  </div>;
}

export function EventPanel({ offer, onChoose }: { offer: BuildEventOffer; onChoose: (choiceId: string) => void }) {
  const [selectedId, setSelectedId] = useState(() => offer.choices[0]?.id ?? "");
  const [pending, setPending] = useState(false);
  useEffect(() => { setSelectedId(offer.choices[0]?.id ?? ""); setPending(false); }, [offer.id]);
  const selected = offer.choices.find(choice => choice.id === selectedId) ?? offer.choices[0];
  const commit = () => { if (!selected || pending) return; setPending(true); onChoose(selected.id); };
  return <div className="event-panel">
    <div className="event-intro"><span>此行抉择</span><h3>{offer.name}</h3><p>{offer.description}</p></div>
    <div className="event-body">
      <div className="event-options" role="radiogroup" aria-label="事件选择">{offer.choices.map((choice, index) => <button key={choice.id} type="button" role="radio" aria-checked={choice.id === selected?.id} className={choice.id === selected?.id ? "selected" : ""} disabled={pending} onClick={() => setSelectedId(choice.id)}><span className="event-option-order">{String(index + 1).padStart(2, "0")}</span><strong>{choice.name}</strong><span>{choice.description}</span><small>{scopeNames[choice.scope]}</small></button>)}</div>
      {selected && <div className="event-reading" aria-live="polite"><div className="event-reading-heading"><span>{scopeNames[selected.scope]}生效</span><h4>{selected.name}</h4><p>{selected.description}</p></div><EffectSummary choice={selected} />{selected.activation === 'after-room' && <p className="event-trial-order">先通过下一房的压力试炼，再领取收益。</p>}</div>}
    </div>
    <div className="event-actions"><span>此页必须作出选择后继续</span><Button word="chooseevent" variant="primary" disabled={!selected || pending} onClick={commit}>{pending ? "正在写入抉择…" : `选择「${selected?.name ?? ""}」`}</Button></div>
  </div>;
}
