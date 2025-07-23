# CC Leaderboard Backend

Cloudflare Workers backend API for the Claude Code usage leaderboard, built with Hono.js and D1 database.

## API Endpoints

### User Registration
```
POST /api/v1/users/register
{
  "username": "string",  // 3-30 chars, alphanumeric + underscore
  "deviceId": "string"   // UUID
}
```

### Usage Upload
```
POST /api/v1/usage/upload
{
  "username": "string",
  "dailyUsage": [{
    "date": "YYYY-MM-DD",
    "totalRequests": number,
    "totalInputTokens": number,
    "totalOutputTokens": number,
    "totalCost": number
  }]
}
```

### Leaderboard
```
GET /api/v1/leaderboard?metric=requests&period=all&limit=100&offset=0
```
- `metric`: 'requests' | 'tokens' | 'cost' (default: 'requests')
- `period`: 'all' | 'month' | 'week' (default: 'all')
- `limit`: max 500 (default: 100)
- `offset`: for pagination (default: 0)

### User Sync Status
```
GET /api/v1/users/:username/sync-status
```

### User Stats
```
GET /api/v1/users/:username/stats
```

## Development

```bash
# Install dependencies
bun install

# Run development server
bun run dev

# Generate database migrations
bun run db:generate

# Push migrations to D1
bun run db:push

# Deploy to Cloudflare
bun run deploy
```

## Database Schema

- **users**: Stores user information and aggregated totals
- **daily_usage**: Stores daily usage metrics per user

## Features

- Username-based registration (one per device)
- Bulk upload support with UPSERT logic
- Leaderboard filtering by metric and time period
- Input validation and sanitization
- CORS support for Mac app integration
- Rate limiting (100 requests/minute per IP)