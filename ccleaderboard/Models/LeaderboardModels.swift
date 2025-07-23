import Foundation

// MARK: - Request Models

struct RegisterRequest: Codable {
    let username: String
    let deviceId: String
}

struct UploadRequest: Codable {
    let username: String
    let dailyUsage: [DailyUsageData]
    
    struct DailyUsageData: Codable {
        let date: String
        let totalRequests: Int
        let totalInputTokens: Int
        let totalOutputTokens: Int
        let totalCost: Double
    }
}

// MARK: - Response Models

struct RegisterResponse: Codable {
    let success: Bool
    let username: String
    let created: Bool
    let error: String?
}

struct UploadResponse: Codable {
    let success: Bool
    let uploaded: Int
    let skipped: Int
    let errors: [String]?
}

struct LeaderboardResponse: Codable {
    let leaderboard: [LeaderboardEntry]
    let total: Int
    let period: String
    let metric: String
}

struct LeaderboardEntry: Codable, Identifiable {
    let rank: Int
    let username: String
    let totalRequests: Int
    let totalTokens: Int
    let totalCost: Double
    let lastActive: String
    
    var id: String { username }
}

struct SyncStatusResponse: Codable {
    let username: String
    let lastSyncDate: String?
    let lastUploadTime: String?
    let totalDaysUploaded: Int
}

struct UserStatsResponse: Codable {
    let username: String
    let globalRank: GlobalRank
    let totals: UserTotals
    let recentActivity: [RecentActivity]
    
    struct GlobalRank: Codable {
        let byRequests: Int
        let byTokens: Int
        let byCost: Int
    }
    
    struct UserTotals: Codable {
        let requests: Int
        let inputTokens: Int
        let outputTokens: Int
        let cost: Double
    }
    
    struct RecentActivity: Codable, Identifiable {
        let date: String
        let requests: Int
        let cost: Double
        
        var id: String { date }
    }
}

// MARK: - Enums for API Parameters

enum LeaderboardMetric: String, CaseIterable {
    case requests = "requests"
    case tokens = "tokens"
    case cost = "cost"
    
    var displayName: String {
        switch self {
        case .requests: return "Total Requests"
        case .tokens: return "Total Tokens"
        case .cost: return "Total Cost"
        }
    }
}

enum LeaderboardPeriod: String, CaseIterable {
    case all = "all"
    case month = "month"
    case week = "week"
    
    var displayName: String {
        switch self {
        case .all: return "All Time"
        case .month: return "This Month"
        case .week: return "This Week"
        }
    }
}