import { Hono } from 'hono';
import { drizzle } from 'drizzle-orm/d1';
import { eq, and, sql } from 'drizzle-orm';
import { users, dailyUsage, type NewDailyUsage } from '../db/schema';
import type { CloudflareBindings, UploadRequest, UploadResponse } from '../types';
import { validateUsername, validateBulkUpload } from '../validators';

const app = new Hono<{ Bindings: CloudflareBindings }>();

app.post('/upload', async (c) => {
  try {
    const body = await c.req.json<UploadRequest>();
    
    const usernameError = validateUsername(body.username);
    if (usernameError) {
      return c.json<UploadResponse>({
        success: false,
        uploaded: 0,
        skipped: 0,
        errors: [usernameError]
      }, 400);
    }
    
    const validationErrors = validateBulkUpload(body.dailyUsage);
    if (validationErrors.length > 0) {
      return c.json<UploadResponse>({
        success: false,
        uploaded: 0,
        skipped: 0,
        errors: validationErrors
      }, 400);
    }
    
    const db = drizzle(c.env.DB, { schema: { users, dailyUsage } });
    
    const user = await db.select()
      .from(users)
      .where(eq(users.username, body.username))
      .limit(1);
      
    if (user.length === 0) {
      return c.json<UploadResponse>({
        success: false,
        uploaded: 0,
        skipped: 0,
        errors: ['User not found']
      }, 404);
    }
    
    const userData = user[0];
    const userId = userData.id;
    
    let uploaded = 0;
    let skipped = 0;
    const errors: string[] = [];
    
    let totalRequests = userData.totalRequests || 0;
    let totalInputTokens = userData.totalInputTokens || 0;
    let totalOutputTokens = userData.totalOutputTokens || 0;
    let totalCost = userData.totalCost || 0;
    let latestDate = userData.lastSyncDate || '';
    
    for (const entry of body.dailyUsage) {
      try {
        const existingEntry = await db.select()
          .from(dailyUsage)
          .where(and(
            eq(dailyUsage.userId, userId),
            eq(dailyUsage.date, entry.date)
          ))
          .limit(1);
        
        if (existingEntry.length > 0) {
          const existing = existingEntry[0];
          
          if (entry.totalRequests >= existing.totalRequests) {
            const deltaRequests = entry.totalRequests - existing.totalRequests;
            const deltaInputTokens = entry.totalInputTokens - existing.totalInputTokens;
            const deltaOutputTokens = entry.totalOutputTokens - existing.totalOutputTokens;
            const deltaCost = entry.totalCost - existing.totalCost;
            
            await db.update(dailyUsage)
              .set({
                totalRequests: entry.totalRequests,
                totalInputTokens: entry.totalInputTokens,
                totalOutputTokens: entry.totalOutputTokens,
                totalCost: entry.totalCost,
                updatedAt: new Date().toISOString()
              })
              .where(eq(dailyUsage.id, existing.id));
            
            totalRequests += deltaRequests;
            totalInputTokens += deltaInputTokens;
            totalOutputTokens += deltaOutputTokens;
            totalCost += deltaCost;
            
            uploaded++;
          } else {
            skipped++;
          }
        } else {
          const newEntry: NewDailyUsage = {
            userId,
            date: entry.date,
            totalRequests: entry.totalRequests,
            totalInputTokens: entry.totalInputTokens,
            totalOutputTokens: entry.totalOutputTokens,
            totalCost: entry.totalCost,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString()
          };
          
          await db.insert(dailyUsage).values(newEntry);
          
          totalRequests += entry.totalRequests;
          totalInputTokens += entry.totalInputTokens;
          totalOutputTokens += entry.totalOutputTokens;
          totalCost += entry.totalCost;
          
          uploaded++;
        }
        
        if (entry.date > latestDate) {
          latestDate = entry.date;
        }
        
      } catch (error) {
        errors.push(`Failed to process entry for ${entry.date}: ${error instanceof Error ? error.message : 'Unknown error'}`);
      }
    }
    
    await db.update(users)
      .set({
        totalRequests,
        totalInputTokens,
        totalOutputTokens,
        totalCost,
        lastSyncDate: latestDate,
        lastUploadAt: new Date().toISOString()
      })
      .where(eq(users.id, userData.id));
    
    return c.json<UploadResponse>({
      success: true,
      uploaded,
      skipped,
      errors: errors.length > 0 ? errors : undefined
    });
    
  } catch (error) {
    console.error('Upload error:', error);
    return c.json<UploadResponse>({
      success: false,
      uploaded: 0,
      skipped: 0,
      errors: ['Internal server error']
    }, 500);
  }
});

export default app;