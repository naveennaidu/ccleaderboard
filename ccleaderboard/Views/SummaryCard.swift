import SwiftUI

struct SummaryCard: View {
    let dailyUsage: [DailyUsage]
	
    private var totalCost: Double {
        dailyUsage.reduce(0) { $0 + $1.totalCost }
    }
	
    private var totalTokens: Int {
        dailyUsage.reduce(0) { $0 + $1.totalTokens }
    }
    
    private var totalInputTokens: Int {
        dailyUsage.reduce(0) { $0 + $1.inputTokens }
    }
    
    private var totalOutputTokens: Int {
        dailyUsage.reduce(0) { $0 + $1.outputTokens }
    }
    
    private var averageDailyCost: Double {
        guard !dailyUsage.isEmpty else { return 0 }
        return totalCost / Double(dailyUsage.count)
    }
	
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
        VStack(spacing: 16) {
            // Main stats
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Total Cost")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Text(currencyFormatter.string(from: NSNumber(value: totalCost)) ?? "$0.00")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    Text("Period")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Text("\(dailyUsage.count) days")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            }
            
            Divider()
            
            // Secondary stats
            HStack(spacing: 20) {
                StatItem(
                    label: "Avg Daily",
                    value: currencyFormatter.string(from: NSNumber(value: averageDailyCost)) ?? "$0.00",
                    icon: "chart.line.uptrend.xyaxis"
                )
                
                Spacer()
                
                StatItem(
                    label: "Total Tokens",
                    value: tokenFormatter.string(from: NSNumber(value: totalTokens)) ?? "0",
                    icon: "text.word.spacing"
                )
                
                Spacer()
                
                StatItem(
                    label: "Input/Output",
                    value: "\(tokenFormatter.string(from: NSNumber(value: totalInputTokens)) ?? "0") / \(tokenFormatter.string(from: NSNumber(value: totalOutputTokens)) ?? "0")",
                    icon: "arrow.left.arrow.right"
                )
            }
        }
        .padding(24)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    SummaryCard(dailyUsage: [])
        .padding()
}