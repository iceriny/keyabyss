const test = require('node:test');
const assert = require('node:assert/strict');
const {
  trajectoryMetrics, scenarioGain, aggregateGain, budget, dominates,
} = require('../tools/balance-model.mjs');

const close = (actual, expected) => assert.ok(Math.abs(actual - expected) < 1e-12, `${actual} != ${expected}`);

test('constant and linear trajectories have hand-computed progress and risk integrals', () => {
  const constant = trajectoryMetrics([
    { t: 0, progress: .4, risk: .2 },
    { t: 10, progress: .4, risk: .2 },
  ], 10, 20);
  close(constant.progressIntegral, 4);
  close(constant.riskIntegral, 2);
  close(constant.P, 2);
  close(constant.meanRisk, .2);
  close(constant.peakRisk, .2);
  close(constant.R, .2);

  const linear = trajectoryMetrics([
    { t: 0, progress: 0, risk: 0 },
    { t: 10, progress: 1, risk: 1 },
  ], 10, 20);
  close(linear.progressIntegral, 5);
  close(linear.riskIntegral, 5);
  close(linear.P, 2.5);
  close(linear.meanRisk, .5);
  close(linear.peakRisk, 1);
  close(linear.R, .75);

  const oneSample = trajectoryMetrics([{ t: 0, progress: .4, risk: .2 }], 10, 20);
  close(oneSample.P, 2);
  close(oneSample.meanRisk, .2);
  close(oneSample.peakRisk, .2);
  close(oneSample.R, .2);
});

test('death stops progress while the remainder of the horizon has full risk', () => {
  const result = trajectoryMetrics([
    { t: 0, progress: 0, risk: .1 },
    { t: 4, progress: .5, risk: 1, terminal: 'dead' },
  ], 10, 10);
  close(result.progressIntegral, 1);
  close(result.P, 1);
  close(result.riskIntegral, 8.2);
  close(result.meanRisk, .82);
  close(result.peakRisk, 1);
  close(result.R, .91);
  assert.equal(result.d, 1);
});

test('clear freezes earned progress and health risk until the common horizon', () => {
  const result = trajectoryMetrics([
    { t: 0, progress: 0, risk: 0 },
    { t: 4, progress: 1, risk: .4, terminal: 'cleared' },
  ], 10, 10);
  close(result.progressIntegral, 8);
  close(result.P, 8);
  close(result.riskIntegral, 3.2);
  close(result.meanRisk, .32);
  close(result.peakRisk, .4);
  close(result.R, .36);
  assert.equal(result.d, 0);
});

test('same build has zero gain; survival weights and death penalty use the stated units', () => {
  const reference = { P: 2, R: .2, d: 0 };
  close(scenarioGain(reference, reference), 0);
  close(scenarioGain({ P: 2, R: .1, d: 0 }, reference), .1);
  close(scenarioGain({ P: 2, R: .1, d: 0 }, reference, { lambda: 2 }), .2);
  close(scenarioGain({ P: 2, R: .2, d: 1 }, reference), -Math.log(4));
  close(scenarioGain({ P: 4, R: .1, d: 1 }, reference), Math.log(4.02 / 2.02) + .1 - Math.log(4));
  assert.deepEqual(aggregateGain([{ group: 'same', G: 0 }], { same: 1 }), { G: 0, U: 1, BP: 0 });
  const weighted = aggregateGain([
    { group: 'common', G: Math.log(2) },
    { group: 'rare', G: -Math.log(2) },
  ], { common: 3, rare: 1 });
  close(weighted.G, Math.log(2) / 2);
  close(weighted.U, Math.sqrt(2));
  close(weighted.BP, 50 * Math.log(2));
});

test('same-budget dominance requires no worse progress or survival and one strict advantage', () => {
  assert.equal(budget(2, 1), 14);
  assert.equal(budget(0, 2), 16);
  const reference = [{ P: 2, R: .2 }, { P: 2, R: .3 }];
  assert.equal(dominates([{ P: 3, R: .2 }, { P: 2, R: .3 }], reference), true);
  assert.equal(dominates([{ P: 2, R: .1 }, { P: 2, R: .3 }], reference), true);
  assert.equal(dominates(reference, reference), false);
  assert.equal(dominates([{ P: 3, R: .21 }, { P: 2, R: .3 }], reference), false);
  assert.equal(dominates([{ P: 1.9, R: .1 }, { P: 2, R: .3 }], reference), false);
  assert.equal(dominates([reference[0]], reference), false);
});

test('non-monotone trajectory sample times are rejected', () => {
  assert.throws(() => trajectoryMetrics([
    { t: 0, progress: 0, risk: 0 },
    { t: 5, progress: .3, risk: .2 },
    { t: 4, progress: .4, risk: .3 },
  ], 10, 20), /Non-monotone trajectory/);
});
