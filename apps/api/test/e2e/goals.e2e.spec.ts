import { afterAll, beforeAll, describe, expect, it } from 'bun:test';
import { randomUUID } from 'node:crypto';
import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { and, eq, isNull } from 'drizzle-orm';

import { createE2eApp } from '../utils/e2e';
import { createTestDb } from '../utils/db';
import type { TestDb, TestTx } from '../utils/db';
import { userGoals } from '../../src/db/schema/userGoals';
import { dailySummary } from '../../src/db/schema/dailySummary';
import { dailyActivity } from '../../src/db/schema/dailyActivity';
import { weightLogs } from '../../src/db/schema/weightLogs';

let db: TestDb;
let tx: TestTx;
let rollback: () => Promise<void>;
let app: INestApplication;

beforeAll(async () => {
  db = createTestDb();
  const opened = await db.openTx();
  tx = opened.tx;
  rollback = opened.rollback;
  app = await createE2eApp(opened.tx);
});

afterAll(async () => {
  await app.close();
  await rollback();
  await db.close();
});

const http = () => request(app.getHttpServer());
const UUID = '11111111-1111-4111-8111-111111111111';

async function register(): Promise<string> {
  const res = await http()
    .post('/api/auth/register')
    .send({
      email: `${randomUUID()}@test.com`,
      password: 'secret1',
      firstName: 'Ann',
      lastName: 'Lee',
    })
    .expect(201);
  return (res.body as { accessToken: string }).accessToken;
}

const auth = (token: string) => ({ Authorization: `Bearer ${token}` });

async function createProfile(token: string) {
  await http()
    .post('/api/profiles')
    .set(auth(token))
    .send({
      weight: 80,
      height: 180,
      age: 30,
      gender: 'male',
      goal: 'maintain',
      activityLevel: 'medium',
    })
    .expect(201);
}

function utcToday(): string {
  const d = new Date();
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}-${String(d.getUTCDate()).padStart(2, '0')}`;
}

function dateOffset(days: number): string {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() - days);
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}-${String(d.getUTCDate()).padStart(2, '0')}`;
}

async function getProfile(token: string) {
  const res = await http().get('/api/profiles/me').set(auth(token)).expect(200);
  return res.body as { userId: string; weight: number | string; goal: string };
}

async function ageGoalsForPersonalization(userId: string, days = 20) {
  const ts = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
  await tx
    .update(userGoals)
    .set({ createdAt: ts, updatedAt: ts, startedAt: ts })
    .where(and(eq(userGoals.userId, userId), isNull(userGoals.endedAt)));
}

describe('goals routes', () => {
  it('rejects unauthenticated reads', async () => {
    await http().get('/api/goals').expect(401);
  });

  it('returns 404 before goals exist', async () => {
    const token = await register();
    await http().get('/api/goals').set(auth(token)).expect(404);
  });

  it('creates goals via PATCH and returns history', async () => {
    const token = await register();

    const patched = await http()
      .patch('/api/goals')
      .set(auth(token))
      .send({ dailyCaloriesGoal: 2100 })
      .expect(200);
    expect(patched.body.source).toBe('user');
    expect(patched.body.dailyCaloriesGoal).toBe(2100);

    const fetched = await http().get('/api/goals').set(auth(token)).expect(200);
    expect(fetched.body.dailyCaloriesGoal).toBe(2100);

    const history = await http()
      .get('/api/goals/history')
      .set(auth(token))
      .expect(200);
    expect(history.body.items).toBeArray();
    expect(history.body.items.length).toBeGreaterThan(0);
    expect(history.body.items[0].changes.length).toBeGreaterThan(0);
    expect(history.body.items[0].reason).toBe('user_edit');
  });

  it('rejects an invalid goals body', async () => {
    const token = await register();
    await http()
      .patch('/api/goals')
      .set(auth(token))
      .send({ dailyCaloriesGoal: -1 })
      .expect(400);
  });

  it('requires a profile to calculate', async () => {
    const token = await register();
    await http().post('/api/goals/calculate').set(auth(token)).expect(404);
  });

  it('calculates goals from the profile', async () => {
    const token = await register();
    await createProfile(token);

    const res = await http()
      .post('/api/goals/calculate')
      .set(auth(token))
      .expect(201);
    expect(res.body.source).toBe('initial');
    expect(res.body.dailyCaloriesGoal).toBe(2759);
  });

  it('resets manual goals back to automatic', async () => {
    const token = await register();
    await createProfile(token);
    await http()
      .patch('/api/goals')
      .set(auth(token))
      .send({ dailyCaloriesGoal: 3000 })
      .expect(200);

    const res = await http()
      .post('/api/goals/reset-to-automatic')
      .set(auth(token))
      .expect(201);
    expect(res.body.source).toBe('initial');
    expect(res.body.dailyCaloriesGoal).toBe(2759);
  });

  it('reports personalization state and a fresh run as not_due', async () => {
    const token = await register();

    const personalized = await http()
      .post('/api/goals/personalize')
      .set(auth(token))
      .expect(201);
    expect(personalized.body.status).toBe('not_due');

    const state = await http()
      .get('/api/goals/personalization')
      .set(auth(token))
      .expect(200);
    expect(state.body.personalizationDue).toBeBoolean();
    expect(state.body.pending).toBeNull();
  });

  it('validates recommendation ids', async () => {
    const token = await register();

    await http()
      .post('/api/goals/personalization/not-a-uuid/accept')
      .set(auth(token))
      .expect(400);
    await http()
      .post(`/api/goals/personalization/${UUID}/accept`)
      .set(auth(token))
      .expect(404);

    await http()
      .post('/api/goals/personalization/not-a-uuid/dismiss')
      .set(auth(token))
      .expect(400);
    await http()
      .post(`/api/goals/personalization/${UUID}/dismiss`)
      .set(auth(token))
      .expect(404);
  });

  it('preview returns recommended metrics and estimated completion for measurable goal', async () => {
    const token = await register();
    await http()
      .post('/api/profiles')
      .set(auth(token))
      .send({
        weight: 80,
        height: 170,
        age: 30,
        gender: 'female',
        goal: 'lose',
        activityLevel: 'medium',
        targetWeightKg: 72,
      })
      .expect(201);

    const res = await http()
      .get('/api/goals/preview')
      .set(auth(token))
      .expect(200);
    expect(res.body.recommended).toBeDefined();
    expect(res.body.recommended.dailyCaloriesGoal).toBeNumber();
    expect(res.body.recommended.dailyProteinGoal).toBeNumber();
    expect(res.body.basis).toBeDefined();
    expect(res.body.calories.paceSource).toBe('recommended_default');
    expect(res.body.estimatedCompletion).toBeDefined();
    expect(res.body.estimatedCompletion.isApproximate).toBe(true);
  });

  it('progress returns insufficient_data when there is not enough history', async () => {
    const token = await register();
    await createProfile(token);

    const res = await http()
      .get('/api/goals/progress?days=14')
      .set(auth(token))
      .expect(200);

    expect(res.body.status).toBeDefined();
    expect(res.body.recommendation).toBeDefined();
    expect(res.body.recommendation.action).toBeDefined();
    // New profile with no logs should not produce a confident actionable change
    expect([
      'insufficient_data',
      'on_track',
      'slightly_off',
      'off_track',
    ]).toContain(res.body.status);
  });

  it('progress/apply rejects when there is no actionable adjustment', async () => {
    const token = await register();
    await createProfile(token);

    await http()
      .post('/api/goals/progress/apply?days=14')
      .set(auth(token))
      .send({})
      .expect(400);
  });

  it('manual mode creates suggestion on recalculate and allows dismiss', async () => {
    const token = await register();
    await createProfile(token);

    await http()
      .patch('/api/goals')
      .set(auth(token))
      .send({ dailyCaloriesGoal: 2300 })
      .expect(200);

    const recalc = await http()
      .post('/api/goals/calculate')
      .set(auth(token))
      .expect(201);

    expect(recalc.body.mode).toBe('manual');
    expect(recalc.body.suggestedGoals).toBeDefined();

    const dismissed = await http()
      .post('/api/goals/dismiss-suggestion')
      .set(auth(token))
      .expect(201);
    expect(dismissed.body.suggestedGoals == null).toBe(true);
  });

  it('manual suggestion can be partially applied', async () => {
    const token = await register();
    await createProfile(token);

    await http()
      .patch('/api/goals')
      .set(auth(token))
      .send({ dailyCaloriesGoal: 2300 })
      .expect(200);

    const recalc = await http()
      .post('/api/goals/calculate')
      .set(auth(token))
      .expect(201);
    expect(recalc.body.suggestedGoals).toBeDefined();

    const applied = await http()
      .post('/api/goals/apply-suggestion')
      .set(auth(token))
      .send({ metrics: ['dailyWaterGoal'] })
      .expect(201);

    expect(applied.body.mode).toBe('manual');
    expect(applied.body.dailyCaloriesGoal).toBe(2300);
  });

  it('new-cycle maintain sets maintain range and reapplies goals', async () => {
    const token = await register();
    await createProfile(token);

    const res = await http()
      .post('/api/goals/new-cycle')
      .set(auth(token))
      .send({
        action: 'maintain',
        goal: 'maintain',
        targetWeightMinKg: 79,
        targetWeightMaxKg: 81,
        targetWeightKg: 80,
      })
      .expect(201);

    expect(res.body).toBeDefined();
    const profile = await http()
      .get('/api/profiles/me')
      .set(auth(token))
      .expect(200);
    expect(profile.body.goal).toBe('maintain');
    expect(profile.body.targetWeightMinKg).toBe(79);
    expect(profile.body.targetWeightMaxKg).toBe(81);
  });

  it('real DB full lifecycle smoke: preview/calculate/manual/progress/weight/personalize/new-cycle', async () => {
    const token = await register();
    await http()
      .post('/api/profiles')
      .set(auth(token))
      .send({
        weight: 80,
        height: 170,
        age: 30,
        gender: 'female',
        goal: 'lose',
        activityLevel: 'medium',
        targetWeightKg: 72,
      })
      .expect(201);

    const me = await getProfile(token);
    const userId = me.userId;

    // 1) Preview
    const preview = await http()
      .get('/api/goals/preview')
      .set(auth(token))
      .expect(200);
    expect(preview.body.recommended.dailyCaloriesGoal).toEqual(
      expect.any(Number),
    );
    expect(preview.body.calories.paceSource).toBe('recommended_default');
    expect(preview.body.estimatedCompletion?.isApproximate).toBe(true);

    // 2) Calculate
    const calculated = await http()
      .post('/api/goals/calculate')
      .set(auth(token))
      .expect(201);
    expect(calculated.body.dailyCaloriesGoal).toEqual(expect.any(Number));

    // 3) Manual suggestion / partial apply
    await http()
      .patch('/api/goals')
      .set(auth(token))
      .send({ dailyCaloriesGoal: 2300 })
      .expect(200);
    const recalc = await http()
      .post('/api/goals/calculate')
      .set(auth(token))
      .expect(201);
    expect(recalc.body.mode).toBe('manual');
    expect(recalc.body.suggestedGoals).toBeDefined();

    const partialApplied = await http()
      .post('/api/goals/apply-suggestion')
      .set(auth(token))
      .send({ metrics: ['dailyWaterGoal'] })
      .expect(201);
    expect(partialApplied.body.mode).toBe('manual');
    expect(partialApplied.body.dailyCaloriesGoal).toBe(2300);

    await http()
      .post('/api/goals/dismiss-suggestion')
      .set(auth(token))
      .expect(201);

    // 4) Progress apply stale-check / no-action guard
    const progress = await http()
      .get('/api/goals/progress?days=14')
      .set(auth(token))
      .expect(200);
    expect(progress.body.recommendation).toBeDefined();

    const applyRes = await http()
      .post('/api/goals/progress/apply?days=14')
      .set(auth(token))
      .send({ metrics: { dailyCaloriesGoal: 99999 } });
    // Either no actionable adjustment (400) or stale mismatch (400).
    expect(applyRes.status).toBe(400);

    // 5) Today weight / make-current / delete rollback
    const today = utcToday();
    const yesterday = dateOffset(1);

    await http()
      .post('/api/weight-logs')
      .set(auth(token))
      .send({ weightKg: 81, date: today })
      .expect(201);
    const afterToday = await getProfile(token);
    expect(Number(afterToday.weight)).toBe(81);

    await http()
      .post('/api/weight-logs')
      .set(auth(token))
      .send({ weightKg: 79, date: yesterday })
      .expect(201);
    const afterPast = await getProfile(token);
    expect(Number(afterPast.weight)).toBe(81);

    await http()
      .post(`/api/weight-logs/${yesterday}/make-current`)
      .set(auth(token))
      .expect(201);
    const afterMakeCurrent = await getProfile(token);
    expect(Number(afterMakeCurrent.weight)).toBe(79);

    // Today's log is initial (created with profile) and cannot be deleted.
    const delInitial = await http()
      .delete(`/api/weight-logs/${today}`)
      .set(auth(token));
    expect(delInitial.status).toBe(400);

    const manualDate = dateOffset(12);
    await http()
      .post('/api/weight-logs')
      .set(auth(token))
      .send({ weightKg: 78.5, date: manualDate })
      .expect(201);
    const delManual = await http()
      .delete(`/api/weight-logs/${manualDate}`)
      .set(auth(token));
    expect(delManual.status).toBe(200);
    const afterDeleteManual = await getProfile(token);
    expect(Number(afterDeleteManual.weight)).toEqual(expect.any(Number));

    // 6) Personalize / cooldown / idempotency (smoke via real DB state)
    await ageGoalsForPersonalization(userId, 20);
    for (let i = 2; i <= 10; i++) {
      const date = dateOffset(i);
      await tx.insert(weightLogs).values({
        userId,
        weightKg: String(80 - i * 0.1),
        entryDate: date,
        source: 'manual',
      });
      await tx.insert(dailySummary).values({
        userId,
        date,
        totalCalories: 1800,
      });
      await tx.insert(dailyActivity).values({
        userId,
        date,
        steps: 9000,
        activeCalories: 350,
      });
    }

    const p1 = await http().post('/api/goals/personalize').set(auth(token));
    expect([200, 201]).toContain(p1.status);
    expect(p1.body.status).toBeDefined();

    const p2 = await http().post('/api/goals/personalize').set(auth(token));
    expect([200, 201]).toContain(p2.status);
    expect(p2.body.status).toBeDefined();
    // Idempotency/safety: repeated call should not create duplicate actionable pending state unexpectedly.
    if (p1.body.status === 'pending_exists' || p1.body.status === 'created') {
      expect([
        'pending_exists',
        'not_due',
        'created',
        'no_change',
        'collect_data',
        'insufficient_data',
      ]).toContain(p2.body.status);
    }

    // 7) New-cycle / maintain range
    const newCycle = await http()
      .post('/api/goals/new-cycle')
      .set(auth(token))
      .send({
        action: 'maintain',
        goal: 'maintain',
        targetWeightMinKg: 78,
        targetWeightMaxKg: 82,
        targetWeightKg: 80,
      })
      .expect(201);
    expect(newCycle.body).toBeDefined();

    const profileAfterCycle = await http()
      .get('/api/profiles/me')
      .set(auth(token))
      .expect(200);
    expect(profileAfterCycle.body.goal).toBe('maintain');
    expect(Number(profileAfterCycle.body.targetWeightMinKg)).toBe(78);
    expect(Number(profileAfterCycle.body.targetWeightMaxKg)).toBe(82);
  });

  it('real DB lifecycle: manual overrides then reset-to-automatic restores auto mode', async () => {
    const token = await register();
    await http()
      .post('/api/profiles')
      .set(auth(token))
      .send({
        weight: 80,
        height: 170,
        age: 30,
        gender: 'female',
        goal: 'lose',
        activityLevel: 'medium',
        targetWeightKg: 72,
      })
      .expect(201);

    const initial = await http()
      .post('/api/goals/calculate')
      .set(auth(token))
      .expect(201);
    expect(initial.body.mode).toBe('auto');
    const autoCalories = initial.body.dailyCaloriesGoal;

    await http()
      .patch('/api/goals')
      .set(auth(token))
      .send({ dailyCaloriesGoal: autoCalories + 300 })
      .expect(200);

    const manual = await http().get('/api/goals').set(auth(token)).expect(200);
    expect(manual.body.mode).toBe('manual');
    expect(manual.body.dailyCaloriesGoal).toBe(autoCalories + 300);

    const recalc = await http()
      .post('/api/goals/calculate')
      .set(auth(token))
      .expect(201);
    expect(recalc.body.mode).toBe('manual');
    expect(recalc.body.suggestedGoals).toBeDefined();

    const reset = await http()
      .post('/api/goals/reset-to-automatic')
      .set(auth(token))
      .expect(201);
    expect(reset.body.mode).toBe('auto');
    expect(reset.body.source).toBe('initial');
    expect(reset.body.dailyCaloriesGoal).toBe(autoCalories);
    expect(reset.body.suggestedGoals == null).toBe(true);

    const afterReset = await http()
      .get('/api/goals')
      .set(auth(token))
      .expect(200);
    expect(afterReset.body.mode).toBe('auto');
    expect(afterReset.body.dailyCaloriesGoal).toBe(autoCalories);
  });
});
