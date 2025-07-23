import { Hono } from 'hono';
import { drizzle } from 'drizzle-orm/d1';
import { desc, sql, gte, eq } from 'drizzle-orm';
import { users, dailyUsage } from '../db/schema';
import type { CloudflareBindings, LeaderboardRequest, LeaderboardResponse } from '../types';

const app = new Hono<{ Bindings: CloudflareBindings }>();

app.get('/', async (c) => {
  try {
    const query = c.req.query();
    const metric = query.metric as 'requests' | 'tokens' | 'cost' || 'requests';
    const period = query.period as 'all' | 'month' | 'week' || 'all';
    const limit = Math.min(parseInt(query.limit || '100'), 500);
    const offset = parseInt(query.offset || '0');
    
    const db = drizzle(c.env.DB, { schema: { users, dailyUsage } });
    
    let dateFilter = '';
    const now = new Date();
    
    if (period === 'week') {
      const weekAgo = new Date(now);
      weekAgo.setDate(weekAgo.getDate() - 7);
      dateFilter = weekAgo.toISOString().split('T')[0];
    } else if (period === 'month') {
      const monthAgo = new Date(now);
      monthAgo.setMonth(monthAgo.getMonth() - 1);
      dateFilter = monthAgo.toISOString().split('T')[0];
    }
    
    let orderBy;
    let selectFields;
    
    if (period === 'all') {
      switch (metric) {
        case 'tokens':
          orderBy = desc(sql`total_input_tokens + total_output_tokens`);
          break;
        case 'cost':
          orderBy = desc(users.totalCost);
          break;
        default:
          orderBy = desc(users.totalRequests);
      }
      
      selectFields = {
        username: users.username,
        totalRequests: users.totalRequests,
        totalTokens: sql<number>`${users.totalInputTokens} + ${users.totalOutputTokens}`,
        totalCost: users.totalCost,
        lastActive: users.lastUploadAt
      };
      
      const results = await db.select(selectFields)
        .from(users)
        .orderBy(orderBy)
        .limit(limit)
        .offset(offset);
      
      const totalUsers = await db.select({ count: sql<number>`count(*)` })
        .from(users);
      
      const leaderboardWithRanks = results.map((user, index) => ({
        rank: offset + index + 1,
        username: user.username,
        totalRequests: user.totalRequests || 0,
        totalTokens: user.totalTokens || 0,
        totalCost: user.totalCost || 0,
        lastActive: user.lastActive || ''
      }));
      
      return c.json<LeaderboardResponse>({
        leaderboard: leaderboardWithRanks,
        total: totalUsers[0]?.count || 0,
        period,
        metric
      });
      
    } else {
      const aggregatedData = await db.select({
        userId: dailyUsage.userId,
        username: users.username,
        totalRequests: sql<number>`sum(${dailyUsage.totalRequests})`,
        totalInputTokens: sql<number>`sum(${dailyUsage.totalInputTokens})`,
        totalOutputTokens: sql<number>`sum(${dailyUsage.totalOutputTokens})`,
        totalCost: sql<number>`sum(${dailyUsage.totalCost})`,
        lastActive: sql<string>`max(${dailyUsage.date})`
      })
        .from(dailyUsage)
        .innerJoin(users, eq(users.id, dailyUsage.userId))
        .where(gte(dailyUsage.date, dateFilter))
        .groupBy(dailyUsage.userId, users.username);
      
      const sorted = aggregatedData.sort((a, b) => {
        switch (metric) {
          case 'tokens':
            return (b.totalInputTokens + b.totalOutputTokens) - (a.totalInputTokens + a.totalOutputTokens);
          case 'cost':
            return b.totalCost - a.totalCost;
          default:
            return b.totalRequests - a.totalRequests;
        }
      });
      
      const paginated = sorted.slice(offset, offset + limit);
      
      const leaderboardWithRanks = paginated.map((user, index) => ({
        rank: offset + index + 1,
        username: user.username,
        totalRequests: user.totalRequests || 0,
        totalTokens: (user.totalInputTokens || 0) + (user.totalOutputTokens || 0),
        totalCost: user.totalCost || 0,
        lastActive: user.lastActive || ''
      }));
      
      return c.json<LeaderboardResponse>({
        leaderboard: leaderboardWithRanks,
        total: sorted.length,
        period,
        metric
      });
    }
    
  } catch (error) {
    console.error('Leaderboard error:', error);
    return c.json({ error: 'Internal server error' }, 500);
  }
});

export default app;