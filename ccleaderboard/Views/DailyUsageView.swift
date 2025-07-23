import SwiftUI

struct DailyUsageView: View {
    @StateObject private var dataLoader = UsageDataLoader.shared
    @EnvironmentObject var leaderboardService: LeaderboardService
    @State private var selectedProject: String? = nil
    @State private var showProjectFilter = false
    @State private var hoveredRow: UUID? = nil
    @State private var isSyncing = false
    @State private var lastSyncTime: Date?
    
    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    private let tokenFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            Spacer()
            contentView
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            dataLoader.loadDailyUsage()
        }
        .onChange(of: dataLoader.dailyUsage) { newUsage in
            // Auto-sync when data changes if user is joined
            if leaderboardService.isJoined && !newUsage.isEmpty && !isSyncing {
                print("[DailyUsageView] Data changed, triggering auto-sync. Data count: \(newUsage.count)")
                performSync()
            }
        }
    }
    
    @ViewBuilder
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Claude Usage")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    if let selectedDir = dataLoader.selectedDirectory {
                        directoryInfoView(selectedDir: selectedDir)
                    }
                }
                Spacer()
                
                // Sync button and refresh button
                HStack(spacing: 12) {
                    if leaderboardService.isJoined {
                        syncButton
                    }
                    refreshButton
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 12)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    @ViewBuilder
    private func directoryInfoView(selectedDir: URL) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "folder.fill")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(selectedDir.path)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Button(action: { dataLoader.selectDirectory() }) {
                Text("Change")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var syncButton: some View {
        Button(action: performSync) {
            HStack(spacing: 4) {
                if isSyncing {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.system(size: 16))
                }
                Text(isSyncing ? "Syncing..." : "Sync")
                    .font(.caption)
            }
            .foregroundColor(isSyncing ? .secondary : .accentColor)
        }
        .buttonStyle(.plain)
        .disabled(isSyncing || dataLoader.isLoading)
        .help(lastSyncTime != nil ? "Last synced: \(lastSyncTime!.formatted())" : "Sync usage data to leaderboard")
    }
    
    private var refreshButton: some View {
        Button(action: { dataLoader.loadDailyUsage() }) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .disabled(dataLoader.isLoading)
        .help("Refresh usage data")
    }
    
    private func performSync() {
        Task {
            print("[DailyUsageView] Starting sync process...")
            isSyncing = true
            do {
                // First ensure data is loaded
                if dataLoader.dailyUsage.isEmpty {
                    print("[DailyUsageView] No data loaded, loading now...")
                    dataLoader.loadDailyUsage()
                    
                    // Wait for data to load
                    var attempts = 0
                    while dataLoader.isLoading && attempts < 30 {
                        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                        attempts += 1
                    }
                    print("[DailyUsageView] Data loading wait completed after \(attempts) attempts")
                }
                
                print("[DailyUsageView] Calling performSmartSync...")
                try await leaderboardService.performSmartSync()
                lastSyncTime = Date()
                print("[DailyUsageView] Sync completed successfully at \(lastSyncTime!)")
            } catch {
                print("[DailyUsageView] Sync failed: \(error.localizedDescription)")
            }
            isSyncing = false
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if dataLoader.isLoading {
            loadingView
        } else if let error = dataLoader.error {
            errorView(error: error)
        } else if dataLoader.dailyUsage.isEmpty && dataLoader.selectedDirectory == nil {
            noDirectoryView
        } else if dataLoader.dailyUsage.isEmpty {
            emptyDataView
        } else {
            usageDataView
        }
    }
    
    private var loadingView: some View {
        ProgressView("Loading usage data...")
            .padding()
    }
    
    private func errorView(error: Error) -> some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.red)
            Text("Error loading data")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var noDirectoryView: some View {
        VStack {
            Image(systemName: "folder.badge.questionmark")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("Select Claude Data Directory")
                .font(.headline)
            Text("Click the button below to select your Claude config directory\n(usually ~/.config/claude or ~/.claude)")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Select Directory") {
                dataLoader.selectDirectory()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding()
    }
    
    private var emptyDataView: some View {
        VStack {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No usage data found")
                .font(.headline)
            Text("Make sure the selected directory contains Claude usage data")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Select Different Directory") {
                dataLoader.selectDirectory()
            }
            .buttonStyle(.bordered)
            .padding(.top)
        }
        .padding()
    }
    
    private var usageDataView: some View {
        ScrollView {
            VStack(spacing: 20) {
                SummaryCard(dailyUsage: dataLoader.dailyUsage)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                
                usageTableView
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var usageTableView: some View {
        VStack(spacing: 0) {
            tableHeaderView
            
            Divider()
            
            tableRowsView
        }
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
    
    private var tableHeaderView: some View {
        HStack {
            Text("Date")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Models")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Input")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .trailing)
            
            Text("Output")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .trailing)
            
            Text("Cost (USD)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .trailing)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    @ViewBuilder
    private var tableRowsView: some View {
        ForEach(dataLoader.dailyUsage) { daily in
            VStack(spacing: 0) {
                DailyUsageTableRow(
                    daily: daily,
                    tokenFormatter: tokenFormatter,
                    currencyFormatter: currencyFormatter,
                    isHovered: hoveredRow == daily.id
                )
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        hoveredRow = hovering ? daily.id : nil
                    }
                }
                
                if daily.id != dataLoader.dailyUsage.last?.id {
                    Divider()
                        .padding(.horizontal, 24)
                }
            }
        }
    }
}


#Preview {
    DailyUsageView()
}
