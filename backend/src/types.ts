export interface RegisterRequest {
  username: string;
  deviceId: string;
}

export interface RegisterResponse {
  success: boolean;
  username: string;
  created: boolean;
  error?: string;
}

export interface UploadRequest {
  username: string;
  dailyUsage: {
    date: string;
    totalRequests: number;
    totalInputTokens: number;
    totalOutputTokens: number;
    totalCost: number;
  }[];
}

export interface UploadResponse {
  success: boolean;
  uploaded: number;
  skipped: number;
  errors?: string[];
}

export interface LeaderboardRequest {
  metric?: 'requests' | 'tokens' | 'cost';
  period?: 'all' | 'month' | 'week';
  limit?: number;
  offset?: number;
}

export interface LeaderboardResponse {
  leaderboard: {
    rank: number;
    username: string;
    totalRequests: number;
    totalTokens: number;
    totalCost: number;
    lastActive: string;
  }[];
  total: number;
  period: string;
  metric: string;
}

export interface SyncStatusResponse {
  username: string;
  lastSyncDate: string | null;
  lastUploadTime: string | null;
  totalDaysUploaded: number;
}

export interface UserStatsResponse {
  username: string;
  globalRank: {
    byRequests: number;
    byTokens: number;
    byCost: number;
  };
  totals: {
    requests: number;
    inputTokens: number;
    outputTokens: number;
    cost: number;
  };
  recentActivity: {
    date: string;
    requests: number;
    cost: number;
  }[];
}

export interface CloudflareBindings {
  DB: D1Database;
  KV: KVNamespace;
}