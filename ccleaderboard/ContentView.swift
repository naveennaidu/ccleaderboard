//
//  ContentView.swift
//  ccleaderboard
//
//  Created by Naveennaidu Mummana on 23/07/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var leaderboardService = LeaderboardService()
    
    var body: some View {
        TabView {
            DailyUsageView()
                .tabItem {
                    Label("Usage", systemImage: "chart.bar.fill")
                }
            
            LeaderboardView()
                .tabItem {
                    Label("Leaderboard", systemImage: "chart.line.uptrend.xyaxis")
                }
                .environmentObject(leaderboardService)
        }
    }
}

#Preview {
    ContentView()
}
