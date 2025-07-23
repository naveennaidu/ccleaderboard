import { Hono } from 'hono';
import { drizzle } from 'drizzle-orm/d1';
import { eq, sql, desc, and, gte, lte } from 'drizzle-orm';
import { users, dailyUsage, type User, type NewUser } from '../db/schema';
import type { 
  CloudflareBindings, 
  RegisterRequest, 
  RegisterResponse,
  SyncStatusResponse,
  UserStatsResponse 
} from '../types';
import { validateUsername, validateDeviceId } from '../validators';

const app = new Hono<{ Bindings: CloudflareBindings }>();

app.post('/register', async (c) => {
  try {
    const body = await c.req.json<RegisterRequest>();
    
    const usernameError = validateUsername(body.username);
    if (usernameError) {
      return c.json<RegisterResponse>({
        success: false,
        username: body.username,
        created: false,
        error: usernameError
      }, 400);
    }
    
    const deviceIdError = validateDeviceId(body.deviceId);
    if (deviceIdError) {
      return c.json<RegisterResponse>({
        success: false,
        username: body.username,
        created: false,
        error: deviceIdError
      }, 400);
    }
    
    const db = drizzle(c.env.DB, { schema: { users, dailyUsage } });
    
    const existingUser = await db.select()
      .from(users)
      .where(eq(users.username, body.username))
      .limit(1);
      
    if (existingUser.length > 0) {
      return c.json<RegisterResponse>({
        success: false,
        username: body.username,
        created: false,
        error: 'Username already taken'
      }, 400);
    }
    
    const existingDevice = await db.select()
      .from(users)
      .where(eq(users.deviceId, body.deviceId))
      .limit(1);
      
    if (existingDevice.length > 0) {
      return c.json<RegisterResponse>({
        success: false,
        username: body.username,
        created: false,
        error: 'Device already registered'
      }, 400);
    }
    
    const newUser: NewUser = {
      username: body.username,
      deviceId: body.deviceId,
      createdAt: new Date().toISOString(),
      lastUploadAt: null,
      lastSyncDate: null,
      totalRequests: 0,
      totalInputTokens: 0,
      totalOutputTokens: 0,
      totalCost: 0
    };
    
    await db.insert(users).values(newUser);
    
    return c.json<RegisterResponse>({
      success: true,
      username: body.username,
      created: true
    });
    
  } catch (error) {
    console.error('Registration error:', error);
    return c.json<RegisterResponse>({
      success: false,
      username: '',
      created: false,
      error: 'Internal server error'
    }, 500);
  }
});

app.get('/:username/sync-status', async (c) => {
  try {
    const username = c.req.param('username');
    
    const usernameError = validateUsername(username);
    if (usernameError) {
      return c.json({ error: usernameError }, 400);
    }
    
    const db = drizzle(c.env.DB, { schema: { users, dailyUsage } });
    
    const user = await db.select()
      .from(users)
      .where(eq(users.username, username))
      .limit(1);
      
    if (user.length === 0) {
      return c.json({ error: 'User not found' }, 404);
    }
    
    const userData = user[0];
    
    const daysCount = await db.select({ count: sql<number>`count(*)` })
      .from(dailyUsage)
      .where(eq(dailyUsage.userId, userData.id));
    
    return c.json<SyncStatusResponse>({
      username: userData.username,
      lastSyncDate: userData.lastSyncDate,
      lastUploadTime: userData.lastUploadAt,
      totalDaysUploaded: daysCount[0]?.count || 0
    });
    
  } catch (error) {
    console.error('Sync status error:', error);
    return c.json({ error: 'Internal server error' }, 500);
  }
});

app.get('/:username/stats', async (c) => {
  try {
    const username = c.req.param('username');
    
    const usernameError = validateUsername(username);
    if (usernameError) {
      return c.json({ error: usernameError }, 400);
    }
    
    const db = drizzle(c.env.DB, { schema: { users, dailyUsage } });
    
    const user = await db.select()
      .from(users)
      .where(eq(users.username, username))
      .limit(1);
      
    if (user.length === 0) {
      return c.json({ error: 'User not found' }, 404);
    }
    
    const userData = user[0];
    
    const rankByRequests = await db.select({ count: sql<number>`count(*)` })
      .from(users)
      .where(sql`total_requests > ${userData.totalRequests}`);
      
    const rankByTokens = await db.select({ count: sql<number>`count(*)` })
      .from(users)
      .where(sql`(total_input_tokens + total_output_tokens) > ${(userData.totalInputTokens || 0) + (userData.totalOutputTokens || 0)}`);
      
    const rankByCost = await db.select({ count: sql<number>`count(*)` })
      .from(users)
      .where(sql`total_cost > ${userData.totalCost}`);
    
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    const thirtyDaysAgoStr = thirtyDaysAgo.toISOString().split('T')[0];
    
    const recentActivity = await db.select({
      date: dailyUsage.date,
      requests: dailyUsage.totalRequests,
      cost: dailyUsage.totalCost
    })
      .from(dailyUsage)
      .where(and(
        eq(dailyUsage.userId, userData.id),
        gte(dailyUsage.date, thirtyDaysAgoStr)
      ))
      .orderBy(desc(dailyUsage.date))
      .limit(30);
    
    return c.json<UserStatsResponse>({
      username: userData.username,
      globalRank: {
        byRequests: (rankByRequests[0]?.count || 0) + 1,
        byTokens: (rankByTokens[0]?.count || 0) + 1,
        byCost: (rankByCost[0]?.count || 0) + 1
      },
      totals: {
        requests: userData.totalRequests || 0,
        inputTokens: userData.totalInputTokens || 0,
        outputTokens: userData.totalOutputTokens || 0,
        cost: userData.totalCost || 0
      },
      recentActivity
    });
    
  } catch (error) {
    console.error('User stats error:', error);
    return c.json({ error: 'Internal server error' }, 500);
  }
});

export default app;