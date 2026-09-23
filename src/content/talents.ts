import type { TalentNode } from "../contracts/talents.ts";

/** Edges are undirected. Content order is the deterministic tie-break for invalid saves. */
export const TALENT_NODES: readonly TalentNode[] = [
  { id: "frost-root", name: "霜页", description: "冰霜主书的免费起点。从其他主书连入时，为主术提供30点寒气的晶体结构。", school: "frost", root: "frost", cost: 1, x: 100, y: 85, links: ["cold-ink", "rime"], capabilities: ["cold"], grants: { crystalPayload: 1 } },
  { id: "flame-root", name: "焰页", description: "火焰主书的免费起点。从其他主书连入时，每12个有效人工字符供给一份热性载荷。", school: "flame", root: "flame", cost: 1, x: 760, y: 85, links: ["warm-ink", "ember"], capabilities: ["heat"], grants: { heatPayload: 1 } },
  { id: "storm-root", name: "雷页", description: "雷霆主书的免费起点。从其他主书连入时，每12个有效人工字符供给一份有限传导。", school: "storm", root: "storm", cost: 1, x: 760, y: 455, links: ["branch", "reflected-light"], capabilities: ["conduction"], grants: { conductionPayload: 1 } },
  { id: "spirit-root", name: "纸页", description: "纸灵主书的免费起点。从其他主书连入时，每12个有效人工字符供给一张复写页。", school: "spirit", root: "spirit", cost: 1, x: 100, y: 455, links: ["copy-page", "paper-ward"], capabilities: ["carrier"], grants: { copyPages: 1 } },
  { id: "cold-ink", name: "凝墨", description: "寒气层数 +1，主术命中可附加寒气。", school: "frost", cost: 1, x: 235, y: 85, links: ["crystal"], grants: { coldStacks: 1 }, capabilities: ["cold"] },
  { id: "warm-ink", name: "温墨", description: "灼烧强度增加一阶，强化法术已施加的灼烧。", school: "flame", cost: 1, x: 625, y: 85, links: ["heat-payload"], grants: { burnPower: 1 }, capabilities: ["heat"] },
  { id: "branch", name: "分枝", description: "主书雷电可多传导一个目标。", school: "storm", cost: 1, x: 625, y: 455, links: ["conduction-payload"], grants: { chainTargets: 1 } },
  { id: "copy-page", name: "复写", description: "以人工输入积累有限纸页，纸页可承载主术。", school: "spirit", cost: 1, x: 235, y: 455, links: ["paper-carrier"], grants: { copyPages: 1 }, capabilities: ["carrier"] },
  { id: "crystal", name: "晶构", description: "为主术加入晶体结构，使承载与传导拥有冰霜材料。", school: "frost", cost: 1, x: 325, y: 175, links: ["binding", "focus", "rime"], grants: { crystalPayload: 1 }, capabilities: ["cold"] },
  { id: "heat-payload", name: "热载", description: "为主术加入热性载荷，热量可随组合传播。", school: "flame", cost: 1, x: 535, y: 175, links: ["binding", "focus", "recovery"], grants: { heatPayload: 1 }, capabilities: ["heat"] },
  { id: "conduction-payload", name: "导流", description: "为主术建立有限传导，每次传播实际消耗载荷。", school: "storm", cost: 1, x: 535, y: 365, links: ["binding", "focus", "reflected-light"], grants: { conductionPayload: 1 }, capabilities: ["conduction"] },
  { id: "paper-carrier", name: "承页", description: "增加一份可积累的纸页承载，纸页具有有限寿命。", school: "spirit", cost: 1, x: 325, y: 365, links: ["binding", "focus", "echo", "paper-ward"], grants: { copyPages: 1 }, capabilities: ["carrier"] },
  { id: "binding", name: "合订", description: "开放一本副书。每 12 个有效人工字符积累一份副术材料，最多缓存三份。与独卷互斥。", school: "shared", cost: 2, x: 430, y: 220, links: [], grants: { secondaryBinding: 1 }, exclusive: "binding" },
  { id: "focus", name: "独卷", description: "主术威力提高 30%。专注主书，与合订互斥。", school: "shared", cost: 2, x: 430, y: 315, links: [], grants: { singleFocus: 1 }, exclusive: "binding" },
  { id: "rime", name: "霜纹", description: "额外增加一层寒气，深化冻结能力。", school: "frost", cost: 1, x: 100, y: 210, links: ["paper-ward"], grants: { coldStacks: 1 }, capabilities: ["cold"] },
  { id: "ember", name: "余烬", description: "额外增加一层灼烧强度。", school: "flame", cost: 1, x: 760, y: 210, links: ["recovery"], grants: { burnPower: 1 }, capabilities: ["heat"] },
  { id: "recovery", name: "余热回收", description: "回收人工主术留下的未结算灼烧，以折损热量供给下一次释放。", school: "flame", cost: 2, x: 645, y: 270, links: ["conduction-payload"], grants: { heatRecovery: 1 }, capabilities: ["recovery"], requires: ["heat"] },
  { id: "reflected-light", name: "回光", description: "反射威力 +1，强化弹反回敬的攻击。", school: "storm", cost: 1, x: 760, y: 335, links: ["ember"], grants: { reflectPower: 1 } },
  { id: "paper-ward", name: "护页", description: "纸页可被防御消耗；每页只选择一种消耗出口。", school: "spirit", cost: 1, x: 100, y: 335, links: [], grants: { carrierGuard: 1 }, capabilities: ["guard"], requires: ["carrier"] },
  { id: "echo", name: "遗响", description: "纸页因防御或寿命终结消耗时，释放尚未使用的载荷。", school: "spirit", cost: 2, x: 280, y: 270, links: [], grants: { carrierRelease: 1 }, capabilities: ["release"], requires: ["carrier"] },
];

export const TALENT_BY_ID = Object.fromEntries(TALENT_NODES.map(node => [node.id, node]));
export const TALENT_BOOKS = ["frost", "flame", "storm", "spirit"] as const;
