import type { BuildExample, DemonstrationHandle, DemonstrationMetrics, DemonstrationSnapshot } from '../contracts/build-examples.ts';
import type { SimulationContent } from '../contracts/SimulationContent.ts';
import type { BuildEventContext } from '../simulation/progression/BuildEventSystem.ts';
import { CombatSimulation } from '../simulation/CombatSimulation.ts';
import { resolveTalents, talentNeighbors } from '../shared/talents.ts';

const words = ['ember', 'silver', 'mirror', 'cinder', 'river', 'branch', 'paper', 'crystal', 'echo', 'lantern', 'frost', 'storm'].map(word => ({ word }));
const inputPeriod = 60 / (55 * 5);

function talentPath(example: BuildExample): readonly string[] {
  const root = `${example.book}-root`;
  const requested = new Set<string>();
  for (const destination of example.talentIds) {
    const queue = [root];
    const parent = new Map([[root, '']]);
    for (let head = 0; head < queue.length && !parent.has(destination); head++) {
      for (const neighbor of [...talentNeighbors(queue[head])].sort()) if (!parent.has(neighbor)) {
        parent.set(neighbor, queue[head]); queue.push(neighbor);
      }
    }
    if (!parent.has(destination)) throw Error(`Talent ${destination} is disconnected from ${root}`);
    for (let cursor = destination; cursor !== root; cursor = parent.get(cursor)!) requested.add(cursor);
  }
  const resolved = resolveTalents(example.book, [...requested], 24);
  for (const id of example.talentIds) if (!resolved.allocated.includes(id)) throw Error(`Talent ${id} exceeds the legal 24-point example route`);
  return resolved.allocated;
}

function acquire(game: CombatSimulation, example: BuildExample): void {
  for (const id of example.relicIds) {
    const relic = game.content.relics.find(item => item.id === id);
    if (!relic || !game.canUpgrade(relic)) throw Error(`Relic ${id} is not a legal acquisition in example ${example.id}`);
    game.afterUpgrade = 'play';
    game.setState('upgrade');
    game.chooseUpgrade(id);
    if (!game.relics[id]) throw Error(`Relic ${id} was not acquired in example ${example.id}`);
  }
}

function createSimulation(content: SimulationContent, example: BuildExample, talents: readonly string[]): CombatSimulation {
  const game = new CombatSimulation(content);
  try {
    game.start({ book: example.book, mode: 'normal', words, vocabTitle: '演示词页', vocabId: 'demonstration', progressive: false, seed: `learning:${example.id}`, talents: [...talents], talentPoints: 24 });
    game.runId = `learning:${example.id}`;
    acquire(game, example);
    return game;
  } catch (error) { game.destroy(); throw error; }
}

function eventContext(game: CombatSimulation, talents: readonly string[]): BuildEventContext {
  const resolved = resolveTalents(game.book, talents, 24);
  return { runId: game.runId, room: game.roomVisit, chapter: game.campaign.at(game.stage).chapter,
    capabilities: game.capabilities, talentGrants: resolved.grants, talents,
    talentSources: game.content.talents ?? [], relics: game.relics,
    definitions: game.content.relics, hp: game.player.hp, maxHp: game.player.maxHp };
}

function eventReason(game: CombatSimulation, example: BuildExample, talents: readonly string[]): string {
  const definition = game.content.buildEvents?.find(item => item.id === example.eventId);
  if (!definition) return `事件 ${example.eventId} 尚未接入`;
  const ctx = eventContext(game, talents);
  if (ctx.maxHp - definition.maxHealthCost < 25) return `需要支付 ${definition.maxHealthCost} 点生命上限`;
  const missing = definition.needs?.filter(capability => !ctx.capabilities.includes(capability)) ?? [];
  if (missing.length) return `缺少能力：${missing.join('、')}`;
  if (definition.talentStats && !definition.talentStats.some(stat => (ctx.talentGrants[stat] ?? 0) > 0)) return `缺少事件要求的天赋规则`;
  if (definition.evolve) return `缺少可合法演化的 ${definition.family ?? ''} 遗物`;
  return '当前事件资格未满足';
}

function metric(game: CombatSimulation): DemonstrationMetrics {
  const weave = game.weave.summary;
  return { seconds: game.elapsed, casts: game.casts, damage: game.totalDamage, health: game.player.hp,
    shield: game.player.shield, manualCharacters: weave.manualCharacters, pagesCreated: weave.pagesCreated,
    pagesReleased: weave.pagesReleased, pagesBlocked: weave.pagesBlocked, recoveredHeat: weave.recoveredHeat,
    kills: game.kills, state: game.state, roomVisit: game.roomVisit,
    remainingShots: game.shots.filter(shot => !shot.dead).length, remainingPages: game.weave.pages.length };
}

function continueWithoutReward(game: CombatSimulation, firstRoom: number): void {
  if (game.state === 'upgrade') {
    const after = game.afterUpgrade;
    game.pending = 0;
    game.afterUpgrade = null;
    game.setState('playing');
    if (after === 'clear') game.completeRoom();
    else if (after === 'route') game.beginRoom(game.queuedRoute);
  }
  if (game.state === 'route' && game.roomVisit === firstRoom) {
    const normal = game.routeOffers.find(route => route.type === 'normal' && !route.relic);
    if (normal) game.chooseRoute(normal);
  }
}

function enterOneCharacter(game: CombatSimulation): void {
  if (game.state !== 'playing') return;
  const target = game.target && (game.target.dead ? !!game.prefix : true) ? game.target : null;
  const next = target?.word[game.prefix.length];
  if (next && next !== ' ') { game.input(next); return; }
  const candidate = game.targets().filter(item => !!item.kind || game.canEnemyAct(item)).sort((a, b) => game.priority(a) - game.priority(b))[0];
  if (candidate) game.input(candidate.word[0]);
}

export function createBuildDemonstration(content: SimulationContent, example: BuildExample): DemonstrationHandle {
  const talents = talentPath(example);
  const baseline = createSimulation(content, example, talents);
  let revised: CombatSimulation;
  try { revised = createSimulation(content, example, talents); }
  catch (error) { baseline.destroy(); throw error; }
  const held = Object.keys(baseline.relics).sort();
  const talentNames = talents.map(id => content.talents?.find(node => node.id === id)?.name ?? id);
  const relicNames = (ids: readonly string[]) => ids.map(id => content.relics.find(relic => relic.id === id)?.name ?? id);
  const definition = content.buildEvents?.find(item => item.id === example.eventId);
  const offer = definition && revised.buildEvents.open([definition], eventContext(revised, talents), () => 0);
  let applied = false;
  let eventStatus = offer ? definition!.name : eventReason(revised, example, talents);
  if (offer) {
    revised.setState('event');
    applied = revised.chooseEvent(offer.id, 'rewrite');
    if (!applied) eventStatus = '事件提交条件已变化';
  }
  baseline.beginRoom(); // Both arms enter the same next room after the event decision.
  if (!applied) revised.destroy();
  const firstRoom = baseline.roomVisit;
  let running = true;
  let elapsed = 0;
  let accumulator = 0;
  let finalSnapshot: DemonstrationSnapshot | undefined;
  const snapshot = (): DemonstrationSnapshot => finalSnapshot ?? ({ example, talentIds: talents, heldRelics: held,
    talentNames, heldRelicNames: relicNames(held), revisedRelicNames: applied ? relicNames(Object.keys(revised.relics).sort()) : undefined,
    eventStatus, eventApplied: applied, eventScope: definition?.scope,
    eventRecordStatus: applied ? revised.buildEvents.records.find(record => record.definitionId === example.eventId)?.status : undefined,
    elapsed, baseline: metric(baseline), revised: applied ? metric(revised) : undefined, running });
  const stop = () => {
    if (!running) return;
    running = false;
    finalSnapshot = snapshot();
    baseline.destroy();
    if (applied) revised.destroy();
  };
  return {
    snapshot,
    step(seconds) {
      if (!running) return snapshot();
      const dt = Math.max(0, Math.min(.1, seconds, 45 - elapsed));
      elapsed += dt;
      baseline.update(dt); if (applied) revised.update(dt);
      continueWithoutReward(baseline, firstRoom);
      if (applied) continueWithoutReward(revised, firstRoom);
      accumulator += dt;
      while (accumulator >= inputPeriod) {
        accumulator -= inputPeriod;
        enterOneCharacter(baseline);
        if (applied) enterOneCharacter(revised);
      }
      if (elapsed >= 45 || (baseline.state !== 'playing' && (!applied || revised.state !== 'playing'))) stop();
      return snapshot();
    },
    stop,
    destroy: stop,
  };
}
