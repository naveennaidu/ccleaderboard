import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject var leaderboardService: LeaderboardService
    @State private var showJoinSheet = false
    @State private var selectedMetric: LeaderboardMetric = .cost
    @State private var selectedPeriod: LeaderboardPeriod = .all
    @State private var leaderboardData: LeaderboardResponse?
    @State private var userStats: UserStatsResponse?
    @State private var isLoading = false
    @State private var lastRefresh = Date()
    @State private var isUploadingInitialData = false
    @State private var uploadProgress = ""
    
    var body: some View {
        VStack {
            if leaderboardService.isJoined {
                leaderboardContent
            } else {
                notJoinedView
            }
        }
        .onAppear {
            if leaderboardService.isJoined {
                Task {
                    await loadLeaderboard()
                }
            }
        }
        .sheet(isPresented: $showJoinSheet) {
            JoinLeaderboardView()
                .environmentObject(leaderboardService)
                .onDisappear {
                    // When the join sheet closes after successful registration,
                    // start the upload process
                    if leaderboardService.isJoined && leaderboardData == nil {
                        Task {
                            await performInitialDataUpload()
                        }
                    }
                }
        }
    }
    
    private var notJoinedView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            Text("Join the Global Leaderboard")
                .font(.title)
                .fontWeight(.semibold)
            
            Text("Compete with other Claude Code users worldwide\nand track your usage statistics")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: { showJoinSheet = true }) {
                Label("Join Leaderboard", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var leaderboardContent: some View {
        VStack(spacing: 0) {
            // Header with controls
            VStack(spacing: 16) {
                HStack {
                    Text("Leaderboard")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    if let username = leaderboardService.username {
                        Text("@\(username)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: { Task { await loadLeaderboard() } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading || isUploadingInitialData)
                }
                
            }
            .padding()
            
            Divider()
            
            // Show uploading state if initial data is being uploaded
            if isUploadingInitialData {
                Spacer()
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Text("Uploading your usage data")
                        .font(.headline)
                    
                    Text("We're bringing all your local usage data to Claude.\nThis will take a few moments...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    if !uploadProgress.isEmpty {
                        Text(uploadProgress)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                Spacer()
            } else if isLoading && leaderboardData == nil {
                Spacer()
                ProgressView("Loading leaderboard...")
                Spacer()
            } else if let data = leaderboardData {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Header row
                        LeaderboardHeaderRow()
                        
                        // Data rows
                        ForEach(data.leaderboard) { entry in
                            LeaderboardRow(entry: entry, currentUsername: leaderboardService.username)
                                .background(entry.username == leaderboardService.username ? Color.accentColor.opacity(0.1) : Color.clear)
                        }
                    }
                }
            } else {
                Spacer()
                Text("No data available")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }
    
    private func loadLeaderboard() async {
        isLoading = true
        do {
            leaderboardData = try await leaderboardService.fetchLeaderboard(
                metric: .cost,
                period: .all
            )
            
            if leaderboardService.isJoined {
                userStats = try await leaderboardService.fetchUserStats()
            }
        } catch {
            print("Failed to load leaderboard: \(error)")
        }
        isLoading = false
    }
    
    private func performInitialDataUpload() async {
        await MainActor.run {
            isUploadingInitialData = true
            uploadProgress = "Preparing your usage history..."
        }
        
        do {
            // Perform the initial sync
            try await leaderboardService.performInitialSync()
            
            await MainActor.run {
                uploadProgress = "Upload complete! Loading leaderboard..."
            }
            
            // Brief delay to show completion message
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            // Load the leaderboard with fresh data
            await loadLeaderboard()
            
            await MainActor.run {
                isUploadingInitialData = false
                uploadProgress = ""
            }
        } catch {
            await MainActor.run {
                isUploadingInitialData = false
                uploadProgress = ""
                // Handle error if needed
                print("Initial upload failed: \(error)")
            }
        }
    }
}

struct LeaderboardHeaderRow: View {
    var body: some View {
        HStack {
            Text("Rank")
                .frame(width: 50, alignment: .leading)
            
            Text("User")
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Value")
                .frame(width: 120, alignment: .trailing)
            
            Text("Last Active")
                .frame(width: 100, alignment: .trailing)
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
    }
}

struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    let currentUsername: String?
    
    private var displayValue: String {
        String(format: "$%.2f", entry.totalCost)
    }
    
    private var isCurrentUser: Bool {
        entry.username == currentUsername
    }
    
    var body: some View {
        HStack {
            // Rank with medal for top 3
            HStack(spacing: 4) {
                if entry.rank <= 3 {
                    Image(systemName: medalIcon(for: entry.rank))
                        .foregroundColor(medalColor(for: entry.rank))
                        .font(.system(size: 14))
                }
                Text("#\(entry.rank)")
                    .fontWeight(entry.rank <= 3 ? .semibold : .regular)
            }
            .frame(width: 50, alignment: .leading)
            
            // Username
            HStack {
                Text(entry.username)
                    .fontWeight(isCurrentUser ? .semibold : .regular)
                if isCurrentUser {
                    Text("(You)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Value and total tokens
            VStack(alignment: .trailing, spacing: 2) {
                Text(displayValue)
                    .fontWeight(entry.rank <= 10 ? .medium : .regular)
                Text(formatNumber(entry.totalTokens) + " tokens")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 120, alignment: .trailing)
            
            // Last active
            Text(formatRelativeDate(entry.lastActive))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.clear)
        .contentShape(Rectangle())
        Divider()
    }
    
    private func medalIcon(for rank: Int) -> String {
        switch rank {
        case 1: return "medal.fill"
        case 2: return "medal.fill"
        case 3: return "medal.fill"
        default: return ""
        }
    }
    
    private func medalColor(for rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return Color(white: 0.75)
        case 3: return .orange
        default: return .clear
        }
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    private func formatRelativeDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: dateString) else {
            return "Unknown"
        }
        
        let now = Date()
        let components = Calendar.current.dateComponents([.day, .hour, .minute], from: date, to: now)
        
        if let days = components.day, days > 0 {
            return "\(days)d ago"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h ago"
        } else if let minutes = components.minute {
            return "\(minutes)m ago"
        } else {
            return "Just now"
        }
    }
}

#Preview {
    LeaderboardView()
        .environmentObject(LeaderboardService())
}