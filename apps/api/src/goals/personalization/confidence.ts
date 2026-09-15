import type { DataQualityResult, ConfidenceResult } from './types';

export const HIGH_CONFIDENCE_SCORE = 0.6;
export const MEDIUM_CONFIDENCE_SCORE = 0.35;

export function calculateConfidence(
  dataQuality: DataQualityResult,
): ConfidenceResult {
  const reasons: string[] = [];

  if (dataQuality.trackedDays < 7) {
    reasons.push('few_tracked_days');
  }
  if (dataQuality.weightLogsCount >= 2) {
    reasons.push('weight_trend_available');
  }
  if (dataQuality.activityDays >= 5) {
    reasons.push('activity_data_rich');
  }
  if (dataQuality.sleepNights >= 5) {
    reasons.push('sleep_data_rich');
  }

  let level: ConfidenceResult['level'];
  if (dataQuality.score >= HIGH_CONFIDENCE_SCORE) {
    level = 'high';
  } else if (dataQuality.score >= MEDIUM_CONFIDENCE_SCORE) {
    level = 'medium';
  } else {
    level = 'low';
  }

  if (level !== 'high') {
    reasons.push('limited_data');
  }

  return {
    level,
    score: dataQuality.score,
    reasons,
  };
}
