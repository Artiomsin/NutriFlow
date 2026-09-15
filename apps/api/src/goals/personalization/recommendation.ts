import type { AnalysisInput, Recommendation } from './types';
import { evaluateDataQuality } from './dataQuality';
import { calculateBaseline } from './baseline';
import { calculateAdherence } from './adherence';
import { analyzeOutcome } from './outcome';
import { analyzeCrossDomain } from './crossDomain';
import { calculateConfidence } from './confidence';
import { applyAdjustmentRules } from './rules';

export function generateRecommendation(
  input: AnalysisInput,
): Recommendation | null {
  const dataQuality = evaluateDataQuality(input);
  if (!dataQuality.isEnough) {
    return null;
  }

  const baseline = calculateBaseline(input);
  const adherence = calculateAdherence(input, baseline);
  const outcome = analyzeOutcome(
    input.profile.goal,
    baseline.weightTrendKgPerWeek,
  );
  const crossDomain = analyzeCrossDomain(input, adherence);
  const confidence = calculateConfidence(dataQuality);

  const ruleResult = applyAdjustmentRules({
    input,
    baseline,
    adherence,
    outcome,
    crossDomain,
    dataQuality,
    confidence: confidence.level,
  });

  const hasChanges = Object.values(ruleResult.domainChanges).some(Boolean);
  if (!hasChanges) {
    return null;
  }

  return {
    previousGoals: { ...input.currentGoals },
    recommendedGoals: { ...ruleResult.recommendedGoals },
    analysisPeriodStart: input.periodStart,
    analysisPeriodEnd: input.periodEnd,
    reasons: ruleResult.reasons,
    confidence: {
      level: confidence.level,
      dataQualityScore: dataQuality.score,
      trackedDays: dataQuality.trackedDays,
      weightLogsCount: dataQuality.weightLogsCount,
      activityDays: dataQuality.activityDays,
      workoutCount: dataQuality.workoutCount,
      sleepNights: dataQuality.sleepNights,
      adherenceStepsPct: adherence.stepsPct,
      weightTrendKgPerWeek: baseline.weightTrendKgPerWeek,
    },
    domainChanges: ruleResult.domainChanges,
  };
}
