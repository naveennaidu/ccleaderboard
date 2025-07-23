import Foundation
import SwiftUI

class LeaderboardService: ObservableObject {
    @Published var isJoined: Bool = false
    @Published var username: String?
    @Published var deviceId: String
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // TODO: Replace with your actual Cloudflare Workers URL
    private let baseURL = "http://localhost:8787/api/v1" // Change this to your deployed backend URL
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
        
        print("[SYNC] Getting sync status from: \(url)")
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("[SYNC] Sync status response code: \(httpResponse.statusCode)")
        }
        
        let syncStatus = try JSONDecoder().decode(SyncStatusResponse.self, from: data)
        print("[SYNC] Last sync date from server: \(syncStatus.lastSyncDate ?? "never")")
        return syncStatus
    }
    
    func syncUsageData(_ dailyUsage: [DailyUsage]) async throws {
        guard let username = username else { return }
        
        let startTime = Date()
        print("[SYNC] Starting sync of \(dailyUsage.count) days of data...")
        
        await MainActor.run {
            self.isLoading = true
        }
        defer { 
            Task { @MainActor in
                self.isLoading = false
                let duration = Date().timeIntervalSince(startTime)
                print("[SYNC] Total sync duration: \(String(format: "%.2f", duration)) seconds")
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
        
        print("[SYNC] Sending POST request to: \(url)")
        print("[SYNC] Payload size: \(urlRequest.httpBody?.count ?? 0) bytes")
        print("[SYNC] Number of days in payload: \(uploadData.count)")
        
        let requestStartTime = Date()
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        let requestDuration = Date().timeIntervalSince(requestStartTime)
        print("[SYNC] Request completed in \(String(format: "%.2f", requestDuration)) seconds")
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("[SYNC] ERROR: Invalid response type")
            throw LeaderboardError.invalidResponse
        }
        
        print("[SYNC] Response status code: \(httpResponse.statusCode)")
        print("[SYNC] Response size: \(data.count) bytes")
        
        guard httpResponse.statusCode == 200 else {
            print("[SYNC] ERROR: Upload failed with status \(httpResponse.statusCode)")
            if let errorString = String(data: data, encoding: .utf8) {
                print("[SYNC] Error response: \(errorString)")
            }
            throw LeaderboardError.uploadFailed
        }
        
        let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
        
        if uploadResponse.success {
            print("[SYNC] Upload successful! Uploaded: \(uploadResponse.uploaded), Skipped: \(uploadResponse.skipped)")
            // Update last sync date to the newest date (first in the array since it's sorted descending)
            if let newestDate = dailyUsage.first?.date {
                userDefaults.set(newestDate, forKey: lastSyncDateKey)
                print("[SYNC] Updated last sync date to: \(newestDate)")
            }
        } else {
            print("[SYNC] Upload failed: \(uploadResponse.errors?.joined(separator: ", ") ?? "Unknown error")")
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
    
    // MARK: - Smart Sync Methods
    
    func performSmartSync() async throws {
        guard let username = username else {
            throw LeaderboardError.notJoined
        }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        defer {
            Task { @MainActor in
                self.isLoading = false
            }
        }
        
        // 1. Get sync status from backend
        let syncStatus = try await getSyncStatus()
        
        // 2. Load local usage data
        let dataLoader = UsageDataLoader.shared
        await MainActor.run {
            // Ensure data is loaded
            if dataLoader.dailyUsage.isEmpty && dataLoader.selectedDirectory != nil {
                dataLoader.loadDailyUsage()
            }
        }
        
        // Wait for data to load if needed
        var attempts = 0
        while dataLoader.isLoading && attempts < 30 {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            attempts += 1
        }
        
        guard !dataLoader.dailyUsage.isEmpty else {
            print("No usage data available to sync")
            return
        }
        
        // 3. Filter data that needs uploading
        let allData = dataLoader.dailyUsage
        print("[SYNC] Total local data available: \(allData.count) days")
        if let firstDate = allData.first?.date, let lastDate = allData.last?.date {
            print("[SYNC] Date range: \(firstDate) to \(lastDate)")
        }
        
        let dataToUpload: [DailyUsage]
        
        if let lastSyncDateString = syncStatus?.lastSyncDate {
            // Try parsing as ISO8601 first, then try as simple date format
            var lastSyncDate: Date?
            
            // Try ISO8601 format first
            lastSyncDate = ISO8601DateFormatter().date(from: lastSyncDateString)
            
            // If that fails, try simple date format (YYYY-MM-DD)
            if lastSyncDate == nil {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
                lastSyncDate = dateFormatter.date(from: lastSyncDateString)
            }
            
            guard let syncDate = lastSyncDate else {
                print("[SYNC] ERROR: Unable to parse last sync date: \(lastSyncDateString)")
                dataToUpload = allData
                print("[SYNC] Falling back to uploading all \(dataToUpload.count) days of data")
                return
            }
            // Upload data newer than last sync, plus today's data (in case it was updated)
            let today = Calendar.current.startOfDay(for: Date())
            
            print("[SYNC] Last sync date from server: \(lastSyncDateString) (\(syncDate))")
            print("[SYNC] Today's date: \(today)")
            
            dataToUpload = allData.filter { usage in
                let isNewer = usage.date > syncDate
                let isToday = Calendar.current.isDate(usage.date, inSameDayAs: today)
                let shouldUpload = isNewer || isToday
                
                if shouldUpload {
                    print("[SYNC] Will upload: \(usage.dateString) (newer: \(isNewer), today: \(isToday))")
                }
                
                return shouldUpload
            }
            print("[SYNC] Smart sync: Found \(dataToUpload.count) days to upload (newer than \(lastSyncDateString))")
        } else {
            // First sync - upload all data
            dataToUpload = allData
            print("[SYNC] Initial sync: Uploading all \(dataToUpload.count) days of data")
        }
        
        // 4. Upload filtered data
        if !dataToUpload.isEmpty {
            try await syncUsageData(dataToUpload)
            print("Successfully synced \(dataToUpload.count) days of usage data")
        } else {
            print("No new data to sync")
        }
    }
    
    func performInitialSync() async throws {
        guard username != nil else {
            throw LeaderboardError.notJoined
        }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        defer {
            Task { @MainActor in
                self.isLoading = false
            }
        }
        
        // Load all usage data
        let dataLoader = UsageDataLoader.shared
        await MainActor.run {
            if dataLoader.selectedDirectory != nil {
                dataLoader.loadDailyUsage()
            }
        }
        
        // Wait for data to load
        var attempts = 0
        while dataLoader.isLoading && attempts < 30 {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            attempts += 1
        }
        
        guard !dataLoader.dailyUsage.isEmpty else {
            print("No usage data available for initial sync")
            return
        }
        
        // Upload all data
        let allData = dataLoader.dailyUsage
        print("Performing initial sync with \(allData.count) days of data")
        try await syncUsageData(allData)
        print("Initial sync completed successfully")
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
