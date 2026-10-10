import { useEffect, useState } from "react";
import type { BuildEventChoice, BuildEventOffer, BuildEventScope } from "../contracts/build-events.ts";
import type { CombatStat } from "../contracts/stats.ts";
import type { CombatCapability } from "../contracts/combat-weave.ts";
import { RELICS } from "../content/catalog.ts";
import { TALENT_NODES } from "../content/talents.ts";
import { Button } from "./components";
import "./event-panel.css";

const scopeNames: Record<BuildEventScope, string> = { room: "下一房", chapter: "本章", run: "本局" };
const statNames: Partial<Record<CombatStat, string>> = {
  carrierCapacity: "保存空位", carrierDelay: "释放前的等待", carrierLifetime: "可保存的时间", carrierRelay: "纸页接力", carrierGuard: "用纸页抵挡攻击", carrierRelease: "结束时释放剩余法术", carrierRetain: "延后释放以便防御", guardNewest: "优先消耗新纸页", guardEfficiency: "纸页防御效率",
  crystalPayload: "寒气与冰晶", crystalStorage: "用冰晶保存法术", conductionPayload: "电荷", heatPayload: "热量", heatCapacity: "储备上限", heatRecovery: "灼烧回收", recoveryEfficiency: "回收比例", recoveryExtract: "提前回收灼烧", reserveThreshold: "使用储备所需的积攒量", reservePersist: "保留储备到下一房",
  copyPages: "复写能力", copyEfficiency: "复写威力", copyInheritance: "复写继承法术形状", copyCadence: "复写积攒速度", chainReach: "连锁距离", chainShare: "用于连锁的威力比例", chainCount: "连锁目标数", fragmentCount: "碎片数量", fragmentShare: "用于碎片的威力比例", forkPayload: "分出更多法术", mergePayload: "合并法术", concentrate: "集中法术", payloadPierce: "穿透目标数",
  thermalRelease: "受热后提前释放", paperRecovery: "回收未用纸页", missRecovery: "失去目标后回收", materialConserve: "材料保留比例", materialRate: "材料积攒速度", reactionEfficiency: "后续法术威力", markCarrier: "用字母奖励保存法术", markSpread: "分散字母奖励", letterScatter: "散落字母奖励", spellPower: "法术威力", summonTransport: "纸灵运送法术",
};
const nodeNames = new Map(RELICS.map(node => [node.id, node.name]));
const referenceNames = new Map<string, string>([...RELICS.map(node => [`relic:${node.id}`, `遗物·${node.name}`] as const), ...TALENT_NODES.map(node => [`talent:${node.id}`, `天赋·${node.name}`] as const)]);
const capabilityNames: Record<CombatCapability, string> = { cold: "寒气与冰晶", heat: "热量", conduction: "连锁传递", carrier: "保存法术", guard: "抵挡攻击", release: "释放剩余法术", recovery: "回收剩余力量" };
const grantCapability: Partial<Record<CombatStat, CombatCapability>> = { crystalPayload: "cold", heatPayload: "heat", conductionPayload: "conduction", copyPages: "carrier", crystalStorage: "carrier", carrierGuard: "guard", carrierRelease: "release", heatRecovery: "recovery", paperRecovery: "recovery" };
function nodeCapabilities(id: string): readonly CombatCapability[] {
  return RELICS.find(relic => relic.id === id)?.provides ?? TALENT_NODES.find(talent => talent.id === id)?.capabilities ?? [];
}
const signed = (value: number) => `${value > 0 ? "+" : ""}${Number.isInteger(value) ? value : Math.round(value * 1000) / 1000}`;
const ratios = new Set<CombatStat>(['copyEfficiency', 'materialRate', 'materialConserve', 'reactionEfficiency', 'recoveryEfficiency', 'fragmentShare', 'chainShare', 'spellPower', 'guardEfficiency']);
const amount = (stat: CombatStat, value: number) => ratios.has(stat) ? `${signed(value * 100)}%` : `${signed(value)}${stat === 'carrierDelay' || stat === 'carrierLifetime' ? ' 秒' : ''}`;

function EffectSummary({ choice }: { choice: BuildEventChoice }) {
  const grants = Object.entries(choice.grants).filter(([, value]) => value !== undefined && value !== 0) as [CombatStat, number][];
  const gains = grants.filter(([, value]) => value > 0);
  const supplied = [...new Set(gains.map(([stat]) => grantCapability[stat]).filter((value): value is CombatCapability => !!value))];
  return <div className="event-effects">
    <div><h4>需要付出</h4>
      {choice.maxHealthCost > 0 && <p>本局生命上限 −{choice.maxHealthCost}</p>}
      {choice.rewardDebt > 0 && <p>后续普通奖励减少 {choice.rewardDebt} 次</p>}
      {choice.pressure > 0 && <p>下一房压力 +{Math.round(choice.pressure * 100)}%</p>}
      {choice.replacement && <><p>失去：{nodeNames.get(choice.replacement.from) ?? choice.replacement.from}</p>{nodeCapabilities(choice.replacement.from).length > 0 && <p>原节点能力：{nodeCapabilities(choice.replacement.from).map(value => capabilityNames[value]).join("、")}</p>}</>}
      {!choice.maxHealthCost && !choice.rewardDebt && !choice.pressure && !choice.replacement && <p>不扣除生命或后续奖励</p>}
    </div>
    <div><h4>{choice.activation === 'after-room' ? '通过下一房后的变化' : '选择后的变化'}</h4>
      {choice.heal > 0 && <p>恢复生命 +{choice.heal}</p>}
      {grants.map(([stat, value]) => <p key={stat}>{statNames[stat] ?? stat} {amount(stat, value)}</p>)}
      {supplied.length > 0 && <p>可用于：{supplied.map(value => capabilityNames[value]).join("、")}</p>}
      {choice.replacement && <><p>获得：{nodeNames.get(choice.replacement.to) ?? choice.replacement.to}</p>{nodeCapabilities(choice.replacement.to).length > 0 && <p>新节点能力：{nodeCapabilities(choice.replacement.to).map(value => capabilityNames[value]).join("、")}</p>}</>}
      {choice.nodeIds.length > 0 && <p>作用节点：{choice.nodeIds.map(id => referenceNames.get(id) ?? id).join(" · ")}</p>}
      {!choice.heal && !grants.length && !choice.replacement && !choice.nodeIds.length && <p>保留当前构筑</p>}
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
