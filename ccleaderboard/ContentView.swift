//
//  ContentView.swift
//  ccleaderboard
//
//  Created by Naveennaidu Mummana on 23/07/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var leaderboardService: LeaderboardService
    
    var body: some View {
        TabView {
            DailyUsageView()
                .tabItem {
                    Label("Usage", systemImage: "chart.bar.fill")
                }
                .environmentObject(leaderboardService)
            
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
        .environmentObject(LeaderboardService())
}
