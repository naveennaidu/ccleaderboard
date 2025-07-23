//
//  ccleaderboardApp.swift
//  ccleaderboard
//
//  Created by Naveennaidu Mummana on 23/07/25.
//

import SwiftUI

@main
struct ccleaderboardApp: App {
    @StateObject private var leaderboardService = LeaderboardService()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(leaderboardService)
                .onAppear {
                    // Perform sync on app launch if user is joined
                    performBackgroundSync()
                }
                .onChange(of: scenePhase) { newPhase in
                    switch newPhase {
                    case .active:
                        // App became active (foreground)
                        performBackgroundSync()
                    case .inactive:
                        // App is inactive
                        break
                    case .background:
                        // App is in background
                        break
                    @unknown default:
                        break
                    }
                }
        }
    }
    
    private func performBackgroundSync() {
        guard leaderboardService.isJoined else { return }
        
        Task {
            do {
                print("🔄 Performing background sync...")
                try await leaderboardService.performSmartSync()
                print("✅ Background sync completed")
            } catch {
                print("❌ Background sync failed: \(error.localizedDescription)")
            }
        }
    }
}
