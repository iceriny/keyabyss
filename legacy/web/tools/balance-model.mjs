export const clamp01 = value => Math.max(0, Math.min(1, value));

/** Fixed-budget time integrals; death contributes no further progress and full risk. */
export function trajectoryMetrics(samples, horizon, characters) {
  if (!(horizon > 0) || !(characters > 0) || !samples.length) throw new Error('Invalid trajectory horizon or character budget');
  let progressIntegral = 0, riskIntegral = 0, peakRisk = samples[0].risk;
  for (let index = 1; index < samples.length; index++) {
    const before = samples[index - 1], after = samples[index];
    const dt = after.t - before.t;
    if (!(dt >= 0)) throw new Error('Non-monotone trajectory');
    progressIntegral += dt * (before.progress + after.progress) / 2;
    riskIntegral += dt * (before.risk + after.risk) / 2;
    peakRisk = Math.max(peakRisk, before.risk, after.risk);
  }
  const tail = horizon - samples.at(-1).t;
  if (tail < -1e-6) throw new Error('Trajectory exceeds horizon');
  const last = samples.at(-1);
  if (tail > 0) {
    if (last.terminal === 'cleared') progressIntegral += tail * last.progress;
    else if (last.terminal !== 'dead') progressIntegral += tail * last.progress;
    riskIntegral += tail * (last.terminal === 'dead' ? 1 : last.risk);
    if (last.terminal === 'dead') peakRisk = 1;
  }
  const P = 100 * progressIntegral / (characters * horizon);
  const meanRisk = riskIntegral / horizon;
  const R = .5 * meanRisk + .5 * peakRisk;
  return { P, R, meanRisk, peakRisk, d: last.terminal === 'dead' ? 1 : 0, progressIntegral, riskIntegral };
}

export function scenarioGain(value, reference, { lambda = 1, kappa = Math.log(4) } = {}) {
  if (!value || !reference || !Number.isFinite(value.P) || !Number.isFinite(reference.P)) return null;
  const epsilon = Math.max(.01 * reference.P, .000001);
  return Math.log((epsilon + value.P) / (epsilon + reference.P)) - lambda * (value.R - reference.R) - kappa * (value.d - reference.d);
}

export function aggregateGain(paired, weights) {
  const denominator = paired.reduce((sum, item) => sum + (weights[item.group] ?? 0), 0);
  if (!(denominator > 0)) return null;
  const G = paired.reduce((sum, item) => sum + item.G * (weights[item.group] ?? 0), 0) / denominator;
  return { G, U: Math.exp(G), BP: 100 * G };
}

export function budget(spentTalentPoints, rewardOpportunities) {
  return 3 * spentTalentPoints + 8 * rewardOpportunities;
}

export function quantile(values, fraction) {
  if (!values.length) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const position = (sorted.length - 1) * fraction;
  const lower = Math.floor(position), upper = Math.ceil(position);
  return sorted[lower] + (sorted[upper] - sorted[lower]) * (position - lower);
}

export function dominates(left, right, slack = .000001) {
  if (!left.length || left.length !== right.length) return false;
  let strict = false;
  for (let index = 0; index < left.length; index++) {
    if (left[index].P + slack < right[index].P || left[index].R > right[index].R + slack) return false;
    if (left[index].P > right[index].P + slack || left[index].R + slack < right[index].R) strict = true;
  }
  return strict;
}
