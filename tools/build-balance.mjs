#!/usr/bin/env node
/** Full-content, deterministic diagnostic. Run only during final integrated acceptance. */
import { createHash } from 'node:crypto';
import { createWriteStream } from 'node:fs';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { once } from 'node:events';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { cpus, release, totalmem } from 'node:os';
import { builtinContent } from '../src/bootstrap/content.ts';
import { CombatSimulation } from '../src/simulation/CombatSimulation.ts';
import { resolveTalents, talentNeighbors } from '../src/shared/talents.ts';
import { collectCapabilities } from '../src/shared/combat-capabilities.ts';
import { eligibleRelic } from '../src/simulation/progression/EligibilityService.ts';
import { random, hash } from '../src/shared/math.ts';
import { WordPool } from '../src/vocabulary/index.ts';
import { trajectoryMetrics, scenarioGain, aggregateGain, budget, quantile, dominates, clamp01 } from './balance-model.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const sha = value => createHash('sha256').update(typeof value === 'string' ? value : JSON.stringify(value)).digest('hex');
const key = value => { let hash = 2166136261; for (const char of value) hash = Math.imul(hash ^ char.charCodeAt(0), 16777619); return hash >>> 0; };
const stable = (items, seed) => [...items].sort((a, b) => key(`${seed}:${a.id}`) - key(`${seed}:${b.id}`) || a.id.localeCompare(b.id));
const toFixed = value => Number.isFinite(value) ? Math.round(value * 1e6) / 1e6 : null;

function argumentsOf(argv) {
  const options = { config: resolve(root, 'tools/build-balance.config.json'), out: resolve(root, '.temp/build-balance'), limit: Infinity, phase: 'all', shard: null, focus: {}, merge: null };
  for (let index = 0; index < argv.length; index++) {
    const flag = argv[index], value = argv[++index];
    if (!['--config', '--out', '--limit', '--phase', '--shard', '--focus', '--merge'].includes(flag) || !value) throw new Error(`Expected --config PATH, --out DIR, --limit COUNT, --phase NAME, --shard INDEX/TOTAL, --focus KEY:VALUE, or --merge DIR[,DIR...]; got ${flag}`);
    if (flag === '--limit') { options.limit = Number(value); if (!Number.isInteger(options.limit) || options.limit < 1) throw new Error('--limit must be a positive integer'); }
    else if (flag === '--phase') { options.phase = value; if (!['all', 'fixed', 'extras', 'full'].includes(value)) throw new Error('--phase must be all, fixed, extras, or full'); }
    else if (flag === '--shard') {
      const match = /^(\d+)\/(\d+)$/.exec(value);
      if (!match) throw new Error('--shard must be INDEX/TOTAL, zero based');
      options.shard = { index: Number(match[1]), total: Number(match[2]) };
      if (!Number.isSafeInteger(options.shard.index) || !Number.isSafeInteger(options.shard.total) || options.shard.total < 1 || options.shard.index >= options.shard.total) throw new Error('Invalid --shard INDEX/TOTAL');
    }
    else if (flag === '--focus') {
      const match = /^(book|tier|mode|input|route|wpm|seed|scene):(.+)$/.exec(value);
      if (!match) throw new Error('--focus must be book|tier|mode|input|route|wpm|seed|scene:VALUE[,VALUE...]');
      options.focus[match[1]] = match[2].split(',');
    }
    else if (flag === '--merge') options.merge = value.split(',').map(path => resolve(path));
    else options[flag.slice(2)] = resolve(value);
  }
  if (options.shard && !['all', 'fixed'].includes(options.phase)) throw new Error('--shard applies only to fixed cases');
  if (Object.keys(options.focus).length && !['all', 'full', 'fixed'].includes(options.phase)) throw new Error('--focus applies only to full or fixed cases');
  if (options.merge && (options.phase !== 'all' || options.shard || Object.keys(options.focus).length)) throw new Error('--merge must be used without phase, shard, or focus');
  return options;
}
function validateConfig(config) {
  if (config.version !== 1 || !config.books?.length || !config.modes?.length || !config.tiers?.length || !config.inputGroups?.length || !config.seeds?.length || !config.scenarios?.length) throw new Error('Incomplete versioned balance configuration');
  for (const book of config.books) if (!builtinContent.books[book]) throw new Error(`Unknown book ${book}`);
  for (const mode of config.modes) if (!builtinContent.modes[mode]) throw new Error(`Unknown mode ${mode}`);
  for (const tier of config.tiers) if (!Number.isInteger(tier.points) || tier.points < 0 || tier.points > 24 || !(tier.healthScale > 0)) throw new Error(`Invalid tier ${tier.name}`);
  for (const group of config.inputGroups) if (!group.wpm?.every(value => value > 0)) throw new Error(`Invalid input group ${group.name}`);
  for (const scene of config.scenarios) {
    if (!(scene.seconds > 0 && scene.characters > 0 && scene.weight > 0)) throw new Error(`Invalid scene ${scene.id}`);
    if (scene.kind === 'boss') continue;
    if (!scene.targets?.length || !scene.targets.every(target => builtinContent.enemies[target.type] && target.weight > 0 && Number.isFinite(target.x) && Number.isFinite(target.y))) throw new Error(`Invalid target list ${scene.id}`);
  }
  if (!config.words?.length) throw new Error('No fixed input words');
  if (config.fullRun?.enabled && (!(config.fullRun.seconds > 0) || !config.fullRun.tiers?.length || !config.fullRun.routes?.length || config.fullRun.tiers.some(name => !config.tiers.some(tier => tier.name === name)) || config.fullRun.routes.some(route => !['ordinary', 'favorable'].includes(route)))) throw new Error('Invalid full-run matrix');
  if (config.bossLifecycle && (!(config.bossLifecycle.seconds > 0) || !config.tiers.some(tier => tier.name === config.bossLifecycle.tier) || config.bossLifecycle.modes.some(mode => !config.modes.includes(mode)) || config.bossLifecycle.wpm.some(wpm => !config.inputGroups.some(group => group.wpm.includes(wpm))))) throw new Error('Invalid boss lifecycle matrix');
}

function talentDistance(target, id) {
  if (target === id) return 0;
  const seen = new Set([id]), queue = [[id, 0]];
  for (let i = 0; i < queue.length; i++) for (const next of talentNeighbors(queue[i][0])) {
    if (next === target) return queue[i][1] + 1;
    if (!seen.has(next)) { seen.add(next); queue.push([next, queue[i][1] + 1]); }
  }
  return Infinity;
}
function talentPlan(book, points, targetId, seed) {
  let current = resolveTalents(book, [], points, false);
  if (!targetId) return current;
  for (let step = 0; step < 30 && !current.allocated.includes(targetId); step++) {
    const candidates = builtinContent.talents.filter(node => !current.allocated.includes(node.id)).map(node => {
      const trial = resolveTalents(book, [...current.allocated, node.id], points, false);
      return { node, trial };
    }).filter(item => item.trial.allocated.includes(item.node.id) && current.allocated.every(id => item.trial.allocated.includes(id)));
    if (!candidates.length) break;
    candidates.sort((a, b) => talentDistance(targetId, a.node.id) - talentDistance(targetId, b.node.id) || key(`${seed}:${a.node.id}`) - key(`${seed}:${b.node.id}`));
    current = candidates[0].trial;
  }
  return current.allocated.includes(targetId) ? current : null;
}
function filledTalentPlan(book, points, seed) {
  let current = resolveTalents(book, [], points, false);
  for (let step = 0; step < 30; step++) {
    const candidates = stable(builtinContent.talents.filter(node => !current.allocated.includes(node.id)), seed).map(node => resolveTalents(book, [...current.allocated, node.id], points, false)).filter(trial => trial.spent > current.spent && current.allocated.every(id => trial.allocated.includes(id)));
    if (!candidates.length) break;
    candidates.sort((a, b) => b.spent - a.spent);
    current = candidates[0];
  }
  return current;
}
function sampleTalents(book, tier, config, skipped) {
  const result = [{ id: `${book}:${tier.name}:base`, book, tier: tier.name, points: tier.points, talents: [], talentTarget: null, relicTarget: null, relics: [], secondaryBook: undefined, spent: 0, opportunities: 0 }];
  const families = Map.groupBy(builtinContent.talents.filter(node => !node.root), node => node.family ?? node.school);
  for (const [family, nodes] of families) for (const node of stable(nodes, `${book}:${tier.name}:${family}`).slice(0, config.sample.perFamily)) {
    const trial = talentPlan(book, tier.points, node.id, `${book}:${tier.name}`);
    if (!trial) { skipped.push({ type: 'talent', id: node.id, book, tier: tier.name, reason: 'unreachable_with_budget_or_prerequisite' }); continue; }
    result.push({ id: `${book}:${tier.name}:talent:${node.id}`, book, tier: tier.name, points: tier.points, talents: trial.allocated, talentTarget: node.id, relicTarget: null, relics: [], secondaryBook: undefined, spent: trial.spent, opportunities: 0 });
  }
  return result;
}

function relicSequence(target, book, talentIds, words, maxOpportunities) {
  const resolved = resolveTalents(book, talentIds, 24, false);
  const levels = {}, sequence = [], busy = new Set();
  const shortest = Math.min(...words.map(word => word.length)), longest = Math.max(...words.map(word => word.length));
  const capabilities = () => collectCapabilities(builtinContent.books[book], builtinContent.relics, levels, resolved.capabilities);
  const stats = new Proxy({}, { get: (_, stat) => typeof stat === 'string' ? (resolved.grants[stat] ?? 0) + builtinContent.relics.reduce((sum, item) => sum + (levels[item.id] ?? 0) * (item.grants?.[stat] ?? 0), 0) : undefined });
  const byId = new Map(builtinContent.relics.map(relic => [relic.id, relic]));
  const acquire = (id, desired = 1) => {
    const relic = byId.get(id);
    if (!relic) throw new Error(`unknown_prerequisite:${id}`);
    if (relic.eventOnly) throw new Error(`event_only:${id}`);
    if (busy.has(id)) throw new Error(`cyclic_prerequisite:${id}`);
    busy.add(id);
    try {
      while ((levels[id] ?? 0) < desired) {
        if (sequence.length >= maxOpportunities) throw new Error(`opportunity_limit:${id}`);
        for (const required of relic.requires ?? []) if (!levels[required]) acquire(required);
        for (const [required, level] of Object.entries(relic.requiresLevels ?? {})) if ((levels[required] ?? 0) < level) acquire(required, level);
        if (relic.evolution && !levels[relic.evolution.from]) acquire(relic.evolution.from);
        for (const capability of relic.needs ?? []) if (!capabilities().includes(capability)) {
          const providers = stable(builtinContent.relics.filter(item => !item.eventOnly && item.id !== id && item.provides?.includes(capability)), `${book}:${id}:${capability}`);
          let supplied = false;
          for (const provider of providers) {
            const before = sequence.length;
            try { acquire(provider.id); supplied = capabilities().includes(capability); if (supplied) break; }
            catch { /* Try another legal source after reverting the attempt below. */ }
            while (sequence.length > before) sequence.pop();
            Object.keys(levels).forEach(key => delete levels[key]);
            for (const acquired of sequence) { const item = byId.get(acquired); if (item.evolution) delete levels[item.evolution.from]; levels[acquired] = (levels[acquired] ?? 0) + 1; }
          }
          if (!supplied) throw new Error(`missing_capability:${capability}`);
        }
        if (!eligibleRelic(relic, { book, levels, shortest, longest, capabilities: capabilities(), definitions: builtinContent.relics, stats })) throw new Error(`ineligible_after_prerequisites:${id}`);
        sequence.push(id);
        if (relic.evolution) delete levels[relic.evolution.from];
        levels[id] = (levels[id] ?? 0) + 1;
      }
    } finally { busy.delete(id); }
  };
  acquire(target.id);
  return sequence;
}

function sampleBuilds(config, skipped) {
  const builds = [];
  for (const book of config.books) for (const tier of config.tiers) {
    const talentBuilds = sampleTalents(book, tier, config, skipped);
    builds.push(...talentBuilds);
    const focus = tier.points === Math.max(...config.tiers.map(item => item.points)) ? builtinContent.relics : [...Map.groupBy(builtinContent.relics, relic => relic.family ?? 'legacy').values()].flatMap(items => stable(items, `${book}:${tier.name}`).slice(0, config.sample.perFamily));
    for (const relic of focus) {
      try {
        const sequence = relicSequence(relic, book, [], config.words, config.sample.maxRelicOpportunities);
        builds.push({ id: `${book}:${tier.name}:relic:${relic.id}`, book, tier: tier.name, points: tier.points, talents: [], talentTarget: null, relicTarget: relic.id, relics: sequence, secondaryBook: undefined, spent: 0, opportunities: sequence.length });
      } catch (error) { skipped.push({ type: 'relic', id: relic.id, book, tier: tier.name, reason: error.message }); }
    }
    for (const talentBuild of talentBuilds.filter(item => item.talentTarget)) {
      const talent = builtinContent.talents.find(item => item.id === talentBuild.talentTarget);
      const related = builtinContent.relics.filter(relic => !relic.eventOnly && (relic.family === talent?.family || Object.keys(relic.grants ?? {}).some(stat => talent?.grants?.[stat] !== undefined) || relic.needs?.some(capability => talent?.capabilities?.includes(capability))));
      const relic = stable(related, `${book}:${tier.name}:${talentBuild.talentTarget}`)[0];
      if (!relic) continue;
      try {
        const sequence = relicSequence(relic, book, talentBuild.talents, config.words, config.sample.maxRelicOpportunities);
        builds.push({ ...talentBuild, id: `${book}:${tier.name}:combo:${talent.id}:${relic.id}`, relicTarget: relic.id, relics: sequence, opportunities: sequence.length });
      } catch (error) { skipped.push({ type: 'combo', id: `${talent.id}+${relic.id}`, book, tier: tier.name, reason: error.message }); }
    }
    if (config.sample.secondaryBooks) {
      for (const secondaryBook of config.books.filter(id => id !== book)) {
        const binding = builtinContent.talents.find(node => node.grants?.secondaryBinding);
        const trial = binding && talentPlan(book, tier.points, binding.id, `${book}:${secondaryBook}`);
        if (trial?.grants.secondaryBinding) builds.push({ id: `${book}:${tier.name}:secondary:${secondaryBook}`, book, tier: tier.name, points: tier.points, talents: trial.allocated, talentTarget: binding.id, relicTarget: null, relics: [], secondaryBook, spent: trial.spent, opportunities: 0 });
        else skipped.push({ type: 'secondary', id: `${book}->${secondaryBook}`, tier: tier.name, reason: 'binding_path_unreachable' });
      }
    }
  }
  return [...new Map(builds.map(build => [build.id, build])).values()];
}

function configureFixedEncounter(game, scene) {
  game.resetArrays();
  game.roomQuota = Number.MAX_SAFE_INTEGER;
  game.spawned = 0;
  game.waveCount = 1;
  game.spawnClock = Number.POSITIVE_INFINITY;
  game.nodeClock = Number.POSITIVE_INFINITY;
  game.roomEnded = false;
  game.bossRoom = false;
  const targets = scene.targets.map(spec => {
    const enemy = game.spawnEnemy(spec.type, spec.x, spec.y, false, true);
    if (!enemy) throw new Error(`spawn_failed:${spec.type}`);
    return { enemy, entryHp: enemy.maxHp, weight: spec.weight };
  });
  return targets;
}
function currentProgress(targets) {
  const total = targets.reduce((sum, target) => sum + target.weight, 0);
  return targets.reduce((sum, target) => sum + target.weight * (target.enemy.dead ? 1 : clamp01((target.entryHp - target.enemy.hp) / target.entryHp)), 0) / total;
}
function currentRisk(game) { return clamp01(1 - game.player.hp / Math.max(1, game.player.maxHp)); }
function operateDefense(game, enabled) {
  if (!enabled || game.player.invuln > .12 || game.player.dashState) return;
  const player = game.player;
  const projectile = game.bullets.some(bullet => !bullet.dead && !bullet.reflected && Math.hypot(bullet.x + bullet.vx * .18 - player.x, bullet.y + bullet.vy * .18 - player.y) < bullet.r + 28);
  const area = game.lasers.some(laser => !laser.dead && laser.warning < .3 && (laser.vertical ? Math.abs(player.x - laser.pos) : Math.abs(player.y - laser.pos)) < laser.width + 18) || game.blasts.some(blast => !blast.dead && blast.warning < .3 && Math.hypot(blast.x - player.x, blast.y - player.y) < blast.r + 18);
  if (!projectile && !area) return;
  if (!area && player.parryCooldown <= 0) game.input(' ');
  else if (player.dash >= 1) game.input(player.x > 640 ? 'ArrowLeft' : 'ArrowRight');
}
function operateTyping(game, clock, dt, wpm, fixedCharacters, actualSent) {
  clock -= dt;
  if (clock > 0 || actualSent >= fixedCharacters) return { clock, actualSent };
  const targets = game.targets().filter(target => !target.dead && !target.wordPending);
  targets.sort((a, b) => game.priority(a) - game.priority(b) || a.id - b.id);
  if (!game.target || game.target.dead || game.target.wordPending) {
    if (targets[0]) game.clickTarget(targets[0].x, targets[0].y, targets[0].id);
  }
  const letter = game.target?.word?.[game.prefix.length];
  if (letter) { if (game.input(letter)) actualSent++; game.releaseKey(letter); }
  return { clock: (letter ? Math.max(-dt, clock) : 0) + 60 / (wpm * 5), actualSent };
}

function acquireBuild(game, build) {
  const resolved = resolveTalents(build.book, build.talents, build.points, false);
  if (resolved.allocated.length !== new Set(build.talents).size + (build.talents.includes(`${build.book}-root`) ? 0 : 1) || resolved.spent !== build.spent) throw new Error('talent_resolver_rejected_build');
  for (const id of build.relics) {
    const relic = builtinContent.relics.find(item => item.id === id);
    if (!relic || !game.canUpgrade(relic)) throw new Error(`illegal_reward_sequence:${id}`);
    const before = game.relics[id] ?? 0;
    game.afterUpgrade = 'play';
    game.setState('upgrade');
    game.chooseUpgrade(id);
    if (game.state !== 'playing' || (game.relics[id] ?? 0) !== before + 1) throw new Error(`formal_acquire_failed:${id}`);
  }
}

function simulateFixed(build, scene, tier, mode, wpm, seed, config) {
  if (scene.kind === 'boss') return { status: 'unsupported', reason: 'No fixed stage/phase target adapter; boss progress cannot be credited exactly.' };
  const scaledEnemies = Object.fromEntries(Object.entries(builtinContent.enemies).map(([id, enemy]) => [id, { ...enemy, hp: enemy.hp * tier.healthScale }]));
  const content = { ...builtinContent, enemies: scaledEnemies };
  const game = new CombatSimulation(content);
  game.start({ seed, book: build.book, mode, words: config.words, vocabTitle: 'Balance fixed list', vocabId: 'balance-fixed', progressive: false, talentPoints: build.points, talents: build.talents, secondaryBook: build.secondaryBook });
  if (game.godMode) throw new Error('god_mode_forbidden');
  acquireBuild(game, build);
  return measureEncounter(game, scene, wpm, seed, config);
}
function measureEncounter(game, scene, wpm, seed, config) {
  // Reward acquisition cannot alter the fixed encounter's random stream.
  game.rng = random(hash(`${seed}:${scene.id}:encounter`));
  game.pool = new WordPool(config.words, game.rng);
  const targets = configureFixedEncounter(game, scene);
  const horizon = scene.seconds, dt = 1 / 60;
  let clock = 0, actualSent = 0, clearTime = null, deathTime = null, deferredRewards = 0;
  const samples = [{ t: 0, progress: currentProgress(targets), risk: currentRisk(game), terminal: null }];
  for (let tick = 0; tick < Math.ceil(horizon / dt); tick++) {
    if (game.state === 'upgrade') {
      if (game.afterUpgrade !== 'play') throw new Error(`unexpected_fixed_reward_continuation:${game.afterUpgrade}`);
      game.pending = 0;
      game.afterUpgrade = null;
      game.setState('playing');
      deferredRewards++;
    }
    if (game.state !== 'playing') throw new Error(`unexpected_state:${game.state}`);
    operateDefense(game, true);
    if (game.resonance >= 100 && (game.enemies.filter(enemy => !enemy.dead).length > 2 || game.bossRoom)) game.input('Shift');
    ({ clock, actualSent } = operateTyping(game, clock, dt, wpm, scene.characters, actualSent));
    game.updateVisual(dt); game.update(dt);
    const t = Math.min(horizon, (tick + 1) * dt);
    const dead = game.player.hp <= 0 || game.state === 'result';
    const cleared = targets.every(target => target.enemy.dead);
    const terminal = dead ? 'dead' : cleared ? 'cleared' : null;
    if (tick % 15 === 14 || terminal || t >= horizon) samples.push({ t, progress: currentProgress(targets), risk: dead ? 1 : currentRisk(game), terminal });
    if (terminal) { if (dead) deathTime = t; else clearTime = t; break; }
  }
  const metric = trajectoryMetrics(samples, horizon, scene.characters);
  const actualManual = game.weave.summary.manualCharacters;
  return { status: 'ok', ...metric, clearTime, deathTime, cleared: clearTime !== null, actualSent, actualManual, deferredRewards, per100ActualCharacters: actualManual > 0 ? 100 * metric.progressIntegral / (actualManual * horizon) : null, kills: game.kills, casts: game.casts, hp: game.player.hp, maxHp: game.player.maxHp, stage: game.stage, resource: game.weave.summary, trajectory: samples };
}

function favorableRoute(route) { return Number(Boolean(route.relic)) * 100 + (route.heal ?? 0) + (route.shield ?? 0) * .5 - (route.hurt ?? 0) * 2; }
function favorableReward(reward) { return ({ curse: -2, common: 0, rare: 2, awaken: 3 })[reward.rarity] ?? -1; }
function favorableEvent(choice) { return Object.values(choice.grants).reduce((sum, value) => sum + Math.max(0, value ?? 0), 0) + (choice.heal ?? 0) / 20 - (choice.maxHealthCost ?? 0) / 10 - (choice.rewardDebt ?? 0) - (choice.pressure ?? 0); }
function simulateFullRun(book, tier, routeStrategy, mode, wpm, seed, config) {
  let offer = null, rewardOffer = null;
  const game = new CombatSimulation(builtinContent, { event(value) { offer = value; }, upgrade(value) { rewardOffer = value; } });
  const talentBuild = filledTalentPlan(book, tier.points, `${book}:${tier.name}:campaign`);
  game.start({ seed, book, mode, words: config.words, vocabTitle: 'Balance fixed list', vocabId: 'balance-fixed', progressive: false, talentPoints: tier.points, talents: talentBuild.allocated });
  let clock = 0, actualSent = 0, elapsed = 0;
  const dt = 1 / 60, horizon = config.fullRun.seconds;
  const acquired = [], routes = [], events = [];
  let transitions = 0;
  while (elapsed < horizon && game.state !== 'result') {
    if (++transitions > horizon / dt + 10000) throw new Error('campaign_transition_limit');
    if (game.state === 'upgrade') {
      const choices = rewardOffer;
      if (!choices?.length) throw new Error('missing_emitted_upgrade_offer');
      const choice = routeStrategy === 'favorable' ? [...choices].sort((a, b) => favorableReward(b) - favorableReward(a))[0] : choices[0];
      if (!choice) throw new Error('missing_upgrade_offer');
      rewardOffer = null;
      game.chooseUpgrade(choice.id); acquired.push(choice.id); continue;
    }
    if (game.state === 'route') {
      const route = routeStrategy === 'favorable' ? [...game.routeOffers].sort((a, b) => favorableRoute(b) - favorableRoute(a))[0] : game.routeOffers[0];
      if (!route) throw new Error('missing_route_offer');
      game.chooseRoute(route); routes.push(route.id); continue;
    }
    if (game.state === 'event') {
      const choice = routeStrategy === 'favorable' ? [...(offer?.choices ?? [])].sort((a, b) => favorableEvent(b) - favorableEvent(a))[0] : offer?.choices.at(-1);
      if (!choice) throw new Error('missing_event_offer');
      if (!game.chooseEvent(offer.id, choice.id)) throw new Error(`event_choice_rejected:${offer.id}:${choice.id}`);
      events.push({ offer: offer.id, choice: choice.id }); offer = null; continue;
    }
    if (game.state !== 'playing') throw new Error(`unsupported_full_run_state:${game.state}`);
    operateDefense(game, true);
    if (game.resonance >= 100 && (game.enemies.length > 2 || game.bossRoom)) game.input('Shift');
    ({ clock, actualSent } = operateTyping(game, clock, dt, wpm, Infinity, actualSent));
    game.updateVisual(dt); game.update(dt); elapsed += dt;
  }
  return { status: 'ok', kind: 'fullRun', book, tier: tier.name, talentPoints: tier.points, talents: talentBuild.allocated, spent: talentBuild.spent, routeStrategy, mode, wpm, seed, result: game.state === 'result' ? game.lastWin ? 'win' : 'defeat' : 'timeout', elapsed: toFixed(elapsed), timeLimit: horizon, stage: game.stage, hp: toFixed(game.player.hp), maxHp: toFixed(game.player.maxHp), kills: game.kills, casts: game.casts, actualSent, actualManual: game.weave.summary.manualCharacters, relics: { ...game.relics }, acquired, routes, events, progressMetric: 'unsupported_across_variable_boss_phases' };
}

function eventCandidates(definition, builds) {
  return [...builds].sort((a, b) => {
    const score = build => Number(Boolean(definition.evolve && build.relics.some(id => builtinContent.relics.find(relic => relic.id === id)?.family === definition.family))) * 100 + Number(Boolean(definition.talentStats?.length && build.talents.length)) * 20 + Number(Boolean(definition.needs?.length && build.relics.length)) * 10 + build.relics.length;
    return score(b) - score(a) || a.id.localeCompare(b.id);
  });
}
function simulateEvent(definition, choiceId, builds, config) {
  const rejections = [];
  const mode = config.modes[0], wpm = config.inputGroups[0].wpm[0];
  for (const build of eventCandidates(definition, builds)) {
    let offer = null;
    const content = { ...builtinContent, buildEvents: [definition] };
    const game = new CombatSimulation(content, { event(value) { offer = value; } });
    try {
      game.start({ seed: `event:${definition.id}:${build.id}`, book: build.book, mode, words: config.words, vocabTitle: 'Balance fixed list', vocabId: 'balance-event', progressive: false, talentPoints: build.points, talents: build.talents, secondaryBook: build.secondaryBook });
      acquireBuild(game, build);
      if (!game.openBuildEvent() || offer?.definitionId !== definition.id) { rejections.push(`${build.id}:ineligible_event_prerequisite`); continue; }
      const choice = offer.choices.find(item => item.id === choiceId);
      if (!choice) return { kind: 'event', eventId: definition.id, choiceId, status: 'unsupported', reason: `choice_unavailable:${choiceId}` };
      const before = { hp: game.player.hp, maxHp: game.player.maxHp, relics: { ...game.relics }, grants: { ...game.buildEvents.grants } };
      if (!game.chooseEvent(offer.id, choice.id)) throw new Error(`formal_event_commit_rejected:${choice.id}`);
      const record = game.buildEvents.records.find(item => item.id === offer.id);
      if (!record) throw new Error('committed_event_record_missing');
      const after = { hp: game.player.hp, maxHp: game.player.maxHp, relics: { ...game.relics }, grants: { ...game.buildEvents.grants }, status: record.status, active: record.active, rewardDebt: game.buildEvents.rewardDebt, pressure: game.buildEvents.pressure(record.room) };
      if (after.maxHp !== before.maxHp - choice.maxHealthCost) throw new Error('max_health_cost_mismatch');
      if (choice.replacement && (after.relics[choice.replacement.from] || !after.relics[choice.replacement.to])) throw new Error('event_replacement_mismatch');
      const duplicateAccepted = game.chooseEvent(offer.id, choice.id);
      if (duplicateAccepted) throw new Error('event_idempotency_failed');
      const scene = config.scenarios.find(item => item.kind !== 'boss');
      const encounterSeed = `event-compare:${definition.id}:${build.id}:${choice.id}`;
      const beforeMetric = simulateFixed(build, scene, { healthScale: 1 }, mode, wpm, encounterSeed, config);
      const afterMetric = measureEncounter(game, scene, wpm, encounterSeed, config);
      if (beforeMetric.status !== 'ok' || afterMetric.status !== 'ok') throw new Error('event_comparison_unmeasurable');
      if (definition.kind === 'trial' && choice.id === 'rewrite') game.buildEvents.completeRoom(record.room);
      const completed = game.buildEvents.records.find(item => item.id === record.id);
      game.buildEvents.advance(record.room + 1, record.chapter);
      const nextRoom = game.buildEvents.records.find(item => item.id === record.id);
      game.buildEvents.advance(record.room + 2, record.chapter + 1);
      const nextChapter = game.buildEvents.records.find(item => item.id === record.id);
      if (choice.id === 'rewrite' && (choice.scope === 'room' && nextRoom.active || choice.scope === 'chapter' && nextChapter.active || choice.scope === 'run' && !nextChapter.active || definition.kind === 'trial' && !completed.active)) throw new Error('event_lifecycle_mismatch');
      return { kind: 'event', eventId: definition.id, choiceId, status: 'ok', book: build.book, tier: build.tier, build: build.id, mode, wpm, offer: { id: offer.id, definitionId: offer.definitionId, choices: offer.choices.map(item => item.id) }, choice, before, after, encounter: { scene: scene.id, before: { P: beforeMetric.P, R: beforeMetric.R, d: beforeMetric.d }, after: { P: afterMetric.P, R: afterMetric.R, d: afterMetric.d }, G: scenarioGain(afterMetric, beforeMetric, config), trialTiming: definition.kind === 'trial' && choice.id === 'rewrite' ? 'pressure_before_completion_reward' : 'normal' }, completed: { status: completed.status, active: completed.active }, nextRoom: { status: nextRoom.status, active: nextRoom.active }, nextChapter: { status: nextChapter.status, active: nextChapter.active }, duplicateAccepted };
    } catch (error) { return { kind: 'event', eventId: definition.id, choiceId, status: 'failed', build: build.id, reason: error.stack ?? String(error) }; }
  }
  return { kind: 'event', eventId: definition.id, choiceId, status: 'unsupported', reason: 'no_legal_sampled_build_or_event_offer', rejections: rejections.slice(0, 20), attemptedBuilds: builds.length };
}

function reachableBossStages() {
  const campaign = new CombatSimulation(builtinContent).campaign;
  const queue = [0], seen = new Set([0]), result = [];
  for (let index = 0; index < queue.length; index++) {
    const stage = queue[index], progress = campaign.at(stage);
    if (progress.room.boss) result.push({ stage, room: progress.room.id });
    for (const next of campaign.successors(stage)) if (!seen.has(next.stage)) { seen.add(next.stage); queue.push(next.stage); }
  }
  return result;
}
function simulateBossLifecycle(entry, book, tier, mode, wpm, seed, config) {
  const game = new CombatSimulation(builtinContent);
  const talents = filledTalentPlan(book, tier.points, `${book}:${tier.name}:boss`).allocated;
  game.start({ seed, book, mode, words: config.words, vocabTitle: 'Balance fixed list', vocabId: 'balance-boss', progressive: false, talentPoints: tier.points, talents });
  game.stage = entry.stage;
  game.beginRoom({ type: 'normal' });
  const boss = game.boss;
  if (!boss || boss.bossId === undefined) throw new Error(`campaign_boss_not_spawned:${entry.room}`);
  const definition = builtinContent.bosses[boss.bossId];
  if (!definition) throw new Error(`unknown_boss_definition:${boss.bossId}`);
  const phaseVisits = [{ t: 0, phase: boss.phase, hpRatio: 1 }];
  let clock = 0, actualSent = 0, elapsed = 0, deferredRewards = 0;
  const dt = 1 / 60, horizon = config.bossLifecycle.seconds;
  for (let tick = 0; tick < horizon / dt && !boss.dead && game.state !== 'result'; tick++) {
    if (game.state === 'upgrade' && game.afterUpgrade === 'play') {
      game.pending = 0;
      game.afterUpgrade = null;
      game.setState('playing');
      deferredRewards++;
    }
    if (game.state !== 'playing') break;
    operateDefense(game, true);
    if (game.resonance >= 100) game.input('Shift');
    ({ clock, actualSent } = operateTyping(game, clock, dt, wpm, Infinity, actualSent));
    game.updateVisual(dt); game.update(dt); elapsed += dt;
    if (boss.phase !== phaseVisits.at(-1).phase) phaseVisits.push({ t: toFixed(elapsed), phase: boss.phase, hpRatio: toFixed(clamp01(boss.hp / boss.maxHp)) });
  }
  const result = boss.dead ? 'boss_defeated' : game.player.hp <= 0 || game.state === 'result' && !game.lastWin ? 'player_defeated' : elapsed >= horizon ? 'timeout' : `interrupted:${game.state}`;
  return { kind: 'bossLifecycle', status: result.startsWith('interrupted') ? 'failed' : 'ok', room: entry.room, stage: entry.stage, bossId: boss.bossId, expectedPhases: definition.phases.length, phaseVisits, phasesReached: Math.max(...phaseVisits.map(item => item.phase)), result, elapsed: toFixed(elapsed), horizon, book, tier: tier.name, mode, wpm, seed, actualSent, actualManual: game.weave.summary.manualCharacters, deferredRewards, hp: toFixed(game.player.hp), bossHpRatio: toFixed(clamp01(boss.hp / boss.maxHp)), scoring: 'lifecycle_only_no_fixed_progress_score' };
}

function summarize(rows, skipped, config, metadata, partial) {
  const cases = rows.filter(row => row.kind === 'case');
  const successful = cases.filter(row => row.status === 'ok');
  const failed = cases.filter(row => row.status === 'failed');
  const unsupported = cases.filter(row => row.status === 'unsupported');
  const full = rows.filter(row => row.kind === 'fullRun');
  const failedFull = full.filter(row => row.status === 'failed');
  const events = rows.filter(row => row.kind === 'event');
  const bosses = rows.filter(row => row.kind === 'bossLifecycle');
  const failedExtra = [...events, ...bosses].filter(row => row.status === 'failed');
  const fullRunGroups = [...Map.groupBy(full, row => `${row.book}:${row.tier}:${row.mode}:${row.inputGroup}:${row.routeStrategy}`).entries()].map(([id, items]) => ({ id, samples: items.length, wins: items.filter(row => row.result === 'win').length, defeats: items.filter(row => row.result === 'defeat').length, timeouts: items.filter(row => row.result === 'timeout').length, failures: items.filter(row => row.status === 'failed').length, winRateAmongConcluded: items.filter(row => ['win', 'defeat'].includes(row.result)).length ? items.filter(row => row.result === 'win').length / items.filter(row => ['win', 'defeat'].includes(row.result)).length : null, medianElapsedOfConcluded: quantile(items.filter(row => ['win', 'defeat'].includes(row.result)).map(row => row.elapsed), .5) }));
  const byBuild = Map.groupBy(successful, row => row.build.id);
  const weights = Object.fromEntries(config.scenarios.map(scene => [scene.group, scene.weight]));
  const focused = (field, value) => !metadata.focus?.[field] || metadata.focus[field].includes(String(value));
  const expectedObservations = config.scenarios.filter(scene => scene.kind !== 'boss' && focused('scene', scene.id)).length * config.modes.filter(mode => focused('mode', mode)).length * config.seeds.filter(seed => focused('seed', seed)).length * config.inputGroups.filter(group => focused('input', group.name)).reduce((sum, group) => sum + group.wpm.filter(wpm => focused('wpm', wpm)).length, 0);
  const aggregates = [];
  for (const [id, items] of byBuild) {
    const gain = aggregateGain(items.filter(item => item.G !== null).map(item => ({ group: item.scenario.group, G: item.G })), weights);
    if (!gain) continue;
    const item = items[0], C = budget(item.build.spent, item.build.opportunities);
    const complete = items.length === expectedObservations;
    aggregates.push({ id, book: item.build.book, tier: item.build.tier, talentTarget: item.build.talentTarget, relicTarget: item.build.relicTarget, costBP: C, ...gain, globalBP: gain.BP, incrementalBP: null, efficiency: null, observations: items.length, expectedObservations, complete });
  }
  const bookBases = new Map(aggregates.filter(item => item.complete && item.id === `${item.book}:${item.tier}:base`).map(item => [`${item.book}:${item.tier}`, item]));
  for (const item of aggregates) {
    const base = bookBases.get(`${item.book}:${item.tier}`);
    if (!item.complete || !base) continue;
    item.incrementalBP = item.globalBP - base.globalBP;
    if (item.costBP > 0) item.efficiency = item.incrementalBP / item.costBP;
  }
  const p = successful.map(item => item.P), risks = successful.map(item => item.R), efficiencies = aggregates.map(item => item.efficiency).filter(Number.isFinite);
  const coverage = { relics: {}, talents: {}, events: {} };
  for (const relic of builtinContent.relics) coverage.relics[relic.id] = { cases: 0, skipped: skipped.filter(item => item.type === 'relic' && item.id === relic.id).map(item => item.reason) };
  for (const talent of builtinContent.talents) coverage.talents[talent.id] = { cases: 0, skipped: skipped.filter(item => item.type === 'talent' && item.id === talent.id).map(item => item.reason) };
  for (const event of builtinContent.buildEvents ?? []) coverage.events[event.id] = { cases: 0, choices: [], unsupported: [] };
  for (const row of events) if (coverage.events[row.eventId]) {
    if (row.status === 'ok') { coverage.events[row.eventId].cases++; coverage.events[row.eventId].choices.push(row.choiceId); }
    else coverage.events[row.eventId].unsupported.push(`${row.choiceId}:${row.reason}`);
  }
  for (const row of events.filter(item => item.status === 'ok')) for (const id of Object.keys(row.after.relics)) if (coverage.relics[id] && !row.before.relics[id]) coverage.relics[id].cases++;
  for (const item of successful) {
    for (const id of item.build.relics) if (coverage.relics[id]) coverage.relics[id].cases++;
    for (const id of item.build.talents) if (coverage.talents[id]) coverage.talents[id].cases++;
  }
  const worst = [...successful].sort((a, b) => a.G - b.G).slice(0, 12).map(item => ({ build: item.build.id, scenario: item.scenario.id, mode: item.mode, wpm: item.wpm, seed: item.seed, G: item.G, P: item.P, R: item.R, d: item.d }));
  const saturation = config.scenarios.map(scene => {
    const items = successful.filter(row => row.scenario.id === scene.id);
    const fraction = items.length ? items.filter(row => row.cleared && row.clearTime / scene.seconds < 1 - config.saturationThreshold).length / items.length : null;
    return { id: scene.id, samples: items.length, earlyClearFraction: fraction, flagged: fraction !== null && fraction >= config.saturationThreshold };
  });
  const groupMetrics = [...Map.groupBy(successful, item => `${item.build.tier}:${item.mode}:${item.inputGroup}:${item.scenario.group}`).entries()].map(([id, items]) => ({ id, samples: items.length, P50: quantile(items.map(item => item.P), .5), P95: quantile(items.map(item => item.P), .95), R50: quantile(items.map(item => item.R), .5), R95: quantile(items.map(item => item.R), .95), deathRate: items.reduce((sum, item) => sum + item.d, 0) / items.length, clearRate: items.filter(item => item.cleared).length / items.length }));
  const dominance = [];
  const sameBudget = Map.groupBy(aggregates.filter(item => item.complete && item.costBP > 0), item => `${item.tier}:${item.costBP}`);
  for (const group of sameBudget.values()) for (let i = 0; i < Math.min(group.length, 60); i++) for (let j = i + 1; j < Math.min(group.length, 60); j++) {
    const left = byBuild.get(group[i].id), right = byBuild.get(group[j].id);
    const byPair = new Map(right.map(item => [`${item.scenario.id}:${item.mode}:${item.wpm}:${item.seed}`, item]));
    const pairs = left.map(item => [item, byPair.get(`${item.scenario.id}:${item.mode}:${item.wpm}:${item.seed}`)]).filter(pair => pair[1]);
    if (pairs.length < 4) continue;
    if (dominates(pairs.map(pair => pair[0]), pairs.map(pair => pair[1]))) dominance.push({ stronger: group[i].id, weaker: group[j].id, paired: pairs.length });
    else if (dominates(pairs.map(pair => pair[1]), pairs.map(pair => pair[0]))) dominance.push({ stronger: group[j].id, weaker: group[i].id, paired: pairs.length });
  }
  const byAggregate = new Map(aggregates.filter(item => item.complete).map(item => [item.id, item]));
  const interactionCandidates = [];
  for (const combo of aggregates.filter(item => item.complete && item.id.includes(':combo:'))) {
    const [talentId, relicId] = combo.id.split(':combo:')[1].split(':');
    const prefix = `${combo.book}:${combo.tier}`;
    const talent = byAggregate.get(`${prefix}:talent:${talentId}`), relic = byAggregate.get(`${prefix}:relic:${relicId}`), base = byAggregate.get(`${prefix}:base`);
    if (talent && relic && base) interactionCandidates.push({ combo: combo.id, I: combo.BP - talent.BP - relic.BP + base.BP, paidBudget: combo.costBP, observations: combo.observations });
  }
  interactionCandidates.sort((a, b) => Math.abs(b.I) - Math.abs(a.I));
  return { metadata, status: partial ? 'partial' : failed.length || failedFull.length || failedExtra.length ? 'failed' : unsupported.length || skipped.length || events.some(item => item.status === 'unsupported') || bosses.some(item => item.status === 'unsupported') || Object.values(coverage.relics).some(item => !item.cases) || Object.values(coverage.events).some(item => !item.cases) ? 'incomplete' : 'measured', note: 'Diagnostic measurement; no automatic balanced verdict.', counts: { cases: cases.length, successful: successful.length, failed: failed.length, unsupported: unsupported.length, skipped: skipped.length, fullRuns: full.length, failedFullRuns: failedFull.length, events: events.length, failedEvents: events.filter(item => item.status === 'failed').length, unsupportedEvents: events.filter(item => item.status === 'unsupported').length, bosses: bosses.length, failedBosses: bosses.filter(item => item.status === 'failed').length }, p50: { P: quantile(p, .5), R: quantile(risks, .5), efficiency: quantile(efficiencies, .5) }, p95: { P: quantile(p, .95), R: quantile(risks, .95), efficiency: quantile(efficiencies, .95) }, deathRate: successful.length ? successful.reduce((sum, item) => sum + item.d, 0) / successful.length : null, clearRate: successful.length ? successful.filter(item => item.cleared).length / successful.length : null, coverage, skipped, failed: [...failed.map(item => ({ build: item.build.id, scenario: item.scenario.id, reason: item.reason })), ...failedExtra.map(item => ({ kind: item.kind, id: item.eventId ?? item.room, reason: item.reason }))], unsupported: [...unsupported.map(item => ({ build: item.build.id, scenario: item.scenario.id, reason: item.reason })), ...events.filter(item => item.status === 'unsupported').map(item => ({ kind: 'event', id: item.eventId, choice: item.choiceId, reason: item.reason }))], worst, groupMetrics, saturation, dominance: dominance.slice(0, 60), interactionCandidates: interactionCandidates.slice(0, 40), aggregates, bossLifecycleSummary: { samples: bosses.length, reachedFinalPhase: bosses.filter(item => item.status === 'ok' && item.phasesReached >= item.expectedPhases).length, bossDefeats: bosses.filter(item => item.result === 'boss_defeated').length, playerDefeats: bosses.filter(item => item.result === 'player_defeated').length, timeouts: bosses.filter(item => item.result === 'timeout').length, groups: [...Map.groupBy(bosses, item => `${item.room}:${item.mode}:${item.wpm}`).entries()].map(([id, items]) => ({ id, samples: items.length, finalPhaseRate: items.length ? items.filter(item => item.status === 'ok' && item.phasesReached >= item.expectedPhases).length / items.length : null })) }, fullRunSummary: { wins: full.filter(item => item.result === 'win').length, defeats: full.filter(item => item.result === 'defeat').length, timeouts: full.filter(item => item.result === 'timeout').length, failed: failedFull.length, samples: full.length, groups: fullRunGroups, status: partial || !full.length ? 'not_measured' : failedFull.length ? 'failed' : full.some(item => item.result === 'timeout') ? 'measured_with_censoring' : 'measured' } };
}
function reportMarkdown(summary) {
  const { counts, p50, p95 } = summary;
  return `# 完整内容通用数值评估\n\n状态：**${summary.status}**。这是诊断报告，不作“已平衡”结论。\n\n- 案例：${counts.cases}；成功 ${counts.successful}；失败 ${counts.failed}；不支持 ${counts.unsupported}；采样跳过 ${counts.skipped}。事件交易 ${counts.events}（失败 ${counts.failedEvents}，未支持 ${counts.unsupportedEvents}）；Boss 生命周期 ${counts.bosses}（失败 ${counts.failedBosses}）；完整局 ${counts.fullRuns}。\n- P p50/p95：${p50.P ?? '无'}/${p95.P ?? '无'}；R p50/p95：${p50.R ?? '无'}/${p95.R ?? '无'}；效率 p50/p95：${p50.efficiency ?? '无'}/${p95.efficiency ?? '无'}。\n- 死亡率：${summary.deathRate ?? '无'}；清房率：${summary.clearRate ?? '无'}。\n- 同预算支配候选 ${summary.dominance.length}；高效率/交互审查候选 ${summary.interactionCandidates.length}；饱和场景 ${summary.saturation.filter(item => item.flagged).length}。\n\n## 最差组\n\n${summary.worst.map(item => `- ${item.build} / ${item.scenario} / ${item.mode} / ${item.wpm} WPM / ${item.seed}: G=${toFixed(item.G)}, P=${toFixed(item.P)}, R=${toFixed(item.R)}, 死亡=${item.d}`).join('\n') || '无可比较组'}\n\n## 覆盖与限制\n\n- 未覆盖遗物：${Object.entries(summary.coverage.relics).filter(([, value]) => !value.cases).map(([id]) => id).join('、') || '无'}。\n- 未覆盖天赋：${Object.entries(summary.coverage.talents).filter(([, value]) => !value.cases).map(([id]) => id).join('、') || '无'}。\n- 未覆盖事件：${Object.entries(summary.coverage.events).filter(([, value]) => !value.cases).map(([id]) => id).join('、') || '无'}。\n- Boss 仅用真实战役房与阶段生命周期作诊断；固定 P 场景未定义精确阶段目标，逐案 unsupported。阶段最终相位 ${summary.bossLifecycleSummary.reachedFinalPhase}/${summary.bossLifecycleSummary.samples}，Boss 击败 ${summary.bossLifecycleSummary.bossDefeats}，玩家死亡 ${summary.bossLifecycleSummary.playerDefeats}，截断 ${summary.bossLifecycleSummary.timeouts}。\n- 固定场景 healthScale 仅放大独立目标耐久，不作用于玩家、正式难度或完整局。\n- 完整局：胜利 ${summary.fullRunSummary.wins}、死亡失败 ${summary.fullRunSummary.defeats}、时间上限 ${summary.fullRunSummary.timeouts}、执行失败 ${summary.fullRunSummary.failed}。截断不计死亡或通关；按书/点数/难度/输入组/获得路线分组见 summary.json。\n- 配置 hash：${summary.metadata.configHash}；内容 hash：${summary.metadata.contentHash}。\n- 命令：\`${summary.metadata.command}\`；Node ${summary.metadata.node}，${summary.metadata.platform}。\n\n详见 summary.json 与逐案 cases.jsonl；--limit 结果明确为 partial。\n`;
}

async function mergeFixedReports(options, config, metadata, builds, skipped) {
  const rows = [], shards = new Set();
  let expectedTotal = null, focused = null;
  for (const path of options.merge) {
    const source = JSON.parse(await readFile(resolve(path, 'summary.json'), 'utf8'));
    const sourceMeta = source.metadata;
    if (sourceMeta.phase !== 'fixed' || sourceMeta.configHash !== metadata.configHash || sourceMeta.contentHash !== metadata.contentHash || sourceMeta.plannedBuilds !== builds.length || !sourceMeta.shard || sourceMeta.limit !== null) throw new Error(`Incompatible fixed shard: ${path}`);
    if (expectedTotal === null) { expectedTotal = sourceMeta.shard.total; focused = sourceMeta.focus; }
    if (sourceMeta.shard.total !== expectedTotal || JSON.stringify(sourceMeta.focus) !== JSON.stringify(focused) || shards.has(sourceMeta.shard.index)) throw new Error(`Duplicate or mismatched fixed shard: ${path}`);
    shards.add(sourceMeta.shard.index);
    for (const line of (await readFile(resolve(path, 'cases.jsonl'), 'utf8')).split('\n')) if (line) rows.push(JSON.parse(line));
  }
  if (shards.size !== expectedTotal || [...Array(expectedTotal).keys()].some(index => !shards.has(index))) throw new Error('Missing fixed shard');
  const cases = rows.filter(row => row.kind === 'case');
  const focusedMatch = (field, value) => !focused?.[field] || focused[field].includes(String(value));
  const planned = builds.filter(build => focusedMatch('book', build.book) && focusedMatch('tier', build.tier)).length * config.scenarios.filter(scene => focusedMatch('scene', scene.id)).length * config.modes.filter(mode => focusedMatch('mode', mode)).length * config.seeds.filter(seed => focusedMatch('seed', seed)).length * config.inputGroups.filter(group => focusedMatch('input', group.name)).reduce((sum, group) => sum + group.wpm.filter(wpm => focusedMatch('wpm', wpm)).length, 0);
  const keys = new Set(cases.map(row => `${row.build.id}:${row.scenario.id}:${row.mode}:${row.wpm}:${row.seed}`));
  if (cases.length !== planned || keys.size !== planned) throw new Error(`Incomplete or duplicate fixed matrix: ${cases.length} rows, ${keys.size} unique, ${planned} planned`);
  metadata.phase = 'fixed-merged'; metadata.focus = focused; metadata.mergeSources = options.merge; metadata.plannedBuilds = builds.length; metadata.scheduledCases = cases.length; metadata.selectedCases = cases.length; metadata.finishedAt = new Date().toISOString();
  const summary = summarize(rows, skipped, config, metadata, true);
  await writeFile(resolve(options.out, 'summary.json'), `${JSON.stringify(summary, null, 2)}\n`);
  await writeFile(resolve(options.out, 'report.md'), reportMarkdown(summary));
  await writeFile(resolve(options.out, 'cases.jsonl'), `${rows.map(row => JSON.stringify(row)).join('\n')}\n`);
  process.stdout.write(`Balance diagnostic ${summary.status}: ${cases.length} merged fixed cases; ${options.out}\n`);
  if (summary.counts.failed) process.exitCode = 1;
}

async function main() {
  const options = argumentsOf(process.argv.slice(2));
  const raw = await readFile(options.config, 'utf8'), config = JSON.parse(raw);
  validateConfig(config);
  const metadata = { version: 1, command: process.argv.map(value => JSON.stringify(value)).join(' '), config: options.config, out: options.out, configHash: sha(raw), contentHash: sha({ books: builtinContent.books, modes: builtinContent.modes, relics: builtinContent.relics, talents: builtinContent.talents, events: builtinContent.buildEvents, enemies: builtinContent.enemies, bosses: builtinContent.bosses, chapters: builtinContent.chapters, routes: builtinContent.routes }), node: process.version, platform: `${process.platform}/${process.arch}`, osRelease: release(), cpu: cpus()[0]?.model ?? 'unknown', cpuCount: cpus().length, memoryBytes: totalmem(), startedAt: new Date().toISOString() };
  await mkdir(options.out, { recursive: true });
  const skipped = [], builds = sampleBuilds(config, skipped), rows = [], refs = new Map();
  if (options.merge) return mergeFixedReports(options, config, metadata, builds, skipped);
  const stream = createWriteStream(resolve(options.out, 'cases.jsonl'), { encoding: 'utf8' });
  const write = row => { rows.push(row); stream.write(`${JSON.stringify(row)}\n`); };
  const matches = (field, value) => !options.focus[field] || options.focus[field].includes(String(value));
  let scheduled = 0, selected = 0, partial = options.phase === 'fixed' || Boolean(options.shard) || Object.keys(options.focus).length > 0;
  if (options.phase === 'all' || options.phase === 'fixed') outer: for (const build of builds) for (const tier of config.tiers.filter(item => item.name === build.tier)) for (const mode of config.modes) for (const group of config.inputGroups) for (const wpm of group.wpm) for (const seed of config.seeds) for (const scene of config.scenarios) {
    if (!matches('book', build.book) || !matches('tier', tier.name) || !matches('mode', mode) || !matches('input', group.name) || !matches('wpm', wpm) || !matches('seed', seed) || !matches('scene', scene.id)) continue;
    if (options.shard && scheduled++ % options.shard.total !== options.shard.index) continue;
    if (selected >= options.limit) { partial = true; break outer; }
    if (!options.shard) scheduled++;
    selected++;
    const referenceKey = `${tier.name}:${mode}:${wpm}:${seed}:${scene.id}`;
    if (!refs.has(referenceKey)) {
      const reference = { id: `reference:${config.books[0]}:${tier.name}`, book: config.books[0], tier: tier.name, points: tier.points, talents: [], relics: [], spent: 0, opportunities: 0 };
      let result;
      try { result = simulateFixed(reference, scene, tier, mode, wpm, seed, config); }
      catch (error) { result = { status: 'failed', reason: error.stack ?? String(error) }; }
      refs.set(referenceKey, result);
      write({ kind: 'reference', build: reference, scenario: { id: scene.id, group: scene.group }, mode, wpm, inputGroup: group.name, seed, ...result });
    }
    let result;
    try { result = simulateFixed(build, scene, tier, mode, wpm, seed, config); }
    catch (error) { result = { status: 'failed', reason: error.stack ?? String(error) }; }
    const reference = refs.get(referenceKey);
    const referenceMismatch = reference.status === 'ok' && reference.P < .0001;
    if (result.status === 'ok' && reference.status !== 'ok') result = { ...result, status: reference.status, reason: `reference_${reference.status}:${reference.reason}` };
    if (result.status === 'ok' && referenceMismatch) result = { ...result, status: 'unsupported', reason: 'reference_progress_near_zero' };
    const G = result.status === 'ok' ? scenarioGain(result, reference, config) : null;
    const survivalSensitivity = result.status === 'ok' ? { lambdaHalf: scenarioGain(result, reference, { ...config, lambda: config.lambda * .5 }), lambdaOneHalf: scenarioGain(result, reference, { ...config, lambda: config.lambda * 1.5 }) } : null;
    write({ kind: 'case', build, scenario: { id: scene.id, group: scene.group, seconds: scene.seconds, characters: scene.characters }, mode, wpm, inputGroup: group.name, seed, ...result, G, survivalSensitivity, referenceMismatch, referenceStatus: reference.status });
  }
  if ((options.phase === 'all' && !partial || options.phase === 'extras')) for (const definition of builtinContent.buildEvents ?? []) for (const choiceId of ['rewrite', 'annotate', 'leave']) write(simulateEvent(definition, choiceId, builds, config));
  if ((options.phase === 'all' && !partial || options.phase === 'extras') && config.bossLifecycle) {
    const tier = config.tiers.find(item => item.name === config.bossLifecycle.tier);
    for (const entry of reachableBossStages()) for (const book of config.books) for (const mode of config.bossLifecycle.modes) for (const wpm of config.bossLifecycle.wpm) for (const seed of config.seeds) {
      let result;
      try { result = simulateBossLifecycle(entry, book, tier, mode, wpm, seed, config); }
      catch (error) { result = { kind: 'bossLifecycle', room: entry.room, stage: entry.stage, book, tier: tier.name, mode, wpm, seed, status: 'failed', reason: error.stack ?? String(error) }; }
      write(result);
    }
  }
  if (config.fullRun?.enabled && (options.phase === 'all' && !partial || options.phase === 'full')) for (const book of config.books) for (const tier of config.tiers.filter(item => config.fullRun.tiers.includes(item.name))) for (const routeStrategy of config.fullRun.routes) for (const mode of config.modes) for (const group of config.inputGroups) for (const wpm of group.wpm) for (const seed of config.seeds) {
    if (!matches('book', book) || !matches('tier', tier.name) || !matches('route', routeStrategy) || !matches('mode', mode) || !matches('input', group.name) || !matches('wpm', wpm) || !matches('seed', seed)) continue;
    let result;
    try { result = simulateFullRun(book, tier, routeStrategy, mode, wpm, seed, config); }
    catch (error) { result = { kind: 'fullRun', book, tier: tier.name, routeStrategy, mode, wpm, seed, status: 'failed', reason: error.stack ?? String(error) }; }
    write({ inputGroup: group.name, ...result });
  }
  stream.end(); await once(stream, 'finish');
  metadata.finishedAt = new Date().toISOString(); metadata.plannedBuilds = builds.length; metadata.scheduledCases = scheduled; metadata.selectedCases = selected; metadata.limit = Number.isFinite(options.limit) ? options.limit : null; metadata.phase = options.phase; metadata.shard = options.shard; metadata.focus = options.focus;
  const summary = summarize(rows, skipped, config, metadata, partial);
  await writeFile(resolve(options.out, 'summary.json'), `${JSON.stringify(summary, null, 2)}\n`);
  await writeFile(resolve(options.out, 'report.md'), reportMarkdown(summary));
  process.stdout.write(`Balance diagnostic ${summary.status}: ${scheduled} scheduled cases; ${options.out}\n`);
  if (summary.counts.failed || summary.counts.failedFullRuns || summary.counts.failedEvents || summary.counts.failedBosses) process.exitCode = 1;
}
main().catch(error => { process.stderr.write(`${error.stack ?? error}\n`); process.exitCode = 1; });
