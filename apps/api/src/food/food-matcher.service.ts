import { Injectable, Logger } from '@nestjs/common';
import { db } from '../db/db';
import { foods } from '../db/schema/foods';
import { foodCategories } from '../db/schema/foodCategories';
import { eq, sql } from 'drizzle-orm';
import type { FoodAnalysisItem } from './food.schema';

interface CandidateRow {
  id: string;
  name: string;
  caloriesPer100g: number;
  proteinPer100g: number | null;
  fatPer100g: number | null;
  carbsPer100g: number | null;
  source: string;
  category: string | null;
}

@Injectable()
export class FoodMatcherService {
  private readonly logger = new Logger(FoodMatcherService.name);

  async matchItems(items: FoodAnalysisItem[]): Promise<FoodAnalysisItem[]> {
    const names = items
      .map((i) => i.name?.trim())
      .filter((n): n is string => !!n);

    if (!names.length) {
      return items.map((item) => ({ ...item, source: 'ai' }));
    }

    const matches = await this.findMatches(names);

    return items.map((item) => {
      const name = item.name?.trim();
      if (!name) return { ...item, source: 'ai' };

      const match = matches.get(name.toLowerCase());
      if (!match) return { ...item, source: 'ai' };

      const grams = item.grams && item.grams > 0 ? item.grams : 100;
      const ratio = grams / 100;

      const catalogCalories = Math.round(match.caloriesPer100g * ratio);
      const aiCalories = item.calories;

      const replaced: FoodAnalysisItem = {
        ...item,
        name: match.name,
        category: match.category ?? item.category,
        foodId: match.id,
        source: 'catalog',
        calories: catalogCalories,
        protein: Math.round((match.proteinPer100g ?? 0) * ratio),
        fat: Math.round((match.fatPer100g ?? 0) * ratio),
        carbs: Math.round((match.carbsPer100g ?? 0) * ratio),
        aiCalories,
        catalogCalories,
      };

      const divergent =
        aiCalories != null &&
        catalogCalories > 0 &&
        Math.abs(aiCalories - catalogCalories) / catalogCalories > 0.5;

      this.logger.log(
        `[matcher] "${item.name}" -> "${match.name}"` +
          ` | ai=${aiCalories} catalog=${catalogCalories}` +
          (divergent ? ' | DIVERGENT' : ''),
      );

      return replaced;
    });
  }

  private async findMatches(names: string[]): Promise<Map<string, CandidateRow>> {
    const where = sql`(${names.map((name) => this.nameClause(name)).join(' OR ')})`;

    const rows: CandidateRow[] = await db
      .select({
        id: foods.id,
        name: foods.name,
        caloriesPer100g: foods.caloriesPer100g,
        proteinPer100g: foods.proteinPer100g,
        fatPer100g: foods.fatPer100g,
        carbsPer100g: foods.carbsPer100g,
        source: foods.source,
        category: foodCategories.name,
      })
      .from(foods)
      .leftJoin(foodCategories, eq(foods.categoryId, foodCategories.id))
      .where(where)
      .limit(100);

    const result = new Map<string, CandidateRow>();

    for (const name of names) {
      const nameLower = name.toLowerCase();
      const scored = rows
        .map((f) => {
          const fn = f.name.toLowerCase();
          let score = 0;
          if (fn === nameLower) score += 100;
          else if (fn.startsWith(nameLower)) score += 50;
          else if (fn.includes(nameLower)) score += 30;
          else if (nameLower.includes(fn)) score += 20;
          else score += 10;
          score += this.readinessBonus(fn);
          score += f.source === 'user' ? 5 : 2;
          return { f, score };
        })
        .sort((a, b) => b.score - a.score);

      const best = scored[0];
      if (best && best.score >= 12) {
        result.set(nameLower, best.f);
      }
    }

    return result;
  }

  private nameClause(name: string) {
    return sql`(
      to_tsvector('russian', ${foods.name}) @@ plainto_tsquery('russian', ${name})
      OR to_tsvector('english', ${foods.name}) @@ plainto_tsquery('english', ${name})
      OR to_tsvector('simple', ${foods.name}) @@ plainto_tsquery('simple', ${name})
      OR ${foods.name} ILIKE ${`%${name}%`}
    )`;
  }

  private readinessBonus(fn: string): number {
    const cooked = /(отварн|варё|варен|приготовлен|готов|тушен|жарен|запечен|пассер|сварен|печен)/;
    const raw = /(сух|сыр|всухом|сухой|всыром|необработанн)/;
    if (cooked.test(fn)) return 15;
    if (raw.test(fn)) return -15;
    return 0;
  }
}
