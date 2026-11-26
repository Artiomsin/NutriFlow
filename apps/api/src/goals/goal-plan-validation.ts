import { validationProblem } from '../common/http/problem-details';
import { FieldErrorCode } from '../common/validation/field-errors';

export interface GoalPlanValidationInput {
  weight: number | null;
  goal: 'lose' | 'gain' | 'maintain' | null;
  targetWeightKg: number | null;
  targetWeightMinKg?: number | null;
  targetWeightMaxKg?: number | null;
  weeklyRateKg: number | null;
  targetDate: string | null;
  goalStartedAt: Date | string | null;
}

/**
 * Shared validation for every path that changes the user's plan: profile
 * creation/update, new cycle and applying a personalization recommendation.
 */
export function validateGoalPlanFields(input: GoalPlanValidationInput): void {
  const {
    weight,
    goal,
    targetWeightKg,
    targetWeightMinKg = null,
    targetWeightMaxKg = null,
    weeklyRateKg,
    targetDate,
  } = input;
  if (weeklyRateKg != null && weeklyRateKg <= 0) {
    throw validationProblem([
      {
        field: 'weeklyRateKg',
        code: FieldErrorCode.weeklyRateMustBePositive,
      },
    ]);
  }
  if (targetDate != null) {
    const today = new Date().toISOString().slice(0, 10);
    if (targetDate < today) {
      throw validationProblem([
        { field: 'targetDate', code: FieldErrorCode.targetDateInPast },
      ]);
    }
  }
  if (targetDate != null && targetWeightKg == null && goal !== 'maintain') {
    throw validationProblem([
      {
        field: 'targetWeightKg',
        code: FieldErrorCode.targetWeightRequiredForDate,
      },
    ]);
  }
  if (
    goal === 'lose' &&
    targetWeightKg != null &&
    weight != null &&
    targetWeightKg >= weight
  ) {
    throw validationProblem([
      {
        field: 'targetWeightKg',
        code: FieldErrorCode.targetWeightMustBeLowerThanCurrent,
      },
    ]);
  }
  if (
    goal === 'gain' &&
    targetWeightKg != null &&
    weight != null &&
    targetWeightKg <= weight
  ) {
    throw validationProblem([
      {
        field: 'targetWeightKg',
        code: FieldErrorCode.targetWeightMustBeHigherThanCurrent,
      },
    ]);
  }

  const hasMin = targetWeightMinKg != null;
  const hasMax = targetWeightMaxKg != null;
  if (hasMin !== hasMax) {
    throw validationProblem([
      {
        field: hasMin ? 'targetWeightMaxKg' : 'targetWeightMinKg',
        code: FieldErrorCode.maintainRangePairRequired,
      },
    ]);
  }
  if (hasMin && hasMax) {
    if (targetWeightMinKg! >= targetWeightMaxKg!) {
      throw validationProblem([
        {
          field: 'targetWeightMaxKg',
          code: FieldErrorCode.maintainRangeOrderInvalid,
        },
      ]);
    }
    const width = targetWeightMaxKg! - targetWeightMinKg!;
    if (width < 0.5 || width > 10) {
      throw validationProblem([
        {
          field: 'targetWeightMaxKg',
          code: FieldErrorCode.maintainRangeWidthOutOfRange,
        },
      ]);
    }
  }

  if (goal === 'maintain') {
    if (hasMin && hasMax) {
      if (weight != null) {
        if (
          targetWeightMaxKg! < weight - 15 ||
          targetWeightMinKg! > weight + 15
        ) {
          throw validationProblem([
            {
              field: 'targetWeightMinKg',
              code: FieldErrorCode.maintainRangeTooFarFromCurrent,
            },
          ]);
        }
      }
      if (targetWeightKg != null) {
        if (
          targetWeightKg < targetWeightMinKg! ||
          targetWeightKg > targetWeightMaxKg!
        ) {
          throw validationProblem([
            {
              field: 'targetWeightKg',
              code: FieldErrorCode.targetWeightOutsideMaintainRange,
            },
          ]);
        }
      }
    } else if (targetWeightKg != null && weight != null) {
      if (Math.abs(targetWeightKg - weight) > 10) {
        throw validationProblem([
          {
            field: 'targetWeightKg',
            code: FieldErrorCode.targetWeightTooFarFromCurrent,
          },
        ]);
      }
    }
  } else if (hasMin || hasMax) {
    throw validationProblem([
      {
        field: 'targetWeightMinKg',
        code: FieldErrorCode.maintainRangeNotAllowed,
      },
    ]);
  }

  if (targetDate != null && input.goalStartedAt != null) {
    const started =
      input.goalStartedAt instanceof Date
        ? input.goalStartedAt.toISOString().slice(0, 10)
        : String(input.goalStartedAt).slice(0, 10);
    if (targetDate <= started) {
      throw validationProblem([
        {
          field: 'targetDate',
          code: FieldErrorCode.targetDateMustBeAfterGoalStart,
        },
      ]);
    }
  }
}
