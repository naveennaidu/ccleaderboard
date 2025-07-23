import Foundation
import SwiftUI

class LeaderboardService: ObservableObject {
    @Published var isJoined: Bool = false
    @Published var username: String?
    @Published var deviceId: String
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let baseURL = "http://localhost:8787/api/v1"
    private let userDefaults = UserDefaults.standard
    
    private let usernameKey = "leaderboardUsername"
    private let deviceIdKey = "leaderboardDeviceId"
    private let joinedDateKey = "leaderboardJoinedDate"
    private let lastSyncDateKey = "lastLocalSyncDate"
    private let pendingUploadsKey = "pendingUploads"
    
    init() {
        self.deviceId = DeviceID.current
        self.loadJoinedStatus()
    }
    
    // MARK: - Join Status
    
    private func loadJoinedStatus() {
        if let savedUsername = userDefaults.string(forKey: usernameKey) {
            self.username = savedUsername
            self.isJoined = true
        }
    }
    
    // MARK: - API Methods
    
    func checkUsernameAvailability(_ username: String) async -> Bool {
        // For now, we'll check by attempting to register
        // In a real app, you might want a dedicated endpoint
        return true
    }
    
    func joinLeaderboard(username: String) async throws {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        defer { 
            Task { @MainActor in
                self.isLoading = false
            }
        }
        
        let request = RegisterRequest(username: username, deviceId: deviceId)
        
        guard let url = URL(string: "\(baseURL)/users/register") else {
            throw LeaderboardError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LeaderboardError.invalidResponse
        }
        
        let registerResponse = try JSONDecoder().decode(RegisterResponse.self, from: data)
        
        if httpResponse.statusCode == 200 && registerResponse.success {
            await MainActor.run {
                self.username = username
                self.isJoined = true
                self.userDefaults.set(username, forKey: self.usernameKey)
                self.userDefaults.set(Date(), forKey: self.joinedDateKey)
            }
        } else {
            throw LeaderboardError.registrationFailed(registerResponse.error ?? "Unknown error")
        }
    }
    
    func getSyncStatus() async throws -> SyncStatusResponse? {
        guard let username = username else { return nil }
        
        guard let url = URL(string: "\(baseURL)/users/\(username)/sync-status") else {
            throw LeaderboardError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(SyncStatusResponse.self, from: data)
    }
    
    func syncUsageData(_ dailyUsage: [DailyUsage]) async throws {
        guard let username = username else { return }
        
        await MainActor.run {
            self.isLoading = true
        }
        defer { 
            Task { @MainActor in
                self.isLoading = false
            }
        }
        
        // Convert DailyUsage to UploadRequest format
        let uploadData = dailyUsage.map { usage in
            UploadRequest.DailyUsageData(
                date: usage.dateString,
                totalRequests: usage.modelBreakdowns.count,
                totalInputTokens: usage.inputTokens,
                totalOutputTokens: usage.outputTokens,
                totalCost: usage.totalCost
            )
        }
        
        let request = UploadRequest(username: username, dailyUsage: uploadData)
        
        guard let url = URL(string: "\(baseURL)/usage/upload") else {
            throw LeaderboardError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LeaderboardError.uploadFailed
        }
        
        let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
        
        if uploadResponse.success {
            // Update last sync date
            if let lastDate = dailyUsage.last?.date {
                userDefaults.set(lastDate, forKey: lastSyncDateKey)
            }
        }
    }
    
    func fetchLeaderboard(metric: LeaderboardMetric = .requests, 
                         period: LeaderboardPeriod = .all,
                         limit: Int = 100) async throws -> LeaderboardResponse {
        var components = URLComponents(string: "\(baseURL)/leaderboard")!
        components.queryItems = [
            URLQueryItem(name: "metric", value: metric.rawValue),
            URLQueryItem(name: "period", value: period.rawValue),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        guard let url = components.url else {
            throw LeaderboardError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(LeaderboardResponse.self, from: data)
    }
    
    func fetchUserStats() async throws -> UserStatsResponse? {
        guard let username = username else { return nil }
        
        guard let url = URL(string: "\(baseURL)/users/\(username)/stats") else {
            throw LeaderboardError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(UserStatsResponse.self, from: data)
    }
    
    // MARK: - Leave Leaderboard
    
    func leaveLeaderboard() {
        username = nil
        isJoined = false
        userDefaults.removeObject(forKey: usernameKey)
        userDefaults.removeObject(forKey: joinedDateKey)
        userDefaults.removeObject(forKey: lastSyncDateKey)
    }
}

// MARK: - Error Types

enum LeaderboardError: LocalizedError {
    case invalidURL
    case invalidResponse
    case registrationFailed(String)
    case uploadFailed
    case notJoined
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid server response"
        case .registrationFailed(let message):
            return "Registration failed: \(message)"
        case .uploadFailed:
            return "Failed to upload usage data"
        case .notJoined:
            return "You must join the leaderboard first"
        }
    }
}
